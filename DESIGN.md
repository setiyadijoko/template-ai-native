# DESIGN.md

**Status:** Template baseline — adapt to your project.

`DESIGN.md` is the **approved system-design baseline**. It is not a scratchpad. Feature-specific designs belong in `docs/plans/active/YYYY-MM-DD-<feature>-design.md` and move to `docs/plans/completed/` when shipped.

## Problem statement

Teams building AI-native applications need a shared, governed baseline so that quality, security, agent discipline, and production control are consistent across projects — without locking in a stack.

## Business objectives

- Provide a reusable template that encodes engineering, AI-agent, security, and operational standards.
- Let consumers adopt any stack via stack-detecting CI.
- Make production changes human-gated, auditable, and reversible.

## Scope

Governance + documentation + stack-aware CI + security/AI/supply-chain controls (as docs and workflows) + operational readiness guidance. See [PRODUCT.md](PRODUCT.md).

## Out of scope

A committed stack, a concrete deployment target, a working model adapter, DAST/perf/canary/DR automation. See [PRODUCT.md](PRODUCT.md).

## Stakeholders

See [PRODUCT.md](PRODUCT.md) stakeholder groups.

## Personas

See [docs/product/personas.md](docs/product/personas.md).

## Functional requirements

- Provide document-driven governance files (PRODUCT/DESIGN/ARCHITECTURE/AGENTS/ADR).
- Provide stack-detecting Make + CI that no-op cleanly until a stack is wired.
- Provide PR quality, security, and AI-evaluation gates.
- Provide human-gated production deployment and rollback workflows.
- Provide AI scaffolding (prompts registry, eval framework, model-abstraction guidance).

## Non-functional requirements

See [docs/product/non-functional-requirements.md](docs/product/non-functional-requirements.md). Summary: maintainable, secure by default, observable, reversible, auditable, stack-agnostic.

## Business rules

See [docs/product/business-rules.md](docs/product/business-rules.md).

## System context

See [docs/architecture/system-context.md](docs/architecture/system-context.md). In short: a documentation/governance layer + stack-aware CI, with `src/` consumer-owned.

## Architecture overview

See [ARCHITECTURE.md](ARCHITECTURE.md) and [docs/architecture/container-view.md](docs/architecture/container-view.md).

## Component boundaries

- **Docs/governance** — root markdown + `docs/` (source of truth).
- **CI/CD** — `.github/workflows/` (stack-aware, least-privilege).
- **AI apparatus** — `prompts/`, `evals/`, `docs/ai/` (scaffolding + guidance).
- **Implementation** — `src/`, `tests/` (consumer-owned).
- **Infrastructure/deployment/observability** — consumer-owned directories with scanning hooks.

## Primary data flows

N/A for the template itself (no runtime). Consumer defines per project; see [docs/architecture/data-flow.md](docs/architecture/data-flow.md).

## Data model

N/A for the template. See [docs/architecture/data-model.md](docs/architecture/data-model.md).

## API model

N/A for the template. See [docs/api/](docs/api/).

## Integration model

The template integrates with: GitHub (Actions, Environments, Security tab, Dependabot), and (consumer-wired) AI providers, secret managers, and deployment platforms. See [docs/architecture/integration.md](docs/architecture/integration.md).

## Authentication

N/A for the template. See [docs/api/authentication.md](docs/api/authentication.md).

## Authorization

Branch protection, CODEOWNERS, GitHub Environment approval for production. See [docs/api/authorization.md](docs/api/authorization.md) and [docs/security/access-control.md](docs/security/access-control.md).

## Security model

Least privilege everywhere; secrets never committed; AI output validated before trust; production human-gated. See [docs/security/](docs/security/).

## AI subsystem

Stack-agnostic scaffolding: model abstraction via an adapter/gateway layer (no direct SDK calls), prompt registry, structured-output validation, evaluation framework, safety/leakage evals, AI observability. See [docs/ai/](docs/ai/).

## Deployment model

Target state after consumer platform activation: local → test (CI) →
development (on merge) → staging (manual and protected) → production (manual,
GitHub Environment approval and job-scoped OIDC, promoting the same artifact
without rebuilding). The current `deploy-*.yml` and `smoke-test.yml` files
remain skeletons; the template performs and proves none of those environment
deployments, approvals, OIDC authentication, or health checks. See
[docs/operations/deployment-guide.md](docs/operations/deployment-guide.md).

## Observability

OpenTelemetry recommended; structured logs with correlation IDs; RED metrics;
AI telemetry. The Phase 6 validator checks contract and evidence-reference
shape only and always reports `production_ready=false`; human review, evidence
freshness, content approval, and production authorization remain separate
human/platform controls. See
[docs/operations/observability.md](docs/operations/observability.md).

## Failure handling

Alerts link responders to runbooks; the documented incident and change
authority decides whether to stop, mitigate, or request rollback. The Phase 6
rollback baseline is manual, environment-bound, and fail closed at its unwired
sentinel, so it performs no rollback. Automated stop or rollback is a future
consumer-wired target only after an approved platform-specific design defines
thresholds, authority, execution, recovery verification, and reviewed evidence.
See [docs/operations/](docs/operations/).

## Testing strategy

See [docs/development/testing-strategy.md](docs/development/testing-strategy.md). Unit/contract/integration/E2E/AI tests; thresholds in spec §8.

## Constraints

Stack-agnostic; MIT; no production target; clean no-op Make targets; least-privilege SHA-pinned workflows. See [PRODUCT.md](PRODUCT.md) constraints.

## Risks

- Consumer skips wiring branch protection (mitigation: `scripts/setup-branch-protection.sh`).
- Phase-1 workflows pin Actions by tag pending SHA pinning (tracked in `docs/plans/technical-debt.md`).
- AI-eval skeleton may be mistaken for working evals (mitigation: READMEs mark skeleton-only).

## Assumptions

See [docs/assumptions.md](docs/assumptions.md).

## Unresolved decisions

- Specific stack (consumer decides).
- Deployment platform (consumer decides).
- AI provider + model (consumer decides).

## Acceptance criteria

See the spec's final acceptance criteria (§14). The template is acceptable when a consumer repo created from it passes all items there.
