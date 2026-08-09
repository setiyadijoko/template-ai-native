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
  --primary-path PATH   primary application path (defaults to first component)
  --component SPEC      repeatable monorepo component: ID=PATH:STACK
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
COMPONENT_SPECS=''

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
    --component)
      [ "$#" -ge 2 ] || die '--component requires a value'
      COMPONENT_SPECS="${COMPONENT_SPECS}${COMPONENT_SPECS:+$NL}$(printf '%s' "$2" | tr ',' "$NL")"
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

[ "$LAYOUT" = 'monorepo' ] || [ -z "$COMPONENT_SPECS" ] \
  || die '--component requires --layout monorepo'

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

if [ "$LAYOUT" = 'monorepo' ] && [ "$STACK" != 'auto' ]; then
  die '--stack must be auto when --layout monorepo; set each component stack with --component'
fi

if [ "$LAYOUT" = 'monorepo' ] && [ -z "$COMPONENT_SPECS" ] && [ -t 0 ]; then
  printf '%s' 'Components (ID=PATH:STACK, comma-separated): '
  IFS= read -r COMPONENT_LINE || true
  COMPONENT_SPECS="$(printf '%s' "$COMPONENT_LINE" | tr ',' "$NL")"
fi
if [ "$LAYOUT" = 'monorepo' ] && [ -z "$COMPONENT_SPECS" ]; then
  die '--component is required when --layout monorepo is non-interactive'
fi

if [ "$LAYOUT" = 'monorepo' ] && [ -z "$PRIMARY_PATH" ] && [ -n "$COMPONENT_SPECS" ]; then
  FIRST_SPEC="$(printf '%s\n' "$COMPONENT_SPECS" | sed -n '1p')"
  FIRST_VALUE="${FIRST_SPEC#*=}"
  PRIMARY_PATH="${FIRST_VALUE%%:*}"
fi
if [ -z "$PRIMARY_PATH" ]; then
  if [ "$LAYOUT" = 'single' ]; then
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

COMPONENT_ROWS="${TMPDIR:-/tmp}/template-ai-native-components.$$"
COMPONENT_INPUT=''
if [ "$LAYOUT" = 'monorepo' ]; then
  : > "$COMPONENT_ROWS"
  COMPONENT_INPUT="${TMPDIR:-/tmp}/template-ai-native-component-input.$$"
  printf '%s\n' "$COMPONENT_SPECS" > "$COMPONENT_INPUT"
  while IFS= read -r SPEC || [ -n "$SPEC" ]; do
    [ -n "$SPEC" ] || die '--component cannot be empty'
    case "$SPEC" in
      *'<!--'*|*'-->'*|*"$NL"*|*"$CR"*) die '--component must be a single safe value' ;;
      *=*) COMPONENT_ID="${SPEC%%=*}"; COMPONENT_VALUE="${SPEC#*=}" ;;
      *) die '--component must use ID=PATH:STACK' ;;
    esac
    case "$COMPONENT_VALUE" in
      *:*) COMPONENT_PATH="${COMPONENT_VALUE%%:*}"; COMPONENT_STACK="${COMPONENT_VALUE#*:}" ;;
      *) die '--component must use ID=PATH:STACK' ;;
    esac
    printf '%s' "$COMPONENT_ID" | grep -Eq '^[a-z0-9][a-z0-9_-]{0,31}$' \
      || die "invalid component id '$COMPONENT_ID'"
    case "$COMPONENT_PATH" in
      /*|*'..'*|*'<!--'*|*'-->'*) die "invalid component path '$COMPONENT_PATH'" ;;
    esac
    printf '%s' "$COMPONENT_PATH" | grep -Eq '^[[:alnum:]_.//-]+$' \
      || die "invalid component path '$COMPONENT_PATH'"
    [ "$COMPONENT_PATH" != '.' ] || die 'component path must identify a directory'
    case "$COMPONENT_STACK" in
      python|node|go|java|dotnet) ;;
      *) die "unsupported component stack '$COMPONENT_STACK'" ;;
    esac
    printf '%s\t%s\t%s\ttrue\t%s\n' \
      "$COMPONENT_ID" "$COMPONENT_PATH" "$COMPONENT_STACK" "$COMPONENT_ID" \
      >> "$COMPONENT_ROWS"
  done < "$COMPONENT_INPUT"
  rm -f "$COMPONENT_INPUT"
  DUPLICATE_IDS="$(cut -f1 "$COMPONENT_ROWS" | sort | uniq -d)"
  [ -z "$DUPLICATE_IDS" ] || die "duplicate component id '$DUPLICATE_IDS'"
  if ! awk -F '\t' -v primary_path="$PRIMARY_PATH" '$2 == primary_path { found=1 } END { exit !found }' "$COMPONENT_ROWS"; then
    die "primary path '$PRIMARY_PATH' must match one component path"
  fi
fi

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
trap 'rm -f "$BLOCK_FILE" "$TEMP_FILE" "$CONFIG_TEMP" "$COMPONENT_ROWS" "$COMPONENT_INPUT"' EXIT HUP INT TERM

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
if [ "$LAYOUT" = 'monorepo' ]; then
  {
    printf '%s\n' \
      '# Generated by scripts/init-project.sh; keep credentials out of this file.' \
      'version: 2' \
      'layout: monorepo' \
      'primary_stack: auto' \
      "primary_path: $PRIMARY_PATH" \
      'components:'
    while IFS="$(printf '\t')" read -r COMPONENT_ID COMPONENT_PATH COMPONENT_STACK COMPONENT_REQUIRED COMPONENT_ARTIFACT; do
      printf '%s\n' \
        "  - id: $COMPONENT_ID" \
        "    path: $COMPONENT_PATH" \
        "    stack: $COMPONENT_STACK" \
        "    required: $COMPONENT_REQUIRED" \
        "    artifact: $COMPONENT_ARTIFACT"
    done < "$COMPONENT_ROWS"
  } > "$CONFIG_TEMP"
else
  printf '%s\n' \
    '# Generated by scripts/init-project.sh; keep credentials out of this file.' \
    'version: 1' \
    "layout: $LAYOUT" \
    "primary_stack: $STACK" \
    "primary_path: $PRIMARY_PATH" > "$CONFIG_TEMP"
fi

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
