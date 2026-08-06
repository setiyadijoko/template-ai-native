# Rollback

**Status:** Template policy (spec §22.4).

Rollback paths: application, configuration, feature-flag, infrastructure, database forward-recovery, model, prompt. **Database rollback is not assumed safe** — prefer forward recovery; destructive migrations require explicit approval. Production deployments auto-stop or roll back when thresholds are exceeded.
