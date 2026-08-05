# Error Model

**Status:** Adapt to your project.

Standard error envelope:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message.",
    "request_id": "uuid",
    "details": {}
  }
}
```

## Status code policy

| Code | When |
|------|------|
| 400 | Malformed input |
| 401 | Unauthenticated |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict |
| 422 | Semantic validation failure |
| 429 | Rate limited |
| 5xx | Server error (never leak internals) |
