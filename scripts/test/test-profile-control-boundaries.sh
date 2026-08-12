#!/usr/bin/env sh
# Structural contracts for reusable, channel-isolated profile control boundaries.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

CI="$ROOT/.github/workflows/ci.yml"
CI_QUALITY="$ROOT/.github/workflows/ci-quality.yml"
CI_TEST="$ROOT/.github/workflows/ci-test.yml"
MONOREPO="$ROOT/.github/workflows/ci-monorepo.yml"
SECRET_SCAN="$ROOT/.github/workflows/secret-scan.yml"
DEPENDENCY_REVIEW="$ROOT/.github/workflows/dependency-review.yml"
CODEQL="$ROOT/.github/workflows/codeql.yml"
AI_EVALUATION="$ROOT/.github/workflows/ai-evaluation.yml"

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else PASS=$((PASS+1)); fi
}

assert_text_contains() {
  label="$1"; value="$2"; pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_text_not_contains() {
  label="$1"; value="$2"; pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else PASS=$((PASS+1)); fi
}

assert_count() {
  label="$1"; file="$2"; pattern="$3"; expected="$4"
  actual="$(grep -Ec -- "$pattern" "$file" || true)"
  assert_eq "$label" "$actual" "$expected"
}

on_block() {
  sed -n '/^on:/,/^permissions:/p' "$1"
}

workflow_call_block() {
  awk '
    /^  workflow_call:/ { inside=1 }
    inside && /^  [a-z_]+:/ && $0 !~ /^  workflow_call:/ { exit }
    inside { print }
  ' "$1"
}

execution_channel_block() {
  awk '
    /^      execution_channel:/ { inside=1 }
    inside && /^      [a-zA-Z0-9_-]+:/ && $0 !~ /^      execution_channel:/ { exit }
    inside && /^  [a-zA-Z0-9_-]+:/ { exit }
    inside { print }
  ' "$1"
}

job_block() {
  file="$1"; job="$2"
  awk -v header="  $job:" '
    $0 == header { inside=1 }
    inside && /^  [a-zA-Z0-9_-]+:/ && $0 != header { exit }
    inside { print }
  ' "$file"
}

assert_read_only() {
  label="$1"; file="$2"
  permissions="$(sed -n '/^permissions:/,/^$/p' "$file")"
  assert_text_contains "$label defaults to contents read" "$permissions" '^  contents: read$'
  assert_text_not_contains "$label has no workflow-level writes" "$permissions" ': write'
}

assert_action_pin() {
  label="$1"; file="$2"; action="$3"; sha="$4"; version="$5"
  assert_contains "$label" "$file" \
    "uses: ${action}@${sha}[[:space:]]+# ${version}"
}

assert_reusable_input() {
  label="$1"; file="$2"; requirement="$3"
  call="$(workflow_call_block "$file")"
  channel="$(execution_channel_block "$file")"
  assert_text_contains "$label exposes workflow_call" "$call" '^  workflow_call:$'
  assert_text_contains "$label declares execution_channel" "$channel" '^      execution_channel:$'
  assert_text_contains "$label types execution_channel as string" "$channel" '^        type: string$'
  if [ "$requirement" = required ]; then
    assert_text_contains "$label requires execution_channel" "$channel" '^        required: true$'
  else
    assert_text_contains "$label keeps execution_channel optional" "$channel" '^        required: false$'
  fi
  assert_text_not_contains "$label accepts no secret input" "$call" '^    secrets:'
}

assert_concurrency_contract() {
  label="$1"; file="$2"; suffix="$3"; fallback="$4"
  group="$(awk '
    /^concurrency:$/ { inside=1; next }
    inside && /^[^[:space:]]/ { exit }
    inside && /^  group:/ { print; exit }
  ' "$file")"
  assert_text_contains "$label has workflow suffix" "$group" "-${suffix}-"
  assert_text_contains "$label has explicit channel" "$group" \
    "inputs\.execution_channel \|\| '${fallback}'"
  assert_text_contains "$label has PR/ref/run identity" "$group" \
    'github\.event\.pull_request\.number \|\| github\.ref \|\| github\.run_id'
  assert_text_not_contains "$label does not discriminate by event name" "$group" 'github\.event_name'
}

assert_validation_before_checkout() {
  label="$1"; block="$2"; allowed="$3"
  validation_line="$(printf '%s\n' "$block" | grep -n -m1 'name: Validate execution channel' | cut -d: -f1 || true)"
  checkout_line="$(printf '%s\n' "$block" | grep -n -m1 'name: Checkout' | cut -d: -f1 || true)"
  if [ -n "$validation_line" ] && [ -n "$checkout_line" ] && [ "$validation_line" -lt "$checkout_line" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); printf 'FAIL %s validates before checkout\n' "$label" >&2
  fi
  assert_text_contains "$label validates documented channels" "$block" "$allowed"
  assert_text_contains "$label rejects unknown channels" "$block" 'exit 1'
}

# Direct trigger, permission, check-name, and action-pin compatibility.
secret_on="$(on_block "$SECRET_SCAN")"
assert_text_contains "secret scan retains pull requests" "$secret_on" '^  pull_request:$'
assert_text_contains "secret scan retains main push" "$secret_on" '^  push:$'
assert_text_contains "secret scan push targets main" "$secret_on" 'branches: \[main\]'
assert_text_contains "secret scan retains schedule" "$secret_on" '^  schedule:$'
assert_text_contains "secret scan retains manual dispatch" "$secret_on" '^  workflow_dispatch:$'

dependency_on="$(on_block "$DEPENDENCY_REVIEW")"
assert_text_contains "dependency review retains pull requests" "$dependency_on" '^  pull_request:$'
assert_text_contains "dependency review retains manual dispatch" "$dependency_on" '^  workflow_dispatch:$'
assert_text_not_contains "dependency review gains no push trigger" "$dependency_on" '^  push:'
assert_text_not_contains "dependency review gains no schedule trigger" "$dependency_on" '^  schedule:'

codeql_on="$(on_block "$CODEQL")"
assert_text_contains "CodeQL retains pull requests" "$codeql_on" '^  pull_request:$'
assert_count "CodeQL direct branches stay main-only" "$CODEQL" '^    branches: \[main\]$' 2
assert_text_contains "CodeQL retains main push" "$codeql_on" '^  push:$'
assert_text_contains "CodeQL retains schedule" "$codeql_on" '^  schedule:$'
assert_text_contains "CodeQL retains manual dispatch" "$codeql_on" '^  workflow_dispatch:$'

ai_on="$(on_block "$AI_EVALUATION")"
assert_text_contains "AI evaluation retains pull requests" "$ai_on" '^  pull_request:$'
assert_text_contains "AI evaluation retains path filters" "$ai_on" '^    paths:$'
for path in 'prompts/[*][*]' 'evals/[*][*]' 'src/[*][*]' '[.]github/workflows/ai-evaluation[.]yml'; do
  assert_text_contains "AI evaluation retains path $path" "$ai_on" "$path"
done
assert_text_contains "AI evaluation retains manual dispatch" "$ai_on" '^  workflow_dispatch:$'

for file in "$SECRET_SCAN" "$DEPENDENCY_REVIEW" "$CODEQL" "$AI_EVALUATION"; do
  assert_not_contains "$(basename "$file") never uses pull_request_target" "$file" 'pull_request_target:'
  assert_not_contains "$(basename "$file") defines no reusable secret input" "$file" '^    secrets:'
done

for file in "$CI_QUALITY" "$CI_TEST" "$MONOREPO" "$SECRET_SCAN" \
  "$DEPENDENCY_REVIEW" "$CODEQL" "$AI_EVALUATION"; do
  assert_not_contains "$(basename "$file") does not use inherited event-name discrimination" \
    "$file" 'github\.event_name'
done

assert_read_only "secret scan" "$SECRET_SCAN"
assert_read_only "dependency review" "$DEPENDENCY_REVIEW"
assert_read_only "CodeQL" "$CODEQL"
assert_read_only "AI evaluation" "$AI_EVALUATION"
assert_contains "secret scan check name is stable" "$SECRET_SCAN" '^    name: gitleaks \(block on any secret\)$'
assert_contains "dependency review check name is stable" "$DEPENDENCY_REVIEW" '^    name: osv-scanner \(block on vulnerable dependency\)$'
assert_contains "CodeQL check name is stable" "$CODEQL" '^    name: CodeQL \(blocking\)$'
assert_contains "direct AI check name is stable" "$AI_EVALUATION" '^    name: AI evaluation \(advisory skeleton\)$'
assert_action_pin "secret scan checkout pin is stable" "$SECRET_SCAN" actions/checkout 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1
assert_action_pin "dependency review checkout pin is stable" "$DEPENDENCY_REVIEW" actions/checkout 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1
assert_action_pin "CodeQL checkout pin is stable" "$CODEQL" actions/checkout 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1
for action in init autobuild analyze; do
  assert_action_pin "CodeQL $action pin is stable" "$CODEQL" "github/codeql-action/$action" 5595ccaf912efad79be6eef63a5619ff05969be3 v4.37.6
done
assert_action_pin "AI evaluation checkout pin is stable" "$AI_EVALUATION" actions/checkout 3d3c42e5aac5ba805825da76410c181273ba90b1 v7.0.1

# Every called boundary exposes and validates the explicit channel contract.
assert_reusable_input "quality boundary" "$CI_QUALITY" optional
assert_reusable_input "test boundary" "$CI_TEST" optional
assert_reusable_input "monorepo boundary" "$MONOREPO" optional
assert_reusable_input "secret scan boundary" "$SECRET_SCAN" required
assert_reusable_input "dependency review boundary" "$DEPENDENCY_REVIEW" required
assert_reusable_input "CodeQL boundary" "$CODEQL" required
assert_reusable_input "AI evaluation boundary" "$AI_EVALUATION" required

assert_count "baseline dispatcher passes execution channel to all CI boundaries" "$CI" \
  '^      execution_channel: baseline-ci$' 3

assert_concurrency_contract "quality boundary" "$CI_QUALITY" ci-quality manual
assert_concurrency_contract "test boundary" "$CI_TEST" ci-test manual
assert_concurrency_contract "monorepo boundary" "$MONOREPO" ci-monorepo manual
assert_concurrency_contract "secret scan boundary" "$SECRET_SCAN" secret-scan baseline-direct
assert_concurrency_contract "dependency review boundary" "$DEPENDENCY_REVIEW" dependency-review baseline-direct
assert_concurrency_contract "CodeQL boundary" "$CODEQL" codeql baseline-direct
assert_concurrency_contract "AI evaluation boundary" "$AI_EVALUATION" ai-evaluation baseline-direct

assert_validation_before_checkout "quality boundary" "$(job_block "$CI_QUALITY" quality)" 'baseline-ci\|profile-advisory\|manual'
assert_validation_before_checkout "test boundary" "$(job_block "$CI_TEST" test)" 'baseline-ci\|profile-advisory\|manual'
assert_validation_before_checkout "monorepo boundary" "$(job_block "$MONOREPO" resolve)" 'baseline-ci\|profile-advisory\|manual'
assert_validation_before_checkout "secret scan boundary" "$(job_block "$SECRET_SCAN" secret-scan)" 'baseline-direct\|profile-advisory'
assert_validation_before_checkout "dependency review boundary" "$(job_block "$DEPENDENCY_REVIEW" osv-scan)" 'baseline-direct\|profile-advisory'
assert_validation_before_checkout "CodeQL boundary" "$(job_block "$CODEQL" codeql)" 'baseline-direct\|profile-advisory'

# The reusable AI path is deterministic and isolated from the direct secret-aware path.
reusable_ai="$(job_block "$AI_EVALUATION" deterministic-ai-evaluation)"
direct_ai="$(job_block "$AI_EVALUATION" ai-evaluation)"
assert_text_contains "reusable AI job selects non-empty input" "$reusable_ai" \
  "if:.*inputs\.execution_channel != ''"
assert_validation_before_checkout "reusable AI boundary" "$reusable_ai" 'profile-advisory'
assert_text_contains "reusable AI runs deterministic contract" "$reusable_ai" 'sh evals/run-evals\.sh --check'
assert_text_not_contains "reusable AI has no secrets context" "$reusable_ai" 'secrets\.'
assert_text_not_contains "reusable AI has no API credential" "$reusable_ai" 'AI_EVAL_API_KEY'
assert_text_not_contains "reusable AI has no provider command" "$reusable_ai" 'provider|model call'
assert_text_contains "direct AI job selects empty input" "$direct_ai" \
  "if:.*inputs\.execution_channel == ''"
assert_validation_before_checkout "direct AI boundary" "$direct_ai" 'baseline-direct'
assert_text_contains "direct AI retains credential-aware behavior" "$direct_ai" \
  'AI_EVAL_API_KEY:.*secrets\.AI_EVAL_API_KEY'
assert_text_contains "direct AI retains missing-credential skip" "$direct_ai" \
  "env\.AI_EVAL_API_KEY == ''"
assert_text_contains "direct AI retains credential-gated run" "$direct_ai" \
  "env\.AI_EVAL_API_KEY != ''"

# CodeQL write permission stays at job scope for caller-compatible least privilege.
codeql_workflow_permissions="$(sed -n '/^permissions:/,/^$/p' "$CODEQL")"
codeql_job_permissions="$(printf '%s\n' "$(job_block "$CODEQL" codeql)" | sed -n '/^    permissions:/,/^    steps:/p')"
assert_text_not_contains "CodeQL workflow keeps security writes out of global scope" \
  "$codeql_workflow_permissions" 'security-events: write'
assert_text_contains "CodeQL job retains security event writes" "$codeql_job_permissions" \
  '^      security-events: write'

report
