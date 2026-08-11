#!/usr/bin/env sh
set -eu

PROFILE_CONFIG="${1:-.template/profile.yaml}"
CONTROL_MAP="${2:-.template/profile-controls.yaml}"
PROJECT_CONFIG="${3:-.template/project.yaml}"
CONTROLS='secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard ai_evaluation semantic_review structural_review production_governance'
HERE="$(cd "$(dirname "$0")" && pwd)"

die() {
  printf 'profile-policy: %s\n' "$1" >&2
  exit 1
}

profile_name() {
  awk '
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line ~ /^profile:[[:space:]]*/) {
        sub(/^profile:[[:space:]]*/, "", line)
        print line
        exit
      }
    }
  ' "$PROFILE_CONFIG"
}

profile_value() {
  section="$1"; key="$2"
  awk -v section="$section" -v key="$key" '
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
    }
    line == section ":" { inside = 1; next }
    inside && line ~ /^[^ ]/ { exit }
    inside && line ~ "^  " key ":[[:space:]]*" {
      value = line
      sub("^  " key ":[[:space:]]*", "", value)
      print value
      exit
    }
  ' "$PROFILE_CONFIG"
}

mapping_value() {
  selected_profile="$1"; control="$2"
  awk -v profile="$selected_profile" -v control="$control" '
    $0 == "  " profile ":" { inside = 1; next }
    inside && /^  [a-z]/ { exit }
    inside && $0 ~ "^    " control ":[[:space:]]*" {
      value = $0
      sub("^    " control ":[[:space:]]*", "", value)
      print value
      exit
    }
  ' "$CONTROL_MAP"
}

execution_class() {
  case "$1" in
    secret_scan|dependency_review|codeql|coverage|ai_evaluation)
      echo pull-request-blocking ;;
    semantic_review|structural_review) echo pull-request-advisory ;;
    sbom|artifact_attestation) echo post-merge ;;
    scorecard) echo scheduled-push ;;
    production_governance) echo manual-environment ;;
    *) die "unsupported control '$1'" ;;
  esac
}

validate_mapping_value() {
  control="$1"; value="$2"
  case "$control" in
    secret_scan|dependency_review|codeql|coverage)
      case "$value" in true|false) ;; *) die "unsupported mapping value '$value' for $control" ;; esac
      ;;
    sbom|artifact_attestation|scorecard)
      case "$value" in true|false|optional) ;; *) die "unsupported mapping value '$value' for $control" ;; esac
      ;;
    ai_evaluation)
      case "$value" in optional|when-ai-enabled|required-for-ai) ;; *) die "unsupported mapping value '$value' for $control" ;; esac
      ;;
    semantic_review|structural_review)
      case "$value" in off|advisory|enabled) ;; *) die "unsupported mapping value '$value' for $control" ;; esac
      ;;
    production_governance)
      case "$value" in when-deployed|required) ;; *) die "unsupported mapping value '$value' for $control" ;; esac
      ;;
    *) die "unsupported control '$control'" ;;
  esac
}

validate_mapping_shape() {
  awk -v controls="$CONTROLS" '
    function fail() {
      invalid = 1
      exit
    }
    function known_control(control) {
      return index(" " controls " ", " " control " ") > 0
    }
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^[[:space:]]*#/) next
      if (line ~ /[\t\r]/) fail()

      if (line ~ /^version:[[:space:]]*[^[:space:]#].*$/) {
        if (state != 0) fail()
        value = line
        sub(/^version:[[:space:]]*/, "", value)
        version_count++
        version_value = value
        state = 1
        next
      }
      if (line == "profiles:") {
        if (state != 1) fail()
        profiles_count++
        state = 2
        next
      }
      if (line ~ /^  [a-z][a-z0-9_]*:[[:space:]]*$/) {
        if (state < 2) fail()
        profile = line
        sub(/^  /, "", profile)
        sub(/:.*/, "", profile)
        if (profile != "starter" && profile != "standard" && profile != "enterprise") fail()
        if (++profile_count[profile] != 1) fail()
        active_profile = profile
        state = 3
        next
      }
      if (line ~ /^    [a-z][a-z0-9_]*:[[:space:]]*[^[:space:]#].*$/) {
        if (state != 3 || active_profile == "") fail()
        control = line
        sub(/^    /, "", control)
        sub(/:.*/, "", control)
        if (!known_control(control)) fail()
        if (++control_count[active_profile SUBSEP control] != 1) fail()
        next
      }
      fail()
    }
    END {
      if (invalid || version_count != 1 || version_value != "1" || profiles_count != 1) exit 2
      split("starter standard enterprise", profiles, " ")
      split(controls, control_names, " ")
      for (profile_index in profiles) {
        profile = profiles[profile_index]
        if (profile_count[profile] != 1) exit 2
        for (control_index in control_names) {
          control = control_names[control_index]
          if (control_count[profile SUBSEP control] != 1) exit 2
        }
      }
    }
  ' "$CONTROL_MAP" || die 'mapping must use the documented profile/control shape'
}

validate_mapping() {
  [ -f "$CONTROL_MAP" ] || die "mapping not found at $CONTROL_MAP"
  validate_mapping_shape

  for profile in starter standard enterprise; do
    for control in $CONTROLS; do
      value="$(mapping_value "$profile" "$control")"
      [ -n "$value" ] || die "missing mapping value for $profile.$control"
      validate_mapping_value "$control" "$value"
    done
  done
}

boolean_alignment() {
  declared="$1"; default="$2"
  case "$default:$declared" in
    optional:true|optional:false|true:true|false:false) echo aligned ;;
    false:true) echo stronger-than-default ;;
    true:false) echo policy-mismatch ;;
    *) die "invalid Boolean comparison '$declared' against '$default'" ;;
  esac
}

review_rank() {
  case "$1" in
    off) echo 0 ;;
    advisory) echo 1 ;;
    enabled) echo 2 ;;
    *) die "invalid review value '$1'" ;;
  esac
}

review_alignment() {
  declared_rank="$(review_rank "$1")"
  default_rank="$(review_rank "$2")"
  if [ "$declared_rank" -eq "$default_rank" ]; then
    echo aligned
  elif [ "$declared_rank" -gt "$default_rank" ]; then
    echo stronger-than-default
  else
    echo policy-mismatch
  fi
}

boolean_policy_required() {
  default="$1"; enabled="$2"
  case "$default:$enabled" in
    true:true|true:false|false:true|optional:true) echo true ;;
    false:false|optional:false) echo false ;;
    *) die "invalid Boolean policy value '$enabled' against '$default'" ;;
  esac
}

validate_mapping

if [ ! -e "$PROJECT_CONFIG" ] && [ ! -e "$PROFILE_CONFIG" ]; then
  printf 'mode=compatibility\nprofile=none\nstatus=current-baseline\n'
  for control in $CONTROLS; do
    printf 'control.%s.enabled=current-baseline\n' "$control"
  done
  exit 0
fi

[ -f "$PROJECT_CONFIG" ] || die "project config required at $PROJECT_CONFIG"
[ -f "$PROFILE_CONFIG" ] || die "initialized consumer requires profile config at $PROFILE_CONFIG"

sh "$HERE/validate-project-config.sh" "$PROJECT_CONFIG" >/dev/null 2>&1 \
  || die "invalid project config '$PROJECT_CONFIG'"
sh "$HERE/validate-profile-config.sh" "$PROFILE_CONFIG" >/dev/null 2>&1 \
  || die "invalid profile config '$PROFILE_CONFIG'"

PROFILE="$(profile_name)"
case "$PROFILE" in
  starter|standard|enterprise) ;;
  *) die "unsupported profile '$PROFILE'" ;;
esac

REPORT="$(mktemp "${TMPDIR:-/tmp}/template-ai-native-profile-policy.XXXXXX")" \
  || die 'unable to create report file'
trap 'rm -f "$REPORT"' EXIT HUP INT TERM
HAS_MISMATCH=false

for control in $CONTROLS; do
  default="$(mapping_value "$PROFILE" "$control")"
  class="$(execution_class "$control")"

  case "$control" in
    secret_scan|dependency_review|codeql|coverage|sbom|artifact_attestation|scorecard)
      declared="$(profile_value controls "$control")"
      enabled="$declared"
      alignment="$(boolean_alignment "$declared" "$default")"
      policy_required="$(boolean_policy_required "$default" "$enabled")"
      ;;
    ai_evaluation)
      ai_enabled="$(profile_value ai enabled)"
      ai_evaluation="$(profile_value ai evaluation)"
      if [ "$ai_enabled" = true ] && [ "$ai_evaluation" = true ]; then
        declared=true
      else
        declared=false
      fi
      enabled="$declared"
      case "$default" in
        optional)
          alignment=aligned
          policy_required="$enabled"
          ;;
        when-ai-enabled|required-for-ai)
          if [ "$enabled" = "$ai_enabled" ]; then
            alignment=aligned
          else
            alignment=policy-mismatch
          fi
          policy_required="$ai_enabled"
          ;;
        *) die "invalid AI evaluation default '$default'" ;;
      esac
      ;;
    semantic_review|structural_review)
      declared="$(profile_value ai "$control")"
      case "$declared" in
        off) enabled=false ;;
        advisory|enabled) enabled=true ;;
        *) die "invalid profile value '$declared' for $control" ;;
      esac
      alignment="$(review_alignment "$declared" "$default")"
      case "$default:$enabled" in
        off:false) policy_required=false ;;
        off:true|advisory:true|advisory:false|enabled:true|enabled:false) policy_required=true ;;
        *) die "invalid review policy value '$enabled' against '$default'" ;;
      esac
      ;;
    production_governance)
      declared="$(profile_value deployment enabled)"
      enabled="$declared"
      case "$default" in
        when-deployed)
          alignment=aligned
          policy_required="$enabled"
          ;;
        required)
          if [ "$enabled" = true ]; then
            alignment=aligned
          else
            alignment=policy-mismatch
          fi
          policy_required=true
          ;;
        *) die "invalid production governance default '$default'" ;;
      esac
      ;;
    *) die "unsupported control '$control'" ;;
  esac

  case "$enabled" in true|false) ;; *) die "invalid enabled value '$enabled' for $control" ;; esac
  case "$policy_required" in true|false) ;; *) die "invalid policy-required value '$policy_required' for $control" ;; esac
  if [ "$policy_required" = true ] && [ "$enabled" = true ] \
    && [ "$class" = pull-request-blocking ]; then
    pr_required=true
  else
    pr_required=false
  fi

  case "$alignment" in
    policy-mismatch)
      HAS_MISMATCH=true
      printf '::warning title=Profile policy mismatch::%s declaration differs from %s default\n' \
        "$control" "$PROFILE" >&2
      ;;
    aligned|stronger-than-default) ;;
    *) die "invalid alignment '$alignment' for $control" ;;
  esac
  printf 'control.%s.declared=%s\ncontrol.%s.default=%s\ncontrol.%s.enabled=%s\ncontrol.%s.class=%s\ncontrol.%s.policy_required=%s\ncontrol.%s.pr_required=%s\ncontrol.%s.alignment=%s\n' \
    "$control" "$declared" "$control" "$default" "$control" "$enabled" \
    "$control" "$class" "$control" "$policy_required" "$control" "$pr_required" \
    "$control" "$alignment" >> "$REPORT"
done

printf 'mode=profile\nprofile=%s\n' "$PROFILE"
if [ "$HAS_MISMATCH" = true ]; then
  printf 'status=warning\n'
else
  printf 'status=aligned\n'
fi
cat "$REPORT"
