#!/usr/bin/env sh
# Contracts for suppressing only duplicated direct profile-control execution.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

MODE_WORKFLOW="$ROOT/.github/workflows/direct-execution-mode.yml"
CI="$ROOT/.github/workflows/ci.yml"
SECRET_SCAN="$ROOT/.github/workflows/secret-scan.yml"
DEPENDENCY_REVIEW="$ROOT/.github/workflows/dependency-review.yml"
CODEQL="$ROOT/.github/workflows/codeql.yml"
AI_EVALUATION="$ROOT/.github/workflows/ai-evaluation.yml"
README="$ROOT/README.md"
GETTING_STARTED="$ROOT/docs/getting-started.md"
ADR="$ROOT/docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md"
ROADMAP="$ROOT/docs/plans/roadmap.md"
TECHNICAL_DEBT="$ROOT/docs/plans/technical-debt.md"
CHANGELOG="$ROOT/CHANGELOG.md"

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

job_block() {
  file="$1"; job="$2"
  awk -v header="  $job:" '
    $0 == header { inside=1 }
    inside && /^  [a-zA-Z0-9_-]+:/ && $0 != header { exit }
    inside { print }
  ' "$file"
}

if [ -f "$MODE_WORKFLOW" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL direct execution mode workflow exists\n' >&2
  report
  exit 1
fi

assert_contains "mode workflow is reusable only" "$MODE_WORKFLOW" '^  workflow_call:$'
assert_not_contains "mode workflow has no direct PR trigger" "$MODE_WORKFLOW" '^  pull_request:'
assert_not_contains "mode workflow has no direct push trigger" "$MODE_WORKFLOW" '^  push:'
assert_contains "mode workflow defaults to read-only" "$MODE_WORKFLOW" '^  contents: read$'
assert_contains "mode workflow exposes boolean-like output" "$MODE_WORKFLOW" \
  'value: [$][{][{] jobs\.resolve\.outputs\.direct_profile_controls [}][}]'
assert_contains "mode workflow invokes canonical resolver" "$MODE_WORKFLOW" \
  'sh scripts/resolve-direct-execution-mode\.sh'
assert_contains "mode workflow requires caller event input" "$MODE_WORKFLOW" \
  '^      source_event:$'
assert_contains "mode workflow binds the caller event through env" "$MODE_WORKFLOW" \
  'SOURCE_EVENT: [$][{][{] inputs\.source_event [}][}]'
assert_contains "mode workflow disables checkout credentials" "$MODE_WORKFLOW" \
  'persist-credentials: false'

for workflow in "$CI" "$SECRET_SCAN" "$DEPENDENCY_REVIEW" "$CODEQL"; do
  direct_mode="$(job_block "$workflow" direct_mode)"
  assert_text_contains "$(basename "$workflow") calls direct mode resolver" "$direct_mode" \
    '^    uses: [.]\/\.github\/workflows\/direct-execution-mode[.]yml$'
  assert_text_contains "$(basename "$workflow") passes its source event" "$direct_mode" \
    'source_event: [$][{][{] github\.event_name [}][}]'
done

for job in quality test monorepo; do
  block="$(job_block "$CI" "$job")"
  assert_text_contains "CI $job depends on direct mode" "$block" \
    '^    needs: \[detect, direct_mode\]$'
  assert_text_contains "CI $job runs only in compatibility mode" "$block" \
    "needs\.direct_mode\.outputs\.direct_profile_controls == 'true'"
done

build="$(job_block "$CI" build)"
attest="$(job_block "$CI" attest)"
assert_text_not_contains "build stays independent of direct mode" "$build" 'direct_mode'
assert_text_not_contains "attestation stays independent of direct mode" "$attest" 'direct_mode'
assert_text_contains "attestation rejects monorepo layout explicitly" "$attest" \
  "needs\.detect\.outputs\.layout != 'monorepo'"

for entry in \
  "$SECRET_SCAN|secret-scan" \
  "$DEPENDENCY_REVIEW|osv-scan" \
  "$CODEQL|codeql"; do
  file="${entry%%|*}"
  job="${entry#*|}"
  direct_mode="$(job_block "$file" direct_mode)"
  block="$(job_block "$file" "$job")"
  assert_text_contains "$(basename "$file") resolves mode only for direct invocation" \
    "$direct_mode" "if:.*inputs\.execution_channel == ''"
  assert_text_contains "$(basename "$file") scanner depends on direct mode" "$block" \
    '^    needs: direct_mode$'
  assert_text_contains "$(basename "$file") scanner evaluates skipped resolver safely" "$block" \
    'always\(\)'
  assert_text_contains "$(basename "$file") reusable call remains active" "$block" \
    "inputs\.execution_channel != ''"
  assert_text_contains "$(basename "$file") direct mode must resolve successfully" "$block" \
    "needs\.direct_mode\.result == 'success'"
  assert_text_contains "$(basename "$file") compatibility mode remains active" "$block" \
    "needs\.direct_mode\.outputs\.direct_profile_controls == 'true'"
done

assert_text_not_contains "secret scanner does not inspect inherited event" \
  "$(job_block "$SECRET_SCAN" secret-scan)" 'github\.event_name'
assert_text_not_contains "dependency scanner does not inspect inherited event" \
  "$(job_block "$DEPENDENCY_REVIEW" osv-scan)" 'github\.event_name'
assert_text_not_contains "CodeQL scanner does not inspect inherited event" \
  "$(job_block "$CODEQL" codeql)" 'github\.event_name'

assert_not_contains "provider-backed AI evaluation is not suppressed" "$AI_EVALUATION" \
  'direct-execution-mode[.]yml'

assert_contains "README explains initialized-consumer delegation" "$README" \
  'Initialized profile consumers delegate duplicated direct'
assert_contains "getting started explains bounded PR and push suppression" "$GETTING_STARTED" \
  'direct profile-dependent PR/push jobs$'
assert_contains "ADR records local duplicate suppression" "$ADR" \
  'duplicate suppression implemented locally; hosted consumer revalidation pending'
assert_contains "roadmap identifies hosted revalidation as next gate" "$ROADMAP" \
  'duplicate suppression implemented locally; hosted revalidation next'
assert_contains "technical debt remains open for hosted proof" "$TECHNICAL_DEBT" \
  'Duplicate suppression is implemented locally; hosted consumer revalidation remains pending'
assert_contains "changelog records bounded duplicate suppression" "$CHANGELOG" \
  'Suppressed duplicated direct profile-dependent PR/push jobs'

report
