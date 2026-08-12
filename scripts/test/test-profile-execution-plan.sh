#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

PLAN="$ROOT/scripts/resolve-profile-execution-plan.sh"
INIT="$ROOT/scripts/init-project.sh"
MAPPING="$ROOT/.template/profile-controls.yaml"
BOUNDARIES='quality_unit test_coverage monorepo_ci secret_scan dependency_review codeql ai_evaluation sbom artifact_attestation scorecard semantic_review structural_review production_governance'
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-plan.XXXXXX")"
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

assert_boundary() {
  label="$1"; output="$2"; boundary="$3"; decision="$4"; required="$5"; reason="$6"
  assert_contains "$label decision" "$output" "^boundary\\.$boundary\\.decision=$decision$"
  assert_contains "$label required" "$output" "^boundary\\.$boundary\\.required=$required$"
  assert_contains "$label reason" "$output" "^boundary\\.$boundary\\.reason=$reason$"
}

make_fixture() {
  fixture="$1"; profile="$2"; ai_enabled="$3"
  mkdir -p "$fixture"
  cp "$ROOT/scripts/test/fixtures/init-project-README.md" "$fixture/README.md"
  if [ "$profile" = enterprise ]; then
    (cd "$fixture" && sh "$INIT" --name plan-fixture --stack auto --profile "$profile" \
      --ai-enabled "$ai_enabled" --layout single --deployment-target self-hosted) >/dev/null
  else
    (cd "$fixture" && sh "$INIT" --name plan-fixture --stack auto --profile "$profile" \
      --ai-enabled "$ai_enabled" --layout single) >/dev/null
  fi
}

make_monorepo_fixture() {
  fixture="$1"; profile="$2"
  mkdir -p "$fixture"
  cp "$ROOT/scripts/test/fixtures/init-project-README.md" "$fixture/README.md"
  (cd "$fixture" && sh "$INIT" --name monorepo-fixture --stack auto --profile "$profile" \
    --layout monorepo --primary-path apps/api --component api=apps/api:python) >/dev/null
  mkdir -p "$fixture/apps/api"
  printf '[project]\nname = "monorepo-fixture"\nversion = "0.0.1"\n' \
    > "$fixture/apps/api/pyproject.toml"
}

assert_plan_failure() {
  label="$1"; fixture="$2"
  if (cd "$fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml) \
    >/dev/null 2>&1; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     expected planner failure\n' "$label" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_report_failure() {
  label="$1"; fixture="$2"; report_path="$3"
  if (cd "$fixture" && sh "$PLAN" --policy-report "$report_path" \
    .template/profile.yaml "$MAPPING" .template/project.yaml) >/dev/null 2>&1; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     expected planner failure\n' "$label" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_boundary_matrix() {
  label="$1"; output="$2"
  for boundary in $BOUNDARIES; do
    assert_count "$label $boundary has three fields" "$output" \
      "^boundary\\.$boundary\\.(decision|required|reason)=" 3
  done
}

# Empty template compatibility delegates all advisory controls to the existing
# baseline and emits every fixed-order boundary field.
mkdir -p "$WORK/template"
compatibility="$(cd "$WORK/template" && sh "$PLAN" \
  "$WORK/missing-profile.yaml" "$MAPPING" "$WORK/missing-project.yaml")"
assert_contains "compatibility mode" "$compatibility" '^mode=compatibility$'
assert_contains "compatibility quality delegation" "$compatibility" \
  '^boundary\.quality_unit\.decision=delegated-to-current-baseline$'
assert_contains "compatibility secret delegation" "$compatibility" \
  '^boundary\.secret_scan\.decision=delegated-to-current-baseline$'
assert_count "all boundaries have three fields" "$compatibility" \
  '^boundary\.[^.]+\.(decision|required|reason)=' 39

# Valid initialized consumers without a detected stack run stack-neutral
# controls while reporting application controls as inapplicable.
for profile in starter standard enterprise; do
  fixture="$WORK/no-stack-$profile"
  make_fixture "$fixture" "$profile" false
  plan="$(cd "$fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
  assert_contains "$profile no-stack mode" "$plan" '^mode=profile$'
  assert_contains "$profile no-stack layout" "$plan" '^layout=single$'
  assert_contains "$profile no-stack stack" "$plan" '^stack=unknown$'
  assert_contains "$profile no-stack ready" "$plan" '^status=ready$'
  assert_boundary "$profile secret scan" "$plan" secret_scan run true required-by-profile
  assert_boundary "$profile dependency review" "$plan" dependency_review run true required-by-profile
  for boundary in quality_unit test_coverage codeql; do
    assert_boundary "$profile $boundary no-stack" "$plan" "$boundary" \
      not-applicable false no-executable-stack
  done
done

ai_fixture="$WORK/no-stack-standard-ai"
make_fixture "$ai_fixture" standard true
ai_plan="$(cd "$ai_fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
assert_boundary "AI-enabled no-stack evaluation" "$ai_plan" ai_evaluation run true required-by-profile

# Executable single stacks retain the current quality/unit baseline while the
# central effective policy controls coverage, CodeQL, and deterministic AI.
for profile in starter standard enterprise; do
  fixture="$WORK/single-$profile"
  make_fixture "$fixture" "$profile" false
  printf '[project]\nname = "plan-fixture"\nversion = "0.0.1"\n' > "$fixture/pyproject.toml"
  plan="$(cd "$fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
  assert_contains "$profile single layout" "$plan" '^layout=single$'
  assert_contains "$profile single stack" "$plan" '^stack=python$'
  assert_boundary "$profile quality unit" "$plan" quality_unit run true required-by-profile
  assert_boundary "$profile secret scan" "$plan" secret_scan run true required-by-profile
  assert_boundary "$profile dependency review" "$plan" dependency_review run true required-by-profile
  case "$profile" in
    starter)
      assert_boundary "Starter coverage" "$plan" test_coverage planned-skip false disabled-by-profile
      assert_boundary "Starter CodeQL" "$plan" codeql planned-skip false disabled-by-profile
      ;;
    standard|enterprise)
      assert_boundary "$profile coverage" "$plan" test_coverage run true required-by-profile
      assert_boundary "$profile CodeQL" "$plan" codeql run true required-by-profile
      ;;
  esac
done

strengthened="$WORK/single-starter-strengthened"
make_fixture "$strengthened" starter false
printf '[project]\nname = "plan-fixture"\nversion = "0.0.1"\n' > "$strengthened/pyproject.toml"
sed 's/^  codeql: false$/  codeql: true/; s/^  coverage: false$/  coverage: true/' \
  "$strengthened/.template/profile.yaml" > "$strengthened/.template/profile.yaml.next"
mv "$strengthened/.template/profile.yaml.next" "$strengthened/.template/profile.yaml"
strengthened_plan="$(cd "$strengthened" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
assert_boundary "strengthened Starter coverage" "$strengthened_plan" test_coverage run true required-by-profile
assert_boundary "strengthened Starter CodeQL" "$strengthened_plan" codeql run true required-by-profile

for profile in starter standard enterprise; do
  fixture="$WORK/single-ai-$profile"
  case "$profile" in starter) ai_enabled=false ;; standard|enterprise) ai_enabled=true ;; esac
  make_fixture "$fixture" "$profile" "$ai_enabled"
  printf '[project]\nname = "plan-fixture"\nversion = "0.0.1"\n' > "$fixture/pyproject.toml"
  plan="$(cd "$fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
  case "$profile" in
    starter)
      assert_boundary "AI-disabled policy Starter" "$plan" ai_evaluation planned-skip false disabled-by-profile
      ;;
    standard|enterprise)
      assert_boundary "$profile AI evaluation" "$plan" ai_evaluation run true required-by-profile
      ;;
  esac
done

# A valid v2 monorepo retains the existing combined component boundary instead
# of attempting to split the policy across individual stacks.
monorepo="$WORK/monorepo-standard"
make_monorepo_fixture "$monorepo" standard
monorepo_plan="$(cd "$monorepo" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
assert_contains "monorepo layout" "$monorepo_plan" '^layout=monorepo$'
assert_contains "monorepo stack" "$monorepo_plan" '^stack=unknown$'
assert_boundary "monorepo combined CI" "$monorepo_plan" monorepo_ci run true required-by-profile
assert_boundary "monorepo quality covered" "$monorepo_plan" quality_unit planned-skip false covered-by-monorepo-boundary
assert_boundary "monorepo coverage covered" "$monorepo_plan" test_coverage planned-skip false covered-by-monorepo-boundary

invalid_v1_monorepo="$WORK/invalid-v1-monorepo"
make_monorepo_fixture "$invalid_v1_monorepo" standard
sed 's/^version: 2$/version: 1/' "$invalid_v1_monorepo/.template/project.yaml" \
  > "$invalid_v1_monorepo/.template/project.yaml.next"
mv "$invalid_v1_monorepo/.template/project.yaml.next" "$invalid_v1_monorepo/.template/project.yaml"
assert_plan_failure "v1 monorepo declaration fails closed" "$invalid_v1_monorepo"

invalid_components="$WORK/invalid-components"
make_monorepo_fixture "$invalid_components" standard
sed 's/^    stack: python$/    stack: rust/' "$invalid_components/.template/project.yaml" \
  > "$invalid_components/.template/project.yaml.next"
mv "$invalid_components/.template/project.yaml.next" "$invalid_components/.template/project.yaml"
assert_plan_failure "invalid component configuration fails closed" "$invalid_components"

undecided="$WORK/undecided-no-stack"
make_fixture "$undecided" standard false
sed 's/^layout: single$/layout: undecided/' "$undecided/.template/project.yaml" \
  > "$undecided/.template/project.yaml.next"
mv "$undecided/.template/project.yaml.next" "$undecided/.template/project.yaml"
undecided_plan="$(cd "$undecided" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
assert_contains "undecided no-stack remains ready" "$undecided_plan" '^status=ready$'
assert_contains "undecided no-stack layout" "$undecided_plan" '^layout=undecided$'
printf '[project]\nname = "undecided"\nversion = "0.0.1"\n' > "$undecided/pyproject.toml"
assert_plan_failure "undecided executable stack fails closed" "$undecided"

# Parser fixtures are regular files only. They exercise the precomputed-report
# path without executing report content or reinterpreting consumer text.
parser_fixture="$WORK/parser-fixture"
make_fixture "$parser_fixture" standard false
printf '[project]\nname = "parser-fixture"\nversion = "0.0.1"\n' > "$parser_fixture/pyproject.toml"
valid_report="$WORK/valid-policy-report"
sh "$ROOT/scripts/resolve-profile-policy.sh" "$parser_fixture/.template/profile.yaml" \
  "$MAPPING" "$parser_fixture/.template/project.yaml" > "$valid_report"
report_plan="$(cd "$parser_fixture" && sh "$PLAN" --policy-report "$valid_report" \
  .template/profile.yaml "$WORK/no-mapping.yaml" .template/project.yaml)"
assert_boundary "precomputed report supports parser diagnostics" "$report_plan" quality_unit run true required-by-profile
assert_boundary_matrix "precomputed report" "$report_plan"
assert_count "all output boundaries have three fields" "$report_plan" \
  '^boundary\.[^.]+\.(decision|required|reason)=' 39
assert_count "all output reasons are bounded tokens" "$report_plan" \
  '^boundary\.[^.]+\.reason=[a-z0-9][a-z0-9-]{0,63}$' 13

printf 'mode=profile\n' >> "$valid_report"
assert_report_failure "duplicate central record fails" "$parser_fixture" "$valid_report"
sed '$d' "$valid_report" > "$WORK/valid-policy-report.next"
mv "$WORK/valid-policy-report.next" "$valid_report"

printf 'control.unknown.enabled=true\n' >> "$valid_report"
assert_report_failure "unknown central record fails" "$parser_fixture" "$valid_report"
sed '$d' "$valid_report" > "$WORK/valid-policy-report.next"
mv "$WORK/valid-policy-report.next" "$valid_report"

sed '/^control\.codeql\.enabled=/d' "$valid_report" > "$WORK/missing-policy-report"
assert_report_failure "missing central record fails" "$parser_fixture" "$WORK/missing-policy-report"

cp "$valid_report" "$WORK/malformed-policy-report"
printf 'malformed record\n' >> "$WORK/malformed-policy-report"
assert_report_failure "malformed central record fails" "$parser_fixture" "$WORK/malformed-policy-report"

sed 's/^control\.codeql\.alignment=aligned$/control.codeql.alignment=policy-mismatch/' \
  "$valid_report" > "$WORK/mismatched-aligned-policy-report"
assert_report_failure "aligned status with policy mismatch fails" "$parser_fixture" \
  "$WORK/mismatched-aligned-policy-report"

sed 's/^control\.codeql\.enabled=true$/control.codeql.enabled=current-baseline/' \
  "$valid_report" > "$WORK/profile-current-baseline-boolean-report"
assert_report_failure "profile Boolean cannot use current baseline" "$parser_fixture" \
  "$WORK/profile-current-baseline-boolean-report"

mkdir "$WORK/policy-report-directory"
assert_report_failure "directory policy report fails" "$parser_fixture" "$WORK/policy-report-directory"
ln -s "$valid_report" "$WORK/policy-report-link"
assert_report_failure "symlink policy report fails" "$parser_fixture" "$WORK/policy-report-link"
ln -s "$WORK/missing-policy-report-target" "$WORK/policy-report-dangling-link"
assert_report_failure "dangling symlink policy report fails" "$parser_fixture" "$WORK/policy-report-dangling-link"

bad_project="$WORK/bad-project-layout"
make_fixture "$bad_project" standard false
printf '[project]\nname = "bad-project"\nversion = "0.0.1"\n' > "$bad_project/pyproject.toml"
sed 's/^version: 1$/version: 2/' "$bad_project/.template/project.yaml" \
  > "$bad_project/.template/project.yaml.next"
mv "$bad_project/.template/project.yaml.next" "$bad_project/.template/project.yaml"
assert_report_failure "unsupported project layout and stack combination fails" "$bad_project" "$valid_report"

normal_once="$(cd "$parser_fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
normal_twice="$(cd "$parser_fixture" && sh "$PLAN" .template/profile.yaml "$MAPPING" .template/project.yaml)"
assert_eq "valid plan is byte-identical" "$normal_twice" "$normal_once"
assert_boundary_matrix "normal plan" "$normal_once"

weakened="$WORK/weakened-enterprise"
make_fixture "$weakened" enterprise false
printf '[project]\nname = "weakened"\nversion = "0.0.1"\n' > "$weakened/pyproject.toml"
sed 's/^  sbom: true$/  sbom: false/' "$weakened/.template/profile.yaml" \
  > "$weakened/.template/profile.yaml.next"
mv "$weakened/.template/profile.yaml.next" "$weakened/.template/profile.yaml"
assert_plan_failure "policy mismatch status fails closed" "$weakened"

report
