# P0 Consumer CI Regressions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a freshly initialized Go and Node.js monorepo run its component
CI without a duplicate caller workflow, a missing Go linter, or false failures
from empty optional Node.js test categories.

**Architecture:** Keep `ci.yml` as the only event-facing dispatcher and retain
the accepted version-2 component contract. CI workflows called by the
dispatcher receive unique concurrency groups, install a pinned Go linter before
the existing mapper runs, and delegate optional Node.js test-category handling
to a focused POSIX shell helper. The existing consumer fixture and shell
contracts cover the local boundary; a GitHub pull request supplies the final
hosted-runner verification.

**Tech Stack:** GitHub Actions, POSIX shell, Make, Go, Node.js/Vitest.

## Global Constraints

- Preserve stack-agnostic behavior and version-1 compatibility.
- Preserve the 80% coverage gate; coverage-policy changes are outside P0.
- Keep existing check names, least-privilege permissions, fork safety, and
  immutable Action SHA pinning.
- Do not add a second event-facing monorepo caller workflow.
- Do not change branch protection, deployment, or profile-aware controls.

---

### Task 1: Prevent reusable-workflow concurrency collisions

**Files:**

- Modify: `.github/workflows/ci-quality.yml`
- Modify: `.github/workflows/ci-test.yml`
- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/ci-monorepo.yml`
- Test: `scripts/test/test-monorepo-ci.sh`

**Interfaces:**

- Consumes: the top-level `ci.yml` concurrency group and GitHub's reusable
  workflow context behavior.
- Produces: distinct caller and callee concurrency groups for the same ref.

- [x] Add a regression assertion that evaluates the caller/callee group
  contract and fails when a reusable workflow can resolve to the caller group.
- [x] Run `sh scripts/test/test-monorepo-ci.sh` and confirm the collision test
  fails against the current workflow definitions.
- [x] Give each reusable workflow a stable workflow-specific group suffix.
- [x] Re-run the focused test and confirm it passes.

### Task 2: Install a deterministic Go linter

**Files:**

- Modify: `.github/workflows/ci-quality.yml`
- Modify: `.github/workflows/ci-monorepo.yml`
- Test: `scripts/test/test-monorepo-ci.sh`
- Test: `scripts/test/test-security-workflows.sh`

**Interfaces:**

- Consumes: `go:lint -> golangci-lint run` from `scripts/stack-tools.sh`.
- Produces: `golangci-lint` v2.12.2 on `PATH` through
  `golangci/golangci-lint-action` v9.3.0 pinned to commit
  `ba0d7d2ec06a0ea1cb5fa41b2e4a3ab91d21278a` in install-only mode.

- [x] Add failing contracts for the pinned installer, exact linter version,
  install-only behavior, and both single-stack/component-aware jobs.
- [x] Run the focused workflow tests and confirm the installer contracts fail.
- [x] Add the installer after Go setup and before the mapper-based lint step.
- [x] Re-run the workflow and security contracts.

### Task 3: Skip empty optional Node.js test categories safely

**Files:**

- Create: `scripts/run-node-test-category.sh`
- Create: `scripts/test/test-node-test-category.sh`
- Modify: `scripts/stack-tools.sh`
- Modify: `scripts/test/test-stack-detection.sh`
- Modify: `Makefile`

**Interfaces:**

- Consumes: category `integration` or `e2e` and the component working
  directory.
- Produces: exit 0 with an explicit skip message when no matching tests exist;
  otherwise executes local Vitest and preserves its exit status.

- [x] Add behavior tests for missing directories, empty directories, a real
  test-file handoff, invalid categories, and propagation of Vitest failure.
- [x] Run the new test and confirm it fails because the helper is absent.
- [x] Implement the minimal helper and map Node.js integration/e2e commands to
  it without changing unit-test behavior.
- [x] Re-run the new test and mapper contracts.

### Task 4: Strengthen consumer regression evidence and documentation

**Files:**

- Modify: `tests/fixtures/consumer-monorepo/`
- Modify: `scripts/test/test-consumer-regressions.sh`
- Modify: `docs/adr/0007-component-aware-monorepo-ci-contract.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `scripts/README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**

- Consumes: the version-2 Go/Node fixture and P0 runtime contracts.
- Produces: a fixture with minimal source/test-category boundaries and an
  explicit hosted-runner verification requirement.

- [x] Add fixture assertions that fail until the Go and Node.js runtime
  boundaries used by the P0 contracts are present.
- [x] Add minimal fixture source and tests without adding runtime dependencies
  to the template root.
- [x] Document caller-owned concurrency, deterministic Go lint setup, optional
  Node.js category behavior, and the remaining remote validation boundary.
- [x] Run `make test-scripts`, `make docs-check`, `make ci`, workflow syntax and
  security tools when installed, and inspect the complete diff.
