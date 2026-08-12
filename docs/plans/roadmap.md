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

Follow-up — 2026-08-11: ADR-0010 approves the hybrid activation architecture
for new consumers. The baseline remains unchanged while implementation,
hosted activation pilots, and enforcement evidence are staged separately.

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

### Hosted single-stack Python coverage pilot — verified 2026-08-11

- Consumer: [setiyadijoko/template-ai-native-python-coverage-pilot](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot).
- Pull request: [#2](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/pull/2), merged from reviewed head `d3836197d5de499b71aaf916f3ec4cc88f48391d`.
- Merge commit: `02d399f3d32008f9171c29784350a3e013c96607`.
- Main CI: [run 31430494963](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31430494963) completed successfully for the merge commit.
- Hosted coverage collected identically named unit, integration, and E2E test modules without consumer pytest discovery workarounds: 12 tests passed with 100% coverage.
- Python quality, build, CodeQL, OSV Scanner, secret scanning, workflow security, and post-merge provenance passed; only the inapplicable component-aware monorepo job skipped.
- Artifact `template-ai-native-build-python.tar.gz` contained the wheel and source distribution; attested subject SHA-256: `7693208e0bcda789fabcb4a77be260a9e40aa9bbee10add23a0306506fd27fa0`.
- Strict `gh attestation verify` policy bound the subject to the signer workflow, merge digest, `refs/heads/main`, and a GitHub-hosted runner. GitHub recorded [attestation 39903008](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/attestations/39903008).
- The Standard profile remained declarative and did not change workflow execution.

### P1 — profile foundation (implemented; activation contract accepted)

- Define and validate a versioned `.template/profile.yaml` schema; see
  `.template/profile.schema.yaml` and `scripts/validate-profile-config.sh`.
- Define Starter, Standard, and Enterprise control mappings in
  [ADR-0008](../adr/0008-profile-foundation.md) and
  `.template/profile-controls.yaml`.
- Preserve a compatibility fallback when no profile exists; current behavior
  and security defaults remain unchanged.
- Govern future workflow activation, required contexts, and new-consumer
  adoption through ADR-0010 and its hosted activation gate.

### P1 — profile shadow mode (all-profile evidence verified; completed)

- ADR-0009 approves one isolated, advisory observation workflow and a
  deterministic resolver.
- All current workflows, required checks, branch protection, initializer
  behavior, and production controls remain unchanged.
- Template compatibility mode passed on
  [push run 31445189380](https://github.com/setiyadijoko/template-ai-native/actions/runs/31445189380)
  with all eleven controls at `current-baseline` and read-only permissions.
- The public Standard-profile Python consumer passed
  [PR shadow run 31454139223](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31454139223),
  [CI run 31454139325](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31454139325),
  and
  [push shadow run 31457093780](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31457093780).
- External [fork PR #4](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/pull/4)
  was first held with `action_required`. After explicit maintainer approval,
  attempt 2 passed the stable shadow context in
  [run 31458012221](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31458012221)
  with `Contents: read` and `Secret source: None`; Python CI and CodeQL also
  passed without changing the application or profile.
- Config-only [Starter PR #5](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/pull/5)
  passed all eleven workflows. Its
  [shadow run 31460087254](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31460087254)
  reported `status=aligned`; CodeQL, coverage, and artifact attestation were
  correctly stronger than Starter defaults. The PR was closed without merge.
- Config-only [Enterprise PR #6](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/pull/6)
  passed all eleven workflows. Its
  [shadow run 31460090901](https://github.com/setiyadijoko/template-ai-native-python-coverage-pilot/actions/runs/31460090901)
  reported the expected SBOM, Scorecard, semantic-review, structural-review,
  and production-governance mismatches. The PR was closed without merge.
- The shadow resolution took under three seconds in the observed profile jobs. The
  Standard consumer consistently warned that semantic and structural review
  were declared `off` while the profile defaults are `advisory`; this was
  accurate observation, not execution failure.
- Process finding: fork evidence PR #4 was later merged despite its evidence-only
  boundary. Its diff was limited to one README sentence and changed no runtime,
  workflow, or profile behavior. Subsequent evidence PRs were closed promptly.

Decision: the observation gate is complete. ADR-0010 now defines the approved
activation architecture; no workflow condition or branch-protection change was
authorized by the shadow pilot itself.

### P1 — profile-aware activation (hosted evidence passed; enforcement PR next)

- [ADR-0010](../adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md)
  selects a hybrid two-layer architecture: five invariant governance contexts
  plus one stable `Profile policy / Required controls` aggregate.
- Implemented foundation: new consumers choose Starter, Standard, or Enterprise
  during initialization; non-interactive use requires `--profile`, while
  interactive use prompts for it, and selection is never inferred. The template
  remains profile-free in compatibility mode; the central effective-policy
  resolver fails closed for an initialized consumer with a missing or invalid
  profile. The shadow presentation delegates to that resolver.
- Local advisory implementation is complete: the execution-plan resolver,
  reusable boundaries, and `Profile policy / Required controls` aggregate run
  while all direct baseline workflows continue to run. The duplicate baseline
  path is intentional during the pilot. Disposable historical pilots will not
  be migrated.
- Hosted evidence is complete. Fresh Starter, Standard, and AI-enabled
  Enterprise consumers passed pull-request reruns and `main` pushes with the
  same stable aggregate context. Enterprise also passed its post-merge SBOM,
  Scorecard, provenance, and credential-free deterministic AI-evaluation
  boundaries. Exact repositories, runs, durations, and outcomes are recorded
  in [ADR-0010](../adr/0010-activate-profile-aware-controls-through-a-stable-aggregate.md#activation-evidence-decision--2026-08-13).
- A disposable Starter failure PR proved required-failure propagation and a
  blocked protected merge. An external fork proved read-only permissions,
  `Secret source: None`, and an aggregate with no unresolved required context.
  Branch protection was applied with the five invariant contexts plus the
  stable aggregate, then rolled back to its original unprotected state.
- Decision: the activation evidence gate is **PASS**. A separate enforcement
  PR is authorized to update the branch-protection helper for new consumers.
  Enforcement is not active in the current baseline.
- After a protected disposable consumer validates that helper, a later PR may
  remove duplicate direct profile-dependent execution. The five invariant
  governance workflows remain independent and unchanged.

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

### P2 — optional profile UX extensions (future)

- Keep identity updates and explicit reconfiguration protection stable after
  the required P1 profile selection is implemented.
- Consider additional non-interactive UX only after the required
  non-interactive `--profile` contract is reliable.
- Do not add profile variants or generated workflow files outside ADR-0010.

## Exit criteria for profile-aware enforcement

ADR-0009 shadow evidence, ADR-0010 design approval, and all hosted activation
evidence are complete:

1. the initializer requires a valid explicit profile for new consumers while
   preserving template compatibility mode;
2. the advisory aggregate passes on fresh Starter, Standard, and Enterprise
   consumers across pull-request, rerun, `main` push, and fork paths;
3. required failures propagate, optional/advisory behavior matches policy, and
   no disabled control leaves a pending context;
4. fork permissions, secret isolation, duration, warning noise, and avoided
   profile-variable jobs are recorded;
5. branch-protection migration and rollback are exercised on a disposable
   repository; and
6. every ADR-0010 acceptance criterion has evidence.

All six exit criteria passed on 2026-08-13. The next bounded change is the
branch-protection helper enforcement PR. Actual enforcement remains inactive
until that change is reviewed and merged; duplicate baseline removal remains a
later, independently reversible change.
