#!/usr/bin/env sh
# Contract checks for the optional Graphify codebase-knowledge integration.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

DOC="$ROOT/docs/ai/graphify.md"
ADR="$ROOT/docs/adr/0005-adopt-graphify-as-optional-codebase-memory.md"
README="$ROOT/README.md"
GITIGNORE="$ROOT/.gitignore"
GRAPH="$ROOT/.github/workflows/code-review-graph.yml"
OCR="$ROOT/.github/workflows/open-code-review.yml"

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq "$pattern" "$file"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_contains "Graphify docs pin the reference package" "$DOC" 'graphifyy==0\.9\.35'
assert_contains "Graphify docs include project-scoped Codex setup" "$DOC" 'graphify install --project --platform codex'
assert_contains "Graphify docs identify generated output" "$DOC" 'graphify-out/'
assert_contains "Graphify docs separate codebase from runtime memory" "$DOC" 'not user/session memory'
assert_contains "README links Graphify guidance" "$README" 'docs/ai/graphify\.md'
assert_contains "ADR records optional codebase decision" "$ADR" 'optional.*codebase'
assert_contains "ADR excludes runtime or user memory" "$ADR" 'not runtime/user memory'
assert_contains "generated Graphify output is ignored" "$GITIGNORE" '^graphify-out/$'

# Complement rule: existing review layers must remain present.
if [ -f "$GRAPH" ] && [ -f "$OCR" ]; then PASS=$((PASS+1)); else
  FAIL=$((FAIL+1)); printf 'FAIL existing graph and Alibaba workflows remain present\n' >&2
fi

report
