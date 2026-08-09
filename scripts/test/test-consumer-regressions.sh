#!/usr/bin/env sh
# Regression contracts for the consumer-facing README, monorepo fixture, and
# framework artifact conventions.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

README="$ROOT/README.md"
FIXTURE="$ROOT/tests/fixtures/consumer-monorepo"
CONFIG="$FIXTURE/.template/project.yaml"
ARTIFACTS="$ROOT/docs/development/artifact-conventions.md"

assert_contains() {
  label="$1"
  file="$2"
  pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then
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
  if grep -Eq -- "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_contains "README uses copy-safe clone placeholder" "$README" 'git clone https://github\.com/YOUR-ORG/YOUR-REPO\.git'
assert_contains "README uses copy-safe cd placeholder" "$README" 'cd YOUR-REPO'
assert_not_contains "README has no angle-bracket clone command" "$README" 'git clone <your-new-repo-from-this-template>'
assert_not_contains "README has no angle-bracket cd command" "$README" 'cd <your-repo>'

assert_contains "fixture declares version 2" "$CONFIG" '^version:[[:space:]]+2$'
assert_contains "fixture declares monorepo layout" "$CONFIG" '^layout:[[:space:]]+monorepo$'
assert_contains "fixture declares backend component" "$CONFIG" '^[[:space:]]+- id:[[:space:]]+backend$'
assert_contains "fixture declares frontend component" "$CONFIG" '^[[:space:]]+- id:[[:space:]]+frontend$'
assert_contains "fixture includes Go manifest" "$FIXTURE/src/backend/go.mod" '^module[[:space:]]+example\.com/template-ai-native-fixture/backend$'
assert_contains "fixture includes Node manifest" "$FIXTURE/src/frontend/package.json" '"name"[[:space:]]*:[[:space:]]*"template-ai-native-fixture-frontend"'

assert_contains "artifact guide covers Next.js" "$ARTIFACTS" 'Next\.js.*\.next'
assert_contains "artifact guide covers Nuxt" "$ARTIFACTS" 'Nuxt.*\.output'
assert_contains "artifact guide covers Angular" "$ARTIFACTS" 'Angular.*dist/<project>'
assert_contains "artifact guide states dist packaging boundary" "$ARTIFACTS" 'dist/'
assert_contains "artifact guide states build packaging boundary" "$ARTIFACTS" 'build/'

EXPECTED_TSV="backend$(printf '\t')src/backend$(printf '\t')go$(printf '\t')true$(printf '\t')backend
frontend$(printf '\t')src/frontend$(printf '\t')node$(printf '\t')true$(printf '\t')frontend"
if [ "$(sh "$ROOT/scripts/resolve-components.sh" --tsv "$CONFIG" 2>/dev/null)" = "$EXPECTED_TSV" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
  printf 'FAIL fixture resolves to the expected component list\n' >&2
fi

if sh "$ROOT/scripts/validate-project-config.sh" "$CONFIG" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
  printf 'FAIL fixture project config validates\n' >&2
fi

report
