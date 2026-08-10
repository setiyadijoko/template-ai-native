#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="$HERE/resolve-python-project-dir.sh"
USAGE_ERROR=65
PYTHON_BIN="${PYTHON_BIN:-python}"

project_dir="$(sh "$RESOLVER")"
if [ ! -f "$project_dir/pyproject.toml" ] \
  && [ ! -f "$project_dir/setup.py" ]; then
  printf 'Python package build requires pyproject.toml or setup.py under %s.\n' \
    "$project_dir" >&2
  exit "$USAGE_ERROR"
fi

if ! python_exec="$(command -v "$PYTHON_BIN" 2>/dev/null)"; then
  printf 'Python build executable is unavailable: %s\n' "$PYTHON_BIN" >&2
  exit "$USAGE_ERROR"
fi

case "$python_exec" in
  /*) ;;
  *)
    python_exec="$(cd "$(dirname "$python_exec")" && pwd)/$(basename "$python_exec")"
    ;;
esac

(cd "$project_dir" && "$python_exec" -m build)
