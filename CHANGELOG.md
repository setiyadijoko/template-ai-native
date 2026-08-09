# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added proposed ADR-0007 defining the component-aware monorepo CI contract;
  implementation remains deferred pending a consumer pilot.
- Added an illustrative OpenAPI `/health` contract, global bearer-auth default,
  explicit consumer guidance, and a regression contract test.
- Added an SPDX license-header template and coding-standards guidance for
  consumer source files.
- Added explicit `single`/`monorepo`/`undecided` layout selection, credential-free
  project config validation, and fail-safe monorepo detection. Component-aware
  CI remains deferred until its execution and check-context contract is approved.
- Added a beginner-friendly getting-started guide with quick-start steps,
  required/optional control mapping, terminology, expected results, and
  troubleshooting; linked it from the root README and documentation index.
- Added the README-only `scripts/init-project.sh` initializer with explicit
  reconfiguration protection and contract tests; it updates only the marked
  consumer identity block and does not activate profile-aware controls.
- Added coherent example task/system prompts, referenced JSON schemas, golden fixtures, provider-neutral evaluation config and runner contract, version-pinning and branch-protection guidance, optional PostHog observability guidance, and stack-specific cache guidance.
- Documented optional Graphify codebase knowledge integration without changing
  the existing Code Review Graph or Alibaba review workflows.
- Coordinated the local graph review and optional Alibaba semantic review under a shared advisory PR-review policy and code/AI change scope.
- Added advisory local-first `code-review-graph` PR review with fork-safe report validation and sticky comment publication.
- Added the Phase 6 vendor-neutral production-readiness contract, read-only readiness workflow, fail-closed manual rollback skeleton, executable validation tests, and operational observability/recovery baseline. Validation is approval-neutral and always reports `production_ready=false`; platform activation remains tracked by TD-0011.
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

### Changed
- Synchronized README maturity and deployment status with the shipped Phase 1–6
  baseline; documented profile-driven adoption as deferred roadmap work pending
  a compatible CI check-context design.
- Archived the shipped Phase 6 design and implementation plan under `docs/plans/completed/` and synchronized the roadmap status through Phase 6.
- Documentation tree: `docs/` (product, architecture, ADRs, API, security, AI, development, operations, templates, plans) + ADR-0001.
- AI-native scaffolding: `prompts/registry.yaml` (2 examples), `prompts/schemas/`, `evals/` framework README + subdirs, `tests/`, and consumer-owned `src/`, `infrastructure/`, `deployment/`, `observability/` with READMEs.

### Fixed
- Fixed the graph-review report handoff by pinning the action version that exports `comment-file`; hardened the trusted `workflow_run` publisher to satisfy zizmor's permission and concurrency checks.
- Repaired the Phase 5 build-to-release chain: same-run provenance attestation,
  exact-commit CI artifact promotion without rebuild, fail-closed artifact
  validation, and delivery workflow contract tests. Deploy and smoke-test
  workflows remain skeletons.
- Activated public-repository security enforcement: CodeQL now scans pull requests and fails closed for execution/storage errors; Scorecard uses job-scoped OIDC and fails closed for publication/SARIF errors while findings remain advisory (TD-0006 closed).

### Known limitations (Phase 1)
- Phase-1 workflows pin all third-party GitHub Actions to immutable commit SHAs (TD-0001 closed — see `docs/plans/technical-debt.md`).
- Quality, security-scan, AI-evaluation, and deploy workflows arrive in Phases 2–6.
- Stack is not committed; `make` targets no-op until a consumer adopts one.
