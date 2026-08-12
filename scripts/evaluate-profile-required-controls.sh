#!/usr/bin/env sh
set -eu

BOUNDARIES='quality_unit test_coverage monorepo_ci secret_scan dependency_review codeql ai_evaluation sbom artifact_attestation scorecard semantic_review structural_review production_governance'

die() {
  printf 'profile-required-controls: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 2 ] || die 'usage: evaluate-profile-required-controls.sh PLAN_FILE OUTCOMES_FILE'
PLAN_FILE="$1"
OUTCOMES_FILE="$2"

SNAPSHOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-required-controls.XXXXXX" 2>/dev/null)" \
  || die 'unable to create input snapshots'
chmod 700 "$SNAPSHOT_DIR" 2>/dev/null || die 'unable to secure input snapshots'
trap 'rm -rf "$SNAPSHOT_DIR"' EXIT HUP INT TERM

snapshot_input() {
  source_file="$1"
  snapshot_file="$2"
  label="$3"
  [ -f "$source_file" ] && [ ! -L "$source_file" ] \
    || die "$label must be a regular non-symlink file"
  if ! (umask 077; cat 2>/dev/null < "$source_file" > "$snapshot_file") 2>/dev/null; then
    die "unable to snapshot $label"
  fi
  [ -f "$snapshot_file" ] && [ ! -L "$snapshot_file" ] \
    || die "unable to snapshot $label"
}

PLAN_SNAPSHOT="$SNAPSHOT_DIR/plan"
OUTCOMES_SNAPSHOT="$SNAPSHOT_DIR/outcomes"
snapshot_input "$PLAN_FILE" "$PLAN_SNAPSHOT" plan
snapshot_input "$OUTCOMES_FILE" "$OUTCOMES_SNAPSHOT" outcomes

validate_plan() {
  awk -F '=' -v boundaries="$BOUNDARIES" '
    function known(list, value) {
      return index(" " list " ", " " value " ") > 0
    }
    function token(value) {
      return value ~ /^[a-z0-9][a-z0-9-]*$/ && length(value) <= 64
    }
    function fail() {
      invalid = 1
      exit
    }
    {
      if (NF != 2 || $1 == "" || $2 == "" || ++seen[$1] != 1) fail()
      values[$1] = $2

      if ($1 == "mode") {
        if ($2 != "compatibility" && $2 != "profile") fail()
        next
      }
      if ($1 == "profile") {
        if ($2 != "none" && $2 != "starter" && $2 != "standard" && $2 != "enterprise") fail()
        next
      }
      if ($1 == "layout") {
        if ($2 != "unknown" && $2 != "single" && $2 != "undecided" && $2 != "monorepo") fail()
        next
      }
      if ($1 == "stack") {
        if ($2 != "unknown" && $2 != "python" && $2 != "node" && $2 != "go" && $2 != "java" && $2 != "dotnet") fail()
        next
      }
      if ($1 == "status") {
        if ($2 != "delegated" && $2 != "ready") fail()
        next
      }

      if ($1 !~ /^boundary\.[a-z_]+\.(decision|required|reason)$/) fail()
      count = split($1, parts, ".")
      if (count != 3 || !known(boundaries, parts[2])) fail()
      if (parts[3] == "decision") {
        if ($2 != "run" && $2 != "planned-skip" && $2 != "not-applicable" && $2 != "delegated-to-current-baseline" && $2 != "policy-only") fail()
      } else if (parts[3] == "required") {
        if ($2 != "true" && $2 != "false") fail()
      } else if (!token($2)) {
        fail()
      }
    }
    END {
      if (invalid) exit 2
      if (seen["mode"] != 1 || seen["profile"] != 1 || seen["layout"] != 1 || seen["stack"] != 1 || seen["status"] != 1) exit 2
      boundary_count = split(boundaries, boundary_names, " ")
      for (boundary_index = 1; boundary_index <= boundary_count; boundary_index++) {
        boundary = boundary_names[boundary_index]
        decision_key = "boundary." boundary ".decision"
        required_key = "boundary." boundary ".required"
        reason_key = "boundary." boundary ".reason"
        if (seen[decision_key] != 1 || seen[required_key] != 1 || seen[reason_key] != 1) exit 2
        if (values[decision_key] != "run" && values[required_key] != "false") exit 2
      }
      if (values["mode"] == "compatibility") {
        if (values["profile"] != "none" || values["layout"] != "unknown" || values["stack"] != "unknown" || values["status"] != "delegated") exit 2
        for (boundary_index = 1; boundary_index <= boundary_count; boundary_index++) {
          boundary = boundary_names[boundary_index]
          if (values["boundary." boundary ".decision"] != "delegated-to-current-baseline" || values["boundary." boundary ".required"] != "false" || values["boundary." boundary ".reason"] != "current-baseline") exit 2
        }
      } else {
        if (values["profile"] == "none" || values["status"] != "ready") exit 2
        if (values["layout"] == "single") {
          if (values["stack"] != "unknown" && values["stack"] != "python" && values["stack"] != "node" && values["stack"] != "go" && values["stack"] != "java" && values["stack"] != "dotnet") exit 2
        } else if ((values["layout"] != "undecided" && values["layout"] != "monorepo") || values["stack"] != "unknown") exit 2
      }
    }
  ' 2>/dev/null < "$PLAN_SNAPSHOT" || die 'plan has malformed, duplicate, missing, or unknown records'
}

validate_outcomes() {
  awk -F '=' -v boundaries="$BOUNDARIES" '
    function known(list, value) {
      return index(" " list " ", " " value " ") > 0
    }
    function fail() {
      invalid = 1
      exit
    }
    {
      if (NF != 2 || $1 == "" || $2 == "" || ++seen[$1] != 1) fail()
      if ($1 !~ /^boundary\.[a-z_]+\.conclusion$/) fail()
      count = split($1, parts, ".")
      if (count != 3 || !known(boundaries, parts[2])) fail()
      if ($2 != "success" && $2 != "failure" && $2 != "cancelled" && $2 != "skipped") fail()
    }
    END {
      if (invalid) exit 2
      boundary_count = split(boundaries, boundary_names, " ")
      for (boundary_index = 1; boundary_index <= boundary_count; boundary_index++) {
        key = "boundary." boundary_names[boundary_index] ".conclusion"
        if (seen[key] != 1) exit 2
      }
    }
  ' 2>/dev/null < "$OUTCOMES_SNAPSHOT" || die 'outcomes have malformed, duplicate, missing, or unknown records'
}

value_for() {
  file="$1"
  key="$2"
  awk -F '=' -v key="$key" '$1 == key { print $2 }' 2>/dev/null < "$file" \
    || die 'unable to read input snapshot'
}

validate_plan
validate_outcomes

aggregate=pass
for boundary in $BOUNDARIES; do
  decision="$(value_for "$PLAN_SNAPSHOT" "boundary.$boundary.decision")"
  required="$(value_for "$PLAN_SNAPSHOT" "boundary.$boundary.required")"
  conclusion="$(value_for "$OUTCOMES_SNAPSHOT" "boundary.$boundary.conclusion")"

  if [ "$decision" = run ]; then
    if [ "$conclusion" = success ]; then
      verdict=pass
    elif [ "$required" = true ]; then
      verdict=fail
      aggregate=fail
    else
      verdict=warning
    fi
  elif [ "$conclusion" = skipped ]; then
    verdict=planned
  else
    verdict=fail
    aggregate=fail
  fi
done

printf 'aggregate.status=%s\n' "$aggregate"
for boundary in $BOUNDARIES; do
  decision="$(value_for "$PLAN_SNAPSHOT" "boundary.$boundary.decision")"
  required="$(value_for "$PLAN_SNAPSHOT" "boundary.$boundary.required")"
  reason="$(value_for "$PLAN_SNAPSHOT" "boundary.$boundary.reason")"
  conclusion="$(value_for "$OUTCOMES_SNAPSHOT" "boundary.$boundary.conclusion")"

  if [ "$decision" = run ]; then
    if [ "$conclusion" = success ]; then
      verdict=pass
    elif [ "$required" = true ]; then
      verdict=fail
    else
      verdict=warning
    fi
  elif [ "$conclusion" = skipped ]; then
    verdict=planned
  else
    verdict=fail
  fi
  printf 'boundary.%s.verdict=%s\nboundary.%s.detail=%s\n' \
    "$boundary" "$verdict" "$boundary" "$reason"
done

[ "$aggregate" = pass ]
