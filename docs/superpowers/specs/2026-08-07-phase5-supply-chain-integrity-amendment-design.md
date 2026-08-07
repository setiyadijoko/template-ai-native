# Phase 5 Supply-Chain Integrity Amendment Design

**Status:** Approved for implementation

**Date:** 2026-08-07

**Owner:** Template maintainers

**Amends:** `2026-08-06-phase5-delivery-pipeline-design.md`

## Executive summary

Phase 5 currently defines build, attestation, and release as separate workflows,
but the implemented hand-off does not preserve artifact identity across those
boundaries. The attestation workflow requests a fixed `build-unknown` artifact
without identifying the originating workflow run, while the release workflow
publishes only an SBOM and checksum rather than the artifact that passed CI.

This amendment makes the supply-chain path fail closed:

1. a successful CI run builds one packaged artifact for a detected stack;
2. that same CI run attests the exact uploaded artifact bytes;
3. a version tag releases the artifact from a successful CI run for the exact
   tagged commit, without rebuilding it; and
4. an empty template repository may release a source archive only when stack
   detection returns `unknown`.

Deployment and smoke-test workflows remain skeletons. No production deployment,
environment configuration, or Phase 6 capability is introduced.

## Business objective

Provide auditable evidence that a released artifact is the same artifact that
passed the governed CI path. This reduces release substitution risk, prevents a
tag workflow from silently rebuilding different bytes, and gives adopters a
safe baseline before they connect the template to a deployment platform.

## Scope

### In scope

- Stable build-artifact identity and reusable-workflow outputs.
- Same-run GitHub artifact attestation on pushes to `main`.
- Exact-commit CI provenance checks before a tagged release.
- No-rebuild release packaging.
- A source-archive fallback for the stack-agnostic empty-template state only.
- Release SBOM and SHA-256 digest generation.
- POSIX shell contract tests for the workflow topology and fail-closed rules.
- Phase 5 operations documentation and changelog updates.

### Out of scope

- Wiring `deploy-development.yml`, `deploy-staging.yml`, or
  `deploy-production.yml` to a platform.
- Converting `smoke-test.yml` from a skeleton into an active test.
- Creating GitHub Environments or changing repository protection settings.
- Phase 6 observability, incident, or operational automation.
- Selecting a programming language or framework for `src/`.

## Current-state defect

The original Phase 5 design requires cross-run artifact download metadata, but
the current implementation omits the originating run identifier and token. It
also uses the literal artifact name `build-unknown`, although known-stack builds
upload `build-<stack>`. The download is allowed to fail, so attestation may be
skipped without failing the workflow. Separately, the release workflow does not
retrieve or publish the artifact produced by CI.

The result is a broken chain of custody:

```text
build bytes  -X->  attestation subject  -X->  released artifact
```

## Approved architecture

### CI and attestation path

```text
push / pull request
        |
        v
     detect stack
        |
        v
  build known stack ----> package + upload build-<stack>
        |                       |
        +---- output metadata --+
                                |
                 push to main only
                                v
                  attest exact artifact bytes
```

`ci.yml` remains the dispatcher. `build.yml` exposes the artifact name and an
`artifact-uploaded` output. `artifact-attestation.yml` becomes a reusable
workflow called from the same CI run, removing the cross-run `workflow_run`
boundary.

Pull requests run quality, test, and build checks but do not mint attestations.
Attestation runs only after a successful push build on `main`, where the
repository-controlled commit and required `id-token: write` permission are
appropriate.

### Release path

```text
v* tag
  |
  v
resolve tagged commit SHA
  |
  v
require successful ci.yml push run for the exact SHA
  |
  +-- exactly one valid build-* artifact --> download exact CI bytes
  |
  +-- no artifact + detected stack unknown --> git source archive
  |
  +-- any other state ----------------------> fail release
  |
  v
generate SBOM + digests.txt
  |
  v
publish artifact + SBOM + digests
```

The tag workflow never invokes the stack build command. For a known stack, it
renames the single packaged file downloaded from CI for the versioned release;
the file bytes do not change. For the empty-template state,
`scripts/detect-stack.sh` must return `unknown` before a source archive is
permitted.

## Component design

### `.github/workflows/build.yml`

- Continue accepting the detected stack as input.
- Require at least one supported output path after the stack build command. A
  known stack that produces no output fails the build.
- Package the supported outputs into one deterministic
  `template-ai-native-build-<stack>.tar.gz` file, then upload that file as the
  Actions artifact `build-<stack>`.
- Expose workflow outputs:
  - `artifact-name`: the uploaded artifact name;
  - `artifact-uploaded`: string form of the successful upload state.
- Do not use the empty-template source archive as a fallback for a known stack.

### `.github/workflows/ci.yml`

- Preserve the existing detect, quality, test, and build jobs.
- Call the reusable attestation workflow with the build outputs.
- Gate attestation to a `push` on `refs/heads/main`.
- Require successful stack detection and either a successful known-stack build
  or a legitimately skipped build for stack `unknown`.
- Do not grant attestation permissions to pull-request jobs.

For `unknown`, the reusable workflow receives `artifact-uploaded: false` and
performs an explicit, successful no-artifact skip. It does not invent an
artifact name or create an attestation.

### `.github/workflows/artifact-attestation.yml`

- Use `workflow_call` rather than `workflow_run`.
- Accept `artifact-name` and `artifact-uploaded` inputs.
- Use least-privilege permissions: `contents: read`, `id-token: write`, and
  `attestations: write`.
- When an artifact exists, validate the name against
  `build-(python|node|go|java|dotnet)` and download it from the current run.
- Attest the downloaded `template-ai-native-build-<stack>.tar.gz` file with the
  SHA-pinned `actions/attest-build-provenance` action.
- Fail on invalid names, download errors, or attestation errors. No
  `continue-on-error` is allowed on the integrity path.
- Never reference `build-unknown`.

### `.github/workflows/release.yml`

- Trigger only on `v*` tags. Remove manual dispatch so a release cannot bypass
  the immutable version-tag contract.
- Grant `contents: write` for the GitHub Release and `actions: read` for CI run
  and artifact lookup. Do not request an OIDC token in this workflow.
- Resolve a completed, successful `ci.yml` run whose event is `push` and whose
  `head_sha` exactly matches the tagged commit.
- Inspect artifacts from that run and accept exactly one non-expired artifact
  whose name matches `build-(python|node|go|java|dotnet)`.
- Fail on no matching successful CI run, expired artifacts, invalid names,
  multiple matching artifacts, or download failure.
- Permit no-artifact fallback only when the exact tagged tree causes
  `scripts/detect-stack.sh` to return `unknown`; create the fallback with
  `git archive`.
- Never execute `scripts/stack-tools.sh build` or an equivalent rebuild command.
- Rename the downloaded package to `template-ai-native-<tag>.tar.gz` without
  modifying its bytes.
- Publish three assets:
  1. `template-ai-native-<tag>.tar.gz`;
  2. `sbom.spdx.json`; and
  3. `digests.txt`, containing SHA-256 digests for the release artifact and SBOM.

## Security and trust boundaries

- The repository is public, enabling GitHub-native artifact attestations without
  requiring GitHub Enterprise Cloud for a private repository.
- Removing `workflow_run` avoids a privileged cross-workflow hand-off and keeps
  artifact identity within one CI run.
- Pull-request code cannot request the attestation OIDC token.
- Release lookup is constrained by repository, workflow filename, successful
  conclusion, `push` event, and exact commit SHA.
- Artifact names are allowlisted; ambiguity or missing evidence stops release.
- Every third-party GitHub Action remains pinned to an immutable commit SHA with
  its human-readable release tag documented in a comment.
- No secret or long-lived cloud credential is introduced.

## Contract-test design

Add `scripts/test/test-delivery-workflows.sh` and run it from
`make test-scripts`. The test is structural because the repository template has
no adopted runtime stack and CI topology is the public contract being changed.

The contract test asserts:

- `build.yml` declares dynamic artifact outputs and a known-stack missing-output
  failure path;
- `ci.yml` orders attestation after build, passes artifact metadata, and limits
  it to pushes on `main`;
- `artifact-attestation.yml` is reusable, contains the minimum permissions,
  rejects invalid names, and contains no `workflow_run`, `build-unknown`, or
  `continue-on-error` integrity bypass;
- `release.yml` requires an exact-SHA successful CI run, downloads and only
  renames the packaged CI file, has no stack build invocation, constrains the
  source fallback to `unknown`, and publishes the artifact, SBOM, and digest
  manifest; and
- all third-party actions in the affected workflows are SHA pinned.

The contract test is written first and must fail against the current workflow
topology before implementation begins.

## Documentation changes

- Keep the original Phase 5 design as historical context and treat this document
  as the authoritative amendment for build, attestation, and release topology.
- Update `docs/operations/deployment-guide.md` with the exact-artifact release
  path and the empty-template fallback.
- Add the repair under `CHANGELOG.md` → `Unreleased`.
- Leave deploy and smoke-test documentation explicitly marked as skeletons.

## Acceptance criteria

1. A known-stack push to `main` uploads one named build artifact and attests the
   downloaded bytes in the same CI run.
2. A known-stack build that produces no supported artifact fails.
3. Pull requests do not receive attestation write or OIDC permissions.
4. A tag release fails unless a successful `ci.yml` push run exists for the
   exact tagged SHA.
5. A known-stack release downloads the single valid CI package, changes no file
   bytes, and never rebuilds it.
6. An empty-template release may use `git archive` only when stack detection for
   the tagged tree returns `unknown`.
7. The release attaches the artifact, SPDX SBOM, and SHA-256 digest manifest.
8. Integrity-critical failures are blocking; no relevant step uses
   `continue-on-error`.
9. Contract tests cover the workflow topology and pass through
   `make test-scripts`.
10. `make ci`, `make docs-check`, workflow syntax validation, action pin checks,
    and `git diff --check` pass.
11. Deploy and smoke-test workflows have no behavioral changes.

## Verification plan

Run and record actual results for:

```bash
make test-scripts
make ci
make docs-check
actionlint .github/workflows/*.yml
git diff --check
```

Also inspect the complete diff and confirm that no build, deploy, or release is
fabricated. A test tag or production release is not created as part of this
change; live release execution remains an authorized maintainer action.

## Rollback

Revert the implementation commit to restore the prior workflow topology. This
change creates no deployment and modifies no production data. If a release
fails after adoption, retain the failed run as audit evidence, correct the
workflow through a reviewed change, and create a new immutable tag rather than
moving an existing tag.
