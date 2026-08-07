# Observability

**Status:** Enforceable template baseline; consumer backend and evidence are
required for activation.

Observability exists to make customer impact, unsafe AI behavior, deployment
regressions, dependency failures, and recovery status visible to accountable
humans. A green readiness check validates the repository contract; it does not
approve production. The committed `template` state is valid but always reports
`production_ready=false`. `active` requires a reviewed platform decision,
named ownership, and complete SLO, alert, recovery, and rollback evidence.

## Ownership and evidence

The service owner owns the telemetry contract and names the operations team
authorized to change collection, retention, dashboards, and alerts. Before
activation, record the selected backend, data classification and retention
rules, dashboard and alert references, SLO definitions, runbook links, and
evidence from rollback and restore exercises when recovery applies. Review the
contract after material service, dependency, data-classification, model, or
deployment changes and after incidents that expose an observability gap.

## Telemetry contract

Every structured log event must include:

- timestamp, level, service, environment, version, and deploy ID;
- correlation ID and a stable event name; and
- a safe error classification that supports aggregation without exposing
  sensitive content.

Metrics must cover:

- RED signals: request rate, error rate, and duration;
- dependency health and latency;
- resource and queue saturation;
- business outcomes defined by the product owner; and
- AI cost, quality, safety, and fallback behavior.

Traces must propagate correlation across inbound requests, service and worker
boundaries, queues, data stores, model gateways, and external dependencies.
Sampling policy must preserve incident and error visibility and be documented
with its owner and review evidence.

AI telemetry must identify provider, model, prompt ID and version, completion
status, latency, input and output token counts, estimated cost, fallback path,
tool calls, guardrail events, evaluation score, and user or reviewer feedback.
Tool and guardrail records describe outcomes and classifications, not sensitive
arguments or content.

## Data boundary

Do not collect raw sensitive prompts or responses, credentials, access tokens,
session tokens, customer payloads, or production data by default. Any approved
exception requires data-owner and security approval, documented purpose and
retention, access control, minimization or redaction, and auditable deletion.
Telemetry failures must not cause sensitive content to be written to fallback
logs.

## Validation

Run both supported interfaces when changing the manifest or its evidence:

```bash
make readiness-check
sh scripts/validate-production-readiness.sh observability/production-readiness.conf
```

OpenTelemetry is the recommended vendor-neutral instrumentation boundary; the
consumer records the approved backend separately.
