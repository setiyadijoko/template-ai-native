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

validate_mapping() {
  [ -f "$CONTROL_MAP" ] || die "mapping not found at $CONTROL_MAP"
  version="$(awk -F ':[[:space:]]*' '$1 == "version" { print $2; exit }' "$CONTROL_MAP")"
  [ "$version" = '1' ] || die "unsupported mapping version '$version'"

  for profile in starter standard enterprise; do
    grep -Eq "^  $profile:[[:space:]]*$" "$CONTROL_MAP" \
      || die "missing mapping profile '$profile'"
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
