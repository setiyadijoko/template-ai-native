#!/usr/bin/env sh
# Structural contract for the advisory profile-required-controls orchestrator.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORKFLOW="$ROOT/.github/workflows/profile-required-controls.yml"
BRANCH_PROTECTION="$ROOT/scripts/setup-branch-protection.sh"
MAKEFILE="$ROOT/Makefile"
README="$ROOT/README.md"
GETTING_STARTED="$ROOT/docs/getting-started.md"
SCRIPTS_README="$ROOT/scripts/README.md"
ADR="$ROOT/docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md"
ROADMAP="$ROOT/docs/plans/roadmap.md"
TECHNICAL_DEBT="$ROOT/docs/plans/technical-debt.md"
CHANGELOG="$ROOT/CHANGELOG.md"
DESIGN_SPEC="$ROOT/docs/superpowers/specs/2026-08-12-profile-required-controls-advisory-design.md"
PROFILE_SCHEMA="$ROOT/.template/profile.schema.yaml"
PROFILE_CONTROLS="$ROOT/.template/profile-controls.yaml"
ADR_INDEX="$ROOT/docs/adr/README.md"
AGENT_GUIDANCE="$ROOT/AGENTS.md"
EVALUATION_STRATEGY="$ROOT/docs/ai/evaluation-strategy.md"
EVALS_README="$ROOT/evals/README.md"
AI_WORKFLOW="$ROOT/.github/workflows/ai-evaluation.yml"

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else PASS=$((PASS+1)); fi
}

assert_text_contains() {
  label="$1"; value="$2"; pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_text_not_contains() {
  label="$1"; value="$2"; pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else PASS=$((PASS+1)); fi
}

job_block() {
  file="$1"; job="$2"
  awk -v marker="  $job:" '
    $0 == marker { inside=1 }
    inside && $0 ~ /^  [a-z_]+:$/ && $0 != marker { exit }
    inside { print }
  ' "$file"
}

assert_action_pins() {
  invalid="$({
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$WORKFLOW" |
      sed '/^\.\//d' |
      grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}([[:space:]]+#.*)?$'
  } || true)"
  assert_eq "all third-party Actions are SHA-pinned" "$invalid" ""
}

if [ ! -f "$WORKFLOW" ]; then
  FAIL=$((FAIL+1))
  printf 'FAIL profile required controls workflow exists\n' >&2
  report
  exit 1
fi

on_block="$(sed -n '/^on:$/,/^permissions:$/p' "$WORKFLOW")"
permissions="$(sed -n '/^permissions:$/,/^$/p' "$WORKFLOW")"
plan="$(job_block "$WORKFLOW" plan)"
quality="$(job_block "$WORKFLOW" quality_unit)"
test_coverage="$(job_block "$WORKFLOW" test_coverage)"
monorepo="$(job_block "$WORKFLOW" monorepo_ci)"
secret="$(job_block "$WORKFLOW" secret_scan)"
dependency="$(job_block "$WORKFLOW" dependency_review)"
codeql="$(job_block "$WORKFLOW" codeql)"
ai="$(job_block "$WORKFLOW" ai_evaluation)"
aggregate="$(job_block "$WORKFLOW" aggregate)"

# Stable context, supported events, and workflow-level safety.
assert_contains "workflow name is exact" "$WORKFLOW" '^name: Profile policy$'
event_ids="$(printf '%s\n' "$on_block" | awk '
  /^  [a-z_]+:$/ { value=$0; sub(/^  /, "", value); sub(/:$/, "", value); print value }
')"
assert_eq "event trigger set is exact" "$event_ids" \
  "$(printf 'pull_request\npush\nworkflow_dispatch')"
assert_text_contains "pull requests enabled" "$on_block" '^  pull_request:$'
assert_text_contains "pull requests target main" "$on_block" '^    branches: \[main\]$'
assert_text_contains "pushes enabled" "$on_block" '^  push:$'
assert_eq "main branch appears for PR and push" \
  "$(printf '%s\n' "$on_block" | grep -Ec '^    branches: \[main\]$')" "2"
assert_text_contains "manual dispatch enabled" "$on_block" '^  workflow_dispatch:$'
assert_text_not_contains "events have no paths filter" "$on_block" 'paths:'
assert_not_contains "fork-safe event only" "$WORKFLOW" 'pull_request_target'
assert_eq "workflow permissions are exactly read-only" "$permissions" \
  "$(printf 'permissions:\n  contents: read')"
assert_contains "concurrency uses PR or ref identity" "$WORKFLOW" \
  "group: profile-policy-[$][{][{] github.event.pull_request.number \|\| github.ref \|\| github.run_id [}][}]"
assert_contains "stale runs cancel" "$WORKFLOW" '^  cancel-in-progress: true$'
assert_not_contains "workflow consumes no reusable secrets" "$WORKFLOW" 'secrets:'
assert_not_contains "required failure is never masked" "$WORKFLOW" 'continue-on-error'
assert_action_pins

# Exact top-level job contract.
job_ids="$(awk '
  /^jobs:$/ { inside=1; next }
  inside && /^  [a-z_]+:$/ { value=$0; sub(/^  /, "", value); sub(/:$/, "", value); print value }
' "$WORKFLOW")"
assert_eq "job IDs are exact and stable" "$job_ids" \
  "$(printf 'plan\nquality_unit\ntest_coverage\nmonorepo_ci\nsecret_scan\ndependency_review\ncodeql\nai_evaluation\naggregate')"
assert_contains "aggregate context pair is unique" /dev/stdin '^2$' <<EOF
$(awk '/^(name: Profile policy|    name: Required controls)$/ { count++ } END { print count + 0 }' "$ROOT"/.github/workflows/*.yml)
EOF
assert_contains "branch protection recommends stable aggregate" "$BRANCH_PROTECTION" \
  "required_status_checks\[contexts\]\[\]=Required controls"
assert_not_contains "branch protection excludes UI-style aggregate label" \
  "$BRANCH_PROTECTION" 'required_status_checks\[contexts\]\[\]=Profile policy / Required controls'

# Plan job: deterministic resolver, credential-free checkout, and bounded outputs.
assert_text_contains "plan has short timeout" "$plan" 'timeout-minutes: 5'
assert_text_contains "plan checkout is pinned" "$plan" \
  'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7\.0\.1'
assert_text_contains "plan disables persisted credentials" "$plan" 'persist-credentials: false'
assert_text_contains "plan uses resolver" "$plan" \
  'sh scripts/resolve-profile-execution-plan\.sh > "[$]report"'
assert_text_contains "plan report stays in runner temp" "$plan" \
  'report="[$][{]RUNNER_TEMP[}]/profile-execution-plan\.txt"'
assert_text_contains "plan prints normalized report" "$plan" 'cat "[$]report"'
assert_text_contains "plan exact-key helper rejects duplicates" "$plan" 'count != 1'
assert_text_contains "plan validates output values against allowlist" "$plan" 'allowed'
assert_text_not_contains "plan avoids AWK allowlist membership" "$plan" \
  '\| awk -v candidate='
assert_text_contains "plan compares each allowed shell token exactly" "$plan" \
  'for allowed_value in [$]allowed; do'
assert_text_contains "plan uses a quoted exact shell comparison" "$plan" \
  'if \[ "[$]value" = "[$]allowed_value" \]; then'
assert_text_contains "plan writes only via GITHUB_OUTPUT" "$plan" \
  '>> "[$]GITHUB_OUTPUT"'

for output in mode profile layout stack \
  quality_unit_decision quality_unit_required \
  test_coverage_decision test_coverage_required \
  monorepo_ci_decision monorepo_ci_required \
  secret_scan_decision secret_scan_required \
  dependency_review_decision dependency_review_required \
  codeql_decision codeql_required \
  ai_evaluation_decision ai_evaluation_required; do
  assert_text_contains "plan exposes $output" "$plan" \
    "^      ${output}: [$][{][{] steps.resolve.outputs.${output} [}][}]$"
done

# Each executable boundary is plan-gated, local, secret-free, and channel-isolated.
for tuple in \
  "quality_unit|ci-quality.yml|quality_unit_decision" \
  "test_coverage|ci-test.yml|test_coverage_decision" \
  "monorepo_ci|ci-monorepo.yml|monorepo_ci_decision" \
  "secret_scan|secret-scan.yml|secret_scan_decision" \
  "dependency_review|dependency-review.yml|dependency_review_decision" \
  "codeql|codeql.yml|codeql_decision" \
  "ai_evaluation|ai-evaluation.yml|ai_evaluation_decision"; do
  job="${tuple%%|*}"
  rest="${tuple#*|}"
  workflow="${rest%%|*}"
  decision="${rest#*|}"
  block="$(job_block "$WORKFLOW" "$job")"
  assert_text_contains "$job depends on plan" "$block" '^    needs: plan$'
  assert_text_contains "$job is gated by plan decision" "$block" \
    "if: needs.plan.outputs.${decision} == 'run'"
  assert_text_contains "$job calls canonical boundary" "$block" \
    "uses: ./\.github/workflows/${workflow}"
  assert_text_contains "$job uses literal advisory channel" "$block" \
    '^      execution_channel: profile-advisory$'
  assert_text_not_contains "$job has no inherited secrets" "$block" 'secrets:'
done
assert_text_contains "quality receives detected stack" "$quality" \
  'stack: [$][{][{] needs.plan.outputs.stack [}][}]'
assert_text_contains "test receives detected stack" "$test_coverage" \
  'stack: [$][{][{] needs.plan.outputs.stack [}][}]'
assert_text_not_contains "monorepo receives no synthetic stack" "$monorepo" 'stack:'
assert_text_contains "CodeQL caller retains contents read" "$codeql" '^      contents: read$'
assert_text_contains "CodeQL caller alone receives security write" "$codeql" \
  '^      security-events: write$'
for block in "$plan" "$quality" "$test_coverage" "$monorepo" "$secret" "$dependency" "$ai" "$aggregate"; do
  assert_text_not_contains "non-CodeQL job has no write permission" "$block" ': write'
done
assert_eq "only CodeQL caller has orchestrator write permission" \
  "$(grep -Ec '^[[:space:]]+security-events: write$' "$WORKFLOW")" "1"

# Aggregate always materializes all conclusions and fails closed through evaluator.
assert_text_contains "aggregate name is exact" "$aggregate" '^    name: Required controls$'
assert_text_contains "aggregate always runs" "$aggregate" '^    if: always[(][)]$'
assert_text_contains "aggregate depends on all jobs" "$aggregate" \
  '^    needs: \[plan, quality_unit, test_coverage, monorepo_ci, secret_scan, dependency_review, codeql, ai_evaluation\]$'
assert_text_contains "aggregate checkout is pinned" "$aggregate" \
  'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7\.0\.1'
assert_text_contains "aggregate checkout disables credentials" "$aggregate" 'persist-credentials: false'
assert_text_contains "aggregate receives plan conclusion as data" "$aggregate" \
  'PLAN_RESULT: [$][{][{] needs.plan.result [}][}]'
for job in quality_unit test_coverage monorepo_ci secret_scan dependency_review codeql ai_evaluation; do
  upper="$(printf '%s' "$job" | tr '[:lower:]' '[:upper:]')"
  assert_text_contains "aggregate receives $job result as data" "$aggregate" \
    "${upper}_RESULT: [$][{][{] needs.${job}.result [}][}]"
  assert_text_contains "aggregate writes $job fixed outcome" "$aggregate" \
    "boundary[.]${job}[.]conclusion=%s"
done
for boundary in sbom artifact_attestation scorecard semantic_review structural_review production_governance; do
  assert_text_contains "aggregate marks $boundary skipped" "$aggregate" \
    "boundary[.]${boundary}[.]conclusion=skipped"
done
assert_text_contains "aggregate checks plan result before evaluation" "$aggregate" \
  'if \[ "[$]PLAN_RESULT" != success \]; then'
assert_text_contains "failed plan writes a diagnostic" "$aggregate" 'profile plan failed'
assert_text_contains "failed plan records conclusion" "$aggregate" 'plan[.]conclusion=%s'
assert_text_contains "failed plan exits non-zero" "$aggregate" 'exit 1'
assert_text_contains "aggregate reruns deterministic plan" "$aggregate" \
  'sh scripts/resolve-profile-execution-plan[.]sh > "[$]report"'
for field in mode profile layout stack; do
  upper="$(printf '%s' "$field" | tr '[:lower:]' '[:upper:]')"
  assert_text_contains "aggregate compares $field identity" "$aggregate" \
    "assert_identity ${field} \"[$]PLAN_${upper}\""
done
assert_text_contains "aggregate invokes fail-closed evaluator" "$aggregate" \
  'sh scripts/evaluate-profile-required-controls[.]sh "[$]report" "[$]outcomes"'
assert_text_contains "aggregate publishes normalized plan" "$aggregate" '## Normalized execution plan'
assert_text_contains "aggregate publishes outcomes" "$aggregate" '## Boundary conclusions'
assert_text_contains "aggregate publishes evaluator report" "$aggregate" '## Advisory aggregate verdict'
assert_text_contains "aggregate appends Job Summary" "$aggregate" '>> "[$]GITHUB_STEP_SUMMARY"'

assert_contains "Makefile runs workflow contract" "$MAKEFILE" \
  '@sh scripts/test/test-profile-required-controls-workflow[.]sh'

# Consumer and governance guidance must distinguish the helper recommendation
# from repository-level enforcement and later duplicate-path removal.
for document in "$README" "$GETTING_STARTED" "$ADR" "$ROADMAP" "$TECHNICAL_DEBT" "$CHANGELOG"; do
  assert_contains "$(basename "$document") names the stable aggregate" "$document" \
    'Profile policy / Required controls'
done
assert_contains "README labels the aggregate advisory" "$README" 'advisory'
assert_contains "getting started labels the aggregate advisory" "$GETTING_STARTED" 'advisory'
assert_contains "getting started explains duplicate baseline execution" "$GETTING_STARTED" \
  'duplicate baseline'
assert_contains "getting started states protected-consumer gate" "$GETTING_STARTED" \
  'protected disposable consumer'
assert_contains "README shows local profile policy command" "$README" \
  'make profile-policy-check'
assert_contains "README shows execution plan command" "$README" \
  'sh scripts/resolve-profile-execution-plan[.]sh'
assert_contains "scripts README documents execution plan resolver" "$SCRIPTS_README" \
  'resolve-profile-execution-plan[.]sh'
assert_contains "scripts README documents aggregate evaluator" "$SCRIPTS_README" \
  'evaluate-profile-required-controls[.]sh'
assert_contains "ADR status records helper recommendation" "$ADR" \
  '^\- \*\*Status:\*\* Accepted — helper recommendation implemented; repository application owner-controlled$'
assert_contains "roadmap marks local advisory implementation complete" "$ROADMAP" \
  'Local advisory implementation is complete'
assert_contains "roadmap records exact aggregate check-run name" "$ROADMAP" \
  'exact check-run name, `Required controls`'
assert_contains "technical debt records exact aggregate check-run name" "$TECHNICAL_DEBT" \
  'exact `Required controls` check-run name'
assert_contains "changelog records advisory aggregate" "$CHANGELOG" \
  'advisory `Profile policy / Required controls` aggregate'
assert_contains "design spec records implementation status" "$DESIGN_SPEC" \
  '^\*\*Status:\*\* Implemented locally — hosted enforcement evidence pending$'

# Current-state guidance must distinguish advisory execution from later
# enforcement and must distinguish reusable deterministic AI evaluation from
# the direct secret-gated provider path.
assert_contains "scripts README says generated profiles select advisory jobs" "$SCRIPTS_README" \
  'Profile values select reusable jobs in the advisory aggregate'
assert_not_contains "scripts README does not claim profiles activate nothing" "$SCRIPTS_README" \
  'Profile values do not activate workflows'
assert_contains "getting started says initializer output selects advisory jobs" "$GETTING_STARTED" \
  'Generated profile values select reusable jobs in the advisory aggregate'
assert_not_contains "getting started does not claim controls stay inactive" "$GETTING_STARTED" \
  'does not create credentials, change workflows, or activate profile-aware controls'
assert_contains "getting started distinguishes deterministic and provider AI paths" "$GETTING_STARTED" \
  'Reusable deterministic checks run without credentials; direct provider-backed evaluation remains secret-gated'
assert_contains "profile schema comment records advisory selection" "$PROFILE_SCHEMA" \
  'select advisory aggregate jobs'
assert_contains "profile controls comment records advisory selection" "$PROFILE_CONTROLS" \
  'select advisory aggregate jobs'
assert_contains "ADR index records helper recommendation" "$ADR_INDEX" \
  'Accepted — helper recommendation implemented; repository application owner-controlled'
assert_contains "changelog records profile-selected advisory execution" "$CHANGELOG" \
  'Profile values now select reusable jobs in the advisory aggregate'
assert_not_contains "changelog no longer claims profile workflows are entirely inactive" "$CHANGELOG" \
  'Profile files do not activate workflows yet'
assert_contains "canonical guidance distinguishes AI execution modes" "$AGENT_GUIDANCE" \
  'reusable deterministic mode runs `--check` without a credential or provider call'
assert_contains "evaluation strategy distinguishes AI execution modes" "$EVALUATION_STRATEGY" \
  'reusable deterministic path runs `--check` without credentials or a provider call'
assert_contains "evals README says deterministic advisory path is active" "$EVALS_README" \
  'advisory aggregate runs this deterministic path without credentials'
assert_contains "AI workflow header documents reusable deterministic mode" "$AI_WORKFLOW" \
  'Reusable advisory mode always runs the deterministic `--check` contract'
assert_contains "AI workflow header documents direct secret gate" "$AI_WORKFLOW" \
  'Direct event mode remains secret-gated'

# Execute the embedded plan step against adversarial reports. Each compound
# candidate is made entirely from adjacent allowed values, so substring
# matching would accept it even though it is not one exact enum/Boolean.
PLAN_TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/profile-required-controls-workflow.XXXXXX")"
trap 'rm -rf "$PLAN_TEST_TMP"' EXIT HUP INT TERM
PLAN_STEP_SCRIPT="$PLAN_TEST_TMP/plan-step.sh"
printf '%s\n' "$plan" | awk '
  /^        run: \|$/ { inside=1; next }
  inside { sub(/^          /, ""); print }
' > "$PLAN_STEP_SCRIPT"

FIXTURE_ROOT="$PLAN_TEST_TMP/fixture"
mkdir -p "$FIXTURE_ROOT/scripts"
printf '%s\n' '#!/usr/bin/env sh' "cat \"\$FAKE_PLAN_REPORT\"" \
  > "$FIXTURE_ROOT/scripts/resolve-profile-execution-plan.sh"
chmod +x "$FIXTURE_ROOT/scripts/resolve-profile-execution-plan.sh"

BASE_PLAN="$PLAN_TEST_TMP/base-plan.txt"
cat > "$BASE_PLAN" <<'EOF'
mode=compatibility
profile=none
layout=unknown
stack=unknown
boundary.quality_unit.decision=delegated-to-current-baseline
boundary.quality_unit.required=false
boundary.test_coverage.decision=delegated-to-current-baseline
boundary.test_coverage.required=false
boundary.monorepo_ci.decision=delegated-to-current-baseline
boundary.monorepo_ci.required=false
boundary.secret_scan.decision=delegated-to-current-baseline
boundary.secret_scan.required=false
boundary.dependency_review.decision=delegated-to-current-baseline
boundary.dependency_review.required=false
boundary.codeql.decision=delegated-to-current-baseline
boundary.codeql.required=false
boundary.ai_evaluation.decision=delegated-to-current-baseline
boundary.ai_evaluation.required=false
EOF

assert_compound_value_rejected() {
  label="$1"
  key="$2"
  compound="$3"
  report_file="$PLAN_TEST_TMP/$label-report.txt"
  output_file="$PLAN_TEST_TMP/$label-output.txt"
  stdout_file="$PLAN_TEST_TMP/$label-stdout.txt"
  stderr_file="$PLAN_TEST_TMP/$label-stderr.txt"

  awk -F '=' -v key="$key" -v compound="$compound" '
    BEGIN { OFS="=" }
    $1 == key { $2=compound }
    { print }
  ' "$BASE_PLAN" > "$report_file"
  : > "$output_file"

  set +e
  (
    cd "$FIXTURE_ROOT"
    FAKE_PLAN_REPORT="$report_file" \
      RUNNER_TEMP="$PLAN_TEST_TMP" \
      GITHUB_OUTPUT="$output_file" \
      sh "$PLAN_STEP_SCRIPT"
  ) > "$stdout_file" 2> "$stderr_file"
  actual_exit=$?
  set -e

  if [ "$actual_exit" -ne 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s compound candidate exits nonzero\n' "$label" >&2
  fi
  if grep -Fq -- "=$compound" "$output_file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s compound candidate is not written to GITHUB_OUTPUT\n' "$label" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_compound_value_rejected profile profile 'starter standard'
assert_compound_value_rejected boolean boundary.quality_unit.required 'true false'
assert_compound_value_rejected decision boundary.quality_unit.decision 'run planned-skip'
assert_compound_value_rejected stack stack 'python node'

report
