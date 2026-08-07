#!/usr/bin/env sh
# Validate the repository's production-readiness contract without evaluating it.
set -eu

KEYS='READINESS_SCHEMA_VERSION READINESS_STATUS SERVICE_OWNER PRODUCTION_ENVIRONMENT OBSERVABILITY_BACKEND SLO_AVAILABILITY_PERCENT SLO_LATENCY_P95_MS ERROR_BUDGET_WINDOW_DAYS ALERT_POLICY_PATH ALERT_RUNBOOK_PATH ROLLBACK_RUNBOOK_PATH ROLLBACK_TEST_DATE ROLLBACK_TEST_EVIDENCE_PATH RTO_MINUTES DATA_RECOVERY_REQUIRED RPO_MINUTES RESTORE_TEST_DATE RESTORE_TEST_EVIDENCE_PATH'

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

if [ "$#" -gt 1 ]; then
  fail 'usage: validate-production-readiness.sh [manifest_path]'
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
MANIFEST_INPUT="${1:-$SCRIPT_DIR/../observability/production-readiness.conf}"
MANIFEST_NAME="$(basename "$MANIFEST_INPUT")"
MANIFEST_DIR="$(cd "$(dirname "$MANIFEST_INPUT")" 2>/dev/null && pwd -P)" ||
  fail 'manifest parent directory does not exist'
MANIFEST_PATH="$MANIFEST_DIR/$MANIFEST_NAME"

if [ -L "$MANIFEST_PATH" ]; then
  fail 'manifest must not be a symlink'
fi
if [ ! -f "$MANIFEST_PATH" ]; then
  fail 'manifest must be a regular file'
fi

REPO_ROOT_RAW="$(
  unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_INDEX_FILE \
    GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM
  git -C "$MANIFEST_DIR" rev-parse --show-toplevel 2>/dev/null
)" ||
  fail 'manifest is not inside a Git worktree'
REPO_ROOT="$(cd "$REPO_ROOT_RAW" 2>/dev/null && pwd -P)" ||
  fail 'could not canonicalize repository root'

case "$MANIFEST_PATH" in
  "$REPO_ROOT"/*) ;;
  *) fail 'manifest path is outside the repository root' ;;
esac

umask 077
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/production-readiness.XXXXXX")" ||
  fail 'could not create private parser workspace'
PARSED_FILE="$TMP_ROOT/manifest.values"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
: > "$PARSED_FILE"

carriage_return="$(printf '\r')"
if LC_ALL=C grep -q "$carriage_return" "$MANIFEST_PATH"; then
  fail 'manifest contains CRLF line endings'
fi

line_number=0
while IFS= read -r line || [ -n "$line" ]; do
  line_number=$((line_number + 1))
  case "$line" in
    ''|'#'*) continue ;;
  esac

  case "$line" in
    *=*) ;;
    *) fail "malformed line $line_number: expected exactly one =" ;;
  esac

  key=${line%%=*}
  value=${line#*=}
  case "$value" in
    *=*) fail "malformed line $line_number: expected exactly one =" ;;
  esac

  if ! printf '%s\n' "$key" | LC_ALL=C grep -Eq '^[A-Z][A-Z0-9_]*$'; then
    fail "invalid key at line $line_number"
  fi
  case " $KEYS " in
    *" $key "*) ;;
    *) fail "unknown key $key" ;;
  esac
  if LC_ALL=C grep -q "^${key}=" "$PARSED_FILE"; then
    fail "duplicate key $key"
  fi
  if [ -z "$value" ]; then
    fail "empty value for $key"
  fi
  if ! printf '%s\n' "$value" | LC_ALL=C grep -Eq '^[A-Za-z0-9._/@:+-]+$'; then
    fail "invalid value syntax for $key"
  fi

  printf '%s=%s\n' "$key" "$value" >> "$PARSED_FILE"
done < "$MANIFEST_PATH"

for required_key in $KEYS; do
  if ! LC_ALL=C grep -q "^${required_key}=" "$PARSED_FILE"; then
    fail "missing key $required_key"
  fi
done

value_for() {
  lookup_key=$1
  sed -n "
/^${lookup_key}=/ {
  s/^[^=]*=//
  p
  q
}
" "$PARSED_FILE"
}

is_positive_integer() {
  awk -v value="$1" 'BEGIN {
    exit !(value ~ /^[0-9]+$/ && value + 0 > 0)
  }'
}

is_nonnegative_integer() {
  awk -v value="$1" 'BEGIN {
    exit !(value ~ /^[0-9]+$/ && value + 0 >= 0)
  }'
}

is_availability() {
  awk -v value="$1" 'BEGIN {
    if (value !~ /^[0-9]+([.][0-9]+)?$/) {
      exit 1
    }

    decimal_point = index(value, ".")
    if (decimal_point > 0) {
      whole = substr(value, 1, decimal_point - 1)
      fraction = substr(value, decimal_point + 1)
    } else {
      whole = value
      fraction = ""
    }

    sub(/^0+/, "", whole)
    if (whole == "") {
      whole = "0"
    }
    if (whole == "0" && fraction !~ /[1-9]/) {
      exit 1
    }
    if (length(whole) < 3) {
      exit 0
    }
    if (length(whole) > 3 || whole != "100") {
      exit 1
    }
    exit !(fraction == "" || fraction ~ /^0+$/)
  }'
}

CURRENT_UTC_DATE="$(date -u +%Y-%m-%d)"
is_calendar_date_not_future() {
  awk -v value="$1" -v today="$CURRENT_UTC_DATE" 'BEGIN {
    if (value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
      exit 1
    }
    year = substr(value, 1, 4) + 0
    month = substr(value, 6, 2) + 0
    day = substr(value, 9, 2) + 0
    if (year < 1 || month < 1 || month > 12 || day < 1) {
      exit 1
    }
    days[1] = 31
    days[2] = 28
    days[3] = 31
    days[4] = 30
    days[5] = 31
    days[6] = 30
    days[7] = 31
    days[8] = 31
    days[9] = 30
    days[10] = 31
    days[11] = 30
    days[12] = 31
    if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) {
      days[2] = 29
    }
    if (day > days[month] || value > today) {
      exit 1
    }
    exit 0
  }'
}

validate_repo_file() {
  path_key=$1
  markers=$2
  relative_path="$(value_for "$path_key")"

  case "$relative_path" in
    UNSET|NOT_APPLICABLE) fail "$path_key must reference a repository file" ;;
    /*) fail "$path_key must not be an absolute path" ;;
    ..|../*|*/../*|*/..) fail "$path_key must not contain a .. segment" ;;
  esac

  candidate="$REPO_ROOT/$relative_path"
  if [ -L "$candidate" ]; then
    fail "$path_key must not reference a symlink"
  fi

  candidate_parent="$(dirname "$candidate")"
  canonical_parent="$(cd "$candidate_parent" 2>/dev/null && pwd -P)" ||
    fail "$path_key parent directory does not exist"
  case "$canonical_parent" in
    "$REPO_ROOT"|"$REPO_ROOT"/*) ;;
    *) fail "$path_key resolves outside the repository root" ;;
  esac

  canonical_path="$canonical_parent/$(basename "$candidate")"
  if [ ! -f "$canonical_path" ]; then
    fail "$path_key must reference an existing regular file"
  fi

  if [ "$markers" = yes ]; then
    if LC_ALL=C grep -Eiq '(^|[^[:alnum:]_])(TODO|TBD|FIXME|UNSET)([^[:alnum:]_]|$)' "$canonical_path"; then
      fail "$path_key contains an unresolved template marker"
    fi
    if LC_ALL=C grep -Fq 'Adapt to your project' "$canonical_path"; then
      fail "$path_key contains an unresolved generic status"
    fi
  fi
}

schema_version="$(value_for READINESS_SCHEMA_VERSION)"
readiness_status="$(value_for READINESS_STATUS)"
production_environment="$(value_for PRODUCTION_ENVIRONMENT)"

if [ "$schema_version" != 1 ]; then
  fail 'READINESS_SCHEMA_VERSION must be 1'
fi
case "$readiness_status" in
  template|active) ;;
  *) fail 'READINESS_STATUS must be template or active' ;;
esac
if [ "$production_environment" != production ]; then
  fail 'PRODUCTION_ENVIRONMENT must be production'
fi

validate_repo_file ALERT_POLICY_PATH no
validate_repo_file ALERT_RUNBOOK_PATH no
validate_repo_file ROLLBACK_RUNBOOK_PATH no

if [ "$readiness_status" = template ]; then
  for template_key in $KEYS; do
    if [ "$(value_for "$template_key")" = NOT_APPLICABLE ]; then
      fail "$template_key must not be NOT_APPLICABLE in template mode"
    fi
  done
  printf '%s\n' \
    'readiness_status=template' \
    'readiness_contract_valid=true' \
    'production_ready=false'
  exit 0
fi

for active_key in $KEYS; do
  active_value="$(value_for "$active_key")"
  case "$active_value" in
    UNSET) fail "$active_key must not be UNSET in active mode" ;;
    NOT_APPLICABLE)
      case "$active_key" in
        RPO_MINUTES|RESTORE_TEST_DATE|RESTORE_TEST_EVIDENCE_PATH) ;;
        *) fail "$active_key must not be NOT_APPLICABLE in active mode" ;;
      esac
      ;;
  esac
done

availability="$(value_for SLO_AVAILABILITY_PERCENT)"
if ! is_availability "$availability"; then
  fail 'SLO_AVAILABILITY_PERCENT must be greater than 0 and at most 100'
fi

latency="$(value_for SLO_LATENCY_P95_MS)"
if ! is_positive_integer "$latency"; then
  fail 'SLO_LATENCY_P95_MS must be a positive integer'
fi

window="$(value_for ERROR_BUDGET_WINDOW_DAYS)"
if ! is_positive_integer "$window" || ! awk -v value="$window" 'BEGIN { exit !(value <= 365) }'; then
  fail 'ERROR_BUDGET_WINDOW_DAYS must be an integer from 1 through 365'
fi

rto="$(value_for RTO_MINUTES)"
if ! is_positive_integer "$rto"; then
  fail 'RTO_MINUTES must be a positive integer'
fi

rollback_date="$(value_for ROLLBACK_TEST_DATE)"
if ! is_calendar_date_not_future "$rollback_date"; then
  fail 'ROLLBACK_TEST_DATE must be a valid, non-future UTC date'
fi

validate_repo_file ALERT_POLICY_PATH yes
validate_repo_file ALERT_RUNBOOK_PATH yes
validate_repo_file ROLLBACK_RUNBOOK_PATH yes
validate_repo_file ROLLBACK_TEST_EVIDENCE_PATH yes

recovery_required="$(value_for DATA_RECOVERY_REQUIRED)"
case "$recovery_required" in
  yes)
    rpo="$(value_for RPO_MINUTES)"
    if ! is_nonnegative_integer "$rpo"; then
      fail 'RPO_MINUTES must be a non-negative integer when recovery is required'
    fi
    restore_date="$(value_for RESTORE_TEST_DATE)"
    if ! is_calendar_date_not_future "$restore_date"; then
      fail 'RESTORE_TEST_DATE must be a valid, non-future UTC date when recovery is required'
    fi
    validate_repo_file RESTORE_TEST_EVIDENCE_PATH yes
    ;;
  no)
    if [ "$(value_for RPO_MINUTES)" != NOT_APPLICABLE ]; then
      fail 'RPO_MINUTES must be NOT_APPLICABLE when recovery is not required'
    fi
    if [ "$(value_for RESTORE_TEST_DATE)" != NOT_APPLICABLE ]; then
      fail 'RESTORE_TEST_DATE must be NOT_APPLICABLE when recovery is not required'
    fi
    if [ "$(value_for RESTORE_TEST_EVIDENCE_PATH)" != NOT_APPLICABLE ]; then
      fail 'RESTORE_TEST_EVIDENCE_PATH must be NOT_APPLICABLE when recovery is not required'
    fi
    ;;
  *) fail 'DATA_RECOVERY_REQUIRED must be yes or no' ;;
esac

printf '%s\n' \
  'readiness_status=active' \
  'readiness_contract_valid=true' \
  'production_ready=false'
