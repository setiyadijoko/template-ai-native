# .NET Coverage Contract Design

**Status:** Approved 2026-08-10
**Date:** 2026-08-10
**Owner:** Project owner (@setiyadijoko)
**Target:** `template-ai-native` single-stack and component-aware .NET CI

## Problem

The template documents an overall automated-test coverage threshold of at
least 80% for every supported stack. The current .NET mapper runs:

```text
dotnet test --collect:"XPlat Code Coverage" /p:CoverletOutputFormat=cobertura
```

That command collects coverage but does not enforce the documented threshold.
The collector writes `coverage.cobertura.xml` below a generated
`TestResults/<id>/` directory, while the single-stack and component-aware
workflows currently upload only a root-level `coverage.cobertura.xml`.

The result can be a false-green .NET coverage job: tests and collection may
succeed when coverage is below 80%, and the generated report may not be
retained as workflow evidence. A hosted .NET pilot performed on this contract
would therefore validate an overstated gate.

## Decision

Add one repository-owned POSIX shell wrapper that runs the existing .NET
collector, discovers all generated Cobertura reports, and enforces an
aggregate line-coverage threshold of 80%. Route the existing .NET coverage
mapper through that wrapper and update both coverage-artifact paths to retain
reports from generated `TestResults` directories.

The fix precedes the hosted .NET consumer pilot. The pilot must be created
from template `main` only after this contract is reviewed and merged.

## Command boundary

Create `scripts/run-dotnet-coverage.sh`. It executes from the selected project
or component working directory and owns the complete coverage operation:

1. resolve the `dotnet` executable, supporting `DOTNET_BIN` for deterministic
   tests and approved local toolchain selection;
2. clear only the wrapper-owned generated directory
   `TestResults/template-ai-native-coverage`, never the consumer's other test
   results;
3. execute `dotnet test --collect:"XPlat Code Coverage"
   --results-directory TestResults/template-ai-native-coverage
   /p:CoverletOutputFormat=cobertura` without changing the existing consumer
   package contract;
4. recursively discover files named `coverage.cobertura.xml` only below that
   wrapper-owned current-run directory;
5. validate and aggregate those reports;
6. print the measured line coverage and required threshold;
7. exit non-zero when coverage is absent, invalid, or below 80%.

`scripts/stack-tools.sh` remains the public command mapper. Its .NET coverage
entry changes from an inline `dotnet test` command to the absolute wrapper
invocation, following the existing Python build-wrapper pattern. Other .NET
format, lint, compile, test-category, and build mappings remain unchanged.

## Coverage calculation

For every discovered Cobertura report, read the root `coverage` element's
integer `lines-covered` and `lines-valid` attributes. Compute one weighted
aggregate across all reports:

```text
aggregate percentage =
  100 * sum(lines-covered) / sum(lines-valid)
```

The gate passes when the aggregate is at least `80.0` and fails below it.
Weighted aggregation prevents a small test project from contributing the same
weight as a large project. It also avoids accepting the mean of per-report
percentages when report sizes differ.

The threshold is repository-owned and fixed at 80%. Consumers must not lower
it through an environment variable. Stronger consumer-specific thresholds can
be adopted through their own reviewed tooling without weakening this baseline.

## Report validation and failure behavior

The wrapper fails closed with an explicit GitHub Actions error message when:

- the `dotnet` executable is unavailable;
- `dotnet test` or the collector exits non-zero;
- no `coverage.cobertura.xml` is produced below `TestResults`;
- a report lacks integer `lines-covered` or `lines-valid` attributes;
- a report contains negative counts, covered lines greater than valid lines,
  or otherwise malformed numeric data;
- aggregate `lines-valid` is zero;
- aggregate line coverage is below 80%.

The wrapper does not fabricate an empty report, silently skip a test project,
or convert a collector failure into success. Existing reports from prior runs
cannot be accepted as current evidence because discovery is restricted to the
wrapper-owned results directory after that exact directory is cleared before
the collector runs.

Error messages report paths and numeric values but must not print environment
variables, credentials, package-source tokens, or arbitrary report content.

## Workflow integration

Update both existing test workflows without introducing another job or action:

- `.github/workflows/ci-test.yml` retains root compatibility paths and also
  uploads `**/TestResults/**/coverage.cobertura.xml`;
- `.github/workflows/ci-monorepo.yml` uploads the same recursive pattern below
  `${{ matrix.component.path }}`;
- recursive paths remain unquoted inside the YAML block scalar because each
  line is passed to the upload action literally and quote characters would
  become part of the glob;
- artifact upload remains `if: always()` and `if-no-files-found: ignore`, while
  the wrapper itself is the blocking evidence gate;
- no workflow permission, trigger, concurrency group, action SHA, timeout, or
  fork behavior changes.

The recursive upload path preserves actual collector output. It does not move
or merge reports, and it does not alter build artifact identity or provenance
attestation behavior.

## Consumer contract

The template supplies orchestration and threshold enforcement, not the test
framework or coverage package. A .NET consumer must provide a solution or
project discoverable by `dotnet`, categorized tests, and a compatible coverage
collector in its test project. Dependency versions and lockfiles remain
consumer-owned and version-controlled.

If the consumer omits or misconfigures its collector, the wrapper fails because
no measurable report exists. This is an actionable consumer-configuration
failure, not a reason for the template to install an unpinned package.

## Regression strategy

Create `scripts/test/test-dotnet-coverage.sh` using a fake `dotnet` executable
and deterministic Cobertura fixtures. The tests do not require a locally
installed .NET SDK and cover:

1. the collector command is invoked with the required arguments;
2. one report at exactly 80% passes;
3. one report below 80% fails;
4. multiple reports use weighted aggregation;
5. a missing report fails;
6. malformed or impossible counters fail;
7. zero aggregate valid lines fails;
8. a stale report alone is not accepted;
9. a collector command failure is preserved;
10. report discovery errors fail closed even if partial output exists;
11. leading-zero counters are normalized before shell arithmetic;
12. consumer-owned sibling results survive cleanup and a symlinked results
    parent is rejected without changing its external target;
13. the mapper returns the wrapper command.

Extend existing delivery and monorepo workflow contract tests to assert the
recursive .NET coverage paths. Add the new test script to `make test-scripts`.

## Documentation and traceability

Implementation updates:

- `scripts/README.md` with the wrapper contract;
- `docs/development/testing-strategy.md` to distinguish collection from the
  repository-owned threshold enforcement;
- `docs/plans/technical-debt.md` with `TD-0019`, closed only after focused and
  repository-wide checks pass;
- `CHANGELOG.md` under `## [Unreleased]`.

The roadmap is not marked as hosted-.NET verified by this change. Hosted
evidence is recorded only after the later consumer pilot completes on GitHub.

## Security and compatibility

- No new package, global tool, GitHub Action, permission, credential, or
  network integration is introduced by the template fix.
- The wrapper accepts only numeric coverage counters and never evaluates
  report contents as shell code.
- Existing .NET consumers keep the same `dotnet test` collector command and
  receive the documented threshold enforcement instead of a silent pass.
- Python, Node.js, Go, Java, unknown-stack, and version-1 compatibility paths
  do not change.
- Both single-stack and version-2 component-aware .NET execution use the same
  mapper-owned wrapper, preventing duplicated threshold logic.

## Out of scope

- changing the .NET SDK version selected by `actions/setup-dotnet`;
- adopting Microsoft Testing Platform or `coverlet.MTP`;
- replacing `coverlet.collector` with `coverlet.msbuild`;
- adding NuGet caching or a repository-owned package version;
- enforcing branch or method coverage;
- enforcing critical-module or changed-lines thresholds;
- merging multiple reports into one new XML document;
- changing .NET build artifact discovery;
- creating the hosted .NET consumer in the same pull request;
- profile-aware workflow activation, deployment, or production readiness.

## Acceptance criteria

1. The .NET coverage mapper invokes one shared repository wrapper from both
   single-stack and component-aware working directories.
2. The wrapper preserves collector failures and fails when current-run coverage
   evidence is missing or malformed.
3. Aggregate line coverage at exactly 80% passes and coverage below 80% fails.
4. Multiple reports are aggregated by covered and valid line counts, not by an
   unweighted mean of percentages.
5. Stale reports cannot make a collector run appear measurable.
6. Single-stack and component-aware workflows retain recursive Cobertura
   reports from `TestResults` without changing permissions or action pins.
7. Focused shell contracts, workflow contracts, `make test-scripts`,
   `make docs-check`, `make ci`, and `git diff --check` pass.
8. Documentation and `CHANGELOG.md` describe only the implemented contract;
   `TD-0019` closes only with actual passing evidence.
9. No hosted .NET success, production readiness, profile activation, or
   deployment capability is claimed by the template fix.

## Rollback

Revert the mapper entry, wrapper, workflow upload paths, focused tests, and
documentation as one reviewed change. Existing consumers would return to
coverage collection without template-owned threshold enforcement, so rollback
must explicitly acknowledge that the documented 80% .NET gate is no longer
enforced. No database, deployment, secret, environment, or external resource
requires rollback.
