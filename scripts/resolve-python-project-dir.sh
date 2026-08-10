#!/usr/bin/env sh
set -eu

USAGE_ERROR=65

has_manifest() {
  directory="$1"
  [ -f "$directory/pyproject.toml" ] \
    || [ -f "$directory/setup.py" ] \
    || [ -f "$directory/requirements.txt" ] \
    || [ -f "$directory/requirements-dev.txt" ] \
    || [ -f "$directory/Pipfile" ]
}

root_has=false
src_has=false
has_manifest . && root_has=true
has_manifest src && src_has=true

if [ "$root_has" = true ] && [ "$src_has" = true ]; then
  printf '%s\n' \
    'Python dependency manifests exist in both the current directory and src/; keep one project boundary or use the explicit monorepo contract.' >&2
  exit "$USAGE_ERROR"
fi

if [ "$root_has" = true ]; then
  printf '%s\n' '.'
elif [ "$src_has" = true ]; then
  printf '%s\n' 'src'
else
  printf '%s\n' \
    'No supported Python dependency manifest found in the current directory or src/.' >&2
  exit "$USAGE_ERROR"
fi
