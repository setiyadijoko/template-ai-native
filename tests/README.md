# Tests

**Status:** Skeleton — populate once a stack is wired.

See [../docs/development/testing-strategy.md](../docs/development/testing-strategy.md) for the strategy and thresholds.

| Subdir | Contains |
|--------|----------|
| `unit/` | domain rules, validation, routing, parsers, guardrails |
| `contract/` | FE↔BE, adapter, tool-interface contracts |
| `integration/` | DB, migrations, queues, auth, external adapters (test doubles) |
| `e2e/` | critical user/business journeys |
| `security/` | security-specific tests (alongside CI scans) |
| `performance/` | performance tests (when justified) |
