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
`.template/project.yaml`:

```yaml
version: 1
layout: monorepo
primary_stack: go
primary_path: src/backend
```

Supported layouts are `single`, `monorepo`, and `undecided`. The project config
is validated locally and by `make ci` when present.

Until component-aware reusable workflows are designed and approved, a declared
`monorepo` returns `unknown` from `scripts/detect-stack.sh`. This is a fail-safe
choice: the current single-stack workflows must not guess which nested service
to build or test. Repositories without a config retain compatibility behavior.

## Consequences

Positive:

- The layout decision is explicit and reviewable.
- Consumer onboarding can ask the monorepo question early.
- Nested services are not silently misclassified.
- No credentials or provider-specific settings are introduced.

Trade-offs:

- A monorepo currently receives no stack-dependent CI until component-aware
  workflow execution is implemented.
- `primary_path` records intent but does not yet make the reusable workflows
  multi-component aware.
- A future component-aware design must define fan-out, paths, artifacts, and
  required check contexts before enabling nested execution.

## Rejected alternative

Recursively selecting the first manifest under `src/` was rejected because it is
not deterministic for multi-stack repositories and can produce false-green or
false-red CI results.
