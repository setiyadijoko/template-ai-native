# observability/

This directory owns the vendor-neutral production-readiness contract and the
consumer's reviewed observability assets: collector configuration, dashboards,
alert rules, SLO definitions, and evidence references.

## Readiness lifecycle

`production-readiness.conf` starts in `template` status. Both valid `template`
and `active` states report `readiness_contract_valid=true` and
`production_ready=false`; a successful check is never production approval.

A consumer may change the status to `active` only after an approved platform
decision identifies the production environment and observability backend, and
the service owner has supplied reviewed SLO, alert, recovery, restore when
applicable, and rollback evidence. Active status fails closed when any required
field, policy, or evidence reference is incomplete. The validator does not
verify human review, evidence freshness, or content approval. Human change
authority and the protected production Environment remain responsible for
approval.

Validate the committed contract locally with either interface:

```bash
make readiness-check
sh scripts/validate-production-readiness.sh observability/production-readiness.conf
```

Keep the manifest limited to non-secret operational metadata and
repository-relative evidence paths. Never put credentials, tokens, raw
sensitive prompts or responses, customer payloads, or production data in it.
See [observability policy](../docs/operations/observability.md),
[monitoring policy](../docs/operations/monitoring.md), and
[rollback policy](../docs/operations/rollback.md).
