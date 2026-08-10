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

- Overall automated-test coverage ≥ 80% — **enforced in Phase 2**
  (`fail-under=80`) when a supported stack is detected. Python follows the
  consumer's pytest discovery configuration instead of forcing coverage to the
  unit-test directory; tests must remain in their correct unit, contract,
  integration, or E2E category. The first application PR has no bootstrap
  bypass; below-threshold results fail with the active threshold in the log.
  .NET runs its consumer-owned XPlat collector in an isolated current-run
  results directory; the repository wrapper aggregates Cobertura line counters
  across test projects and fails closed below 80% or when evidence is missing
  or invalid.
  The initializer remains stack-agnostic and does not generate application
  tests. See the minimal tested consumer fixture under
  `tests/fixtures/consumer-monorepo/`.
- Critical domain modules ≥ 90% — deferred to Codecov (TD-0002).
- Changed-lines coverage ≥ 90% — deferred to Codecov (TD-0002).
- Critical security findings = 0 (Phase 3).
- Committed secrets = 0 (Phase 3).
- Blocking lint/type errors = 0 — enforced in Phase 2.
- Failed required AI evaluations = 0 (Phase 4).
- Undocumented breaking API changes = 0.

No meaningless coverage-only tests.
