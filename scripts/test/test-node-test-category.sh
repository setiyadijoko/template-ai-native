#!/usr/bin/env sh
# Behavior contracts for optional Node.js integration and end-to-end tests.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

HELPER="$ROOT/scripts/run-node-test-category.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-node-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

if [ -x "$HELPER" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL Node category helper is executable\n' >&2
fi

set +e
missing_output="$(cd "$WORK" && sh "$HELPER" integration 2>&1)"
missing_status=$?
set -e
assert_eq "missing optional category status" "$missing_status" "0"
assert_eq "missing optional category message" "$missing_output" \
  "[skip] no Node.js integration tests found under tests/integration"

mkdir -p "$WORK/tests/e2e"
set +e
empty_output="$(cd "$WORK" && sh "$HELPER" e2e 2>&1)"
empty_status=$?
set -e
assert_eq "empty optional category status" "$empty_status" "0"
assert_eq "empty optional category message" "$empty_output" \
  "[skip] no Node.js e2e tests found under tests/e2e"

mkdir -p "$WORK/bin" "$WORK/tests/integration"
cat > "$WORK/bin/npx" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "$*" > "$NPM_ARGS_FILE"
exit "${NPM_EXIT_CODE:-0}"
EOF
chmod +x "$WORK/bin/npx"
printf '%s\n' 'test("real failure", () => {});' \
  > "$WORK/tests/integration/sample.test.ts"

set +e
run_output="$(cd "$WORK" && \
  PATH="$WORK/bin:$PATH" \
  NPM_ARGS_FILE="$WORK/npx.args" \
  NPM_EXIT_CODE=23 \
  sh "$HELPER" integration 2>&1)"
run_status=$?
set -e
assert_eq "existing test delegates to Vitest" "$run_status" "23"
assert_eq "existing test keeps Vitest output" "$run_output" ""
assert_eq "existing test uses local Vitest" "$(cat "$WORK/npx.args")" \
  "--no-install vitest run --dir tests/integration"

set +e
invalid_output="$(cd "$WORK" && sh "$HELPER" unit 2>&1)"
invalid_status=$?
set -e
assert_eq "invalid optional category status" "$invalid_status" "64"
assert_eq "invalid optional category message" "$invalid_output" \
  "usage: run-node-test-category.sh <integration|e2e>"

report
