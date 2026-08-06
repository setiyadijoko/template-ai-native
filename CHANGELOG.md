# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Phase 2 code-quality baseline: `ci.yml` dispatcher + `ci-quality` / `ci-test` / `build` reusable workflows that auto-detect the consumer's stack (python/node/go/java/dotnet) and run format-check, lint, typecheck, unit/integration/e2e tests, an 80% coverage gate, and build. All jobs skip cleanly on the empty template (stack unknown).
- `scripts/stack-tools.sh` — single-source-of-truth per-stack tool mapper.
- `scripts/test/test-stack-detection.sh` — shell tests for the detection/mapper scripts.
- `make test-scripts` target; Makefile + ci-local now execute real tools when a stack is present.
- Repository foundation config: `.gitignore`, `.gitattributes`, `.editorconfig`, `.env.example`, MIT `LICENSE`, `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`.
- Canonical `AGENTS.md` (24 sections, Karpathy discipline, DoR/DoD, agent workflow) + tool adapters (`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/project.mdc`, `.codex/instructions.md`).
- Core baselines: `README.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`.
- Command interface: `Makefile` (clean no-op stubs until a stack is wired) + `scripts/{detect-stack,ci-local,setup-branch-protection}.sh`.
- GitHub governance: `CODEOWNERS`, `dependabot.yml`, `labeler.yml`, `release.yml`, pull-request template, issue templates.
- Phase-1 CI workflows: `pr-title`, `validate-metadata`, `docs-check`, `action-security` (least-privilege, pinned Actions) + `.markdownlint.jsonc`.
- Documentation tree: `docs/` (product, architecture, ADRs, API, security, AI, development, operations, templates, plans) + ADR-0001.
- AI-native scaffolding: `prompts/registry.yaml` (2 examples), `prompts/schemas/`, `evals/` framework README + subdirs, `tests/`, and consumer-owned `src/`, `infrastructure/`, `deployment/`, `observability/` with READMEs.

### Known limitations (Phase 1)
- Phase-1 workflows pin all third-party GitHub Actions to immutable commit SHAs (TD-0001 closed — see `docs/plans/technical-debt.md`).
- Quality, security-scan, AI-evaluation, and deploy workflows arrive in Phases 2–6.
- Stack is not committed; `make` targets no-op until a consumer adopts one.

