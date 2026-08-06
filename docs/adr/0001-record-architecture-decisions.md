# ADR-0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-08-05

## Context

`template-ai-native` is a reusable, **stack-agnostic** GitHub template. It encodes engineering, AI-agent, security, and operational governance without committing to a language, framework, or deployment target. We need (a) a place to record future architecture decisions for consumer projects, and (b) a decision record for two foundational choices: adopting ADRs, and keeping the template stack-agnostic.

## Decision

1. **Adopt ADRs** as the mechanism for recording architecture decisions, using the MADR-inspired format in `docs/templates/adr-template.md`. Numbered sequentially under `docs/adr/`.
2. **The template remains stack-agnostic.** No language, framework, runtime, database, or deployment platform is committed. `src/` is consumer-owned; CI adapts via `scripts/detect-stack.sh`.

## Alternatives considered

- **No ADRs / decisions in chat or PR comments:** rejected — decisions must be durable and discoverable (see `AGENTS.md` source-of-truth hierarchy).
- **A committed reference stack (e.g. Python or Node):** rejected — reduces reusability across target project types; tooling would run for one ecosystem only.
- **Multiple stack variants with a selector:** rejected for v1 — heavy to maintain; revisit if demand emerges.

## Consequences

- Every consumer architecture decision is traceable.
- Consumers must wire their own toolchain; Make targets no-op until then.
- Tooling that requires a stack (formatter, linter, type checker, real deploy steps) is delivered as scaffolding + stack-detecting stubs.

## Security implications

Stack-agnosticism means no concrete security tooling runs until a stack is adopted. Mitigation: security workflows (secret scan, CodeQL, dependency review, workflow security) are stack-independent and run regardless.

## Data implications

None at the template level — no data stores are committed. Consumer data decisions get their own ADRs.

## Operational implications

Consumers must run `scripts/setup-branch-protection.sh` and adopt a stack before production. Observability guidance (OpenTelemetry) is provided but not wired.

## Migration strategy

N/A — this is the bootstrap decision.

## Rollback considerations

Stack-agnosticism can be reversed by adopting a reference stack in a future ADR; existing governance docs and workflows would remain valid.
