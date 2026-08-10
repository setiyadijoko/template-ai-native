#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-python-project-dir.sh"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-python-build.XXXXXX")" && pwd)"
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

BUILD_HELPER="$ROOT/scripts/run-python-build.sh"
BUILD_LOG="$WORK/build.log"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/python-build-fixture" <<'EOF'
#!/usr/bin/env sh
set -eu
printf 'cwd=%s args=%s\n' "$PWD" "$*" > "$BUILD_LOG"
mkdir -p dist
: > dist/fixture.whl
EOF
chmod +x "$WORK/bin/python-build-fixture"

run_build() {
  python_bin="$1"
  set +e
  RUN_OUTPUT="$({
    cd "$PROJECT" &&
      BUILD_LOG="$BUILD_LOG" PYTHON_BIN="$python_bin" sh "$BUILD_HELPER"
  } 2>&1)"
  RUN_STATUS=$?
  set -e
}

assert_file_contains() {
  label="$1"
  file="$2"
  pattern="$3"
  if [ -f "$file" ] && grep -Eq -- "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_file_exists() {
  label="$1"
  file="$2"
  if [ -f "$file" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file: %s\n' "$label" "$file" >&2
  fi
}

reset_project
mkdir -p "$PROJECT/.venv/bin"
cp "$WORK/bin/python-build-fixture" "$PROJECT/.venv/bin/python"
: > "$PROJECT/pyproject.toml"
run_build '.venv/bin/python'
assert_eq "root build status" "$RUN_STATUS" "0"
assert_file_contains "root build cwd" "$BUILD_LOG" \
  "^cwd=$PROJECT args=-m build$"
assert_file_exists "root build output" "$PROJECT/dist/fixture.whl"

reset_project
mkdir -p "$PROJECT/src"
: > "$PROJECT/src/setup.py"
run_build "$WORK/bin/python-build-fixture"
assert_eq "src build status" "$RUN_STATUS" "0"
assert_file_contains "src build cwd" "$BUILD_LOG" \
  "^cwd=$PROJECT/src args=-m build$"
assert_file_exists "src build output" "$PROJECT/src/dist/fixture.whl"

reset_project
: > "$PROJECT/requirements.txt"
run_build "$WORK/bin/python-build-fixture"
assert_eq "requirements-only build status" "$RUN_STATUS" "65"
assert_text_contains "requirements-only build guidance" "$RUN_OUTPUT" \
  'requires pyproject.toml or setup.py'

reset_project
: > "$PROJECT/Pipfile"
run_build "$WORK/bin/python-build-fixture"
assert_eq "Pipfile-only build status" "$RUN_STATUS" "65"
assert_text_contains "Pipfile-only build guidance" "$RUN_OUTPUT" \
  'requires pyproject.toml or setup.py'

report
