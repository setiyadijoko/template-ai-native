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
