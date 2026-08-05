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

## Thresholds (spec §8, configurable)

- Overall unit coverage ≥80%
- Critical domain modules ≥90%
- Changed-lines coverage ≥90%
- Critical security findings = 0
- Committed secrets = 0
- Blocking lint/type errors = 0
- Failed required AI evaluations = 0
- Undocumented breaking API changes = 0

No meaningless coverage-only tests.
