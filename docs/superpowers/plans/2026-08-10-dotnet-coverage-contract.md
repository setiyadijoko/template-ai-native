# .NET Coverage Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the documented 80% overall .NET line-coverage gate measurable, fail-closed, and retained as workflow evidence before the hosted .NET consumer pilot.

**Architecture:** A repository-owned POSIX wrapper runs the existing Coverlet collector inside one controlled current-run results directory, validates every Cobertura report, and enforces one weighted aggregate threshold. The existing mapper routes both single-stack and component-aware jobs through that wrapper; workflows retain the collector's recursive reports without adding jobs, actions, or permissions.

**Tech Stack:** POSIX `sh`, fake-command shell contract tests, Cobertura XML counters, GitHub Actions YAML, existing Makefile test orchestration.

## Global Constraints

- The overall line-coverage threshold is fixed at 80%; consumers cannot lower it through configuration or environment variables.
- Keep the collector integration as `dotnet test --collect:"XPlat Code Coverage"`; do not adopt `coverlet.MTP`, `coverlet.msbuild`, or a template-owned NuGet package.
- Use only the wrapper-owned `TestResults/template-ai-native-coverage` directory for current-run evidence; do not delete other consumer test results.
- Aggregate `lines-covered` and `lines-valid` across reports before calculating the percentage; do not average per-report percentages.
- Missing, malformed, impossible, zero-valid, below-threshold, or collector-failure evidence must fail closed.
- Keep every non-.NET stack mapping and all workflow permissions, triggers, concurrency groups, action SHAs, timeouts, and fork behavior unchanged.
- Do not claim hosted .NET verification, production readiness, deployment, or profile activation in this change.
- Use `apply_patch` for source, test, workflow, and documentation edits. Do not broaden the change beyond this contract.

---

### Task 1: Add the fail-closed .NET coverage wrapper and mapper contract

**Files:**

- Create: `scripts/run-dotnet-coverage.sh`
- Create: `scripts/test/test-dotnet-coverage.sh`
- Modify: `scripts/stack-tools.sh`
- Modify: `scripts/test/test-stack-detection.sh`
- Modify: `Makefile`

**Interfaces:**

- Consumes: a consumer-owned `dotnet` executable and compatible XPlat coverage collector.
- Produces: `sh "<template-root>/scripts/run-dotnet-coverage.sh"` from `scripts/stack-tools.sh coverage` for a detected .NET project.
- Produces: blocking exit status and `.NET coverage: <percent>% (<covered>/<valid> lines)` output.
- Preserves: all non-.NET mapper output byte-for-byte.

- [ ] **Step 1: Create the focused failing contract test**

Use `apply_patch` to create `scripts/test/test-dotnet-coverage.sh` with this exact content:

```sh
#!/usr/bin/env sh
# Contract tests for current-run .NET coverage collection and enforcement.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dotnet-coverage.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

HELPER="$ROOT/scripts/run-dotnet-coverage.sh"
FAKE_BIN="$WORK/bin"
mkdir -p "$FAKE_BIN"

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

write_report() {
  directory="$1"
  covered="$2"
  valid="$3"
  mkdir -p "$directory"
  printf '<coverage line-rate="0" lines-covered="%s" lines-valid="%s"></coverage>\n' \
    "$covered" "$valid" > "$directory/coverage.cobertura.xml"
}

cat > "$FAKE_BIN/dotnet" <<'EOF'
#!/usr/bin/env sh
set -eu

printf '%s\n' "$@" > "$DOTNET_LOG"
result_root="$PWD/TestResults/template-ai-native-coverage"

case "$DOTNET_FIXTURE_MODE" in
  exact)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="8" lines-valid="10"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  below)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="79" lines-valid="100"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  weighted-pass)
    mkdir -p "$result_root/run-a" "$result_root/run-b"
    printf '<coverage lines-covered="100" lines-valid="100"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    printf '<coverage lines-covered="700" lines-valid="900"></coverage>\n' \
      > "$result_root/run-b/coverage.cobertura.xml"
    ;;
  weighted-fail)
    mkdir -p "$result_root/run-a" "$result_root/run-b"
    printf '<coverage lines-covered="100" lines-valid="100"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    printf '<coverage lines-covered="620" lines-valid="900"></coverage>\n' \
      > "$result_root/run-b/coverage.cobertura.xml"
    ;;
  missing)
    ;;
  malformed)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="8"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  impossible)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="11" lines-valid="10"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  zero)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="0" lines-valid="0"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  collector-fail)
    exit 42
    ;;
  *)
    printf 'unsupported fixture mode: %s\n' "$DOTNET_FIXTURE_MODE" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/dotnet"

run_case() {
  name="$1"
  mode="$2"
  case_dir="$WORK/$name"
  mkdir -p "$case_dir"
  (
    cd "$case_dir"
    PATH="$FAKE_BIN:$PATH" \
      DOTNET_BIN=dotnet \
      DOTNET_FIXTURE_MODE="$mode" \
      DOTNET_LOG="$case_dir/dotnet.log" \
      sh "$HELPER"
  )
}

set +e
exact_output="$(run_case exact exact 2>&1)"
exact_status=$?
set -e
assert_eq "coverage at threshold status" "$exact_status" "0"
assert_text_contains "coverage at threshold output" "$exact_output" \
  '[.]NET coverage: 80[.]00% [(]8/10 lines[)]'
assert_text_contains "coverage threshold is visible" "$exact_output" \
  'Required [.]NET coverage threshold: 80%'
assert_text_contains "collector uses test command" "$(cat "$WORK/exact/dotnet.log")" '^test$'
assert_text_contains "collector uses XPlat" "$(cat "$WORK/exact/dotnet.log")" \
  '^--collect:XPlat Code Coverage$'
assert_text_contains "collector uses controlled results option" \
  "$(cat "$WORK/exact/dotnet.log")" '^--results-directory$'
assert_text_contains "collector uses controlled results path" \
  "$(cat "$WORK/exact/dotnet.log")" '^TestResults/template-ai-native-coverage$'
assert_text_contains "collector requests cobertura" "$(cat "$WORK/exact/dotnet.log")" \
  '^/p:CoverletOutputFormat=cobertura$'

set +e
below_output="$(run_case below below 2>&1)"
below_status=$?
set -e
assert_eq "below threshold status" "$below_status" "1"
assert_text_contains "below threshold output" "$below_output" \
  '[.]NET coverage 79[.]00% < 80%'

set +e
weighted_pass_output="$(run_case weighted-pass weighted-pass 2>&1)"
weighted_pass_status=$?
set -e
assert_eq "weighted threshold status" "$weighted_pass_status" "0"
assert_text_contains "weighted threshold output" "$weighted_pass_output" \
  '[.]NET coverage: 80[.]00% [(]800/1000 lines[)]'

set +e
weighted_fail_output="$(run_case weighted-fail weighted-fail 2>&1)"
weighted_fail_status=$?
set -e
assert_eq "weighted calculation rejects unweighted false pass" \
  "$weighted_fail_status" "1"
assert_text_contains "weighted failure output" "$weighted_fail_output" \
  '[.]NET coverage 72[.]00% < 80%'

for failure_mode in missing malformed impossible zero; do
  set +e
  failure_output="$(run_case "$failure_mode" "$failure_mode" 2>&1)"
  failure_status=$?
  set -e
  assert_eq "$failure_mode evidence status" "$failure_status" "1"
  assert_text_contains "$failure_mode evidence is CI error" "$failure_output" '^::error::'
done

stale_dir="$WORK/stale/TestResults/template-ai-native-coverage/old-run"
write_report "$stale_dir" 10 10
set +e
stale_output="$(run_case stale missing 2>&1)"
stale_status=$?
set -e
assert_eq "stale report is removed" "$stale_status" "1"
assert_text_contains "stale report cannot satisfy gate" "$stale_output" \
  'No current-run [.]NET coverage report found'

set +e
run_case collector-fail collector-fail >/dev/null 2>&1
collector_status=$?
set -e
assert_eq "collector failure is preserved" "$collector_status" "42"

missing_bin_dir="$WORK/missing-bin"
mkdir -p "$missing_bin_dir"
set +e
missing_bin_output="$(
  cd "$missing_bin_dir"
  DOTNET_BIN="$WORK/does-not-exist" sh "$HELPER" 2>&1
)"
missing_bin_status=$?
set -e
assert_eq "missing dotnet status" "$missing_bin_status" "65"
assert_text_contains "missing dotnet is explicit" "$missing_bin_output" \
  '^::error::[.]NET coverage executable is unavailable'

PROJECT="$WORK/mapper"
mkdir -p "$PROJECT"
printf '<Project Sdk="Microsoft.NET.Sdk"></Project>\n' > "$PROJECT/app.csproj"
mapper_output="$(cd "$PROJECT" && sh "$ROOT/scripts/stack-tools.sh" coverage)"
assert_eq "dotnet coverage mapper uses helper" "$mapper_output" \
  "sh \"$ROOT/scripts/run-dotnet-coverage.sh\""

report
```

- [ ] **Step 2: Run the focused test to verify RED**

Run:

```sh
sh scripts/test/test-dotnet-coverage.sh
```

Expected: non-zero because `scripts/run-dotnet-coverage.sh` does not exist and
the current mapper still returns the inline `dotnet test` command.

- [ ] **Step 3: Implement the fail-closed wrapper**

Use `apply_patch` to create `scripts/run-dotnet-coverage.sh`. The original
inline draft was removed after final review because duplicating the complete
executable here allowed the plan and reviewed implementation to diverge. The
authoritative implementation is the adjacent repository script
`scripts/run-dotnet-coverage.sh`.

The following final-review corrections are load-bearing and must remain exact:

```sh
if ! find "$RESULTS_DIR" -type f -name coverage.cobertura.xml -print \
  > "$REPORT_LIST"; then
  printf '::error::Failed to discover current-run .NET coverage reports under %s.\n' \
    "$RESULTS_DIR" >&2
  exit 1
fi
```

Discovery writes directly to the report list and checks `find` itself. Do not
pipe it through `sort`, because POSIX pipeline status would mask a traversal
failure when a later command succeeds.

Validated digit strings are canonicalized and range-checked before any shell
comparison or arithmetic:

```sh
normalize_safe_counter() {
  printf '%s\n' "$1" | awk '
    {
      value = $0
      sub(/^0+/, "", value)
      if (value == "") value = "0"
      if (length(value) < 10) {
        normalized = value
        next
      }
      if (length(value) > 10) {
        invalid = 1
        next
      }

      limit = "2147483647"
      for (position = 1; position <= 10; position++) {
        digit = substr(value, position, 1)
        limit_digit = substr(limit, position, 1)
        if (digit < limit_digit) {
          normalized = value
          next
        }
        if (digit > limit_digit) {
          invalid = 1
          next
        }
      }
      normalized = value
    }
    END {
      if (NR != 1 || invalid || normalized == "") exit 1
      print normalized
    }
  '
}

  if ! covered="$(normalize_safe_counter "$covered")" || \
    ! valid="$(normalize_safe_counter "$valid")"; then
    printf '::error::.NET coverage counter exceeds safe shell range: %s\n' \
      "$report" >&2
    exit 1
  fi
```

After the existing impossible-counter check, aggregate overflow uses the same
safe decimal boundary:

```sh
  if [ "$covered" -gt "$((MAX_SAFE_COUNTER - total_covered))" ] || \
    [ "$valid" -gt "$((MAX_SAFE_COUNTER - total_valid))" ]; then
    printf '::error::.NET coverage aggregate exceeds safe shell range: %s\n' \
      "$report" >&2
    exit 1
  fi
```

This normalization ensures values such as `08` and `010` enter shell
arithmetic as decimal `8` and `10`, while oversized individual or aggregate
counters fail closed.

Run:

```sh
chmod +x scripts/run-dotnet-coverage.sh
```

- [ ] **Step 4: Route the mapper through the wrapper**

Use `apply_patch` in `scripts/stack-tools.sh` to replace:

```sh
  dotnet:coverage)          echo 'dotnet test --collect:"XPlat Code Coverage" /p:CoverletOutputFormat=cobertura' ;;
```

with:

```sh
  dotnet:coverage)          printf 'sh "%s/run-dotnet-coverage.sh"\n' "$HERE" ;;
```

Use `apply_patch` in `scripts/test/test-stack-detection.sh` after the existing
.NET unit assertion to add:

```sh
assert_eq "dotnet coverage" "$($TOOL coverage)" \
  "sh \"$ROOT/scripts/run-dotnet-coverage.sh\""
```

- [ ] **Step 5: Register the focused test**

Use `apply_patch` in `Makefile` immediately after the Go coverage test line:

```make
	@sh scripts/test/test-dotnet-coverage.sh
```

- [ ] **Step 6: Run GREEN verification and commit**

Run:

```sh
sh scripts/test/test-dotnet-coverage.sh
sh scripts/test/test-stack-detection.sh
make test-scripts
git diff --check
git diff -- scripts/run-dotnet-coverage.sh \
  scripts/test/test-dotnet-coverage.sh \
  scripts/stack-tools.sh scripts/test/test-stack-detection.sh Makefile
git add scripts/run-dotnet-coverage.sh \
  scripts/test/test-dotnet-coverage.sh \
  scripts/stack-tools.sh scripts/test/test-stack-detection.sh Makefile
git commit -m "fix: enforce .NET coverage threshold"
git status --short --branch
```

Expected: all shell contracts pass without a local .NET installation, the
helper is executable, and the branch is clean after the implementation commit.

---

### Task 2: Retain recursive .NET coverage reports in both workflows

**Files:**

- Modify: `.github/workflows/ci-test.yml`
- Modify: `.github/workflows/ci-monorepo.yml`
- Modify: `scripts/test/test-delivery-workflows.sh`
- Modify: `scripts/test/test-monorepo-ci.sh`

**Interfaces:**

- Consumes: current-run reports under
  `TestResults/template-ai-native-coverage/**/coverage.cobertura.xml` from
  Task 1.
- Produces: retained single-stack `coverage-dotnet` and component
  `coverage-<id>` artifact contents.
- Preserves: existing root compatibility paths and `if: always()` behavior.

- [ ] **Step 1: Add failing workflow contract assertions**

Use `apply_patch` in `scripts/test/test-delivery-workflows.sh` after the build
workflow declarations to add:

```sh
CI_TEST="$ROOT/.github/workflows/ci-test.yml"
```

Add after the build artifact assertions:

```sh
assert_contains "single-stack retains recursive .NET coverage" "$CI_TEST" \
  '^[[:space:]]+[*][*]/TestResults/[*][*]/coverage[.]cobertura[.]xml[[:space:]]*$'
assert_not_contains "single-stack .NET coverage glob has no literal quotes" \
  "$CI_TEST" '^[[:space:]]+"[*][*]/TestResults/[*][*]/coverage[.]cobertura[.]xml"[[:space:]]*$'
```

Include `$CI_TEST` in the existing `assert_action_pins` invocation.

Use `apply_patch` in `scripts/test/test-monorepo-ci.sh` after the existing
shared Go coverage assertions to add:

```sh
assert_contains "monorepo retains recursive .NET coverage" "$MONO" \
  '^[[:space:]]+[$][{][{][[:space:]]matrix[.]component[.]path[[:space:]][}][}]/[*][*]/TestResults/[*][*]/coverage[.]cobertura[.]xml[[:space:]]*$'
assert_not_contains "monorepo .NET coverage glob has no literal quotes" "$MONO" \
  '^[[:space:]]+"[$][{][{].*TestResults/[*][*]/coverage[.]cobertura[.]xml"[[:space:]]*$'
```

- [ ] **Step 2: Run the workflow contracts to verify RED**

Run:

```sh
sh scripts/test/test-delivery-workflows.sh
sh scripts/test/test-monorepo-ci.sh
```

Expected: both exit non-zero because neither workflow retains recursive .NET
collector output yet.

- [ ] **Step 3: Add the single-stack recursive artifact path**

Use `apply_patch` in `.github/workflows/ci-test.yml` to add this path after the
root `coverage.cobertura.xml` entry:

```yaml
            **/TestResults/**/coverage.cobertura.xml
```

Do not add quote characters inside the YAML block scalar. Its lines are passed
to the upload action literally, so quotes would become part of the glob.

- [ ] **Step 4: Add the component-aware recursive artifact path**

Use `apply_patch` in `.github/workflows/ci-monorepo.yml` to add this path after
the component root `coverage.cobertura.xml` entry:

```yaml
            ${{ matrix.component.path }}/**/TestResults/**/coverage.cobertura.xml
```

Do not modify the job condition, artifact name, action pin, or
`if-no-files-found` behavior.

- [ ] **Step 5: Run workflow verification and commit**

Run:

```sh
sh scripts/test/test-delivery-workflows.sh
sh scripts/test/test-monorepo-ci.sh
sh scripts/test/test-security-workflows.sh
make test-scripts
git diff --check
git diff -- .github/workflows/ci-test.yml \
  .github/workflows/ci-monorepo.yml \
  scripts/test/test-delivery-workflows.sh \
  scripts/test/test-monorepo-ci.sh
git add .github/workflows/ci-test.yml \
  .github/workflows/ci-monorepo.yml \
  scripts/test/test-delivery-workflows.sh \
  scripts/test/test-monorepo-ci.sh
git commit -m "ci: retain .NET coverage reports"
git status --short --branch
```

Expected: workflow contracts and action-security regressions pass; no action,
permission, trigger, or concurrency setting changes.

---

### Task 3: Document and close the .NET coverage false-green gap

**Files:**

- Modify: `scripts/README.md`
- Modify: `docs/development/testing-strategy.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`

**Interfaces:**

- Consumes: reviewed wrapper and workflow behavior from Tasks 1–2.
- Produces: accurate consumer guidance and traceability through closed
  `TD-0019`.
- Preserves: roadmap hosted-pilot status; this task does not claim hosted .NET
  verification.

- [ ] **Step 1: Document the operational script**

Use `apply_patch` in `scripts/README.md` after the Go coverage helper row:

```markdown
| `run-dotnet-coverage.sh` | Called by single-stack and component-aware .NET coverage mappings | Runs the consumer-owned XPlat collector in an isolated current-run results directory, validates all Cobertura reports, and enforces the fixed 80% weighted aggregate line threshold. Missing, malformed, zero-valid, impossible, and below-threshold evidence fails closed. |
```

- [ ] **Step 2: Clarify the testing strategy**

Use `apply_patch` in the first coverage-threshold bullet of
`docs/development/testing-strategy.md`, after the Python discovery sentence, to
add:

```markdown
  .NET runs its consumer-owned XPlat collector in an isolated current-run
  results directory; the repository wrapper aggregates Cobertura line counters
  across test projects and fails closed below 80% or when evidence is missing
  or invalid.
```

- [ ] **Step 3: Record and close TD-0019 with actual implementation evidence**

Use `apply_patch` in `docs/plans/technical-debt.md` after TD-0018 to add one
table row:

```markdown
| TD-0019 | (Closed) The .NET XPlat collector command generated Cobertura output below `TestResults` but did not enforce the documented 80% overall threshold, and workflow artifacts looked only for a root report. | `scripts/run-dotnet-coverage.sh`, `scripts/stack-tools.sh`, `.github/workflows/ci-test.yml`, `.github/workflows/ci-monorepo.yml` | Closed 2026-08-10 | A shared current-run wrapper now validates and aggregates all .NET Cobertura line counters, fails closed below 80% or on invalid evidence, and both workflow paths retain recursive collector reports with focused regression coverage. Hosted .NET runtime validation remains a separate pilot. |
```

Do not mark the hosted .NET pilot or profile foundation complete.

- [ ] **Step 4: Update the changelog**

Use `apply_patch` under `CHANGELOG.md` → `## [Unreleased]` → `### Fixed` to add:

```markdown
- Enforced the documented 80% .NET line-coverage baseline through a shared,
  fail-closed current-run Cobertura aggregator and retained recursive collector
  reports in single-stack and component-aware CI.
```

- [ ] **Step 5: Run complete repository verification**

Run:

```sh
sh scripts/test/test-dotnet-coverage.sh
sh scripts/test/test-delivery-workflows.sh
sh scripts/test/test-monorepo-ci.sh
make test-scripts
make docs-check
make ci
git diff --check
git diff -- scripts/README.md \
  docs/development/testing-strategy.md \
  docs/plans/technical-debt.md CHANGELOG.md
```

Expected: focused and repository-wide gates pass. Local optional documentation
tools may skip only according to the existing best-effort contract and must be
reported rather than relabeled as executed.

- [ ] **Step 6: Review scope and commit**

Confirm:

```sh
git status --short
git diff --stat HEAD
git diff HEAD -- . ':!docs/superpowers/specs/2026-08-10-dotnet-coverage-contract-design.md' ':!docs/superpowers/plans/2026-08-10-dotnet-coverage-contract.md'
```

Verify every changed line belongs to the .NET coverage contract, no credential
or sensitive report content is present, the roadmap does not claim hosted .NET
success, and the implementation plan/spec remain separate documentation
commits.

Then run:

```sh
git add scripts/README.md \
  docs/development/testing-strategy.md \
  docs/plans/technical-debt.md CHANGELOG.md
git commit -m "docs: record .NET coverage contract"
git status --short --branch
```

Expected: the documentation commit contains exactly the four intended files
and the branch is clean.

---

## Final verification

Before declaring this template fix complete:

1. Review the complete branch diff from its merge base with `main`.
2. Confirm the design and plan match the implemented wrapper command exactly.
3. Confirm the controlled results directory cannot reuse a stale report.
4. Confirm weighted aggregation passes exactly 80% and fails below it.
5. Confirm both single-stack and component-aware workflows retain recursive
   .NET reports without any workflow security change.
6. Confirm all non-.NET mapper commands remain unchanged.
7. Confirm `TD-0019` closes only after actual focused and repository-wide
   checks pass.
8. Confirm documentation makes no hosted .NET, deployment, profile, or
   production-readiness claim.
9. Inspect the complete diff for unrelated changes, generated reports,
   credentials, temporary files, and accidental permission changes.

## Subsequent hosted pilot

After this branch is reviewed, merged, and template `main` is synchronized,
create a separate hosted .NET 8/xUnit consumer pilot. That pilot owns package
pins, lockfiles, categorized unit/integration/E2E tests, Release build output,
pull-request checks, human-controlled merge, main artifact inspection, and
provenance-attestation evidence. None of those hosted outcomes are acceptance
criteria for this template-fix pull request.
