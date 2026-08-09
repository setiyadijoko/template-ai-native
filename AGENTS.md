# AGENTS.md — Canonical Agent Instructions

> **This is the canonical instruction file for every AI coding agent working on this repository.** Read it before modifying anything. Tool-specific adapters (`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/project.mdc`, `.codex/instructions.md`) supplement but do **not** override this file.

## Repository purpose

`template-ai-native` is a reusable, **stack-agnostic** GitHub template that lets a development team and AI coding agents build AI-native applications to a consistent, governed standard — from discovery through production operation. No programming language or framework is committed; `src/` is consumer-owned. CI adapts via `scripts/detect-stack.sh`.

## Business context

The template targets AI-enabled enterprise applications, AI agents and agentic workflows, RAG applications, LLM gateways, document extraction and OCR, internal enterprise apps, API services, web apps, background workers, data-processing apps, integration platforms, and cloud-native or self-hosted systems. Engineering here means governing the full lifecycle: business problem → requirements → design → implementation → testing → security → review → build → deploy → monitoring → incident management → continuous improvement.

## Documentation hierarchy

```text
PRODUCT.md        → WHY   (vision, problem, users, metrics, scope)
      ↓
DESIGN.md         → WHAT  (approved system design: requirements, flows, model, acceptance criteria)
      ↓
ARCHITECTURE.md   → HOW   (executive view: components, boundaries, topology)
      ↓
docs/adr/         → WHY-THAT-CHOICE (traceable decisions + alternatives + consequences)
      ↓
AGENTS.md         → HOW-WE-WORK (this file: canonical agent discipline, boundaries, DoR/DoD)
      ↓
docs/plans/active/ → CURRENT-FEATURE designs (moved to completed/ on merge)
```

`DESIGN.md` is the **approved baseline**, not a scratchpad. Feature-specific designs live in `docs/plans/active/YYYY-MM-DD-<feature>-design.md` and move to `docs/plans/completed/` when shipped.

## Architecture summary

See `ARCHITECTURE.md` for the executive overview and `DESIGN.md` for the approved design. `src/` is consumer-owned — do not commit a language/framework unless the project owner explicitly adopts one. Single-stack CI is stack-aware (`scripts/detect-stack.sh`); a version-2 monorepo uses the explicit component resolver and `ci-monorepo.yml`, while unknown/no-config paths remain safe no-ops.

## Source-of-truth precedence

When instructions conflict, follow the higher-precedence source; do not silently choose. Identify the conflict, follow precedence, document any material deviation, and request approval when required.

1. Security, legal, compliance, and regulatory requirements
2. Explicit approved business requirements
3. `PRODUCT.md`
4. `DESIGN.md`
5. Accepted Architecture Decision Records
6. `ARCHITECTURE.md`
7. `AGENTS.md` (this file)
8. Approved implementation plan
9. Existing code conventions
10. Tool-specific agent instructions

## Setup, test, build, and security commands

```text
make setup            # project bootstrap (no-op until a stack is wired)
make dev              # run locally
make test             # all tests
make test-unit        # unit only
make build            # build the artifact
make security         # secret/dependency/container/IaC scans (stubs until stack wired)
make ci               # local mirror of the primary CI quality gate
make docs-check       # markdown lint + link check + TBD/TODO scan
```

These no-op cleanly until a stack is detected in `src/`. `make ci` and `make docs-check` always run (they validate the template itself).

> CI runs these via the `ci.yml` dispatcher. Single-stack repositories call the `ci-quality` / `ci-test` / `build` reusable workflows; validated version-2 monorepos call `ci-monorepo.yml` with explicit component working directories and aggregate checks. The per-stack tool commands live in `scripts/stack-tools.sh` (single source of truth) — change a tool there, not in each workflow. `make test-scripts` runs the shell tests for the detection, resolver, and workflow contracts.

## Directory boundaries

| Directory | Owner | Can AI agents modify? |
|---|---|---|
| `src/` | Consumer (project) | Yes, after a stack is adopted |
| `tests/` | Consumer | Yes, with implementation changes |
| `docs/` (incl. `docs/plans/active/`) | Project | Yes — keep in sync with changes |
| `docs/adr/` | Project | Yes — add a new ADR for architecture decisions |
| `prompts/`, `evals/` | Project | Yes — prompt changes are reviewed like code |
| `.template/` | Consumer project metadata | Yes — generated layout config is credential-free and reviewed like code |
| `.github/workflows/` | Template maintainers | Yes, with care; workflow security rules apply |
| `infrastructure/`, `deployment/`, `observability/` | Consumer | Yes, with relevant scans |
| `AGENTS.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md` | Project | Yes — `DESIGN.md` only after approval |
| `.github/CODEOWNERS`, branch protection | Owners | Propose only; do not self-approve |

## Coding conventions

- Follow existing naming, style, and patterns. Do not reformat unrelated files.
- Conventional Commits: `feat, fix, docs, test, refactor, perf, build, ci, chore, security, revert`.
- One coherent change per PR; never mix feature work with refactoring, dependency upgrades, style-only changes, architecture changes, or infrastructure modernization.
- Match the surrounding code's comment density and idiom.

## Prohibited changes

Do not:

- Code before understanding the requirement; silently make assumptions; mark assumptions as facts.
- Generate a large application in one uncontrolled pass; create speculative features; create abstractions for a single use case; add configuration without a requirement.
- Change architecture without an ADR; modify unrelated code; do broad refactoring inside a bug fix; reformat adjacent modules.
- Hide business logic in controllers or UI.
- Hardcode credentials; log secrets; commit secrets in any form.
- Provide AI agents unrestricted access to shell, production databases, cloud consoles, email, source-control administration, infrastructure, payment systems, production deployment, or secrets.
- Trust unvalidated LLM output; call a model-provider SDK directly from business logic (use the adapter/gateway layer).
- Disable tests to make CI pass; lower security thresholds without approval; create meaningless coverage-only tests.
- Use mutable `latest` tags in production; rebuild a different artifact for production; silently introduce breaking changes.
- Automatically accept AI review findings; fabricate command output, test results, security-scan results, or deployment success.

## Database migration rules

- All schema changes are version-controlled, peer-reviewed migrations.
- Test migrations against a realistic database before merge.
- Prefer expand-and-contract for breaking schema changes; keep changes backward-compatible during rolling deployment.
- Include forward-recovery or rollback strategy, data-validation steps, and a performance assessment.
- Avoid destructive changes in the same release where possible.
- Production destructive migrations require explicit approval.
- **AI agents must not modify production data directly.** Database rollback is not assumed safe.

## API compatibility rules

- No undocumented breaking API changes. See `docs/api/versioning.md`.
- Validate AI-generated output against a schema before it enters databases, workflows, automated actions, external APIs, financial calculations, approval processes, or enterprise systems.
- Invalid output must fail safely; do not silently accept malformed model output.

## Security rules

- Least privilege everywhere: `permissions: contents: read` default in workflows; write only at job level.
- No secrets in logs; do not log raw sensitive prompts or responses by default.
- Validate AI output before trust (see API compatibility).
- Pin third-party GitHub Actions to immutable commit SHA (document the release tag).
- Scan secrets (gitleaks), code (CodeQL), dependencies, containers, and IaC per `.github/workflows/`.
- **Phase 3 security scans:** `secret-scan` (gitleaks) and `dependency-review` (critical/high) are blocking. CodeQL runs on pull requests to `main`, pushes to `main`, schedule, and manual dispatch; scanner execution and Code Scanning storage fail closed. Scorecard findings remain advisory, while Scorecard execution, OIDC publication, and SARIF storage fail closed. `dependency-audit` and `license-check` remain advisory. See `docs/security/`.
- See `docs/security/` for the full threat model, data classification, access control, and incident response.

## Secrets rules

- Never commit real credentials. `.env.example` contains names + descriptions + safe placeholders only.
- Production secrets reside in an approved secret manager; use OIDC over long-lived cloud credentials.
- Report any accidentally committed secret immediately and rotate it (see `SECURITY.md`).

## AI model and prompt rules

- **Model abstraction (spec §7.1):** business logic must not call a provider SDK directly. Use a controlled adapter/gateway layer supporting provider/model selection, fallback, timeout, retry, rate limits, circuit breakers, token/cost limits, model routing, structured logging, and evaluation hooks.
- **Prompt management (spec §7.2):** production prompts live in `prompts/registry.yaml` — each with id, name, purpose, version, owner, input, output schema, model compatibility, safety constraints, eval dataset, changelog, deprecation status. Prompt changes are reviewed like code and trigger relevant AI evaluations.
- **Structured output (spec §7.3):** prefer schema-constrained output; validate before use.
- **Phase 4 AI workflows:** `ai-evaluation.yml` (skeleton, advisory; skips without `AI_EVAL_API_KEY`) and `open-code-review.yml` (Alibaba OCR, advisory; skips without `OCR_LLM_*` secrets). Both use `pull_request` (not `pull_request_target`) per the security rule. See `docs/ai/evaluation-strategy.md`.

## Testing requirements

- Unit (domain rules, validation, transformations, authorization, routing logic, prompt builders, parsers, guardrails), contract (FE↔BE, adapters, tool interfaces), integration (DB, migrations, queues, auth, adapters with test doubles), E2E (critical journeys only), AI tests (deterministic CI with stubs; real-model calls only in controlled workflows with spending limits).
- Thresholds (configurable): overall automated-test coverage ≥80%, critical domain modules ≥90%, changed-lines ≥90%, critical security findings = 0, committed secrets = 0, blocking lint/type errors = 0. See `docs/development/testing-strategy.md`.
- No meaningless tests created only to raise coverage.

## Documentation update requirements

- Keep `DESIGN.md`, relevant ADRs, and operations docs in sync with changes.
- A new architecture decision requires a new ADR before the change is merged.
- Update the changelog (`CHANGELOG.md`) under `## [Unreleased]`.
- Record deferred technical debt in `docs/plans/technical-debt.md`, not in code comments alone.

## Production restrictions

AI agents **may** generate code/tests/IaC/release notes, prepare deployment plans, deploy to **development**, deploy to **staging when permitted**, and **propose** a production deployment.

AI agents **must not** deploy to production without **all** of:

- configured GitHub Environment approval;
- authorized human approval;
- required checks green;
- verified release artifact (the exact artifact validated in staging — no rebuild);
- documented rollback procedure.

**Phase 5 delivery pipeline:** `sbom.yml` (SPDX SBOM), `artifact-attestation.yml` (Sigstore build-provenance), and `release.yml` (on `v*` tag) are ACTIVE. The three `deploy-*.yml` workflows and `smoke-test.yml` are SKELETONS — wire them to your platform with OIDC when you adopt a deploy target. Production deploy points at the `production` GitHub Environment, which MUST have Required Reviewers enabled (human gate). See `docs/operations/deployment-guide.md`.

Phase 6 production-readiness baseline: `production-readiness.yml` validates the
vendor-neutral manifest. `template` and `active` status can be contract-valid,
but the validator always reports `production_ready=false`; `active` additionally
fails closed unless required SLO, alert, recovery, and rollback references are
complete. It does not verify human review, evidence freshness, content approval,
or production authorization; those remain separate human and platform controls.
`rollback.yml` is manual, environment-bound, and
must fail at the unwired sentinel until an approved platform-specific design
adds artifact verification, authentication, execution, and recovery checks.

## Definition of Ready

A feature is ready only when: business objective defined; target user identified; scope and out-of-scope defined; business rules documented; acceptance criteria testable; dependencies known; security, data, privacy, and AI-behavior impact assessed; design approved when required; unresolved blockers identified; rollback implications understood. See `docs/development/definition-of-ready.md`.

## Definition of Done

A feature is complete only when: acceptance criteria satisfied; format/lint/type-check pass; required tests pass with coverage thresholds; security scanning passes; AI evaluations pass where applicable; documentation updated; ADR updated where applicable; observability included; error handling verified; migrations documented; rollback documented; deployment impact documented; the complete diff reviewed; no unrelated change included; CI green; required human review completed; no fabricated results; no known critical issue unresolved. See `docs/development/definition-of-done.md`.

## Karpathy-inspired coding discipline

The following five rules are mandatory; the detailed guidance is in
[`docs/ai/coding-discipline.md`](docs/ai/coding-discipline.md):

1. Think before coding; state assumptions, inspect existing implementation,
   define verification, and stop when requirements conflict with approved
   architecture or security policy.
2. Prefer the simplest sufficient implementation without sacrificing
   correctness, security, observability, or maintainability.
3. Make surgical changes that are traceable to the requirement; avoid
   unrelated refactoring, formatting, upgrades, and speculative configuration.
4. Define measurable outcomes; for bugs use reproduce → failing test → fix →
   verify → regression.
5. Review the complete diff for correctness, security, tests, documentation,
   and accidental changes before completion.

## Avoid unrelated refactoring

When you discover unrelated technical debt while working on a task: record it, report it, optionally create a separate issue, and **do not fix it in the current change** unless it blocks the requested work. See "Surgical changes" above.

## Never fabricate results

Never state that a command passed unless it was executed successfully. Never fabricate command output, test results, deployment status, security findings, or evaluation scores. Record actual results; if a check fails, say so with the output.

## Inspect the complete diff before completion

Before declaring work done, run `git diff` over the full change. Confirm every changed file and line supports the task, no debug code or temporary config remains, no secret is present, no unrelated formatting was introduced, tests match changed behavior, and documentation matches implementation.

## Agent implementation workflow

Every task follows the nine-step loop in
[`docs/ai/implementation-workflow.md`](docs/ai/implementation-workflow.md):
Orient → Inspect → Define success → Plan → Implement incrementally → Test
continuously → Self-review the complete diff → Verify → Report.
