# Phase 1 — Repository Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the full Phase 1 governance layer of the stack-agnostic `template-ai-native` GitHub template — root docs, canonical agent instructions + adapters, product/architecture docs, Makefile + scripts, `.github` governance + Phase-1 workflows, the `docs/` tree, and the AI/test/infra scaffolding directories — all committed and locally verified, with a checkpoint for owner review before Phase 2.

**Architecture:** A documentation-and-governance template (no committed language/framework). CI adapts via `scripts/detect-stack.sh`. Phase 1 ships only the governance + documentation-validation workflows (`pr-title`, `validate-metadata`, `docs-check`, `action-security`); code-quality, security, AI, and delivery workflows come in Phases 2–6. All Make targets no-op cleanly until a stack is wired.

**Tech Stack:** Markdown (docs, templates), GitHub Actions YAML, POSIX shell (scripts, Makefile). Verification uses `python3` (PyYAML-style safe load via stdlib `yaml` if available, else a structural check), and best-effort `markdownlint-cli2` / `actionlint` when installed.

**Reference spec:** `docs/superpowers/specs/2026-08-05-template-ai-native-design.md` (authoritative for content requirements; this plan references its section numbers).

## Global Constraints

- **Stack-agnostic:** no language/framework committed in `src/`; `.gitkeep` + README only.
- **No unused infrastructure:** every file/directory has a concrete purpose; no empty-purpose folders.
- **Secure defaults:** `.env.example` contains names + descriptions + safe placeholders ONLY, never real credentials.
- **Workflow security (spec §15.6):** `permissions: contents: read` default; write only at job level; third-party Actions pinned to immutable commit SHA with the release tag documented in a comment; no `pull_request_target`; timeouts + concurrency defined.
- **Make targets no-op cleanly** (exit 0 with a message) when no stack is detected, until the consumer wires one.
- **License:** MIT.
- **Commit style:** Conventional Commits (`docs:`, `chore:`, `ci:`, `feat:`).
- **No fabrication:** every verification step records actual command output.
- Git repo already initialized, remote `origin` set, spec committed (`c0805b6`). Do **not** push.

## File Structure

Grouped by cohesion (files that change together live together). Each task produces one independently-verifiable, committable unit.

| Task | Cohesion group | Key files |
|---|---|---|
| 1 | Repo foundation config | `.gitignore`, `.gitattributes`, `.editorconfig`, `.env.example`, `LICENSE`, `CHANGELOG.md`, `CODE_OF_CONDUCT.md` |
| 2 | Canonical agent instructions | `AGENTS.md` + `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/project.mdc`, `.codex/instructions.md` |
| 3 | Core product/architecture docs | `README.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md` |
| 4 | Makefile + scripts | `Makefile`, `scripts/{README.md,ci-local.sh,detect-stack.sh,setup-branch-protection.sh}`, `scripts/lib/.gitkeep` |
| 5 | `.github` governance (non-workflow) | `CODEOWNERS`, `dependabot.yml`, `labeler.yml`, `release.yml`, `pull_request_template.md`, `ISSUE_TEMPLATE/*.yml` |
| 6 | Phase-1 workflows | `.github/workflows/{pr-title,validate-metadata,docs-check,action-security}.yml` |
| 7 | `docs/` tree A: index + product + architecture + adr | `docs/README.md`, `docs/{glossary,assumptions,constraints}.md`, `docs/product/*`, `docs/architecture/*`, `docs/adr/*` |
| 8 | `docs/` tree B: api + security + ai + development + operations + plans + templates | `docs/{api,security,ai,development,operations,templates}/*`, `docs/plans/*` |
| 9 | AI/test/infra scaffolding | `prompts/*`, `evals/*`, `tests/*`, `src/*`, `infrastructure/*`, `deployment/*`, `observability/*` |
| 10 | Phase-1 verification | run `make ci` / `docs-check`, validate all YAML, final diff review |

---

## Task 1: Repo foundation config

**Files:**
- Create: `.gitignore`
- Create: `.gitattributes`
- Create: `.editorconfig`
- Create: `.env.example`
- Create: `LICENSE`
- Create: `CHANGELOG.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`

**Content requirements:**
- `.gitignore` — common OS/IDE/language-agnostic entries: `.DS_Store`, `Thumbs.db`, `*.swp`, `.idea/`, `.vscode/` (but keep `!.vscode/extensions.json` style allow-lists minimal), `node_modules/`, `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `build/`, `*.log`, `.env`, `.env.*` (but NOT `.env.example`), `.coverage`, `.pytest_cache/`, `.mypy_cache/`, `.terraform/`, `*.tfstate*`. Include a comment header: "Environment files are ignored except `.env.example`."
- `.gitattributes` — `* text=auto eol=lf`; `*.bat text eol=crlf`; `*.sh text eol=lf`; `*.png binary`; `*.jpg binary`; `*.pdf binary`; export-ignore for `.github` is NOT set.
- `.editorconfig` — root=true; UTF-8; indent_style per extension (2-space for `*.md`,`*.yml`,`*.yaml`,`*.json`, 4-space for `*.py`); `max_line_length = off` for `*.md`; trailing newline inserted.
- `.env.example` — grouped sections (`# --- Application ---`, `# --- AI Provider ---`, `# --- Observability ---`, `# --- Deployment ---`), each variable with an inline comment description and a safe placeholder. NEVER real credentials. Include at least: `APP_ENV=local`, `LOG_LEVEL=info`, `AI_PROVIDER=` (empty), `AI_MODEL=`, `AI_API_KEY=` (placeholder `<set-in-secret-manager>`), `OTEL_EXPORTER_OTLP_ENDPOINT=`.
- `LICENSE` — MIT License text, copyright `Copyright (c) 2026 setiyadijoko`, full MIT permission notice.
- `CHANGELOG.md` — Keep a Changelog 1.1.0 header + `## [Unreleased]` with an `### Added` entry: "Initial template governance scaffold (Phase 1)."
- `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1 full text.
- `CONTRIBUTING.md` — spec §10.3/§10.4: how to contribute (open issue first for substantial changes), branching strategy (trunk-based, PR to `main`), Conventional Commits type list, PR requirements (reference the PR template), merge strategy (squash merge default + conventional PR title), code-review expectations, AI-agent contributor expectations (must follow `AGENTS.md`).
- `SECURITY.md` — supported versions table, how to **privately** report a vulnerability (email/`gh security advisory`), response SLA (acknowledge ≤48h, initial assessment ≤5 business days), scope, and a note that public issues must NOT be used for security reports. Include a "no real secrets in issues/PRs" line.

- [ ] **Step 1:** Create `.gitignore`, `.gitattributes`, `.editorconfig` with the content above.
- [ ] **Step 2:** Create `.env.example` with named vars + descriptions + safe placeholders only (verify NO real secret; grep `KEY=` lines point to placeholders).
- [ ] **Step 3:** Create `LICENSE` (MIT), `CHANGELOG.md` (Keep a Changelog), `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `CONTRIBUTING.md`, `SECURITY.md`.
- [ ] **Step 4: Verify** — Run: `grep -nE '(sk-|ghp_|AKIA|password\s*=)' .env.example || echo "OK: no real-secret patterns"`. Expected: `OK: no real-secret patterns`. Also run `python3 -c "print(open('LICENSE').read()[:20])"` → prints `MIT License\n\nCopyright`.
- [ ] **Step 5: Commit** — `git add .gitignore .gitattributes .editorconfig .env.example LICENSE CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md SECURITY.md && git commit -m "chore: add repo foundation config (gitignore, editorconfig, env example, MIT license, changelog, CoC, contributing, security)"`

---

## Task 2: Canonical agent instructions + adapters

**Files:**
- Create: `AGENTS.md` (CANONICAL — all other adapters reference this)
- Create: `CLAUDE.md`
- Create: `.github/copilot-instructions.md`
- Create: `.cursor/rules/project.mdc`
- Create: `.codex/instructions.md`

**Content requirements:**

`AGENTS.md` must contain every section listed in spec §6.5, in this order, each with concrete enforceable content (not placeholders):
1. Repository purpose (one paragraph — this is the `template-ai-native` stack-agnostic governance template).
2. Business context (brief — target project types from spec §1).
3. Documentation hierarchy (the source-of-truth ladder from spec §1, verbatim precedence list).
4. Architecture summary (pointer to ARCHITECTURE.md + DESIGN.md; note `src/` is consumer-owned).
5. Source-of-truth precedence (the 10-level hierarchy from spec §1).
6. Setup commands (`make setup`), test (`make test`), build (`make build`), security (`make security`) — note these no-op until a stack is wired.
7. Directory boundaries (table: dir → owner → can-agent-modify).
8. Coding conventions (follow existing; no unrelated reformatting; conventional commits).
9. Prohibited changes (the anti-pattern list from spec §29, condensed to a bulleted "Do not" list).
10. Database migration rules (spec §19: version-controlled, peer-reviewed, expand-and-contract, no AI direct prod data).
11. API compatibility rules (spec §6.3 API model; no undocumented breaking changes; versioning).
12. Security rules (spec §15 condensed: least privilege, no secrets in logs, validate AI output before trust).
13. Secrets rules (never commit; `.env.example` only; secret manager in prod).
14. AI model and prompt rules (spec §7.1 model abstraction via adapter layer, no direct SDK calls; §7.2 prompt registry; §7.3 structured output validation).
15. Testing requirements (spec §9 condensed + thresholds from spec §8).
16. Documentation update requirements (keep DESIGN.md/ADR/ops docs in sync with changes).
17. Production restrictions (spec §2.6 verbatim gate: no prod deploy without Environment approval + human + checks + verified artifact + rollback).
18. Definition of Ready (spec §26, condensed bullet list).
19. Definition of Done (spec §27, condensed bullet list).
20. Karpathy-inspired coding discipline (the 5 principles from spec §3, each 2–4 lines, enforceable).
21. Instructions to avoid unrelated refactoring (spec §3.3 condensed).
22. Instructions never to fabricate results (spec §2.5 + §29).
23. Instructions to inspect the complete diff before completion (spec §3.5).
24. The 9-step agent workflow (spec §5 / spec §28).

The four adapters each contain **only** the short adapter block from spec §6.6 (the "Read and follow `/AGENTS.md`..." block) plus a one-line tool-specific note (e.g. Cursor: "This file is loaded automatically by Cursor."). They must NOT duplicate `AGENTS.md`.

`.cursor/rules/project.mdc` frontmatter:
```yaml
---
description: Project-wide rules for AI coding agents on template-ai-native
globs:
  - "**/*"
alwaysApply: true
---
```

- [ ] **Step 1:** Write `AGENTS.md` with all 24 sections above, concrete content, referencing spec section numbers where the full list lives in the spec.
- [ ] **Step 2:** Write `CLAUDE.md`, `.github/copilot-instructions.md`, `.codex/instructions.md` (identical short adapter block + one-line tool note each).
- [ ] **Step 3:** Write `.cursor/rules/project.mdc` (frontmatter above + adapter block body).
- [ ] **Step 4: Verify** — Run: `grep -c "^##" AGENTS.md` → expect ≥24. Run: `wc -l CLAUDE.md .github/copilot-instructions.md .codex/instructions.md` → each ≤ 30 lines (adapters are short). Run: `grep -L "AGENTS.md" CLAUDE.md .github/copilot-instructions.md .codex/instructions.md .cursor/rules/project.mdc || echo "OK: all adapters reference AGENTS.md"`.
- [ ] **Step 5: Commit** — `git add AGENTS.md CLAUDE.md .github/copilot-instructions.md .cursor/rules/project.mdc .codex/instructions.md && git commit -m "docs: add canonical AGENTS.md and tool-specific adapters"`

---

## Task 3: Core product/architecture docs

**Files:**
- Create: `README.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`

**Content requirements (sections from spec §6.1–§6.4):**
- `README.md` — sections: Project Overview, Business Objective, Major Capabilities, Architecture Summary, Technology Stack, Prerequisites, Local Setup, Common Commands (the `make` table), Testing, Security Reporting, Deployment Overview, Documentation Index (links into `docs/`), Contribution Process, Current Project Status. Include a badges row (CI, License MIT) as placeholder markdown that renders gracefully.
- `PRODUCT.md` — spec §6.2 full section list: vision, business problem, target users, stakeholder groups, user needs, primary journeys, business value, product principles, success metrics, scope, out-of-scope, roadmap, assumptions, constraints.
- `DESIGN.md` — spec §6.3 full section list (problem statement → acceptance criteria). Add an explicit note: "Feature-specific designs belong in `docs/plans/active/`; this file is the approved baseline."
- `ARCHITECTURE.md` — spec §6.4: system boundaries, major components, integration points, data stores, security zones, deployment topology, technology choices, links to ADRs/diagrams. Include a C4-style system-context description in text (no image dependency).

Each doc starts with a status line (`**Status:** Template baseline — adapt to your project.`) so consumers know to customize.

- [ ] **Step 1:** Write `README.md` with all sections + documentation index links.
- [ ] **Step 2:** Write `PRODUCT.md` (spec §6.2 sections).
- [ ] **Step 3:** Write `DESIGN.md` (spec §6.3 sections + the feature-design-location note).
- [ ] **Step 4:** Write `ARCHITECTURE.md` (spec §6.4 sections + text system-context).
- [ ] **Step 5: Verify** — Run: `grep -c "^##" README.md` (≥14), `grep -c "^##" PRODUCT.md` (≥14), `grep -c "^##" DESIGN.md` (≥20), `grep -c "^##" ARCHITECTURE.md` (≥8). Check internal links render: `grep -n "docs/" README.md | head`.
- [ ] **Step 6: Commit** — `git add README.md PRODUCT.md DESIGN.md ARCHITECTURE.md && git commit -m "docs: add README, PRODUCT, DESIGN, ARCHITECTURE baselines"`

---

## Task 4: Makefile + scripts

**Files:**
- Create: `Makefile`
- Create: `scripts/README.md`
- Create: `scripts/detect-stack.sh`
- Create: `scripts/ci-local.sh`
- Create: `scripts/setup-branch-protection.sh`
- Create: `scripts/lib/.gitkeep`

**Content requirements:**

`scripts/detect-stack.sh` (real content — this is code):
```sh
#!/usr/bin/env sh
# Detects the primary stack in the repo root. Prints a single token to stdout
# (python | node | go | java | dotnet | unknown). Used by Makefile + CI to
# decide which tooling to run. Exit 0 always.
set -eu

if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ] || [ -f "Pipfile" ]; then
  echo "python"; exit 0
fi
if [ -f "package.json" ]; then
  echo "node"; exit 0
fi
if [ -f "go.mod" ]; then
  echo "go"; exit 0
fi
if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  echo "java"; exit 0
fi
if [ -f "*.csproj" ] || [ -f "*.sln" ]; then
  echo "dotnet"; exit 0
fi
echo "unknown"
```
Make executable (`chmod +x`).

`scripts/ci-local.sh` (real content):
```sh
#!/usr/bin/env sh
# Local mirror of the primary CI quality gate. Runs whatever is available.
# Exit non-zero only when a configured tool reports failure. Missing tools
# are reported but do not fail the run (template is stack-agnostic).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
run() { # run <label> <command...>
  label="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf ":: %s ::\n" "$label"; "$@" || fail=1
  else
    printf "-- %s skipped (tool '%s' not installed)\n" "$label" "$1"
  fi
}

run "markdownlint" markdownlint-cli2 "**/*.md"
run "link-check"   lychee --no-progress --exclude-loopback README.md docs
run "yaml-lint"    yamllint -d "{extends: default, rules: {line-length: disable}}" .github 2>/dev/null || true
run "actionlint"   actionlint

echo
if [ "$fail" -eq 0 ]; then echo "ci-local: OK (best-effort)"; else echo "ci-local: FAILURES"; fi
exit "$fail"
```
Make executable.

`scripts/setup-branch-protection.sh` (real content — prints `gh` commands; executes only with `--apply`):
```sh
#!/usr/bin/env sh
# Prints recommended gh CLI commands to configure branch protection + Rulesets
# for a consumer repo created from this template. Use --apply to run them.
# Requires: gh CLI authenticated, repo created on GitHub.
set -eu
BRANCH="${1:-main}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "<owner>/<repo>")"

require_approvals="gh api -X PUT repos/${REPO}/branches/${BRANCH}/protection \
  -H 'Accept: application/vnd.github+json' \
  -f required_status_checks[strict]=true \
  -f required_status_checks[contexts][]='pr-title' \
  -f required_status_checks[contexts][]='validate-metadata' \
  -f required_status_checks[contexts][]='docs-check' \
  -f required_status_checks[contexts][]='action-security' \
  -f enforce_admins=true \
  -f required_pull_request_reviews[required_approving_review_count]=1 \
  -f required_pull_request_reviews[dismiss_stale_reviews]=true \
  -f restrictions= \
  -f required_linear_history=true \
  -f allow_force_pushes=false \
  -f allow_deletions=false"

echo "# Recommended branch protection for ${REPO} @ ${BRANCH}"
echo "${require_approvals}"
echo
echo "# Create a 'production' GitHub Environment requiring manual approval:"
echo "gh api -X PUT repos/${REPO}/environments/production"
echo "  # then in the UI: Settings > Environments > production > Required reviewers"

if [ "${2:-}" = "--apply" ]; then
  echo "Applying..."; sh -c "${require_approvals}" || { echo "apply failed"; exit 1; }
else
  echo "(dry-run; pass --apply as 2nd arg to execute)"
fi
```
Make executable.

`scripts/README.md` — describes each script + when to run it.

`Makefile` — every §21 target as a clean no-op stub. Each target calls `scripts/detect-stack.sh`; if `unknown`, it prints `[skip] no stack detected — wire src/ to enable <target>` and exits 0. Real content:
```makefile
SHELL := /bin/sh
STACK := $(shell sh scripts/detect-stack.sh)

.PHONY: setup dev format format-check lint typecheck \
        test test-unit test-contract test-integration test-e2e test-coverage \
        eval eval-regression eval-safety \
        security secret-scan dependency-scan container-scan iac-scan \
        build run smoke-test docs-check ci

# Helper: no-op cleanly when no stack is wired.
define noop
	@sh -c 'if [ "$(STACK)" = "unknown" ]; then echo "[skip] no stack detected — wire src/ to enable $@"; else $(1); fi'
endef

setup:           ; $(call noop, echo 'configure setup for $(STACK)')
dev:             ; $(call noop, echo 'configure dev server for $(STACK)')
format:          ; $(call noop, echo 'configure formatter for $(STACK)')
format-check:    ; $(call noop, echo 'configure format-check for $(STACK)')
lint:            ; $(call noop, echo 'configure linter for $(STACK)')
typecheck:       ; $(call noop, echo 'configure typecheck for $(STACK)')
test:            ; $(call noop, echo 'configure test for $(STACK)')
test-unit:       ; $(call noop, echo 'configure test-unit for $(STACK)')
test-contract:   ; $(call noop, echo 'configure test-contract for $(STACK)')
test-integration:; $(call noop, echo 'configure test-integration for $(STACK)')
test-e2e:        ; $(call noop, echo 'configure test-e2e for $(STACK)')
test-coverage:   ; $(call noop, echo 'configure test-coverage for $(STACK)')
eval:            ; $(call noop, echo 'configure AI eval for $(STACK)')
eval-regression: ; $(call noop, echo 'configure eval-regression')
eval-safety:     ; $(call noop, echo 'configure eval-safety')
secret-scan:     ; @sh scripts/ci-local.sh >/dev/null 2>&1 || true; echo '[stub] gitleaks runs in CI'
dependency-scan: ; $(call noop, echo '[stub] dependency-review runs in CI')
container-scan:  ; $(call noop, echo '[stub] trivy runs in CI when containers exist')
iac-scan:        ; $(call noop, echo '[stub] checkov runs in CI when IaC exists')
security: secret-scan dependency-scan container-scan iac-scan
build:           ; $(call noop, echo 'configure build for $(STACK)')
run:             ; $(call noop, echo 'configure run for $(STACK)')
smoke-test:      ; $(call noop, echo 'configure smoke-test')
docs-check:      ; @sh scripts/ci-local.sh
ci: format-check lint docs-check
	@echo "[ci] local gate (best-effort) complete"
```
Note: `docs-check` and `ci` run regardless of stack (they validate the template itself).

- [ ] **Step 1:** Create `scripts/lib/.gitkeep`, `scripts/README.md`.
- [ ] **Step 2:** Create `scripts/detect-stack.sh`, `scripts/ci-local.sh`, `scripts/setup-branch-protection.sh`; `chmod +x` all three.
- [ ] **Step 3:** Create `Makefile`.
- [ ] **Step 4: Verify** — Run: `make ci` → exits 0, prints `[ci] local gate (best-effort) complete`. Run: `make docs-check` → exits 0. Run: `sh scripts/detect-stack.sh` → prints `unknown`. Run: `make test` → prints `[skip] no stack detected...` and exits 0.
- [ ] **Step 5: Commit** — `git add Makefile scripts && git commit -m "feat: add Makefile command interface and stack-detection scripts"`

---

## Task 5: `.github` governance (non-workflow)

**Files:**
- Create: `.github/CODEOWNERS`
- Create: `.github/dependabot.yml`
- Create: `.github/labeler.yml`
- Create: `.github/release.yml`
- Create: `.github/pull_request_template.md`
- Create: `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml`, `security-config.yml`, `technical-debt.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml` (to enable blank issues or route them)

**Content requirements:**
- `CODEOWNERS` — spec §10.1 sensitive paths (`/.github/ @owner`, `/infrastructure/ @owner`, `/deployment/ @owner`, `/prompts/ @owner`, `/evals/ @owner`, plus `* @owner` default). Use `@setiyadijoko` as default owner with a comment to replace.
- `dependabot.yml` — spec §17: `github-actions` (weekly) + `docker` (weekly) ecosystems; grouped patch+minor; open-pull-requests-limit 5; labels `dependencies`; commit-message prefix `chore(deps):`.
- `labeler.yml` — path-based labels: `documentation` for `*.md`/`docs/**`, `github-actions` for `.github/workflows/**`, `ai` for `prompts/**`/`evals/**`, `infrastructure` for `infrastructure/**`/`deployment/**`, `dependencies` for lockfiles.
- `release.yml` — release-drafter config: name template `v$RESOLVED_VERSION`, categories mapping conventional-commit types to sections (feat→🚀 Features, fix→🐛 Fixes, docs→📖 Documentation, etc.), template placeholders.
- `pull_request_template.md` — spec §10.2 full checklist: business purpose, linked requirement, scope, out-of-scope, design reference, architecture impact, security impact, data & privacy impact, AI behavior impact, testing performed, evaluation results, deployment impact, migration requirements, rollback plan, screenshots/evidence, documentation changes, risk level, no-secret confirmation + the AI discipline checklist block (verbatim from spec §10.2).
- `ISSUE_TEMPLATE/bug.yml`, `feature.yml`, `security-config.yml`, `technical-debt.yml` — GitHub issue forms (`name`, `description`, `title`, `labels`, `body` with required markdown + textarea fields). `security-config.yml` points to `SECURITY.md` for private reporting.
- `ISSUE_TEMPLATE/config.yml` — `blank_issues_enabled: true` + a contact link to SECURITY.md.

- [ ] **Step 1:** Create `CODEOWNERS`, `dependabot.yml`, `labeler.yml`, `release.yml`.
- [ ] **Step 2:** Create `pull_request_template.md` with the full §10.2 checklist + AI discipline block.
- [ ] **Step 3:** Create the 4 issue forms + `config.yml`.
- [ ] **Step 4: Verify** — Run YAML validity: `python3 - <<'PY'\nimport yaml, glob\nfor f in glob.glob('.github/**/*.yml', recursive=True):\n    list(yaml.safe_load_all(open(f))); print('OK', f)\nPY`. Expected: each `.github/**/*.yml` prints `OK`. Run `grep -c "AI discipline" .github/pull_request_template.md` → ≥1.
- [ ] **Step 5: Commit** — `git add .github/CODEOWNERS .github/dependabot.yml .github/labeler.yml .github/release.yml .github/pull_request_template.md .github/ISSUE_TEMPLATE && git commit -m "chore: add GitHub governance (CODEOWNERS, dependabot, labeler, release, PR + issue templates)"`

---

## Task 6: Phase-1 workflows

**Files:**
- Create: `.github/workflows/pr-title.yml`
- Create: `.github/workflows/validate-metadata.yml`
- Create: `.github/workflows/docs-check.yml`
- Create: `.github/workflows/action-security.yml`

**Content requirements (real YAML; all must obey Global Constraints §15.6):**

Common header for each:
```yaml
name: <Name>
on:
  pull_request:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

`pr-title.yml` — uses `amannn/action-semantic-pull-request@<sha>` (pin to a commit SHA; comment the release tag). Job `pr-title` on `ubuntu-latest`, timeout 5m, validates Conventional Commit types from spec §10.3 (`feat,fix,docs,test,refactor,perf,build,ci,chore,security,revert`). Require scope optional, subject required.

`validate-metadata.yml` — checks required root docs exist (`README.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, `AGENTS.md`) and that changed `.md` files under `docs/` have a top-level `# ` title. Steps: checkout `actions/checkout@<sha>`; a `python` step that lists missing files and fails if any.

`docs-check.yml` — `nvuillam/markdownlint-cli2-action@<sha>` (config file `.markdownlint.jsonc` created in this task) on `**/*.md` excluding `CHANGELOG.md`/`LICENSE`; `lychee` link check (`lycheeverse/lychee-action@<sha>`) on `README.md` + `docs/`; a `grep` step failing if `TBD`/`TODO`/`FIXME` appear in `docs/` outside `docs/plans/`. Also create `.markdownlint.jsonc` config (enable default config; `MD013: false` line-length; `MD024: { siblings_only: true }`; ignore `node_modules`, `CHANGELOG.md`).

`action-security.yml` — runs `zizmor` (`woodruffw/zizmor-action@<sha>` or `rhysd/actionlint@<sha>`) on `.github/workflows/**`. Upload SARIF to GH security tab when on a non-fork.

All third-party Actions pinned to a 40-char SHA with the tag in a trailing comment, e.g.:
```yaml
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```
For SHAs you cannot fetch live, use the documented stable tag and add a `# TODO(pinning): replace tag with commit SHA before production use` comment — record this in `docs/plans/technical-debt.md` (Task 8). (Phase 1 pinning debt is acceptable because the template ships before consumers add secrets.)

- [ ] **Step 1:** Create `.markdownlint.jsonc`.
- [ ] **Step 2:** Create `pr-title.yml`, `validate-metadata.yml`, `docs-check.yml`, `action-security.yml` with the common header + pinned Actions + timeouts.
- [ ] **Step 3: Verify** — Run: `python3 - <<'PY'\nimport yaml, glob\nfor f in sorted(glob.glob('.github/workflows/*.yml')):\n    list(yaml.safe_load_all(open(f))); print('OK', f)\nPY`. Each prints `OK`. Run: `grep -L "permissions:" .github/workflows/*.yml` → empty (all have permissions). Run: `grep -c "on:" .github/workflows/pr-title.yml` → 1.
- [ ] **Step 4: Commit** — `git add .markdownlint.jsonc .github/workflows/pr-title.yml .github/workflows/validate-metadata.yml .github/workflows/docs-check.yml .github/workflows/action-security.yml && git commit -m "ci: add Phase-1 governance workflows (pr-title, validate-metadata, docs-check, action-security)"`

---

## Task 7: `docs/` tree A — index + product + architecture + adr

**Files:**
- Create: `docs/README.md`
- Create: `docs/glossary.md`, `docs/assumptions.md`, `docs/constraints.md`
- Create: `docs/product/{vision,personas,user-journeys,requirements,non-functional-requirements,business-rules,success-metrics}.md`
- Create: `docs/architecture/{system-context,container-view,component-view,data-flow,deployment-view,integration,data-model,technology-radar}.md`
- Create: `docs/adr/README.md`, `docs/adr/0001-record-architecture-decisions.md`

**Content requirements:**
- `docs/README.md` — doc index: table linking every doc file with one-line purpose; navigation guidance; pointer to source-of-truth hierarchy.
- `docs/glossary.md` — term table (RAG, LLM, ADR, SLO, RTO, RPO, OIDC, SBOM, prompt-injection, guardrail, eval, etc.).
- `docs/assumptions.md` — the 8 assumptions from spec §12 (template-relevant) + a "project assumptions" section for consumers to fill.
- `docs/constraints.md` — template constraints (stack-agnostic, MIT, no prod target) + project-constraints section.
- `docs/product/*` — each file: a `# <Title>` H1, a `**Status:** adapt to your project` line, and the relevant section prompts from spec §6.2 expanded into sub-headings.
- `docs/architecture/*` — each file: H1 + status + the relevant views (spec §6.4 / docs/architecture purpose list). `technology-radar.md` uses Adopt/Trial/Assess categories.
- `docs/adr/README.md` — ADR process (when to write one, MADR format pointer, numbering, status lifecycle Proposed→Accepted→Deprecated→Superseded) + an index table.
- `docs/adr/0001-record-architecture-decisions.md` — the bootstrap ADR (accept ADR practice + the template's stack-agnostic decision) using the template from Task 8 once created; for ordering, write it against the format described in spec §6.7 (status/date/context/decision/alternatives/consequences/security/data/operational/migration/rollback).

- [ ] **Step 1:** Create `docs/README.md`, `docs/glossary.md`, `docs/assumptions.md`, `docs/constraints.md`.
- [ ] **Step 2:** Create the 7 `docs/product/*.md` files.
- [ ] **Step 3:** Create the 8 `docs/architecture/*.md` files.
- [ ] **Step 4:** Create `docs/adr/README.md` + `docs/adr/0001-record-architecture-decisions.md`.
- [ ] **Step 5: Verify** — Run: `find docs -name '*.md' | wc -l` → expect 20 (1 + 3 + 7 + 8 + 1 ADR README + 1 ADR = 21; adjust assertion to actual count and confirm ≥20). Run: `grep -L "^# " docs/product/*.md docs/architecture/*.md` → empty (each has an H1).
- [ ] **Step 6: Commit** — `git add docs/README.md docs/glossary.md docs/assumptions.md docs/constraints.md docs/product docs/architecture docs/adr && git commit -m "docs: add docs index, glossary, assumptions, product, architecture, ADR-0001"`

---

## Task 8: `docs/` tree B — api + security + ai + development + operations + plans + templates

**Files:**
- Create: `docs/api/{api-guidelines,error-model,authentication,authorization,versioning}.md`, `docs/api/openapi.yaml`
- Create: `docs/security/{threat-model,data-classification,access-control,secrets-management,secure-coding,dependency-policy,vulnerability-management,incident-response,privacy-impact-assessment}.md`
- Create: `docs/ai/{ai-system-design,model-selection,model-card,prompt-management,agent-design,tool-permissions,evaluation-strategy,safety-and-guardrails,prompt-injection-defense,data-privacy,model-routing,cost-management,human-oversight}.md`
- Create: `docs/development/{development-guide,local-setup,coding-standards,branching-strategy,pull-request-process,testing-strategy,definition-of-ready,definition-of-done}.md`
- Create: `docs/operations/{deployment-guide,environment-strategy,observability,monitoring,alerting,backup-and-recovery,disaster-recovery,capacity-management,rollback,runbook}.md`
- Create: `docs/templates/{feature-design-template,implementation-plan-template,adr-template,threat-model-template,incident-report-template,postmortem-template,release-checklist-template}.md`
- Create: `docs/plans/README.md`, `docs/plans/technical-debt.md`, `docs/plans/active/.gitkeep`, `docs/plans/completed/.gitkeep`

**Content requirements:**
- Each `.md`: H1 + `**Status:** adapt to your project` line + sub-headings drawn from the spec section that defines its purpose:
  - `docs/security/*` ← spec §15 + §7.7; `threat-model.md` references STRIDE.
  - `docs/ai/*` ← spec §7 (each file = one §7 subsection); `prompt-management.md` links to `prompts/registry.yaml`; `evaluation-strategy.md` links to `evals/`.
  - `docs/development/testing-strategy.md` ← spec §9; thresholds table from spec §8.
  - `docs/development/definition-of-ready.md` ← spec §26; `definition-of-done.md` ← spec §27.
  - `docs/operations/*` ← spec §22 (deployment), §24 (observability), §25 (ops/reliability); `rollback.md` ← spec §22.4; `runbook.md` is a skeleton with section placeholders for common incidents.
  - `docs/api/openapi.yaml` — minimal valid OpenAPI 3.0 skeleton (`openapi`, `info`, `paths: {}`, `components`).
  - `docs/api/error-model.md` — standard error envelope example + status-code policy.
- Templates (real, copy-pasteable):
  - `adr-template.md` — MADR format with all spec §6.7 fields.
  - `feature-design-template.md`, `implementation-plan-template.md` — from spec §2.3 design-before-implementation checklist.
  - `threat-model-template.md` — STRIDE table + data-flow + trust boundaries.
  - `incident-report-template.md`, `postmortem-template.md`, `release-checklist-template.md` — standard structures (timeline, impact, root cause, action items / release sign-off items).
- `docs/plans/README.md` — lifecycle: active → completed; naming `YYYY-MM-DD-<feature>-design.md`.
- `docs/plans/technical-debt.md` — seed with the Phase-1 Action-pinning debt entry: "Third-party GitHub Actions in Phase-1 workflows use tags pending SHA pinning before consumer adds secrets."

- [ ] **Step 1:** Create `docs/api/*` (5 md + `openapi.yaml`).
- [ ] **Step 2:** Create `docs/security/*` (9 md).
- [ ] **Step 3:** Create `docs/ai/*` (12 md).
- [ ] **Step 4:** Create `docs/development/*` (8 md).
- [ ] **Step 5:** Create `docs/operations/*` (10 md).
- [ ] **Step 6:** Create `docs/templates/*` (7 md).
- [ ] **Step 7:** Create `docs/plans/{README.md,technical-debt.md}` + `active/.gitkeep` + `completed/.gitkeep`.
- [ ] **Step 8: Verify** — Run: `python3 -c "import yaml; yaml.safe_load(open('docs/api/openapi.yaml')); print('openapi OK')"`. Run: `grep -L "^# " docs/api/*.md docs/security/*.md docs/ai/*.md docs/development/*.md docs/operations/*.md docs/templates/*.md | grep -v openapi` → empty.
- [ ] **Step 9: Commit** — `git add docs/api docs/security docs/ai docs/development docs/operations docs/templates docs/plans && git commit -m "docs: add api, security, ai, development, operations, templates, plans scaffolding"`

---

## Task 9: AI / test / infra scaffolding

**Files:**
- Create: `prompts/README.md`, `prompts/registry.yaml`, `prompts/{system,tasks,evaluators,versions,schemas}/.gitkeep`
- Create: `evals/README.md`, `evals/{config,datasets,golden,adversarial,regression,safety,performance,cost,reports}/.gitkeep`
- Create: `tests/README.md`, `tests/{unit,contract,integration,e2e,security,performance}/.gitkeep`
- Create: `src/README.md`, `src/.gitkeep`
- Create: `infrastructure/README.md`, `infrastructure/.gitkeep`
- Create: `deployment/README.md`, `deployment/.gitkeep`
- Create: `observability/README.md`, `observability/.gitkeep`

**Content requirements:**
- `prompts/README.md` ← spec §7.2: registry process; fields each prompt must have (id, name, purpose, version, owner, input, output schema, model compatibility, safety constraints, eval dataset, changelog, deprecation). State prompt changes are reviewed like code and trigger evals.
- `prompts/registry.yaml` — example with 2 sample entries exercising every field, clearly marked `example`.
- `evals/README.md` ← spec §7.4 + §9.5: the eval taxonomy (deterministic, schema, golden, semantic, hallucination, retrieval relevance, groundedness, citation, prompt-injection, leakage, unsafe tool-use, harmful output, refusal, latency, token, cost, fallback, regression); thresholds by risk level; skeleton-only note (consumer wires model endpoint).
- `tests/README.md` ← spec §9: what goes in each subdir; thresholds from spec §8.
- `src/README.md` — "consumer-owned implementation lives here; template is stack-agnostic."
- `infrastructure/README.md`, `deployment/README.md`, `observability/README.md` — purpose + what to place here; observability references OTel + spec §24.

- [ ] **Step 1:** Create all `.gitkeep` placeholders for prompts/evals/tests/src/infra/deploy/observability subdirs.
- [ ] **Step 2:** Create the READMEs + `prompts/registry.yaml`.
- [ ] **Step 3: Verify** — Run: `python3 -c "import yaml; yaml.safe_load(open('prompts/registry.yaml')); print('registry OK')"`. Run: `find prompts evals tests infrastructure deployment observability src -name '.gitkeep' | wc -l` → expect ≥ 24. Run: `git check-ignore .env.example || echo "OK: .env.example NOT ignored"`.
- [ ] **Step 4: Commit** — `git add prompts evals tests src infrastructure deployment observability && git commit -m "feat: add AI-native, test, and infra scaffolding (prompts, evals, tests, src, infra, deploy, observability)"`

---

## Task 10: Phase-1 verification & checkpoint

**Files:** none (verification only; updates `CHANGELOG.md` Unreleased section).

- [ ] **Step 1:** Run `make ci` and capture output; confirm exit 0.
- [ ] **Step 2:** Run `make docs-check`; confirm exit 0.
- [ ] **Step 3:** Validate ALL YAML: `python3 - <<'PY'\nimport yaml, glob\nfiles = glob.glob('.github/**/*.yml', recursive=True) + glob.glob('docs/**/*.yaml', recursive=True) + glob.glob('prompts/**/*.yaml', recursive=True)\nfor f in sorted(files):\n    list(yaml.safe_load_all(open(f))); print('OK', f)\nprint('total', len(files))\nPY`
- [ ] **Step 4:** Confirm every required Phase-1 file exists. Run the structural assertion: `for f in README.md PRODUCT.md DESIGN.md ARCHITECTURE.md AGENTS.md CLAUDE.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md LICENSE Makefile .editorconfig .gitignore .gitattributes .env.example .github/CODEOWNERS .github/dependabot.yml .github/labeler.yml .github/release.yml .github/pull_request_template.md docs/README.md docs/adr/0001-record-architecture-decisions.md prompts/registry.yaml; do [ -f "$f" ] && echo "OK $f" || echo "MISSING $f"; done` → no MISSING.
- [ ] **Step 5:** Review the full diff: `git log --oneline` and `git diff --stat $(git rev-list --max-parents=0 HEAD) HEAD`.
- [ ] **Step 6:** Update `CHANGELOG.md` Unreleased `### Added` to summarize Phase 1 deliverables.
- [ ] **Step 7: Commit** — `git add CHANGELOG.md && git commit -m "docs: update changelog for Phase 1 completion"`
- [ ] **Step 8:** Report — list every file generated, every command run with actual output, remaining risks (Phase-1 pinning debt), and the checkpoint handoff for owner review before Phase 2.

---

## Self-Review (run after writing)

**1. Spec coverage (Phase 1 scope only):**
- Root config (gitignore/editorconfig/env/license/changelog/CoC) → Task 1 ✓
- CONTRIBUTING.md / SECURITY.md — **GAP**: neither Task above creates them. They are in the spec §5 root file list. → Add to Task 1 (Step list). *Fixed inline below.*
- Canonical AGENTS.md + 4 adapters → Task 2 ✓
- README/PRODUCT/DESIGN/ARCHITECTURE → Task 3 ✓
- Makefile + 3 scripts → Task 4 ✓
- .github governance (CODEOWNERS/dependabot/labeler/release/PR template/issue templates) → Task 5 ✓
- Phase-1 workflows (pr-title/validate-metadata/docs-check/action-security) → Task 6 ✓
- docs/ tree (all subdirs + templates + ADR-0001) → Tasks 7 & 8 ✓
- prompts/ evals/ tests/ src/ infrastructure/ deployment/ observability/ scaffolding → Task 9 ✓

**2. Placeholder scan:** no TBD/TODO/"fill in" in steps (the one `# TODO(pinning)` is a deliberate, tracked debt comment with a corresponding `technical-debt.md` entry — acceptable per spec §18 which allows TODO linked to a debt record). ✓

**3. Consistency:** `detect-stack.sh` token names match Makefile `$(STACK)` checks; `ci-local.sh` is invoked by both `make docs-check` and `make ci`. ✓

**Fix applied:** Task 1 now also creates `CONTRIBUTING.md` and `SECURITY.md`.
