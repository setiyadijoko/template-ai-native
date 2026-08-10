# Profile-Aware CI Shadow Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one read-only advisory observation path that reports how an optional maturity profile would affect controls without changing any existing workflow execution or required check.

**Architecture:** A POSIX resolver validates the existing profile contract, reads the existing normative mapping, and emits deterministic key/value observations. A separate GitHub Actions workflow renders those observations into a stable Job Summary; the current dispatcher, control workflows, branch protection, and initializer remain unchanged.

**Tech Stack:** POSIX `sh`, `awk`, `sed`, `grep`, Make, YAML, GitHub Actions, existing shell-test helpers.

## Global Constraints

- The implementation is observational only; no existing workflow may read a shadow decision to run, skip, pass, or fail.
- Do not modify `.github/workflows/ci.yml`, any existing control workflow, or `scripts/setup-branch-protection.sh`.
- Workflow name is exactly `Profile shadow`; job/check name is exactly `Profile shadow / Profile policy observation`.
- The workflow runs on pull requests to `main`, pushes to `main`, and manual dispatch, with no path filter.
- Workflow permissions are exactly `contents: read`; use `pull_request`, never `pull_request_target`.
- Do not add a secret, write permission, API call, PR comment, uploaded report artifact, telemetry provider, or new package dependency.
- Missing `.template/profile.yaml` succeeds in compatibility mode and never infers a profile.
- Invalid profile or normative mapping fails only the new advisory observation path.
- Valid policy mismatches emit warnings and succeed; they do not change current controls.
- Do not modify `scripts/init-project.sh`, deployment, environment, production, or provider behavior.
- The shadow check remains absent from branch protection.

---

### Task 1: Build the deterministic profile-shadow resolver through TDD

**Files:**
- Create: `scripts/test/test-profile-shadow.sh`
- Create: `scripts/resolve-profile-shadow.sh`

**Interfaces:**
- Consumes: `sh scripts/validate-profile-config.sh PROFILE_PATH` and `.template/profile-controls.yaml` version `1`.
- Produces: `sh scripts/resolve-profile-shadow.sh [PROFILE_PATH] [MAPPING_PATH]` with deterministic key/value stdout, GitHub warning annotations on stderr, and exit `0` for compatibility/aligned/mismatch observations.
- Fails: non-zero with prefix `profile-shadow:` for invalid/missing mapping, invalid profile, unsupported mapping values, or incomplete selected-profile controls.

- [ ] **Step 1: Write the failing resolver contract test**

Create `scripts/test/test-profile-shadow.sh` with this fixture structure and exact behavioral assertions:

```sh
#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-profile-shadow.sh"
MAPPING="$ROOT/.template/profile-controls.yaml"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-shadow.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

assert_output_contains() {
  label="$1"; output="$2"; pattern="$3"
  if printf '%s\n' "$output" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

run_shadow() {
  sh "$RESOLVER" "$1" "${2:-$MAPPING}"
}

# The missing profile is compatibility mode, not an inferred profile.
compatibility="$(run_shadow "$WORK/missing.yaml")"
assert_output_contains "compatibility mode" "$compatibility" '^mode=compatibility$'
assert_output_contains "compatibility has no profile" "$compatibility" '^profile=none$'
assert_output_contains "compatibility preserves secret scan" "$compatibility" \
  '^control\.secret_scan\.decision=current-baseline$'
compatibility_controls="$(printf '%s\n' "$compatibility" | grep -Ec '^control\.[^.]+\.decision=current-baseline$')"
assert_eq "compatibility reports every control" "$compatibility_controls" "11"

# Standard example resolves deterministically.
standard="$(run_shadow "$ROOT/.template/profile.yaml.example")"
assert_output_contains "standard shadow mode" "$standard" '^mode=shadow$'
assert_output_contains "standard profile" "$standard" '^profile=standard$'
assert_output_contains "standard codeql runs" "$standard" \
  '^control\.codeql\.decision=would-run$'
assert_output_contains "standard codeql class" "$standard" \
  '^control\.codeql\.class=pull-request-blocking$'

# Starter may choose stronger controls without a mismatch.
sed 's/^profile: standard$/profile: starter/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/starter.yaml"
starter="$(run_shadow "$WORK/starter.yaml" 2>"$WORK/starter.err")"
assert_output_contains "starter stronger codeql" "$starter" \
  '^control\.codeql\.alignment=stronger-than-default$'

# Enterprise defaults expose weakening declarations as warnings, not failure.
sed 's/^profile: standard$/profile: enterprise/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/enterprise.yaml"
enterprise="$(run_shadow "$WORK/enterprise.yaml" 2>"$WORK/enterprise.err")"
assert_output_contains "enterprise warning status" "$enterprise" '^status=warning$'
assert_output_contains "enterprise sbom mismatch" "$enterprise" \
  '^control\.sbom\.alignment=policy-mismatch$'
assert_output_contains "enterprise warning annotation" \
  "$(cat "$WORK/enterprise.err")" '^::warning.*sbom'

# AI-disabled Standard resolves evaluation and reviews to would-skip.
sed -e 's/^  enabled: true$/  enabled: false/' \
  -e 's/^  evaluation: true$/  evaluation: false/' \
  -e 's/^  semantic_review: advisory$/  semantic_review: off/' \
  -e 's/^  structural_review: advisory$/  structural_review: off/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/ai-disabled.yaml"
ai_disabled="$(run_shadow "$WORK/ai-disabled.yaml")"
assert_output_contains "AI evaluation skips" "$ai_disabled" \
  '^control\.ai_evaluation\.decision=would-skip$'

# Invalid profile and malformed policy fail closed.
cp "$ROOT/.template/profile.yaml.example" "$WORK/invalid.yaml"
printf 'provider: openai\n' >> "$WORK/invalid.yaml"
assert_exit "invalid profile fails" 1 run_shadow "$WORK/invalid.yaml"
sed '/^[[:space:]]*codeql:/d' "$MAPPING" > "$WORK/malformed-controls.yaml"
assert_exit "malformed mapping fails" 1 run_shadow \
  "$ROOT/.template/profile.yaml.example" "$WORK/malformed-controls.yaml"

# Repeated runs are byte-identical.
standard_again="$(run_shadow "$ROOT/.template/profile.yaml.example")"
assert_eq "deterministic report" "$standard_again" "$standard"

report
```

- [ ] **Step 2: Run the test and verify the intended RED state**

Run:

```sh
sh scripts/test/test-profile-shadow.sh
```

Expected: non-zero because `scripts/resolve-profile-shadow.sh` does not exist.
Retain the exact missing-script error in the task report.

- [ ] **Step 3: Implement the resolver with fixed control order**

Create `scripts/resolve-profile-shadow.sh` with `set -eu`, these defaults, and
this exact control order:

```sh
PROFILE_CONFIG="${1:-.template/profile.yaml}"
CONTROL_MAP="${2:-.template/profile-controls.yaml}"
CONTROLS='secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard ai_evaluation semantic_review structural_review production_governance'
```

Implement these bounded helpers:

```sh
die() {
  printf 'profile-shadow: %s\n' "$1" >&2
  exit 1
}

profile_name() {
  awk -F ':[[:space:]]*' '$1 == "profile" { print $2; exit }' "$PROFILE_CONFIG"
}

profile_value() {
  section="$1"; key="$2"
  awk -v section="$section" -v key="$key" '
    $0 == section ":" { inside = 1; next }
    inside && /^[^ ]/ { exit }
    inside && $0 ~ "^  " key ":[[:space:]]*" {
      value = $0
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
```

Validate mapping version `1`, all three profile headings, all eleven controls
for every profile, and these allowed values before resolving anything:

```text
secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard: true|false
ai_evaluation: optional|when-ai-enabled|required-for-ai
semantic_review structural_review: off|advisory|enabled
production_governance: when-deployed|required
```

Implement `execution_class()` with the exact mapping:

```sh
case "$1" in
  secret_scan|dependency_review|codeql|coverage) echo pull-request-blocking ;;
  ai_evaluation|semantic_review|structural_review) echo pull-request-advisory ;;
  sbom|artifact_attestation) echo post-merge ;;
  scorecard) echo scheduled-push ;;
  production_governance) echo manual-environment ;;
  *) die "unsupported control '$1'" ;;
esac
```

For a missing profile, print `mode=compatibility`, `profile=none`,
`status=current-baseline`, then exactly one
`control.<name>.decision=current-baseline` line per control.

For a present profile:

1. Run `sh scripts/validate-profile-config.sh "$PROFILE_CONFIG" >/dev/null`.
2. Resolve Boolean declarations directly from `controls.*`.
3. Resolve `ai_evaluation` to true only when `ai.enabled=true` and
   `ai.evaluation=true`.
4. Resolve semantic/structural decisions to `would-skip` for `off` and
   `would-run` otherwise.
5. Resolve production governance from `deployment.enabled`.
6. Compare Boolean defaults as `aligned`, `stronger-than-default`, or
   `policy-mismatch`.
7. Compare review enums by rank `off=0`, `advisory=1`, `enabled=2`.
8. Treat `optional` AI evaluation as aligned; for `when-ai-enabled` and
   `required-for-ai`, compare the resolved decision to `ai.enabled`.
9. Treat `when-deployed` production governance as aligned; for `required`, a
   disabled deployment is a policy mismatch.
10. Emit one `::warning title=Profile shadow policy mismatch::<control> ...`
    annotation per mismatch and set the report header to `status=warning`.

Print every control in `CONTROLS` order with these exact fields:

```text
control.<name>.declared=<value>
control.<name>.default=<value>
control.<name>.decision=would-run|would-skip
control.<name>.class=<execution-class>
control.<name>.alignment=aligned|stronger-than-default|policy-mismatch
```

- [ ] **Step 4: Run syntax and resolver contracts to verify GREEN**

Run:

```sh
sh -n scripts/resolve-profile-shadow.sh
sh -n scripts/test/test-profile-shadow.sh
sh scripts/test/test-profile-shadow.sh
sh scripts/resolve-profile-shadow.sh
sh scripts/resolve-profile-shadow.sh .template/profile.yaml.example
```

Expected: syntax checks and test pass; the template reports compatibility;
the example reports Standard shadow mode.

- [ ] **Step 5: Review and commit the resolver slice**

Run:

```sh
git diff --check
git diff -- scripts/resolve-profile-shadow.sh scripts/test/test-profile-shadow.sh
git add scripts/resolve-profile-shadow.sh scripts/test/test-profile-shadow.sh
git commit -m "feat: add profile shadow resolver"
```

Expected: one resolver/test commit with no workflow or documentation change.

---

### Task 2: Add the isolated advisory workflow and structural contract

**Files:**
- Create: `.github/workflows/profile-shadow.yml`
- Create: `scripts/test/test-profile-shadow-workflow.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `scripts/resolve-profile-shadow.sh` from Task 1.
- Produces: stable check `Profile shadow / Profile policy observation` and a GitHub Job Summary containing the resolver's complete report.

- [ ] **Step 1: Write the failing workflow contract test**

Create `scripts/test/test-profile-shadow-workflow.sh`. Source
`scripts/test/lib.sh`, define `assert_contains` and `assert_not_contains` using
`grep -Eq`, and assert all of these exact contracts:

```text
name: Profile shadow
pull_request targets [main]
push targets [main]
workflow_dispatch exists
permissions block contains only contents: read
job name is Profile shadow / Profile policy observation
timeout-minutes is 3
checkout is pinned to 3d3c42e5aac5ba805825da76410c181273ba90b1 with # v7.0.1
checkout persist-credentials is false
resolver command is sh scripts/resolve-profile-shadow.sh
report is appended to GITHUB_STEP_SUMMARY
```

Assert the workflow does not contain:

```text
pull_request_target
paths:
secrets.
: write
continue-on-error
upload-artifact
github-script
curl
```

Also assert `scripts/setup-branch-protection.sh` does not contain
`Profile shadow / Profile policy observation`.

- [ ] **Step 2: Run the workflow contract test and verify RED**

Run:

```sh
sh scripts/test/test-profile-shadow-workflow.sh
```

Expected: failure because `.github/workflows/profile-shadow.yml` is absent.

- [ ] **Step 3: Create the minimal workflow**

Create `.github/workflows/profile-shadow.yml` exactly from this structure:

```yaml
name: Profile shadow

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  observe:
    name: Profile shadow / Profile policy observation
    runs-on: ubuntu-latest
    timeout-minutes: 3
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Resolve profile policy
        shell: sh
        run: |
          report="${RUNNER_TEMP}/profile-shadow-report.txt"
          sh scripts/resolve-profile-shadow.sh > "$report"
          cat "$report"
          {
            printf '## Profile policy shadow\n\n'
            printf 'This report is observational and changes no workflow execution.\n\n'
            printf '```text\n'
            cat "$report"
            printf '```\n'
          } >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 4: Register both focused tests in the native test gate**

Append these commands after `test-profile-config.sh` in `Makefile`'s
`test-scripts` target:

```make
	@sh scripts/test/test-profile-shadow.sh
	@sh scripts/test/test-profile-shadow-workflow.sh
```

- [ ] **Step 5: Verify the workflow and security contracts**

Run:

```sh
sh scripts/test/test-profile-shadow.sh
sh scripts/test/test-profile-shadow-workflow.sh
command -v actionlint >/dev/null 2>&1 && actionlint .github/workflows/profile-shadow.yml || true
make test-scripts
```

Expected: both focused tests and the full shell suite pass. If actionlint is
installed it must execute and pass; if unavailable, record that it skipped.

- [ ] **Step 6: Review and commit the workflow slice**

Run:

```sh
git diff --check
git diff -- .github/workflows/profile-shadow.yml scripts/test/test-profile-shadow-workflow.sh Makefile
git add .github/workflows/profile-shadow.yml scripts/test/test-profile-shadow-workflow.sh Makefile
git commit -m "ci: add profile shadow observation"
```

Expected: the existing `.github/workflows/ci.yml` and branch-protection script
remain unchanged.

---

### Task 3: Synchronize implementation status and run full local verification

**Files:**
- Modify: `scripts/README.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/adr/0009-observe-profile-policy-before-activation.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/plans/roadmap.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `docs/superpowers/specs/2026-08-11-profile-shadow-mode-design.md`

**Interfaces:**
- Consumes: locally verified resolver and workflow from Tasks 1-2.
- Produces: accurate user guidance and a locally implemented/hosted-pending state without activation claims.

- [ ] **Step 1: Document the resolver and observation boundary**

Add a `scripts/README.md` table row stating that
`resolve-profile-shadow.sh` validates the optional profile and normative
mapping, emits hypothetical decisions, and never controls workflow execution.

Extend README's adoption-profile section with this exact meaning:

```markdown
The separate `Profile shadow / Profile policy observation` check reports how a
valid profile would map controls while every current workflow continues to run.
The check is advisory and is not part of the recommended branch-protection
contexts. Missing profiles retain compatibility mode; shadow evidence does not
authorize profile-aware activation.
```

- [ ] **Step 2: Update lifecycle status without overstating hosted evidence**

Apply these status changes:

- Spec: `**Status:** Implemented locally; hosted validation pending`.
- ADR-0009 and ADR index: `Accepted — observational implementation; activation deferred`.
- Roadmap heading: `P1 — profile shadow mode (implemented locally; hosted pilot pending)`.
- TD-0015 status: `Shadow mode implemented locally; activation deferred`.
- Changelog: replace the design-only ADR-0009 bullet with an Added entry for
  the resolver, advisory workflow, stable observation context, and focused
  contracts; retain the explicit statement that existing controls are
  unchanged.

- [ ] **Step 3: Run the complete local gate**

Run:

```sh
sh scripts/resolve-profile-shadow.sh
sh scripts/resolve-profile-shadow.sh .template/profile.yaml.example
make test-scripts
make docs-check
make security
make ci
git diff --check
git status --short
```

Expected: compatibility and Standard reports are correct; all required local
commands exit `0`; optional unavailable documentation tools are reported as
skipped rather than executed.

- [ ] **Step 4: Prove existing execution surfaces are unchanged**

Run:

```sh
git diff origin/main...HEAD -- .github/workflows/ci.yml scripts/setup-branch-protection.sh scripts/init-project.sh
git diff origin/main...HEAD --name-only
```

Expected: the first command is empty. The complete file list contains only the
approved design/plan, resolver/tests, isolated workflow, Makefile, and minimum
documentation updates.

- [ ] **Step 5: Commit documentation state**

Run:

```sh
git add README.md CHANGELOG.md scripts/README.md docs/adr/0009-observe-profile-policy-before-activation.md docs/adr/README.md docs/plans/roadmap.md docs/plans/technical-debt.md docs/superpowers/specs/2026-08-11-profile-shadow-mode-design.md
git commit -m "docs: document profile shadow observation"
```

Expected: one documentation-only commit.

---

### Task 4: Publish and validate template compatibility mode

**Files:**
- No repository file changes expected.

**Interfaces:**
- Consumes: Tasks 1-3 and current required-check policy.
- Produces: Draft PR evidence that the template's absent profile reports compatibility while all existing checks remain unchanged.

- [ ] **Step 1: Verify branch scope before publication**

Run:

```sh
git status -sb
git log --oneline origin/main..HEAD
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- .github/workflows/ci.yml scripts/setup-branch-protection.sh scripts/init-project.sh
```

Expected: clean worktree; the protected execution files have no diff.

- [ ] **Step 2: Push and open a Draft PR**

Push without force and open a Draft PR titled:

```text
feat: add profile shadow observation
```

The body must state that the new check is advisory, the template has no active
profile, current workflows remain unchanged, and activation is out of scope.

- [ ] **Step 3: Verify hosted compatibility evidence**

Run:

```sh
gh pr checks --watch --interval 10
gh pr view --json number,url,state,isDraft,headRefOid,statusCheckRollup
```

Inspect the new job log and verify:

```text
mode=compatibility
profile=none
status=current-baseline
11 current-baseline control decisions
```

Confirm `Profile shadow / Profile policy observation` is stable, all existing
required/non-skipped checks succeed, and the branch-protection setup output is
unchanged. Do not merge.

- [ ] **Step 4: Report hosted findings for owner review**

Record PR/run/job URLs, exact head SHA, check names, duration, shadow report,
expected skips, and discrepancies. The owner decides whether to merge.

---

### Task 5: Validate Standard and fork behavior after the template merge

**Files:**
- Consumer-only follow-up in `setiyadijoko/template-ai-native-python-coverage-pilot`; no additional template implementation file is expected.

**Interfaces:**
- Consumes: owner-approved template merge and its exact merged shadow files.
- Produces: hosted Standard-profile and fork-safety evidence required before an activation design may begin.

- [ ] **Step 1: Verify the template merge and push-to-main observation**

Identify the merge SHA and exact push-to-main run. Confirm the shadow check
succeeds in compatibility mode with the same context name used on the PR.

- [ ] **Step 2: Create the Standard consumer pilot branch only with owner authorization**

In the existing public Python coverage pilot, branch from `main` and apply the
exact merged versions of:

```text
.template/profile-controls.yaml
.github/workflows/profile-shadow.yml
scripts/resolve-profile-shadow.sh
```

Do not change the consumer's `.template/profile.yaml`, application, pytest
configuration, baseline workflows, or branch protection.

- [ ] **Step 3: Verify the Standard report locally and on a Draft PR**

Run locally:

```sh
sh scripts/validate-profile-config.sh
sh scripts/resolve-profile-shadow.sh
make ci
```

Expected report includes:

```text
mode=shadow
profile=standard
control.codeql.decision=would-run
control.coverage.decision=would-run
```

Open a Draft PR, watch all checks, and confirm the stable shadow context passes
while Python quality, tests, 100% coverage, build, and security still execute.

- [ ] **Step 4: Run one fork pull request without secrets or elevated permissions**

After explicit owner authorization for the fork target, create a fork branch
that changes only a harmless documentation line. Open a pull request to the
consumer `main` and verify the same shadow context succeeds with
`contents: read`, no secret, and no `pull_request_target` execution.

- [ ] **Step 5: Issue the activation-design readiness decision**

Report context stability across template PR, template push, consumer PR,
rerun, and fork; resolver accuracy; duration; warnings; existing-check
stability; and security behavior.

Issue `GO` only for writing a separate activation design when every hosted
criterion passes. Do not add profile conditions, branch-protection contexts,
initializer profile flags, or production behavior in this plan.
