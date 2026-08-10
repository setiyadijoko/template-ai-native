#!/usr/bin/env sh
# Install a Python consumer and the CI tools it has not supplied itself.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS_FILE="$HERE/python-ci-tools.txt"
PYTHON_BIN="${PYTHON_BIN:-python}"
USAGE_ERROR=65

RESOLVER="$HERE/resolve-python-project-dir.sh"

if [ ! -x "$RESOLVER" ]; then
  printf 'Python project-directory resolver is unavailable: %s\n' "$RESOLVER" >&2
  exit "$USAGE_ERROR"
fi

project_dir="$(sh "$RESOLVER")"

install_with_pip() {
  "$PYTHON_BIN" -m pip install "$@"
}

if [ -f "$project_dir/pyproject.toml" ]; then
  if has_dev_extra="$("$PYTHON_BIN" - "$project_dir/pyproject.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    document = tomllib.load(handle)

optional = document.get("project", {}).get("optional-dependencies", {})
print("true" if isinstance(optional.get("dev"), list) else "false")
PY
  )"; then
    :
  else
    printf 'Unable to parse Python project metadata: %s/pyproject.toml\n' "$project_dir" >&2
    exit "$USAGE_ERROR"
  fi

  if [ "$has_dev_extra" = true ]; then
    install_with_pip -e "${project_dir}[dev]"
  else
    install_with_pip -e "$project_dir"
  fi
elif [ -f "$project_dir/setup.py" ]; then
  install_with_pip -e "$project_dir"
elif [ -f "$project_dir/requirements.txt" ] \
  || [ -f "$project_dir/requirements-dev.txt" ]; then
  if [ -f "$project_dir/requirements.txt" ]; then
    install_with_pip -r "$project_dir/requirements.txt"
  fi
  if [ -f "$project_dir/requirements-dev.txt" ]; then
    install_with_pip -r "$project_dir/requirements-dev.txt"
  fi
elif [ -f "$project_dir/Pipfile" ]; then
  printf '%s\n' \
    'Pipfile-only dependency bootstrap is not supported; commit a reviewed pyproject.toml or requirements contract, or add governed Pipenv support.' >&2
  exit "$USAGE_ERROR"
fi

if [ ! -f "$TOOLS_FILE" ]; then
  printf 'Python fallback tool manifest not found: %s\n' "$TOOLS_FILE" >&2
  exit "$USAGE_ERROR"
fi

while IFS='|' read -r requirement module; do
  [ -n "$requirement" ] || continue
  case "$requirement" in
    [A-Za-z0-9_.-]*'=='[0-9]*) ;;
    *)
      printf 'Invalid Python fallback requirement: %s\n' "$requirement" >&2
      exit "$USAGE_ERROR"
      ;;
  esac
  case "$module" in
    ''|*[!A-Za-z0-9_]*)
      printf 'Invalid Python fallback module: %s\n' "$module" >&2
      exit "$USAGE_ERROR"
      ;;
  esac

  if "$PYTHON_BIN" -c \
    'import importlib.util, sys; raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)' \
    "$module"; then
    continue
  fi
  install_with_pip "$requirement"
done < "$TOOLS_FILE"
