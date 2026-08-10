# Hosted Java Consumer Pilot Design

**Status:** Approved 2026-08-10
**Date:** 2026-08-10
**Owner:** Project owner (@setiyadijoko)
**Target:** `setiyadinamikaintegrasi/template-java-pilot`

## Problem

The template declares Java 21 and Maven support, but that support has not been
validated end to end in a fresh consumer repository on GitHub-hosted runners.
Local mapper contracts prove command selection; they do not prove Maven plugin
compatibility, workflow orchestration, artifact discovery, security scanning,
or post-merge provenance attestation in an adopted repository.

The pilot must isolate the template contract from application-framework
complexity. A Spring Boot service, database, container, or deployment target
would introduce failure sources that do not help determine whether the generic
Java path is usable.

## Decision

Create a new public consumer repository from `setiyadijoko/template-ai-native`
and adopt a minimal Java 21 Maven application. The application implements one
deterministic domain rule, includes the exact test categories expected by the
template, produces a JAR, and has no network, database, framework, cloud, or
secret dependency.

The pilot is evidence gathering, not a production application. A green run
validates the current single-stack Java contract only. It does not validate
deployment, production readiness, profile-aware activation, or Java frameworks.

## Consumer repository

- Owner: `setiyadinamikaintegrasi`.
- Name: `template-java-pilot`.
- Visibility: public.
- Source: GitHub's template-repository creation flow using
  `setiyadijoko/template-ai-native`.
- Layout: single-stack, with `pom.xml` at the repository root.
- Runtime: Java 21.
- Build system: Maven using the runner-provided `mvn` command required by the
  existing stack mapper.

The initializer personalizes the consumer README and records a `single` layout
with the repository root as the primary component. No profile configuration is
introduced because profile-aware activation remains deferred.

## Pilot application

The consumer contains a small `TicketPriorityClassifier` domain component.
It accepts a request containing severity and customer-impact inputs, validates
required values, and returns a priority enum. Invalid blank or unsupported
inputs fail explicitly with `IllegalArgumentException`.

The component is intentionally pure:

- no HTTP server or framework;
- no persistence or message broker;
- no filesystem, clock, network, or environment dependency;
- no AI provider or nondeterministic behavior;
- no credential or secret requirement.

This gives the hosted pipeline real source and test behavior while keeping any
failure attributable to the Java toolchain or template orchestration.

## Maven contract

The root `pom.xml` pins the versions used by the consumer and configures:

- Java release 21 compilation;
- JUnit 5 for tests;
- Spotless for `spotless:apply` and `spotless:check`;
- Maven Checkstyle Plugin for `checkstyle:check`;
- JaCoCo through a `coverage` profile with an overall line threshold of 80%;
- standard JAR output under `target/`.

The pilot follows the commands already owned by `scripts/stack-tools.sh`. It
does not change the template mapper or substitute wrapper-specific commands.
All consumer dependencies and Maven plugins use explicit versions.

## Test categories

The consumer includes three deterministic categories matching the current
template commands:

1. `*Test` verifies domain rules and invalid-input behavior through
   `mvn -q test`.
2. `*IT` verifies the public classifier boundary through
   `mvn -q verify -Dtest='*IT'`.
3. `*E2E` verifies the complete input-to-priority journey through
   `mvn -q verify -Dtest='*E2E'`.

The JaCoCo `coverage` profile must pass through `mvn -q verify -Pcoverage` with
at least 80% overall line coverage. Tests must assert behavior and must not
exist only to inflate coverage.

## Execution flow

1. Create the public consumer from the latest merged template `main`.
2. Clone the consumer and run the initializer for a single Java project.
3. Create a feature branch containing the Maven contract, application, tests,
   and consumer documentation.
4. Run the repository-native local gates before publication.
5. Push the feature branch and open a draft pull request.
6. Observe every hosted check without weakening or bypassing failures.
7. Classify failures as consumer configuration, template defect, runner/tool
   issue, or external-service issue.
8. Fix consumer-only defects in the pilot branch. A template defect requires a
   separate reviewed template change before the pilot is rerun.
9. Present the green pull-request evidence for human merge approval.
10. After merge, observe the `main` workflow and provenance attestation and
    record the actual run and artifact evidence in the template roadmap.

## Hosted evidence requirements

The pull request must resolve the Java stack and exercise, where triggered:

- Java quality: formatting, lint/checkstyle, and compilation;
- unit, integration, and E2E tests;
- JaCoCo coverage with the configured threshold;
- JAR build and artifact upload;
- CodeQL;
- OSV dependency scanning;
- secret scanning;
- metadata, documentation, workflow syntax, workflow security, and
  production-readiness contract checks.

Skipped checks are acceptable only when the workflow design explicitly makes
them inapplicable. A skipped Java quality, test, coverage, or build job is a
pilot failure. Advisory AI or graph-review availability does not determine the
Java contract verdict.

After merge, the pilot must capture:

- the `main` run URL and conclusion;
- the Java build artifact name and presence;
- the attestation job conclusion;
- the attested subject name and digest when GitHub exposes them;
- failed, skipped, or noisy checks and their classification;
- any template change required to obtain the result.

Evidence is recorded only from actual GitHub runs. Local results must not be
reported as hosted results.

## Error and security behavior

- No credentials are committed or required by the application.
- Workflow permissions, action pins, fork behavior, and security thresholds
  inherited from the template are not weakened for the pilot.
- A failing required check remains failing until its cause is understood.
- No check is disabled solely to make the pilot green.
- Dependency or plugin resolution failures are recorded with exact hosted logs
  before changing versions.
- The public repository contains only synthetic domain data.
- The pilot is not deployed and does not create GitHub Environments or cloud
  resources.

## Documentation and evidence disposition

The consumer README explains that the repository is a hosted template
validation pilot, not a production service. PRODUCT, DESIGN, and architecture
documents describe only the small classifier and the evidence objective.

When the pilot completes, update `docs/plans/roadmap.md` in the template with
the repository, pull request, hosted run links, conclusions, important runtime
or noise observations, and any remaining limitation. Add technical debt only
for a real deferred gap; do not create debt for expected consumer-owned work.

## Out of scope

- Spring Boot, Jakarta EE, Quarkus, Micronaut, or another application framework;
- HTTP endpoints, authentication, database, queue, cache, or migration;
- Docker, Kubernetes, Terraform, deployment, smoke testing, or rollback;
- AI prompts, providers, evaluations, or semantic review configuration;
- Maven-wrapper adoption or a template mapper change;
- Java monorepo/component-aware validation;
- .NET validation;
- profile-aware workflow activation;
- branch-protection changes in the consumer repository;
- claims of production readiness.

## Acceptance criteria

1. The consumer repository is created publicly from the latest template
   `main`, not assembled by copying selected files.
2. The initializer records a single Java consumer without introducing a
   profile or speculative infrastructure.
3. Local stack detection reports `java`, and repository-native local gates
   pass before the pull request is opened.
4. Hosted Java quality, test categories, coverage, and build jobs execute and
   pass on the pull request.
5. The build workflow uploads the expected Java artifact without changing the
   template's artifact identity.
6. Blocking security and governance checks pass without weakened policies.
7. No real credential, sensitive data, external service, or deployment target
   is introduced.
8. Human approval controls the pilot merge.
9. The post-merge `main` workflow and provenance attestation pass, with actual
   run and subject evidence recorded.
10. The template roadmap distinguishes verified hosted behavior from remaining
    limitations and does not overstate production readiness.

## Rollback

Before merge, close the consumer pull request and leave its branch available for
diagnosis. After merge, revert the consumer merge commit if required. The pilot
has no data, deployment, environment, or external resource to roll back.

The consumer repository is retained as evidence unless the project owner
explicitly authorizes deletion. Any template remediation remains a separate,
reviewed change and is never hidden inside the pilot repository.
