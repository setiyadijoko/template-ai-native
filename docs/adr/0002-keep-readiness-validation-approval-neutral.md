# ADR-0002: Keep readiness validation approval-neutral

- **Status:** Accepted
- **Date:** 2026-08-07

## Context

The Phase 6 manifest has `template` and `active` states. Active validation can
prove that required values are populated, dates and field relationships are
valid, and evidence references resolve to repository-confined regular files.
It cannot prove that an authorized human reviewed the referenced content, that
the evidence is fresh for a particular production change, or that the protected
production Environment approved the change.

Emitting `production_ready=true` after repository-only validation would merge
contract validity with production authorization and create false assurance.

## Decision

Readiness validation is contract and evidence-reference validation only. A
successful `template` or `active` validation prints its status plus:

```text
readiness_contract_valid=true
production_ready=false
```

Active status additionally enforces populated operational fields and valid
reference shape. Production approval remains a separate human decision enforced
through protected platform controls, including the GitHub production
Environment where applicable. The validator does not verify human review,
evidence freshness, or content approval.

## Alternatives considered

- **Keep `production_ready=true` for active status and introduce schema-v2
  evidence:** rejected. Repository evidence could improve traceability, but a
  schema cannot itself prove current human authorization or external platform
  protection. The boolean would still overstate what the validator establishes.
- **Contract-only, approval-neutral output:** selected. This preserves useful
  fail-closed structural validation without representing it as production
  authorization.

## Consequences

- Automation may gate on `readiness_contract_valid=true`, but must not treat it
  as permission to deploy or mutate production.
- Both valid states retain exit code zero while always reporting
  `production_ready=false`.
- Active validation remains useful for detecting missing, malformed, unsafe,
  or internally inconsistent operational references.
- Human and platform approval evidence must be evaluated outside this validator.

## Security implications

The decision prevents a repository-controlled boolean from bypassing human or
environment gates. The readiness workflow remains read-only and gains no
credential, OIDC permission, secret, or production command.

## Data implications

None. The manifest remains limited to non-secret operational metadata and
repository-relative evidence references.

## Operational implications

Operators must review evidence content and freshness for the specific change,
then use the authorized production process. A green readiness workflow is only
contract evidence and never production approval.

## Migration strategy

Consumers must stop interpreting `production_ready=true`; the validator no
longer emits it. Consumers should read `readiness_contract_valid=true` for
contract validity and retain a separate human/platform approval gate. No
manifest schema change is required because field validation semantics remain
compatible.

## Rollback considerations

Reintroducing a positive production-approval signal requires a superseding ADR
and a design that proves human authorization, evidence freshness, content
approval, and protected-environment enforcement. Reverting only the output
boolean is not acceptable.
