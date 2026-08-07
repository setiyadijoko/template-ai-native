#!/usr/bin/env sh
# Structural contracts for public CodeQL and OpenSSF Scorecard enforcement.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

CODEQL="$ROOT/.github/workflows/codeql.yml"
SCORECARD="$ROOT/.github/workflows/scorecard.yml"
AGENTS="$ROOT/AGENTS.md"
VULNERABILITY="$ROOT/docs/security/vulnerability-management.md"
ASSUMPTIONS="$ROOT/docs/assumptions.md"
DEBT="$ROOT/docs/plans/technical-debt.md"
CHANGELOG="$ROOT/CHANGELOG.md"

assert_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"

  if printf '%s\n' "$value" | grep -Eq "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_text_not_contains() {
  label="$1"
  value="$2"
  pattern="$3"

  if printf '%s\n' "$value" | grep -Eq "$pattern"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_text_count() {
  label="$1"
  value="$2"
  pattern="$3"
  expected="$4"
  actual="$(printf '%s\n' "$value" | grep -Ec "$pattern" || true)"

  assert_eq "$label" "$actual" "$expected"
}

assert_checkout_credentials() {
  label="$1"
  file="$2"
  actual="$(awk '
    function finish_step() {
      if (checkout) {
        total++
        if (hardened) secure++
      }
    }
    /^[[:space:]]*-[[:space:]]+name:/ {
      finish_step()
      checkout = 0
      hardened = 0
    }
    /^[[:space:]]*uses:[[:space:]]+actions\/checkout@/ { checkout = 1 }
    checkout && /^[[:space:]]*persist-credentials:[[:space:]]+false([[:space:]]|$)/ {
      hardened = 1
    }
    END {
      finish_step()
      printf "%d:%d\n", total, secure
    }
  ' "$file")"

  assert_eq "$label" "$actual" "1:1"
}

assert_action_pins() {
  label="$1"
  shift
  invalid="$({
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$@" |
      sed '/^\.\//d' |
      grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]+v[0-9]+(\.[0-9]+){1,2}([.+-][0-9A-Za-z.-]+)?$'
  } || true)"

  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     unpinned action references:\n%s\n' "$label" "$invalid" >&2
  fi
}

assert_scorecard_action_allowlist() {
  invalid="$({
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$SCORECARD" |
      grep -Ev '^(actions/checkout|ossf/scorecard-action|github/codeql-action/upload-sarif)@'
  } || true)"

  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL scorecard uses only approved actions\n     unapproved action references:\n%s\n' "$invalid" >&2
  fi
}

codeql_pr_trigger="$(sed -n '/^  pull_request:/,/^  push:/p' "$CODEQL")"
codeql_push_trigger="$(sed -n '/^  push:/,/^  schedule:/p' "$CODEQL")"
codeql_workflow_permissions="$(sed -n '/^permissions:/,/^$/p' "$CODEQL")"
codeql_job_permissions="$(sed -n '/^    permissions:/,/^$/p' "$CODEQL")"
scorecard_triggers="$(sed -n '/^on:/,/^permissions:/p' "$SCORECARD")"
scorecard_push_trigger="$(sed -n '/^  push:/,/^  schedule:/p' "$SCORECARD")"
scorecard_workflow_permissions="$(sed -n '/^permissions:/,/^$/p' "$SCORECARD")"
scorecard_job_permissions="$(sed -n '/^    permissions:/,/^$/p' "$SCORECARD")"

# CodeQL: public-repository PR scanning, isolated concurrency, and fail closed.
assert_contains "codeql runs for pull requests" "$CODEQL" '^  pull_request:$'
assert_not_contains "codeql forbids pull_request_target" "$CODEQL" 'pull_request_target:'
assert_text_contains "codeql pull requests target main" "$codeql_pr_trigger" 'branches: \[main\]'
assert_text_contains "codeql pushes target main" "$codeql_push_trigger" 'branches: \[main\]'
assert_contains "codeql retains schedule" "$CODEQL" '^  schedule:$'
assert_contains "codeql retains manual dispatch" "$CODEQL" '^  workflow_dispatch:$'
assert_contains "codeql isolates concurrency by PR or ref" "$CODEQL" 'group:.*github\.event\.pull_request\.number.*github\.ref'
assert_text_contains "codeql workflow defaults to read-only" "$codeql_workflow_permissions" '^  contents: read([[:space:]]|$)'
assert_text_not_contains "codeql workflow has no write permission" "$codeql_workflow_permissions" ': write'
assert_text_contains "codeql job reads contents" "$codeql_job_permissions" '^      contents: read[[:space:]]+#'
assert_text_contains "codeql job writes security events" "$codeql_job_permissions" '^      security-events: write[[:space:]]+#'
assert_contains "codeql is labeled blocking" "$CODEQL" 'name: CodeQL \(blocking\)'
assert_not_contains "codeql delegates language autodetection to the action" "$CODEQL" '^[[:space:]]+languages:'
assert_not_contains "codeql has no error suppression" "$CODEQL" 'continue-on-error:'
assert_contains "codeql retains timeout" "$CODEQL" 'timeout-minutes: 30'
assert_checkout_credentials "codeql checkout disables credential persistence" "$CODEQL"

# Scorecard: trusted events, OIDC publication, advisory findings, fail-closed execution.
assert_text_not_contains "scorecard does not run on pull requests" "$scorecard_triggers" 'pull_request:'
assert_contains "scorecard retains main push" "$SCORECARD" '^  push:$'
assert_text_contains "scorecard pushes target main" "$scorecard_push_trigger" 'branches: \[main\]'
assert_contains "scorecard retains schedule" "$SCORECARD" '^  schedule:$'
assert_contains "scorecard retains manual dispatch" "$SCORECARD" '^  workflow_dispatch:$'
assert_text_contains "scorecard workflow defaults to read-only" "$scorecard_workflow_permissions" '^  contents: read([[:space:]]|$)'
assert_text_not_contains "scorecard workflow has no write permission" "$scorecard_workflow_permissions" ': write'
assert_not_contains "scorecard has no top-level env or defaults" "$SCORECARD" '^(env|defaults):'
assert_not_contains "scorecard job has no forbidden execution context" "$SCORECARD" '^    (env|defaults|environment|container|services):'
assert_not_contains "scorecard has no shell run steps" "$SCORECARD" '^[[:space:]]*(-[[:space:]]+)?run:'
assert_text_contains "scorecard job reads contents" "$scorecard_job_permissions" '^      contents: read[[:space:]]+#'
assert_text_contains "scorecard job writes security events" "$scorecard_job_permissions" '^      security-events: write[[:space:]]+#'
assert_text_not_contains "scorecard workflow does not request OIDC" "$scorecard_workflow_permissions" '^  id-token:'
assert_text_count "scorecard job requests OIDC exactly once" "$scorecard_job_permissions" '^      id-token: write[[:space:]]+#' "1"
assert_contains "scorecard job label documents advisory findings" "$SCORECARD" 'name: OpenSSF Scorecard \(advisory\)'
assert_contains "scorecard publishes authenticated results" "$SCORECARD" 'publish_results: true'
assert_contains "scorecard uploads its SARIF category" "$SCORECARD" 'category: scorecard'
assert_not_contains "scorecard has no error suppression" "$SCORECARD" 'continue-on-error:'
assert_contains "scorecard retains timeout" "$SCORECARD" 'timeout-minutes: 15'
assert_checkout_credentials "scorecard checkout disables credential persistence" "$SCORECARD"
assert_scorecard_action_allowlist

assert_action_pins "security workflows pin actions with release tags" "$CODEQL" "$SCORECARD"

# Current-state documentation must close TD-0006 without private-repo claims.
assert_contains "agents defines fail-closed CodeQL" "$AGENTS" 'CodeQL.*fail[- ]closed'
assert_contains "agents preserves advisory Scorecard findings" "$AGENTS" 'Scorecard findings.*advisory'
assert_contains "vulnerability guide documents public storage" "$VULNERABILITY" 'public repository.*Code Scanning'
assert_contains "assumptions document Scorecard OIDC" "$ASSUMPTIONS" 'Scorecard.*OIDC'
assert_contains "technical debt closes TD-0006" "$DEBT" 'TD-0006.*Closed 2026-08-07'
assert_contains "changelog records CodeQL PR enforcement" "$CHANGELOG" 'CodeQL.*pull request'
assert_contains "changelog records Scorecard OIDC" "$CHANGELOG" 'Scorecard.*OIDC'
assert_not_contains "agents drops private-repo scanning state" "$AGENTS" 'private repo.*no GHAS|without GHAS'
assert_not_contains "vulnerability guide drops private-repo scanning state" "$VULNERABILITY" 'private personal repo|without GHAS'
assert_not_contains "assumptions drop private Scorecard limitation" "$ASSUMPTIONS" 'limited on private repos'

report
