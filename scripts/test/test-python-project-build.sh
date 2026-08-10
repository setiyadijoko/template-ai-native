#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-python-project-dir.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-python-build.XXXXXX")"
PROJECT="$WORK/project"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

reset_project() {
  rm -rf "$PROJECT"
  mkdir -p "$PROJECT"
}

run_resolver() {
  set +e
  RUN_OUTPUT="$(cd "$PROJECT" && sh "$RESOLVER" 2>&1)"
  RUN_STATUS=$?
  set -e
}

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

reset_project
: > "$PROJECT/pyproject.toml"
run_resolver
assert_eq "root project status" "$RUN_STATUS" "0"
assert_eq "root project directory" "$RUN_OUTPUT" "."

reset_project
mkdir -p "$PROJECT/src"
: > "$PROJECT/src/requirements-dev.txt"
run_resolver
assert_eq "src project status" "$RUN_STATUS" "0"
assert_eq "src project directory" "$RUN_OUTPUT" "src"

reset_project
: > "$PROJECT/setup.py"
mkdir -p "$PROJECT/src"
: > "$PROJECT/src/requirements.txt"
run_resolver
assert_eq "ambiguous project status" "$RUN_STATUS" "65"
assert_text_contains "ambiguous project guidance" "$RUN_OUTPUT" \
  'both the current directory and src/'

reset_project
run_resolver
assert_eq "missing project status" "$RUN_STATUS" "65"
assert_text_contains "missing project guidance" "$RUN_OUTPUT" \
  'No supported Python dependency manifest found'

report
