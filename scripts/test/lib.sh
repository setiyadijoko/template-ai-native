# Minimal POSIX test helpers. No framework dependency.
PASS=0
FAIL=0

# assert_eq <label> <actual> <expected>
assert_eq() {
  label="$1"; actual="$2"; expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$label" "$expected" "$actual" >&2
  fi
}

# assert_exit <label> <expected_code> <command...>
# Runs the command with set -e suspended so a non-zero (expected) exit does
# not abort the test runner.
assert_exit() {
  label="$1"; expected="$2"; shift 2
  set +e
  "$@" >/dev/null 2>&1
  actual=$?
  set -e
  assert_eq "$label (exit)" "$actual" "$expected"
}

report() {
  printf 'passed=%d failed=%d\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
