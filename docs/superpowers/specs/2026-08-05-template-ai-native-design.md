# Design Spec — `template-ai-native`

**Status:** Approved
**Date:** 2026-08-05
**Owner:** Project owner (@setiyadijoko)
**Remote:** https://github.com/setiyadijoko/template-ai-native.git

---

## 1. Executive summary

`template-ai-native` is a reusable, production-grade GitHub repository template ("Use this template") that lets a development team and AI coding agents build AI-native applications to a consistent, governed standard — from discovery through production operation and continuous improvement.

The template is **stack-agnostic**: it carries governance, documentation, agent discipline, security controls, AI evaluation scaffolding, CI/CD workflows, and operational guidance, but it does **not** commit to a specific programming language, framework, or deployment target. Consumers select their stack; the template's CI adapts via stack detection.

**Target project types.** AI-enabled enterprise applications; AI agents and agentic workflows; RAG applications; LLM gateways; document extraction and OCR systems; internal enterprise applications; API services; web applications; background workers; data-processing applications; integration platforms; cloud-native or self-hosted applications.

**Recommended maturity.** Level 2 (Production Standard) with selected Level 3 controls — the level the source brief recommends for enterprise AI projects.

**Core engineering principles enforced via docs + gates.** Business-first engineering; document-driven development; design before implementation; small-context engineering; evidence before completion; human-controlled production.

**Karpathy-inspired AI coding discipline**, canonicalized in `AGENTS.md`:
1. Think before coding.
2. Simplicity first.
3. Surgical changes.
4. Goal-driven execution.
5. Diff discipline.

Tool-specific adapters reference `AGENTS.md` rather than re-stating it.

**Source-of-truth hierarchy:**
1. Security, legal, compliance, regulatory requirements
2. Explicit approved business requirements
3. `PRODUCT.md`
4. `DESIGN.md`
5. Accepted Architecture Decision Records
6. `ARCHITECTURE.md`
7. `AGENTS.md`
8. Approved implementation plan
9. Existing code conventions
10. Tool-specific agent instructions

---

## 2. Key decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Template type | Stack-agnostic governance | Maximally reusable across the target project types |
| 2 | Maturity | Level 2 + selected Level 3 | Matches brief §31/§32 for enterprise AI |
| 3 | AI-native apparatus | Full scaffolding (docs + dirs + workflow) | Satisfies §7 and §32; remains docs/scaffolding only |
| 4 | Execution | Design first, phased build | Required by §33/§36 |
| 5 | License | MIT | Permissive, conventional for templates |
| 6 | AI-evaluation gating | Advisory now, blocking later | Matches §14 measure-then-block guidance |
| 7 | Real-model eval calls | Skeleton only; consumer wires endpoint | No cost/secrets burned on a public template |
| 8 | Make targets before stack wired | Stubs that no-op cleanly | Template stays green out of the box |
| 9 | Branch protection | Documentation + `scripts/setup-branch-protection.sh` | Cannot be applied from a template file |
| 10 | Build sequencing | Phase 1 full + verified, then checkpoint | Matches §36 incremental/verify instruction |
| 11 | Git remote | `https://github.com/setiyadijoko/template-ai-native.git` | Provided by owner; init + set remote only, no push until owner says so |

### Selected Level 3 controls (in scope)
- SBOM generation (SPDX/CycloneDX) on build
- Artifact build-provenance/attestation
- OIDC deployment credentials (documented + workflow skeleton)
- OpenSSF Scorecard
- Automated-rollback **hooks** (documented; full automation needs a deployment target)

### Level 3 controls deferred (documented as "enable when justified")
Signed releases · full policy-as-code suite · DAST · performance gates · canary/blue-green deployment · formal DR validation. These require a concrete stack or target platform; including them as empty scaffolding now would violate the "no unused infrastructure" rule and YAGNI.

---

## 3. Repository structure

```text
template-ai-native/
├── README.md                        # Overview, objective, setup, commands, doc index, status
├── AGENTS.md                        # CANONICAL agent instructions (Karpathy discipline, boundaries, DoR/DoD)
├── CLAUDE.md                        # Adapter → references AGENTS.md
├── PRODUCT.md                       # Vision, problem, users, journeys, metrics, scope, roadmap
├── DESIGN.md                        # Approved system-design baseline
├── ARCHITECTURE.md                  # Executive-readable architecture overview
├── CONTRIBUTING.md                  # Contribution process, branching, PR norms
├── SECURITY.md                      # Security policy, reporting, scope, response SLA
├── CODE_OF_CONDUCT.md               # Contributor Covenant
├── CHANGELOG.md                     # Keep a Changelog format
├── LICENSE                          # MIT
├── Makefile                         # Canonical command interface (stub no-op until stack wired)
├── .editorconfig
├── .gitignore
├── .gitattributes
├── .env.example                     # Names + descriptions + safe placeholders ONLY
│
├── .codex/instructions.md           # Adapter → AGENTS.md
├── .cursor/rules/project.mdc        # Adapter → AGENTS.md
│
├── .github/
│   ├── CODEOWNERS                   # Sensitive-path ownership
│   ├── copilot-instructions.md      # Adapter → AGENTS.md
│   ├── dependabot.yml               # github-actions + docker ecosystems
│   ├── labeler.yml
│   ├── release.yml                  # release-drafter / changelog automation
│   ├── pull_request_template.md     # Quality gates + AI discipline checklist
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug.yml
│   │   ├── feature.yml
│   │   ├── security-config.yml
│   │   └── technical-debt.yml
│   └── workflows/
│       ├── pr-title.yml             # Conventional Commits title lint
│       ├── validate-metadata.yml    # Markdown frontmatter / required-doc checks
│       ├── docs-check.yml           # markdownlint + lychee link check + TBD/TODO scan
│       ├── ci-quality.yml           # REUSABLE: language-detect → format/lint/typecheck/unit
│       ├── ci-test.yml              # REUSABLE: integration/e2e/coverage (path-aware)
│       ├── build.yml                # REUSABLE: build artifact (matrix, language-detect)
│       ├── codeql.yml               # SAST
│       ├── dependency-review.yml    # PR dependency diff scan
│       ├── dependency-audit.yml     # scheduled vuln audit
│       ├── secret-scan.yml          # gitleaks (current + history opt)
│       ├── license-check.yml        # license policy
│       ├── action-security.yml      # zizmor workflow scan
│       ├── scorecard.yml            # OpenSSF Scorecard (L3)
│       ├── ai-evaluation.yml        # regression + safety evals (advisory→blocking path)
│       ├── open-code-review.yml     # Alibaba OpenCodeReview (advisory)
│       ├── sbom.yml                 # SBOM (SPDX/CycloneDX) on build (L3)
│       ├── artifact-attestation.yml # build provenance/attestation (L3)
│       ├── release.yml              # tag → release with changelog + digest
│       ├── deploy-development.yml   # on merge to main → dev env + smoke
│       ├── deploy-staging.yml       # manual/protected → staging
│       ├── deploy-production.yml    # GitHub Environment approval + OIDC (HUMAN-GATED)
│       ├── smoke-test.yml           # post-deploy smoke
│       └── rollback.yml             # documented rollback workflow
│
├── docs/
│   ├── README.md                    # Doc index + navigation
│   ├── glossary.md
│   ├── assumptions.md
│   ├── constraints.md
│   ├── product/
│   │   ├── vision.md  personas.md  user-journeys.md  requirements.md
│   │   ├── non-functional-requirements.md  business-rules.md  success-metrics.md
│   ├── architecture/
│   │   ├── system-context.md  container-view.md  component-view.md  data-flow.md
│   │   ├── deployment-view.md  integration.md  data-model.md  technology-radar.md
│   ├── adr/
│   │   ├── README.md                          # ADR process + index
│   │   └── 0001-record-architecture-decisions.md
│   ├── api/
│   │   ├── api-guidelines.md  error-model.md  authentication.md  authorization.md
│   │   ├── versioning.md  openapi.yaml
│   ├── security/
│   │   ├── threat-model.md  data-classification.md  access-control.md  secrets-management.md
│   │   ├── secure-coding.md  dependency-policy.md  vulnerability-management.md
│   │   ├── incident-response.md  privacy-impact-assessment.md
│   ├── ai/
│   │   ├── ai-system-design.md  model-selection.md  model-card.md  prompt-management.md
│   │   ├── agent-design.md  tool-permissions.md  evaluation-strategy.md
│   │   ├── safety-and-guardrails.md  prompt-injection-defense.md  data-privacy.md
│   │   ├── model-routing.md  cost-management.md  human-oversight.md
│   ├── development/
│   │   ├── development-guide.md  local-setup.md  coding-standards.md  branching-strategy.md
│   │   ├── pull-request-process.md  testing-strategy.md
│   │   ├── definition-of-ready.md  definition-of-done.md
│   ├── operations/
│   │   ├── deployment-guide.md  environment-strategy.md  observability.md  monitoring.md
│   │   ├── alerting.md  backup-and-recovery.md  disaster-recovery.md
│   │   ├── capacity-management.md  rollback.md  runbook.md
│   ├── plans/
│   │   ├── README.md
│   │   ├── active/      (.gitkeep — feature designs live here)
│   │   ├── completed/   (.gitkeep)
│   │   └── technical-debt.md
│   └── templates/
│       ├── feature-design-template.md  implementation-plan-template.md
│       ├── adr-template.md  threat-model-template.md
│       ├── incident-report-template.md  postmortem-template.md
│       └── release-checklist-template.md
│
├── prompts/
│   ├── README.md          # Prompt registry process
│   ├── registry.yaml      # Schema example + fields
│   ├── system/  tasks/  evaluators/   (.gitkeep each)
│   ├── versions/          # versioned prompt snapshots
│   └── schemas/           # JSON schema for structured outputs
│
├── evals/
│   ├── README.md          # Eval framework strategy
│   ├── config/  datasets/  golden/  adversarial/  regression/
│   ├── safety/  performance/  cost/  reports/   (.gitkeep each)
│
├── src/                  (.gitkeep + README explaining where implementation lives)
├── tests/
│   ├── README.md          # Testing strategy — what goes where
│   ├── unit/  contract/  integration/  e2e/  security/  performance/  (.gitkeep each)
│
├── scripts/
│   ├── README.md
│   ├── ci-local.sh        # Local CI mirror (`make ci` backend)
│   ├── detect-stack.sh    # language/framework detection used by workflows
│   ├── setup-branch-protection.sh  # prints/runs gh CLI to configure protection
│   └── lib/               # shared helpers
│
├── infrastructure/        (.gitkeep + README; IaC scanned by iac-scan)
├── deployment/            (.gitkeep + README; manifests, Helm, etc.)
└── observability/         (.gitkeep + README; dashboards, alert rules, OTel config)
```

### Deliberately excluded
- **Empty-purpose folders** — every directory above has a concrete purpose or is a `.gitkeep` placeholder for an expected consumer file.
- **Concrete implementation** in `src/` — `.gitkeep` + README only; consumer chooses stack.
- **DAST, performance-test, canary, DR-validation workflows** — deferred (need concrete target).
- **Duplicate `/security/`, `/auth/`, `/migrations/` root folders** — folded into `docs/security/` + CODEOWNERS path patterns.

---

## 4. Documentation model

### Source-of-truth lifecycle
```
PRODUCT.md        → WHY   (vision, problem, users, metrics, scope)
      ↓
DESIGN.md         → WHAT  (approved system design: requirements, flows, model, ACs)
      ↓
ARCHITECTURE.md   → HOW   (executive view: components, boundaries, topology)
      ↓
docs/adr/         → WHY-THAT-CHOICE (traceable decisions + alternatives + consequences)
      ↓
AGENTS.md         → HOW-WE-WORK (canonical agent discipline, boundaries, DoR/DoD)
      ↓
docs/plans/active/ → CURRENT-FEATURE designs (moved to completed/ on merge)
```

- `DESIGN.md` is the approved baseline, not a scratchpad.
- Feature-specific designs go to `docs/plans/active/YYYY-MM-DD-<feature>-design.md` and move to `completed/` when shipped.
- ADRs use the MADR-style template (`docs/templates/adr-template.md`). Every ADR records security, data, operational implications, migration strategy, and rollback considerations.

### Document responsibilities (summary)
- **README.md** — overview, business objective, capabilities, architecture summary, stack, prerequisites, setup, common commands, testing, security reporting, deployment overview, documentation index, contribution process, current status.
- **PRODUCT.md** — vision, business problem, target users, stakeholders, user needs, primary journeys, business value, product principles, success metrics, scope, out-of-scope, roadmap, assumptions, constraints.
- **DESIGN.md** — problem statement, business objectives, scope, out-of-scope, stakeholders, personas, functional/non-functional requirements, business rules, system context, architecture overview, component boundaries, primary data flows, data model, API model, integration model, authentication, authorization, security model, AI subsystem, deployment model, observability, failure handling, testing strategy, constraints, risks, assumptions, unresolved decisions, acceptance criteria.
- **ARCHITECTURE.md** — system boundaries, major components, integration points, data stores, security zones, deployment topology, important technology choices, links to diagrams and ADRs.
- **AGENTS.md** — repository purpose, business context, documentation hierarchy, architecture summary, source-of-truth precedence, setup/test/build/security commands, directory boundaries, coding conventions, prohibited changes, database migration rules, API compatibility rules, security rules, secrets rules, AI model and prompt rules, testing requirements, documentation update requirements, production restrictions, DoR, DoD, Karpathy discipline, no-unrelated-refactoring rules, no-fabrication rules, diff-inspection requirement.
- **Tool adapters** (`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/project.mdc`, `.codex/instructions.md`) — short, point to `AGENTS.md`, do not duplicate it.

---

## 5. AI-agent operating model

Every AI coding agent follows this 9-step loop, encoded in `AGENTS.md`:

1. **Orient** — read AGENTS.md → PRODUCT.md → DESIGN.md → ARCHITECTURE.md → relevant ADRs → active plans → code → tests. Summarize understood scope before changing code.
2. **Inspect** — existing implementation, patterns, dependencies, tests, interfaces, security boundaries, recent changes, reusable components. Do not assume a component is absent before searching.
3. **Define success** — convert the request into measurable acceptance criteria, test cases, verification commands, expected artifacts.
4. **Plan** — files to create/modify, tests, documentation, risks, security considerations, verification steps, rollback implications.
5. **Implement incrementally** — smallest coherent change; never mix feature work with unrelated refactoring, dependency upgrades, style-only changes, architecture changes, or infrastructure modernization.
6. **Test continuously** — TDD for bugs: reproduce → failing test → fix → confirm pass → regression.
7. **Self-review the diff** — correctness, security, data leakage, accidental changes, missing tests, backward compatibility, unnecessary abstractions, dead code, misleading comments, overengineering, documentation gaps.
8. **Verify** — execute required commands; record actual results; never fabricate.
9. **Report** — what changed and why, design impact, tests performed, security checks performed, AI evaluations performed, remaining risks, deferred technical debt, deployment implications.

### Karpathy discipline — enforced as rules
- **Think before coding** — state material assumptions, identify ambiguity, do not silently choose between materially different interpretations, identify trade-offs, inspect existing implementation, search for existing components before creating new ones, identify the simplest viable solution, define verification, identify security/data boundaries, stop when requirements conflict with approved architecture or security policy.
- **Simplicity first** — minimum code to satisfy the AC. Before completion ask: fewer components? fewer abstractions? fewer files? less code without losing clarity? is any configurability speculative? would a senior engineer call this overengineered? A ~200-line implementation that can be ~50 lines gets simplified. Never sacrifice correctness, security, readability, required error handling, observability, or maintainability merely to reduce line count.
- **Surgical changes** — every changed line traceable to an approved requirement, design, AC, required test, cleanup caused by the current change, or required documentation. Modify only necessary files; follow existing naming/style; do not reformat unrelated files, rewrite adjacent modules, upgrade unrelated dependencies, rename unrelated symbols, remove pre-existing dead code unless requested, combine feature work with broad refactoring, or modify unrelated comments. Remove only newly orphaned imports/variables/functions/files/config/tests. Record (do not fix) unrelated technical debt in a separate issue.
- **Goal-driven execution** — translate every task into measurable outcomes; avoid vague verbs ("improve", "clean up", "make production ready").
- **Diff discipline** — before completion review the complete diff: every changed file/line necessary, no debug code, no temporary config, no unrelated formatting, no secret, no sensitive data, no unnecessary abstraction, no accidental breaking change, tests match behavior, documentation matches implementation.

### Prohibited anti-patterns (§29)
Coding before understanding · large uncontrolled generation · silent assumptions · speculative features · abstractions for one use case · configuration without a requirement · architecture changes without an ADR · unrelated code modification · broad refactoring inside a bug fix · hidden business logic in controllers/UI · direct production database manipulation · hardcoded credentials · secrets in logs · unrestricted AI agents · unvalidated LLM output · blind trust in AI-generated code · disabling tests to pass CI · lowering security thresholds without approval · meaningless coverage-only tests · rebuilding a different prod artifact · `latest` tags in production · silent breaking changes · auto-accepting AI review findings · marking assumptions as facts · fabricating command output / test results / security-scan results / deployment success.

### Production control (§2.6)
AI agents may generate code/tests/IaC/release notes, prepare deployment plans, deploy to **development**, deploy to **staging when permitted**, and **propose** production deployment. Agents must not deploy to production without: configured GitHub Environment approval, authorized human approval, required checks green, verified release artifact, documented rollback procedure.

---

## 6. Workflow matrix

`B` = blocking (required), `A` = advisory, `R` = reusable (`workflow_call`). Runtime: `S`<2m, `M`2–8m, `L`>8m.

| Workflow | Trigger | Purpose | Status | Runtime | Level |
|---|---|---|---|---|---|
| `pr-title.yml` | PR | Conventional Commits title lint | B | S | L1 |
| `validate-metadata.yml` | PR | Required frontmatter/doc checks | B | S | L1 |
| `docs-check.yml` | PR (md/**) | markdownlint + lychee link check + TBD/TODO scan | B | S | L1 |
| `ci-quality.yml` (R) | called | Stack-detect → format/lint/typecheck/unit | B | M | L1 |
| `ci-test.yml` (R) | called | integration/e2e/coverage (path-aware) | B | M–L | L2 |
| `build.yml` (R) | called | Build artifact (matrix, stack-detect) | B | M | L1 |
| `codeql.yml` | PR + cron | SAST (Autobuild + SARIF upload) | B | M | L2 |
| `dependency-review.yml` | PR (dep changed) | GH dependency diff scan | B | S | L1 |
| `dependency-audit.yml` | weekly cron | Scheduled vuln audit | A→B | S | L2 |
| `secret-scan.yml` | PR + cron | gitleaks (current; history opt via cron) | B | S | L1 |
| `license-check.yml` | PR (dep changed) | License policy | A→B | S | L2 |
| `action-security.yml` | PR (.github/**) | zizmor workflow scan | B | S | L2 |
| `scorecard.yml` | cron + push main | OpenSSF Scorecard | A | M | L3 |
| `ai-evaluation.yml` | PR (prompts/evals/src/**) | regression + safety + leakage eval (skeleton) | A→B | M | L2 |
| `open-code-review.yml` | PR | Alibaba OpenCodeReview (advisory) | A | M | L2 |
| `sbom.yml` | via build | SBOM SPDX/CycloneDX on build | B | S | L3 |
| `artifact-attestation.yml` | via build | Build provenance/attestation | A→B | S | L3 |
| `release.yml` | tag `v*` | Release + changelog + digest + SBOM | B | M | L2 |
| `deploy-development.yml` | push main | Deploy dev + smoke | B | M | L2 |
| `deploy-staging.yml` | manual (protected) | Deploy staging + verification | B | M–L | L2 |
| `deploy-production.yml` | manual (Environment approval + OIDC) | Promote same artifact (HUMAN-GATED) | B | L | L2 |
| `smoke-test.yml` | post-deploy | Smoke endpoint | B | S | L2 |
| `rollback.yml` | manual | Documented rollback | B | M | L2 |

**Path-aware execution rule (§30):** secret-scan, action-security, dependency-review (when dependencies change), and validate-metadata must not be bypassed by path filters.

**Workflow security (§15.6):** least-privilege permissions (default `contents: read`, write only at job level), third-party Actions pinned to immutable commit SHA with the release tag documented in a comment, no untrusted PR data injected into shell, no unsafe `pull_request_target`, environment secrets protected, OIDC over long-lived credentials, timeouts and concurrency controls defined, obsolete runs cancelled, secrets not exposed to forked PRs, downloaded artifacts validated, workflows scanned by zizmor.

---

## 7. Security control matrix

| Control | Threat addressed | Tool | Stage | Blocking rule | Exception process |
|---|---|---|---|---|---|
| Secret scanning | Committed credentials | gitleaks + GH Secret Scanning | PR + cron | Block on any finding | SECURITY.md; documented waiver |
| SAST | Code vulnerabilities (injection, path, etc.) | CodeQL (+ optional Semgrep) | PR | Critical/High block | Waiver + issue, bounded time |
| Dependency review | New dependency vulnerabilities | GH Dependency Review | PR (dep changed) | Critical block | Risk-acceptance record |
| Dependency audit | Accumulated dependency vulnerabilities | Dependabot + audit cron | weekly | Critical block | Patch or exception |
| License check | Incompatible licenses | license-policy script | PR (dep changed) | Denylist block | Legal approval |
| Action security | Workflow injection / action supply-chain | zizmor | PR (.github/**) | High block | Documented waiver |
| Container scan | Image vulnerabilities | Trivy/Grype | build (if containerized) | Critical block | Documentation + fix schedule |
| IaC scan | Cloud/infra misconfiguration | Checkov/Trivy config | PR (infrastructure/**) | High block | Waiver |
| SBOM | Supply-chain inventory | syft (SPDX/CycloneDX) | build | Required present | — |
| Attestation | Artifact authenticity | GH attestations | build/release | Required on prod | — |
| Scorecard | Repo security posture | OpenSSF Scorecard | cron | Advisory | — |
| AI prompt-injection | Injection via prompt/document | eval suite | PR (prompt/eval) | Advisory→B | Threshold review |

Secrets are never printed to workflow logs. Real model calls and secrets are not exposed to forked PRs.

---

## 8. Testing strategy

- **Unit (L1)** — domain rules, validation, transformations, calculations, authorization decisions, error handling, model-routing logic, prompt builders, response parsers, guardrails.
- **Contract (L2)** — FE↔BE, internal services, external services, event producers/consumers, repository contracts, AI-provider adapters, vector-store adapters, tool interfaces.
- **Integration (L2)** — database operations + migrations, queues, object storage, authentication, authorization, external adapters (test doubles), AI orchestration, cache behavior, transaction boundaries. Isolated, reproducible environments.
- **E2E (L2)** — critical user/business journeys: login, authorization, primary transaction, approval, error recovery, critical integrations, critical AI-assisted journeys. Not for edge cases.
- **AI tests (L2)** — separated: deterministic CI tests (stubs) · provider-adapter tests · real-model integration tests (controlled, spending limit, timeout, caching, secret protection, recorded results) · regression evaluations · safety evaluations · scheduled benchmark tests · cost evaluations.
- **Non-functional (L3, documented)** — performance, load, stress, resilience, failover, backup restoration, DR exercises, accessibility, browser compatibility, security tests.

**Initial thresholds (configurable by project criticality, §8):**
```
Overall unit-test coverage: minimum 80%
Critical domain-module coverage: minimum 90%
Changed-lines coverage: minimum 90%
Critical security findings: zero
High security findings: zero unless formally waived
Committed secrets: zero
Known critical dependency vulnerabilities: zero
Blocking lint errors: zero
Blocking type errors: zero
Failed required AI evaluations: zero
Undocumented breaking API changes: zero
```
No meaningless tests created only to raise coverage.

---

## 9. Deployment strategy

| Environment | Trigger | Artifact | Gate | Verification |
|---|---|---|---|---|
| local | dev | — | — | `make ci` |
| test | CI | ephemeral | PR checks | unit/contract/integration |
| development | push main | immutable, versioned | required checks green | smoke |
| staging | manual | same artifact with digest | protected, migration validation | smoke + integration + critical e2e + DAST (needs target) + AI eval |
| production | manual | exactly the staging artifact, digest verified, attestation verified | **GitHub Environment approval + human + OIDC** | smoke + monitor error/latency/business metrics + auto stop/rollback on threshold breach |

**Artifact promotion (§16):** staging → production uses the exact same artifact; no rebuild. No mutable `latest` tags in production.

**Rollback (§22.4):** application, configuration, feature-flag, infrastructure, database forward-recovery, model, prompt. Database rollback is not assumed safe. Production destructive migrations require explicit approval. AI agents do not modify production data directly.

---

## 10. Observability strategy

- **OpenTelemetry recommended.** `observability/` holds example config, dashboards, and alert rules.
- **Logs** — structured, with correlation IDs. Raw sensitive prompts/responses are not logged by default.
- **Metrics** — RED (rate/error/duration), dependency latency, database health, queue depth, memory/CPU, application version, deployment identifier, business transaction metrics.
- **Traces** — distributed.
- **AI telemetry (§7.8)** — request correlation ID, provider, model, prompt identifier + version, completion status, latency, token count, estimated cost, fallback usage, tool calls, guardrail events, evaluation score, user feedback.
- **Alerts** — actionable, severity-identified, linked to a runbook, anti-noise, identify affected service and environment.
- **Operational docs** — SLI/SLO, error budgets, backup schedule, restore procedure, DR objective, RTO, RPO, capacity planning, incident roles, escalation path, postmortem process. Restoration is tested periodically; a backup that has never been restored is not assumed valid.

---

## 11. Command interface

A Makefile provides the canonical §21 targets. Before a stack is wired in, each target **no-ops cleanly** with an explanatory message and exit 0 (template stays green out of the box); once a stack is detected by `scripts/detect-stack.sh`, the target dispatches to the real tool.

Required targets:
```
setup dev format format-check lint typecheck
test test-unit test-contract test-integration test-e2e test-coverage
eval eval-regression eval-safety
security secret-scan dependency-scan container-scan iac-scan
build run smoke-test docs-check ci
```
`make ci` reproduces the primary local quality gate as closely as practical. All targets fail with non-zero exit when validation fails (or when a configured tool reports failure).

---

## 12. Assumptions

1. **Stack-agnostic template** — no concrete formatter/linter/type-checker runs in CI until the consumer populates `src/`. Workflows use `scripts/detect-stack.sh` to no-op cleanly when no stack is detected.
2. **No real deployment target** in the template. `deploy-*` workflows are skeletons with commented steps; the consumer fills in OIDC + deploy action.
3. **AI-evaluation skeleton** does not call a real model; the consumer provides an endpoint via secret.
4. **CodeQL Autobuild** works for many common languages; the consumer adjusts for custom builds.
5. **Branch protection/Rulesets** cannot be applied from a template file; delivered via `scripts/setup-branch-protection.sh` (`gh` CLI) plus documentation.
6. **OpenCodeReview** requires a model endpoint + secret; shipped as an advisory workflow with safe placeholders.
7. **Scorecard** works best on public repositories; the workflow still runs but may be limited on private repos.
8. **MIT license** for the template; consumers may replace it.

---

## 13. Phased implementation plan

| Phase | Scope | Checkpoint |
|---|---|---|
| **1 — Repository governance** | `git init` + set remote (no push); root docs (README/PRODUCT/DESIGN/ARCHITECTURE/AGENTS.md + adapters), CONTRIBUTING/SECURITY/CODE_OF_CONDUCT/CHANGELOG/LICENSE, Makefile (clean no-op stubs), .editorconfig/.gitignore/.gitattributes/.env.example, scripts/ (ci-local.sh, detect-stack.sh, setup-branch-protection.sh), .github/ (CODEOWNERS, dependabot, labeler, release, pull_request_template, ISSUE_TEMPLATE/*, workflows pr-title/validate-metadata/docs-check/action-security), docs/ tree (all subdirs + templates + ADR-0001), prompts/ + evals/ + tests/ + src/ + infrastructure/ + deployment/ + observability/ (.gitkeep + READMEs) | **🔴 CHECKPOINT — owner reviews before Phase 2** |
| **2 — Code-quality baseline** | ci-quality.yml, ci-test.yml, build.yml (reusable, stack-detect), coverage gating | |
| **3 — Security baseline** | codeql, secret-scan, dependency-review, dependency-audit, license-check, scorecard | |
| **4 — AI-native capability** | ai-evaluation.yml (skeleton, advisory→blocking), open-code-review.yml (advisory), prompts/registry content + eval strategy docs | |
| **5 — Delivery pipeline** | sbom, artifact-attestation, release, deploy-development, deploy-staging, smoke-test | |
| **6 — Production readiness** | deploy-production (HUMAN-GATED + OIDC), rollback, observability docs/baseline | |

After all phases: full L1 + L2 (minus DAST/perf that need a target) + selected L3 (SBOM, attestation, Scorecard, OIDC, automated-rollback hooks).

### Build rules per phase
- Provide meaningful content; no generic placeholders.
- Avoid duplicate documentation; cross-reference between documents.
- Consistent terminology; concise, enforceable instructions.
- Executable commands; secure defaults.
- Pin versions where necessary.
- Every generated file has a clear purpose.
- Report every generated file and every command executed with actual results.
- Never fabricate completion.

---

## 14. Final acceptance criteria (template-level)

A consumer repo created from this template is acceptable only when:
- a new engineer can understand the project;
- an AI agent can understand its boundaries;
- the business objective is documented;
- architecture decisions are traceable;
- local validation runs with one command (`make ci`);
- pull requests receive deterministic checks;
- pull requests receive AI-assisted review;
- secrets are scanned;
- dependencies are maintained;
- source code is tested;
- AI behavior is evaluated;
- artifacts are traceable;
- staging and production use the same validated artifact;
- production requires controlled approval;
- production behavior is observable;
- failure recovery is documented;
- rollback procedures exist;
- sensitive data handling is documented;
- security findings have a defined blocking policy;
- every change is small, focused, and reviewable;
- AI agents do not make speculative or unrelated changes;
- no result is claimed without verification.
