# Roadmap

This roadmap records improvements to the reusable template. It separates work
that improves adoption immediately from profile-aware automation that requires a
compatible CI and branch-protection design.

## Current baseline

Phases 1–6 are available as a governed, stack-agnostic baseline. Deployment,
smoke testing, provider execution, and production-readiness activation remain
consumer-specific or skeleton implementations. See the status table in
[`../../README.md`](../../README.md) and the roadmap in [`../../PRODUCT.md`](../../PRODUCT.md).

## Decision — 2026-08-08

Profile-aware implementation is deferred. The proposed Starter/Standard/
Enterprise model is directionally useful, but changing workflow activation now
could make required GitHub checks pending or silently weaken controls for
existing consumers. The current baseline and security defaults therefore remain
unchanged until the compatibility design is approved.

## Prioritized work

### Completed / low-risk alignment

- Synchronize README maturity status with the shipped Phase 1–6 baseline.
- Identify deployment and smoke-test workflows as skeletons until a platform is
  adopted.
- Add a README/layout initializer with explicit reconfiguration protection; it
  does not activate profile-aware controls.
- Document profile-driven adoption as a roadmap item rather than an active
  capability.

### P1 — profile foundation (future)

- Define and validate a versioned `.template/profile.yaml` schema.
- Define Starter, Standard, and Enterprise control mappings.
- Add a compatibility fallback when no profile exists; it must preserve current
  behavior and must not weaken security by default.
- Add an ADR covering workflow activation, required check contexts, and
  migration for existing consumers.

### P1 — explicit monorepo layout (foundation)

Completed foundation:

- Ask for `single`, `monorepo`, or `undecided` during consumer initialization.
- Validate `.template/project.yaml` and record the primary component path.
- Keep monorepo stack detection fail-safe until component-aware CI execution is
  approved.

Remaining design work:

- Define component fan-out, artifact ownership, and required check contexts
  before enabling nested service workflows; the proposed contract is recorded
  in [ADR-0007](../adr/0007-component-aware-monorepo-ci-contract.md).

### P2 — bootstrap extensions and workflow activation (future)

- Keep the existing idempotent initializer stable; extend it only after the
  profile contract and migration behavior are approved.
- Introduce profile-aware workflow activation only after proving that required
  checks remain stable and disabled controls do not leave pending statuses.
- Measure CI duration and check noise before and after activation.

## Exit criteria for resuming profile work

Profile implementation may resume when all of the following are defined:

1. compatibility behavior for repositories without a profile;
2. a stable required-check strategy for every profile;
3. an explicit policy for controls that are blocking, advisory, scheduled, or
   manual;
4. an idempotent document-update strategy for the initializer;
5. a consumer pilot that validates adoption cost and security behavior.
