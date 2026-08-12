#!/usr/bin/env sh
set -eu

POLICY_REPORT=''
if [ "${1:-}" = '--policy-report' ]; then
  [ "$#" -ge 2 ] || { printf '%s\n' 'profile-execution-plan: --policy-report requires a file' >&2; exit 1; }
  POLICY_REPORT="$2"
  shift 2
fi
[ "$#" -le 3 ] || { printf '%s\n' 'profile-execution-plan: too many arguments' >&2; exit 1; }
PROFILE_CONFIG="${1:-.template/profile.yaml}"
CONTROL_MAP="${2:-.template/profile-controls.yaml}"
PROJECT_CONFIG="${3:-.template/project.yaml}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BOUNDARIES='quality_unit test_coverage monorepo_ci secret_scan dependency_review codeql ai_evaluation sbom artifact_attestation scorecard semantic_review structural_review production_governance'
CONTROLS='secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard ai_evaluation semantic_review structural_review production_governance'
CONTROL_FIELDS='declared default enabled class policy_required pr_required alignment'

die() {
  printf 'profile-execution-plan: %s\n' "$1" >&2
  exit 1
}

emit_boundary() {
  boundary="$1"; decision="$2"; required="$3"; reason="$4"
  printf 'boundary.%s.decision=%s\nboundary.%s.required=%s\nboundary.%s.reason=%s\n' \
    "$boundary" "$decision" "$boundary" "$required" "$boundary" "$reason"
}

control_value() {
  control="$1"; field="$2"
  awk -F '=' -v key="control.$control.$field" '$1 == key { print $2 }' "$REPORT"
}

validate_report() {
  awk -F '=' -v controls="$CONTROLS" -v fields="$CONTROL_FIELDS" '
    function known(list, value) { return index(" " list " ", " " value " ") > 0 }
    function fail() { invalid = 1; exit }
    {
      if (NF != 2 || $1 == "" || $2 == "") fail()
      if (++seen[$1] != 1) fail()
      if ($1 == "mode") { if ($2 != "compatibility" && $2 != "profile") fail(); mode = $2; next }
      if ($1 == "profile") { if ($2 != "none" && $2 != "starter" && $2 != "standard" && $2 != "enterprise") fail(); profile = $2; next }
      if ($1 == "status") { if ($2 != "current-baseline" && $2 != "aligned" && $2 != "warning") fail(); status = $2; next }
      if ($1 !~ /^control\.[a-z_]+\.[a-z_]+$/) fail()
      key = $1
      sub(/^control\./, "", key)
      part_count = split(key, parts, ".")
      if (part_count != 2 || !known(controls, parts[1])) fail()
      if (!known(fields, parts[2])) fail()
      if (parts[2] == "enabled" || parts[2] == "policy_required" || parts[2] == "pr_required") {
        if ($2 != "true" && $2 != "false" && $2 != "current-baseline") fail()
      } else if (parts[2] == "class") {
        if ($2 != "pull-request-blocking" && $2 != "pull-request-advisory" && $2 != "post-merge" && $2 != "scheduled-push" && $2 != "manual-environment") fail()
      } else if (parts[2] == "alignment") {
        if ($2 != "aligned" && $2 != "stronger-than-default" && $2 != "policy-mismatch") fail()
      } else if (parts[2] == "declared" || parts[2] == "default") {
        if ($2 !~ /^(true|false|optional|when-ai-enabled|required-for-ai|off|advisory|enabled|when-deployed|required)$/) fail()
      }
    }
    END {
      if (invalid || seen["mode"] != 1 || seen["profile"] != 1 || seen["status"] != 1) exit 2
      if (mode == "compatibility") {
        if (profile != "none" || status != "current-baseline") exit 2
        control_count = split(controls, control_names, " ")
        for (control_index = 1; control_index <= control_count; control_index++) {
          control = control_names[control_index]
          if (seen["control." control ".enabled"] != 1) exit 2
        }
      } else if (mode == "profile") {
        if (profile == "none" || (status != "aligned" && status != "warning")) exit 2
        control_count = split(controls, control_names, " ")
        field_count = split(fields, field_names, " ")
        for (control_index = 1; control_index <= control_count; control_index++) {
          for (field_index = 1; field_index <= field_count; field_index++) {
            if (seen["control." control_names[control_index] "." field_names[field_index]] != 1) exit 2
          }
        }
      } else exit 2
    }
  ' "$REPORT" || die 'central policy report has malformed, duplicate, or unknown records'

  report_mode="$(awk -F '=' '$1 == "mode" { print $2 }' "$REPORT")"
  case "$report_mode" in
    compatibility)
      [ "$(awk -F '=' '$1 == "profile" { print $2 }' "$REPORT")" = none ] \
        || die 'compatibility policy report has invalid profile'
      [ "$(awk -F '=' '$1 == "status" { print $2 }' "$REPORT")" = current-baseline ] \
        || die 'compatibility policy report has invalid status'
      for control in $CONTROLS; do
        [ "$(awk -F '=' -v key="control.$control.enabled" '$1 == key { print $2 }' "$REPORT")" = current-baseline ] \
          || die "compatibility policy report is missing $control baseline"
      done
      [ "$(wc -l < "$REPORT" | tr -d ' ' )" -eq 14 ] \
        || die 'compatibility policy report has unexpected records'
      ;;
    profile)
      report_profile="$(awk -F '=' '$1 == "profile" { print $2 }' "$REPORT")"
      case "$report_profile" in starter|standard|enterprise) ;; *) die 'policy report has unsupported profile' ;; esac
      [ "$(awk -F '=' '$1 == "status" { print $2 }' "$REPORT")" = aligned ] \
        || die 'policy report status is not aligned'
      for control in $CONTROLS; do
        for field in $CONTROL_FIELDS; do
          value="$(control_value "$control" "$field")"
          [ -n "$value" ] || die "policy report is missing $control.$field"
        done
      done
      [ "$(wc -l < "$REPORT" | tr -d ' ' )" -eq 80 ] \
        || die 'policy report has unexpected records'
      ;;
    *) die 'policy report has unsupported mode' ;;
  esac
}

emit_policy_metadata() {
  boundary="$1"; control="$2"
  enabled="$(control_value "$control" enabled)"
  class="$(control_value "$control" class)"
  case "$enabled:$class" in
    false:*) emit_boundary "$boundary" planned-skip false disabled-by-profile ;;
    true:post-merge) emit_boundary "$boundary" policy-only false post-merge-control ;;
    true:scheduled-push) emit_boundary "$boundary" policy-only false scheduled-control ;;
    true:manual-environment) emit_boundary "$boundary" policy-only false manual-environment-control ;;
    true:pull-request-advisory) emit_boundary "$boundary" policy-only false advisory-policy-only ;;
    *) die "unsupported policy metadata for $control" ;;
  esac
}

emit_pr_control() {
  boundary="$1"; control="$2"
  enabled="$(control_value "$control" enabled)"
  policy_required="$(control_value "$control" policy_required)"
  pr_required="$(control_value "$control" pr_required)"
  case "$enabled:$policy_required:$pr_required" in
    true:true:true) emit_boundary "$boundary" run true required-by-profile ;;
    false:*) emit_boundary "$boundary" planned-skip false disabled-by-profile ;;
    *) die "inconsistent effective pull-request policy for $control" ;;
  esac
}

REPORT="$(mktemp "${TMPDIR:-/tmp}/template-ai-native-profile-plan.XXXXXX")" \
  || die 'unable to create policy report file'
chmod 600 "$REPORT" || die 'unable to secure policy report file'
trap 'rm -f "$REPORT"' EXIT HUP INT TERM

if [ -n "$POLICY_REPORT" ]; then
  [ -f "$POLICY_REPORT" ] && [ ! -L "$POLICY_REPORT" ] \
    || die 'policy report must be a regular non-symlink file'
  cat "$POLICY_REPORT" > "$REPORT"
elif ! sh "$HERE/resolve-profile-policy.sh" "$PROFILE_CONFIG" "$CONTROL_MAP" "$PROJECT_CONFIG" >"$REPORT"; then
  die 'central policy resolution failed'
fi
validate_report

MODE="$(awk -F '=' '$1 == "mode" { print $2 }' "$REPORT")"
if [ "$MODE" = compatibility ]; then
  printf 'mode=compatibility\nprofile=none\nlayout=unknown\nstack=unknown\nstatus=delegated\n'
  for boundary in $BOUNDARIES; do
    emit_boundary "$boundary" delegated-to-current-baseline false current-baseline
  done
  exit 0
fi

sh "$HERE/validate-project-config.sh" "$PROJECT_CONFIG" >/dev/null 2>&1 \
  || die 'invalid project config for execution planning'
sh "$HERE/validate-profile-config.sh" "$PROFILE_CONFIG" >/dev/null 2>&1 \
  || die 'invalid profile config for execution planning'

PROFILE="$(awk -F '=' '$1 == "profile" { print $2 }' "$REPORT")"
LAYOUT="$(sh "$HERE/resolve-components.sh" --layout "$PROJECT_CONFIG")"
case "$LAYOUT" in single|undecided|monorepo) ;; *) die 'unsupported repository layout' ;; esac
if [ "$LAYOUT" = monorepo ]; then
  sh "$HERE/resolve-components.sh" --validate "$PROJECT_CONFIG" >/dev/null
fi
STACK="$(sh "$HERE/detect-stack.sh")"
case "$STACK" in python|node|go|java|dotnet|unknown) ;; *) die 'unsupported detected stack' ;; esac

if [ "$LAYOUT" = monorepo ]; then
  printf 'mode=profile\nprofile=%s\nlayout=monorepo\nstack=unknown\nstatus=ready\n' "$PROFILE"
  emit_boundary quality_unit planned-skip false covered-by-monorepo-boundary
  emit_boundary test_coverage planned-skip false covered-by-monorepo-boundary
  emit_boundary monorepo_ci run true required-by-profile
  emit_boundary secret_scan run true required-by-profile
  emit_boundary dependency_review run true required-by-profile
  emit_pr_control codeql codeql
  emit_pr_control ai_evaluation ai_evaluation
  emit_policy_metadata sbom sbom
  emit_policy_metadata artifact_attestation artifact_attestation
  emit_policy_metadata scorecard scorecard
  emit_policy_metadata semantic_review semantic_review
  emit_policy_metadata structural_review structural_review
  emit_policy_metadata production_governance production_governance
  exit 0
fi

if [ "$LAYOUT" = undecided ] && [ "$STACK" != unknown ]; then
  die 'executable stack requires explicit single or monorepo layout'
fi

if [ "$STACK" = unknown ]; then
  printf 'mode=profile\nprofile=%s\nlayout=%s\nstack=unknown\nstatus=ready\n' "$PROFILE" "$LAYOUT"
  emit_boundary quality_unit not-applicable false no-executable-stack
  emit_boundary test_coverage not-applicable false no-executable-stack
  emit_boundary monorepo_ci not-applicable false no-executable-stack
  emit_boundary secret_scan run true required-by-profile
  emit_boundary dependency_review run true required-by-profile
  emit_boundary codeql not-applicable false no-executable-stack

  emit_pr_control ai_evaluation ai_evaluation
  emit_policy_metadata sbom sbom
  emit_policy_metadata artifact_attestation artifact_attestation
  emit_policy_metadata scorecard scorecard
  emit_policy_metadata semantic_review semantic_review
  emit_policy_metadata structural_review structural_review
  emit_policy_metadata production_governance production_governance
else
  printf 'mode=profile\nprofile=%s\nlayout=single\nstack=%s\nstatus=ready\n' "$PROFILE" "$STACK"
  emit_boundary quality_unit run true required-by-profile
  emit_pr_control test_coverage coverage
  emit_boundary monorepo_ci not-applicable false no-executable-stack
  emit_boundary secret_scan run true required-by-profile
  emit_boundary dependency_review run true required-by-profile
  emit_pr_control codeql codeql
  emit_pr_control ai_evaluation ai_evaluation
  emit_policy_metadata sbom sbom
  emit_policy_metadata artifact_attestation artifact_attestation
  emit_policy_metadata scorecard scorecard
  emit_policy_metadata semantic_review semantic_review
  emit_policy_metadata structural_review structural_review
  emit_policy_metadata production_governance production_governance
fi
