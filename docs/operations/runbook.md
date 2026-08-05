# Runbook

**Status:** Adapt to your project.

Operational runbooks indexed by symptom. Each entry: symptom, severity, diagnosis steps, mitigation, escalation, post-incident link.

## Common incidents

### High error rate after deploy
- Diagnose: check deploy id, error metrics, recent change.
- Mitigate: rollback per [rollback.md](rollback.md).
- Escalation: on-call.

### Elevated AI cost / latency
- Diagnose: model routing, token usage, fallback events.
- Mitigate: adjust budgets/routing.
