# Agent Implementation Workflow

This document contains the detailed workflow referenced by the canonical
[`AGENTS.md`](../../AGENTS.md). Follow it for every feature, bug fix, document
change, and maintenance task in this repository or a consumer repository.

Every task follows this nine-step loop:

1. **Orient** — read `AGENTS.md → PRODUCT.md → DESIGN.md → ARCHITECTURE.md → relevant ADRs → active plans → code → tests`. Summarize the understood scope before changing code.
2. **Inspect** — review the existing implementation, patterns, dependencies, tests, interfaces, security boundaries, recent changes, and reusable components. Do not assume a component is absent before searching for it.
3. **Define success** — convert the request into measurable acceptance criteria, test cases, verification commands, expected artifacts, and explicit remaining risks.
4. **Plan** — identify files to create or modify, tests, documentation, risks, security considerations, verification steps, and rollback implications.
5. **Implement incrementally** — make the smallest coherent change; never mix feature work with unrelated refactoring, dependency upgrades, style-only changes, architecture changes, or infrastructure modernization.
6. **Test continuously** — add or update tests with the implementation. Use a failing test first for bugs and behavior changes where practical.
7. **Self-review the diff** — check correctness, security, data leakage, accidental changes, missing tests, backward compatibility, unnecessary abstractions, dead code, misleading comments, overengineering, and documentation gaps.
8. **Verify** — execute the applicable commands and record actual results. Never fabricate command output, test results, security findings, deployment status, or evaluation scores.
9. **Report** — state what changed and why, design impact, tests performed, security checks performed, AI evaluations performed, remaining risks, deferred technical debt, and deployment implications.
