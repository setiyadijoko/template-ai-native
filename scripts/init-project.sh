#!/usr/bin/env sh
# Initialize the consumer-facing README identity and credential-free project
# layout config without changing workflows, source code, or profile controls.
set -eu

usage() {
  cat <<'USAGE'
Usage: scripts/init-project.sh --name NAME [options]

Updates the project identity block in README.md and writes `.template/project.yaml`.

Options:
  --name NAME           Project name (required)
  --description TEXT    One-line project description (optional)
  --stack STACK         auto|node|python|go|java|dotnet|other (default: auto)
  --layout LAYOUT       single|monorepo|undecided (asks when interactive)
  --primary-path PATH   primary application path (required for monorepo)
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
LAYOUT=''
PRIMARY_PATH=''

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
    --layout)
      [ "$#" -ge 2 ] || die '--layout requires a value'
      LAYOUT="$2"
      shift 2
      ;;
    --primary-path)
      [ "$#" -ge 2 ] || die '--primary-path requires a value'
      PRIMARY_PATH="$2"
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

if [ -z "$LAYOUT" ] && [ -t 0 ]; then
  printf '%s' 'Repository layout (single/monorepo/undecided) [undecided]: '
  IFS= read -r LAYOUT || true
fi
[ -n "$LAYOUT" ] || LAYOUT='undecided'

case "$LAYOUT" in
  single|monorepo|undecided) ;;
  *) die "unsupported layout '$LAYOUT' (use single, monorepo, or undecided)" ;;
esac

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

if [ "$LAYOUT" = 'monorepo' ] && [ -z "$PRIMARY_PATH" ] && [ -t 0 ]; then
  printf '%s' 'Primary component path (for example, src/backend): '
  IFS= read -r PRIMARY_PATH || true
fi
if [ -z "$PRIMARY_PATH" ]; then
  if [ "$LAYOUT" = 'monorepo' ]; then
    die '--primary-path is required when --layout monorepo is non-interactive'
  elif [ "$LAYOUT" = 'single' ]; then
    PRIMARY_PATH='src'
  else
    PRIMARY_PATH='.'
  fi
fi

case "$PRIMARY_PATH" in
  /*|*'..'*|*'<!--'*|*'-->'*) die '--primary-path must be a relative safe path' ;;
esac
printf '%s' "$PRIMARY_PATH" | grep -Eq '^[[:alnum:]_.//-]+$' \
  || die '--primary-path contains unsupported characters'
[ "$LAYOUT" != 'monorepo' ] || [ "$PRIMARY_PATH" != '.' ] \
  || die 'monorepo primary path must identify a component directory'

README='README.md'
START='<!-- template-ai-native:project-identity:start -->'
END='<!-- template-ai-native:project-identity:end -->'
GENERATED='<!-- template-ai-native:project-identity:generated -->'
CONFIG_DIR='.template'
CONFIG_FILE="$CONFIG_DIR/project.yaml"

[ -f "$README" ] || die 'README.md not found; run from the repository root'
[ "$(grep -F -c "$START" "$README")" -eq 1 ] \
  || die 'README.md must contain exactly one project identity start marker'
[ "$(grep -F -c "$END" "$README")" -eq 1 ] \
  || die 'README.md must contain exactly one project identity end marker'

if grep -Fq "$GENERATED" "$README" && [ "$RECONFIGURE" != 'yes' ]; then
  die 'README identity was already generated; rerun with --reconfigure to replace it'
fi
if [ -f "$CONFIG_FILE" ] && [ "$RECONFIGURE" != 'yes' ]; then
  die 'project config already exists; rerun with --reconfigure to replace it'
fi

if [ -z "$DESCRIPTION" ]; then
  DESCRIPTION="$NAME application bootstrapped from template-ai-native."
fi

BLOCK_FILE="README.md.init-block.$$"
TEMP_FILE="README.md.init.$$"
CONFIG_TEMP="$CONFIG_FILE.init.$$"
trap 'rm -f "$BLOCK_FILE" "$TEMP_FILE" "$CONFIG_TEMP"' EXIT HUP INT TERM

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

mkdir -p "$CONFIG_DIR"
printf '%s\n' \
  '# Generated by scripts/init-project.sh; keep credentials out of this file.' \
  'version: 1' \
  "layout: $LAYOUT" \
  "primary_stack: $STACK" \
  "primary_path: $PRIMARY_PATH" > "$CONFIG_TEMP"

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
mv "$CONFIG_TEMP" "$CONFIG_FILE"
trap - EXIT HUP INT TERM
rm -f "$BLOCK_FILE"
printf 'Initialized project identity for %s (layout: %s, stack: %s).\n' "$NAME" "$LAYOUT" "$STACK"
