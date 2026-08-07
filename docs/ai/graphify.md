# Graphify codebase knowledge graph

Graphify is an optional developer tool for building a queryable knowledge graph
of a repository and its documentation. It complements the pull-request review
layers; it does not replace them.

## Role in this template

- **Graphify** helps an engineer or coding agent understand repository-wide
  structure, dependencies, and evidence-backed relationships.
- **Code Review Graph** analyzes the changed pull request and reports structural
  impact and test gaps in CI.
- **Alibaba Open Code Review** provides optional semantic review through the
  consumer-approved LLM endpoint.

Graphify is codebase knowledge, not user/session memory and not an application
runtime memory store. Use a separately governed data store for conversation,
agent, or product memory.

## Local installation

The following pins the package version observed in Graphify v8. Verify the
upstream release and its security posture before changing the pin:

```sh
uv tool install 'graphifyy==0.9.35'
graphify install --project --platform codex
```

Run it from the consumer repository:

```sh
graphify .
```

The generated local artifacts include `graphify-out/graph.html`,
`graphify-out/GRAPH_REPORT.md`, and `graphify-out/graph.json`. They are ignored
by this template because they can contain the repository's structure and should
not be committed by default.

## Security and data policy

- Run Graphify locally or in an approved isolated development environment.
- Review the repository data classification before enabling semantic processing
  for documents or media; keep provider credentials outside the repository.
- Treat generated graph artifacts as source-derived information with the same
  access controls as the source tree.
- Do not add Graphify to pull-request CI by default. A consumer may propose a
  separately reviewed workflow after pinning the tool, bounding runtime and
  artifact size, and documenting any external model endpoint or retention.

See the upstream [Graphify repository](https://github.com/Graphify-Labs/graphify)
for supported platforms and release details. Upstream claims are not a
substitute for this repository's security and change review.
