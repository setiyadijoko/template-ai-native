#!/usr/bin/env sh
# Resolve an explicit version-2 monorepo component list.
# Prints validated component rows as TSV or JSON; never discovers manifests.
set -eu

usage() {
  printf '%s\n' \
    'Usage: scripts/resolve-components.sh --layout [CONFIG]' \
    '       scripts/resolve-components.sh --validate [CONFIG]' \
    '       scripts/resolve-components.sh --tsv [CONFIG]' \
    '       scripts/resolve-components.sh --json [CONFIG]' >&2
}

die() {
  printf 'resolve-components: %s\n' "$1" >&2
  exit 1
}

MODE="${1:-}"
CONFIG="${2:-.template/project.yaml}"
case "$MODE" in
  --layout|--validate|--tsv|--json) ;;
  *) usage; exit 64 ;;
esac

if [ "$MODE" = '--layout' ]; then
  if [ ! -f "$CONFIG" ]; then
    printf '%s\n' 'unknown'
    exit 0
  fi
  awk -F ':[[:space:]]*' '$1 == "layout" { print $2; found=1; exit } END { if (!found) print "unknown" }' "$CONFIG"
  exit 0
fi

[ -f "$CONFIG" ] || die "config not found: $CONFIG"

VERSION="$(awk -F ':[[:space:]]*' '$1 == "version" { print $2; exit }' "$CONFIG")"
LAYOUT="$(awk -F ':[[:space:]]*' '$1 == "layout" { print $2; exit }' "$CONFIG")"
[ "$VERSION" = '2' ] || die 'component resolution requires version: 2'
[ "$LAYOUT" = 'monorepo' ] || die 'component resolution requires layout: monorepo'

ROWS="${TMPDIR:-/tmp}/template-ai-native-components.$$"
trap 'rm -f "$ROWS"' EXIT HUP INT TERM

awk '
function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}
function fail(message) {
  print "resolve-components: " message > "/dev/stderr"
  exit 1
}
function emit(    key) {
  if (!active) return
  if (id == "" || path == "" || stack == "" || required == "" || artifact == "") {
    fail("component is missing one of id, path, stack, required, or artifact")
  }
  if (id !~ /^[a-z0-9][a-z0-9_-]*$/ || length(id) > 32) fail("invalid component id: " id)
  if (path !~ /^[A-Za-z0-9_.\/-]+$/ || path ~ /\.\./ || path ~ /^\// || path == ".") fail("invalid component path: " path)
  if (stack !~ /^(python|node|go|java|dotnet)$/) fail("unsupported component stack: " stack)
  if (required != "true" && required != "false") fail("component required must be true or false: " id)
  if (artifact !~ /^[a-z0-9][a-z0-9_-]*$/ || length(artifact) > 48) fail("invalid artifact name: " artifact)
  if (ids[id]++) fail("duplicate component id: " id)
  if (artifacts[artifact]++) fail("duplicate artifact name: " artifact)
  count++
  if (count > 32) fail("component count exceeds 32")
  print id "\t" path "\t" stack "\t" required "\t" artifact
  active=0
  id=path=stack=required=artifact=""
  delete fields
}

$0 ~ /^[[:space:]]*#/ { next }
$0 ~ /^components:[[:space:]]*$/ {
  if (components_seen++) fail("components must appear exactly once")
  inside=1
  next
}
inside && $0 !~ /^[[:space:]]/ {
  emit()
  inside=0
}
inside && $0 ~ /^[[:space:]]*$/ { next }
inside && $0 ~ /^[[:space:]]+-[[:space:]]+id:[[:space:]]*/ {
  emit()
  line=$0
  sub(/^[[:space:]]+-[[:space:]]+id:[[:space:]]*/, "", line)
  id=trim(line)
  fields["id"]++
  active=1
  next
}
inside && $0 ~ /^[[:space:]]+-[[:space:]]*/ { fail("each component must start with - id:") }
inside && $0 ~ /^[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*:[[:space:]]*/ {
  line=$0
  sub(/^[[:space:]]+/, "", line)
  key=line
  sub(/:.*/, "", key)
  value=line
  sub(/^[^:]+:[[:space:]]*/, "", value)
  value=trim(value)
  if (key != "id" && key != "path" && key != "stack" && key != "required" && key != "artifact") fail("unsupported component field: " key)
  if (!active) fail("component field appears before - id:")
  if (fields[key]++) fail("duplicate component field: " key)
  if (key == "id") id=value
  else if (key == "path") path=value
  else if (key == "stack") stack=value
  else if (key == "required") required=value
  else artifact=value
  next
}
inside { fail("unsupported component syntax") }
END {
  emit()
  if (!components_seen) fail("components must appear exactly once")
  if (count == 0) fail("at least one component is required")
}
' "$CONFIG" > "$ROWS"

case "$MODE" in
  --validate)
    printf 'Component config valid: %s\n' "$CONFIG"
    ;;
  --tsv)
    cat "$ROWS"
    ;;
  --json)
    TAB="$(printf '\t')"
    JSON='['
    COMMA=''
    while IFS="$TAB" read -r id path stack required artifact; do
      [ -n "$id" ] || continue
      JSON="${JSON}${COMMA}{\"id\":\"${id}\",\"path\":\"${path}\",\"stack\":\"${stack}\",\"required\":${required},\"artifact\":\"${artifact}\"}"
      COMMA=','
    done < "$ROWS"
    printf '%s]\n' "$JSON"
    ;;
esac
