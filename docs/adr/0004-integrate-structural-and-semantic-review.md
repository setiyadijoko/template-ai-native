# ADR-0004: Integrate structural and semantic PR review

- **Status:** Accepted
- **Date:** 2026-08-07

## Context

The template now has two advisory review capabilities: local structural impact
analysis from Code Review Graph and semantic LLM review from Alibaba Open Code
Review. Running them with unrelated scopes and permission conventions creates
confusing coverage and makes it difficult for a consumer to understand which
review is authoritative.

## Decision

Coordinate both workflows under one PR-review policy:

- Code Review Graph remains the local structural layer and keeps its separate
  fork-safe trusted publisher.
- Alibaba Open Code Review remains an optional semantic layer, activated only
  with consumer-approved `OCR_LLM_*` secrets and an approved endpoint.
- Both cover source, test, prompt, evaluation, and review-workflow changes;
  both remain advisory and post distinct comments.
- The graph markdown report is not passed to the LLM. The Alibaba action has no
  supported graph-context input, and adding a new text/credential handoff would
  create an unnecessary data boundary.

## Alternatives considered

- **One combined LLM prompt:** rejected because the Alibaba action does not
  expose a supported graph-context input and report injection would be an
  unvalidated data path.
- **Replace graph analysis with OCR:** rejected because semantic review does
  not provide deterministic structural blast-radius evidence.
- **Make either review blocking:** rejected until consumer-specific precision,
  cost, duplication, and false-positive measurements exist.

## Consequences

- Consumers receive complementary structural and semantic review signals.
- Pull requests may contain two distinct advisory comments.
- Enabling OCR creates source-code egress to the configured LLM endpoint and
  requires data-retention and provider approval.
- A future governed aggregator remains possible, but is not part of this
  integration.
