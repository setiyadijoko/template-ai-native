#!/usr/bin/env sh
# Structural contracts for the fork-safe code-review-graph integration.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

REVIEW="$ROOT/.github/workflows/code-review-graph.yml"
COMMENT="$ROOT/.github/workflows/code-review-graph-comment.yml"
DOC="$ROOT/docs/ai/code-review-graph.md"
ADR="$ROOT/docs/adr/0003-adopt-local-first-graph-pr-review.md"

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq "$pattern" "$file"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else PASS=$((PASS+1)); fi
}

assert_contains "review uses pull_request" "$REVIEW" '^  pull_request:'
assert_not_contains "review forbids pull_request_target" "$REVIEW" 'pull_request_target:'
assert_contains "review is read-only" "$REVIEW" '^  contents: read$'
assert_contains "review disables credential persistence" "$REVIEW" 'persist-credentials: false'
assert_contains "review pins code-review-graph" "$REVIEW" 'tirth8205/code-review-graph@[0-9a-f]{40}[[:space:]]+# v2\.3\.6'
assert_contains "review disables direct comments" "$REVIEW" 'comment: "false"'
assert_contains "review keeps risk advisory" "$REVIEW" 'fail-on-risk: none'
assert_contains "review uploads bounded report" "$REVIEW" 'name: crg-report'

assert_contains "comment uses workflow_run" "$COMMENT" '^  workflow_run:'
assert_not_contains "comment does not checkout code" "$COMMENT" 'actions/checkout@'
assert_contains "comment reads artifacts" "$COMMENT" '^  actions: read$'
assert_contains "comment writes pull requests" "$COMMENT" '^  pull-requests: write$'
assert_contains "comment checks successful pull request run" "$COMMENT" "workflow_run\.conclusion == 'success'"
assert_contains "comment caps artifact size" "$COMMENT" 'MAX_ARCHIVE_BYTES'
assert_contains "comment validates report format" "$COMMENT" 'unexpected format'
assert_contains "comment verifies analyzed commit" "$COMMENT" 'PR head does not match the analyzed commit'
assert_not_contains "comment forbids pull_request_target" "$COMMENT" 'pull_request_target:'

assert_contains "docs record advisory integration" "$DOC" 'advisory'
assert_contains "adr records decision" "$ADR" 'local-first graph PR review'

invalid="$({ sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$REVIEW" "$COMMENT" | grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]+v[0-9]+(\.[0-9]+){1,2}([.+-][0-9A-Za-z.-]+)?$'; } || true)"
if [ -z "$invalid" ]; then PASS=$((PASS+1)); else
  FAIL=$((FAIL+1)); printf 'FAIL all graph workflow actions are SHA-pinned\n%s\n' "$invalid" >&2
fi

report
