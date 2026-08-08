#!/usr/bin/env sh
# Initialize the consumer-facing README identity without changing workflows,
# source code, credentials, or profile controls.
set -eu

usage() {
  cat <<'USAGE'
Usage: scripts/init-project.sh --name NAME [options]

Updates only the project identity block in README.md.

Options:
  --name NAME           Project name (required)
  --description TEXT    One-line project description (optional)
  --stack STACK         auto|node|python|go|java|dotnet|other (default: auto)
  --reconfigure         Explicitly replace an identity generated previously
  --help                Show this help
USAGE
}

die() {
  printf 'init-project: %s\n' "$1" >&2
  exit 1
}

NAME=''
DESCRIPTION=''
STACK='auto'
RECONFIGURE='no'
TICK='`'
NL='
'
CR=$(printf '\rX')
CR=${CR%X}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || die '--name requires a value'
      NAME="$2"
      shift 2
      ;;
    --description)
      [ "$#" -ge 2 ] || die '--description requires a value'
      DESCRIPTION="$2"
      shift 2
      ;;
    --stack)
      [ "$#" -ge 2 ] || die '--stack requires a value'
      STACK="$2"
      shift 2
      ;;
    --reconfigure)
      RECONFIGURE='yes'
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ -n "$NAME" ] || die 'provide --name NAME'

case "$NAME" in
  *'<!--'*|*'-->'*) die '--name cannot contain HTML comment markers' ;;
  *"$NL"*|*"$CR"*) die '--name must be one line' ;;
esac
printf '%s' "$NAME" | grep -Eq '^[[:alnum:]][[:alnum:] ._-]{0,79}$' \
  || die '--name must start with a letter/number and contain only letters, numbers, spaces, dot, underscore, or hyphen'

case "$DESCRIPTION" in
  *'<!--'*|*'-->'*) die '--description cannot contain HTML comment markers' ;;
  *"$NL"*|*"$CR"*) die '--description must be one line' ;;
esac

case "$STACK" in
  auto|node|python|go|java|dotnet|other) ;;
  *) die "unsupported stack '$STACK' (use auto, node, python, go, java, dotnet, or other)" ;;
esac

README='README.md'
START='<!-- template-ai-native:project-identity:start -->'
END='<!-- template-ai-native:project-identity:end -->'
GENERATED='<!-- template-ai-native:project-identity:generated -->'

[ -f "$README" ] || die 'README.md not found; run from the repository root'
[ "$(grep -F -c "$START" "$README")" -eq 1 ] \
  || die 'README.md must contain exactly one project identity start marker'
[ "$(grep -F -c "$END" "$README")" -eq 1 ] \
  || die 'README.md must contain exactly one project identity end marker'

if grep -Fq "$GENERATED" "$README" && [ "$RECONFIGURE" != 'yes' ]; then
  die 'README identity was already generated; rerun with --reconfigure to replace it'
fi

if [ -z "$DESCRIPTION" ]; then
  DESCRIPTION="$NAME application bootstrapped from template-ai-native."
fi

BLOCK_FILE="README.md.init-block.$$"
TEMP_FILE="README.md.init.$$"
trap 'rm -f "$BLOCK_FILE" "$TEMP_FILE"' EXIT HUP INT TERM

printf '%s\n' \
  "$GENERATED" \
  "$START" \
  "# $NAME" \
  '' \
  '![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)' \
  '' \
  "**Status:** Consumer project bootstrapped from ${TICK}template-ai-native${TICK}." \
  '' \
  "$DESCRIPTION" \
  '' \
  "**Stack:** ${TICK}${STACK}${TICK}" \
  "$END" > "$BLOCK_FILE"

awk -v start="$START" -v end="$END" -v block_file="$BLOCK_FILE" '
  $0 == start {
    while ((getline line < block_file) > 0) print line
    close(block_file)
    inside=1
    replaced++
    next
  }
  $0 == end {
    inside=0
    next
  }
  !inside { print }
  END { if (replaced != 1) exit 2 }
' "$README" > "$TEMP_FILE" || die 'could not replace the project identity block'

mv "$TEMP_FILE" "$README"
trap - EXIT HUP INT TERM
rm -f "$BLOCK_FILE"
printf 'Initialized README identity for %s (stack: %s).\n' "$NAME" "$STACK"
