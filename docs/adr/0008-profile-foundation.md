# ADR-0008: Establish a declarative maturity-profile foundation

- **Status:** Accepted — foundation only; workflow activation deferred
- **Date:** 2026-08-10
- **Decision owners:** Template maintainers and consumer project owners

## Context

The template currently provides one governed baseline for every consumer. A
proposed Starter/Standard/Enterprise model can make adoption proportional, but
activating profile-specific workflows immediately could remove required checks,
leave pending contexts, or change the security posture of existing consumers.
The repository therefore needs a reviewable profile contract before any CI
activation is attempted.

## Decision

Add an optional, credential-free `.template/profile.yaml` contract with schema
version `1`. The template ships `.template/profile.schema.yaml` and a
documentation-only `.template/profile.yaml.example`; it does not ship an
active profile file and does not change workflow execution.

The contract has these sections:

```yaml
version: 1
profile: standard
project:
  type: web-app
stack:
  primary: auto
ai:
  enabled: true
  evaluation: true
  semantic_review: advisory
  structural_review: advisory
deployment:
  enabled: false
  target: none
controls:
  secret_scan: true
  dependency_review: true
  codeql: true
  coverage: true
  sbom: false
  artifact_attestation: false
  scorecard: false
```

`sh scripts/validate-profile-config.sh [PATH]` validates this bounded shape
with standard POSIX tools. It rejects unknown fields, duplicate fields,
unsupported enum values, malformed indentation, and credential-like keys. If
the file is absent, it reports compatibility mode and exits successfully.

### Normative control mapping

The following mapping is the foundation policy and is also recorded in the
machine-readable `.template/profile-controls.yaml`. It describes the desired
control posture; it is not automatically applied until a later activation
decision.

| Control | Starter | Standard | Enterprise |
|---|:---:|:---:|:---:|
| Core docs, AGENTS, PR template | Required | Required | Required |
| Unit tests and secret scan | Required | Required | Required |
| Dependency vulnerability baseline | Required | Required | Required |
| Type checking and coverage gate | Optional | Required | Required |
| CodeQL/SAST | Optional | Required | Required |
| AI evaluation for AI projects | Optional | When AI is enabled | Required for AI projects |
| Semantic AI review | Off | Advisory | Enabled by policy |
| Structural graph review | Off | Advisory | Enabled |
| SBOM and artifact attestation | Off | Optional | Required |
| Scorecard | Off | Optional | Required |
| Production governance | When deployed | When deployed | Required |
| SLOs, runbooks, readiness evidence | Minimal | Required for production | Strongly required |

The validator checks configuration shape and safe values only. It does not
enforce that every `controls` boolean matches the profile row yet; enforcing
that policy belongs to activation and would be a behavior change.

### Blocking and execution policy

Until activation is separately approved:

- Existing required check contexts remain unchanged.
- Repositories without `.template/profile.yaml` retain the current baseline
  and security defaults.
- Profile files are documentation/configuration evidence only; no workflow
  reads them to skip, add, or downgrade a check.
- Future activation must classify each control as blocking, advisory,
  scheduled, or manual and must publish one stable aggregate context per
  profile without leaving disabled checks pending.
- Production deployment remains human-gated and cannot become an AI-only
  decision because of profile selection.

## Alternatives considered

### Put profile conditions directly into every workflow

Rejected. This would duplicate policy, risk check-context drift, increase CI
noise, and make existing branch protection dependent on a new optional file.

### Require a YAML parser or new runtime dependency

Rejected for the foundation. The contract is deliberately small; a strict
POSIX validator keeps empty-template and consumer bootstrap behavior portable.

### Make Enterprise the default

Rejected. It would impose cost and review overhead on low-risk consumers and
would contradict proportional adoption.

### Infer a profile from repository contents

Rejected. Risk, data sensitivity, and operational criticality are business
decisions that cannot be safely inferred from a stack or file layout.

## Consequences

Positive:

- Consumers have one versioned, reviewable place to declare intended maturity.
- Existing consumers remain backward-compatible when the file is absent.
- Control mapping and activation risks are explicit before workflow changes.
- The contract is testable without adding a provider, cloud SDK, or framework.

Trade-offs:

- The profile is not operational yet; consumers must still select controls
  explicitly.
- Shape validation cannot prove that a consumer's selected controls are
  appropriate for its risk level.
- A later activation design must preserve stable GitHub check contexts and
  document migration for branch protection.

## Security implications

The profile file accepts no credentials, tokens, provider endpoints, or
arbitrary commands. Existing secret scanning, least-privilege Actions, SHA
pinning, fork-safe triggers, and human production approval remain unchanged.
An absent or invalid profile cannot silently disable a security workflow.

## Migration strategy

1. Existing consumers continue without a profile and remain in compatibility
   mode.
2. A consumer may copy the example to `.template/profile.yaml`, edit values,
   and run the validator as a documentation/configuration check.
3. A future activation ADR must define stable check contexts, fallback
   behavior, control ownership, and a tested initializer migration before any
   workflow condition is added.
4. A hosted consumer pilot must validate adoption cost, fork behavior, and
   branch-protection compatibility before activation becomes blocking.

## Rollback considerations

Because this ADR does not modify workflows, rollback is deleting the optional
profile file and reverting the documentation/validator change. Future
activation must provide an explicit switch back to the current baseline and
must not fall through to an inferred profile.
