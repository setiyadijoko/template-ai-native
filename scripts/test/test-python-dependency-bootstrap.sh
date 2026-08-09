#!/usr/bin/env sh
# Behavior contracts for Python consumer dependency bootstrap.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

HELPER="$ROOT/scripts/setup-python-deps.sh"
TOOLS="$ROOT/scripts/python-ci-tools.txt"
MAKEFILE="$ROOT/Makefile"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-python-deps.XXXXXX")"
PROJECT="$WORK/project"
FAKE_SITE="$WORK/fake-site"
PIP_LOG="$WORK/pip.log"
REAL_PYTHON="$(command -v python3)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

mkdir -p "$WORK/bin" "$PROJECT" "$FAKE_SITE"

cat > "$WORK/bin/python-fixture" <<'EOF'
#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "-m" ] && [ "${2:-}" = "pip" ] && [ "${3:-}" = "install" ]; then
  shift 3
  printf '%s\n' "$*" >> "$PIP_LOG"
  if [ "${PIP_FAIL:-0}" = "1" ]; then
    exit "${PIP_FAIL_CODE:-23}"
  fi
  case " $* " in
    *" -e "*"[dev]"*)
      if [ "${FAKE_PROJECT_PROVIDES_TOOLS:-0}" = "1" ]; then
        for module in ruff mypy pytest pytest_cov build; do
          : > "$FAKE_SITE/$module.py"
        done
      fi
      ;;
  esac
  exit 0
fi

# The helper uses one -c call for importlib module availability checks. Keep
# test results independent of packages installed on the developer machine.
if [ "${1:-}" = "-c" ]; then
  module="${3:-}"
  [ -f "$FAKE_SITE/$module.py" ]
  exit
fi

exec "$REAL_PYTHON" "$@"
EOF
chmod +x "$WORK/bin/python-fixture"

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

assert_file_contains "make setup routes Python through dependency helper" \
  "$MAKEFILE" 'if \[ "[$][(]STACK[)]" = "python" \]; then.*setup-python-deps\.sh'

reset_project() {
  rm -rf "$PROJECT" "$FAKE_SITE"
  mkdir -p "$PROJECT" "$FAKE_SITE"
  : > "$PIP_LOG"
}

run_helper() {
  set +e
  RUN_OUTPUT="$(
    cd "$PROJECT" &&
      PYTHON_BIN="$WORK/bin/python-fixture" \
      REAL_PYTHON="$REAL_PYTHON" \
      PIP_LOG="$PIP_LOG" \
      FAKE_SITE="$FAKE_SITE" \
      FAKE_PROJECT_PROVIDES_TOOLS="${FAKE_PROJECT_PROVIDES_TOOLS:-0}" \
      PIP_FAIL="${PIP_FAIL:-0}" \
      PIP_FAIL_CODE="${PIP_FAIL_CODE:-23}" \
      sh "$HELPER" 2>&1
  )"
  RUN_STATUS=$?
  set -e
}

if [ -x "$HELPER" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
  printf 'FAIL Python dependency helper is executable\n' >&2
fi

if [ -f "$TOOLS" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
  printf 'FAIL Python fallback tool manifest exists\n' >&2
fi

# PEP 621 dev dependencies are consumer-owned and must prevent fallback tools
# from overriding compatible versions selected by the consumer.
reset_project
cat > "$PROJECT/pyproject.toml" <<'EOF'
[project]
name = "fixture-with-dev"
version = "0.1.0"
dependencies = ["fastapi"]

[project.optional-dependencies]
dev = ["ruff", "mypy", "pytest", "pytest-cov", "build"]
EOF
FAKE_PROJECT_PROVIDES_TOOLS=1 run_helper
assert_eq "pyproject dev status" "$RUN_STATUS" "0"
assert_eq "pyproject dev install" "$(cat "$PIP_LOG")" "-e .[dev]"

# A project without a dev extra still installs itself before exact fallback CI
# tools are supplied.
reset_project
cat > "$PROJECT/pyproject.toml" <<'EOF'
[project]
name = "fixture-without-dev"
version = "0.1.0"
dependencies = ["fastapi"]
EOF
FAKE_PROJECT_PROVIDES_TOOLS=0 run_helper
assert_eq "pyproject fallback status" "$RUN_STATUS" "0"
assert_eq "pyproject fallback install count" "$(wc -l < "$PIP_LOG" | tr -d ' ')" "6"
assert_eq "pyproject installs project first" "$(sed -n '1p' "$PIP_LOG")" "-e ."
assert_file_contains "ruff fallback pin" "$PIP_LOG" '^ruff==0\.15\.22$'
assert_file_contains "mypy fallback pin" "$PIP_LOG" '^mypy==2\.3\.0$'
assert_file_contains "pytest fallback pin" "$PIP_LOG" '^pytest==9\.1\.1$'
assert_file_contains "pytest-cov fallback pin" "$PIP_LOG" '^pytest-cov==7\.1\.0$'
assert_file_contains "build fallback pin" "$PIP_LOG" '^build==1\.5\.0$'

# Direct src/ manifests remain aligned with the detector boundary.
reset_project
mkdir -p "$PROJECT/src"
cat > "$PROJECT/src/pyproject.toml" <<'EOF'
[project]
name = "fixture-under-src"
version = "0.1.0"

[project.optional-dependencies]
dev = ["pytest"]
EOF
FAKE_PROJECT_PROVIDES_TOOLS=1 run_helper
assert_eq "src pyproject status" "$RUN_STATUS" "0"
assert_eq "src pyproject install" "$(cat "$PIP_LOG")" "-e src[dev]"

# Requirements projects install runtime before development dependencies.
reset_project
printf '%s\n' 'fastapi==1.0.0' > "$PROJECT/requirements.txt"
printf '%s\n' 'pytest==9.1.1' > "$PROJECT/requirements-dev.txt"
run_helper
assert_eq "requirements status" "$RUN_STATUS" "0"
assert_eq "requirements runtime first" "$(sed -n '1p' "$PIP_LOG")" "-r ./requirements.txt"
assert_eq "requirements development second" "$(sed -n '2p' "$PIP_LOG")" "-r ./requirements-dev.txt"

# Legacy setup.py projects remain pip-installable without a new package manager.
reset_project
printf '%s\n' 'from setuptools import setup; setup()' > "$PROJECT/setup.py"
run_helper
assert_eq "setup.py status" "$RUN_STATUS" "0"
assert_eq "setup.py installs project first" "$(sed -n '1p' "$PIP_LOG")" "-e ."

# Unsupported, missing, and ambiguous boundaries fail before a misleading
# successful workflow can be reported.
reset_project
printf '%s\n' '[[source]]' > "$PROJECT/Pipfile"
run_helper
assert_eq "Pipfile-only status" "$RUN_STATUS" "65"
assert_text_contains "Pipfile-only guidance" "$RUN_OUTPUT" 'Pipfile-only dependency bootstrap is not supported'

reset_project
printf '%s\n' '[project]' > "$PROJECT/pyproject.toml"
mkdir -p "$PROJECT/src"
printf '%s\n' 'fastapi' > "$PROJECT/src/requirements.txt"
run_helper
assert_eq "ambiguous boundary status" "$RUN_STATUS" "65"
assert_text_contains "ambiguous boundary guidance" "$RUN_OUTPUT" 'both the current directory and src/'

reset_project
run_helper
assert_eq "missing manifest status" "$RUN_STATUS" "65"
assert_text_contains "missing manifest guidance" "$RUN_OUTPUT" 'No supported Python dependency manifest found'

# A real installer failure is authoritative; the helper must not hide it with
# another dependency format or fallback path.
reset_project
cat > "$PROJECT/pyproject.toml" <<'EOF'
[project]
name = "fixture-pip-failure"
version = "0.1.0"
EOF
PIP_FAIL=1 PIP_FAIL_CODE=23 run_helper
assert_eq "pip failure propagates" "$RUN_STATUS" "23"
assert_eq "pip failure stops after first install" "$(wc -l < "$PIP_LOG" | tr -d ' ')" "1"

report
