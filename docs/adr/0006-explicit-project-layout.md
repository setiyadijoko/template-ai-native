# ADR-0006: Declare project layout before stack detection

- Status: Accepted
- Date: 2026-08-08
- Decision owners: Template maintainers

## Context

The template originally detected one primary stack from the repository root or
directly under `src/`. A consumer monorepo may instead contain multiple
components such as `src/backend/go.mod` and `src/frontend/package.json`.
Choosing the first nested manifest would be ambiguous and could run a stack
toolchain against the wrong component.

## Decision

The consumer initializer records a credential-free layout declaration in
`.template/project.yaml`. Version 1 remains the compatibility format:

```yaml
version: 1
layout: monorepo
primary_stack: go
primary_path: src/backend
```

Supported layouts are `single`, `monorepo`, and `undecided`. The project config
is validated locally and by `make ci` when present.

Version 1 monorepo configuration returns `unknown` from
`scripts/detect-stack.sh`. This is a fail-safe compatibility choice: the
single-stack workflows must not guess which nested service to build or test.
Repositories without a config retain compatibility behavior.

Version 2 enables the explicit component contract after validation:

```yaml
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: src/backend
    stack: go
    required: true
    artifact: backend
```

The component-aware workflow consumes the complete `components` list; it does
not discover manifests recursively. Version 1 consumers remain on the
fail-safe single-stack path.

## Consequences

Positive:

- The layout decision is explicit and reviewable.
- Consumer onboarding can ask the monorepo question early.
- Nested services are not silently misclassified.
- No credentials or provider-specific settings are introduced.

Trade-offs:

- Version 1 monorepos continue to receive no stack-dependent CI until they
  migrate to the explicit version-2 component contract.
- Version 2 component jobs are advisory until a consumer pilot confirms cost,
  stable check names, artifact ownership, and fork behavior.
- Branch protection is not changed by component-aware workflow activation.

## Rejected alternative

Recursively selecting the first manifest under `src/` was rejected because it is
not deterministic for multi-stack repositories and can produce false-green or
false-red CI results.
