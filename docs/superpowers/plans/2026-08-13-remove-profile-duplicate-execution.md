# Remove Profile Duplicate Execution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop duplicate direct profile-dependent pull-request execution for initialized consumers while preserving template compatibility, stable required contexts, build provenance, and independent scheduled/manual controls.

**Architecture:** Add one fail-closed repository-mode resolver used only to gate direct workflow jobs. Profile consumers execute required pull-request controls through `Profile policy / Required controls`; the template compatibility mode keeps the established direct baseline. The central profile-policy resolver remains the only profile mapping authority, while build/attestation and non-PR control channels stay independent.

**Tech Stack:** POSIX shell, GitHub Actions YAML, existing shell contract harness.

## Global Constraints

- Preserve the five invariant governance workflows and exact `Required controls` check-run name.
- Never infer a profile; incomplete initialized consumers fail closed in the aggregate.
- Do not suppress build, provenance, SBOM, Scorecard, scheduled scans, manual dispatch, or provider-secret paths.
- Use `pull_request`, never `pull_request_target`; preserve least privilege and immutable Action pins.
- Keep rollback reversible by restoring direct-job guards to unconditional compatibility behavior.

---

### Task 1: Direct execution mode contract

**Files:**
- Create: `scripts/resolve-direct-execution-mode.sh`
- Create: `scripts/test/test-profile-direct-execution-mode.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes repository-owned `.template/project.yaml` and `.template/profile.yaml` paths.
- Produces exactly `direct_profile_controls=true|false` and exits non-zero for partial initialization.

- [x] Write tests for empty-template compatibility, valid profile consumer delegation, project-only failure, profile-only failure, symlinks, and deterministic output.
- [x] Run the focused test and verify RED because the helper is absent.
- [x] Implement the smallest regular-file/symlink-safe resolver without parsing maturity mappings.
- [x] Run the focused test and verify GREEN.

### Task 2: Gate duplicate direct jobs

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/secret-scan.yml`
- Modify: `.github/workflows/dependency-review.yml`
- Modify: `.github/workflows/codeql.yml`
- Inspect only: `.github/workflows/ai-evaluation.yml` (provider path must remain independent)
- Modify: `scripts/test/test-profile-control-boundaries.sh`
- Modify: `scripts/test/test-delivery-workflows.sh`

**Interfaces:**
- Direct PR/push quality, coverage, monorepo, secret, dependency, and CodeQL jobs execute only in compatibility mode.
- Build and push attestation remain independent in `ci.yml`.
- Schedule/manual security jobs and direct secret-gated AI evaluation remain independent.

- [x] Add structural and executable tests proving profile mode delegates only duplicated jobs and compatibility mode retains them.
- [x] Run focused contracts and verify RED against current unconditional jobs.
- [x] Add bounded mode-resolver jobs/outputs and minimal job guards.
- [x] Run focused contracts and verify GREEN.

### Task 3: Governance synchronization and verification

**Files:**
- Modify: `README.md`
- Modify: `docs/getting-started.md`
- Modify: `docs/adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/plans/roadmap.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`
- Modify: `scripts/test/test-profile-required-controls-workflow.sh`

**Interfaces:**
- Documents duplicate removal as implemented locally pending hosted consumer revalidation.
- Keeps TD-0015 open until post-merge consumer evidence proves no duplicate or pending contexts.

- [x] Add documentation assertions and verify RED against stale duplicate-baseline wording.
- [x] Synchronize governance without claiming hosted completion.
- [x] Run `make test-scripts`, `make docs-check`, `make ci`, workflow security checks, and `git diff --check`.
- [x] Review the complete diff.
- [ ] Commit, push, and open a Draft PR.
