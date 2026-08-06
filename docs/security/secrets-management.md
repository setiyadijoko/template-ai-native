# Secrets Management

**Status:** Adapt to your project.

- Never commit secrets (`.env.example` holds names + descriptions + safe placeholders only).
- Production secrets live in an approved secret manager; use OIDC over long-lived cloud credentials.
- Rotate on schedule and on incident.
- Scan with gitleaks + GitHub Secret Scanning; secrets are never printed to logs.
