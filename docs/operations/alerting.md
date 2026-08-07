# Alerting

**Status:** Enforceable alert policy; consumer routing and thresholds require
reviewed activation evidence.

Alerts exist to route actionable customer or operational risk to a human with
authority to respond. Metrics without an owned response path do not satisfy
production readiness.

## Severity model

- **SEV-1 — Critical:** widespread or severe business impact, safety or
  security risk, or loss of a critical production capability. Page the primary
  on-call and incident authority immediately through the approved human route.
- **SEV-2 — High:** material degradation, contained high-risk failure, or a
  rapidly consuming error budget. Page the owning on-call and escalate if
  impact or burn increases.
- **SEV-3 — Moderate:** limited degradation with a safe workaround or adequate
  remaining budget. Route to the owning team for timely investigation.
- **SEV-4 — Low:** informational risk, trend, or maintenance condition that
  does not require interruption. Route to the owned operational queue.

The service owner maps each alert to one severity and a tested primary and
backup human route. Routing must not depend solely on a dashboard, mailbox, or
AI agent. The incident commander may raise severity as impact becomes clearer;
downgrades require recorded rationale.

## Required alert content

Every notification must include severity, service, environment, symptom, start
time, current value, threshold, deploy ID, dashboard link, runbook link, and
accountable owner. Use safe identifiers and classifications. Do not include
credentials, tokens, raw sensitive prompts or responses, customer payloads, or
other production data.

## Noise and lifecycle controls

- Group and deduplicate notifications for the same service, environment,
  symptom, and incident while preserving the first-seen time and latest value.
- Define hysteresis or separate trigger and recovery conditions so normal
  measurement fluctuation does not repeatedly page responders.
- Suppress only through an approved maintenance window with owner, scope,
  reason, start, expiry, and audit record; suppression must expire
  automatically and must not hide unrelated critical symptoms.
- Route recovery notifications to the active responders and require the
  runbook's recovery checks before closing the incident.

Review alert ownership, routing, thresholds, grouping, and runbook links at
least quarterly and after every incident that revealed late, noisy, missing,
or misrouted detection. Store review evidence and corrective actions with an
owner and due date. See [runbook.md](runbook.md).
