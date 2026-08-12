# Advisory Profile Required Controls Design

**Status:** Implemented locally — hosted enforcement evidence pending
**Date:** 2026-08-12
**Owner:** Template maintainers
**Decision reference:** ADR-0010

## Purpose

Implement the first execution slice of ADR-0010: one always-present advisory
aggregate named `Profile policy / Required controls` that executes real
profile-dependent controls without changing branch protection or suppressing
any existing baseline workflow.

The implementation must produce hosted evidence that a stable aggregate can
represent different Starter, Standard, and Enterprise execution plans safely.
It is not profile enforcement. During the pilot, selected controls execute a
second time through reusable workflow boundaries while their existing direct
workflow triggers remain active.

## Business value

The profile foundation currently describes the intended engineering posture
but does not prove that GitHub Actions can apply it without missing checks,
silent skips, fork-secret exposure, or profile-specific branch administration.
This advisory slice converts the declarative policy into observable execution
evidence while retaining the stronger current baseline as the rollback path.

The intended outcome is a defensible enforcement decision based on actual
runtime, failure propagation, and fork evidence rather than a configuration-
only simulation.

## Goals

- Publish one stable aggregate context on pull requests, pushes to `main`, and
  manual diagnostic runs.
- Use `scripts/resolve-profile-policy.sh` as the only normative profile-policy
  source.
- Execute real required controls through bounded reusable workflows.
- Make required failure, cancellation, and unexpected skip visible as a
  non-successful aggregate.
- Keep planned skips and no-stack outcomes explicit and non-misleading.
- Preserve every existing direct workflow trigger during the pilot.
- Retain read-only, secret-free fork behavior for mandatory controls.
- Gather comparable hosted evidence for Starter, Standard, and Enterprise.

## Non-goals

- Adding the aggregate to branch protection.
- Removing, suppressing, renaming, or path-filtering baseline workflows.
- Changing the five invariant governance contexts.
- Making individual profile-dependent jobs required contexts.
- Optimizing profile-aware execution inside monorepo v2.
- Activating SBOM, attestation, Scorecard, deployment, or production operations
  from a pull request.
- Calling a model provider or exposing a provider credential to untrusted code.
- Treating semantic or structural AI findings as merge authority.
- Migrating historical disposable consumer pilots.

## Chosen approach

Use a thin orchestrator backed by the repository's existing reusable workflow
boundaries. Direct baseline triggers remain on each workflow, and
`workflow_call` is added only where orchestration needs an existing control to
be callable.

This approach is preferred over duplicating commands into a new profile
workflow because it keeps tool setup, action pins, permissions, and control
behavior in one implementation. It is preferred over a monolithic workflow
because each control keeps a distinct conclusion that the aggregate can
attribute and test.

Temporary duplicate execution is intentional. It provides equivalence and
failure-propagation evidence before the existing baseline is changed. Duplicate
cost is measured during the pilot and removed only in a later reviewed change.
Every reusable boundary accepts an explicit non-secret `execution_channel`
input. Existing callers pass `baseline-ci`, while the advisory orchestrator
passes `profile-advisory`. Reusable-workflow concurrency keys include that
bounded channel so duplicate pilot runs cannot cancel one another through an
ambiguous inherited GitHub event context. The called job validates the channel
against its documented literals before executing the control.

## Architecture

The advisory slice has four units:

1. **Execution-plan resolver** — translates the central policy report plus
   detected repository layout into deterministic run, skip, required, and
   not-applicable decisions.
2. **Reusable control boundaries** — expose existing quality/unit, test and
   coverage, monorepo, secret, dependency, CodeQL, and deterministic AI
   controls through `workflow_call` without removing their direct triggers.
3. **Profile orchestrator** — runs on every supported event, resolves the plan,
   invokes the planned reusable boundaries, and always starts the aggregate
   job after its dependencies settle.
4. **Result evaluator** — compares planned decisions with actual GitHub job
   conclusions and fails closed for invalid or incomplete required outcomes.

Workflow YAML remains wiring. Profile mapping, plan generation, and result
classification live in POSIX scripts with local contract tests.

## Stable GitHub Actions contract

- Workflow file: `.github/workflows/profile-required-controls.yml`.
- Workflow name: `Profile policy`.
- Aggregate job name: `Required controls`.
- Resulting check context: `Profile policy / Required controls`.
- Events: pull requests targeting `main`, pushes to `main`, and
  `workflow_dispatch`.
- No path filters.
- Default permissions: `contents: read`.
- Event safety: `pull_request`, never `pull_request_target`.
- Concurrency: one current run per pull request or ref, with stale runs
  cancelled.
- The workflow consumes no repository secret for mandatory deterministic
  controls.
- The aggregate is not added to `scripts/setup-branch-protection.sh` in this
  implementation.

The aggregate job uses `if: always()` and depends on the plan plus every
profile-dependent control job. A failed plan therefore still produces the
stable aggregate context and a diagnostic summary.

If an entire workflow run is manually cancelled, GitHub may mark the aggregate
itself cancelled. That remains a safe non-success outcome; the design does not
claim that a cancelled run can manufacture a successful aggregate.

## Execution modes

### Template compatibility

When neither `.template/project.yaml` nor `.template/profile.yaml` exists:

- the central resolver returns compatibility mode;
- the orchestrator publishes the aggregate;
- no duplicate profile-dependent control is invoked;
- every control is reported as `delegated-to-current-baseline`; and
- existing direct workflows continue to provide the actual baseline evidence.

Compatibility mode is limited to the empty template state. A one-sided
consumer configuration remains invalid and fails closed.

### Initialized consumer without an executable stack

When valid project/profile configuration exists but stack detection returns
`unknown`:

- secret scan and dependency baseline execute because they are stack-neutral;
- deterministic AI evaluation executes if enabled and required by the effective
  profile;
- quality/unit, test/coverage, and CodeQL are reported as
  `not-applicable — no executable stack`;
- post-merge, scheduled, and manual controls are reported as configured policy,
  not as completed execution; and
- the aggregate succeeds only if every actually required stack-neutral job
  succeeds.

This permits a documentation/bootstrap pull request to remain green without
pretending that application tests ran.

### Initialized single-stack consumer

For Python, Node.js, Go, Java, or .NET single-stack consumers:

- quality plus unit tests execute for every profile through
  `ci-quality.yml`;
- secret scan and dependency baseline execute for every profile;
- integration/e2e/coverage execute through `ci-test.yml` when coverage is
  enabled by the profile or explicit strengthening;
- CodeQL executes when enabled by the profile or explicit strengthening; and
- deterministic AI evaluation executes when AI is active and effective policy
  requires it.

Starter therefore avoids at least the integration/e2e/coverage and CodeQL
duplicate jobs when those controls retain Starter defaults. Standard and
Enterprise execute both. An explicitly strengthened Starter profile executes
the enabled stronger controls.

### Initialized monorepo v2 consumer

A valid version-2 component configuration invokes `ci-monorepo.yml` as one
combined required boundary. The boundary represents the current component-
aware quality, test, coverage, build, and stable component aggregate behavior.

Secret scan and dependency baseline still execute separately. CodeQL and
deterministic AI evaluation follow their effective profile decisions because
they operate at repository scope.

The initial advisory slice does not split monorepo quality, unit, coverage, or
build by maturity profile. A Starter monorepo may therefore execute a stronger
combined baseline than its minimum. Profile cost differentiation is measured
on otherwise identical single-stack pilots. Monorepo optimization requires a
separate design after aggregate stability is proven.

## Control boundaries

| Boundary | Existing workflow | Profile behavior | Pull-request effect |
|---|---|---|---|
| Quality + unit | `ci-quality.yml` | All profiles when a single stack exists | Required |
| Test + coverage | `ci-test.yml` | Enabled/strengthened coverage profiles | Required when planned |
| Monorepo combined CI | `ci-monorepo.yml` | All profiles for valid monorepo v2 | Required |
| Secret scan | `secret-scan.yml` | All initialized profiles | Required |
| Dependency baseline | `dependency-review.yml` | All initialized profiles | Required |
| CodeQL | `codeql.yml` | Enabled/strengthened profiles with executable code | Required when planned |
| Deterministic AI evaluation | `ai-evaluation.yml` reusable mode | AI-active profiles whose effective policy requires evaluation | Required when planned |

`ci-quality.yml`, `ci-test.yml`, and `ci-monorepo.yml` already expose
`workflow_call`; their callers and concurrency groups add the explicit
`execution_channel`. The security and AI workflows add `workflow_call` plus the
same caller distinction while retaining their direct events and existing
baseline behavior.

The quality/unit boundary intentionally remains combined. Splitting unit tests
would duplicate five language setup paths and create a second toolchain
implementation. The aggregate treats the combined boundary as the mandatory
application quality outcome.

The AI reusable mode runs only `evals/run-evals.sh --check`. It receives no API
key, makes no provider call, and validates the deterministic provider-neutral
contract. The existing direct advisory AI workflow may retain its separately
controlled secret-dependent path.

## Execution-plan contract

A new POSIX execution-plan resolver consumes:

- the key/value report from `scripts/resolve-profile-policy.sh`;
- stack detection from `scripts/detect-stack.sh`; and
- layout/component readiness from the canonical project configuration tools.

It emits fixed-order key/value records suitable for local tests and GitHub job
outputs. The contract includes:

```text
mode=profile
profile=standard
layout=single
stack=python
status=ready
boundary.quality_unit.decision=run
boundary.quality_unit.required=true
boundary.test_coverage.decision=run
boundary.test_coverage.required=true
boundary.codeql.decision=run
boundary.codeql.required=true
boundary.sbom.decision=policy-only
boundary.sbom.required=false
```

Top-level normalized status is `ready` for an initialized valid execution plan
and `delegated` for template compatibility. Compatibility also emits
`profile=none`, `layout=unknown`, and `stack=unknown`. Reason fields use only
bounded implementation-owned lowercase tokens; consumer-controlled text is
never copied into workflow outputs.

Allowed decisions are:

- `run` — invoke the reusable workflow in this event;
- `planned-skip` — policy intentionally disables the boundary;
- `not-applicable` — the boundary cannot apply to the detected repository
  state, with a machine-readable reason;
- `delegated-to-current-baseline` — template compatibility relies on unchanged
  direct workflows; and
- `policy-only` — the control belongs to a post-merge, scheduled, manual, or
  currently non-executed advisory channel and is not claimed as executed on
  this workflow event.

The plan resolver does not duplicate the Starter/Standard/Enterprise mapping.
It reads effective `enabled`, `class`, `policy_required`, `pr_required`, and
`alignment` fields from the central resolver. A policy mismatch makes plan
generation fail. Stronger-than-default declarations are valid and produce
execution when applicable.

Boundary derivation is deterministic:

- initialized single-stack consumers run `quality_unit`; monorepo consumers run
  `monorepo_ci` and mark the two single-stack boundaries as covered;
- coverage, CodeQL, and deterministic AI run only when their effective central
  fields enable and require them for the pull-request class;
- secret and dependency boundaries run for every valid initialized consumer;
- a disabled central control is `planned-skip`;
- an enabled post-merge, scheduled, manual, semantic, or structural control is
  `policy-only`; and
- a boundary incompatible with repository shape is `not-applicable`.

Boundary names and execution-channel mappings are orchestration wiring, not a
second normative policy table. Unknown control names, missing fields, duplicate
records, unknown decisions, or unsupported stack/layout combinations fail
closed.

## Result-evaluation contract

A POSIX evaluator consumes the deterministic plan and actual job conclusions
provided by the aggregate job. Supported GitHub conclusions are `success`,
`failure`, `cancelled`, and `skipped`.

The evaluator applies these rules:

| Planned decision | Required | Acceptable actual conclusion |
|---|---:|---|
| `run` | `true` | `success` only |
| `run` | `false` | `success`; non-success becomes advisory warning |
| `planned-skip` | any | `skipped` |
| `not-applicable` | any | `skipped` |
| `delegated-to-current-baseline` | any | `skipped` |
| `policy-only` | any | `skipped` |

A required planned run that fails, is cancelled, or is unexpectedly skipped
fails the evaluator. A boundary planned not to run but observed running also
fails because it indicates orchestration drift. A failed or missing plan fails
the aggregate before individual outcomes are interpreted.

Advisory failures remain visible in warning annotations and the Job Summary but
do not make the aggregate successful on behalf of a required failure.

## Data flow

1. The `plan` job checks out the repository with persisted credentials disabled.
2. Canonical project/profile validators and the central policy resolver run.
3. The execution-plan resolver detects compatibility, no-stack, single-stack,
   or monorepo-v2 mode and writes normalized job outputs.
4. Job-level conditions invoke reusable boundaries only for `run` decisions.
5. Existing direct workflows continue independently and are not dependencies
   of the advisory aggregate.
6. The aggregate starts with `if: always()`, materializes plan plus `needs.*.result`
   values as plain data, and invokes the result evaluator.
7. The evaluator writes a deterministic result report and exit status.
8. The aggregate appends a Job Summary containing profile, repository mode,
   planned decisions, actual conclusions, policy-only controls, warnings, and
   overall advisory verdict.

No artifact, pull-request comment, repository write, or GitHub API call is
needed for the first implementation.

## Failure behavior

- Missing or malformed consumer project/profile configuration: aggregate fail.
- Invalid or duplicate mapping data: aggregate fail.
- Policy declaration below the selected minimum: aggregate fail.
- Unsupported resolver/plan output: aggregate fail.
- Required job failure: aggregate fail.
- Required job cancellation: aggregate fail when the aggregate can run; an
  entire manually cancelled workflow remains a cancelled non-success.
- Unexpected skip of a required job: aggregate fail.
- Unexpected execution of a planned skip: aggregate fail.
- Advisory job failure: warning plus summary; aggregate remains governed by
  required outcomes.
- Template compatibility: aggregate pass with every duplicate boundary
  explicitly delegated to the current baseline.
- No executable stack: stack-dependent boundaries are not applicable; required
  stack-neutral boundaries still govern the aggregate.

## Security and fork behavior

- The orchestrator uses `pull_request`, never `pull_request_target`.
- Default permissions remain `contents: read`; only the CodeQL caller job and
  called CodeQL job receive the existing minimum `security-events: write`
  requirement needed by reusable-workflow permission inheritance.
- Checkout uses immutable SHA pins and disables persisted credentials wherever
  no subsequent authenticated Git operation is required.
- Mandatory fork paths use no repository secret.
- Deterministic AI evaluation uses no model credential or external provider.
- Secret scan output stays redacted through the existing scanner behavior.
- Untrusted profile values are validated as data and never interpolated into an
  executable shell command.
- Third-party Actions remain pinned to immutable commit SHAs.

On fork pull requests, unavailable secret-dependent semantic or structural
review is reported separately as advisory policy metadata. It is not treated
as successful execution and does not block the aggregate. Deterministic
mandatory controls remain executable without secrets.

## Testing strategy

### Local plan tests

Contract fixtures cover:

- empty-template compatibility;
- initialized no-stack Starter, Standard, and Enterprise;
- otherwise identical single-stack Starter, Standard, and Enterprise;
- explicitly strengthened Starter controls;
- valid monorepo v2;
- one-sided or invalid consumer configuration;
- weaker-than-profile declarations;
- malformed, missing, duplicate, and unknown resolver fields; and
- deterministic field order and byte-identical repeated output.

### Local evaluator tests

Table-driven shell contracts cover every decision/conclusion pair, including:

- required success;
- required failure;
- required cancellation;
- required unexpected skip;
- planned skip;
- not-applicable no-stack;
- compatibility delegation;
- policy-only reporting;
- advisory failure; and
- unexpected execution of a skipped boundary.

### Workflow structural tests

Structural contracts assert:

- exact workflow and aggregate names;
- pull-request, `main` push, and manual triggers without path filters;
- `contents: read` default permission and fork-safe event choice;
- `if: always()` aggregate behavior;
- all planned reusable calls and required dependencies;
- direct baseline triggers retained alongside `workflow_call`;
- deterministic AI mode receives no secret;
- immutable action pins;
- no aggregate entry in the branch-protection helper; and
- no removal or renaming of current invariant contexts.

Repository-native `make test-scripts`, `make docs-check`, and `make ci` remain
mandatory. Optional local documentation tools that are unavailable are
reported as skipped rather than passed.

## Hosted rollout evidence

After the implementation PR is reviewable, hosted evidence uses fresh
disposable consumers built from the same minimal single-stack fixture:

1. Template compatibility pull request and push.
2. Starter pull request, rerun, and `main` push.
3. Standard pull request, rerun, and `main` push.
4. Enterprise pull request, rerun, and `main` push.
5. Injected required-control failure proving aggregate failure attribution.
6. External public-fork pull request proving read-only permissions, no secret,
   and stable context creation.
7. No-stack initialization pull request proving explicit not-applicable status.
8. One monorepo-v2 diagnostic run proving the combined boundary contract.

Evidence records workflow/run URL, event, head SHA, profile, layout, stack,
planned boundaries, actual conclusions, aggregate context, duration, warnings,
rerun behavior, fork secret source, and pending-context outcome.

Starter must avoid at least one expensive profile-variable single-stack job
that Standard and Enterprise execute. Duplicate baseline and orchestrated
durations are recorded so the later enforcement decision can quantify both
the expected saving and the temporary pilot cost.

## Documentation and governance

The implementation PR updates:

- ADR-0010 status to advisory aggregate implemented with enforcement pending;
- the profile guidance in README and getting-started documentation;
- `CHANGELOG.md` under the unreleased section;
- the roadmap and TD-0015; and
- script/workflow documentation for plan and evaluator contracts.

Documentation must not claim that profile enforcement, branch protection,
post-merge controls, deployment, or production operation is active.

## Enforcement gate

Profile-aware enforcement remains **NO-GO** until hosted evidence proves:

1. one identical aggregate context across profiles, events, reruns, and forks;
2. required failures and unexpected skips propagate correctly;
3. no disabled boundary leaves a pending required context;
4. fork runs receive no secret or unexpected write permission;
5. template compatibility and consumer no-stack modes are truthful and green;
6. Starter materially avoids profile-variable single-stack work;
7. Enterprise policy-only controls are represented without false execution
   claims;
8. branch-protection migration and rollback succeed on a disposable repository;
   and
9. runtime and duplicate noise are acceptable.

Only a later PR may add `Profile policy / Required controls` to branch
protection. Only after that migration is proven may another change remove
duplicate direct profile-dependent execution.

## Rollback

Before enforcement, rollback is disabling or reverting the advisory
orchestrator and its plan/evaluator wiring. Direct baseline workflow triggers
remain intact, so security and quality posture returns to the current stronger
baseline without repository-administration changes.

Reusable `workflow_call` entries may remain if harmless, or be reverted with
the orchestrator. The central profile resolver and initializer remain useful
foundation metadata and do not require rollback.

After any future enforcement, rollback order remains ADR-0010's mandatory
sequence: remove the aggregate from branch protection first, restore baseline
execution, then disable orchestration. This implementation does not perform
that future operation.

## Acceptance criteria

1. `Profile policy / Required controls` is emitted on every supported event.
2. The aggregate is advisory and absent from branch protection.
3. Template compatibility invokes no duplicate profile-dependent boundary and
   reports delegation explicitly.
4. Initialized no-stack consumers run stack-neutral required controls and
   report stack-dependent controls as not applicable.
5. Single-stack Starter, Standard, and Enterprise produce the approved
   execution differences.
6. Monorepo v2 uses the combined existing reusable boundary without profile-
   specific decomposition.
7. Required failure, cancellation, and unexpected skip are non-successful.
8. Planned skips, compatibility delegation, policy-only controls, and valid
   not-applicable outcomes are distinguished from successful execution.
9. Existing direct workflow triggers and invariant contexts remain unchanged.
10. Mandatory fork paths are read-only and credential-free.
11. Deterministic AI evaluation makes no provider call and consumes no secret.
12. Focused tests and repository-native gates pass with actual evidence.
13. Hosted pilot evidence is recorded before any enforcement proposal.
14. No workflow, documentation, or report claims post-merge or production work
    succeeded when it was only validated as policy metadata.
