#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILE_CONFIG="${1:-.template/profile.yaml}"
CONTROL_MAP="${2:-.template/profile-controls.yaml}"
PROJECT_CONFIG="${3:-.template/project.yaml}"
CONTROLS='secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard ai_evaluation semantic_review structural_review production_governance'
REPORT="$(mktemp "${TMPDIR:-/tmp}/template-ai-native-profile-shadow.XXXXXX")"
ERROR="${REPORT}.err"
trap 'rm -f "$REPORT" "$ERROR"' EXIT HUP INT TERM

die() {
  printf 'profile-shadow: %s\n' "$1" >&2
  exit 1
}

report_value() {
  control="$1"
  field="$2"
  key="control.$control.$field"
  awk -F= -v key="$key" '
    $1 == key {
      print substr($0, length(key) + 2)
      exit
    }
  ' "$REPORT"
}

present_diagnostics() {
  sed 's/^::warning title=Profile policy mismatch::/::warning title=Profile shadow policy mismatch::/' \
    "$ERROR" >&2
}

if ! sh "$HERE/resolve-profile-policy.sh" "$PROFILE_CONFIG" "$CONTROL_MAP" \
  "$PROJECT_CONFIG" > "$REPORT" 2> "$ERROR"; then
  printf 'profile-shadow: effective policy resolution failed\n' >&2
  present_diagnostics
  exit 1
fi
present_diagnostics

MODE="$(awk -F= '$1 == "mode" { print $2; exit }' "$REPORT")"
PROFILE="$(awk -F= '$1 == "profile" { print $2; exit }' "$REPORT")"
STATUS="$(awk -F= '$1 == "status" { print $2; exit }' "$REPORT")"

case "$MODE" in
  compatibility)
    [ "$PROFILE" = none ] || die 'invalid compatibility profile in policy report'
    [ "$STATUS" = current-baseline ] || die 'invalid compatibility status in policy report'
    printf 'mode=compatibility\nprofile=none\nstatus=current-baseline\n'
    for control in $CONTROLS; do
      enabled="$(report_value "$control" enabled)"
      [ "$enabled" = current-baseline ] \
        || die "invalid compatibility decision for $control"
      printf 'control.%s.decision=current-baseline\n' "$control"
    done
    ;;
  profile)
    case "$PROFILE" in starter|standard|enterprise) ;; *) die 'invalid profile in policy report' ;; esac
    case "$STATUS" in aligned|warning) ;; *) die 'invalid profile status in policy report' ;; esac
    printf 'mode=shadow\nprofile=%s\nstatus=%s\n' "$PROFILE" "$STATUS"
    for control in $CONTROLS; do
      declared="$(report_value "$control" declared)"
      default="$(report_value "$control" default)"
      enabled="$(report_value "$control" enabled)"
      class="$(report_value "$control" class)"
      alignment="$(report_value "$control" alignment)"
      [ -n "$declared" ] || die "missing declared value for $control"
      [ -n "$default" ] || die "missing default value for $control"
      [ -n "$class" ] || die "missing class value for $control"
      case "$enabled" in
        true) decision=would-run ;;
        false) decision=would-skip ;;
        *) die "invalid enabled value for $control" ;;
      esac
      case "$alignment" in
        aligned|stronger-than-default|policy-mismatch) ;;
        *) die "invalid alignment value for $control" ;;
      esac
      printf 'control.%s.declared=%s\ncontrol.%s.default=%s\ncontrol.%s.decision=%s\ncontrol.%s.class=%s\ncontrol.%s.alignment=%s\n' \
        "$control" "$declared" "$control" "$default" "$control" "$decision" \
        "$control" "$class" "$control" "$alignment"
    done
    ;;
  *) die 'invalid mode in policy report' ;;
esac
