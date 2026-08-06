# Phase 5 — Delivery pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Level-2 delivery pipeline: SBOM, artifact attestation, and release workflows (real, run on the repo) plus three deploy workflows + smoke-test (skeletons — no deploy target in the template).

**Architecture:** Real workflows (sbom/attestation/release) operate on the repo tree / build artifact directly. Skeleton workflows (deploy-dev/staging/production, smoke-test) are `workflow_dispatch` with commented OIDC + config steps that print a clear "not configured" message. Production deploy points at a `production` GitHub Environment (human gate).

**Tech Stack:** GitHub Actions (YAML), `anchore/sbom-action`, `actions/attest-build-provenance`, `softprops/action-gh-release`, `actions/download-artifact`.

**Reference spec:** `docs/superpowers/specs/2026-08-06-phase5-delivery-pipeline-design.md` (authoritative).

## Global Constraints

- **No deploy target in the template** → deploy workflows are skeletons (`workflow_dispatch`, commented OIDC, `echo "not configured"`).
- **Workflow security:** least-privilege; `contents: write` only where a step creates a release; `id-token: write` only for attestation/OIDC; SHA-pin every `uses:` via `gh api`.
- **Graceful on empty template:** `artifact-attestation.yml` must skip cleanly when no build artifact exists (guard via `hashFiles`); `release.yml` only triggers on `v*` tags (none in the template); `sbom.yml` runs on the repo tree.
- **Production human-gated:** `deploy-production.yml` uses `environment: production` (GitHub Environment required reviewers — consumer enables in UI).
- Build on branch `phase-5-delivery-pipeline` (created; spec at `1d8dd5f`). Base = `main` (`a607d76`). No direct push to `main`.

## File Structure

| Task | Cohesion | Key files |
|---|---|---|
| 1 | Real delivery workflows | `.github/workflows/{sbom,artifact-attestation,release}.yml` |
| 2 | Skeleton deploy + smoke workflows | `.github/workflows/{deploy-development,deploy-staging,deploy-production,smoke-test}.yml` |
| 3 | Docs + debt + changelog + PR | `AGENTS.md`, `docs/operations/*`, `docs/plans/technical-debt.md`, `CHANGELOG.md`, PR |

---

## Task 1: Real delivery workflows (sbom + attestation + release)

**Files:**
- Create: `.github/workflows/sbom.yml`
- Create: `.github/workflows/artifact-attestation.yml`
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `build.yml` (Phase 2) artifact for attestation; the repo tree for SBOM.
- Produces: SPDX SBOM artifact; Sigstore build-provenance; GitHub Release on `v*` tags.

**Critical:** resolve every `uses:` SHA via `gh api` before writing. For each action+tag:
```sh
repo="anchore/sbom-action"; tag="v0.20.0"   # discover latest stable at impl time
t=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.sha')
ty=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.type')
if [ "$ty" = "tag" ]; then gh api "repos/$repo/git/tags/$t" --jq '.object.sha'; else echo "$t"; fi
```
Verify with `gh api repos/<repo>/git/commits/<sha>` (HTTP 200).

- [ ] **Step 1: Resolve & record SHAs** for: `actions/checkout` (known: `3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`), `anchore/sbom-action` (latest stable), `actions/attest-build-provenance` (latest stable), `actions/download-artifact` (latest stable), `softprops/action-gh-release` (latest stable).

- [ ] **Step 2: Create `.github/workflows/sbom.yml`:**
```yaml
name: sbom

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  sbom:
    name: Generate SPDX SBOM
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Generate SBOM
        uses: anchore/sbom-action@<SHA> # <tag>
        with:
          format: spdx-json
          output-file: sbom.spdx.json
          upload-artifact: true
```

- [ ] **Step 3: Create `.github/workflows/artifact-attestation.yml`:**
```yaml
name: artifact-attestation

# Generates Sigstore build-provenance for the build artifact produced by
# build.yml. Skips cleanly when no artifact exists (empty template / stack
# unknown) via the hashFiles guard.
on:
  workflow_run:
    workflows: [build]
    types: [completed]
  workflow_dispatch:

permissions:
  contents: read
  id-token: write      # required for attestation
  attestations: write  # required to write attestations

concurrency:
  group: ${{ github.workflow }}-${{ github.event.workflow_run.id || github.run_id }}
  cancel-in-progress: true

jobs:
  attest:
    name: Attest build provenance
    runs-on: ubuntu-latest
    timeout-minutes: 10
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Download build artifact
        uses: actions/download-artifact@<SHA> # <tag>
        with:
          name: build-unknown   # matches the upload name in build.yml (Phase 2)
          path: artifact
        continue-on-error: true   # no artifact on empty template

      - name: Skip (no build artifact)
        if: hashFiles('artifact/**') == ''
        run: echo "No build artifact to attest (empty template / stack unknown). Skipping."

      - name: Attest build provenance
        if: hashFiles('artifact/**') != ''
        uses: actions/attest-build-provenance@<SHA> # <tag>
        with:
          subject-path: artifact/**
```

- [ ] **Step 4: Create `.github/workflows/release.yml`:**
```yaml
name: release

on:
  push:
    tags:
      - "v*"
  workflow_dispatch:

permissions:
  contents: write     # create the release
  id-token: write     # attestation (future)

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  release:
    name: Draft GitHub Release
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Generate SBOM
        uses: anchore/sbom-action@<SHA> # <tag>
        with:
          format: spdx-json
          output-file: sbom.spdx.json
          upload-artifact: false   # attached to the release instead

      - name: Compute digest
        run: |
          sha256sum sbom.spdx.json > sbom.spdx.json.sha256
          echo "Digest computed."

      - name: Create release
        uses: softprops/action-gh-release@<SHA> # <tag>
        with:
          generate_release_notes: true   # uses commit/PR history + .github/release.yml categories
          files: |
            sbom.spdx.json
            sbom.spdx.json.sha256
```

- [ ] **Step 5: Verify** — YAML validity + all SHAs resolve via `gh api`.

- [ ] **Step 6: Commit**
```sh
git add .github/workflows/sbom.yml .github/workflows/artifact-attestation.yml .github/workflows/release.yml
git commit -m "ci: add Phase-5 delivery workflows (SBOM, attestation, release)"
```

---

## Task 2: Skeleton deploy + smoke-test workflows

**Files:**
- Create: `.github/workflows/deploy-development.yml`
- Create: `.github/workflows/deploy-staging.yml`
- Create: `.github/workflows/deploy-production.yml`
- Create: `.github/workflows/smoke-test.yml`

**Interfaces:**
- Consumes: nothing (skeletons).
- Produces: 4 `workflow_dispatch` workflows that print a clear "not configured" message + document OIDC/wiring in comments.

- [ ] **Step 1: Create `.github/workflows/deploy-development.yml`:**
```yaml
name: deploy-development

# SKELETON. The template has no deployment target. Wire your platform's OIDC
# auth + deploy action (e.g. aws-actions/configure-aws-credentials + deploy,
# flyctl-actions/flyctl-deploy, cloudrun, etc.). Create a `development`
# GitHub Environment (Settings → Environments) for env-specific secrets.
on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write   # for OIDC to your cloud (no long-lived credentials)

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false

jobs:
  deploy:
    name: Deploy to development (skeleton)
    runs-on: ubuntu-latest
    timeout-minutes: 20
    environment: development
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      # --- Consumer wires deploy below ---
      # - name: Configure cloud credentials (OIDC)
      #   uses: aws-actions/configure-aws-credentials@<sha>
      #   with:
      #     role-to-assume: arn:aws:iam::<account>:role/<role>
      #     aws-region: <region>
      # - name: Deploy
      #   run: <your deploy command>
      - name: Not configured
        run: echo "Deploy target not configured — implement deploy steps for your platform. See AGENTS.md and docs/operations/deployment-guide.md."
```

- [ ] **Step 2: Create `.github/workflows/deploy-staging.yml`** (same structure as development; `environment: staging`, protected — consumer enables required reviewers in Environment settings):
```yaml
name: deploy-staging

# SKELETON. Wire your staging platform + OIDC. Create a `staging` GitHub
# Environment and enable required reviewers for protection.
on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false

jobs:
  deploy:
    name: Deploy to staging (skeleton)
    runs-on: ubuntu-latest
    timeout-minutes: 25
    environment: staging
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      # --- Consumer wires deploy + artifact-digest verification below ---
      - name: Not configured
        run: echo "Deploy target not configured — implement deploy steps + verify the artifact digest matches development/staging. See docs/operations/deployment-guide.md."
```

- [ ] **Step 3: Create `.github/workflows/deploy-production.yml`** (human-gated via the `production` Environment):
```yaml
name: deploy-production

# SKELETON. Production is HUMAN-GATED: the `production` GitHub Environment
# must have Required Reviewers enabled (Settings → Environments → production).
# Per AGENTS.md/spec §2.6, AI agents must not deploy to production without
# Environment approval + human + verified artifact + documented rollback.
on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false   # never cancel an in-flight production deploy

jobs:
  deploy:
    name: Deploy to production (skeleton, human-gated)
    runs-on: ubuntu-latest
    timeout-minutes: 45
    environment: production   # required reviewers enabled in Settings
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      # --- Consumer wires deploy below ---
      # VERIFY: artifact digest matches the staging artifact (spec §16, same artifact promoted).
      # AUTH: OIDC (no long-lived cloud credentials).
      # DOCUMENT: rollback procedure before deploying.
      - name: Not configured
        run: echo "Production deploy target not configured. Wire OIDC + deploy + verify artifact digest matches staging. Ensure the `production` Environment has Required Reviewers enabled."
```

- [ ] **Step 4: Create `.github/workflows/smoke-test.yml`:**
```yaml
name: smoke-test

# SKELETON. Consumer wires their health endpoint (e.g. GET /healthz). Callable
# after a deploy via workflow_call, or run manually.
on:
  workflow_dispatch:
  workflow_call:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  smoke:
    name: Post-deploy smoke test (skeleton)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      # --- Consumer wires smoke checks below ---
      # - name: Health check
      #   run: curl -fsS https://<your-app>/healthz
      - name: Not configured
        run: echo "Smoke target not configured — wire your health endpoint. See docs/operations/runbook.md."
```

- [ ] **Step 5: Verify** — YAML validity.

- [ ] **Step 6: Commit**
```sh
git add .github/workflows/deploy-development.yml .github/workflows/deploy-staging.yml .github/workflows/deploy-production.yml .github/workflows/smoke-test.yml
git commit -m "ci: add Phase-5 deploy + smoke-test skeletons (workflow_dispatch, OIDC-documented)"
```

---

## Task 3: Docs + debt + changelog + PR

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/operations/deployment-guide.md`
- Modify: `docs/operations/release-checklist-template.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update `AGENTS.md`** — under "Production restrictions", after the existing bullets, add:
```markdown
- **Phase 5 delivery pipeline:** `sbom.yml` (SPDX SBOM), `artifact-attestation.yml` (Sigstore build-provenance), and `release.yml` (on `v*` tag) are ACTIVE. The three `deploy-*.yml` workflows and `smoke-test.yml` are SKELETONS — wire them to your platform with OIDC when you adopt a deploy target. Production deploy points at the `production` GitHub Environment, which MUST have Required Reviewers enabled (human gate). See `docs/operations/deployment-guide.md`.
```

- [ ] **Step 2: Update `docs/operations/deployment-guide.md`** — append:
```markdown
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
```

- [ ] **Step 3: Update `docs/operations/release-checklist-template.md`** — confirm SBOM + attestation + digest are present; if not, add. The Phase-1 template already lists them; verify and augment the "staging validated with the same artifact" line if missing:
```markdown
- [ ] Staging validated with the same artifact (digest matches)
```
(Read the file first; only add what's missing.)

- [ ] **Step 4: Update `docs/plans/technical-debt.md`** — append two rows:
```markdown
| TD-0009 | The three deploy workflows (development/staging/production) and smoke-test are skeletons in Phase 5 — the template has no deploy target. Consumer wires platform OIDC + deploy steps + health endpoint when adopting a deploy target. | `.github/workflows/deploy-*.yml`, `.github/workflows/smoke-test.yml` | Open | When a deploy platform is adopted, uncomment the OIDC + deploy steps, create the GitHub Environments (development/staging/production), and enable Required Reviewers on production. |
| TD-0010 | Smoke-test has no wired health endpoint; consumer adds one per environment. | `.github/workflows/smoke-test.yml` | Open | Wire `curl <health-endpoint>` per environment when the app exists. |
```

- [ ] **Step 5: Update `CHANGELOG.md`** — prepend to `### Added`:
```markdown
- Phase 5 delivery pipeline: `sbom.yml` (SPDX), `artifact-attestation.yml` (Sigstore build-provenance, graceful-skip), `release.yml` (on `v*` tag with changelog + SBOM + digest), and `deploy-development/staging/production.yml` + `smoke-test.yml` skeletons (workflow_dispatch, OIDC-documented, production human-gated via GitHub Environment).
```

- [ ] **Step 6: Local verification**
```sh
make ci            # exit 0
make test-scripts  # passed=43 failed=0
make docs-check    # exit 0
/tmp/yamlcheck/bin/python -c "import yaml,glob; [list(yaml.safe_load_all(open(f))) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
# SHA resolves (loop) — all OK
```

- [ ] **Step 7: Commit + push + open PR**
```sh
git add AGENTS.md docs/operations/deployment-guide.md docs/operations/release-checklist-template.md docs/plans/technical-debt.md CHANGELOG.md
git commit -m "docs: document Phase-5 delivery pipeline, deploy skeletons, debt entries, changelog"
git push -u origin phase-5-delivery-pipeline
gh pr create --base main --head phase-5-delivery-pipeline \
  --title "feat: Phase 5 — delivery pipeline (SBOM + attestation + release; deploy skeletons)" \
  --body "<filled from .github/pull_request_template.md>"
```

- [ ] **Step 8: Verify PR checks** — expect: Phase-1/2/3/4 checks green; `sbom.yml` may trigger on push to the branch (push:main filter — confirm it doesn't run on a PR branch, or runs and passes on the repo tree); release/tag/attestation workflows not triggered on PR (tag-only / workflow_run). Report actual results; fix any failure from logs.

- [ ] **Step 9: Hand off** — report PR URL + check status to the owner for merge.

---

## Self-Review (run after writing)

**1. Spec coverage:**
- sbom.yml (real) → Task 1 ✓
- artifact-attestation.yml (real, graceful-skip) → Task 1 ✓
- release.yml (real, on tag) → Task 1 ✓
- deploy-development/staging/production.yml (skeleton, prod human-gated) → Task 2 ✓
- smoke-test.yml (skeleton) → Task 2 ✓
- AGENTS.md / deployment-guide / release-checklist / TD-0009-0010 / CHANGELOG → Task 3 ✓

**2. Placeholder scan:** the `<SHA> # <tag>` markers in Task 1 are "resolve at implementation time" backed by a concrete resolution step (Step 1). The commented `# - name: Configure cloud credentials` blocks in Task 2 are documented consumer wiring (skeleton by design), not plan-failure placeholders. ✓

**3. Consistency:** deploy skeleton pattern (`workflow_dispatch`, `environment: <env>`, commented OIDC, `echo "not configured"`) consistent across Task 2 + Task 3 docs. `id-token: write` present wherever OIDC/attestation needs it. `production` Environment Required Reviewers requirement stated in Task 2 + Task 3 docs + spec. ✓

No gaps found.
