# PRODUCT.md

**Status:** Template baseline — adapt to your project.

`PRODUCT.md` defines **why** this product exists. It is the highest-level source of truth after security/legal/compliance requirements and approved business requirements.

## Product vision

A reusable, stack-agnostic GitHub template that lets teams and AI coding agents ship AI-native applications to a consistent, governed, production-grade standard — without locking in a language, framework, or platform.

## Business problem

Teams building AI-native applications repeatedly reinvent governance: documentation discipline, agent operating rules, quality gates, security controls, supply-chain protections, AI evaluation, CI/CD, observability, and rollback. Without a shared baseline, quality and security drift, AI agents make speculative changes, and production deployments lack human control.

## Target users

- Engineering teams starting a new AI-native application.
- AI coding agents (Claude Code, Copilot, Cursor, Codex) operating on the codebase.
- Platform/security engineers enforcing organizational standards.
- Technical leads accountable for production readiness and auditability.

## Stakeholder groups

- Product owners (business outcomes).
- Engineering (delivery).
- Security and compliance (risk).
- Operations/SRE (reliability).
- AI/ML evaluation (model behavior and cost).

## User needs

- "I can start a new AI-native project with governance already in place."
- "My AI coding agent understands its boundaries and follows a disciplined workflow."
- "Pull requests receive deterministic checks plus AI-assisted review."
- "Production deployments are human-gated and reversible."
- "AI behavior is evaluated before release."

## Primary journeys

1. **Start a project** — use the template → adopt a stack → wire CI → first deploy to dev.
2. **Ship a feature** — design doc → PR → quality + security + AI gates → review → merge → dev deploy → staging → production (human-gated).
3. **Evaluate AI behavior** — add prompt/eval → run regression + safety evals → gate release.
4. **Recover** — detect incident → runbook → rollback → postmortem.

## Business value

- Faster, safer starts for AI-native projects.
- Reduced security and supply-chain risk.
- Consistent, auditable engineering standards across teams.
- Controlled, human-gated production changes.
- Measurable AI quality and cost.

## Product principles

- Business-first engineering.
- Document-driven development.
- Design before implementation.
- Small-context, reversible increments.
- Evidence before completion.
- Human-controlled production.
- Simplicity first; surgical changes; goal-driven execution.

## Success metrics

- Time from "use template" to first dev deploy.
- PR check coverage (deterministic + AI-assisted).
- Critical/high security findings in `main`: zero.
- AI evaluation pass rate on release.
- Mean time to recover (MTTR) from incidents.
- Committed secrets: zero.

## Scope

- Governance, documentation, agent instructions, CI/CD workflows, security controls, AI scaffolding, observability guidance, operational readiness docs.

## Out of scope

- A committed language/framework/runtime.
- A concrete deployment target (AWS/GCP/K8s) with working deploy steps.
- A working model-provider adapter (skeleton only; consumer wires the endpoint).
- DAST, performance-test, canary, and DR-validation automation (deferred; need a target).

## Roadmap

- **Phase 1** — Repository governance (baseline complete).
- **Phase 2** — Code-quality baseline (baseline complete).
- **Phase 3** — Security baseline (baseline complete).
- **Phase 4** — AI-native capability (baseline complete; consumer evaluation remains advisory).
- **Phase 5** — Delivery pipeline (baseline complete; deploy and smoke workflows remain skeletons).
- **Phase 6** — Production readiness (baseline complete; consumer platform activation remains deferred).

## Assumptions

See [docs/assumptions.md](docs/assumptions.md) and the spec's assumptions section. Key: stack-agnostic (no tooling runs until a stack is wired); no real deployment target; AI-eval is a skeleton; branch protection is applied by the consumer via `scripts/setup-branch-protection.sh`.

## Constraints

- No language/framework committed.
- MIT license for the template.
- No production target.
- All Make targets no-op cleanly until a stack is wired.
- Workflows follow least-privilege, SHA-pinned-Actions security rules.
