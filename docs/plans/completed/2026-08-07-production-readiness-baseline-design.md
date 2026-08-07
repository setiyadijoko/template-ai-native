# Feature Design: Phase 6 Production-Readiness Baseline

**Status:** Accepted
**Date:** 2026-08-07
**Owner:** Template maintainers

## Executive summary

Phase 6 adds a vendor-neutral, executable production-readiness contract without
pretending that this stack-agnostic template has a deployment target. Consumers
receive a strict readiness manifest, a dependency-free validator, a read-only
GitHub Actions check, and a manual rollback workflow that fails closed until a
real rollback integration exists.

The baseline distinguishes contract validity from production approval. Both
`template` and `active` can be contract-valid, but the validator always reports
`production_ready=false`. Active status means required values and evidence
references satisfy the contract shape; it does not verify human review,
evidence freshness, evidence content approval, or production authorization.

## Problem statement

The repository already documents observability, incident response, recovery,
and rollback, but most operational documents are short adaptation notes. There
is no executable control proving that a consumer completed them. There is also
no rollback workflow, although the approved baseline requires production
changes to be reversible.

Creating a successful no-op rollback job or treating generic documentation as
production readiness would create false assurance. Conversely, wiring a real
rollback command, observability backend, or health endpoint would violate the
template's explicit no-platform and no-runtime constraints.

## Business objective

Give engineering, SRE, security, and audit stakeholders one machine-verifiable
answer and one explicitly separate governance decision:

1. Is the repository's production-readiness contract structurally valid?
2. Has an authorized human and the protected platform control approved the
   referenced evidence and the production change?

The validator answers only the first question. The separation reduces
premature production approval while keeping human review, evidence freshness,
content approval, and environment protection outside repository automation.

## Scope

### In scope

- A strict, vendor-neutral production-readiness manifest under
  `observability/`.
- A POSIX validator with explicit `template` and `active` semantics.
- A read-only GitHub Actions workflow that runs the validator for pull
  requests, pushes to `main`, and manual dispatches.
- A manual-only rollback workflow skeleton bound to the selected GitHub
  Environment.
- Fail-closed rollback inputs and an unwired sentinel that prevents false
  success.
- Behavioral validator tests and structural workflow security contracts.
- Canonical Make targets and integration with the local CI mirror.
- Meaningful operational guidance for observability, SLOs, alerts, runbooks,
  rollback, backup/recovery, and disaster recovery.
- Documentation, changelog, and technical-debt traceability.

### Out of scope

- A deployment target, cloud account, cluster, production endpoint, or
  observability vendor.
- Live development, staging, or production deployment.
- Wiring the existing deploy or smoke-test workflow skeletons.
- OIDC permissions, cloud credentials, secrets, or production mutations.
- Executing a real application, configuration, database, infrastructure,
  prompt, or model rollback.
- DAST, performance, canary, failover, backup restoration, or DR automation.
- Selecting concrete SLO targets for a consumer application.
- Changing branch protection, repository rules, or GitHub Environment
  settings.

## Constraints and assumptions

- The repository remains stack-, platform-, and vendor-agnostic.
- The validator uses POSIX shell and standard utilities already used by the
  repository. It introduces no application runtime or package dependency.
- The configuration file is parsed as data. It is never sourced or evaluated
  as shell code.
- GitHub Environment protection is owner-managed. The workflow can bind a job
  to an environment but cannot prove that Required Reviewers are configured.
- The template must remain green before a consumer adopts a stack or platform.
- `deploy-*.yml` and `smoke-test.yml` remain byte-for-byte unchanged.

## Alternatives considered

### 1. Declarative readiness contract — selected

A strict manifest plus validator makes missing evidence observable without
choosing a runtime or vendor. It adds a small schema that maintainers must keep
stable, but the schema is explicit and testable.

### 2. OpenTelemetry Collector and Prometheus examples

Concrete examples would be immediately recognizable, but they would silently
select deployment and monitoring technologies that may not fit a consumer.
They also could not be exercised meaningfully while `src/` is empty.

### 3. Workflow and documentation only

This is the smallest file count, but it can verify only that prose exists. It
cannot distinguish a completed production control from an untouched template.

## Architecture

```text
observability/production-readiness.conf
                 |
                 v
scripts/validate-production-readiness.sh
        |                         |
        | local                   | GitHub Actions
        v                         v
make readiness-check     production-readiness.yml
        |
        v
template -> readiness_contract_valid=true, production_ready=false
active   -> readiness_contract_valid=true, production_ready=false

workflow_dispatch
        |
        v
rollback.yml -> validate inputs -> environment gate -> unwired sentinel FAIL
```

The readiness validator and rollback workflow are independent. A valid active
manifest does not make an unwired rollback workflow succeed, and a future
rollback integration must not bypass readiness validation.

## Component design

### Readiness manifest

Create `observability/production-readiness.conf` using a constrained
`KEY=VALUE` grammar. Blank lines and comments beginning with `#` are allowed.
Keys are uppercase ASCII identifiers. Every other non-empty line must contain
exactly one recognized key and a non-empty value.

Schema version 1 contains exactly these keys:

```text
READINESS_SCHEMA_VERSION
READINESS_STATUS
SERVICE_OWNER
PRODUCTION_ENVIRONMENT
OBSERVABILITY_BACKEND
SLO_AVAILABILITY_PERCENT
SLO_LATENCY_P95_MS
ERROR_BUDGET_WINDOW_DAYS
ALERT_POLICY_PATH
ALERT_RUNBOOK_PATH
ROLLBACK_RUNBOOK_PATH
ROLLBACK_TEST_DATE
ROLLBACK_TEST_EVIDENCE_PATH
RTO_MINUTES
DATA_RECOVERY_REQUIRED
RPO_MINUTES
RESTORE_TEST_DATE
RESTORE_TEST_EVIDENCE_PATH
```

The committed template uses:

- `READINESS_SCHEMA_VERSION=1`;
- `READINESS_STATUS=template`;
- `PRODUCTION_ENVIRONMENT=production`;
- real repository paths for the alert policy, alert runbook, and rollback
  runbook; and
- `UNSET` for consumer-owned values.

`UNSET` and `NOT_APPLICABLE` are reserved values and may not be used as normal
free-text values.

### Validator

Create `scripts/validate-production-readiness.sh`. It accepts an optional
manifest path and otherwise reads
`observability/production-readiness.conf`.

The parser must:

- never use `source`, `.`, `eval`, or generated shell;
- resolve the repository root from the manifest's Git worktree and reject a
  manifest that is not inside a worktree, without trusting ambient Git
  repository-selection environment variables;
- reject malformed lines, duplicate keys, missing keys, unknown keys, empty
  values, unsupported schema versions, and unknown readiness states;
- constrain referenced paths to regular files inside the repository after
  canonical path resolution; and
- print deterministic diagnostics without exposing environment variables or
  file contents.

In `template` status, the validator checks the complete key set, schema,
reserved values, production environment, and the three canonical policy paths.
Consumer-owned values may remain `UNSET`. Success prints:

```text
readiness_status=template
readiness_contract_valid=true
production_ready=false
```

In `active` status, the validator additionally requires:

- `SERVICE_OWNER` and `OBSERVABILITY_BACKEND` to be populated;
- availability to be greater than zero and at most 100;
- latency p95 and RTO to be positive integers;
- the error-budget window to be an integer from 1 through 365;
- alert policy, alert runbook, rollback runbook, and rollback-test evidence to
  be repository-confined regular files;
- the rollback-test date to be a calendar-valid `YYYY-MM-DD` value that is not
  later than the current UTC date;
- referenced operational/evidence documents to contain none of `TODO`, `TBD`,
  `FIXME`, `UNSET`, or the generic status `Adapt to your project`;
- `DATA_RECOVERY_REQUIRED` to be `yes` or `no`;
- when recovery is `yes`, RPO must be a non-negative integer and both restore
  date and restore-evidence path must be populated and valid, with the date
  calendar-valid and not later than the current UTC date; and
- when recovery is `no`, RPO, restore date, and restore-evidence path must each
  be exactly `NOT_APPLICABLE`.

Success in active mode prints:

```text
readiness_status=active
readiness_contract_valid=true
production_ready=false
```

Active success validates field semantics and repository-confined reference
shape only. It does not inspect whether a human approved the referenced
content, determine whether evidence is fresh enough for a particular change,
or authorize production. Those remain separate human and platform controls.

Every validation defect produces a targeted error on standard error and a
non-zero exit code.

### Production-readiness workflow

Create `.github/workflows/production-readiness.yml` with:

- `pull_request` targeting `main`, `push` to `main`, and `workflow_dispatch`;
- workflow-level `contents: read` and no write permission;
- concurrency isolated by pull-request number or Git ref;
- one Ubuntu job with a bounded timeout;
- SHA-pinned checkout with `persist-credentials: false`; and
- a step that runs `make readiness-check` and writes the non-secret readiness
  result to the GitHub step summary.

The workflow name and documentation describe it as a contract check, not a
production approval. A green run in either valid state reports
`readiness_contract_valid=true` and `production_ready=false`.

### Rollback workflow

Create `.github/workflows/rollback.yml` with `workflow_dispatch` only. It has
these required inputs:

- `environment`: choice of `development`, `staging`, or `production`;
- `release_ref`: a 40-character lowercase commit SHA or a version tag matching
  `v[0-9][0-9A-Za-z._-]*`, used for audit traceability;
- `artifact_digest`: a lowercase `sha256:` digest with 64 hexadecimal
  characters;
- `reason`: a non-whitespace audit reason; and
- `confirm`: must equal `ROLLBACK`.

The job:

- binds `environment` to the selected GitHub Environment;
- uses a per-environment concurrency key with `cancel-in-progress: false`;
- has only `contents: read` permission;
- has no checkout, OIDC, secret, third-party Action, container, or service;
- maps dispatch inputs into step environment variables rather than embedding
  expressions in shell code;
- validates confirmation, release-ref syntax, digest syntax, and reason; and
- ends with an explicit non-zero sentinel explaining that the rollback target
  is not configured.

The sentinel may be replaced only when a later approved design identifies the
platform, retrieves the exact artifact, verifies its digest and attestation,
defines the rollback command, and documents recovery verification. That later
change adds job-scoped OIDC only if the selected platform requires it.

### Make interface

Add an always-on `readiness-check` target that invokes the validator. Add the
target to `make ci`. Extend `make test-scripts` with the Phase 6 test suite.
These checks run even when stack detection returns `unknown` because they
validate the template's governance surface.

## Failure semantics

| Condition | Result |
|---|---|
| Template manifest is structurally valid | Exit 0; contract valid, `production_ready=false` |
| Template manifest has an invalid contract or path | Exit non-zero |
| Active manifest is complete and internally consistent | Exit 0; contract valid, `production_ready=false` |
| Active manifest has a missing, generic, unsafe, or inconsistent value | Exit non-zero |
| Rollback input is malformed or confirmation is absent | Workflow fails before the sentinel |
| Rollback input is valid but platform integration is absent | Workflow fails at the unwired sentinel |
| GitHub Environment lacks owner-managed protection | Reported as an external configuration risk; no deployment occurs |

## Security, data, and AI implications

### Security

- No production write permission, credential, token, or secret is introduced.
- Input expressions are not inserted directly into shell commands.
- Manifest paths cannot escape the repository.
- Checkout credentials are not persisted.
- `pull_request_target` and error suppression are prohibited.
- Any future third-party Action must be pinned to an immutable commit SHA with
  its release tag documented.

### Data and privacy

- The manifest contains ownership and operational metadata only. It must not
  contain credentials, customer data, raw prompts, raw model responses, or
  production logs.
- Operational guidance continues to prohibit sensitive prompt/response logging
  by default.
- Data-recovery applicability is explicit; a stateless service cannot silently
  omit the decision.

### AI behavior

- No model, prompt, tool permission, evaluation, or AI runtime behavior changes.
- Operational guidance retains AI telemetry requirements for provider, model,
  prompt identifier/version, latency, tokens, cost, fallback, tool calls,
  guardrail events, and evaluation score without raw sensitive content.

## Operational documentation

Expand these current skeletons without selecting a vendor:

- `docs/operations/observability.md`: telemetry contract, correlation,
  sensitive-data boundaries, ownership, and evidence expectations.
- `docs/operations/monitoring.md`: SLI/SLO definitions, measurement windows,
  error-budget response, and dashboard minimums.
- `docs/operations/alerting.md`: severity, routing, deduplication, actionable
  content, runbook linkage, and review cadence.
- `docs/operations/runbook.md`: required runbook structure, incident decision
  flow, escalation, communications, and evidence capture.
- `docs/operations/rollback.md`: rollback types, decision authority, immutable
  artifact verification, stop conditions, database forward recovery, and test
  evidence.
- `docs/operations/backup-and-recovery.md`: scope, encryption, retention,
  restore testing, evidence, and ownership.
- `docs/operations/disaster-recovery.md`: RTO/RPO, dependency order, exercise
  cadence, decision authority, and lessons learned.
- `docs/operations/capacity-management.md`: demand signals, scaling thresholds,
  cost ceilings, saturation response, ownership, and review evidence.
- `docs/operations/deployment-guide.md`: link the readiness and rollback
  controls while preserving Phase 5 workflow status.
- `observability/README.md`: explain the manifest lifecycle and prohibit
  treating template status as approval.

Update `AGENTS.md`, `CHANGELOG.md`, and `docs/plans/technical-debt.md` so the
current state is unambiguous. Add TD-0011 for consumer activation of the
manifest, observability backend, and real rollback command. GitHub Environment
configuration remains tracked by TD-0009; TD-0009 and TD-0010 stay open.

ADR-0002 records the approval-neutral output decision. It preserves the
existing OpenTelemetry recommendation and production-control policy without
selecting an observability or deployment platform.

## Test approach

Create `scripts/test/test-production-readiness.sh`. It executes the real
validator using isolated temporary repositories/files and independently
derived fixtures.

Behavioral cases include:

1. committed template manifest succeeds and reports a valid contract plus
   false production readiness;
2. complete active stateful manifest succeeds with the same approval-neutral
   output and never reports true readiness;
3. complete active stateless manifest succeeds with explicit recovery
   non-applicability;
4. malformed, duplicate, unknown, missing, or empty keys fail;
5. unsupported schema and readiness states fail;
6. invalid SLO, window, RTO, RPO, and date formats fail;
7. `UNSET` active values and inconsistent recovery fields fail;
8. missing, generic, symlink-escaped, absolute, or parent-traversal document
   paths fail; and
9. removing any required evidence field causes at least one fixture to fail;
   and
10. ambient Git repository-selection variables cannot redirect root discovery.

Workflow contract cases include:

- exact trusted triggers and the absence of `pull_request_target`;
- least-privilege permissions and checkout hardening;
- absence of `continue-on-error`;
- production-readiness execution of the canonical Make target;
- rollback manual-only triggering, required input set, environment binding,
  isolated concurrency, and non-cancellation;
- absence of OIDC, secrets, checkout, services, containers, and third-party
  Actions in rollback;
- safe input mapping and explicit validation; and
- exact rollback validation body, exact ordered two-step set, and retention of
  the unwired non-zero sentinel.

Validation commands:

```bash
make readiness-check
make test-scripts
make ci
make docs-check
actionlint .github/workflows/*.yml
shellcheck -x scripts/validate-production-readiness.sh scripts/test/test-production-readiness.sh
uvx zizmor --pedantic .github/workflows/production-readiness.yml .github/workflows/rollback.yml
git diff --check
```

The pull request must show a successful production-readiness contract check
whose summary still says `production_ready=false`. A remote rollback dispatch
is not required because success is intentionally impossible until a consumer
wires a platform; the local contract proves the sentinel remains fail closed.

## Acceptance criteria

1. The committed manifest is schema-complete, validates in template mode, and
   reports `production_ready=false`.
2. Valid active stateful and stateless fixtures report
   `readiness_contract_valid=true` and `production_ready=false`; active output
   never reports true readiness.
3. Every incomplete, unsafe, generic, or inconsistent active fixture fails.
4. `make readiness-check` is always available and `make ci` runs it.
5. The read-only production-readiness workflow runs for pull requests to
   `main`, pushes to `main`, and manual dispatches.
6. The manual rollback workflow validates immutable identity and audit inputs,
   binds the selected environment, and fails at the unwired sentinel.
7. Neither new workflow receives production write access, OIDC, secrets, or an
   unpinned third-party Action.
8. Operational documents define actionable vendor-neutral requirements and no
   longer consist only of adaptation placeholders.
9. Ambient Git repository-selection variables cannot redirect validator root
   discovery, and non-Git manifests remain rejected under a poisoned Git env.
10. The rollback workflow has exactly the two approved ordered steps and the
    exact validation body; added production-action steps are rejected by tests.
11. TD-0011 records the consumer-owned activation work; TD-0009 and TD-0010
   remain open.
12. Existing deploy and smoke-test workflow skeletons are unchanged.
13. Local tests, documentation checks, workflow linters, security audit, and
    diff checks pass with actual recorded evidence.
14. No production deployment, rollback, data mutation, infrastructure change,
    or external message occurs.

## Rollout and migration

This is an additive template change. Existing consumers receive the manifest
in `template` status and a green contract check that explicitly reports false
readiness. Consumers activate the contract in a separate reviewed change only
after selecting operational targets and supplying evidence.

There is no data migration. Repository owners separately configure GitHub
Environments and Required Reviewers; the workflow cannot do that for them.

## Rollback implications

Reverting the implementation removes the validator, checks, workflow skeleton,
and expanded guidance. It does not roll back an application or production
environment because this phase performs no production action. If the validator
contains a defect, correct it through a reviewed change; do not bypass it with
`continue-on-error` or claim readiness from a suppressed failure.
