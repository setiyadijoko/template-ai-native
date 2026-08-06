# Technical Debt

Tracked, deferred debt. Each entry: description, location, why it matters, priority, proposed resolution.

| ID | Description | Location | Status | Resolution |
|----|-------------|----------|--------|------------|
| TD-0001 | (Closed) Phase-1 workflows were initially expected to pin third-party GitHub Actions by git tag pending commit-SHA pinning | `.github/workflows/*.yml` | Closed 2026-08-05 | All Phase-1 workflow `uses:` entries are already pinned to immutable 40-char commit SHAs with the release tag documented in a trailing comment. No action required. Kept for traceability. |
| TD-0002 | Coverage thresholds for critical modules (≥90%) and changed-lines (≥90%) require a coverage service (Codecov). Phase 2 enforces only ≥80% overall via each tool's native `fail-under`. | `scripts/stack-tools.sh`, `.github/workflows/ci-test.yml` | Open | Wire Codecov (`.codecov.yml` + token) and per-module/patch gating in a later phase. |
| TD-0003 | Go has no native `--cov-fail-under`; coverage threshold is enforced by an inline `awk` step in ci-test.yml. | `.github/workflows/ci-test.yml` | Open | Move threshold computation into a small helper script if a second stack needs similar post-processing. |

> Note for Phases 2–6: every new workflow that introduces a `uses:` for a third-party Action MUST pin it to a commit SHA (with the release tag in a comment) from the outset.
