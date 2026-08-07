# Integrated code-review policy

The template uses two complementary advisory review layers on pull requests:

1. **Code Review Graph** builds a local structural graph and reports change
   impact, affected flows, and test gaps. Its report is published through the
   fork-safe trusted publisher described in [graph-aware PR review](code-review-graph.md).
2. **Alibaba Open Code Review** performs semantic review with a consumer-owned
   LLM endpoint and can add inline findings plus a sticky summary.

The workflows are coordinated by policy and scope, not by sharing raw report
text. Both cover application and AI-behavior changes, both remain advisory, and
their comments are intentionally separate so structural evidence is not
confused with model-generated judgment.

For repository-wide exploration outside a pull request, the optional
[Graphify codebase knowledge graph](graphify.md) complements these layers. It
does not replace either workflow, and its generated graph is not application
runtime or user/session memory.

## Data and security boundary

Code Review Graph runs without a model-provider key and keeps its graph on the
runner. Alibaba Open Code Review receives the pull-request source through the
configured `OCR_LLM_URL`; the consumer must approve that endpoint, model,
retention policy, and data classification before setting `OCR_LLM_*` secrets.
Fork pull requests do not receive those secrets, so Alibaba review is skipped;
the graph review remains available through its trusted publication path.

The template does not inject the graph's markdown report into the LLM request:
the Alibaba action has no supported graph-context input, and its review agent
already retrieves repository context. Passing arbitrary report text through
LLM credentials or shell interpolation would add a new unreviewed data path.

## Operating policy

- Keep deterministic quality, security, and test checks as the merge gates.
- Keep both AI-assisted layers advisory until precision, duplication, latency,
  cost, and false-positive rates are measured on the consumer repository.
- Promote a threshold only through an ADR and an explicit branch-protection
  change.
- If the LLM endpoint handles sensitive source, use an approved enterprise or
  self-hosted endpoint and document retention and access controls.
