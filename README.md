# template-ai-native

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Status: Template](https://img.shields.io/badge/Status-Template-2ea44f)

**Status:** Template baseline — adapt to your project.

A reusable, production-grade, **stack-agnostic** GitHub template for building AI-native applications to a consistent, governed standard — from discovery through production operation and continuous improvement. It carries engineering standards, AI-agent operating rules, architectural governance, documentation standards, quality gates, automated testing, security controls, supply-chain controls, AI evaluation, CI/CD workflows, deployment governance, production observability, operational readiness, and rollback/disaster-recovery procedures — **without** committing to a specific language, framework, or deployment target.

## Project overview

This is a **template repository** ("Use this template"). Consumers create a new repo from it and select their stack; the template's CI adapts via `scripts/detect-stack.sh`. It targets AI-enabled enterprise applications, AI agents and agentic workflows, RAG applications, LLM gateways, document extraction and OCR, internal enterprise apps, API services, web apps, background workers, data-processing apps, integration platforms, and cloud-native or self-hosted systems.

## Business objective

Enable a development team and AI coding agents to produce code that is business-aligned, easy to understand, focused, secure, testable, maintainable, observable, deployable, reversible, auditable, and production-ready — governing the complete lifecycle:

```
Business Problem → Product Requirements → System Design → Architecture Decision
→ Implementation Plan → Development → Automated Testing → Security Validation
→ Code Review → Build → Deployment → Production Monitoring → Incident Management
→ Continuous Improvement
```

## Major capabilities

- Document-driven development (`PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, ADRs).
- Canonical AI-agent instructions (`AGENTS.md`) with Karpathy-inspired discipline.
- Stack-detecting CI that no-ops cleanly until a stack is wired.
- Quality gates (format, lint, typecheck, tests, coverage).
- Security controls (secret scan, SAST, dependency review, workflow security, license).
- AI-native scaffolding (prompt registry, eval framework, model-abstraction guidance, AI observability).
- Supply-chain controls (SBOM, artifact attestation, OpenSSF Scorecard).
- Phased CI/CD with human-gated production deployment and rollback.

## Architecture summary

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the executive overview and [`DESIGN.md`](DESIGN.md) for the approved design. In short: a documentation-and-governance layer with stack-aware CI; `src/` is consumer-owned and left empty.

## Technology stack

None committed. The template uses Markdown (docs/templates), GitHub Actions (YAML), and POSIX shell (scripts, Makefile). Consumers adopt their own language and framework in `src/`.

## Prerequisites

- Git.
- `make` (POSIX).
- Python 3 (for YAML validation and metadata checks).
- A supported language toolchain once a stack is adopted (consumer-provided).
- (Optional, for local checks) `markdownlint-cli2`, `lychee`, `actionlint`, `yamllint`.

## Local setup

```sh
git clone <your-new-repo-from-this-template>
cd <your-repo>
cp .env.example .env      # then edit .env with real values (never commit it)
make setup                # bootstrap (no-op until a stack is wired)
```

## Common commands

| Command | Purpose |
|---|---|
| `make setup` | Project bootstrap |
| `make dev` | Run locally |
| `make format` / `make format-check` | Format / verify formatting |
| `make lint` | Lint |
| `make typecheck` | Static type checking |
| `make test` / `make test-unit` / `make test-integration` / `make test-e2e` | Tests |
| `make test-coverage` | Coverage report |
| `make eval` / `make eval-regression` / `make eval-safety` | AI evaluations |
| `make security` | Secret + dependency + container + IaC scans |
| `make build` | Build artifact |
| `make run` | Run the built artifact |
| `make smoke-test` | Post-deploy smoke |
| `make docs-check` | Markdown lint + link check + TBD/TODO scan |
| `make ci` | Local mirror of the primary CI gate |

Targets no-op cleanly until a stack is detected in `src/`.

## Testing

Tests live under `tests/{unit,contract,integration,e2e,security,performance}/`. See [`docs/development/testing-strategy.md`](docs/development/testing-strategy.md) for the strategy and thresholds. Run `make test` once a stack is wired; `make ci` runs the local gate.

## Security reporting

**Do not open public issues for security vulnerabilities.** Report privately via GitHub Security Advisories (`gh security-advisory`) or the contact in [`SECURITY.md`](SECURITY.md). See [`SECURITY.md`](SECURITY.md) for scope and response SLA (acknowledge ≤48h, initial assessment ≤5 business days).

## Deployment overview

Environments: `local`, `test` (CI), `development`, `staging`, `production`. Development deploys on merge to `main`; staging is manual and protected; production is **human-gated** via GitHub Environment approval with OIDC and promotes the exact artifact validated in staging (no rebuild). See [`docs/operations/deployment-guide.md`](docs/operations/deployment-guide.md).

## Documentation index

- [PRODUCT.md](PRODUCT.md) — why (vision, problem, users, metrics, scope)
- [DESIGN.md](DESIGN.md) — what (approved system design)
- [ARCHITECTURE.md](ARCHITECTURE.md) — how (executive architecture)
- [AGENTS.md](AGENTS.md) — how we work (canonical agent instructions)
- [docs/](docs/) — full documentation tree (product, architecture, ADRs, API, security, AI, development, operations, plans, templates)
- [CONTRIBUTING.md](CONTRIBUTING.md) — contribution process
- [SECURITY.md](SECURITY.md) — security policy
- [CHANGELOG.md](CHANGELOG.md) — notable changes

## Contribution process

See [CONTRIBUTING.md](CONTRIBUTING.md). Trunk-based development, all changes via PR to `main`, no direct push, Conventional Commits, squash-merge default, at least one reviewer (CODEOWNERS for sensitive paths). AI-agent contributors must read and follow `AGENTS.md`.

## Current project status

**Phase 1 (Repository governance): in progress.** Phases 2–6 (code-quality baseline, security baseline, AI-native capability, delivery pipeline, production readiness) are planned — see `docs/superpowers/specs/2026-08-05-template-ai-native-design.md` and `docs/superpowers/plans/2026-08-05-phase1-repository-governance.md`.
