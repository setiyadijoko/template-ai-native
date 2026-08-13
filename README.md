<!-- template-ai-native:project-identity:start -->
# template-ai-native

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Status: Template](https://img.shields.io/badge/Status-Template-2ea44f)

**Status:** Template baseline — adapt to your project.

A reusable, production-grade, **stack-agnostic** GitHub template for building AI-native applications to a consistent, governed standard — from discovery through production operation and continuous improvement. It carries engineering standards, AI-agent operating rules, architectural governance, documentation standards, quality gates, automated testing, security controls, supply-chain controls, AI evaluation, CI/CD workflows, deployment governance, production observability, operational readiness, and rollback/disaster-recovery procedures — **without** committing to a specific language, framework, or deployment target.
<!-- template-ai-native:project-identity:end -->

## Project overview

This is a **template repository** ("Use this template"). Consumers create a new repo from it and select their stack; the template's CI adapts via `scripts/detect-stack.sh`. It targets AI-enabled enterprise applications, AI agents and agentic workflows, RAG applications, LLM gateways, document extraction and OCR, internal enterprise apps, API services, web apps, background workers, data-processing apps, integration platforms, and cloud-native or self-hosted systems.

## Quick start for every skill level

This repository is a starting point for an application, not the application
itself. The shortest safe path is:

1. Click **Use this template** on GitHub and create a new repository.
2. Clone that new repository and enter its directory.
3. Personalize the README identity:

   ```sh
   ./scripts/init-project.sh --name my-app --description "My application" --stack auto --layout single --profile standard
   ```

4. Write the business goal in `PRODUCT.md` and the approved design in
   `DESIGN.md`.
5. Add your application under `src/` and tests under `tests/`.
6. Run the local checks:

   ```sh
   make ci
   make docs-check
   ```

7. Create a branch, commit your changes, and open a pull request on GitHub.

If you are new to GitHub or software projects, follow the step-by-step
walk-through in [`docs/getting-started.md`](docs/getting-started.md). It
explains the terms, expected results, optional controls, and common problems.

### What is required and what is optional?

| Do this first | Add when needed | Consumer-specific |
|---|---|---|
| `PRODUCT.md`, `DESIGN.md`, layout choice, `src/`, tests, `make ci`, secret handling | AI evaluations when required by an AI-enabled Standard/Enterprise profile, Alibaba review, Graphify, Code Review Graph promotion | Runtime provider, database, deployment target, health endpoint, GitHub Environments |

The template is useful even when no stack has been chosen yet. In that state,
stack-dependent commands report a clean no-op; this is expected, not a failure.

For a monorepo, choose `layout: monorepo` and list each component explicitly in
`.template/project.yaml` version 2. The component-aware workflow uses each
component's declared path and stack; it never selects the first nested manifest.
Version-1 monorepos remain in the safe `unknown` compatibility mode until they
migrate to the version-2 component contract.

## How to use this template

The [getting-started guide](docs/getting-started.md) contains the complete
walk-through. Experienced users can use the quick start above, then consult
the linked security, AI, development, and operations documents as each area is
introduced.

The template supplies governance and workflow contracts; the consumer remains
responsible for application code, provider configuration, secrets, health
endpoints, deployment commands, and production approvals.

## Business objective

Enable a development team and AI coding agents to produce code that is business-aligned, easy to understand, focused, secure, testable, maintainable, observable, deployable, reversible, auditable, and production-ready — governing the complete lifecycle:

```text
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
- Advisory local-first graph-aware PR review with fork-safe report publication (see [`docs/ai/code-review-graph.md`](docs/ai/code-review-graph.md)).
- Optional Alibaba semantic review complements the graph report; see [`docs/ai/integrated-code-review.md`](docs/ai/integrated-code-review.md).
- Optional Graphify codebase knowledge complements both review layers; see [`docs/ai/graphify.md`](docs/ai/graphify.md).
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
# Replace YOUR-ORG/YOUR-REPO with the repository you created from this template.
git clone https://github.com/YOUR-ORG/YOUR-REPO.git
cd YOUR-REPO
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
| `make profile-policy-check` | Validate the effective profile policy; the empty template remains compatible |
| `make ci` | Local mirror of the primary CI gate |

Single-stack targets no-op cleanly until a stack is detected. A declared
version-2 monorepo runs through the component-aware GitHub Actions workflow;
the root Make targets remain stack-agnostic.

## Testing

Tests live under `tests/{unit,contract,integration,e2e,security,performance}/`. See [`docs/development/testing-strategy.md`](docs/development/testing-strategy.md) for the strategy and thresholds. Run `make test` once a stack is wired; `make ci` runs the local gate.

## Security reporting

**Do not open public issues for security vulnerabilities.** Report privately via GitHub Security Advisories (`gh security-advisory`) or the contact in [`SECURITY.md`](SECURITY.md). See [`SECURITY.md`](SECURITY.md) for scope and response SLA (acknowledge ≤48h, initial assessment ≤5 business days).

## Deployment overview

Environments are scoped as `local`, `test` (CI), `development`, `staging`, and
`production`. The deployment and smoke-test workflows are **skeletons** until a
consumer selects a platform, wires OIDC and health checks, and configures the
corresponding GitHub Environments. Production must remain human-gated and must
promote the exact artifact validated in staging (no rebuild). See
[`docs/operations/deployment-guide.md`](docs/operations/deployment-guide.md).

## Adoption profiles (required for initialized consumers)

Every consumer initialized with `scripts/init-project.sh` must select exactly
one of `starter`, `standard`, or `enterprise`; the initializer never infers a
profile. Non-interactive use must pass `--profile`; interactive use prompts for
the selection. `--project-type` defaults to `other` and `--ai-enabled` defaults
to `false`. An Enterprise selection must also provide a non-`none`
`--deployment-target`. A successful initialization writes both the
credential-free `.template/project.yaml` and `.template/profile.yaml` files.

Review the generated profile and validate its effective policy locally with:

```sh
sh scripts/validate-profile-config.sh .template/profile.yaml
make profile-policy-check
```

The template repository intentionally has neither configuration file and stays
valid in compatibility mode. In contrast, an initialized consumer with a
missing or invalid profile fails `make ci`; it cannot infer a profile. The
mapping and future activation gate are recorded in
[`docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md`](docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md),
with defaults in `.template/profile-controls.yaml`.

The `Profile policy / Required controls` check now resolves the
effective execution plan and runs the applicable reusable control boundaries.
Hosted Starter, Standard, Enterprise, fork, required-failure, and disposable
branch-protection rollback evidence passed. The branch-protection helper now
recommends the aggregate alongside the five invariant governance contexts.
It changes a consumer repository only when an authorized owner runs it with
`--apply`; direct baseline workflows remain enabled, so CI-cost reduction is
not active yet. See the recorded decision in
[`ADR-0010`](docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md#activation-evidence-decision--2026-08-13).

Inspect the local policy and the resulting execution plan before relying on a
hosted run:

```sh
make profile-policy-check
sh scripts/resolve-profile-execution-plan.sh
```

The older `Profile shadow / Profile policy observation` check remains an
advisory policy-only observation. Workflows do not change branch protection
automatically; repository owners retain control through the setup helper.

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

| Phase | Capability | Status |
|---|---|---|
| 1 | Repository governance | Complete baseline |
| 2 | Code quality | Complete baseline |
| 3 | Security baseline | Complete baseline |
| 4 | AI-native capability | Baseline available; provider wiring remains consumer-specific |
| 5 | Delivery pipeline | Baseline/skeleton available; platform wiring required |
| 6 | Production readiness | Governance baseline; evidence and platform configuration required |

The template itself is not a production application. A consumer must adopt a
stack, configure providers and deployment targets, supply operational evidence,
and complete the required human approvals before production use.
