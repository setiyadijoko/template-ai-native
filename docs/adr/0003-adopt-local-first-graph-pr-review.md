# ADR-0003: Adopt local-first graph PR review

- **Status:** Accepted
- **Date:** 2026-08-07

## Context

The template already provides deterministic quality and security checks plus
advisory AI review. Large or multi-language consumer repositories also need a
bounded view of change impact, affected execution flows, and test gaps without
sending source code to a third-party review service.

## Decision

Add `tirth8205/code-review-graph` as an advisory pull-request workflow. Pin the
composite action to the immutable `v2.3.7` commit SHA. Run analysis in an
unprivileged `pull_request` workflow and publish its report from a separate
`workflow_run` workflow after artifact and commit validation. Keep risk gating
disabled until a consumer measures precision and false-positive rates.

## Alternatives considered

- **Run the action directly with `pull-requests: write`:** rejected because
  fork pull requests receive a read-only token and the design couples
  untrusted analysis to a privileged comment operation.
- **Use a hosted code-review service:** rejected for the template baseline due
  to source-code egress, provider credentials, and stack-specific policy.
- **Make risk a blocking gate immediately:** rejected because no repository-
  specific baseline exists and the upstream documents known precision and
  small-change limitations.

## Consequences

- Pull requests receive an additional advisory risk/context report.
- CI spends runner time building or updating a local SQLite graph.
- Consumers must explicitly approve any future risk threshold or path-filter
  change through their project governance.

## Security implications

The analysis workflow has `contents: read` only. The trusted publication job
does not check out pull-request code, caps and validates the artifact, escapes
mentions, and verifies the analyzed commit before writing a comment.
