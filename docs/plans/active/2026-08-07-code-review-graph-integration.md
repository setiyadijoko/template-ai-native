# Code Review Graph integration

## Objective

Add an advisory, local-first graph-aware pull-request review to the template
without weakening the existing least-privilege or fork-safety rules.

## Scope

- Run `tirth8205/code-review-graph` on `pull_request` with read-only access.
- Pin every workflow action to an immutable commit SHA, including the
  report-file output introduced by code-review-graph v2.3.7.
- Publish the report only from a trusted `workflow_run` job after validating the
  artifact and analyzed commit.
- Keep risk gating disabled until a consumer measures false-positive rates.
- Document the integration, ADR, and deferred promotion debt.

## Acceptance criteria

- A pull request receives one updated graph-aware advisory comment when the
  report passes validation.
- Fork pull requests never execute pull-request code with a write-capable token.
- Malformed, oversized, stale, or unexpected report artifacts are rejected.
- Workflow contract tests, docs checks, actionlint, and the local CI gate pass.

## Rollback

Revert the integration commit and remove the two graph-review workflows. The
existing deterministic CI and security workflows remain independent.
