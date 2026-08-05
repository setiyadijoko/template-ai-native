# Technical Debt

Tracked, deferred debt. Each entry: description, location, why it matters, priority, proposed resolution.

| ID | Description | Location | Priority | Proposed resolution |
|----|-------------|----------|----------|---------------------|
| TD-0001 | Phase-1 workflows pin third-party GitHub Actions by git tag pending commit-SHA pinning | `.github/workflows/*.yml` | Medium | Replace tags with immutable commit SHAs (and document the release tag in a comment) before a consumer adds secrets. Some Phase-1 workflows already use SHAs; complete the rest. |
