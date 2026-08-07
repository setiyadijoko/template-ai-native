# ADR-0005: Adopt Graphify as optional codebase memory

- **Status:** Accepted
- **Date:** 2026-08-07
- **Decision owners:** Project maintainers

## Context

The template already provides two complementary advisory pull-request layers:
Code Review Graph for deterministic structural impact and Alibaba Open Code
Review for optional semantic findings. Engineers and coding agents also need a
repository-wide way to explore relationships across source, configuration, and
documentation outside a single pull request.

## Decision

Adopt Graphify as an optional local developer tool for **codebase knowledge**.
It is not runtime/user memory and is not a replacement for either existing
review workflow. The template documents a pinned reference installation,
project-scoped Codex setup, data handling, and generated-artifact hygiene.

Graphify is not enabled automatically in GitHub Actions. Consumers must create
a separate reviewed workflow if they need CI generation, including immutable
tool pinning, bounded artifacts, and approved data-egress controls.

## Consequences

- Engineers can inspect a repository graph without changing the PR review
  contract.
- Local graph output remains untracked by default.
- Consumers retain responsibility for validating upstream releases and any
  external semantic-processing endpoint.
- The template now has three distinct layers: codebase knowledge, structural PR
  review, and semantic PR review.

## Alternatives considered

1. Replace Code Review Graph with Graphify in CI — rejected because Graphify's
   developer knowledge workflow has different runtime and artifact requirements.
2. Send Graphify output into Alibaba review — rejected because that would create
   an unreviewed source-data path and the action has no supported graph-context
   input.
3. Add Graphify automatically to every pull request — rejected until a stable,
   pinned CI distribution and consumer data-egress policy are established.
