# Deployment Guide

**Status:** Delivery policy baseline; platform-specific deployment remains
consumer-owned.

Target state after consumer platform activation: local → test (CI) →
development → staging → production. In that target state, development deploys
on merge to `main`; staging is manual and protected; production is manual,
human-gated by GitHub Environment approvals, authenticates with job-scoped
OIDC, and promotes the exact staging artifact without rebuilding. None of these
development, staging, or production deployment behaviors, Environment approval
controls, or OIDC authentication is active or proven until the consumer
approves a platform design and wires the skeleton workflows. See
[environment-strategy.md](environment-strategy.md) and
[rollback.md](rollback.md).

## Phase 5 workflows

| Workflow | Status | Notes |
|---|---|---|
| `sbom.yml` | Active | Generates an SPDX SBOM on pushes to `main`; release also generates the SBOM attached to a version tag. |
| `artifact-attestation.yml` | Active | Reusable, fail-closed provenance for the packaged artifact in the same successful push-to-`main` CI run; empty templates skip explicitly. |
| `release.yml` | Active | On `v*`, requires a successful exact-SHA `ci.yml` push run and creates a draft release from its packaged artifact without rebuilding, plus SBOM and digests. |
| `deploy-development.yml` | Skeleton | Wire your dev platform + OIDC; create the `development` Environment. |
| `deploy-staging.yml` | Skeleton | Wire staging; create + protect the `staging` Environment. |
| `deploy-production.yml` | Skeleton (human-gated) | Wire production OIDC; the `production` Environment MUST have Required Reviewers. Verify the artifact digest matches staging (same artifact promoted, spec §16). |
| `smoke-test.yml` | Skeleton | Wire your health endpoint; callable after deploy. |

The three deploy workflows and `smoke-test.yml` remain Phase 5 skeletons. They
do not deploy or prove environment health until an approved platform design
wires them with least-privilege OIDC, immutable artifact verification, and
environment-specific recovery checks.

## Phase 6 production-readiness controls

| Control | Status | Meaning |
|---|---|---|
| `production-readiness.yml` | Active | Validates the contract; not production approval. |
| `rollback.yml` | Skeleton, fail closed | Manual and environment-bound; performs no rollback. |
| `production-readiness.conf` | Template | Contract-valid and explicitly not production-ready. |

The readiness check separates contract validity from operational approval.
Both valid manifest states report `readiness_contract_valid=true` and
`production_ready=false`. Active status validates required values and
repository-confined evidence-reference shape only; it does not verify human
review, freshness, content approval, or production authorization. Those remain
separate human and protected-environment controls. The rollback workflow remains manual,
environment-bound, and deliberately fails at its unwired sentinel until that
design adds verified artifact retrieval, job-scoped authentication, execution,
and recovery verification.

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
