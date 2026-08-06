# Dependency Policy

**Status:** Adapt to your project.

## Phase 3 controls
- **dependency-review (PR, blocking):** `fail-on-severity: high`.
- **dependency-audit (weekly cron, advisory):** `npm audit --audit-level=high` / `pip-audit` / `govulncheck`, auto-detected by manifest.
- **license-check (PR, advisory):** `scripts/license-check.sh` enforces an allowlist/denylist.

## License policy
- **Allow:** MIT, Apache-2.0, ISC, BSD-2-Clause, BSD-3-Clause, 0BSD, LGPL-2.1, MPL-2.0, Unlicense.
- **Deny:** GPL-3.0, AGPL-3.0, SSPL, Commons-Clause.
- Phase 3 is advisory (warn on denylist match, exit 0); promote to blocking in a later phase once the policy is validated (TD-0004).

## Auto-merge
- Dependabot security updates: enabled.
- No auto-merge of major versions; patch auto-merge only when tests green and no new vulnerabilities.
- Known critical dependency vulnerabilities: zero in `main`.
