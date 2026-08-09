# Architecture Decision Records (ADR)

ADRs capture architecture decisions and their consequences. They are dated, traceable, and reversible: each has a status lifecycle.

## When to write an ADR

Write an ADR for decisions about: language, framework, database, messaging, authentication, deployment platform, AI model provider, vector database, multi-tenancy, observability platform, API style, repository structure, build system. See `AGENTS.md` — architecture changes without an ADR are prohibited.

## Format

Use the template at [../templates/adr-template.md](../templates/adr-template.md) (MADR-inspired). Each ADR includes: title, status, date, context, decision, alternatives considered, consequences, security implications, data implications, operational implications, migration strategy, rollback considerations.

## Status lifecycle

`Proposed` → `Accepted` → (`Superseded by ADR-NNNN` | `Deprecated`)

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-08-05 |
| [0002](0002-keep-readiness-validation-approval-neutral.md) | Keep readiness validation approval-neutral | Accepted | 2026-08-07 |
| [0003](0003-adopt-local-first-graph-pr-review.md) | Adopt local-first graph PR review | Accepted | 2026-08-07 |
| [0004](0004-integrate-structural-and-semantic-review.md) | Integrate structural and semantic PR review | Accepted | 2026-08-07 |
| [0005](0005-adopt-graphify-as-optional-codebase-memory.md) | Adopt Graphify as optional codebase memory | Accepted | 2026-08-07 |
| [0006](0006-explicit-project-layout.md) | Declare project layout before stack detection | Accepted | 2026-08-08 |
| [0007](0007-component-aware-monorepo-ci-contract.md) | Define a component-aware monorepo CI contract | Proposed | 2026-08-09 |
