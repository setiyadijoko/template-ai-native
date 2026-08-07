# Phase 5 Supply-Chain Integrity Amendment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the governed `build → attestation → release` chain so a version
release publishes the exact packaged bytes produced by a successful CI run for
the tagged commit, while deploy and smoke-test workflows remain unchanged
skeletons.

**Architecture:** `ci.yml` calls `build.yml`, receives stable artifact metadata,
and invokes `artifact-attestation.yml` in the same push-to-main run. A tag-only
`release.yml` resolves a successful `ci.yml` push run for the exact tag SHA,
downloads its single allowlisted artifact, and releases those bytes without a
rebuild; only a detected `unknown` stack may use `git archive`.

**Tech Stack:** GitHub Actions YAML, POSIX shell contract tests, Bash on GitHub
hosted runners, GitHub CLI/API, SHA-pinned GitHub Actions.

**Reference spec:**
`docs/superpowers/specs/2026-08-07-phase5-supply-chain-integrity-amendment-design.md`

## Global Constraints

- Test-first: each workflow behavior is added to
  `scripts/test/test-delivery-workflows.sh` and observed failing before the
  corresponding workflow is changed.
- Build artifact action name is exactly `build-<stack>` where stack is one of
  `python`, `node`, `go`, `java`, or `dotnet`.
- Packaged file name is exactly
  `template-ai-native-build-<stack>.tar.gz`.
- Known-stack builds fail when no supported output is present.
- Attestation is called from the same CI run, only for pushes to `main`; pull
  requests receive no OIDC or attestation write permission.
- Tag releases require a successful `ci.yml` run with `event=push` and an exact
  `head_sha` match.
- Release never invokes `scripts/stack-tools.sh build` or another build command.
- Source-archive fallback is allowed only when `scripts/detect-stack.sh` returns
  `unknown` for the checked-out tag.
- All third-party GitHub Actions remain pinned to 40-character commit SHAs.
- `.github/workflows/deploy-development.yml`, `deploy-staging.yml`,
  `deploy-production.yml`, and `smoke-test.yml` must remain byte-for-byte
  unchanged.
- No live tag, GitHub Release, environment, deployment, or smoke test is created.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/test/test-delivery-workflows.sh` | Executable contract for the four delivery workflows and action pinning |
| `Makefile` | Runs the delivery contract from `make test-scripts` |
| `.github/workflows/build.yml` | Builds, validates output, packages one immutable file, and exports artifact metadata |
| `.github/workflows/ci.yml` | Dispatches same-run attestation on governed pushes |
| `.github/workflows/artifact-attestation.yml` | Downloads and attests the current run's packaged file |
| `.github/workflows/release.yml` | Resolves exact-SHA CI evidence and releases without rebuild |
| `docs/operations/deployment-guide.md` | Documents active integrity chain and unchanged skeleton boundary |
| `CHANGELOG.md` | Records the P0 repair under `Unreleased` |

---

### Task 1: Contract-test and repair build-to-attestation

**Files:**

- Create: `scripts/test/test-delivery-workflows.sh`
- Modify: `Makefile`
- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/artifact-attestation.yml`

**Interfaces:**

- Consumes: `needs.detect.outputs.stack` from `ci.yml` and supported build output
  paths (`dist`, `build`, `bin`, Maven/Gradle JARs, .NET Release files).
- Produces: reusable-workflow outputs `artifact-name: string` and
  `artifact-uploaded: string`; Actions artifact `build-<stack>` containing one
  `template-ai-native-build-<stack>.tar.gz` file.

- [ ] **Step 1: Write the failing build/attestation contract test**

Create `scripts/test/test-delivery-workflows.sh` with local text-contract helpers
that update the shared `PASS` and `FAIL` counters:

```sh
#!/usr/bin/env sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

BUILD="$ROOT/.github/workflows/build.yml"
CI="$ROOT/.github/workflows/ci.yml"
ATTEST="$ROOT/.github/workflows/artifact-attestation.yml"
RELEASE="$ROOT/.github/workflows/release.yml"

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_contains "build exports artifact name" "$BUILD" 'artifact-name:'
assert_contains "build exports upload state" "$BUILD" 'artifact-uploaded:'
assert_contains "build packages one file" "$BUILD" 'template-ai-native-build-.*\.tar\.gz'
assert_contains "build fails without output" "$BUILD" 'No supported build output found'
assert_contains "upload fails without package" "$BUILD" 'if-no-files-found: error'

assert_contains "ci calls attestation" "$CI" 'uses: ./\.github/workflows/artifact-attestation\.yml'
assert_contains "ci attestation needs build" "$CI" 'needs: \[detect, build\]'
assert_contains "ci passes artifact name" "$CI" 'artifact-name:.*needs\.build\.outputs\.artifact-name'
assert_contains "ci passes upload state" "$CI" 'artifact-uploaded:.*needs\.build\.outputs\.artifact-uploaded'
assert_contains "ci limits attestation to push" "$CI" "github\.event_name == 'push'"
assert_contains "ci limits attestation to main" "$CI" "github\.ref == 'refs/heads/main'"

assert_contains "attestation is reusable" "$ATTEST" 'workflow_call:'
assert_contains "attestation accepts name" "$ATTEST" 'artifact-name:'
assert_contains "attestation accepts upload state" "$ATTEST" 'artifact-uploaded:'
assert_contains "attestation validates name" "$ATTEST" 'build-\(python\|node\|go\|java\|dotnet\)'
assert_contains "attestation writes provenance" "$ATTEST" 'attestations: write'
assert_contains "attestation receives OIDC" "$ATTEST" 'id-token: write'
assert_not_contains "attestation has no workflow_run" "$ATTEST" 'workflow_run:'
assert_not_contains "attestation has no fabricated unknown artifact" "$ATTEST" 'build-unknown'
assert_not_contains "attestation has no integrity bypass" "$ATTEST" 'continue-on-error:'

report
```

Modify `Makefile` so the always-on target executes both suites:

```make
test-scripts:
	@sh scripts/test/test-stack-detection.sh
	@sh scripts/test/test-delivery-workflows.sh
```

- [ ] **Step 2: Run the contract and verify RED**

Run: `make test-scripts`

Expected: `test-stack-detection.sh` reports `passed=43 failed=0`; the delivery
contract exits non-zero with failures for missing workflow outputs, same-run
attestation wiring, and the existing forbidden `workflow_run`, `build-unknown`,
and `continue-on-error` entries.

- [ ] **Step 3: Implement minimal build artifact packaging and outputs**

In `.github/workflows/build.yml`:

1. Add `workflow_call.outputs` sourced from `jobs.build.outputs`.
2. Add job outputs sourced from a packaging step with `id: artifact`.
3. Validate `inputs.stack` against the five supported values using an `env:
   STACK` variable and a shell `case` statement.
4. After the existing build, use Bash arrays to collect stack-specific outputs:

```bash
case "$STACK" in
  python) [ -d dist ] && inputs+=(dist) ;;
  node)
    [ -d dist ] && inputs+=(dist)
    [ -d build ] && inputs+=(build)
    ;;
  go) [ -d bin ] && inputs+=(bin) ;;
  java)
    while IFS= read -r -d '' path; do inputs+=("$path"); done < <(
      find . -type f \( -path '*/target/*.jar' -o -path '*/build/libs/*.jar' \) -print0
    )
    ;;
  dotnet)
    while IFS= read -r -d '' path; do inputs+=("$path"); done < <(
      find . -type f -path '*/bin/Release/*' -print0
    )
    ;;
esac

if [ "${#inputs[@]}" -eq 0 ]; then
  echo "::error::No supported build output found for stack $STACK"
  exit 1
fi
```

5. Create `release/template-ai-native-build-${STACK}.tar.gz` with GNU tar's
   sorted entries, normalized timestamps, numeric owner/group zero, and gzip.
6. Set step outputs `name=build-${STACK}` and `uploaded=true`.
7. Upload only the packaged tarball with `if-no-files-found: error`.

- [ ] **Step 4: Implement same-run CI attestation dispatch**

Append a reusable-workflow job to `.github/workflows/ci.yml`:

```yaml
  attest:
    name: Attest build provenance
    needs: [detect, build]
    if: >-
      always() &&
      github.event_name == 'push' &&
      github.ref == 'refs/heads/main' &&
      needs.detect.result == 'success' &&
      (needs.build.result == 'success' ||
      (needs.build.result == 'skipped' &&
      needs.detect.outputs.stack == 'unknown'))
    permissions:
      contents: read
      id-token: write
      attestations: write
    uses: ./.github/workflows/artifact-attestation.yml
    with:
      artifact-name: ${{ needs.build.outputs.artifact-name || '' }}
      artifact-uploaded: ${{ needs.build.outputs.artifact-uploaded == 'true' }}
```

- [ ] **Step 5: Convert attestation to a fail-closed reusable workflow**

Replace the triggers and steps in `.github/workflows/artifact-attestation.yml`:

```yaml
on:
  workflow_call:
    inputs:
      artifact-name:
        type: string
        required: false
        default: ""
      artifact-uploaded:
        type: boolean
        required: true
```

Keep `contents: read`, `id-token: write`, and `attestations: write`. Add an
explicit skip step for `artifact-uploaded == false`. For a present artifact,
validate `inputs.artifact-name` through an environment variable against
`^build-(python|node|go|java|dotnet)$`, download it from the current run, require
exactly one `template-ai-native-build-*.tar.gz` file, and pass that exact path to
the pinned `actions/attest-build-provenance` action. Do not use checkout,
`workflow_run`, `build-unknown`, or `continue-on-error`.

- [ ] **Step 6: Run the focused contract and verify GREEN**

Run: `sh scripts/test/test-delivery-workflows.sh`

Expected: all build/CI/attestation assertions pass and `failed=0`.

- [ ] **Step 7: Run regression and workflow syntax checks**

Run:

```bash
make test-scripts
actionlint .github/workflows/build.yml \
  .github/workflows/ci.yml \
  .github/workflows/artifact-attestation.yml
git diff --check
```

Expected: 43 existing stack assertions pass, all delivery assertions pass,
actionlint exits zero, and diff check is empty.

- [ ] **Step 8: Commit the independently green chain**

```bash
git add Makefile scripts/test/test-delivery-workflows.sh \
  .github/workflows/build.yml .github/workflows/ci.yml \
  .github/workflows/artifact-attestation.yml
git commit -m "ci: repair build attestation chain"
```

---

### Task 2: Contract-test and repair exact-artifact release

**Files:**

- Modify: `scripts/test/test-delivery-workflows.sh`
- Modify: `.github/workflows/release.yml`

**Interfaces:**

- Consumes: GitHub Actions run records for workflow `ci.yml`, exact
  `GITHUB_SHA`, detected stack, and Actions artifact `build-<stack>`.
- Produces: `template-ai-native-<tag>.tar.gz`, `sbom.spdx.json`, and
  `digests.txt` attached to the GitHub Release.

- [ ] **Step 1: Append failing release and pinning assertions**

Before `report` in `scripts/test/test-delivery-workflows.sh`, add assertions for:

```sh
assert_not_contains "release has no manual bypass" "$RELEASE" 'workflow_dispatch:'
assert_contains "release reads Actions evidence" "$RELEASE" 'actions: read'
assert_contains "release queries ci workflow" "$RELEASE" 'actions/workflows/ci\.yml/runs'
assert_contains "release filters exact SHA" "$RELEASE" 'head_sha=.*GITHUB_SHA'
assert_contains "release filters push event" "$RELEASE" 'event=push'
assert_contains "release requires success" "$RELEASE" 'conclusion.*success'
assert_contains "release maps artifact to stack" "$RELEASE" 'expected_artifact="build-\$stack"'
assert_contains "release downloads prior run" "$RELEASE" 'run-id:.*steps\..*\.outputs\.run-id'
assert_contains "release authorizes prior-run download" "$RELEASE" 'github-token:.*github\.token'
assert_contains "release permits unknown source archive" "$RELEASE" 'git archive'
assert_contains "release creates digest manifest" "$RELEASE" 'digests\.txt'
assert_contains "release publishes versioned package" "$RELEASE" 'template-ai-native-.*\.tar\.gz'
assert_not_contains "release does not rebuild" "$RELEASE" 'stack-tools\.sh build'
assert_not_contains "release does not request OIDC" "$RELEASE" 'id-token: write'
```

Add an `assert_action_pins` helper that scans `uses:` entries in `BUILD`, `CI`,
`ATTEST`, and `RELEASE`, exempts local paths beginning `./`, and fails any
third-party reference that does not match `@[0-9a-f]{40}`.

- [ ] **Step 2: Run the contract and verify RED**

Run: `sh scripts/test/test-delivery-workflows.sh`

Expected: non-zero exit with release failures for manual dispatch, missing
Actions read permission, missing exact-SHA CI lookup/download, missing release
artifact, and existing OIDC permission.

- [ ] **Step 3: Implement exact-SHA CI evidence resolution**

In `.github/workflows/release.yml`:

1. Remove `workflow_dispatch`; keep only `push.tags: ["v*"]`.
2. Set permissions to `contents: write` and `actions: read`.
3. Checkout the exact tag SHA and run `scripts/detect-stack.sh` into a step
   output.
4. With `GH_TOKEN: ${{ github.token }}`, query:

```text
repos/${GITHUB_REPOSITORY}/actions/workflows/ci.yml/runs
  ?head_sha=${GITHUB_SHA}&event=push&status=completed&per_page=100
```

5. Select the newest run whose `conclusion` is `success`; fail if none exists.
6. Query that run's artifacts. For a known stack, require exactly one
   non-expired artifact and require its name to equal `build-$stack`. For
   `unknown`, require zero allowlisted build artifacts.
7. Export `run-id`, `artifact-name`, and `artifact-present` step outputs.

- [ ] **Step 4: Implement no-rebuild release asset preparation**

Use the pinned `actions/download-artifact` only when `artifact-present` is true,
passing both `github-token: ${{ github.token }}` and the resolved `run-id`.
Then:

- for a known stack, require exactly one downloaded file named
  `template-ai-native-build-<stack>.tar.gz` and rename it to
  `template-ai-native-${GITHUB_REF_NAME}.tar.gz`;
- for `unknown`, create the same versioned filename with `git archive`, using a
  versioned directory prefix;
- write the final filename to a step output.

- [ ] **Step 5: Publish SBOM and digest manifest with the artifact**

Keep the pinned Anchore SBOM action. Replace the single-SBOM checksum with:

```bash
sha256sum "$RELEASE_ASSET" sbom.spdx.json > digests.txt
```

Pass exactly these assets to the pinned release action:

```yaml
files: |
  ${{ steps.asset.outputs.path }}
  sbom.spdx.json
  digests.txt
```

- [ ] **Step 6: Run the focused contract and verify GREEN**

Run: `sh scripts/test/test-delivery-workflows.sh`

Expected: all delivery assertions and action-pin assertions pass with
`failed=0`.

- [ ] **Step 7: Run release workflow syntax and diff checks**

Run:

```bash
actionlint .github/workflows/release.yml
make test-scripts
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 8: Commit the independently green release repair**

```bash
git add scripts/test/test-delivery-workflows.sh .github/workflows/release.yml
git commit -m "ci: release exact verified artifact"
```

---

### Task 3: Synchronize operations documentation and verify the complete P0

**Files:**

- Modify: `docs/operations/deployment-guide.md`
- Modify: `CHANGELOG.md`

**Interfaces:**

- Consumes: final behavior of build, attestation, and release workflows.
- Produces: operator-facing chain-of-custody instructions without changing the
  deployment skeleton contract.

- [ ] **Step 1: Update the deployment workflow status table**

Change the active workflow rows to state:

```markdown
| `sbom.yml` | Active | Generates an SPDX SBOM on pushes to `main`; release also generates the SBOM attached to a version tag. |
| `artifact-attestation.yml` | Active | Reusable, fail-closed provenance for the packaged artifact in the same successful push-to-`main` CI run; empty templates skip explicitly. |
| `release.yml` | Active | On `v*`, requires a successful exact-SHA `ci.yml` push run and publishes its packaged artifact without rebuilding, plus SBOM and digests. |
```

Add a short `Release chain of custody` subsection describing the known-stack
artifact path, the `unknown`-only source fallback, and the rule that absent,
expired, ambiguous, or mismatched CI evidence blocks release. Leave every deploy
and smoke-test row unchanged.

- [ ] **Step 2: Record the repair in the changelog**

Add a `### Fixed` section under `Unreleased`:

```markdown
- Repaired the Phase 5 build-to-release chain: same-run provenance attestation,
  exact-commit CI artifact promotion without rebuild, fail-closed artifact
  validation, and delivery workflow contract tests. Deploy and smoke-test
  workflows remain skeletons.
```

Replace the old Phase 5 `Added` wording that says attestation gracefully skips
when an artifact download fails; retain the factual list of Phase 5 workflows.

- [ ] **Step 3: Prove deploy and smoke workflows are untouched**

Run:

```bash
git diff ae28e18 --name-only -- \
  .github/workflows/deploy-development.yml \
  .github/workflows/deploy-staging.yml \
  .github/workflows/deploy-production.yml \
  .github/workflows/smoke-test.yml
```

Expected: no output.

- [ ] **Step 4: Run the complete verification matrix**

Run fresh:

```bash
make test-scripts
make ci
make docs-check
actionlint .github/workflows/*.yml
git diff --check
```

Expected: every command exits zero. Optional local tools explicitly reported as
not installed by `scripts/ci-local.sh` are recorded as skipped, not fabricated
as executed.

- [ ] **Step 5: Review the complete branch diff**

Run:

```bash
git diff ae28e18 --stat
git diff ae28e18 -- . ':!.gitignore'
git status --short --branch
```

Confirm every changed line maps to the amendment spec, no debug or temporary
configuration remains, all `uses:` references are pinned, no secrets appear,
and deploy/smoke workflows are absent from the diff.

- [ ] **Step 6: Commit documentation**

```bash
git add docs/operations/deployment-guide.md CHANGELOG.md
git commit -m "docs: document Phase 5 artifact integrity"
```

- [ ] **Step 7: Re-run the final gate after the commit**

Run:

```bash
make ci
actionlint .github/workflows/*.yml
git status --short --branch
```

Expected: CI and actionlint exit zero; worktree is clean and the branch contains
only the approved P0 commits after `ae28e18`.
