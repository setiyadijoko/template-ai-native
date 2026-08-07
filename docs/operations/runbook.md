# Runbook

**Status:** Enforceable runbook structure; consumer ownership and exercised
evidence are required for activation.

Runbooks turn detection into safe, auditable human action. Every runbook entry
must identify owner, scope, symptoms, severity, prerequisites, diagnosis,
safe mitigation, rollback or stop criteria, escalation, communications,
recovery verification, immutable evidence location, and post-incident record.
Commands must state their environment and access assumptions, avoid embedded
credentials or customer data, and stop when identity or safety checks fail.

During an incident, the incident commander owns severity and recovery
decisions; the service owner supplies technical diagnosis; the communications
owner coordinates stakeholder updates. Preserve timestamps, deploy and release
identity, decisions, approvals, observations, and verification results. Review
the runbook after exercises, material system changes, and incidents that expose
a gap.

## Common incidents

### High error rate after deployment

- **Owner and scope:** service owner for the affected production service and
  environment; applies when error rate or error-budget burn correlates with a
  new deploy ID.
- **Symptoms and severity:** sustained error increase, failed business
  outcomes, or dependency failure. Assign severity from
  [alerting.md](alerting.md) based on impact, not error count alone.
- **Prerequisites:** active incident record, named incident commander, safe
  access to dashboards and deployment evidence, and verified current release
  identity.
- **Diagnosis:** compare the error start time with deploy ID and version;
  inspect safe error classifications, critical journey and dependency health,
  saturation, and change records. Do not expose payloads while investigating.
- **Safe mitigation:** stop further promotion, isolate an unsafe feature or
  dependency only through an approved reversible control, and prepare the
  documented rollback path.
- **Rollback or stop criteria:** use [rollback.md](rollback.md) when impact is
  attributable to the current release and the target artifact is verified.
  Stop if artifact identity, authority, database compatibility, or recovery
  checks are uncertain; escalate instead of improvising.
- **Escalation and communications:** route to the incident commander, service
  owner, change authority, and security or data owner when their boundary is
  involved. Communicate scope, impact, mitigation, and next decision point
  through the approved incident channel.
- **Recovery verification and evidence:** confirm SLI recovery, critical
  journeys, dependency health, and business outcomes across a stable
  observation period. Preserve dashboards, release identity, approvals,
  actions, and results in immutable evidence, then link the post-incident
  review.

### Elevated AI cost / latency

- **Owner and scope:** AI service owner for the affected environment, model
  route, prompt version, and business journey.
- **Symptoms and severity:** unexpected cost or latency, token growth,
  excessive fallback, tool failures, quality regression, or guardrail events.
  Set severity from customer, financial, safety, and error-budget impact.
- **Prerequisites:** active incident record, correlation and deploy IDs, safe
  AI telemetry, approved routing policy, and named decision authority.
- **Diagnosis:** compare provider, model, prompt version, completion status,
  latency, token counts, estimated cost, fallback path, tool outcomes,
  guardrail events, evaluation score, and feedback without reading raw
  sensitive content.
- **Safe mitigation:** apply an approved cost limit, disable a risky route,
  reduce non-critical traffic, or select a previously evaluated fallback
  through the controlled model gateway.
- **Rollback or stop criteria:** roll back model, prompt, configuration, or
  application only when the target version and evaluation evidence are
  verified. Stop automated AI actions when safety, authorization, output
  validation, or cost controls cannot be confirmed.
- **Escalation and communications:** involve the incident commander, AI service
  owner, product owner, security or privacy authority, and provider owner as
  applicable. Report impact and mitigation without prompt, response, tool
  argument, credential, or customer content.
- **Recovery verification and evidence:** verify latency, cost, completion,
  fallback, guardrail, evaluation, and business outcome signals. Preserve the
  approved change, model and prompt identities, telemetry snapshots, and
  decisions in immutable evidence, then link the post-incident review.
