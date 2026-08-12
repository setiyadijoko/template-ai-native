#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

EVALUATOR="$ROOT/scripts/evaluate-profile-required-controls.sh"
BOUNDARIES='quality_unit test_coverage monorepo_ci secret_scan dependency_review codeql ai_evaluation sbom artifact_attestation scorecard semantic_review structural_review production_governance'
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-evaluator.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

assert_contains() {
  label="$1"; output="$2"; pattern="$3"
  if printf '%s\n' "$output" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_count() {
  label="$1"; output="$2"; pattern="$3"; expected="$4"
  actual="$(printf '%s\n' "$output" | grep -Ec -- "$pattern" || true)"
  assert_eq "$label" "$actual" "$expected"
}

write_plan() {
  path="$1"; decision="$2"; required="$3"; reason="${4:-required-by-profile}"
  {
    printf 'mode=profile\nprofile=standard\nlayout=single\nstack=python\nstatus=ready\n'
    for boundary in $BOUNDARIES; do
      if [ "$boundary" = quality_unit ]; then
        printf 'boundary.%s.decision=%s\n' "$boundary" "$decision"
        printf 'boundary.%s.required=%s\n' "$boundary" "$required"
        printf 'boundary.%s.reason=%s\n' "$boundary" "$reason"
      else
        printf 'boundary.%s.decision=planned-skip\n' "$boundary"
        printf 'boundary.%s.required=false\n' "$boundary"
        printf 'boundary.%s.reason=disabled-by-profile\n' "$boundary"
      fi
    done
  } > "$path"
}

write_outcomes() {
  path="$1"; conclusion="$2"
  {
    for boundary in $BOUNDARIES; do
      if [ "$boundary" = quality_unit ]; then
        printf 'boundary.%s.conclusion=%s\n' "$boundary" "$conclusion"
      else
        printf 'boundary.%s.conclusion=skipped\n' "$boundary"
      fi
    done
  } > "$path"
}

assert_case() {
  case_name="$1"; decision="$2"; required="$3"; conclusion="$4"; expected_exit="$5"; expected_verdict="$6"
  plan="$WORK/$case_name.plan"
  outcomes="$WORK/$case_name.outcomes"
  write_plan "$plan" "$decision" "$required"
  write_outcomes "$outcomes" "$conclusion"
  set +e
  output="$(sh "$EVALUATOR" "$plan" "$outcomes" 2>"$WORK/$case_name.stderr")"
  actual_exit=$?
  set -e
  assert_eq "$case_name exit" "$actual_exit" "$expected_exit"
  case "$expected_exit" in 0) expected_status=pass ;; 1) expected_status=fail ;; esac
  assert_contains "$case_name aggregate" "$output" "^aggregate.status=$expected_status$"
  assert_contains "$case_name verdict" "$output" "^boundary\\.quality_unit\\.verdict=$expected_verdict$"
  assert_contains "$case_name detail" "$output" '^boundary\.quality_unit\.detail=required-by-profile$'
  assert_count "$case_name verdict records" "$output" '^boundary\.[a-z_]+\.verdict=' 13
  assert_count "$case_name detail records" "$output" '^boundary\.[a-z_]+\.detail=[a-z0-9][a-z0-9-]{0,63}$' 13
  assert_eq "$case_name stderr" "$(cat "$WORK/$case_name.stderr")" ''
}

assert_failure_prefix() {
  case_name="$1"; plan="$2"; outcomes="$3"
  set +e
  sh "$EVALUATOR" "$plan" "$outcomes" >"$WORK/$case_name.stdout" 2>"$WORK/$case_name.stderr"
  actual_exit=$?
  set -e
  assert_eq "$case_name exit" "$actual_exit" 1
  assert_eq "$case_name stdout" "$(cat "$WORK/$case_name.stdout")" ''
  stderr="$(cat "$WORK/$case_name.stderr")"
  case "$stderr" in
    profile-required-controls:*) PASS=$((PASS+1)) ;;
    *) FAIL=$((FAIL+1)); printf 'FAIL %s stderr prefix\n     actual: %s\n' "$case_name" "$stderr" >&2 ;;
  esac
}

assert_deterministic() {
  case_name="$1"; plan="$2"; outcomes="$3"; expected_exit="$4"
  set +e
  sh "$EVALUATOR" "$plan" "$outcomes" >"$WORK/$case_name.one.stdout" 2>"$WORK/$case_name.one.stderr"
  first_exit=$?
  sh "$EVALUATOR" "$plan" "$outcomes" >"$WORK/$case_name.two.stdout" 2>"$WORK/$case_name.two.stderr"
  second_exit=$?
  set -e
  assert_eq "$case_name first exit" "$first_exit" "$expected_exit"
  assert_eq "$case_name second exit" "$second_exit" "$expected_exit"
  if cmp -s "$WORK/$case_name.one.stdout" "$WORK/$case_name.two.stdout" \
    && cmp -s "$WORK/$case_name.one.stderr" "$WORK/$case_name.two.stderr"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s output is not byte-identical\n' "$case_name" >&2
  fi
}

# Decision/conclusion matrix. Every fixture contains all 13 boundaries.
assert_case required_success          run true  success   0 pass
assert_case required_failure          run true  failure   1 fail
assert_case required_cancelled        run true  cancelled 1 fail
assert_case required_skip             run true  skipped   1 fail
assert_case advisory_failure          run false failure   0 warning
assert_case planned_skip              planned-skip false skipped 0 planned
assert_case not_applicable            not-applicable false skipped 0 planned
assert_case compatibility_delegation  delegated-to-current-baseline false skipped 0 planned
assert_case policy_only               policy-only false skipped 0 planned
assert_case unexpected_execution      planned-skip false success 1 fail

# Both a passing and a failing result must be deterministic, including stdout,
# stderr, and exit status.
assert_deterministic required_success "$WORK/required_success.plan" "$WORK/required_success.outcomes" 0
assert_deterministic required_failure "$WORK/required_failure.plan" "$WORK/required_failure.outcomes" 1

valid_plan="$WORK/valid.plan"
valid_outcomes="$WORK/valid.outcomes"
write_plan "$valid_plan" run true
write_outcomes "$valid_outcomes" success

assert_failure_prefix missing-plan "$WORK/missing.plan" "$valid_outcomes"
assert_failure_prefix missing-outcomes "$valid_plan" "$WORK/missing.outcomes"
mkdir "$WORK/plan-directory" "$WORK/outcomes-directory"
assert_failure_prefix plan-directory "$WORK/plan-directory" "$valid_outcomes"
assert_failure_prefix outcomes-directory "$valid_plan" "$WORK/outcomes-directory"
ln -s "$valid_plan" "$WORK/plan-link"
ln -s "$valid_outcomes" "$WORK/outcomes-link"
assert_failure_prefix plan-symlink "$WORK/plan-link" "$valid_outcomes"
assert_failure_prefix outcomes-symlink "$valid_plan" "$WORK/outcomes-link"

printf 'mode=profile\n' >> "$valid_plan"
assert_failure_prefix duplicate-key "$valid_plan" "$valid_outcomes"
sed '$d' "$valid_plan" > "$WORK/valid.plan.next"
mv "$WORK/valid.plan.next" "$valid_plan"

printf 'boundary.unknown.conclusion=skipped\n' >> "$valid_outcomes"
assert_failure_prefix unknown-boundary "$valid_plan" "$valid_outcomes"
sed '$d' "$valid_outcomes" > "$WORK/valid.outcomes.next"
mv "$WORK/valid.outcomes.next" "$valid_outcomes"

sed '/^boundary\.quality_unit\.conclusion=/d' "$valid_outcomes" > "$WORK/missing.outcomes"
assert_failure_prefix missing-conclusion "$valid_plan" "$WORK/missing.outcomes"

sed 's/^boundary\.quality_unit\.decision=run$/boundary.quality_unit.decision=unknown/' "$valid_plan" > "$WORK/unknown-decision.plan"
assert_failure_prefix unknown-decision "$WORK/unknown-decision.plan" "$valid_outcomes"

sed 's/^boundary\.quality_unit\.required=true$/boundary.quality_unit.required=yes/' "$valid_plan" > "$WORK/invalid-boolean.plan"
assert_failure_prefix invalid-boolean "$WORK/invalid-boolean.plan" "$valid_outcomes"

sed 's/^boundary\.quality_unit\.conclusion=success$/boundary.quality_unit.conclusion=unknown/' "$valid_outcomes" > "$WORK/unknown-conclusion.outcomes"
assert_failure_prefix unknown-conclusion "$valid_plan" "$WORK/unknown-conclusion.outcomes"

sed '/^status=ready$/d' "$valid_plan" > "$WORK/missing-status.plan"
assert_failure_prefix missing-plan-status "$WORK/missing-status.plan" "$valid_outcomes"

sed 's/^boundary\.quality_unit\.reason=required-by-profile$/boundary.quality_unit.reason=invalid_reason/' "$valid_plan" > "$WORK/invalid-reason.plan"
assert_failure_prefix invalid-reason "$WORK/invalid-reason.plan" "$valid_outcomes"

printf 'unexpected=value\n' >> "$valid_plan"
assert_failure_prefix unknown-plan-key "$valid_plan" "$valid_outcomes"

report
