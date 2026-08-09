#!/usr/bin/env sh
# Regression contracts for the consumer-facing README, monorepo fixture, and
# framework artifact conventions.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

README="$ROOT/README.md"
GETTING_STARTED="$ROOT/docs/getting-started.md"
LOCAL_SETUP="$ROOT/docs/development/local-setup.md"
FIXTURE="$ROOT/tests/fixtures/consumer-monorepo"
CONFIG="$FIXTURE/.template/project.yaml"
ARTIFACTS="$ROOT/docs/development/artifact-conventions.md"
BACKEND_SOURCE="$FIXTURE/src/backend/main.go"
BACKEND_TEST="$FIXTURE/src/backend/main_test.go"
FRONTEND_SOURCE="$FIXTURE/src/frontend/src/index.ts"
FRONTEND_TEST="$FIXTURE/src/frontend/tests/unit/app.test.ts"
NODE_CATEGORY_HELPER="$ROOT/scripts/run-node-test-category.sh"

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
assert_contains "getting-started uses copy-safe clone placeholder" "$GETTING_STARTED" 'git clone https://github\.com/YOUR-ORG/YOUR-REPO\.git'
assert_contains "getting-started uses copy-safe cd placeholder" "$GETTING_STARTED" 'cd YOUR-REPO'
assert_not_contains "getting-started has no angle-bracket clone command" "$GETTING_STARTED" 'git clone https://github\.com/<owner>/<new-repository>\.git'
assert_not_contains "getting-started has no angle-bracket cd command" "$GETTING_STARTED" 'cd <new-repository>'
assert_contains "local setup uses copy-safe clone placeholder" "$LOCAL_SETUP" 'git clone https://github\.com/YOUR-ORG/YOUR-REPO\.git'
assert_contains "local setup uses copy-safe cd placeholder" "$LOCAL_SETUP" 'cd YOUR-REPO'
assert_not_contains "local setup has no angle-bracket clone command" "$LOCAL_SETUP" 'git clone <your-repo>'
assert_not_contains "local setup has no angle-bracket cd command" "$LOCAL_SETUP" 'cd <your-repo>'

assert_contains "fixture declares version 2" "$CONFIG" '^version:[[:space:]]+2$'
assert_contains "fixture declares monorepo layout" "$CONFIG" '^layout:[[:space:]]+monorepo$'
assert_contains "fixture declares backend component" "$CONFIG" '^[[:space:]]+- id:[[:space:]]+backend$'
assert_contains "fixture declares frontend component" "$CONFIG" '^[[:space:]]+- id:[[:space:]]+frontend$'
assert_contains "fixture includes Go manifest" "$FIXTURE/src/backend/go.mod" '^module[[:space:]]+example\.com/template-ai-native-fixture/backend$'
assert_contains "fixture includes Node manifest" "$FIXTURE/src/frontend/package.json" '"name"[[:space:]]*:[[:space:]]*"template-ai-native-fixture-frontend"'
assert_contains "fixture includes Go source" "$BACKEND_SOURCE" '^func Greeting\(\) string'
assert_contains "fixture includes Go unit test" "$BACKEND_TEST" '^func TestGreeting\(t \*testing\.T\)'
assert_contains "fixture includes Node source" "$FRONTEND_SOURCE" '^export const applicationName ='
assert_contains "fixture includes Node unit test" "$FRONTEND_TEST" 'describe\("consumer fixture"'

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

integration_output="$(cd "$FIXTURE/src/frontend" && \
  sh "$NODE_CATEGORY_HELPER" integration)"
assert_eq "fixture skips absent Node integration category" "$integration_output" \
  "[skip] no Node.js integration tests found under tests/integration"

e2e_output="$(cd "$FIXTURE/src/frontend" && sh "$NODE_CATEGORY_HELPER" e2e)"
assert_eq "fixture skips absent Node e2e category" "$e2e_output" \
  "[skip] no Node.js e2e tests found under tests/e2e"

report
