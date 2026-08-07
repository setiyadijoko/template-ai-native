# Deployment Guide

**Status:** Adapt to your project.

Environments: local → test (CI) → development → staging → production. Dev deploys on merge to `main`; staging is manual/protected; production is human-gated (GitHub Environment approval + OIDC) and promotes the exact staging artifact (no rebuild). See [environment-strategy.md](environment-strategy.md) and [rollback.md](rollback.md).

## Phase 5 workflows

| Workflow | Status | Notes |
|---|---|---|
| `sbom.yml` | Active | Generates an SPDX SBOM on pushes to `main`; release also generates the SBOM attached to a version tag. |
| `artifact-attestation.yml` | Active | Reusable, fail-closed provenance for the packaged artifact in the same successful push-to-`main` CI run; empty templates skip explicitly. |
| `release.yml` | Active | On `v*`, requires a successful exact-SHA `ci.yml` push run and publishes its packaged artifact without rebuilding, plus SBOM and digests. |
| `deploy-development.yml` | Skeleton | Wire your dev platform + OIDC; create the `development` Environment. |
| `deploy-staging.yml` | Skeleton | Wire staging; create + protect the `staging` Environment. |
| `deploy-production.yml` | Skeleton (human-gated) | Wire production OIDC; the `production` Environment MUST have Required Reviewers. Verify the artifact digest matches staging (same artifact promoted, spec §16). |
| `smoke-test.yml` | Skeleton | Wire your health endpoint; callable after deploy. |

Promote the same artifact validated in staging to production — do NOT rebuild (spec §16).

## Release chain of custody

For a detected application stack, `build.yml` packages one immutable tarball,
uploads it as `build-<stack>`, and exposes that identity to the same `ci.yml`
run. The attestation job downloads and attests that exact packaged file. A
version-tag release then requires a successful `ci.yml` push run for the tagged
commit SHA and downloads the matching artifact without invoking another build.

The stack-agnostic empty template is the only exception: when
`scripts/detect-stack.sh` returns `unknown`, the release creates a source archive
with `git archive`. Missing, expired, ambiguous, or stack-mismatched CI evidence
blocks the release. Each release contains the package, `sbom.spdx.json`, and
`digests.txt`.
