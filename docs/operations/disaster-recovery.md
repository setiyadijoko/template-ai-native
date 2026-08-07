# Disaster Recovery

**Status:** Enforceable continuity policy; consumer objectives, authority, and
exercise evidence are required for activation.

Disaster recovery restores an acceptable business service after loss of a
site, region, platform, critical dependency, or operational control. The
business owner approves service priorities and recovery objectives; the
incident or continuity authority decides failover and failback; service, data,
security, and communications owners execute their bounded responsibilities.

## Recovery plan

For each critical service, document:

- approved recovery time objective (RTO) and recovery point objective (RPO),
  with business rationale, owner, scope, and review date;
- dependencies and recovery order, including identity, networking, secrets,
  data, queues, application services, observability, AI gateways, and external
  providers as applicable;
- conditions and authority for disaster declaration, failover, degraded
  operation, suspension, and failback;
- internal, customer, regulator, provider, and executive communications,
  including owner, approval route, audience, and update trigger;
- safe failover steps, integrity and compatibility checks, traffic or workload
  controls, and stop conditions; and
- failback prerequisites, reconciliation, critical-journey verification,
  business and AI outcome checks, and closure authority.

RTO and RPO are consumer-approved business targets. This template does not
invent numeric objectives and a readiness check does not prove they can be met.
Recovery evidence must demonstrate the adopted plan against the approved
objectives.

## Exercises and corrective action

Set an exercise cadence based on business criticality, regulatory obligations,
architecture change, and prior results. Exercise after material dependency,
topology, data, access, or platform changes and after a disaster exposes a plan
gap. Include decision-making and communications as well as technical recovery.

Preserve scenario, scope, participants, authority, timestamps, recovery point,
dependency order, failover and failback results, measured RTO/RPO outcomes,
integrity and reconciliation results, communications evidence, and final
approval in an immutable location. Every gap requires a named owner, risk,
corrective action, due date, and verification. Unaccepted gaps keep the related
readiness evidence incomplete and invoke the documented risk authority.
