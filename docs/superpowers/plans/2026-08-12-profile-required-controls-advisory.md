# Advisory Profile Required Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-present advisory `Profile policy / Required controls` aggregate that executes real profile-selected controls while preserving all baseline workflows and branch-protection settings.

**Architecture:** A POSIX execution-plan resolver consumes the existing central profile-policy report and canonical project/stack detection. Existing workflows expose reusable `workflow_call` boundaries, a thin orchestrator invokes the planned boundaries, and a POSIX evaluator converts the plan plus `needs.*.result` into the stable aggregate conclusion. The aggregate remains advisory; no baseline trigger or required context is removed or changed.

**Tech Stack:** POSIX `sh`, GitHub Actions reusable workflows, existing stack toolchain workflows, local shell contract tests, actionlint/zizmor through repository-native gates.

## Global Constraints

- Follow `AGENTS.md`, ADR-0010, and `docs/superpowers/specs/2026-08-12-profile-required-controls-advisory-design.md`.
- Keep `scripts/resolve-profile-policy.sh` as the only Starter/Standard/Enterprise mapping owner.
- The stable check name is exactly `Profile policy / Required controls`.
- Use `pull_request`, never `pull_request_target`; mandatory fork paths consume no repository secret.
- Preserve all existing direct workflow triggers and the five invariant required contexts.
- Do not add the aggregate to `scripts/setup-branch-protection.sh`.
- Do not suppress duplicate baseline execution, activate deployments, call model providers, or claim post-merge/manual policy as executed.
- All new shell scripts must be POSIX-compatible and deterministic on macOS `/bin/sh` and Linux `dash`.
- Every third-party Action remains pinned to an immutable commit SHA with a release-tag comment.
- Commit each task separately with Conventional Commits and update `CHANGELOG.md` only in the documentation task.

---

## File structure

**Create**

- `scripts/resolve-profile-execution-plan.sh` — translates central policy plus repository shape into boundary decisions.
- `scripts/evaluate-profile-required-controls.sh` — validates actual job conclusions against the execution plan.
- `scripts/test/test-profile-execution-plan.sh` — local table/fixture contracts for all execution modes.
- `scripts/test/test-profile-required-controls-evaluator.sh` — local result matrix and failure propagation contracts.
- `scripts/test/test-profile-required-controls-workflow.sh` — structural security/orchestration contract.
- `.github/workflows/profile-required-controls.yml` — always-present advisory orchestrator and aggregate.

**Modify**

- `Makefile` — register the three new contract suites.
- `.github/workflows/secret-scan.yml` — add reusable call support while preserving direct triggers.
- `.github/workflows/dependency-review.yml` — add reusable call support while preserving direct triggers.
- `.github/workflows/codeql.yml` — add reusable call support while preserving direct triggers and job-scoped SARIF permission.
- `.github/workflows/ai-evaluation.yml` — add credential-free deterministic reusable mode while preserving the direct advisory mode.
- `.github/workflows/ci.yml`, `.github/workflows/ci-quality.yml`, `.github/workflows/ci-test.yml`, `.github/workflows/ci-monorepo.yml` — distinguish baseline and advisory reusable calls so concurrent duplicate evidence cannot self-cancel.
- `scripts/README.md` — document plan/evaluator contracts.
- `README.md`, `docs/getting-started.md` — describe advisory aggregate and non-enforcement boundary.
- `docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md`, `docs/plans/roadmap.md`, `docs/plans/technical-debt.md`, `CHANGELOG.md` — synchronize governance status.
- `docs/superpowers/specs/2026-08-12-profile-required-controls-advisory-design.md` — retain approved status and synchronize only if implementation reveals an approved clarification.

---

### Task 1: Deterministic execution-plan resolver

**Files:**
- Create: `scripts/resolve-profile-execution-plan.sh`
- Create: `scripts/test/test-profile-execution-plan.sh`
- Modify: `Makefile:8,64-88`

**Interfaces:**
- Consumes: `scripts/resolve-profile-policy.sh [PROFILE_PATH] [MAPPING_PATH] [PROJECT_PATH]`, `scripts/detect-stack.sh`, `scripts/resolve-components.sh --layout PROJECT_PATH`, and version-2 component validation.
- Produces: fixed-order `key=value` records with top-level `mode`, `profile`, `layout`, `stack`, `status`, followed by the boundaries `quality_unit`, `test_coverage`, `monorepo_ci`, `secret_scan`, `dependency_review`, `codeql`, `ai_evaluation`, `sbom`, `artifact_attestation`, `scorecard`, `semantic_review`, `structural_review`, and `production_governance`. Every boundary emits exactly `decision`, `required`, and `reason`.
- Allowed decisions: `run`, `planned-skip`, `not-applicable`, `delegated-to-current-baseline`, `policy-only`.
- Normalized top-level states: compatibility emits `mode=compatibility`,
  `profile=none`, `layout=unknown`, `stack=unknown`, `status=delegated`;
  initialized valid plans emit `mode=profile`, selected profile/layout/stack,
  and `status=ready`.
- Allowed reason literals are implementation-owned bounded tokens, including
  `current-baseline`, `required-by-profile`, `disabled-by-profile`,
  `no-executable-stack`, `covered-by-monorepo-boundary`,
  `post-merge-control`, `scheduled-control`, `manual-environment-control`, and
  `advisory-policy-only`.
- CLI: `sh scripts/resolve-profile-execution-plan.sh [--policy-report FILE] [PROFILE_PATH] [MAPPING_PATH] [PROJECT_PATH]`. Normal execution calls the central resolver. `--policy-report` accepts a precomputed regular, non-symlink report only for parser diagnostics and contract fixtures; it never executes content. Repository layout and stack are always detected from the current working directory through canonical scripts.

- [ ] **Step 1: Write the failing execution-mode contract**

Create the test harness and fixture helpers first. Assert this exact compatibility subset:

```sh
compatibility="$(cd "$WORK/template" && sh "$PLAN" \
  "$WORK/missing-profile.yaml" "$MAPPING" "$WORK/missing-project.yaml")"
assert_contains "compatibility mode" "$compatibility" '^mode=compatibility$'
assert_contains "compatibility quality delegation" "$compatibility" \
  '^boundary\.quality_unit\.decision=delegated-to-current-baseline$'
assert_contains "compatibility secret delegation" "$compatibility" \
  '^boundary\.secret_scan\.decision=delegated-to-current-baseline$'
assert_count "all boundaries have three fields" "$compatibility" \
  '^boundary\.[^.]+\.(decision|required|reason)=' 39
```

Add initialized no-stack fixtures for all three profiles. For Enterprise, pass
a safe non-production deployment target because the initializer requires one.
Assert secret and dependency decisions are `run|required=true`, while
`quality_unit`, `test_coverage`, and `codeql` are
`not-applicable|required=false` with reason `no-executable-stack`. Add one
AI-enabled no-stack fixture and assert deterministic AI follows effective
policy independently of application stack detection.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
sh -n scripts/test/test-profile-execution-plan.sh
sh scripts/test/test-profile-execution-plan.sh
```

Expected: syntax exits 0; contract exits non-zero because
`scripts/resolve-profile-execution-plan.sh` does not exist.

- [ ] **Step 3: Implement compatibility and no-stack planning**

Implement a POSIX script with:

```sh
BOUNDARIES='quality_unit test_coverage monorepo_ci secret_scan dependency_review codeql ai_evaluation sbom artifact_attestation scorecard semantic_review structural_review production_governance'

emit_boundary() {
  boundary="$1"; decision="$2"; required="$3"; reason="$4"
  printf 'boundary.%s.decision=%s\nboundary.%s.required=%s\nboundary.%s.reason=%s\n' \
    "$boundary" "$decision" "$boundary" "$required" "$boundary" "$reason"
}
```

Capture central policy stdout to a restrictive temporary file, relay its
warnings, validate that all expected central fields occur exactly once, and
emit fixed-order records. Compatibility delegates every boundary. An
initialized no-stack consumer runs stack-neutral boundaries and makes
stack-dependent boundaries not applicable.

Validate top-level values and emit only internal reason literals matching
`^[a-z0-9][a-z0-9-]{0,63}$`; never copy arbitrary consumer or resolver text into
a reason record.

- [ ] **Step 4: Run the focused contract and verify GREEN for the first modes**

Run:

```bash
sh -n scripts/resolve-profile-execution-plan.sh
sh scripts/test/test-profile-execution-plan.sh
```

Expected: the compatibility/no-stack assertions pass; test still exits non-zero
only for the not-yet-implemented single-stack/monorepo cases added next.

- [ ] **Step 5: Add failing single-stack profile matrix cases**

Generate valid Starter, Standard, and Enterprise profiles through
`scripts/init-project.sh` in isolated fixture repositories, add the same
minimal root `pyproject.toml` manifest to each, and run the planner from each
fixture root. Pass `--deployment-target self-hosted` for Enterprise so the
fixture satisfies the initializer without activating deployment. Assert:

```text
Starter:    quality_unit=run, test_coverage=planned-skip, codeql=planned-skip
Standard:   quality_unit=run, test_coverage=run,          codeql=run
Enterprise: quality_unit=run, test_coverage=run,          codeql=run
All:        secret_scan=run, dependency_review=run
```

Add a strengthened Starter fixture with coverage and CodeQL enabled and assert
both become `run|required=true`. Add AI-disabled, Standard AI-enabled, and
Enterprise AI-enabled fixtures; AI evaluation runs only when the central
policy reports it enabled and required.

- [ ] **Step 6: Run the profile matrix and verify RED**

Run: `sh scripts/test/test-profile-execution-plan.sh`

Expected: non-zero with missing or incorrect single-stack decisions.

- [ ] **Step 7: Implement single-stack mapping from central fields**

Read only central `control.<name>.enabled`, `.class`, `.policy_required`,
`.pr_required`, and `.alignment`. Do not parse profile names into a second
mapping. Reject `status=warning` or any `policy-mismatch`. Map:

- every executable single stack to `quality_unit=run|required=true`;
- coverage `enabled=true` to `test_coverage=run|required=true`, otherwise
  `planned-skip|required=false`;
- CodeQL and AI evaluation using their effective enabled/required fields;
- an enabled post-merge/scheduled/manual control to
  `policy-only|required=false`, otherwise `planned-skip|required=false`;
- an enabled semantic/structural review to `policy-only|required=false` for
  this PR, otherwise `planned-skip|required=false`; and
- `monorepo_ci=not-applicable|required=false` for an explicit single layout.

- [ ] **Step 8: Add and implement monorepo-v2 cases**

Generate a valid monorepo-v2 consumer through `scripts/init-project.sh` in the
temporary test workspace and add minimal component manifests. Assert:

```text
layout=monorepo
stack=unknown
boundary.monorepo_ci.decision=run
boundary.monorepo_ci.required=true
boundary.quality_unit.decision=planned-skip
boundary.test_coverage.decision=planned-skip
```

The reason for both single-stack boundaries is `covered-by-monorepo-boundary`.
An invalid v1 monorepo declaration or invalid component config fails closed.
An undecided layout with no executable stack uses the initialized no-stack
mode; an undecided layout after a manifest appears fails closed until the
consumer explicitly selects `single` or `monorepo`.

- [ ] **Step 9: Add malformed-output and determinism defenses**

Use `--policy-report FILE` fixtures to prove failure for duplicate, unknown,
missing, and malformed central records. Also prove failure for a directory,
symlink, and dangling-symlink report path and unsupported layout/stack
combinations. Run the same valid plan twice and assert byte-identical output.
Assert every one of the 13 boundaries has exactly three fields.

- [ ] **Step 10: Register and run the new contract**

Add `sh scripts/test/test-profile-execution-plan.sh` after
`test-profile-policy.sh` and before shadow tests in `make test-scripts`.

Run:

```bash
sh -n scripts/resolve-profile-execution-plan.sh
sh -n scripts/test/test-profile-execution-plan.sh
sh scripts/test/test-profile-execution-plan.sh
make test-scripts
git diff --check
```

Expected: all exit 0, with the focused test reporting zero failures.

- [ ] **Step 11: Commit Task 1**

```bash
git add Makefile scripts/resolve-profile-execution-plan.sh \
  scripts/test/test-profile-execution-plan.sh
git commit -m "feat: resolve profile execution plans"
```

---

### Task 2: Fail-closed aggregate result evaluator

**Files:**
- Create: `scripts/evaluate-profile-required-controls.sh`
- Create: `scripts/test/test-profile-required-controls-evaluator.sh`
- Modify: `Makefile:64-90`

**Interfaces:**
- Consumes: plan file from Task 1 and an outcomes file containing exactly one
  `boundary.<name>.conclusion=<success|failure|cancelled|skipped>` for every
  boundary.
- Produces: deterministic stdout records `aggregate.status=pass|fail`,
  `boundary.<name>.verdict=<pass|fail|warning|planned>`, and
  `boundary.<name>.detail=<reason>`. Exit 0 only for aggregate pass.
- CLI: `sh scripts/evaluate-profile-required-controls.sh PLAN_FILE OUTCOMES_FILE`.

- [ ] **Step 1: Write the failing decision/conclusion matrix**

Create table-driven fixtures covering:

```sh
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
```

Each fixture must include all 13 boundaries so the evaluator cannot pass on a
partial outcomes file.

- [ ] **Step 2: Run the evaluator test and verify RED**

Run:

```bash
sh -n scripts/test/test-profile-required-controls-evaluator.sh
sh scripts/test/test-profile-required-controls-evaluator.sh
```

Expected: syntax exits 0; test exits non-zero because the evaluator is absent.

- [ ] **Step 3: Implement strict parsing and matrix evaluation**

Validate that both files are regular, non-symlink files; every expected
boundary and field occurs exactly once; plan decisions/required flags are
allowed; outcomes are allowed; and no unknown keys exist. Use a fixed boundary
order, validate reason records against the same bounded token format, and never
use `eval`, `source`, or dynamic command execution.

For `run|required=false`, success yields `pass`; failure/cancelled/skipped yields
`warning` and does not override a required failure. For every non-run decision,
only actual `skipped` is valid.

- [ ] **Step 4: Add fail-closed parser regressions**

Prove failure for missing plan/outcome files, directories, symlinks, duplicate
keys, unknown boundary, missing conclusion, unknown decision, invalid Boolean,
unknown conclusion, and a missing top-level plan status. Assert the evaluator's
stderr prefix is exactly `profile-required-controls:`.

- [ ] **Step 5: Verify determinism and full focused GREEN**

Run the same passing and failing fixtures twice; stdout, stderr, and exit codes
must be byte-identical.

Run:

```bash
sh -n scripts/evaluate-profile-required-controls.sh
sh -n scripts/test/test-profile-required-controls-evaluator.sh
sh scripts/test/test-profile-required-controls-evaluator.sh
```

Expected: exit 0 with zero failed assertions.

- [ ] **Step 6: Register, run the full script suite, and commit**

Register the evaluator test immediately after the execution-plan test.

Run:

```bash
make test-scripts
git diff --check
```

Expected: exit 0.

Commit:

```bash
git add Makefile scripts/evaluate-profile-required-controls.sh \
  scripts/test/test-profile-required-controls-evaluator.sh
git commit -m "feat: evaluate required profile controls"
```

---

### Task 3: Reusable and channel-isolated control boundaries

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/ci-quality.yml`
- Modify: `.github/workflows/ci-test.yml`
- Modify: `.github/workflows/ci-monorepo.yml`
- Modify: `.github/workflows/secret-scan.yml`
- Modify: `.github/workflows/dependency-review.yml`
- Modify: `.github/workflows/codeql.yml`
- Modify: `.github/workflows/ai-evaluation.yml`
- Create: `scripts/test/test-profile-control-boundaries.sh`
- Modify: `Makefile:64-92`

**Interfaces:**
- Produces reusable workflows callable with no secret input.
- Direct baseline events remain identical to their pre-task event sets.
- Every called boundary accepts a validated `execution_channel`; the baseline
  dispatcher passes `baseline-ci`, and the advisory caller passes
  `profile-advisory` in Task 4.
- Deterministic AI reusable mode always executes `sh evals/run-evals.sh --check`
  without reading `AI_EVAL_API_KEY`.

- [ ] **Step 1: Write the failing structural boundary contract**

For the four security/AI workflows assert `workflow_call:` exists. Assert
existing triggers remain:

```text
secret-scan: pull_request, push main, schedule, workflow_dispatch
dependency-review: pull_request, workflow_dispatch
codeql: pull_request main, push main, schedule, workflow_dispatch
ai-evaluation: pull_request path-filtered, workflow_dispatch
```

Also assert `permissions: contents: read`, exact existing check names, action
SHAs, no `pull_request_target`, and no new secret input.

For `ci-quality.yml`, `ci-test.yml`, and `ci-monorepo.yml`, assert the existing
`workflow_call` contract gains a string `execution_channel` input and that
`ci.yml` passes `baseline-ci`. Assert all seven called-workflow concurrency
groups include their workflow-specific suffix, explicit channel, and PR/ref/run
identity. Do not rely on `github.event_name` to distinguish calls because a
reusable workflow inherits the caller's event context.

Assert each called control validates its effective channel before tool setup:
CI boundaries accept `baseline-ci`, `profile-advisory`, or `manual`; direct
security/AI boundaries use `baseline-direct`, and their reusable path accepts
`profile-advisory`. Unknown values fail before the control executes.

For AI, assert the reusable path contains `evals/run-evals.sh --check`, has no
`secrets.` or `AI_EVAL_API_KEY`, and the direct advisory path retains its
existing credential-aware behavior.

- [ ] **Step 2: Run the structural test and verify RED**

Run: `sh scripts/test/test-profile-control-boundaries.sh`

Expected: non-zero because reusable calls are absent on the four workflows.

- [ ] **Step 3: Isolate existing CI reusable calls by execution channel**

Add optional string `execution_channel` inputs to `ci-quality.yml`,
`ci-test.yml`, and `ci-monorepo.yml`. The baseline dispatcher passes
`baseline-ci` to each call; direct manual dispatch falls back to `manual`.
Preserve every job name, command, action pin, and direct trigger. Change only
their concurrency groups and add a first-step channel assertion, using this
pattern with the existing workflow suffix:

```yaml
group: ${{ github.workflow }}-ci-quality-${{ inputs.execution_channel || 'manual' }}-${{ github.event.pull_request.number || github.ref || github.run_id }}
```

Run `scripts/test/test-monorepo-ci.sh` immediately to protect the existing
reusable-workflow suffix invariant.

- [ ] **Step 4: Add `workflow_call` to secret and dependency workflows**

Add a required string `execution_channel` input under `workflow_call`; retain
all direct triggers and job bodies. Direct events use `baseline-direct` as the
channel fallback, while reusable calls provide `profile-advisory`. Include the
workflow-specific suffix, channel, and PR/ref/run identity in concurrency so
the intentional direct and advisory scans cannot cancel each other. Add a
first-step assertion that accepts only those two effective channel values.

- [ ] **Step 5: Add reusable CodeQL with job-scoped permission unchanged**

Add `workflow_call.execution_channel`, direct-event fallback, and channel-aware
concurrency. Keep `security-events: write` on the CodeQL job only. Do not grant
it to the future orchestrator globally. Preserve scanner and SARIF fail-closed
behavior.

- [ ] **Step 6: Separate deterministic reusable AI mode**

Add required `workflow_call.execution_channel`. The reusable job is selected
only when that validated input is non-empty and unconditionally runs the
provider-neutral contract. It has no secret environment. Keep the existing
direct event behavior in a separate job selected only when the input is empty;
that job alone retains `AI_EVAL_API_KEY` and the existing advisory check name.
Give the reusable job a distinct deterministic internal name. Do not use
`github.event_name` as a call-mode discriminator.

If GitHub reusable-workflow syntax cannot safely isolate the secret in one
file, stop and revise the design before implementing; do not pass a secret from
the orchestrator as a workaround.

- [ ] **Step 7: Verify action security and baseline-trigger preservation**

Run:

```bash
sh scripts/test/test-profile-control-boundaries.sh
sh scripts/test/test-monorepo-ci.sh
sh scripts/test/test-security-workflows.sh
sh scripts/test/test-prompt-eval-assets.sh
make docs-check
make test-scripts
git diff --check
```

Expected: all exit 0. `make docs-check` may explicitly skip unavailable local
tools; installed actionlint/gitleaks findings must be zero.

- [ ] **Step 8: Commit Task 3**

```bash
git add .github/workflows/ci.yml .github/workflows/ci-quality.yml \
  .github/workflows/ci-test.yml .github/workflows/ci-monorepo.yml \
  .github/workflows/secret-scan.yml \
  .github/workflows/dependency-review.yml .github/workflows/codeql.yml \
  .github/workflows/ai-evaluation.yml Makefile \
  scripts/test/test-profile-control-boundaries.sh
git commit -m "ci: expose reusable profile control boundaries"
```

---

### Task 4: Advisory orchestrator and stable aggregate

**Files:**
- Create: `.github/workflows/profile-required-controls.yml`
- Create: `scripts/test/test-profile-required-controls-workflow.sh`
- Modify: `Makefile:64-94`

**Interfaces:**
- Consumes: Task 1 plan records, reusable workflows from Task 3,
  `ci-quality.yml`, `ci-test.yml`, and `ci-monorepo.yml`.
- Produces: exact check context `Profile policy / Required controls` and a Job
  Summary containing normalized plan/evaluator records.
- Workflow name is `Profile policy`; aggregate job name is `Required controls`,
  which together form the exact resulting check context.
- Job IDs: `plan`, `quality_unit`, `test_coverage`, `monorepo_ci`,
  `secret_scan`, `dependency_review`, `codeql`, `ai_evaluation`, `aggregate`.

- [ ] **Step 1: Write the failing workflow structural contract**

Assert exact name/triggers/permissions/no paths, expected job IDs, reusable
workflow paths, `plan` outputs, aggregate `needs` list, `if: always()`, and exact
aggregate job name. Assert no `pull_request_target`, no `secrets: inherit`, no
write permission outside the CodeQL caller/called boundary, and no unpinned
Action.

Assert `scripts/setup-branch-protection.sh` does not contain
`Profile policy / Required controls`.

- [ ] **Step 2: Run the workflow test and verify RED**

Run: `sh scripts/test/test-profile-required-controls-workflow.sh`

Expected: non-zero because the workflow does not exist.

- [ ] **Step 3: Implement plan job and outputs**

The plan job checks out with `persist-credentials: false`, runs:

```sh
report="${RUNNER_TEMP}/profile-execution-plan.txt"
sh scripts/resolve-profile-execution-plan.sh > "$report"
cat "$report"
```

Expose only validated enum/Boolean fields needed by job-level `if` expressions:
`mode`, `profile`, `layout`, `stack`, and each executable boundary's
`decision`/`required`. Use a shell helper that retrieves an exact key once and
fails if absent/duplicate; never append unvalidated arbitrary output names.
Use underscore output identifiers such as `quality_unit_decision` consistently.

- [ ] **Step 4: Wire the reusable jobs without secrets**

Use plan decisions:

```yaml
quality_unit:
  needs: plan
  if: needs.plan.outputs.quality_unit_decision == 'run'
  uses: ./.github/workflows/ci-quality.yml
  with:
    stack: ${{ needs.plan.outputs.stack }}
    execution_channel: profile-advisory
```

Apply the same bounded form to test/coverage, monorepo, secret, dependency,
CodeQL, and deterministic AI. Every called boundary receives the literal
`profile-advisory` channel. Do not use `secrets: inherit`.

The CodeQL caller job alone declares `contents: read` and
`security-events: write`; the reusable CodeQL job retains the same minimum
permissions. This is required because a called workflow cannot elevate beyond
its caller. No other orchestrator job receives write permission.

- [ ] **Step 5: Write the aggregate outcomes file and invoke evaluator**

The aggregate is named `Required controls`, has `if: always()`, and `needs`
every job. Materialize conclusions as literals supplied through environment
variables, then write exact fixed keys:

```sh
printf 'boundary.quality_unit.conclusion=%s\n' "$QUALITY_UNIT_RESULT"
```

For policy-only boundaries with no GitHub job, write `skipped`. Pass the plan
artifact as validated text by rerunning the deterministic plan resolver in the
aggregate checkout rather than transporting untrusted multiline job output.
Compare the rerun top-level identity with the plan-job outputs before evaluating.

Check `needs.plan.result` first. If it is not `success`, rerun the plan only to
capture a diagnostic, append the diagnostic and the plan conclusion to the Job
Summary, and exit non-zero without invoking the evaluator. This preserves the
stable aggregate context even when planning itself fails.

Append the evaluator report to `$GITHUB_STEP_SUMMARY`; if evaluator exits
non-zero, print its report first, then fail the aggregate.

- [ ] **Step 6: Add failure-semantics source assertions**

The structural contract must prove:

- every executable job depends on `plan`;
- aggregate depends on plan plus all executable jobs;
- aggregate invokes `evaluate-profile-required-controls.sh`;
- no job uses `continue-on-error` to mask a required boundary;
- compatibility/planned skips still create the aggregate; and
- the workflow/job name pair yields the intended context and is not duplicated
  elsewhere.

- [ ] **Step 7: Run workflow/security suites and verify GREEN**

Run:

```bash
sh scripts/test/test-profile-required-controls-workflow.sh
sh scripts/test/test-profile-control-boundaries.sh
sh scripts/test/test-profile-execution-plan.sh
sh scripts/test/test-profile-required-controls-evaluator.sh
make docs-check
make test-scripts
git diff --check
```

Expected: all exit 0; actionlint and zizmor findings introduced by this workflow
are zero. If `zizmor` is unavailable locally, the hosted action-security check
remains required before merge.

- [ ] **Step 8: Commit Task 4**

```bash
git add .github/workflows/profile-required-controls.yml Makefile \
  scripts/test/test-profile-required-controls-workflow.sh
git commit -m "ci: add advisory profile required controls"
```

---

### Task 5: Governance and consumer guidance synchronization

**Files:**
- Modify: `README.md:165-192`
- Modify: `docs/getting-started.md` profile/CI sections
- Modify: `scripts/README.md:18-25`
- Modify: `docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md:1-8,156-177`
- Modify: `docs/plans/roadmap.md:128-219`
- Modify: `docs/plans/technical-debt.md:21`
- Modify: `CHANGELOG.md:8-21`
- Modify: `docs/superpowers/specs/2026-08-12-profile-required-controls-advisory-design.md:1-6` only if status wording needs synchronization

**Interfaces:**
- Documents: advisory aggregate implemented, duplicate execution intentional,
  branch protection/enforcement/duplicate removal still pending hosted evidence.

- [ ] **Step 1: Add failing documentation assertions**

Extend `scripts/test/test-profile-required-controls-workflow.sh` to assert the
governance documents contain all of:

```text
Profile policy / Required controls
advisory
duplicate baseline
enforcement NO-GO
```

and that branch-protection guidance does not recommend the aggregate yet.

- [ ] **Step 2: Run the focused contract and verify RED**

Run: `sh scripts/test/test-profile-required-controls-workflow.sh`

Expected: non-zero because implementation status is not yet synchronized.

- [ ] **Step 3: Update consumer-facing guidance**

Explain the four execution modes, what the aggregate does, why baseline checks
may appear twice during the pilot, and how to run:

```sh
make profile-policy-check
sh scripts/resolve-profile-execution-plan.sh
```

State that the aggregate is advisory and absent from branch protection.

- [ ] **Step 4: Update governance records truthfully**

- ADR-0010 status: `Accepted — advisory aggregate implemented; hosted enforcement evidence pending`.
- Roadmap: mark local advisory implementation complete; keep hosted pilot,
  migration, enforcement, and duplicate removal pending.
- TD-0015: change foundation/orchestrator portion to implemented; leave pilots,
  cost/noise, branch protection, rollback, and removal open.
- Changelog: add the advisory aggregate and reusable boundaries; explicitly say
  current workflow execution and branch protection remain unchanged.

Do not include unresolved marker tokens outside allowed plan/internal paths.

- [ ] **Step 5: Verify documentation and commit**

Run:

```bash
sh scripts/test/test-profile-required-controls-workflow.sh
make docs-check
make test-scripts
git diff --check
```

Expected: all exit 0; unavailable optional docs tools are reported as skipped.

Commit:

```bash
git add README.md docs/getting-started.md scripts/README.md CHANGELOG.md \
  docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md \
  docs/plans/roadmap.md docs/plans/technical-debt.md \
  docs/superpowers/specs/2026-08-12-profile-required-controls-advisory-design.md \
  scripts/test/test-profile-required-controls-workflow.sh
git commit -m "docs: explain advisory profile aggregation"
```

---

### Task 6: Full local verification and implementation report

**Files:**
- No planned tracked file changes.
- Create ignored execution evidence under `.superpowers/sdd/<plan-id>/` only
  when using subagent-driven development.

**Interfaces:**
- Verifies the complete advisory implementation against the approved spec and
  records actual evidence for the PR body.

- [ ] **Step 1: Run every modified shell syntax check**

```bash
sh -n scripts/resolve-profile-execution-plan.sh
sh -n scripts/evaluate-profile-required-controls.sh
sh -n scripts/test/test-profile-execution-plan.sh
sh -n scripts/test/test-profile-required-controls-evaluator.sh
sh -n scripts/test/test-profile-control-boundaries.sh
sh -n scripts/test/test-profile-required-controls-workflow.sh
```

Expected: all exit 0.

- [ ] **Step 2: Run focused contracts**

```bash
sh scripts/test/test-profile-execution-plan.sh
sh scripts/test/test-profile-required-controls-evaluator.sh
sh scripts/test/test-profile-control-boundaries.sh
sh scripts/test/test-profile-required-controls-workflow.sh
```

Expected: every contract reports zero failures.

- [ ] **Step 3: Run repository-native gates**

```bash
make test-scripts
make docs-check
make ci
```

Expected: all exit 0. Record optional-tool skips exactly; do not call them
passes.

- [ ] **Step 4: Inspect the complete branch diff**

```bash
git diff --check main...HEAD
git diff --name-status main...HEAD
git diff --stat main...HEAD
git diff main...HEAD
```

Confirm:

- no branch-protection helper change;
- no baseline trigger removed;
- no invariant context renamed;
- no `pull_request_target`, `secrets: inherit`, mutable Action ref, credential,
  deployment, or production behavior;
- every tracked file maps to this plan; and
- documentation matches actual advisory behavior.

- [ ] **Step 5: Run final whole-branch review**

If the user explicitly selected subagent-driven execution, request a fresh
reviewer using `superpowers:requesting-code-review` with
`BASE=$(git merge-base main HEAD)` and `HEAD=$(git rev-parse HEAD)`. Otherwise,
perform the same complete-diff review in the primary agent. Resolve Critical
and Important findings and re-review the fix scope before completion.

- [ ] **Step 6: Prepare hosted pilot handoff, without running it automatically**

Report:

- files/architecture changed;
- test and security commands actually executed;
- skipped optional tools;
- current advisory/no-enforcement status;
- remaining hosted scenarios from the spec;
- expected duplicate-cost period; and
- exact next step: push a reviewed implementation PR, then create disposable
  Starter/Standard/Enterprise pilots only with separate user authorization.

No production deployment, branch-protection change, consumer creation, or
hosted failure injection is authorized by this plan alone.
