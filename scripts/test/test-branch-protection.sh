#!/usr/bin/env sh
# Contract checks for the branch-protection API payload.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

SCRIPT="$ROOT/scripts/setup-branch-protection.sh"
DOCS_WORKFLOW="$ROOT/.github/workflows/docs-check.yml"
SECURITY_WORKFLOW="$ROOT/.github/workflows/action-security.yml"

assert_contains() {
  label="$1"; pattern="$2"
  if grep -Eq -- "$pattern" "$SCRIPT"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"; pattern="$2"
  if grep -Eq -- "$pattern" "$SCRIPT"; then
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else PASS=$((PASS+1)); fi
}

assert_contains "boolean fields use typed gh api values" "-F 'required_status_checks\[strict\]=true'"
assert_contains "approval count uses typed gh api value" "-F 'required_pull_request_reviews\[required_approving_review_count\]=1'"
assert_contains "empty restrictions use JSON null" "-F 'restrictions=null'"
assert_contains "nested fields are shell-quoted" "-f 'required_status_checks\[contexts\]\[\]="
assert_contains "PR title context matches emitted check" "-f 'required_status_checks\[contexts\]\[\]=PR Title Check'"
assert_contains "metadata context matches emitted check" "-f 'required_status_checks\[contexts\]\[\]=Validate required docs & metadata'"
assert_contains "docs context matches emitted check" "-f 'required_status_checks\[contexts\]\[\]=Markdown lint \+ link check \+ TBD/TODO scan'"
assert_contains "actionlint context matches emitted check" "-f 'required_status_checks\[contexts\]\[\]=actionlint \(workflow syntax\)'"
assert_contains "zizmor context matches emitted check" "-f 'required_status_checks\[contexts\]\[\]=zizmor \(workflow security\)'"
assert_not_contains "strict is not sent as raw string" "-f required_status_checks\[strict\]=true"
assert_not_contains "approval count is not sent as raw string" "-f required_pull_request_reviews\[required_approving_review_count\]=1"
assert_not_contains "docs check is not path-filtered" "paths:"

if grep -Eq 'paths:' "$DOCS_WORKFLOW" || grep -Eq 'paths:' "$SECURITY_WORKFLOW"; then
  FAIL=$((FAIL+1)); printf 'FAIL required checks run for every pull request\n' >&2
else PASS=$((PASS+1)); fi

sh -n "$SCRIPT" && PASS=$((PASS+1)) || {
  FAIL=$((FAIL+1)); printf 'FAIL branch-protection script passes sh syntax check\n' >&2
}

report
