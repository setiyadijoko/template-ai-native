# Rollback

**Status:** Manual, environment-bound, unwired, and fail-closed baseline.

Rollback limits customer and business impact by restoring a verified known
state under human authority. The Phase 6 `rollback.yml` workflow performs no
rollback: it validates audit inputs, binds the selected GitHub Environment,
and deliberately fails at an unwired sentinel. A successful readiness check is
not rollback approval and does not make this skeleton operational. The Phase 5
deploy and smoke workflows remain unwired skeletons.

## Required decision record

Before execution, the incident commander or authorized change authority must
record:

- decision authority and approval reference;
- target environment;
- current release and target release;
- the target artifact's lowercase `sha256:` digest;
- successful digest and provenance-attestation verification against the exact
  artifact previously validated for that environment;
- rollback type: application, configuration, feature flag, infrastructure,
  database forward recovery, model, or prompt;
- reason, expected customer and business effect, stop conditions, and
  escalation route;
- recovery checks, evidence owner, and immutable evidence location; and
- most recent exercise date and evidence reference for the selected path.

Do not retrieve or execute an artifact when release identity, digest,
attestation, authorization, environment, compatibility, or evidence is
missing. Never rebuild during rollback.

## Execution and stop conditions

The approved platform-specific runbook must authenticate with job-scoped,
least-privilege credentials, retrieve the exact target artifact, verify digest
and attestation before mutation, execute only the selected rollback type, and
capture each result. Stop and escalate on identity mismatch, failed integrity
verification, expired approval, unexpected data migration state, loss of
observability, or a worsening critical SLI. Do not bypass the environment gate
or the fail-closed sentinel to obtain a green workflow.

Database rollback is not assumed safe. Prefer backward-compatible migrations
and forward recovery. Any destructive production data action requires explicit
human approval, a validated recovery plan, and the database rules in
`AGENTS.md`; AI agents must not modify production data directly.

## Recovery verification and evidence

After any future wired rollback, verify artifact identity, service health,
critical journeys, SLO indicators, dependency health, business outcomes, data
integrity, and relevant AI safety and quality signals. Preserve inputs,
approvals, timestamps, artifact verification, command results, dashboards, and
recovery checks in immutable evidence linked from the incident or change
record. Failed checks keep the incident open and invoke the documented
escalation path.

Exercise each adopted rollback type at its approved cadence and after material
platform or deployment changes. Record the exercise date, environment, release
identities, result, evidence link, owner, and corrective actions.

Activation requires an approved platform design that replaces the sentinel
with artifact retrieval, job-scoped authentication, rollback execution, and
recovery verification. Until then the workflow must fail closed.
