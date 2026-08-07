# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Phase 5 delivery pipeline: `sbom.yml` (SPDX), `artifact-attestation.yml` (same-run build provenance), `release.yml` (on `v*` tags with artifact + SBOM + digests), and `deploy-development/staging/production.yml` + `smoke-test.yml` skeletons (workflow_dispatch, OIDC-documented, production human-gated via GitHub Environment).
- Phase 4 AI-native capability: `ai-evaluation.yml` (skeleton, advisory, secret-gated) and `open-code-review.yml` (Alibaba OCR, advisory, secret-gated) — both use `pull_request` (not `pull_request_target`) and skip cleanly without secrets. Plus `example-structured-extractor` prompt with JSON-schema output validation, `evals/README.md` threshold table, and cross-cutting docs.
- Phase 3 security baseline: `secret-scan.yml` (blocking), `dependency-review.yml` (critical/high blocking), `dependency-audit.yml` (advisory, weekly), `license-check.yml` (advisory), `codeql.yml` (graceful-degrade without GHAS), `scorecard.yml` (advisory). Plus `scripts/license-check.sh` (allowlist/denylist, advisory).
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

### Fixed
- Repaired the Phase 5 build-to-release chain: same-run provenance attestation,
  exact-commit CI artifact promotion without rebuild, fail-closed artifact
  validation, and delivery workflow contract tests. Deploy and smoke-test
  workflows remain skeletons.
- Activated public-repository security enforcement: CodeQL now scans pull requests and fails closed for execution/storage errors; Scorecard uses job-scoped OIDC and fails closed for publication/SARIF errors while findings remain advisory (TD-0006 closed).

### Known limitations (Phase 1)
- Phase-1 workflows pin all third-party GitHub Actions to immutable commit SHAs (TD-0001 closed — see `docs/plans/technical-debt.md`).
- Quality, security-scan, AI-evaluation, and deploy workflows arrive in Phases 2–6.
- Stack is not committed; `make` targets no-op until a consumer adopts one.
