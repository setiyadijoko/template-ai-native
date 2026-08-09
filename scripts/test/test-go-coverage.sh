#!/usr/bin/env sh
# Contract tests for the Go coverage threshold helper.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

HELPER="$ROOT/scripts/enforce-go-coverage.sh"
PROFILE="$WORK/coverage.out"
GO_BIN="$WORK/bin"
mkdir -p "$GO_BIN"

# Keep the test independent of a Go installation while exercising the helper's
# command boundary and threshold behavior.
cat > "$GO_BIN/go" <<'EOF'
#!/usr/bin/env sh
set -eu

if [ "$#" -ne 3 ] || [ "$1" != "tool" ] || [ "$2" != "cover" ]; then
  printf 'unexpected go invocation\n' >&2
  exit 2
fi
cat "$GO_COVER_OUTPUT"
EOF
chmod +x "$GO_BIN/go"

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

# A missing profile is not a false pass: the helper reports that the gate is
# not measurable and exits successfully, matching the existing CI contract.
set +e
missing_output="$(PATH="$GO_BIN:$PATH" sh "$HELPER" "$PROFILE" 2>&1)"
missing_status=$?
set -e
assert_eq "missing profile status" "$missing_status" "0"
assert_text_contains "missing profile message" "$missing_output" 'not measurable'

printf 'mode: atomic\n' > "$PROFILE"
printf 'total: (statements) 80.0%%\n' > "$WORK/coverage-pass.txt"
set +e
pass_output="$(PATH="$GO_BIN:$PATH" GO_COVER_OUTPUT="$WORK/coverage-pass.txt" sh "$HELPER" "$PROFILE" 2>&1)"
pass_status=$?
set -e
assert_eq "coverage at threshold status" "$pass_status" "0"
assert_text_contains "coverage pass output" "$pass_output" 'Go coverage: 80.0%'

printf 'total: (statements) 79.9%%\n' > "$WORK/coverage-fail.txt"
set +e
fail_output="$(PATH="$GO_BIN:$PATH" GO_COVER_OUTPUT="$WORK/coverage-fail.txt" sh "$HELPER" "$PROFILE" 2>&1)"
fail_status=$?
set -e
assert_eq "coverage below threshold status" "$fail_status" "1"
assert_text_contains "coverage fail output" "$fail_output" 'Go coverage 79.9% < 80%'

report
