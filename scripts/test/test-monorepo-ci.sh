#!/usr/bin/env sh
# Structural contracts for explicit component-aware monorepo CI.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

CI="$ROOT/.github/workflows/ci.yml"
MONO="$ROOT/.github/workflows/ci-monorepo.yml"
RESOLVER="$ROOT/scripts/resolve-components.sh"

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

assert_pins() {
  invalid="$(sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$MONO" | grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}([[:space:]]+#.*)?$' || true)"
  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL monorepo workflow pins actions\n%s\n' "$invalid" >&2
  fi
}

assert_contains "dispatcher exposes layout" "$CI" 'layout:.*steps\.d\.outputs\.layout'
assert_contains "dispatcher calls monorepo workflow" "$CI" 'uses: ./\.github/workflows/ci-monorepo\.yml'
assert_contains "dispatcher gates monorepo workflow" "$CI" "component-ready == 'true'"
assert_contains "resolver is executable" "$RESOLVER" 'version: 2'

assert_contains "monorepo workflow is reusable" "$MONO" 'workflow_call:'
assert_contains "monorepo workflow validates config" "$MONO" 'resolve-components\.sh --validate'
assert_contains "monorepo workflow emits JSON" "$MONO" 'resolve-components\.sh --json'
assert_contains "monorepo matrix uses explicit components" "$MONO" 'fromJSON\(needs\.resolve\.outputs\.components\)'
assert_contains "monorepo quality check name" "$MONO" 'monorepo / quality /'
assert_contains "monorepo test check name" "$MONO" 'monorepo / test /'
assert_contains "monorepo build check name" "$MONO" 'monorepo / build /'
assert_contains "monorepo aggregate check" "$MONO" 'monorepo / aggregate'
assert_contains "monorepo preserves Go coverage gate" "$MONO" 'Enforce go coverage >= 80%'
assert_contains "component working directory" "$MONO" 'working-directory:.*matrix\.component\.path'
assert_contains "component artifact upload" "$MONO" 'build-\$\{\{ matrix\.component\.id \}\}'
assert_contains "artifact metadata commit" "$MONO" 'GITHUB_SHA'
assert_not_contains "monorepo workflow has no pull request target" "$MONO" 'pull_request_target:'
assert_pins

report
