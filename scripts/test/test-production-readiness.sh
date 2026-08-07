#!/usr/bin/env sh
# Production-readiness validator behavior and workflow security contracts.
# GitHub expressions and shell variable references are intentionally literal.
# shellcheck disable=SC2016
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

VALIDATOR="$ROOT/scripts/validate-production-readiness.sh"
READINESS_WORKFLOW="$ROOT/.github/workflows/production-readiness.yml"
ROLLBACK_WORKFLOW="$ROOT/.github/workflows/rollback.yml"
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

run_validator_poisoned() {
  manifest="$1" git_dir="$2" git_work_tree="$3"
  set +e
  RUN_OUTPUT="$(
    GIT_DIR="$git_dir" \
      GIT_WORK_TREE="$git_work_tree" \
      GIT_COMMON_DIR="$git_dir" \
      GIT_CEILING_DIRECTORIES="$git_work_tree" \
      GIT_DISCOVERY_ACROSS_FILESYSTEM=1 \
      sh "$VALIDATOR" "$manifest" 2>&1
  )"
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

assert_output_not_contains() {
  label="$1" pattern="$2"
  if printf '%s\n' "$RUN_OUTPUT" | grep -Eq "$pattern"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n     output: %s\n' "$label" "$pattern" "$RUN_OUTPUT" >&2
  else
    PASS=$((PASS+1))
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

assert_file_exists() {
  label="$1" file="$2"
  if [ -f "$file" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file: %s\n' "$label" "$file" >&2
  fi
}

assert_file_contains() {
  label="$1" file="$2" pattern="$3"
  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file or pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_file_contains_fixed() {
  label="$1" file="$2" text="$3"
  if [ -f "$file" ] && grep -Fq "$text" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file or text: %s\n' "$label" "$text" >&2
  fi
}

assert_file_has_exact_line() {
  label="$1" file="$2" text="$3"
  if [ -f "$file" ] && grep -Fxq "$text" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file or exact line: %s\n' "$label" "$text" >&2
  fi
}

assert_file_content_equals() {
  label="$1" file="$2" expected="$3"
  if [ -f "$file" ]; then
    actual="$(cat "$file")"
  else
    actual=''
  fi
  if [ -f "$file" ] && [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file or unexpected normalized body\n' "$label" >&2
  fi
}

assert_file_content_not_equals() {
  label="$1" file="$2" forbidden="$3"
  if [ -f "$file" ] && [ "$(cat "$file")" != "$forbidden" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     mutation incorrectly matched approved body\n' "$label" >&2
  fi
}

assert_file_not_contains() {
  label="$1" file="$2" pattern="$3"
  if [ ! -f "$file" ]; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing required file: %s\n' "$label" "$file" >&2
  elif grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

extract_yaml_block() {
  source_file="$1" output_file="$2" start_line="$3" start_indent="$4"
  rm -f "$output_file"
  [ -f "$source_file" ] || return 0
  awk -v start_line="$start_line" -v start_indent="$start_indent" '
    $0 == start_line { found = 1; print; next }
    found {
      if ($0 !~ /^[[:space:]]*($|#)/) {
        current_indent = match($0, /[^ ]/) - 1
        if (current_indent <= start_indent) exit
      }
      print
    }
  ' "$source_file" > "$output_file"
}

extract_run_nodes() {
  source_file="$1" output_file="$2"
  rm -f "$output_file"
  [ -f "$source_file" ] || return 0
  awk '
    /^[ ]*(-[ ]+)?run:[ ]*/ {
      run_indent = match($0, /[^ ]/) - 1
      print
      scalar = $0
      sub(/^[ ]*(-[ ]+)?run:[ ]*/, "", scalar)
      in_block = scalar ~ /^[|>][+-]?[ ]*(#.*)?$/
      next
    }
    in_block {
      if ($0 !~ /^[[:space:]]*$/) {
        current_indent = match($0, /[^ ]/) - 1
        if (current_indent <= run_indent) {
          in_block = 0
          next
        }
      }
      print
    }
  ' "$source_file" > "$output_file"
}

extract_executable_lines() {
  source_file="$1" output_file="$2"
  rm -f "$output_file"
  [ -f "$source_file" ] || return 0
  awk '
    /^[ ]*(-[ ]+)?run:[ ]*/ {
      line = $0
      sub(/^[ ]*(-[ ]+)?run:[ ]*/, "", line)
      in_block = line ~ /^[|>][+-]?[ ]*(#.*)?$/
      if (!in_block && line !~ /^[[:space:]]*($|#)/) print line
      next
    }
    in_block {
      line = $0
      sub(/^[ ]*/, "", line)
      if (line !~ /^[[:space:]]*($|#)/) print line
    }
  ' "$source_file" > "$output_file"
}

normalize_yaml_mapping_keys() {
  source_file="$1" output_file="$2"
  rm -f "$output_file"
  [ -f "$source_file" ] || return 0
  awk '
    {
      line = $0
      match(line, /^[ ]*/)
      indent = substr(line, 1, RLENGTH)
      rest = substr(line, RLENGTH + 1)
      quote = substr(rest, 1, 1)
      if (quote == "\"" || quote == sprintf("%c", 39)) {
        tail = substr(rest, 2)
        closing = index(tail, quote)
        if (closing > 0) {
          key = substr(tail, 1, closing - 1)
          suffix = substr(tail, closing + 1)
          if (suffix ~ /^[ ]*:/) {
            sub(/^[ ]*:/, ":", suffix)
            print indent key suffix
            next
          }
        }
      } else if (match(rest, /^[A-Za-z_][A-Za-z0-9_-]*[ ]*:/)) {
        key = substr(rest, 1, RLENGTH)
        sub(/[ ]*:$/, "", key)
        print indent key ":" substr(rest, RLENGTH + 1)
        next
      }
      print line
    }
  ' "$source_file" > "$output_file"
}

WRITE_PERMISSION_PATTERN='^[[:space:]]*(permissions|contents|actions|checks|deployments|discussions|id-token|issues|models|packages|pages|pull-requests|security-events|statuses|attestations):.*write(-all)?'

assert_file_has_write_permission() {
  label="$1" file="$2"
  if [ -f "$file" ] && grep -Eq "$WRITE_PERMISSION_PATTERN" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     write permission mutation was not detected\n' "$label" >&2
  fi
}

direct_yaml_keys() {
  file="$1" indent="$2"
  [ -f "$file" ] || return 0
  awk -v indent="$indent" '
    {
      prefix = sprintf("%*s", indent, "")
      if (index($0, prefix) == 1 && substr($0, indent + 1) ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) {
        line = substr($0, indent + 1)
        sub(/:.*/, "", line)
        print line
      } else if (index($0, prefix) == 1 && substr($0, indent + 1) ~ /^["\047][^"\047]+["\047]:/) {
        line = substr($0, indent + 1)
        sub(/:.*/, "", line)
        print line
      }
    }
  ' "$file"
}

direct_step_entries() {
  file="$1"
  [ -f "$file" ] || return 0
  awk '
    /^      -([[:space:]]|$)/ {
      entry = $0
      sub(/^      -[[:space:]]*/, "", entry)
      if (entry ~ /^name:[[:space:]]*/) {
        sub(/^name:[[:space:]]*/, "", entry)
      } else if (entry == "") {
        entry = "<unnamed>"
      }
      print entry
    }
  ' "$file"
}

# Exercise every supported run scalar form so a future extractor regression
# cannot hide direct GitHub input interpolation from the workflow contract.
RUN_SCALAR_FIXTURE="$TMP_ROOT/run-scalars.yml"
RUN_SCALAR_NODES="$TMP_ROOT/run-scalar-nodes.yml"
RUN_SCALAR_EXECUTABLE="$TMP_ROOT/run-scalar-executable.txt"
printf '%s\n' \
  'jobs:' \
  '  verify:' \
  '    steps:' \
  '      - run: echo "${{ inputs.inline }}"' \
  '      - run: |' \
  '          echo "${{ inputs.literal }}"' \
  '      - run: |-' \
  '          # COMMENT_ONLY_VALIDATION' \
  '          echo "${{ inputs.literal_strip }}"' \
  '      - run: >' \
  '          echo "${{ inputs.folded }}"' \
  '      - run: >-' \
  '          echo "${{ inputs.folded_strip }}"' \
  > "$RUN_SCALAR_FIXTURE"
extract_run_nodes "$RUN_SCALAR_FIXTURE" "$RUN_SCALAR_NODES"
extract_executable_lines "$RUN_SCALAR_NODES" "$RUN_SCALAR_EXECUTABLE"
run_input_count="$(grep -Fc '${{ inputs.' "$RUN_SCALAR_NODES" || true)"
assert_eq "run extractor covers inline and four block scalar forms" "$run_input_count" '5'
assert_file_not_contains "executable extraction drops comment-only lines" "$RUN_SCALAR_EXECUTABLE" 'COMMENT_ONLY_VALIDATION'
assert_file_has_exact_line "executable extraction preserves inline commands" "$RUN_SCALAR_EXECUTABLE" 'echo "${{ inputs.inline }}"'

SENTINEL_EXPECTED="$(printf '%s\n' \
  "echo '::error::Rollback target is not configured. Wire artifact verification, platform authentication, rollback execution, and recovery verification through an approved design.'" \
  'exit 1')"
SENTINEL_MUTATION="$TMP_ROOT/sentinel-shell-control.yml"
SENTINEL_MUTATION_NODES="$TMP_ROOT/sentinel-shell-control-nodes.yml"
SENTINEL_MUTATION_EXECUTABLE="$TMP_ROOT/sentinel-shell-control-executable.txt"
printf '%s\n' \
  'run: |' \
  '  if false; then' \
  "    echo '::error::Rollback target is not configured. Wire artifact verification, platform authentication, rollback execution, and recovery verification through an approved design.'" \
  '    exit 1' \
  '  fi' \
  > "$SENTINEL_MUTATION"
extract_run_nodes "$SENTINEL_MUTATION" "$SENTINEL_MUTATION_NODES"
extract_executable_lines "$SENTINEL_MUTATION_NODES" "$SENTINEL_MUTATION_EXECUTABLE"
assert_file_content_not_equals "sentinel shell-control mutation is rejected" "$SENTINEL_MUTATION_EXECUTABLE" "$SENTINEL_EXPECTED"

ROLLBACK_VALIDATION_EXPECTED="$(printf '%s\n' \
  'set -eu' \
  '[ "$ROLLBACK_CONFIRM" = ROLLBACK ] || {' \
  "echo '::error::Rollback confirmation must equal ROLLBACK.'" \
  'exit 1' \
  '}' \
  'printf '\''%s\n'\'' "$ROLLBACK_RELEASE_REF" |' \
  "grep -Eq '^([0-9a-f]{40}|v[0-9][0-9A-Za-z._-]*)$' || {" \
  "echo '::error::Release ref must be a lowercase commit SHA or v-prefixed tag.'" \
  'exit 1' \
  '}' \
  'printf '\''%s\n'\'' "$ROLLBACK_ARTIFACT_DIGEST" |' \
  "grep -Eq '^sha256:[0-9a-f]{64}$' || {" \
  "echo '::error::Artifact digest must be lowercase sha256.'" \
  'exit 1' \
  '}' \
  'case "$ROLLBACK_REASON" in' \
  '*[![:space:]]*) ;;' \
  '*)' \
  "echo '::error::Rollback reason must contain a non-whitespace character.'" \
  'exit 1' \
  ';;' \
  'esac' \
  'case "$ROLLBACK_ENVIRONMENT" in' \
  'development|staging|production) ;;' \
  '*)' \
  "echo '::error::Unknown rollback environment.'" \
  'exit 1' \
  ';;' \
  'esac')"

ROLLBACK_STEPS_MUTATION="$TMP_ROOT/rollback-extra-step.yml"
printf '%s\n' \
  '    steps:' \
  '      - name: Validate rollback request' \
  '      - name: Execute production rollback' \
  '      - name: Refuse unwired rollback' \
  > "$ROLLBACK_STEPS_MUTATION"
mutated_rollback_steps="$(direct_step_entries "$ROLLBACK_STEPS_MUTATION")"
assert_eq "extra production-action step is exposed" "$mutated_rollback_steps" "$(printf '%s\n' 'Validate rollback request' 'Execute production rollback' 'Refuse unwired rollback')"

ROLLBACK_NAMELESS_STEP_MUTATION="$TMP_ROOT/rollback-nameless-extra-step.yml"
printf '%s\n' \
  '    steps:' \
  '      - name: Validate rollback request' \
  '      - run: curl -X POST https://production.invalid/rollback' \
  '      - name: Refuse unwired rollback' \
  > "$ROLLBACK_NAMELESS_STEP_MUTATION"
mutated_nameless_rollback_steps="$(direct_step_entries "$ROLLBACK_NAMELESS_STEP_MUTATION")"
assert_eq "nameless production-action step is exposed" "$mutated_nameless_rollback_steps" "$(printf '%s\n' 'Validate rollback request' 'run: curl -X POST https://production.invalid/rollback' 'Refuse unwired rollback')"

ROLLBACK_VALIDATION_MUTATION="$TMP_ROOT/rollback-validation-mutation.yml"
ROLLBACK_VALIDATION_MUTATION_NODES="$TMP_ROOT/rollback-validation-mutation-nodes.yml"
ROLLBACK_VALIDATION_MUTATION_EXECUTABLE="$TMP_ROOT/rollback-validation-mutation-executable.txt"
printf '%s\n' \
  'run: |' \
  '  set -eu' \
  '  echo "validation bypassed"' \
  > "$ROLLBACK_VALIDATION_MUTATION"
extract_run_nodes "$ROLLBACK_VALIDATION_MUTATION" "$ROLLBACK_VALIDATION_MUTATION_NODES"
extract_executable_lines "$ROLLBACK_VALIDATION_MUTATION_NODES" "$ROLLBACK_VALIDATION_MUTATION_EXECUTABLE"
assert_file_content_not_equals "altered rollback validation body is rejected" "$ROLLBACK_VALIDATION_MUTATION_EXECUTABLE" "$ROLLBACK_VALIDATION_EXPECTED"

QUOTED_PERMISSION_MUTATION="$TMP_ROOT/quoted-permission-mutation.yml"
QUOTED_PERMISSION_NORMALIZED="$TMP_ROOT/quoted-permission-normalized.yml"
SPACED_PERMISSION_MUTATION="$TMP_ROOT/spaced-permission-mutation.yml"
SPACED_PERMISSION_NORMALIZED="$TMP_ROOT/spaced-permission-normalized.yml"
printf '%s\n' \
  'jobs:' \
  '  readiness:' \
  '    "permissions" :' \
  "      'contents' : write" \
  > "$QUOTED_PERMISSION_MUTATION"
printf '%s\n' \
  'permissions :' \
  '  "actions" : write-all' \
  > "$SPACED_PERMISSION_MUTATION"
normalize_yaml_mapping_keys "$QUOTED_PERMISSION_MUTATION" "$QUOTED_PERMISSION_NORMALIZED"
normalize_yaml_mapping_keys "$SPACED_PERMISSION_MUTATION" "$SPACED_PERMISSION_NORMALIZED"
assert_file_contains "quoted readiness job permission key is normalized" "$QUOTED_PERMISSION_NORMALIZED" '^    permissions:$'
assert_file_has_write_permission "single-quoted contents write is detected" "$QUOTED_PERMISSION_NORMALIZED"
assert_file_has_write_permission "spaced permission and quoted write-all are detected" "$SPACED_PERMISSION_NORMALIZED"

READINESS_JOB_KEY_MUTATION="$TMP_ROOT/readiness-job-key-mutation.yml"
READINESS_JOB_KEY_NORMALIZED="$TMP_ROOT/readiness-job-key-normalized.yml"
READINESS_JOB_KEY_BLOCK="$TMP_ROOT/readiness-job-key-block.yml"
ROLLBACK_JOB_KEY_MUTATION="$TMP_ROOT/rollback-job-key-mutation.yml"
ROLLBACK_JOB_KEY_NORMALIZED="$TMP_ROOT/rollback-job-key-normalized.yml"
ROLLBACK_JOB_KEY_BLOCK="$TMP_ROOT/rollback-job-key-block.yml"
printf '%s\n' \
  'jobs:' \
  '  readiness:' \
  '    "nested" :' \
  '  "shadow" :' \
  > "$READINESS_JOB_KEY_MUTATION"
printf '%s\n' \
  'jobs:' \
  '  rollback:' \
  "    'nested' :" \
  "  'shadow' :" \
  > "$ROLLBACK_JOB_KEY_MUTATION"
normalize_yaml_mapping_keys "$READINESS_JOB_KEY_MUTATION" "$READINESS_JOB_KEY_NORMALIZED"
normalize_yaml_mapping_keys "$ROLLBACK_JOB_KEY_MUTATION" "$ROLLBACK_JOB_KEY_NORMALIZED"
extract_yaml_block "$READINESS_JOB_KEY_NORMALIZED" "$READINESS_JOB_KEY_BLOCK" 'jobs:' 0
extract_yaml_block "$ROLLBACK_JOB_KEY_NORMALIZED" "$ROLLBACK_JOB_KEY_BLOCK" 'jobs:' 0
readiness_mutated_jobs="$(direct_yaml_keys "$READINESS_JOB_KEY_BLOCK" 2)"
rollback_mutated_jobs="$(direct_yaml_keys "$ROLLBACK_JOB_KEY_BLOCK" 2)"
assert_eq "double-quoted spaced extra readiness job is exposed" "$readiness_mutated_jobs" "$(printf '%s\n' readiness shadow)"
assert_eq "single-quoted spaced extra rollback job is exposed" "$rollback_mutated_jobs" "$(printf '%s\n' rollback shadow)"

# The committed template remains a valid but not production-ready contract.
run_validator "$ROOT/observability/production-readiness.conf"
assert_eq "template manifest exits zero" "$RUN_STATUS" "0"
assert_output_contains "template reports template status" '^readiness_status=template$'
assert_output_contains "template reports valid readiness contract" '^readiness_contract_valid=true$'
assert_output_contains "template reports not production ready" '^production_ready=false$'

# Both valid active recovery variants validate the contract without approval.
new_fixture active-stateful
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
run_validator "$manifest"
assert_eq "active stateful manifest exits zero" "$RUN_STATUS" "0"
assert_output_contains "active stateful reports active status" '^readiness_status=active$'
assert_output_contains "active stateful reports valid readiness contract" '^readiness_contract_valid=true$'
assert_output_contains "active stateful reports not production ready" '^production_ready=false$'
assert_output_not_contains "active stateful cannot report production ready" '^production_ready=true$'

new_fixture active-stateless
write_active_manifest no
manifest="$FIXTURE/observability/production-readiness.conf"
run_validator "$manifest"
assert_eq "active stateless manifest exits zero" "$RUN_STATUS" "0"
assert_output_contains "active stateless reports active status" '^readiness_status=active$'
assert_output_contains "active stateless reports valid readiness contract" '^readiness_contract_valid=true$'
assert_output_contains "active stateless reports not production ready" '^production_ready=false$'
assert_output_not_contains "active stateless cannot report production ready" '^production_ready=true$'

new_fixture poisoned-valid-manifest
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
root_git_dir="$(git -C "$ROOT" rev-parse --absolute-git-dir)"
run_validator_poisoned "$manifest" "$root_git_dir" "$ROOT"
assert_eq "valid manifest ignores poisoned Git repository selection" "$RUN_STATUS" "0"
assert_output_contains "poisoned valid manifest reports active status" '^readiness_status=active$'

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

new_fixture availability-boundary-integer
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SLO_AVAILABILITY_PERCENT 100
run_validator "$manifest"
assert_eq "availability boundary 100 is accepted" "$RUN_STATUS" "0"

new_fixture availability-boundary-decimal
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SLO_AVAILABILITY_PERCENT 100.0
run_validator "$manifest"
assert_eq "availability boundary 100.0 is accepted" "$RUN_STATUS" "0"

new_fixture availability-boundary-leading-zeros
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SLO_AVAILABILITY_PERCENT 000100.0
run_validator "$manifest"
assert_eq "availability boundary with leading zeros is accepted" "$RUN_STATUS" "0"

new_fixture availability-long-precision-overflow
write_active_manifest yes
manifest="$FIXTURE/observability/production-readiness.conf"
set_value "$manifest" SLO_AVAILABILITY_PERCENT 100.0000000000000000000000000000000001
run_validator "$manifest"
assert_nonzero "long precision availability above 100 is rejected"
assert_output_contains "long precision availability above 100 has diagnostic" 'SLO_AVAILABILITY_PERCENT'

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
non_git_dir="$TMP_ROOT/non-git"
cp -R "$FIXTURE" "$non_git_dir"
rm -rf "$non_git_dir/.git"
run_validator "$non_git_dir/observability/production-readiness.conf"
assert_nonzero "manifest outside a Git worktree is rejected"
assert_output_contains "manifest outside a Git worktree has diagnostic" '(Git worktree|repository root)'

poison_repo="$TMP_ROOT/poison-repo"
mkdir -p "$poison_repo"
git -C "$poison_repo" init -q
poison_git_dir="$(git -C "$poison_repo" rev-parse --absolute-git-dir)"
run_validator_poisoned "$non_git_dir/observability/production-readiness.conf" "$poison_git_dir" "$non_git_dir"
assert_nonzero "non-Git manifest rejects poisoned Git repository selection"
assert_output_contains "poisoned non-Git manifest has diagnostic" '(Git worktree|repository root)'

# Workflow contracts are bounded to their owning YAML sections so unrelated
# keys cannot satisfy security-sensitive assertions.
READINESS_ON="$TMP_ROOT/readiness-on.yml"
READINESS_PR="$TMP_ROOT/readiness-pull-request.yml"
READINESS_PUSH="$TMP_ROOT/readiness-push.yml"
READINESS_PERMISSIONS="$TMP_ROOT/readiness-permissions.yml"
READINESS_CONCURRENCY="$TMP_ROOT/readiness-concurrency.yml"
READINESS_JOBS="$TMP_ROOT/readiness-jobs.yml"
READINESS_JOBS_NORMALIZED="$TMP_ROOT/readiness-jobs-normalized.yml"
READINESS_JOB="$TMP_ROOT/readiness-job.yml"
READINESS_NORMALIZED="$TMP_ROOT/readiness-normalized.yml"
READINESS_JOB_NORMALIZED="$TMP_ROOT/readiness-job-normalized.yml"
READINESS_CHECKOUT="$TMP_ROOT/readiness-checkout.yml"
READINESS_VALIDATE="$TMP_ROOT/readiness-validate.yml"
READINESS_RUN_NODES="$TMP_ROOT/readiness-run-nodes.yml"
READINESS_EXECUTABLE="$TMP_ROOT/readiness-executable.txt"

extract_yaml_block "$READINESS_WORKFLOW" "$READINESS_ON" 'on:' 0
extract_yaml_block "$READINESS_ON" "$READINESS_PR" '  pull_request:' 2
extract_yaml_block "$READINESS_ON" "$READINESS_PUSH" '  push:' 2
extract_yaml_block "$READINESS_WORKFLOW" "$READINESS_PERMISSIONS" 'permissions:' 0
extract_yaml_block "$READINESS_WORKFLOW" "$READINESS_CONCURRENCY" 'concurrency:' 0
extract_yaml_block "$READINESS_WORKFLOW" "$READINESS_JOBS" 'jobs:' 0
normalize_yaml_mapping_keys "$READINESS_JOBS" "$READINESS_JOBS_NORMALIZED"
extract_yaml_block "$READINESS_WORKFLOW" "$READINESS_JOB" '  readiness:' 2
normalize_yaml_mapping_keys "$READINESS_WORKFLOW" "$READINESS_NORMALIZED"
normalize_yaml_mapping_keys "$READINESS_JOB" "$READINESS_JOB_NORMALIZED"
extract_yaml_block "$READINESS_JOB" "$READINESS_CHECKOUT" '      - name: Checkout' 6
extract_yaml_block "$READINESS_JOB" "$READINESS_VALIDATE" '      - name: Validate production-readiness contract' 6
extract_run_nodes "$READINESS_VALIDATE" "$READINESS_RUN_NODES"
extract_executable_lines "$READINESS_RUN_NODES" "$READINESS_EXECUTABLE"

assert_file_exists "production-readiness workflow exists" "$READINESS_WORKFLOW"
assert_file_contains "readiness pull_request targets main" "$READINESS_PR" '^    branches: \[main\]$'
assert_file_contains "readiness push targets main" "$READINESS_PUSH" '^    branches: \[main\]$'
readiness_triggers="$(direct_yaml_keys "$READINESS_ON" 2)"
assert_eq "readiness triggers are exact" "$readiness_triggers" "$(printf '%s\n' pull_request push workflow_dispatch)"
assert_file_contains "readiness workflow_dispatch exists" "$READINESS_ON" '^  workflow_dispatch:$'
assert_file_not_contains "readiness schedule is absent" "$READINESS_ON" '^  schedule:'
assert_file_not_contains "readiness pull_request_target is absent" "$READINESS_ON" '^  pull_request_target:'
readiness_permission_keys="$(direct_yaml_keys "$READINESS_PERMISSIONS" 2)"
assert_eq "readiness workflow permission keys are exact" "$readiness_permission_keys" 'contents'
assert_file_contains "readiness workflow permissions are read-only" "$READINESS_PERMISSIONS" '^  contents: read$'
assert_file_not_contains "readiness workflow has no write permission" "$READINESS_PERMISSIONS" ':[[:space:]]*write$'
assert_file_not_contains "readiness has no write permission anywhere" "$READINESS_NORMALIZED" "$WRITE_PERMISSION_PATTERN"
readiness_job_names="$(direct_yaml_keys "$READINESS_JOBS_NORMALIZED" 2)"
assert_eq "readiness has exactly one approved job" "$readiness_job_names" 'readiness'
assert_file_not_contains "readiness job cannot override workflow permissions" "$READINESS_JOB_NORMALIZED" '^    permissions:'
assert_file_contains_fixed "readiness concurrency isolates PR or ref" "$READINESS_CONCURRENCY" 'github.event.pull_request.number || github.ref'
assert_file_contains "readiness concurrency cancels superseded runs" "$READINESS_CONCURRENCY" '^  cancel-in-progress: true$'
assert_file_contains "readiness job has contract check name" "$READINESS_JOB" '^    name: Production-readiness contract$'
assert_file_contains "readiness job timeout is bounded" "$READINESS_JOB" '^    timeout-minutes: 10$'
assert_file_contains_fixed "readiness checkout is SHA pinned" "$READINESS_CHECKOUT" 'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1'
assert_file_contains "readiness checkout does not persist credentials" "$READINESS_CHECKOUT" '^          persist-credentials: false$'
assert_file_has_exact_line "readiness validation runs canonical Make target" "$READINESS_EXECUTABLE" 'result="$(make readiness-check)"'
assert_file_has_exact_line "readiness validation writes step summary" "$READINESS_EXECUTABLE" '} >> "$GITHUB_STEP_SUMMARY"'
assert_file_not_contains "readiness does not suppress failures" "$READINESS_WORKFLOW" '^[[:space:]]*continue-on-error:'

ROLLBACK_ON="$TMP_ROOT/rollback-on.yml"
ROLLBACK_DISPATCH="$TMP_ROOT/rollback-dispatch.yml"
ROLLBACK_INPUTS="$TMP_ROOT/rollback-inputs.yml"
ROLLBACK_ENVIRONMENT_INPUT="$TMP_ROOT/rollback-environment-input.yml"
ROLLBACK_RELEASE_INPUT="$TMP_ROOT/rollback-release-input.yml"
ROLLBACK_DIGEST_INPUT="$TMP_ROOT/rollback-digest-input.yml"
ROLLBACK_REASON_INPUT="$TMP_ROOT/rollback-reason-input.yml"
ROLLBACK_CONFIRM_INPUT="$TMP_ROOT/rollback-confirm-input.yml"
ROLLBACK_OPTIONS="$TMP_ROOT/rollback-environment-options.yml"
ROLLBACK_PERMISSIONS="$TMP_ROOT/rollback-permissions.yml"
ROLLBACK_CONCURRENCY="$TMP_ROOT/rollback-concurrency.yml"
ROLLBACK_JOBS="$TMP_ROOT/rollback-jobs.yml"
ROLLBACK_JOBS_NORMALIZED="$TMP_ROOT/rollback-jobs-normalized.yml"
ROLLBACK_JOB="$TMP_ROOT/rollback-job.yml"
ROLLBACK_STEPS="$TMP_ROOT/rollback-steps.yml"
ROLLBACK_NORMALIZED="$TMP_ROOT/rollback-normalized.yml"
ROLLBACK_JOB_PERMISSIONS="$TMP_ROOT/rollback-job-permissions.yml"
ROLLBACK_VALIDATE="$TMP_ROOT/rollback-validate.yml"
ROLLBACK_ENV="$TMP_ROOT/rollback-env.yml"
ROLLBACK_VALIDATE_RUN_NODES="$TMP_ROOT/rollback-validate-run-nodes.yml"
ROLLBACK_VALIDATE_EXECUTABLE="$TMP_ROOT/rollback-validate-executable.txt"
ROLLBACK_UNWIRED="$TMP_ROOT/rollback-unwired.yml"
ROLLBACK_UNWIRED_RUN_NODES="$TMP_ROOT/rollback-unwired-run-nodes.yml"
ROLLBACK_UNWIRED_EXECUTABLE="$TMP_ROOT/rollback-unwired-executable.txt"
ROLLBACK_ALL_RUN_NODES="$TMP_ROOT/rollback-all-run-nodes.yml"

extract_yaml_block "$ROLLBACK_WORKFLOW" "$ROLLBACK_ON" 'on:' 0
extract_yaml_block "$ROLLBACK_ON" "$ROLLBACK_DISPATCH" '  workflow_dispatch:' 2
extract_yaml_block "$ROLLBACK_DISPATCH" "$ROLLBACK_INPUTS" '    inputs:' 4
extract_yaml_block "$ROLLBACK_INPUTS" "$ROLLBACK_ENVIRONMENT_INPUT" '      environment:' 6
extract_yaml_block "$ROLLBACK_INPUTS" "$ROLLBACK_RELEASE_INPUT" '      release_ref:' 6
extract_yaml_block "$ROLLBACK_INPUTS" "$ROLLBACK_DIGEST_INPUT" '      artifact_digest:' 6
extract_yaml_block "$ROLLBACK_INPUTS" "$ROLLBACK_REASON_INPUT" '      reason:' 6
extract_yaml_block "$ROLLBACK_INPUTS" "$ROLLBACK_CONFIRM_INPUT" '      confirm:' 6
extract_yaml_block "$ROLLBACK_ENVIRONMENT_INPUT" "$ROLLBACK_OPTIONS" '        options:' 8
extract_yaml_block "$ROLLBACK_WORKFLOW" "$ROLLBACK_PERMISSIONS" 'permissions:' 0
extract_yaml_block "$ROLLBACK_WORKFLOW" "$ROLLBACK_CONCURRENCY" 'concurrency:' 0
extract_yaml_block "$ROLLBACK_WORKFLOW" "$ROLLBACK_JOBS" 'jobs:' 0
normalize_yaml_mapping_keys "$ROLLBACK_JOBS" "$ROLLBACK_JOBS_NORMALIZED"
extract_yaml_block "$ROLLBACK_WORKFLOW" "$ROLLBACK_JOB" '  rollback:' 2
extract_yaml_block "$ROLLBACK_JOB" "$ROLLBACK_STEPS" '    steps:' 4
normalize_yaml_mapping_keys "$ROLLBACK_WORKFLOW" "$ROLLBACK_NORMALIZED"
extract_yaml_block "$ROLLBACK_JOB" "$ROLLBACK_JOB_PERMISSIONS" '    permissions:' 4
extract_yaml_block "$ROLLBACK_JOB" "$ROLLBACK_VALIDATE" '      - name: Validate rollback request' 6
extract_yaml_block "$ROLLBACK_VALIDATE" "$ROLLBACK_ENV" '        env:' 8
extract_run_nodes "$ROLLBACK_VALIDATE" "$ROLLBACK_VALIDATE_RUN_NODES"
extract_executable_lines "$ROLLBACK_VALIDATE_RUN_NODES" "$ROLLBACK_VALIDATE_EXECUTABLE"
extract_yaml_block "$ROLLBACK_JOB" "$ROLLBACK_UNWIRED" '      - name: Refuse unwired rollback' 6
extract_run_nodes "$ROLLBACK_UNWIRED" "$ROLLBACK_UNWIRED_RUN_NODES"
extract_executable_lines "$ROLLBACK_UNWIRED_RUN_NODES" "$ROLLBACK_UNWIRED_EXECUTABLE"
extract_run_nodes "$ROLLBACK_WORKFLOW" "$ROLLBACK_ALL_RUN_NODES"

assert_file_exists "rollback workflow exists" "$ROLLBACK_WORKFLOW"
rollback_triggers="$(direct_yaml_keys "$ROLLBACK_ON" 2)"
assert_eq "rollback workflow_dispatch is the only trigger" "$rollback_triggers" 'workflow_dispatch'
rollback_input_names="$(direct_yaml_keys "$ROLLBACK_INPUTS" 6)"
assert_eq "rollback inputs are exact" "$rollback_input_names" "$(printf '%s\n' environment release_ref artifact_digest reason confirm)"
assert_file_contains "rollback environment input is required" "$ROLLBACK_ENVIRONMENT_INPUT" '^        required: true$'
assert_file_contains "rollback environment input is a choice" "$ROLLBACK_ENVIRONMENT_INPUT" '^        type: choice$'
rollback_environment_options="$(sed -n 's/^[[:space:]]*- //p' "$ROLLBACK_OPTIONS" 2>/dev/null || true)"
assert_eq "rollback environment options are exact" "$rollback_environment_options" "$(printf '%s\n' development staging production)"
assert_file_contains "rollback release_ref input is required" "$ROLLBACK_RELEASE_INPUT" '^        required: true$'
assert_file_contains "rollback artifact_digest input is required" "$ROLLBACK_DIGEST_INPUT" '^        required: true$'
assert_file_contains "rollback reason input is required" "$ROLLBACK_REASON_INPUT" '^        required: true$'
assert_file_contains "rollback confirm input is required" "$ROLLBACK_CONFIRM_INPUT" '^        required: true$'
rollback_permission_keys="$(direct_yaml_keys "$ROLLBACK_PERMISSIONS" 2)"
assert_eq "rollback workflow permission keys are exact" "$rollback_permission_keys" 'contents'
assert_file_contains "rollback workflow permissions are read-only" "$ROLLBACK_PERMISSIONS" '^  contents: read$'
assert_file_not_contains "rollback has no write permission anywhere" "$ROLLBACK_NORMALIZED" "$WRITE_PERMISSION_PATTERN"
rollback_job_names="$(direct_yaml_keys "$ROLLBACK_JOBS_NORMALIZED" 2)"
assert_eq "rollback has exactly one approved job" "$rollback_job_names" 'rollback'
rollback_step_names="$(direct_step_entries "$ROLLBACK_STEPS")"
assert_eq "rollback has exactly two ordered validation and refusal steps" "$rollback_step_names" "$(printf '%s\n' 'Validate rollback request' 'Refuse unwired rollback')"
rollback_job_permission_keys="$(direct_yaml_keys "$ROLLBACK_JOB_PERMISSIONS" 6)"
assert_eq "rollback job permission keys are exact" "$rollback_job_permission_keys" 'contents'
assert_file_contains "rollback job permissions are read-only" "$ROLLBACK_JOB_PERMISSIONS" '^      contents: read$'
assert_file_contains_fixed "rollback job binds selected environment" "$ROLLBACK_JOB" 'environment: ${{ inputs.environment }}'
assert_file_contains_fixed "rollback concurrency is per environment" "$ROLLBACK_CONCURRENCY" 'inputs.environment'
assert_file_contains "rollback concurrency does not cancel requests" "$ROLLBACK_CONCURRENCY" '^  cancel-in-progress: false$'
assert_file_contains "rollback job timeout is bounded" "$ROLLBACK_JOB" '^    timeout-minutes: 5$'
assert_file_not_contains "rollback job and steps are unconditional" "$ROLLBACK_JOB" '^[[:space:]]*if:'
assert_file_not_contains "rollback sentinel step is unconditional" "$ROLLBACK_UNWIRED" '^[[:space:]]*if:'
assert_file_not_contains "rollback has no id-token permission" "$ROLLBACK_WORKFLOW" '^[[:space:]]*id-token:'
assert_file_not_contains "rollback has no attestations permission" "$ROLLBACK_WORKFLOW" '^[[:space:]]*attestations:'
assert_file_not_contains "rollback has no security-events permission" "$ROLLBACK_WORKFLOW" '^[[:space:]]*security-events:'
assert_file_not_contains "rollback has no secrets expressions" "$ROLLBACK_WORKFLOW" '\$\{\{[[:space:]]*secrets\.'
assert_file_not_contains "rollback has no checkout" "$ROLLBACK_WORKFLOW" 'actions/checkout@'
assert_file_not_contains "rollback has no Actions uses" "$ROLLBACK_WORKFLOW" '^[[:space:]]*-?[[:space:]]*uses:'
assert_file_not_contains "rollback has no services" "$ROLLBACK_WORKFLOW" '^[[:space:]]*services:'
assert_file_not_contains "rollback has no container" "$ROLLBACK_WORKFLOW" '^[[:space:]]*container:'
assert_file_contains_fixed "rollback maps environment input through step env" "$ROLLBACK_ENV" 'ROLLBACK_ENVIRONMENT: ${{ inputs.environment }}'
assert_file_contains_fixed "rollback maps release_ref input through step env" "$ROLLBACK_ENV" 'ROLLBACK_RELEASE_REF: ${{ inputs.release_ref }}'
assert_file_contains_fixed "rollback maps artifact_digest input through step env" "$ROLLBACK_ENV" 'ROLLBACK_ARTIFACT_DIGEST: ${{ inputs.artifact_digest }}'
assert_file_contains_fixed "rollback maps reason input through step env" "$ROLLBACK_ENV" 'ROLLBACK_REASON: ${{ inputs.reason }}'
assert_file_contains_fixed "rollback maps confirm input through step env" "$ROLLBACK_ENV" 'ROLLBACK_CONFIRM: ${{ inputs.confirm }}'
assert_file_not_contains "rollback run nodes do not interpolate inputs" "$ROLLBACK_ALL_RUN_NODES" '\$\{\{[[:space:]]*inputs\.'
assert_file_has_exact_line "rollback validates confirmation token" "$ROLLBACK_VALIDATE_EXECUTABLE" '[ "$ROLLBACK_CONFIRM" = ROLLBACK ] || {'
assert_file_has_exact_line "rollback validates approved release grammar" "$ROLLBACK_VALIDATE_EXECUTABLE" "grep -Eq '^([0-9a-f]{40}|v[0-9][0-9A-Za-z._-]*)$' || {"
assert_file_has_exact_line "rollback validates lowercase sha256 digest" "$ROLLBACK_VALIDATE_EXECUTABLE" "grep -Eq '^sha256:[0-9a-f]{64}$' || {"
assert_file_has_exact_line "rollback rejects whitespace-only reason" "$ROLLBACK_VALIDATE_EXECUTABLE" '*[![:space:]]*) ;;'
assert_file_content_equals "rollback validation body is exact" "$ROLLBACK_VALIDATE_EXECUTABLE" "$ROLLBACK_VALIDATION_EXPECTED"
assert_file_content_equals "rollback sentinel body is exact and unconditional" "$ROLLBACK_UNWIRED_EXECUTABLE" "$SENTINEL_EXPECTED"
assert_file_not_contains "rollback does not suppress failures" "$ROLLBACK_WORKFLOW" '^[[:space:]]*continue-on-error:'
assert_file_not_contains "rollback pull_request_target is absent" "$ROLLBACK_ON" '^  pull_request_target:'

report
