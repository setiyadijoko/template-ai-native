# Deployment Guide

**Status:** Adapt to your project.

Environments: local → test (CI) → development → staging → production. Dev deploys on merge to `main`; staging is manual/protected; production is human-gated (GitHub Environment approval + OIDC) and promotes the exact staging artifact (no rebuild). See [environment-strategy.md](environment-strategy.md) and [rollback.md](rollback.md).

## Phase 5 workflows

| Workflow | Status | Notes |
|---|---|---|
| `sbom.yml` | Active | Generates SPDX SBOM on push to main; attached to releases. |
| `artifact-attestation.yml` | Active | Sigstore build-provenance for the `build.yml` artifact; skips when no artifact. |
| `release.yml` | Active | Drafts a GitHub Release on `v*` tags with changelog + SBOM + digest. |
| `deploy-development.yml` | Skeleton | Wire your dev platform + OIDC; create the `development` Environment. |
| `deploy-staging.yml` | Skeleton | Wire staging; create + protect the `staging` Environment. |
| `deploy-production.yml` | Skeleton (human-gated) | Wire production OIDC; the `production` Environment MUST have Required Reviewers. Verify the artifact digest matches staging (same artifact promoted, spec §16). |
| `smoke-test.yml` | Skeleton | Wire your health endpoint; callable after deploy. |

Promote the same artifact validated in staging to production — do NOT rebuild (spec §16).
