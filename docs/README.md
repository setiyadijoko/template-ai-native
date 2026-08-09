# Documentation Index

This is the documentation tree for `template-ai-native`. Documents are the source of truth for design, architecture, security, AI behavior, development, and operations — see `AGENTS.md` for the source-of-truth hierarchy.

## How to navigate

Start with the [getting-started guide](getting-started.md) if this is your first
consumer repository or if GitHub/Git terminology is unfamiliar.

| Start with | For |
|---|---|
| [getting-started.md](getting-started.md) | Step-by-step setup, terms, expected results, and troubleshooting |
| [../PRODUCT.md](../PRODUCT.md) | Why (vision, problem, users, metrics) |
| [../DESIGN.md](../DESIGN.md) | What (approved system design) |
| [../ARCHITECTURE.md](../ARCHITECTURE.md) | How (executive architecture) |
| [../AGENTS.md](../AGENTS.md) | How we work (agent discipline, DoR/DoD) |

## Reference

- [glossary.md](glossary.md) — shared terminology
- [assumptions.md](assumptions.md) — template + project assumptions
- [constraints.md](constraints.md) — template + project constraints

## product/

Vision, personas, user journeys, requirements (functional & non-functional), business rules, success metrics. Expand these to describe *your* product.

- [vision.md](product/vision.md)
- [personas.md](product/personas.md)
- [user-journeys.md](product/user-journeys.md)
- [requirements.md](product/requirements.md)
- [non-functional-requirements.md](product/non-functional-requirements.md)
- [business-rules.md](product/business-rules.md)
- [success-metrics.md](product/success-metrics.md)

## architecture/

System context, container/component views, data flow, deployment, integration, data model, technology radar.

- [system-context.md](architecture/system-context.md)
- [container-view.md](architecture/container-view.md)
- [component-view.md](architecture/component-view.md)
- [data-flow.md](architecture/data-flow.md)
- [deployment-view.md](architecture/deployment-view.md)
- [integration.md](architecture/integration.md)
- [data-model.md](architecture/data-model.md)
- [technology-radar.md](architecture/technology-radar.md)

## adr/

Architecture Decision Records — traceable, dated, reversible decisions.

- [adr/README.md](adr/README.md) — process & index
- [adr/0001-record-architecture-decisions.md](adr/0001-record-architecture-decisions.md)
- [adr/0002-keep-readiness-validation-approval-neutral.md](adr/0002-keep-readiness-validation-approval-neutral.md)
- [adr/0003-adopt-local-first-graph-pr-review.md](adr/0003-adopt-local-first-graph-pr-review.md)
- [adr/0004-integrate-structural-and-semantic-review.md](adr/0004-integrate-structural-and-semantic-review.md)
- [adr/0005-adopt-graphify-as-optional-codebase-memory.md](adr/0005-adopt-graphify-as-optional-codebase-memory.md)
- [adr/0006-explicit-project-layout.md](adr/0006-explicit-project-layout.md)
- [adr/0007-component-aware-monorepo-ci-contract.md](adr/0007-component-aware-monorepo-ci-contract.md)

## Other documentation

- `api/` — API guidelines, error model, authn/authz, versioning, and OpenAPI skeleton with health/auth examples
- `security/` — threat model, data classification, secrets, incident response, privacy
- `ai/` — AI system design, model/prompt management, evaluation, safety, guardrails
- `development/` — setup, coding standards, branching, PR process, testing, DoR/DoD
- `operations/` — deployment, environments, observability, monitoring, alerting, runbook, rollback
- `templates/` — feature-design, implementation-plan, ADR, threat-model, incident, postmortem, release-checklist, and license-header templates
- `plans/` — active/completed feature designs + technical-debt log
