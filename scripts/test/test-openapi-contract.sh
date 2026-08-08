#!/usr/bin/env sh
# Contract checks for the stack-agnostic OpenAPI example.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

OPENAPI="$ROOT/docs/api/openapi.yaml"

assert_file() {
  label="$1"; file="$2"
  if [ -f "$file" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing file: %s\n' "$label" "$file" >&2
  fi
}

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_file "OpenAPI skeleton exists" "$OPENAPI"
assert_contains "OpenAPI version is declared" "$OPENAPI" '^openapi: 3\.0\.3$'
assert_contains "global security declaration exists" "$OPENAPI" '^security:$'
assert_contains "global bearer authentication is required" "$OPENAPI" '^  - bearerAuth: \[\]$'
assert_contains "health path exists" "$OPENAPI" '^  /health:$'
assert_contains "health GET operation exists" "$OPENAPI" '^    get:$'
assert_contains "health probe is unauthenticated" "$OPENAPI" '^      security: \[\]$'
assert_contains "health success response exists" "$OPENAPI" "^        '200':$"
assert_contains "health failure response exists" "$OPENAPI" "^        '503':$"
assert_contains "health schema exists" "$OPENAPI" '^    Health:$'
assert_contains "health schema has status" "$OPENAPI" '^        status:$'
assert_contains "health guidance avoids secrets" "$OPENAPI" 'do not expose secrets'
assert_contains "API index documents health/auth examples" "$ROOT/docs/README.md" 'OpenAPI skeleton with health/auth examples'

report
