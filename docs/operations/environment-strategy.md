# Environment Strategy

**Status:** Template policy (spec §20).

| Env | Config source | Secrets | Notes |
|-----|---------------|---------|-------|
| local | `.env` (gitignored) | none committed | unsafe defaults fail closed |
| test | CI ephemeral | masked | PR checks |
| development | env-specific | dev secrets | on merge to main |
| staging | env-specific | staging secrets | manual, protected |
| production | env-specific | secret manager + OIDC | human-gated |

Configuration validated at startup; production debug mode prohibited; development settings must not silently apply to production.
