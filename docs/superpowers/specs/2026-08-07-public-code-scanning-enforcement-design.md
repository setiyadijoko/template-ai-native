# Public Code-Scanning Enforcement Design

**Status:** Approved for implementation

**Date:** 2026-08-07

**Owner:** Template maintainers

**Resolves:** TD-0006

## Executive summary

The repository is now public, so GitHub Code Scanning storage and the public
OpenSSF Scorecard publishing path are available without paid GitHub Advanced
Security. The Phase 3 workflows still preserve their former private-repository
graceful-degrade behavior: CodeQL does not run on pull requests, all CodeQL
analysis steps ignore errors, and Scorecard lacks the OIDC permission required
by `publish_results: true` while also ignoring scan and SARIF upload failures.

This change closes TD-0006 with a minimal fail-closed enforcement model:

1. CodeQL runs on pull requests targeting `main`, pushes to `main`, its weekly
   schedule, and manual dispatch;
2. CodeQL initialization, build, analysis, and result upload failures fail the
   workflow;
3. OpenSSF Scorecard receives the job-scoped OIDC and SARIF permissions needed
   to publish authentic results; and
4. Scorecard findings remain advisory, while failures to run the scan or store
   its SARIF results fail the workflow.

The empty template must remain valid. The CodeQL run for merge commit
`d3b1badd5908339fad819a2d73a2e7ea6d56d330` reported successful step
conclusions, but the existing `continue-on-error` policy makes that historical
signal insufficient evidence. The first fail-closed pull-request run is the
acceptance proof that the current repository can complete initialization,
autobuild, analysis, and storage without an adopted stack in `src/`.

## Business objective

Turn public-repository security scanning from a best-effort signal into
auditable, reliable evidence. A green workflow must mean that the scanner ran
and its results were stored, rather than merely that errors were suppressed.
This reduces false assurance before Phase 6 production-readiness work begins.

## Scope

### In scope

- Enable CodeQL for pull requests targeting `main`.
- Make CodeQL execution and result storage fail closed.
- Isolate CodeQL concurrency by pull request or Git ref.
- Add the OIDC permission required for authenticated Scorecard publishing.
- Make Scorecard execution and SARIF upload failures fail closed.
- Preserve Scorecard findings as advisory.
- Add POSIX shell contract tests for the two workflow policies.
- Update Phase 3 security documentation, assumptions, changelog, and TD-0006.
- Verify the CodeQL pull-request run before merge and the first Scorecard run
  from the default branch after merge.

### Out of scope

- Changing branch protection or repository rules.
- Making a Scorecard score or individual Scorecard finding block a merge.
- Changing dependency-audit or license-check advisory policy (TD-0004).
- Adding container or infrastructure-as-code scanning (TD-0005).
- Selecting a runtime stack or replacing CodeQL's implicit language detection
  with a language matrix.
- Wiring deployment, smoke tests, or Phase 6 production-readiness controls.
- Adding a public Scorecard badge to `README.md`.

## Current-state defect

### CodeQL

`.github/workflows/codeql.yml` runs only for pushes to `main`, a weekly
schedule, and manual dispatch. Its initialize, autobuild, and analyze steps all
use `continue-on-error: true`, so a failed scanner can still produce a green
workflow. The global concurrency key also allows a run from one event to cancel
an unrelated run from another ref.

### OpenSSF Scorecard

`.github/workflows/scorecard.yml` sets `publish_results: true` but does not grant
`id-token: write`. OpenSSF Scorecard v2 requires an OIDC token to authenticate
published results. Both the Scorecard action and SARIF upload currently use
`continue-on-error: true`, so missing publication evidence is not visible as a
workflow failure.

## Approved architecture

```text
pull request to main ----+
push to main ------------+--> CodeQL init -> autobuild -> analyze/upload
weekly/manual -----------+          any execution/storage error -> FAIL

push to main ------------+
weekly/manual on main ---+--> Scorecard -> publish result -> upload SARIF
                                  low score/finding -> ADVISORY
                                  execution/storage error -> FAIL
```

CodeQL is the pull-request SAST control. Scorecard remains a repository-health
signal on trusted repository events and is not added to pull requests. The two
workflows stay independent, use only GitHub-hosted Ubuntu runners, and retain
their existing immutable Action pins.

## Component design

### `.github/workflows/codeql.yml`

- Add `pull_request` for the `main` target branch.
- Retain `push` to `main`, weekly `schedule`, and `workflow_dispatch`.
- Use a concurrency group containing the workflow name plus the pull-request
  number when available, otherwise the Git ref. A PR scan cannot cancel a
  `main` scan or another PR scan.
- Set default workflow permissions to `contents: read`.
- Grant the CodeQL job only `contents: read` and `security-events: write`, with
  explanatory comments for each non-default capability.
- Rename the job from graceful-degrade wording to `CodeQL (blocking)`.
- Omit the `languages` input so CodeQL performs its supported implicit language
  detection; `autodetect` is not a valid CodeQL language identifier.
- Retain the existing initialize, autobuild, and analyze sequence.
- Disable checkout credential persistence.
- Remove every `continue-on-error` from the CodeQL integrity path.
- Keep every third-party Action pinned to an immutable commit SHA with its
  release tag documented.

### `.github/workflows/scorecard.yml`

- Retain `push` to `main`, weekly `schedule`, and `workflow_dispatch`. Do not add
  an experimental pull-request trigger.
- Set default workflow permissions to `contents: read` so no write permission
  exists at workflow level.
- Grant only the Scorecard job:
  - `contents: read` to inspect the repository;
  - `security-events: write` to upload SARIF; and
  - `id-token: write` to authenticate `publish_results: true` through OIDC.
- Keep the job name explicitly advisory because the score does not gate a
  merge.
- Disable checkout credential persistence.
- Remove `continue-on-error` from both Scorecard execution and SARIF upload.
- Keep `results_format: sarif`, `results_file: scorecard.sarif`,
  `publish_results: true`, and category `scorecard`.
- Keep the job compatible with OpenSSF publication restrictions: no top-level
  or job-level `env` or `defaults`; no job-level environment, services, or
  container; no shell `run` steps; and no Actions outside `actions/checkout`,
  `ossf/scorecard-action`, and `github/codeql-action/upload-sarif`.
- Treat Scorecard runtime publication as a default-branch acceptance check.
  The action rejects feature-branch runs even when `workflow_dispatch` is
  available, so such a run is not valid pre-merge evidence.

## Failure semantics

| Condition | Expected result |
|-----------|-----------------|
| CodeQL cannot initialize or autodetect an analyzable target | CodeQL workflow fails |
| CodeQL autobuild fails | CodeQL workflow fails |
| CodeQL analysis or result upload fails | CodeQL workflow fails |
| CodeQL reports a finding | Finding is surfaced through Code Scanning and governed by repository rules |
| Scorecard reports a low score or security-health finding | Workflow succeeds; finding remains advisory |
| Scorecard cannot run or publish its result | Scorecard workflow fails |
| Scorecard SARIF cannot be uploaded | Scorecard workflow fails |

In this design, **blocking** means the GitHub Actions check concludes with
failure. Whether that failed check prevents a merge depends on owner-managed
branch protection or repository rules. AI agents do not change or self-approve
those repository settings.

## Security and trust boundaries

- The `pull_request` event is used for CodeQL; `pull_request_target` is
  prohibited because it would create a privileged boundary around untrusted PR
  content.
- GitHub permits code-scanning result upload for workflows triggered by
  `pull_request`, including the restricted-token fork case.
- No secret is introduced. Scorecard uses GitHub OIDC rather than a long-lived
  credential.
- Write permissions are job-scoped. Scorecard publication specifically requires
  that no write permission be granted at workflow level.
- Scorecard does not run on untrusted PR content.
- Third-party Actions remain SHA pinned.

## Contract-test design

Add `scripts/test/test-security-workflows.sh` and call it from
`make test-scripts`. The test follows the existing POSIX shell contract-test
style and is written before the workflow changes.

The contract test asserts:

- CodeQL has `pull_request` and `push` restricted to `main`;
- CodeQL explicitly excludes `pull_request_target`;
- CodeQL retains schedule and manual dispatch;
- CodeQL concurrency is isolated by PR number or ref;
- CodeQL has job-scoped `security-events: write` and no workflow-level write;
- the CodeQL job is described as blocking;
- CodeQL leaves the `languages` input unset for implicit supported-language
  detection;
- no CodeQL step contains `continue-on-error`;
- Scorecard keeps trusted-event triggers and does not add `pull_request`;
- both checkout steps disable credential persistence;
- Scorecard has job-scoped `contents: read`, `security-events: write`, and
  exactly one `id-token: write`, with no workflow-level OIDC permission;
- Scorecard retains `publish_results: true` and SARIF category `scorecard`;
- no Scorecard step contains `continue-on-error`;
- Scorecard excludes top-level and job-level `env` and `defaults`, job-level
  environment/container/services, shell `run` steps, and unapproved Actions;
- the advisory job-label assertion is a naming and documentation contract,
  while current-state policy assertions establish the findings policy;
- both workflows retain timeouts and immutable Action pins with trailing
  release-tag comments; and
- TD-0006 and public-repository documentation are internally consistent.

The initial test run must fail against the current graceful-degrade workflows.
It must pass only after the minimum workflow and documentation changes are
implemented.

## Documentation changes

- `AGENTS.md`: describe CodeQL execution/storage as fail closed on the public
  repository and Scorecard findings as advisory with blocking execution.
- `docs/security/vulnerability-management.md`: document public Code Scanning
  storage and the operational meaning of a failed scanner.
- `docs/assumptions.md`: replace the private-repository Scorecard limitation
  with the public-repository OIDC/SARIF assumption.
- `docs/plans/technical-debt.md`: mark TD-0006 closed with the resolution date
  and retained traceability.
- `CHANGELOG.md`: record CodeQL PR enforcement and authenticated Scorecard
  publication under `Unreleased`.

No accepted ADR or `DESIGN.md` baseline changes because this work implements
the existing TD-0006 resolution without selecting a new architecture.

## Acceptance criteria

1. CodeQL runs automatically for pull requests targeting `main`.
2. CodeQL runs remain enabled for pushes to `main`, schedule, and manual use.
3. Unrelated PR/ref CodeQL runs do not cancel one another.
4. CodeQL initialization, autobuild, analysis, and result-storage errors fail
   the workflow; no CodeQL integrity step uses `continue-on-error`.
5. Scorecard publishing uses job-scoped `id-token: write` and SARIF upload uses
   job-scoped `security-events: write`.
6. Scorecard scan and SARIF storage errors fail the workflow; Scorecard findings
   remain advisory.
7. No secret, persisted checkout credential, broad workflow-level write
   permission, or Action without an immutable pin and release-tag comment is
   introduced.
8. Security workflow contract tests are integrated into `make test-scripts` and
   demonstrate a red-before-green sequence.
9. `make ci`, `make docs-check`, `actionlint`, `shellcheck`, `zizmor`, Action pin
   checks, and `git diff --check` pass where the corresponding local tool exists.
10. A PR CodeQL run succeeds and stores its analysis.
11. The first default-branch Scorecard push run after merge, or a manual
    dispatch against `main`, succeeds, publishes an authenticated result, and
    stores category `scorecard` SARIF. This is explicitly a post-merge
    acceptance check because the action rejects feature-branch publication.
12. TD-0006 is closed and no affected current-state document still claims that
    this repository is private or lacks Code Scanning storage.

## Verification plan

Run and record actual local results for:

```bash
sh scripts/test/test-security-workflows.sh
make test-scripts
make ci
make docs-check
actionlint .github/workflows/*.yml
shellcheck -x scripts/test/test-security-workflows.sh
uvx zizmor --pedantic .github/workflows/codeql.yml .github/workflows/scorecard.yml
git diff --check
```

After pushing the feature branch:

1. open a draft pull request and verify the CodeQL pull-request run;
2. query GitHub Code Scanning analyses to confirm the PR CodeQL result is
   stored; and
3. report any skipped local optional tool honestly rather than substituting a
   remote result.

After merge, require the Scorecard push run on `main` (or dispatch the workflow
against `main`) to succeed, then confirm authenticated publication and stored
SARIF category `scorecard`. Do not use a feature-branch dispatch as acceptance
evidence because the Scorecard action rejects non-default refs.

## Rollback

Revert the implementation commit to restore the previous workflow policy. The
change creates no deployment, modifies no production data, and introduces no
secret. If the public scanning service is temporarily unavailable, preserve the
failed run as evidence and correct or retry through the reviewed workflow; do
not reintroduce `continue-on-error` without explicit owner approval and a
documented bounded exception.
