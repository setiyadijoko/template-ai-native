#!/usr/bin/env sh
# Validate the declarative maturity-profile contract without a YAML dependency.
set -eu

CONFIG="${1:-.template/profile.yaml}"

if [ ! -f "$CONFIG" ]; then
  printf 'No profile config found at %s; compatibility mode remains active.\n' "$CONFIG"
  exit 0
fi

die() {
  printf 'profile-config: %s\n' "$1" >&2
  exit 1
}

if grep -q '	' "$CONFIG"; then
  die 'tabs are not allowed; use two-space indentation'
fi

if grep -Eiq '(^|[^[:alnum:]_])(token|secret|password|api[_-]?key|credential|auth)([^[:alnum:]_]|$)' "$CONFIG"; then
  die 'profile config must not contain credentials or secret fields'
fi

NORMALIZED="${TMPDIR:-/tmp}/template-ai-native-profile.$$"
trap 'rm -f "$NORMALIZED"' EXIT HUP INT TERM

if ! awk '
  function fail(message) {
    print message > "/dev/stderr"
    exit 2
  }
  {
    line = $0
    sub(/[[:space:]]+#.*$/, "", line)
    if (line ~ /^[[:space:]]*$/) next
    if (line ~ /^[[:space:]]*#/) next
    if (line ~ /[\t\r]/) fail("invalid tab or carriage return")

    if (line ~ /^[a-z][a-z0-9_]*:[[:space:]]*$/) {
      key = line
      sub(/:.*/, "", key)
      section = key
      print "section|" key "|"
      next
    }

    if (line ~ /^[a-z][a-z0-9_]*:[[:space:]]*[^[:space:]#].*$/) {
      key = line
      sub(/:.*/, "", key)
      value = line
      sub(/^[^:]*:[[:space:]]*/, "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value == "" || value ~ /[|]/) fail("invalid scalar value")
      print "scalar|" key "|" value
      next
    }

    if (line ~ /^  [a-z][a-z0-9_]*:[[:space:]]*[^[:space:]#].*$/) {
      if (section == "") fail("nested key appears before a section")
      key = line
      sub(/^  /, "", key)
      sub(/:.*/, "", key)
      value = line
      sub(/^  [^:]*:[[:space:]]*/, "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value == "" || value ~ /[|]/) fail("invalid nested value")
      print "value|" section "." key "|" value
      next
    }

    fail("unsupported YAML shape")
  }
' "$CONFIG" > "$NORMALIZED"; then
  die 'profile config must use the documented two-level scalar shape'
fi

record_count() {
  awk -F '|' -v kind="$1" -v path="$2" \
    '$1 == kind && $2 == path { count++ } END { print count + 0 }' \
    "$NORMALIZED"
}

record_value() {
  awk -F '|' -v kind="$1" -v path="$2" \
    '$1 == kind && $2 == path { print $3; exit }' "$NORMALIZED"
}

require_once() {
  kind="$1"
  path="$2"
  count="$(record_count "$kind" "$path")"
  [ "$count" -eq 1 ] || die "$path must appear exactly once"
}

require_section() {
  require_once section "$1"
}

require_value() {
  require_once value "$1"
}

require_scalar() {
  require_once scalar "$1"
}

enum_value() {
  path="$1"
  allowed="$2"
  value="$(record_value value "$path")"
  case " $allowed " in
    *" $value "*) ;;
    *) die "$path has unsupported value '$value'" ;;
  esac
}

boolean_value() {
  path="$1"
  value="$(record_value value "$path")"
  case "$value" in
    true|false) ;;
    *) die "$path must be true or false" ;;
  esac
}

require_scalar version
require_scalar profile
for section in project stack ai deployment controls; do
  require_section "$section"
done

VERSION="$(record_value scalar version)"
[ "$VERSION" = '1' ] || die "unsupported version '$VERSION'"

PROFILE="$(record_value scalar profile)"
case "$PROFILE" in
  starter|standard|enterprise) ;;
  *) die "unsupported profile '$PROFILE' (use starter, standard, or enterprise)" ;;
esac

require_value project.type
require_value stack.primary
for path in \
  ai.enabled ai.evaluation ai.semantic_review ai.structural_review \
  deployment.enabled deployment.target \
  controls.secret_scan controls.dependency_review controls.codeql \
  controls.coverage controls.sbom controls.artifact_attestation controls.scorecard; do
  require_value "$path"
done

enum_value project.type 'web-app api worker library data-app integration other'
enum_value stack.primary 'auto node python go java dotnet other'
enum_value ai.semantic_review 'off advisory enabled'
enum_value ai.structural_review 'off advisory enabled'
enum_value deployment.target 'none docker kubernetes cloud self-hosted other'

for path in \
  ai.enabled ai.evaluation deployment.enabled \
  controls.secret_scan controls.dependency_review controls.codeql \
  controls.coverage controls.sbom controls.artifact_attestation controls.scorecard; do
  boolean_value "$path"
done

KNOWN_VALUES='project.type stack.primary ai.enabled ai.evaluation ai.semantic_review ai.structural_review deployment.enabled deployment.target controls.secret_scan controls.dependency_review controls.codeql controls.coverage controls.sbom controls.artifact_attestation controls.scorecard'
while IFS='|' read -r kind path value; do
  case "$kind" in
    section)
      case " project stack ai deployment controls " in
        *" $path "*) ;;
        *) die "unsupported section '$path'" ;;
      esac
      ;;
    scalar)
      case " version profile " in
        *" $path "*) ;;
        *) die "unsupported top-level scalar '$path'" ;;
      esac
      ;;
    value)
      case " $KNOWN_VALUES " in
        *" $path "*) ;;
        *) die "unsupported profile field '$path'" ;;
      esac
      ;;
    *) die 'internal profile parser error' ;;
  esac
done < "$NORMALIZED"

printf 'Profile config valid: %s (profile: %s)\n' "$CONFIG" "$PROFILE"
