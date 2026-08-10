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

### Hosted single-stack Java pilot — verified 2026-08-10

- Consumer: [setiyadinamikaintegrasi/template-java-pilot](https://github.com/setiyadinamikaintegrasi/template-java-pilot).
- Pull request: [#2](https://github.com/setiyadinamikaintegrasi/template-java-pilot/pull/2), merged at `2026-08-10T07:36:51Z` from the reviewed head `bd8ca8c99c11c62e1d32e83322581802454fe160`.
- Merge commit: `c7e5f19770e307c07ca46ae84f95cfd655019042`.
- Main CI: [run 31366576067](https://github.com/setiyadinamikaintegrasi/template-java-pilot/actions/runs/31366576067) completed successfully for the merge commit.
- The main CI run executed Java quality, integration/E2E/coverage, build, and provenance jobs successfully; only the inapplicable component-aware monorepo job skipped.
- The same push completed CodeQL, secret scanning, workflow security, Scorecard, SBOM, and the production-readiness contract successfully.
- Artifact `build-java` contained `target/template-java-pilot-0.1.0-SNAPSHOT.jar` in `template-ai-native-build-java.tar.gz`.
- Downloaded archive and attested subject SHA-256: `3f42c297fd23d4b3a79531e2de520c904be1ff01e3944401ed2c6ac7a11e4dd7`.
- `gh attestation verify` verified the SLSA provenance subject against `setiyadinamikaintegrasi/template-java-pilot`; GitHub recorded [attestation 39760436](https://github.com/setiyadinamikaintegrasi/template-java-pilot/attestations/39760436).
- The pilot used Java 21, Maven, deterministic synthetic logic, and no secret, external service, framework, deployment, or profile activation.

### Hosted single-stack .NET pilot — verified 2026-08-10

- Consumer: [setiyadinamikaintegrasi/template-dotnet-pilot](https://github.com/setiyadinamikaintegrasi/template-dotnet-pilot).
- Pull request: [#1](https://github.com/setiyadinamikaintegrasi/template-dotnet-pilot/pull/1), merged at `2026-08-10T10:53:59Z`.
- Merge commit: `e7f4283e2f99beb1aa61a09ea2f2b13b9b3628b9`.
- Main CI: [run 31381140727](https://github.com/setiyadinamikaintegrasi/template-dotnet-pilot/actions/runs/31381140727) completed successfully with .NET quality, unit, integration, E2E, coverage, build, and provenance jobs.
- The consumer used a .NET 8 class library plus a separate xUnit test project; hosted coverage measured `100.00% (26/26 lines)`.
- The same merge completed CodeQL, secret scanning, workflow security, Scorecard, SBOM, OSV Scanner, and the production-readiness contract successfully.
- Artifact `build-dotnet` contained `template-ai-native-build-dotnet.tar.gz`; attested subject SHA-256: `0f079d6fca3cebeea2428a1f69a0523cce0ed3be05e0eb2ad2e46889ec7dd239`.
- `gh attestation verify` verified the SLSA provenance subject; GitHub recorded [attestation 39794621](https://github.com/setiyadinamikaintegrasi/template-dotnet-pilot/attestations/39794621).
- The pilot used deterministic .NET domain logic with no framework server, external service, deployment, AI provider, or profile activation.

### P1 — profile foundation (implemented; activation deferred)

- Define and validate a versioned `.template/profile.yaml` schema; see
  `.template/profile.schema.yaml` and `scripts/validate-profile-config.sh`.
- Define Starter, Standard, and Enterprise control mappings in
  [ADR-0008](../adr/0008-profile-foundation.md) and
  `.template/profile-controls.yaml`.
- Preserve a compatibility fallback when no profile exists; current behavior
  and security defaults remain unchanged.
- Record workflow activation, required check contexts, and consumer migration
  as deferred work requiring a separate ADR and hosted pilot.

### P0 — component-aware monorepo CI (implemented; hosted pilot passed)

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

Pilot result:

- Initializer contract tests now use a dedicated fresh README fixture instead
  of copying the active consumer README, preserving repeatable post-bootstrap
  validation.
- The MangaHub consumer was used as a diagnostic test and confirmed the need
  for explicit component paths, local Node tool resolution, and consumer-owned
  test coverage. Its PR is intentionally not a production rollout.
- The `media-belajar-anak` hosted-runner pilot exposed and drove local fixes for
  reusable-workflow concurrency isolation, deterministic Go lint setup, and
  empty optional Node.js test categories.
- The corrected generic dispatcher then passed twice on the consumer pull
  request without a duplicate caller. Both runs materialized the resolver, six
  Go/Node quality/test/build jobs, and the stable aggregate check. See hosted
  runs
  [31312862775](https://github.com/setiyadinamikaintegrasi/media-belajar-anak/actions/runs/31312862775)
  and
  [31313000802](https://github.com/setiyadinamikaintegrasi/media-belajar-anak/actions/runs/31313000802).

Governance follow-up before making the aggregate check blocking:

- Measure fork behavior, cost and noise on a larger component matrix, and
  artifact ownership/promotion in a consumer that adopts deployment.
- Add `monorepo / aggregate` to branch protection only through a
  human-approved consumer migration plan.

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
