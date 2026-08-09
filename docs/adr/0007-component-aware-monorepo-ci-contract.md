# ADR-0007: Define a component-aware monorepo CI contract before implementation

- **Status:** Proposed
- **Date:** 2026-08-09
- **Decision owners:** Template maintainers and consumer project owners

## Context

ADR-0006 introduced an explicit `monorepo` layout declaration and deliberately
made `scripts/detect-stack.sh` return `unknown` until nested CI behavior was
designed. A monorepo can contain several independent stacks, for example a Go
service under `src/backend` and a Node.js application under `src/frontend`.
Selecting the first nested manifest is not deterministic and can produce a
false-green or false-red result.

The current reusable workflows are single-stack workflows. Enabling nested
execution without a contract would also make artifact names, required check
contexts, path filtering, fork behavior, and branch-protection migration
ambiguous.

This ADR is a design proposal only. It does not change the current workflows,
the version-1 project config, or the fail-safe `unknown` result.

## Decision

Before implementing component-aware CI, validate the following contract with
at least one real consumer monorepo.

### 1. Explicit component manifest

Extend the versioned `.template/project.yaml` contract in a future schema
revision rather than recursively discovering manifests. The proposed shape is:

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
  - id: frontend
    path: src/frontend
    stack: node
    required: true
    artifact: frontend
```

Component `id` values are unique, path values are safe repository-relative
directories, and `stack` values use the existing supported vocabulary. A
component must be explicitly listed; an unlisted nested manifest is not
implicitly built. Version 1 remains valid and continues the current
single-stack/`unknown` compatibility behavior.

### 2. Component fan-out and working directory

Reusable workflows fan out from the validated component list. Each matrix job
runs its stack tools with the component path as its working directory and
receives only the configuration needed for that component. The mapper must
gain an explicit path input before this is implemented; changing the current
root-based mapper implicitly is not allowed.

Unsupported or invalid required components fail configuration validation before
tool execution. Optional components may be marked advisory only after the
consumer defines what “optional” means and how aggregate status is reported.

### 3. Stable checks and aggregation

Every monorepo run creates one stable aggregate check, even when no component
path changed. Component checks use deterministic names derived from the
validated component id, for example:

```text
monorepo / aggregate
monorepo / quality / backend
monorepo / test / backend
monorepo / build / backend
```

The aggregate check reports skipped components explicitly and is the only
candidate for a new branch-protection requirement. Component contexts are
advisory until a consumer pilot proves that matrix names remain stable across
forks, reruns, and component additions. Existing required contexts are not
renamed as part of this work.

### 4. Artifacts and promotion

Each component owns an artifact named with its validated id, such as
`backend-build` or `frontend-build`. Artifact metadata must include the source
commit and component id. Deployment, if later adopted, promotes the exact
validated artifact; it does not rebuild a component for production.

### 5. Paths, cost, and no-op behavior

Path-aware execution may skip unaffected component jobs, but it must not use a
path filter that suppresses the aggregate required check. Shared files,
workflow changes, and dependency/configuration changes conservatively fan out
to all required components. The consumer pilot must measure matrix size,
runtime, duplicate work, and check noise before enabling blocking behavior.

### 6. Security and fork behavior

Component-aware workflows retain `pull_request` fork safety, immutable Action
SHAs, least-privilege permissions, and no provider or deployment secrets in
untrusted pull-request jobs. `pull_request_target` is not an implementation
shortcut. Artifact uploads and comments must use the existing trusted handoff
patterns where write permissions are required.

## Alternatives considered

### Recursively select the first manifest

Rejected. Ordering is not a component contract and mixed stacks can be
misclassified.

### Run one root workflow for every nested stack

Rejected. The current mapper assumes a single working directory, and a root
workflow would obscure ownership, artifact boundaries, and failure attribution.

### Duplicate workflows per component

Rejected. Duplication would drift security permissions, Action pins, check
names, and fixes. Reusable workflows with validated matrix inputs are the
preferred direction.

### Apply path filters to required workflows

Rejected. A filtered-out workflow can leave branch-protection contexts pending
or absent. Aggregation must remain visible on every relevant pull request.

## Consequences

Positive:

- Nested stacks are explicit, reviewable, and attributable to a component.
- Required checks and artifacts can be governed without guessing.
- Existing single-stack consumers retain their current behavior.
- Runtime and provider choices remain consumer-owned.

Trade-offs:

- The template remains `unknown` for declared monorepos until the contract is
  accepted and implemented.
- Consumer setup requires explicit component metadata rather than discovery.
- Matrix CI can increase runtime and cost; a pilot must establish limits.

## Security implications

The proposal preserves fork-safe triggers, least privilege, SHA-pinned Actions,
and human-controlled production. Component paths and ids are validated before
they reach working-directory or artifact commands. No secrets are introduced
into the project manifest.

## Data implications

No application data or customer payloads are added. CI metadata may include
component ids, paths, commit identifiers, and artifact names; consumers must
avoid putting sensitive data in those fields.

## Operational implications

The implementation must publish an aggregate result, bounded matrix size,
component-level logs, artifact retention policy, and a rollback path to the
current single-stack behavior. Required check contexts must be recorded in the
consumer's branch-protection plan before activation.

## Migration strategy

1. Keep version-1 configs and no-config repositories unchanged.
2. Validate this contract against a real consumer monorepo.
3. Add version-2 schema validation and path-aware mapper support with tests.
4. Run component checks advisory-only and measure cost, noise, and stability.
5. Add the aggregate check to branch protection only after a human-approved
   migration plan and stable check evidence.

## Rollback considerations

Disable component-aware fan-out and return declared monorepos to `unknown` if
check names drift, artifacts are ambiguous, fork safety regresses, or CI cost
exceeds the approved limit. Do not silently fall back to the first nested
manifest.
