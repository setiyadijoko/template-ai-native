#!/usr/bin/env sh
# Behavior contract for aggregate Python coverage in a consumer repository.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-python-coverage.XXXXXX")"
PYTEST_ARGS="$WORK/pytest.args"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

mkdir -p \
  "$WORK/bin" \
  "$WORK/tests/unit" \
  "$WORK/tests/integration" \
  "$WORK/tests/fixtures/consumer-python/tests/unit"
: > "$WORK/pyproject.toml"
: > "$WORK/tests/unit/test_priority.py"
: > "$WORK/tests/integration/test_priority.py"
: > "$WORK/tests/fixtures/consumer-python/tests/unit/test_runtime_dependency.py"

cat > "$WORK/bin/pytest" <<'EOF'
#!/usr/bin/env sh
set -eu

printf '%s\n' "$*" > "$PYTEST_ARGS"

case " $* " in
  *' --ignore=tests/fixtures '*) ;;
  *) exit 41 ;;
esac
case " $* " in
  *' --import-mode=importlib '*) ;;
  *) exit 42 ;;
esac

exit "${PYTEST_EXIT_CODE:-0}"
EOF
chmod +x "$WORK/bin/pytest"

run_coverage() {
  set +e
  RUN_OUTPUT="$({
    cd "$WORK" &&
      PATH="$WORK/bin:$PATH" \
      PYTEST_ARGS="$PYTEST_ARGS" \
      PYTEST_EXIT_CODE="${PYTEST_EXIT_CODE:-0}" \
      sh -c "$(sh "$ROOT/scripts/stack-tools.sh" coverage)"
  } 2>&1)"
  RUN_STATUS=$?
  set -e
}

run_coverage
assert_eq "coverage excludes template-owned fixtures" "$RUN_STATUS" "0"
assert_eq "coverage keeps aggregate consumer discovery" "$(cat "$PYTEST_ARGS")" \
  "--ignore=tests/fixtures --import-mode=importlib --cov=src --cov-report=xml --cov-report=term --cov-fail-under=80"

PYTEST_EXIT_CODE=23 run_coverage
assert_eq "coverage propagates pytest failure" "$RUN_STATUS" "23"

report
