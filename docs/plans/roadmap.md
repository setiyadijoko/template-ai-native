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

### P0 — component-aware monorepo CI (implemented; pilot diagnostic complete)

Completed foundation:

- Ask for `single`, `monorepo`, or `undecided` during consumer initialization.
- Validate `.template/project.yaml` and record the primary component path.
- Generate a validated version-2 component list for monorepos during
  initialization.
- Keep recursive manifest discovery disabled.
- Validate an explicit version-2 component list from the MangaHub pilot.

Implemented in the template branch:

- Add reusable component fan-out, aggregate status, and component artifacts.
- Keep version-1/single-stack behavior and branch protection unchanged.

Pilot result and remaining work:

- The MangaHub consumer was used as a diagnostic test and confirmed the need
  for explicit component paths, local Node tool resolution, and consumer-owned
  test coverage. Its PR is intentionally not a production rollout.
- The `media-belajar-anak` hosted-runner pilot exposed and drove local fixes for
  reusable-workflow concurrency isolation, deterministic Go lint setup, and
  empty optional Node.js test categories.
- Run the corrected component workflow on a fresh consumer pull request and
  verify the aggregate check before making component checks blocking.

The contract is recorded in [ADR-0007](../adr/0007-component-aware-monorepo-ci-contract.md).

### P2 — bootstrap extensions and workflow activation (future)

- Keep the existing identity update and reconfiguration protection stable;
  profile-related extensions still require an approved profile contract and
  migration behavior.
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
