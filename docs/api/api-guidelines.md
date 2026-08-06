# API Guidelines

**Status:** Adapt to your project.

- REST + JSON unless another style is approved (then record an ADR).
- Version APIs; no undocumented breaking changes (see [versioning.md](versioning.md)).
- Use the standard error envelope (see [error-model.md](error-model.md)).
- Validate input; authorize every request; correlate with a request ID.
- For AI endpoints, validate model output against a schema before returning/acting (see [AI System Design](../ai/ai-system-design.md)).
