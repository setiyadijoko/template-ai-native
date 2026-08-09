#!/usr/bin/env sh
# Run an optional Node.js test category only when matching Vitest files exist.
set -eu

usage() {
  printf '%s\n' 'usage: run-node-test-category.sh <integration|e2e>' >&2
}

[ "$#" -eq 1 ] || { usage; exit 64; }
CATEGORY="$1"
case "$CATEGORY" in
  integration|e2e) ;;
  *) usage; exit 64 ;;
esac

TEST_DIR="tests/$CATEGORY"
FIRST_TEST=''
if [ -d "$TEST_DIR" ]; then
  FIRST_TEST="$(find "$TEST_DIR" -type f \
    \( -name '*.test.*' -o -name '*.spec.*' \) -print -quit)"
fi

if [ -z "$FIRST_TEST" ]; then
  printf '[skip] no Node.js %s tests found under %s\n' "$CATEGORY" "$TEST_DIR"
  exit 0
fi

exec npx --no-install vitest run --dir "$TEST_DIR"
