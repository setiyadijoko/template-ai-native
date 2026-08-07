# Integrated Code Review Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Code Review Graph and Alibaba Open Code Review operate as one documented, coordinated PR-review policy while preserving their distinct security and data boundaries.

**Architecture:** Code Review Graph remains the local structural-analysis layer and trusted sticky-report publisher. Alibaba Open Code Review remains the optional semantic LLM layer. They share PR scope, advisory status, concurrency conventions, and documentation, but the graph report is not injected into the LLM request because the Alibaba action has no supported graph-context input and its agent already retrieves repository context.

**Tech Stack:** GitHub Actions YAML, POSIX shell contract tests, Markdown, pinned composite GitHub Actions.

## Global Constraints

- No `pull_request_target`.
- Third-party Actions remain pinned to immutable 40-character commit SHAs with release comments.
- Graph analysis remains `contents: read` and fork-safe through `workflow_run` publication.
- Alibaba OCR remains secret-gated and advisory; no AI finding becomes a merge gate.
- Real LLM endpoints and credentials remain consumer-owned.

---

### Task 1: Define the integrated review contract

**Files:**
- Modify: `scripts/test/test-code-review-graph.sh`

- [x] **Step 1: Write failing contract assertions** for shared PR scope, advisory settings, OCR job-level permissions, disabled checkout credentials, and required OCR secret inputs.
- [x] **Step 2: Run `sh scripts/test/test-code-review-graph.sh` and confirm the new assertions fail against the current independent OCR workflow.**
- [x] **Step 3: Keep the contract test focused on observable workflow policy; do not test dynamic LLM output.**

### Task 2: Coordinate the two workflows

**Files:**
- Modify: `.github/workflows/open-code-review.yml`
- Modify: `.github/workflows/code-review-graph.yml`
- Modify: `.github/workflows/code-review-graph-comment.yml`

- [x] **Step 1: Align OCR path filters with code-bearing and AI-behavior paths (`src`, `tests`, `prompts`, `evals`, and relevant workflow files).**
- [x] **Step 2: Set explicit empty workflow permissions and job-scoped OCR permissions.**
- [x] **Step 3: Disable checkout credential persistence for OCR.**
- [x] **Step 4: Keep both jobs advisory and independent; use sticky/incremental OCR summary settings to avoid comment spam.**
- [x] **Step 5: Preserve the existing graph trusted publisher and do not pass untrusted graph text into LLM credentials or shell interpolation.**

### Task 3: Document the complementary review policy

**Files:**
- Create: `docs/ai/integrated-code-review.md`
- Create: `docs/adr/0004-integrate-structural-and-semantic-review.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/plans/technical-debt.md`

- [x] **Step 1: Document the two-layer flow, data boundary, activation secrets, fork behavior, and merge-gate policy.**
- [x] **Step 2: Record that direct graph-to-LLM context injection is intentionally not implemented because the Alibaba action exposes no supported context input.**
- [x] **Step 3: Add a deferred item for measuring combined review precision, duplication, cost, and false positives before promoting either layer.**

### Task 4: Verify and review

- [x] **Step 1: Run the focused contract test and confirm it passes.**
- [x] **Step 2: Run `make test-scripts`, `make docs-check`, `actionlint .github/workflows/*.yml`, and `git diff --check`.**
- [x] **Step 3: Run local zizmor if available and inspect the complete diff.**
- [ ] **Step 4: Move this plan to `docs/superpowers/plans/completed/` only after the PR is merged.**
