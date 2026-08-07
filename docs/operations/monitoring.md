# Monitoring

**Status:** Enforceable SLI/SLO policy; consumer targets require approval and
evidence.

Monitoring must show whether the service is delivering its business outcome,
not merely whether infrastructure is running. The service owner and product
owner approve service-level objectives before the readiness manifest becomes
`active`; the production change authority governs responses when error budgets
are exhausted.

## Required indicators

Define service-level indicators for:

- request or workload rate;
- error rate, including safe failure classifications;
- latency for the customer-critical path;
- dependency availability, latency, and failure rate;
- compute, memory, storage, connection, and queue saturation as applicable;
- business outcomes and failed or delayed business transactions; and
- AI cost, latency, completion, fallback, guardrail, evaluation, and feedback
  quality signals.

Each SLO record must contain an accountable owner, service and environment
scope, measurement query, approved target, measurement window, exclusions,
authoritative data source, and next review date. Targets are consumer decisions
derived from business criticality, risk, user expectations, and measured
baseline; this template does not supply numeric SLO, RTO, RPO, or capacity
targets.

## Dashboards and evidence

Each production service and environment must have an owned dashboard that
shows current SLI values, SLO target and window, error-budget consumption,
deploy ID and version, dependency and saturation signals, and relevant
business and AI indicators. Dashboard and query changes require review and a
repository or change-record reference. Preserve enough history to investigate
the selected SLO window and applicable audit obligations.

## Error-budget response

- At 50% consumption, the service owner reviews burn rate, customer impact,
  and correlation with deployments or dependency changes, then records the
  outcome.
- At 75% consumption, the change authority restricts risky releases and assigns
  an owned, dated mitigation unless an incident commander authorizes a
  recovery-critical exception.
- At 100% consumption, stop non-recovery releases and invoke the documented
  incident and change authority until recovery is verified and continuation is
  approved.

Review SLOs on their recorded review dates and after material business,
architecture, dependency, model, or incident changes. A passing readiness check
confirms required references and values exist; it does not approve the targets
or prove the service is meeting them.
