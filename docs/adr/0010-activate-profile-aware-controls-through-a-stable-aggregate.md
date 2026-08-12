# ADR-0010: Activate profile-aware controls through a stable aggregate

- **Status:** Accepted — design approved; implementation and enforcement staged
- **Date:** 2026-08-11
- **Decision owners:** Template maintainers and consumer project owners

## Context

ADR-0008 established a validated Starter/Standard/Enterprise contract without
changing workflow execution. ADR-0009 then introduced an isolated advisory
shadow workflow. Hosted observations covered compatibility mode, all three
profiles, reruns, `main` pushes, and an external public fork. The resolver
reported the expected profile decisions while every existing workflow remained
active.

That evidence supports an activation design, but it does not make direct
conditions in existing workflows safe. GitHub branch protection waits for
named contexts. A workflow suppressed by a path or event condition can leave a
required context pending, while profile-specific required-context lists would
couple repository administration to configuration changes.

The template repository currently requires five invariant governance contexts:

- `PR Title Check`;
- `Validate required docs & metadata`;
- documentation lint, link, and unresolved-marker check;
- `actionlint (workflow syntax)`; and
- `zizmor (workflow security)`.

Existing consumer repositories were disposable pilots and will not be
migrated. The activation design therefore targets newly initialized consumers
and must keep the template repository itself valid without an active profile.

## Decision

Adopt a hybrid two-layer activation architecture for new consumers:

1. Keep invariant governance contexts independent from profile selection.
2. Add one always-present profile aggregate context named
   `Profile policy / Required controls`.
3. Resolve all profile-dependent execution centrally, then call bounded
   reusable control workflows.
4. Make only required pull-request controls affect the aggregate result.
5. Keep advisory, post-merge, scheduled/push, and manual/environment controls
   outside the pull-request aggregate.

This ADR approves the target architecture and staged implementation. It does
not activate workflow conditions, change branch protection, or modify the
initializer by itself.

## Profile selection and compatibility

Every newly initialized consumer must choose `starter`, `standard`, or
`enterprise`. Interactive initialization must prompt for the profile;
non-interactive initialization must accept an explicit `--profile` value.
Reconfiguration must remain explicit and idempotent and must not overwrite an
existing profile without the established reconfiguration guard.

Repository state determines missing-profile behavior:

- The template repository has no `.template/project.yaml` and may continue in
  compatibility mode without `.template/profile.yaml`.
- An initialized consumer has `.template/project.yaml`; if its profile is
  missing, invalid, or unsupported, the profile aggregate fails closed.
- No repository may infer a profile from its stack, files, owner, visibility,
  or deployment assets.
- Disposable historical pilot repositories require no migration.

The normative profile is a minimum posture, not a ceiling. A consumer may
explicitly enable a stronger control. It may not disable a control required by
its selected profile. Boolean controls therefore allow `false` to `true`
strengthening, while AI review follows `off < advisory < enabled`.

## Architecture

### Layer 1 — invariant governance

The existing five governance contexts remain stable and required for every
profile. Profile selection cannot skip, rename, aggregate, or downgrade them.
Secret scanning, the dependency vulnerability baseline, and unit tests are
also mandatory control outcomes for all profiles, but their execution is
reported through the profile aggregate once activation is proven.

### Layer 2 — profile-aware orchestration

A profile-policy orchestrator must start on every pull request and `main` push.
It may also support manual dispatch for diagnostics. It must:

1. validate project and profile configuration;
2. resolve the selected profile against the normative mapping;
3. produce a deterministic execution plan;
4. invoke applicable reusable control workflows;
5. collect required job conclusions with an always-running aggregate job; and
6. publish `Profile policy / Required controls` on every supported event.

The policy resolver is the single source of profile decisions. Individual
workflows must not independently parse the profile or duplicate the mapping.
The aggregate must treat an unexpectedly skipped, cancelled, or failed
required job as failure. An intentionally disabled optional control is a
resolved policy decision and does not fail the aggregate.

Individual profile-dependent job names may remain visible for diagnostics but
must not be configured as required branch-protection contexts. The stable
aggregate is the only profile-dependent pull-request context intended for
branch protection.

## Execution policy

| Control class | Starter | Standard | Enterprise | Pull-request effect |
|---|---|---|---|---|
| Invariant governance | Required | Required | Required | Blocking outside the aggregate |
| Unit tests, secret scan, dependency baseline | Required | Required | Required | Blocking through the aggregate |
| Coverage and CodeQL | Optional/off by default | Required | Required | Blocking when required or explicitly enabled |
| Deterministic AI evaluation | Optional | Required when AI is enabled | Required when AI is enabled | Blocking when required |
| Semantic and structural AI review | Off by default | Advisory | Must execute when credentials are available | Advisory; never sole merge authority |
| SBOM and artifact attestation | Off by default | Optional | Required | Post-merge, outside PR aggregate |
| Scorecard | Off by default | Optional | Must execute | Scheduled/push; findings remain advisory |
| Production governance | Required when deployed | Required when deployed | Required | Manual and environment-controlled |

Deterministic AI evaluation used as a blocking control must be credential-free
or use approved test doubles. Real-model evaluation remains separately
controlled by secrets, budgets, and provider policy. An AI review can be
required to execute for Enterprise, but its model-generated findings cannot be
the sole merge authority.

Post-merge, scheduled, and manual controls retain their own fail-closed
execution semantics. The pull-request aggregate validates their configured
policy and workflow presence only; it must not claim that a future execution
has succeeded.

## Failure and fork behavior

- Invalid project configuration, profile configuration, mapping, or resolver
  output fails the aggregate.
- Required jobs that fail, cancel, time out, or unexpectedly skip fail the
  aggregate.
- Advisory failures emit visible warnings and summaries without failing the
  aggregate.
- The orchestration path uses `pull_request`, never `pull_request_target`.
- Fork pull requests receive no repository secrets and no write permission.
- A secret-dependent advisory review unavailable on an untrusted fork reports
  `unavailable-on-untrusted-fork`; it does not become blocking or silently
  report success.
- Mandatory deterministic controls must remain executable without secrets on
  forks.

## Branch-protection policy

Branch protection must not vary by profile. The five invariant governance
contexts remain required. `Profile policy / Required controls` may be added as
one additional required context only after the activation pilot passes.

The setup helper must not add individual profile-dependent job contexts. This
keeps Starter, Standard, and Enterprise on one stable administrative contract
even though their execution plans differ.

## Rollout plan

1. Implement the central resolver contract, orchestrator, reusable control
   boundaries, aggregate, initializer selection, and focused tests while the
   aggregate remains advisory.
2. Preserve current baseline workflows until equivalence is demonstrated; do
   not suppress expensive jobs merely because the new plan exists.
3. Create one fresh disposable consumer for each profile using the same small
   stack so profile behavior, rather than application differences, is tested.
4. Exercise pull-request, rerun, `main` push, and one external fork path.
5. Verify expected job execution, required failure propagation, fork
   permissions, absence of secrets, and absence of pending contexts.
6. Record duration, warning noise, and the profile-variable jobs avoided by
   Starter compared with Standard and Enterprise.
7. After hosted evidence passes, update the branch-protection helper to require
   the aggregate for newly initialized consumers.
8. Only then remove duplicate always-run profile-dependent execution.

Implementation and enforcement must be separate PR-sized changes. A green
advisory aggregate is not authority to change branch protection in the same PR.

## Activation acceptance criteria

Activation evidence is sufficient only when:

1. every new consumer receives a valid explicit profile;
2. the template remains green in compatibility mode;
3. the aggregate context has the exact same name across all profiles, reruns,
   pushes, and forks;
4. every required control failure is propagated to the aggregate;
5. optional and advisory outcomes match the normative mapping;
6. no disabled control leaves a pending required context;
7. fork runs use read-only permissions and receive no secrets;
8. Enterprise post-merge, scheduled/push, and manual policy is represented
   without being misreported as completed on a pull request;
9. Starter materially avoids at least one expensive profile-variable PR job
   compared with Standard while retaining mandatory controls; and
10. branch-protection migration and rollback are exercised on a disposable
    repository before the helper changes become the recommended default.

Until all criteria are recorded, profile-aware enforcement remains **NO-GO**.

## Alternatives considered

### Add independent profile guards and sentinel jobs to every workflow

Rejected. The initial edit is smaller, but policy parsing and failure semantics
would be distributed across workflows. Context count and drift risk would grow
with every new control.

### Change branch-protection contexts for each profile

Rejected. It couples repository administration to profile changes, requires
additional privileges, and increases the risk of missing or permanently
pending checks.

### Generate different workflow files during initialization

Rejected. Generated variants would diverge from the template, complicate
updates and audits, and create three CI systems to maintain.

### Continue shadow mode indefinitely

Rejected. Shadow mode proves decisions but cannot reduce unnecessary execution
or enforce the selected minimum posture for new consumers.

## Consequences

Positive:

- Required contexts remain stable across all profiles.
- Starter can reduce unnecessary CI execution without weakening mandatory
  governance, tests, or security controls.
- Standard and Enterprise receive explicit, auditable minimum postures.
- Policy remains centralized and testable.
- New consumers cannot silently omit profile selection.

Trade-offs:

- Existing workflows must be decomposed into reusable boundaries before
  duplicate execution can be removed.
- The aggregate becomes a critical policy component and requires strong
  contract tests.
- Post-merge, scheduled, and manual evidence cannot be represented by one PR
  conclusion and must remain separately observable.
- The template repository needs a narrowly defined compatibility exception.

## Security implications

The design preserves least privilege, immutable action pinning, fork-safe
events, secret isolation, and human production approval. A missing or malformed
consumer profile fails closed. Stronger-than-default controls are allowed;
weaker-than-minimum declarations are rejected. AI-generated review remains
advisory and cannot independently authorize a merge or production deployment.

## Data implications

The resolver handles repository-owned configuration and control conclusions
only. It introduces no application data, personal data, prompt content,
provider payload, credential, or external telemetry requirement.

## Operational implications

Maintainers must monitor aggregate duration, skipped controls, failure
attribution, and warning noise during rollout. Workflow summaries must identify
the selected profile, effective control plan, required conclusions, advisory
findings, and controls delegated to post-merge, scheduled, or manual execution.

## Migration strategy

No historical pilot repository is migrated. New consumers adopt the contract
through initialization and a reviewed profile file. The template repository
continues without an active project/profile pair. If a non-disposable consumer
later requests adoption, it requires its own reviewed initialization or
reconfiguration PR and branch-protection change after the hosted gate passes.

## Rollback considerations

Rollback order is mandatory:

1. remove `Profile policy / Required controls` from required branch protection;
2. restore all baseline workflows to unconditional execution;
3. disable or revert the profile-aware orchestrator; and
4. retain the profile as inert metadata or remove it through a separate
   reviewed change.

Removing the workflow before removing its required context is prohibited
because it can block every pull request. Rollback must restore the stronger
current baseline; it must not fall through to a weaker inferred profile.
