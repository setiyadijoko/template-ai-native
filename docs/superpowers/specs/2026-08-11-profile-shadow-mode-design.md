# Profile-Aware CI Shadow Mode Design

**Status:** All-profile and fork shadow paths hosted-verified; activation design only
**Date:** 2026-08-11
**Owner:** Template maintainers

## Purpose

Evaluate how the declarative Starter, Standard, and Enterprise profiles would
affect engineering controls without changing which workflows run, which checks
are required, or whether a pull request may merge.

The profile foundation in ADR-0008 is validated but intentionally inert. The
hosted Python coverage pilot proved that a Standard-profile consumer can use the
current quality, test, coverage, build, security, and post-merge provenance path.
It did not prove that profile-based workflow conditions are safe. Shadow mode is
the bounded evidence-gathering step between those states.

## Hosted observation evidence

Hosted runs on 2026-08-11 verified the bounded paths approved by ADR-0009:

- the template reported compatibility mode with all eleven decisions at
  `current-baseline` on pull-request and push events;
- the disposable Python consumer reported `profile=standard`, kept CodeQL and
  coverage at `would-run`, and continued to execute its existing quality,
  test, coverage, build, and security jobs;
- config-only Starter and Enterprise pull requests each passed all eleven
  workflows while leaving the consumer application and workflow files
  unchanged;
- Starter reported `status=aligned`, with CodeQL, coverage, and artifact
  attestation correctly classified as stronger than its defaults;
- Enterprise reported `status=warning` for the five expected policy gaps:
  SBOM, Scorecard, semantic review, structural review, and production
  governance;
- an external public fork was held for first-time-contributor approval, then
  completed the same stable shadow context with `Contents: read`, implicit
  metadata read, and `Secret source: None`;
- the Standard consumer correctly warned that semantic and structural review
  were declared `off` while their Standard defaults are `advisory`; the
  warnings did not fail or alter any workflow.

These observations satisfy the shadow-mode evidence gate for compatibility,
Starter, Standard, Enterprise, rerun, and fork paths. They authorize only the
preparation of a separate activation ADR. Actual workflow conditions, required
checks, initializer changes, and consumer migration remain **NO-GO** until that
ADR defines classification semantics, stable contexts, missing-profile
compatibility, rollout, rollback, and measurable cost/noise safeguards.

## Goals

- Resolve an absent or valid profile into deterministic hypothetical control
  decisions.
- Keep every existing workflow and required check unchanged.
- Publish one stable, advisory observation check on normal pull requests and
  pushes to `main`.
- Expose policy mismatches without automatically weakening or strengthening
  execution.
- Gather enough compatibility, fork-safety, duration, and noise evidence to
  design a later activation decision.

## Non-goals

- Skipping, adding, downgrading, or making an existing workflow conditional.
- Changing branch protection or `scripts/setup-branch-protection.sh`.
- Adding profile selection to `scripts/init-project.sh`.
- Automatically enforcing the normative profile mapping.
- Making AI review findings the sole merge authority.
- Activating deployment, production, provider, or environment behavior.

## Architecture

Shadow mode consists of two implementation units:

1. A POSIX resolver that reads `.template/profile.yaml` and the existing
   `.template/profile-controls.yaml` mapping and prints a deterministic
   machine-readable report.
2. A separate, read-only GitHub Actions workflow that invokes the resolver and
   renders the result into the GitHub Job Summary.

The existing `ci.yml` dispatcher and every quality, test, build, security, AI,
supply-chain, deployment, and readiness workflow remain byte-for-byte outside
the shadow-mode implementation scope. The new check is not added to branch
protection.

### Stable workflow contract

- Workflow file: `.github/workflows/profile-shadow.yml`.
- Workflow name: `Profile shadow`.
- Job/check name: `Profile shadow / Profile policy observation` so the stable
  context is explicit rather than inferred from workflow-name rendering.
- Expected context: `Profile shadow / Profile policy observation`.
- Triggers: pull requests targeting `main`, pushes to `main`, and
  `workflow_dispatch`.
- No path filter is used, so the observation context remains visible across
  documentation, configuration, and source changes.
- Permissions are limited to `contents: read`.
- The workflow uses `pull_request`, never `pull_request_target`, and consumes no
  secret, token input, external endpoint, or untrusted shell interpolation.

## Resolution behavior

### Compatibility mode

When `.template/profile.yaml` is absent, the resolver succeeds with
`mode=compatibility` and reports `current-baseline` for every control. It does
not infer Starter, Standard, Enterprise, AI use, deployment status, or project
risk from repository contents.

### Shadow mode

When the profile exists, the resolver first invokes the canonical profile
validator. A valid configuration produces `mode=shadow` and one observation
record per control.

For the seven Boolean fields under `controls`, the declared Boolean determines
the hypothetical `would-run` or `would-skip` decision. The normative profile
mapping supplies the recommended default and alignment state. The `sbom`,
`artifact_attestation`, and `scorecard` defaults may also be `optional`; either
Boolean consumer declaration is then `aligned` while the declaration still
determines the hypothetical decision:

- `aligned` when the declaration matches the default;
- `stronger-than-default` when a consumer voluntarily enables a control whose
  default is disabled;
- `policy-mismatch` when a consumer disables a control whose profile default is
  required.

`stronger-than-default` and `policy-mismatch` are observations only. They emit
annotations and summary text but do not change execution or fail an otherwise
valid shadow report.

AI decisions are derived from the existing bounded fields:

- AI evaluation would run only when both `ai.enabled` and `ai.evaluation` are
  true.
- Semantic and structural review follow their explicit `off`, `advisory`, or
  `enabled` values.
- `enabled` means the review should execute in a future policy; AI findings
  remain advisory and are never sufficient merge authority.

Deployment settings are reported as governance metadata only. They do not
activate a deploy, environment, smoke test, OIDC permission, or production
approval.

### Execution classes

The shadow report classifies the future execution channel without applying it:

| Control | Observed execution class |
|---|---|
| Secret scan, dependency review | Pull-request blocking |
| CodeQL, coverage | Pull-request blocking when enabled |
| AI evaluation, semantic review, structural review | Pull-request advisory |
| SBOM, artifact attestation | Push/release or post-merge |
| Scorecard | Scheduled/push |
| Production governance | Manual and environment-controlled |

The classification describes where a future control belongs. It does not make
the new shadow check or an AI finding blocking.

## Report contract

The resolver prints fixed-order key/value records suitable for shell tests and
future orchestration. At minimum the report includes:

```text
mode=shadow
profile=standard
status=aligned
control.codeql.declared=true
control.codeql.default=true
control.codeql.decision=would-run
control.codeql.class=pull-request-blocking
control.codeql.alignment=aligned
```

The workflow converts the same records into a Job Summary table. The first
implementation does not upload an artifact, call the GitHub API, post a pull
request comment, or collect cross-workflow timing. Hosted evidence is gathered
from the stable check and logs using the existing `gh` workflow during the
consumer pilot.

## Failure handling

- Missing profile: successful compatibility observation.
- Valid aligned or stronger configuration: successful observation.
- Valid policy mismatch: successful observation with a warning annotation.
- Invalid profile shape/value or credential-like field: fail the observation
  check using the canonical validator; existing workflows still run normally.
- Missing or malformed normative mapping: fail closed because a hypothetical
  decision would be unreliable.
- Resolver or rendering error: fail the observation check and preserve all
  current workflow execution.

Because the context is advisory and absent from branch protection, an
observation failure cannot remove or bypass an existing required control.

## Initializer and migration boundary

Shadow mode does not modify the initializer. Consumers opt in by creating the
already-documented `.template/profile.yaml`; missing-profile repositories stay
in compatibility mode.

A later initializer extension requires a separate design. It must create a
profile only when absent and require an explicit reconfiguration flag before
overwriting consumer-owned values. Shadow-mode evidence must not be used as
implicit permission to implement that extension.

## Testing strategy

Focused POSIX contract tests cover:

- missing-profile compatibility mode;
- Starter, Standard, and Enterprise defaults;
- stronger-than-default declarations;
- policy mismatch warnings;
- disabled and enabled AI combinations;
- invalid, duplicate, unknown, and credential-like profile fields through the
  canonical validator;
- missing or malformed control mapping;
- deterministic key order and stable control names.

Workflow contract tests assert the exact workflow/job names, triggers,
read-only permission, absence of path filters and secrets, fork-safe event,
and absence from the branch-protection setup script. Repository-native
`make test-scripts`, `make docs-check`, and `make ci` remain required.

## Hosted pilot and activation gate

The observational implementation must be tested in these states:

1. the template repository without an active profile, proving compatibility;
2. the public Python coverage pilot with its Standard profile, proving a real
   consumer report while all baseline workflows still execute;
3. one fork pull request, proving the check requires no secret or elevated
   permission.

Before any activation design is approved, evidence must show:

- the context name is identical on pull request, push, rerun, and fork events;
- no existing required or advisory workflow is suppressed or renamed;
- the report matches the declared profile and normative mapping;
- invalid configuration fails only the advisory observation path;
- runtime and check noise remain proportionate for a lightweight shell job;
- the consumer migration and rollback procedure are documented.

Passing shadow mode permits a separate activation design. It does not itself
authorize workflow conditions or branch-protection changes.

## Security and privacy

- Profile and mapping values are repository configuration, not secrets.
- The resolver accepts no arbitrary command, path traversal, endpoint, or
  credential field.
- Workflow permissions remain read-only and third-party actions are unnecessary
  for the initial implementation.
- Fork pull requests receive no secret and execute no untrusted privileged
  context.
- The report contains only profile names, control decisions, and alignment
  metadata; it contains no application payload or personal data.

## Observability and cost

Evidence records the workflow run URL, event, head SHA, profile mode, report
status, context name, duration, warnings, and unexpected skips. Cross-workflow
cost aggregation remains a manual pilot analysis; the workflow does not add an
API token or telemetry service merely to collect it.

## Rollback

Before the observation context becomes required, rollback is removing the
separate workflow, resolver, and focused tests. Existing workflows and branch
protection need no restoration because shadow mode never changes them.

If a report is misleading, unstable, unsafe on forks, or disproportionately
noisy, stop the pilot and revert the observational implementation. Do not fall
through to an inferred profile or direct workflow conditions.

## Acceptance criteria

1. Shadow mode is isolated from `ci.yml` and all existing control workflows.
2. Missing profile produces a successful compatibility report.
3. All three valid profiles produce deterministic hypothetical decisions.
4. Policy mismatches are visible but do not change or block existing controls.
5. Invalid configuration and invalid mapping fail the advisory observation.
6. The check context is stable and is not added to branch protection.
7. The workflow is read-only, fork-safe, credential-free, and has no path
   filter.
8. No initializer, deployment, production, provider, or profile activation is
   introduced.
9. Focused tests and repository-native checks pass.
10. Hosted compatibility, Starter, Standard, Enterprise, rerun, and fork
    evidence are recorded before a separate activation design is considered.
