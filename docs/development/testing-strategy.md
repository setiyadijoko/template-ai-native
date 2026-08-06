# Testing Strategy

**Status:** Adapt to your project.

| Level | What | Where |
|-------|------|-------|
| Unit | domain rules, validation, routing, parsers, guardrails | `tests/unit/` |
| Contract | FE↔BE, adapters, tool interfaces | `tests/contract/` |
| Integration | DB, migrations, queues, auth, adapters (test doubles) | `tests/integration/` |
| E2E | critical journeys only | `tests/e2e/` |
| Security | secret/SAST/dependency/container/IaC | CI workflows |
| AI | regression, safety, leakage, cost | `evals/` |

## Thresholds (spec §8, partially phased)

- Overall unit coverage ≥ 80% — **enforced in Phase 2** (`fail-under=80`) when a coverage tool is present; skipped when stack is unknown.
- Critical domain modules ≥ 90% — deferred to Codecov (TD-0002).
- Changed-lines coverage ≥ 90% — deferred to Codecov (TD-0002).
- Critical security findings = 0 (Phase 3).
- Committed secrets = 0 (Phase 3).
- Blocking lint/type errors = 0 — enforced in Phase 2.
- Failed required AI evaluations = 0 (Phase 4).
- Undocumented breaking API changes = 0.

No meaningless coverage-only tests.
