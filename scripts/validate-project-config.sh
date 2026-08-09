#!/usr/bin/env sh
# Validate the small, credential-free project layout contract.
set -eu

CONFIG="${1:-.template/project.yaml}"

if [ ! -f "$CONFIG" ]; then
  printf 'No project config found at %s; compatibility mode remains active.\n' "$CONFIG"
  exit 0
fi

die() {
  printf 'project-config: %s\n' "$1" >&2
  exit 1
}

count_key() {
  grep -Ec "^[[:space:]]*$1:[[:space:]]*[^#].*$" "$CONFIG" || true
}

value_for() {
  awk -F ':[[:space:]]*' -v key="$1" '$1 == key { print $2; exit }' "$CONFIG"
}

[ "$(count_key version)" -eq 1 ] || die 'version must appear exactly once'
[ "$(count_key layout)" -eq 1 ] || die 'layout must appear exactly once'
[ "$(count_key primary_stack)" -eq 1 ] || die 'primary_stack must appear exactly once'
[ "$(count_key primary_path)" -eq 1 ] || die 'primary_path must appear exactly once'

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(value_for version)"
LAYOUT="$(value_for layout)"
STACK="$(value_for primary_stack)"
PATH_VALUE="$(value_for primary_path)"

case "$VERSION" in
  1|2) ;;
  *) die "unsupported version '$VERSION'" ;;
esac

case "$LAYOUT" in
  single|monorepo|undecided) ;;
  *) die "unsupported layout '$LAYOUT' (use single, monorepo, or undecided)" ;;
esac

case "$STACK" in
  auto|node|python|go|java|dotnet|other) ;;
  *) die "unsupported primary_stack '$STACK'" ;;
esac

if [ "$VERSION" = '2' ]; then
  [ "$LAYOUT" = 'monorepo' ] || die 'version 2 requires layout monorepo'
  [ "$STACK" = 'auto' ] || die 'version 2 requires primary_stack auto'
fi

[ -n "$PATH_VALUE" ] || die 'primary_path cannot be empty'
case "$PATH_VALUE" in
  /*|*'..'*|*'<!--'*|*'-->'*) die 'primary_path must be a relative safe path' ;;
esac
printf '%s' "$PATH_VALUE" | grep -Eq '^[[:alnum:]_.//-]+$' \
  || die 'primary_path contains unsupported characters'

if [ "$LAYOUT" = 'monorepo' ] && [ "$PATH_VALUE" = '.' ]; then
  die 'monorepo primary_path must identify a component directory'
fi

if grep -Eiq '(^|[^[:alnum:]_])(token|secret|password|api[_-]?key)([^[:alnum:]_]|$)' "$CONFIG"; then
  die 'project config must not contain credentials or secret fields'
fi

if [ "$VERSION" = '2' ]; then
  sh "$HERE/resolve-components.sh" --validate "$CONFIG"
fi

printf 'Project config valid: %s\n' "$CONFIG"
