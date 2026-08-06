# ARCHITECTURE.md

**Status:** Template baseline — adapt to your project.

An executive-readable overview of the `template-ai-native` architecture. For the approved design see [DESIGN.md](DESIGN.md); for decisions see [docs/adr/](docs/adr/).

## System boundaries

The template is a **documentation-and-governance layer** plus **stack-aware CI**. It has no runtime of its own. Its boundary is the repository: everything inside is governed by the docs, Makefile, scripts, and `.github/workflows/`; everything outside (consumer's chosen stack, provider, platform) is the consumer's responsibility.

## Major components

- **Governance docs** — `README.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`, and the `docs/` tree (source of truth + ADRs + templates).
- **Agent adapters** — `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/project.mdc`, `.codex/instructions.md` (all reference `AGENTS.md`).
- **Command interface** — `Makefile` + `scripts/` (`detect-stack.sh`, `ci-local.sh`, `setup-branch-protection.sh`).
- **CI/CD** — `.github/workflows/` (PR title, metadata, docs-check, action-security in Phase 1; quality/test/build/security/AI/deploy in later phases).
- **GitHub governance** — `CODEOWNERS`, `dependabot.yml`, `labeler.yml`, `release.yml`, PR + issue templates.
- **AI apparatus** — `prompts/` (registry), `evals/` (framework), `docs/ai/` (guidance) — scaffolding only.
- **Implementation surface** — `src/`, `tests/` (consumer-owned, empty).
- **Ops surface** — `infrastructure/`, `deployment/`, `observability/` (consumer-owned, with scanning hooks).

## Integration points

- **GitHub** — Actions, Environments (production approval), Security tab (SARIF), Dependabot, Issues/PRs.
- **AI providers** — consumer-wired via an adapter/gateway layer; never a direct SDK call from business logic.
- **Secret managers / OIDC** — for deployment credentials (consumer-wired).
- **Observability backend** — OpenTelemetry-exported (consumer-wired).

## Data stores

None in the template. Consumer-defined per project; see [docs/architecture/data-model.md](docs/architecture/data-model.md).

## Security zones

- **Trusted: repository governance** (docs, workflows, scripts) — modified via reviewed PR.
- **Sensitive paths** (CODEOWNERS): `.github/`, `infrastructure/`, `deployment/`, `prompts/`, `evals/`, security/auth source.
- **Production zone** — GitHub `production` Environment with required human approval + OIDC; AI agents cannot deploy without it.
- **Untrusted inputs** — PR data is never injected into shell; forked PRs do not receive secrets.

## Deployment topology

No topology in the template. Consumer defines; see [docs/architecture/deployment-view.md](docs/architecture/deployment-view.md). The template's deployment *process* (dev → staging → production, same artifact promoted) is in [docs/operations/deployment-guide.md](docs/operations/deployment-guide.md).

## Important technology choices

- **Markdown** for all docs/templates.
- **GitHub Actions** (YAML) for CI/CD — least-privilege, SHA-pinned third-party Actions.
- **POSIX shell + Make** for the command interface and stack detection.
- **OpenAPI 3.0** skeleton in `docs/api/openapi.yaml`.
- **OpenTelemetry** recommended for observability.
- No language/framework/database committed.

Rationale for each choice is captured in ADRs as the project adopts specifics. See [docs/adr/](docs/adr/) and [docs/architecture/technology-radar.md](docs/architecture/technology-radar.md).

## Diagrams and ADRs

- Architecture views: [docs/architecture/](docs/architecture/) (system context, container, component, data flow, deployment, integration, data model, technology radar).
- Decisions: [docs/adr/](docs/adr/) — start with [ADR-0001](docs/adr/0001-record-architecture-decisions.md).

## C4 system context (textual)

```text
[ Consumer Engineer ]  -->  [ template-ai-native repo ]
[ AI Coding Agent   ]  -->   (docs + AGENTS.md + CI)
                                 |
                                 | (consumer adopts a stack in src/)
                                 v
                          [ Consumer Application ]
                                 |
            +--------------------+--------------------+
            |                    |                    |
       [ AI Provider ]    [ Secret Manager ]   [ Deploy Platform ]
       (via adapter)      (OIDC / secrets)     (dev/staging/prod)
```

The template governs the *repo*; once a stack is adopted, the consumer application interacts with providers, secret managers, and platforms per the consumer's design — all under the governance, security, and human-gated production controls the template establishes.
