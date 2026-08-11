# ADR-0009: Observe profile policy before workflow activation

- **Status:** Accepted — observational implementation; activation deferred
- **Date:** 2026-08-11
- **Decision owners:** Template maintainers and consumer project owners

## Context

ADR-0008 established an optional, validated maturity-profile contract while
deliberately keeping it operationally inert. Directly adding profile conditions
to existing workflows could suppress required controls, leave pending contexts,
or weaken consumers that have no profile.

A public Standard-profile Python consumer has now passed hosted quality,
categorized tests, aggregate coverage, build, blocking security, and signed
post-merge provenance. That evidence supports evaluating profile decisions, but
it does not prove that activating those decisions is compatible with required
checks, forks, cost, or existing consumers.

## Decision

Introduce a separate, advisory profile-policy shadow mode before any workflow
activation.

The shadow implementation will:

- use a deterministic POSIX resolver over the existing validated profile and
  normative mapping;
- run in a separate read-only workflow on pull requests, pushes to `main`, and
  manual dispatch;
- publish the stable context
  `Profile shadow / Profile policy observation`;
- report compatibility mode, hypothetical control decisions, execution class,
  and policy alignment;
- leave every current workflow, required context, branch-protection setting,
  initializer behavior, and production control unchanged.

Missing profiles succeed in compatibility mode without an inferred profile.
Invalid profiles or mappings fail only the advisory observation. A valid policy
mismatch emits a warning and does not affect actual execution.

The detailed contract, pilot states, and acceptance criteria are defined in
`docs/superpowers/specs/2026-08-11-profile-shadow-mode-design.md`.

## Alternatives considered

### Add profile conditions directly to existing workflows

Rejected. This is activation, not observation, and would expose existing
consumers and required checks to unproven behavior.

### Add an observation job inside `ci.yml`

Rejected. It would couple an experiment to the production dispatcher and make
rollback and failure attribution less isolated.

### Run shadow resolution only through `workflow_dispatch`

Rejected. Manual-only evidence cannot establish normal pull-request context
stability, noise, or fork safety.

### Upload reports or post pull-request comments

Rejected for the first implementation. Job logs and summaries provide enough
evidence without write permission, artifact retention, or comment noise.

## Consequences

Positive:

- Profile policy can be measured on real events without changing enforcement.
- Compatibility behavior and check naming become observable before migration.
- Resolver output provides a bounded interface for tests and a future, separate
  activation design.
- Rollback is isolated from current CI and branch protection.

Trade-offs:

- Every relevant event gains one advisory check.
- The first implementation does not automatically aggregate cost or compare
  other workflow conclusions.
- A red advisory observation is visible even though it is not required.
- Shadow results do not reduce current CI cost because all controls continue to
  run.

## Security implications

The workflow is read-only, credential-free, and fork-safe. It uses
`pull_request`, not `pull_request_target`, and adds no external API or provider.
An absent or malformed profile cannot disable a security workflow. AI review
findings remain advisory and cannot become sole merge authority through this
decision.

## Data implications

The resolver handles only repository-owned profile names, Boolean settings,
control names, and alignment metadata. No application data, prompt content,
secret, personal data, or external telemetry is introduced.

## Operational implications

The observation context must remain stable across pull-request, push, rerun,
and fork events and must stay out of branch protection during the pilot. Pilot
evidence records duration, warnings, skipped observations, and discrepancies.
All baseline workflows remain the authority for current execution.

## Hosted evidence — 2026-08-11

Compatibility mode passed in the template on pull-request and push events with
the stable context and all eleven controls preserved as `current-baseline`. A
public Standard-profile Python consumer then passed the same context on its
pull request and `main` push while existing Python quality, tests, coverage,
build, CodeQL, and security execution remained active.

An external public fork was initially held for first-time-contributor workflow
approval. After explicit maintainer approval, attempt 2 passed with
`Contents: read`, implicit metadata read, and `Secret source: None`. The
resolver consistently reported accurate policy mismatches for the consumer's
disabled semantic and structural review declarations without changing or
failing baseline workflows.

This evidence satisfies the ADR's compatibility, Standard, and fork-safety
observation steps. It does not change the activation decision: Starter and
Enterprise have no hosted evidence, scheduled/manual classifications remain
unproven as execution policy, and the sample is insufficient for representative
cost/noise conclusions. Activation therefore remains deferred and requires a
separate ADR.

## Migration strategy

1. Implement and test the resolver and isolated advisory workflow.
2. Prove compatibility mode in the template repository.
3. Prove Standard-profile behavior in the public Python coverage consumer.
4. Prove fork safety without secrets or elevated permissions.
5. Review context stability, noise, duration, and policy accuracy.
6. Create a separate ADR and consumer migration plan before any real workflow
   condition or branch-protection change.

The initializer remains unchanged during these steps. A future profile flag
must be idempotent and require explicit reconfiguration before overwriting a
consumer profile.

## Rollback considerations

Remove the isolated workflow, resolver, and tests. No existing workflow or
branch-protection restoration is necessary. If the profile is absent after
rollback, the repository continues its current compatibility behavior; it must
not infer a profile.
