# API Versioning

**Status:** Adapt to your project.

- Version in the URI path (e.g. `/v1/...`) or header — pick one and record an ADR.
- Backward-compatible changes are additive; breaking changes require a new major version and a deprecation window.
- No undocumented breaking API changes (enforced by `AGENTS.md`).
