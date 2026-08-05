# Deployment Guide

**Status:** Adapt to your project.

Environments: local → test (CI) → development → staging → production. Dev deploys on merge to `main`; staging is manual/protected; production is human-gated (GitHub Environment approval + OIDC) and promotes the exact staging artifact (no rebuild). See [environment-strategy.md](environment-strategy.md) and [rollback.md](rollback.md).
