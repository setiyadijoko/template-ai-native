# Technical Debt

Tracked, deferred debt. Each entry: description, location, why it matters, priority, proposed resolution.

| ID | Description | Location | Status | Resolution |
|----|-------------|----------|--------|------------|
| TD-0001 | (Closed) Phase-1 workflows were initially expected to pin third-party GitHub Actions by git tag pending commit-SHA pinning | `.github/workflows/*.yml` | Closed 2026-08-05 | All Phase-1 workflow `uses:` entries are already pinned to immutable 40-char commit SHAs with the release tag documented in a trailing comment. No action required. Kept for traceability. |

> Note for Phases 2–6: every new workflow that introduces a `uses:` for a third-party Action MUST pin it to a commit SHA (with the release tag in a comment) from the outset.
