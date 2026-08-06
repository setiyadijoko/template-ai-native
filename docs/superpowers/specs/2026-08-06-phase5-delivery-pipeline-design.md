# Design Spec — Phase 5: Delivery pipeline

**Status:** Approved
**Date:** 2026-08-06
**Owner:** Project owner (@setiyadijoko)
**Builds on:** Phase 1 (`cd785fd`) + Phase 2 (`0bb1677`) + Phase 3 (`99fd405` + scorecard fix `b238d68`) + Phase 4 (`a607d76`)

---

## 1. Goal

Add the Level-2 delivery pipeline (with selected Level-3 supply-chain controls) to `template-ai-native`: SBOM generation, artifact build-provenance attestation, and a GitHub Release workflow that work on the repository itself (no deploy target needed). The three deploy workflows (development/staging/production) and smoke-test ship as skeletons — the template has no deployment target (stack-agnostic, no app), so deploy steps are commented OIDC/config placeholders the consumer wires to their platform.

## 2. Key decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Deploy scope | SBOM + attestation + release REAL; deploy + smoke as skeleton | Template has no deployment target; real deploy steps would produce false failures. Skeleton with clear OIDC/config comments is honest + safe (graceful pattern from Phase 3/4). |
| 2 | SBOM tool | `anchore/sbom-action` | GitHub Action, generates SPDX/CycloneDX, attaches to release + artifact. Industry standard. |
| 3 | Release trigger | tag `v*` (semantic versioning) | Drafts GitHub Release with changelog + SBOM + digest on consumer-pushed tag. |
| 4 | Attestation | `actions/attest-build-provenance` | GitHub-native Sigstore build provenance (Level-3 control). Skips cleanly when no build artifact exists. |
| 5 | Deploy trigger | `workflow_dispatch` + commented OIDC | Consumer wires platform (AWS/GCP/Fly/etc.) + GitHub Environment. Production is human-gated via Environment required-reviewers. |
| 6 | Action SHAs | Resolve via `gh api` at implementation time | Phase-1–4 lesson. |

## 3. Workflow inventory

| Workflow | Trigger | Purpose | Status |
|---|---|---|---|
| `sbom.yml` | `push: main` + `workflow_dispatch` | Generate SPDX SBOM, upload as artifact (+ attach on release) | Active |
| `artifact-attestation.yml` | `workflow_run` (after `build.yml`) + `workflow_dispatch` | Sigstore build-provenance for the build artifact | Active — skips cleanly when no artifact (empty template) |
| `release.yml` | tag `v*` | Draft GitHub Release + changelog + SBOM + digest | Active |
| `deploy-development.yml` | `workflow_dispatch` | Skeleton — consumer wires dev platform + OIDC | Skeleton |
| `deploy-staging.yml` | `workflow_dispatch` | Skeleton — consumer wires staging platform | Skeleton |
| `deploy-production.yml` | `workflow_dispatch` (`environment: production`) | Skeleton — human-gated via GitHub Environment + OIDC | Skeleton (HUMAN-GATED when activated) |
| `smoke-test.yml` | `workflow_dispatch` + `workflow_call` | Skeleton — consumer wires health endpoint | Skeleton |

## 4. File structure

```text
.github/workflows/
├── sbom.yml                 # NEW
├── artifact-attestation.yml # NEW
├── release.yml              # NEW
├── deploy-development.yml   # NEW (skeleton)
├── deploy-staging.yml       # NEW (skeleton)
├── deploy-production.yml    # NEW (skeleton)
└── smoke-test.yml           # NEW (skeleton)
```

Modified existing files: `AGENTS.md`, `docs/operations/deployment-guide.md`, `docs/operations/release-checklist-template.md`, `docs/plans/technical-debt.md`, `CHANGELOG.md`.

## 5. Workflow designs

### 5.1 `sbom.yml`
- `permissions: contents: read`.
- `concurrency`, `timeout-minutes: 10`.
- Steps: checkout → `anchore/sbom-action@<SHA>` with `format: spdx-json`, `output-file: sbom.spdx.json`, `upload-artifact: true` (uploads as Actions artifact; release attachment handled by `release.yml`).

### 5.2 `artifact-attestation.yml`
- `on: workflow_run` (`workflows: [build], types: [completed]`) + `workflow_dispatch`.
- `permissions: contents: read, id-token: write, attestations: write`.
- Steps: checkout → `actions/download-artifact` to fetch the build artifact from the triggering `workflow_run` (using `github-token` + `run-id: ${{ github.event.workflow_run.id }}`) → a guard step that checks `if: hashFiles('<artifact-pattern>') == ''` and exits 0 with "no build artifact to attest (empty template / stack unknown)" → otherwise `actions/attest-build-provenance@<SHA>` with `subject-name` + `subject-digest`. The guard makes the job graceful on the empty template.

### 5.3 `release.yml`
- `on: push: tags ['v*']`.
- `permissions: contents: write` (create release), `id-token: write`.
- Steps: checkout (full history) → generate SBOM (call sbom logic or run sbom-action again) → compute digest of the release artifact (or repo tree if no build) → `softprops/action-gh-release@<SHA>` with a changelog body (from the release-drafter categories in `.github/release.yml` Phase 1), attaching `sbom.spdx.json` + a `digests.txt` checksum file.

### 5.4 `deploy-development.yml` (skeleton)
- `on: workflow_dispatch`.
- `permissions: contents: read, id-token: write` (for OIDC).
- `environment: development` (consumer creates the GitHub Environment).
- Steps: checkout → a commented block showing OIDC config patterns (`aws-actions/configure-aws-credentials` / `flyctl-actions` / etc.) → a skeleton `run: echo "Deploy target not configured — implement deploy steps for your platform."`.

### 5.5 `deploy-staging.yml` (skeleton)
- Same as development, `environment: staging`, protected (consumer enables required reviewers in Environment settings).

### 5.6 `deploy-production.yml` (skeleton)
- `on: workflow_dispatch`.
- `environment: production` — **GitHub Environment with required reviewers** (the human gate; consumer enables in Settings → Environments). Per spec §2.6/§22.3, AI agents must not deploy to production without Environment approval + human + verified artifact + rollback.
- `permissions: contents: read, id-token: write`.
- Steps: checkout → commented OIDC + artifact-digest verification block → skeleton echo. Clear comments documenting that the consumer: (a) verifies the artifact digest matches staging, (b) uses OIDC over long-lived credentials, (c) documents rollback.

### 5.7 `smoke-test.yml` (skeleton)
- `on: workflow_dispatch` + `workflow_call` (callable after a deploy).
- `permissions: contents: read`.
- Steps: a commented `# Configure: curl/wget your health endpoint` → `echo "Smoke target not configured — wire your health endpoint."`.

## 6. Documentation updates

- `AGENTS.md` (production restrictions): add a Phase-5 note that deploy workflows are skeletons until the consumer wires a platform; production is human-gated via the `production` GitHub Environment; SBOM + attestation + release are active.
- `docs/operations/deployment-guide.md`: cross-reference the 7 Phase-5 workflows and the skeleton-vs-active distinction; note the same-artifact-promotion rule (spec §16).
- `docs/operations/release-checklist-template.md`: ensure SBOM + attestation + digest are in the checklist (already present from Phase 1 — confirm; augment if needed).
- `docs/plans/technical-debt.md`: TD-0009 (wire deploy workflows when consumer adopts a deploy platform), TD-0010 (wire smoke-test health endpoint).
- `CHANGELOG.md`: `### Added` Phase-5 entry.

## 7. Out of scope

- A working deploy (no platform/target). Container scan / IaC scan (still TD-0005). DAST / performance gates / canary / blue-green / DR validation (Level-3, later). Production observability wiring (Phase 6).

## 8. Assumptions

1. Template has no deployment target → deploy workflows are skeletons (consumer wires).
2. `build.yml` (Phase 2) produces a build artifact only when a stack is adopted; until then, `artifact-attestation.yml` skips cleanly.
3. Releases happen on consumer-pushed `v*` tags; the template itself ships no tags.
4. SBOM generation works on the repo tree even without a build (anchore/sbom-action scans the filesystem).

## 9. Acceptance criteria

Phase 5 is complete when:
- All 7 workflows exist, SHA-pinned (resolved via `gh api`), least-privilege, with timeouts + concurrency.
- `sbom.yml` runs on push to main and produces an SPDX artifact.
- `artifact-attestation.yml` runs after `build.yml` and skips cleanly when no artifact (empty template).
- `release.yml` triggers on `v*` tags (verified by syntax; not triggered on the empty template).
- `deploy-development/staging/production.yml` + `smoke-test.yml` are skeletons that run on `workflow_dispatch` and print clear "not configured" messages.
- `docs/operations/*`, AGENTS.md, technical-debt (TD-0009/0010), CHANGELOG updated.
- All Phase-1/2/3/4 checks remain green.
- PR opened on a feature branch, all checks pass, owner merges to `main`.
