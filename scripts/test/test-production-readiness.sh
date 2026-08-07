#!/usr/bin/env sh
# Behavioral contract for the production-readiness manifest validator.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

VALIDATOR="$ROOT/scripts/validate-production-readiness.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/readiness-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

new_fixture() {
  name="$1"
  FIXTURE="$TMP_ROOT/$name"
  mkdir -p "$FIXTURE/observability" "$FIXTURE/docs/operations" "$FIXTURE/evidence"
  git -C "$FIXTURE" init -q
  printf '%s\n' '# Alert Policy' 'Every alert identifies severity, owner, and runbook.' > "$FIXTURE/docs/operations/alerting.md"
  printf '%s\n' '# Runbook' 'Diagnose, mitigate, escalate, communicate, and preserve evidence.' > "$FIXTURE/docs/operations/runbook.md"
  printf '%s\n' '# Rollback' 'Verify identity, restore, and verify recovery.' > "$FIXTURE/docs/operations/rollback.md"
  printf '%s\n' '# Rollback Evidence' 'Exercise passed.' > "$FIXTURE/evidence/rollback.md"
  printf '%s\n' '# Restore Evidence' 'Restore and integrity checks passed.' > "$FIXTURE/evidence/restore.md"
}

write_active_manifest() {
  recovery="$1"
  if [ "$recovery" = yes ]; then
    rpo=15
    restore_date=2025-01-15
    restore_path=evidence/restore.md
  else
    rpo=NOT_APPLICABLE
    restore_date=NOT_APPLICABLE
    restore_path=NOT_APPLICABLE
  fi
  printf '%s\n' \
    'READINESS_SCHEMA_VERSION=1' \
    'READINESS_STATUS=active' \
    'SERVICE_OWNER=platform-team' \
    'PRODUCTION_ENVIRONMENT=production' \
    'OBSERVABILITY_BACKEND=otlp-gateway' \
    'SLO_AVAILABILITY_PERCENT=99.9' \
    'SLO_LATENCY_P95_MS=500' \
    'ERROR_BUDGET_WINDOW_DAYS=30' \
    'ALERT_POLICY_PATH=docs/operations/alerting.md' \
    'ALERT_RUNBOOK_PATH=docs/operations/runbook.md' \
    'ROLLBACK_RUNBOOK_PATH=docs/operations/rollback.md' \
    'ROLLBACK_TEST_DATE=2025-01-15' \
    'ROLLBACK_TEST_EVIDENCE_PATH=evidence/rollback.md' \
    'RTO_MINUTES=60' \
    "DATA_RECOVERY_REQUIRED=$recovery" \
    "RPO_MINUTES=$rpo" \
    "RESTORE_TEST_DATE=$restore_date" \
    "RESTORE_TEST_EVIDENCE_PATH=$restore_path" \
    > "$FIXTURE/observability/production-readiness.conf"
}

set_value() {
  file="$1" key="$2" value="$3"
  awk -F= -v key="$key" -v value="$value" '
    $1 == key { print key "=" value; next }
    { print }
  ' "$file" > "$file.next"
  mv "$file.next" "$file"
}

remove_key() {
  file="$1" key="$2"
  awk -F= -v key="$key" '$1 != key { print }' "$file" > "$file.next"
  mv "$file.next" "$file"
}

run_validator() {
  manifest="$1"
  set +e
  RUN_OUTPUT="$(sh "$VALIDATOR" "$manifest" 2>&1)"
  RUN_STATUS=$?
  set -e
}

assert_output_contains() {
  label="$1" pattern="$2"
  if printf '%s\n' "$RUN_OUTPUT" | grep -Eq "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n     output: %s\n' "$label" "$pattern" "$RUN_OUTPUT" >&2
  fi
}

assert_nonzero() {
  label="$1"
  if [ "$RUN_STATUS" -ne 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     expected non-zero exit\n' "$label" >&2
  fi
}

# The committed template remains a valid but not production-ready contract.
run_validator "$ROOT/observability/production-readiness.conf"
assert_eq "template manifest exits zero" "$RUN_STATUS" "0"
assert_output_contains "template reports template status" '^readiness_status=template$'
assert_output_contains "template reports not production ready" '^production_ready=false$'

# Both valid active recovery variants may claim production readiness.
new_fixture active-stateful
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
run_validator "$manifest"
assert_eq "active stateful manifest exits zero" "$RUN_STATUS" "0"
assert_output_contains "active stateful reports active status" '^readiness_status=active$'
assert_output_contains "active stateful reports production ready" '^production_ready=true$'

new_fixture active-stateless
write_active_manifest no
manifest="$FIXTURE/observability/production-readiness.conf"
run_validator "$manifest"
assert_eq "active stateless manifest exits zero" "$RUN_STATUS" "0"
assert_output_contains "active stateless reports active status" '^readiness_status=active$'
assert_output_contains "active stateless reports production ready" '^production_ready=true$'

# Parser trust boundary: each malformed or ambiguous contract is rejected.
new_fixture duplicate-service-owner
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
printf '%s\n' 'SERVICE_OWNER=another-team' >> "$manifest"
run_validator "$manifest"
assert_nonzero "duplicate SERVICE_OWNER is rejected"
assert_output_contains "duplicate SERVICE_OWNER has diagnostic" 'SERVICE_OWNER'

new_fixture unknown-key
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
printf '%s\n' 'READY_APPROVER=platform-team' >> "$manifest"
run_validator "$manifest"
assert_nonzero "unknown READY_APPROVER is rejected"
assert_output_contains "unknown READY_APPROVER has diagnostic" 'READY_APPROVER'

new_fixture missing-latency
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
remove_key "$manifest" SLO_LATENCY_P95_MS
run_validator "$manifest"
assert_nonzero "missing latency is rejected"
assert_output_contains "missing latency has diagnostic" 'SLO_LATENCY_P95_MS'

new_fixture empty-owner
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SERVICE_OWNER ''
run_validator "$manifest"
assert_nonzero "empty SERVICE_OWNER is rejected"
assert_output_contains "empty SERVICE_OWNER has diagnostic" 'SERVICE_OWNER'

new_fixture malformed-line
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
printf '%s\n' 'missing equals' >> "$manifest"
run_validator "$manifest"
assert_nonzero "line without equals is rejected"
assert_output_contains "line without equals has diagnostic" 'malformed.*line'

new_fixture unsupported-schema
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" READINESS_SCHEMA_VERSION 2
run_validator "$manifest"
assert_nonzero "schema version 2 is rejected"
assert_output_contains "schema version 2 has diagnostic" 'READINESS_SCHEMA_VERSION'

new_fixture unknown-status
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" READINESS_STATUS ready
run_validator "$manifest"
assert_nonzero "unknown readiness state is rejected"
assert_output_contains "unknown readiness state has diagnostic" 'READINESS_STATUS'

# Active semantic constraints: values must be meaningful and bounded.
new_fixture unset-backend
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" OBSERVABILITY_BACKEND UNSET
run_validator "$manifest"
assert_nonzero "active UNSET backend is rejected"
assert_output_contains "active UNSET backend has diagnostic" 'OBSERVABILITY_BACKEND'

new_fixture invalid-availability
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SLO_AVAILABILITY_PERCENT 100.1
run_validator "$manifest"
assert_nonzero "availability above 100 is rejected"
assert_output_contains "availability above 100 has diagnostic" 'SLO_AVAILABILITY_PERCENT'

new_fixture invalid-latency
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SLO_LATENCY_P95_MS 0
run_validator "$manifest"
assert_nonzero "zero latency is rejected"
assert_output_contains "zero latency has diagnostic" 'SLO_LATENCY_P95_MS'

new_fixture invalid-window
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" ERROR_BUDGET_WINDOW_DAYS 366
run_validator "$manifest"
assert_nonzero "window above 365 days is rejected"
assert_output_contains "window above 365 days has diagnostic" 'ERROR_BUDGET_WINDOW_DAYS'

new_fixture invalid-rto
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" RTO_MINUTES -1
run_validator "$manifest"
assert_nonzero "negative RTO is rejected"
assert_output_contains "negative RTO has diagnostic" 'RTO_MINUTES'

new_fixture invalid-rpo
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" RPO_MINUTES -1
run_validator "$manifest"
assert_nonzero "negative stateful RPO is rejected"
assert_output_contains "negative stateful RPO has diagnostic" 'RPO_MINUTES'

new_fixture invalid-calendar-date
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" ROLLBACK_TEST_DATE 2025-02-30
run_validator "$manifest"
assert_nonzero "invalid calendar date is rejected"
assert_output_contains "invalid calendar date has diagnostic" 'ROLLBACK_TEST_DATE'

new_fixture future-date
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" ROLLBACK_TEST_DATE 2999-01-01
run_validator "$manifest"
assert_nonzero "future rollback date is rejected"
assert_output_contains "future rollback date has diagnostic" 'ROLLBACK_TEST_DATE'

new_fixture missing-stateful-recovery
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" RESTORE_TEST_DATE NOT_APPLICABLE
run_validator "$manifest"
assert_nonzero "stateful NOT_APPLICABLE restore date is rejected"
assert_output_contains "stateful NOT_APPLICABLE restore date has diagnostic" 'RESTORE_TEST_DATE'

new_fixture invalid-stateless-rpo
write_active_manifest no
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" RPO_MINUTES 0
run_validator "$manifest"
assert_nonzero "stateless numeric RPO is rejected"
assert_output_contains "stateless numeric RPO has diagnostic" 'RPO_MINUTES'

# Evidence paths must be repository-confined regular files without template markers.
new_fixture absolute-runbook-path
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" ROLLBACK_RUNBOOK_PATH /tmp/rollback.md
run_validator "$manifest"
assert_nonzero "absolute runbook path is rejected"
assert_output_contains "absolute runbook path has diagnostic" 'ROLLBACK_RUNBOOK_PATH.*absolute'

new_fixture traversal-runbook-path
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" ROLLBACK_RUNBOOK_PATH docs/operations/../rollback.md
run_validator "$manifest"
assert_nonzero "parent traversal runbook path is rejected"
assert_output_contains "parent traversal runbook path has diagnostic" 'ROLLBACK_RUNBOOK_PATH.*\.\.'

new_fixture missing-rollback-evidence
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
rm -f "$FIXTURE/evidence/rollback.md"
run_validator "$manifest"
assert_nonzero "missing rollback evidence is rejected"
assert_output_contains "missing rollback evidence has diagnostic" 'ROLLBACK_TEST_EVIDENCE_PATH'

new_fixture generic-rollback-document
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
printf '%s\n' '# Rollback' 'Status: Adapt to your project.' > "$FIXTURE/docs/operations/rollback.md"
run_validator "$manifest"
assert_nonzero "generic rollback document is rejected"
assert_output_contains "generic rollback document has diagnostic" 'ROLLBACK_RUNBOOK_PATH'

new_fixture todo-alert-policy
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
printf '%s\n' 'TODO' >> "$FIXTURE/docs/operations/alerting.md"
run_validator "$manifest"
assert_nonzero "TODO alert policy is rejected"
assert_output_contains "TODO alert policy has diagnostic" 'ALERT_POLICY_PATH'

new_fixture external-symlink-evidence
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
outside="$TMP_ROOT/rollback-evidence-outside.md"
printf '%s\n' '# External evidence' 'Must not be trusted.' > "$outside"
rm -f "$FIXTURE/evidence/rollback.md"
ln -s "$outside" "$FIXTURE/evidence/rollback.md"
run_validator "$manifest"
assert_nonzero "external rollback evidence symlink is rejected"
assert_output_contains "external rollback evidence symlink has diagnostic" 'ROLLBACK_TEST_EVIDENCE_PATH'

new_fixture non-git-source
write_active_manifest yes
source_manifest="$FIXTURE/observability/production-readiness.conf"
non_git_dir="$TMP_ROOT/non-git"
mkdir -p "$non_git_dir"
cp "$source_manifest" "$non_git_dir/production-readiness.conf"
run_validator "$non_git_dir/production-readiness.conf"
assert_nonzero "manifest outside a Git worktree is rejected"
assert_output_contains "manifest outside a Git worktree has diagnostic" '(Git worktree|repository root)'

report
