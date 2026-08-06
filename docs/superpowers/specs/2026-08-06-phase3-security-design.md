# Design Spec — Phase 3: Security baseline

**Status:** Approved
**Date:** 2026-08-06
**Owner:** Project owner (@setiyadijoko)
**Builds on:** Phase 1 (`cd785fd`) + Phase 2 (`0bb1677`, merged)

---

## 1. Goal

Add the Level-2 security baseline (with selected Level-3 controls) to `template-ai-native`: six security workflows that scan for committed secrets, dependency vulnerabilities (on PR and on a schedule), license policy violations, code vulnerabilities (SAST), and repository security posture. Blocking policy is applied where the spec mandates (secrets = 0, critical/high dependency vulnerabilities = 0); other findings are advisory and promotable. Tools that require GitHub Advanced Security (CodeQL analysis storage, Scorecard SARIF) degrade gracefully on a private personal repository without GHAS.

## 2. Key decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | SAST (CodeQL) | Ship `codeql.yml` with graceful-degrade | Honest about the private-no-GHAS limitation; ready when repo goes public or gets GHAS. Mirrors the zizmor SARIF pattern already in place. |
| 2 | Blocking policy | Secrets + critical/high deps BLOCK; rest advisory | Spec §15.1/§15.3 mandate zero secrets and zero critical/high vulns; lower severities stay non-noisy on a template with no real deps yet. |
| 3 | Scorecard | Include, advisory (private-repo limitation noted) | Completes spec §15.6 / Level-3 list; limited on private repos. |
| 4 | Container/IaC scan | Defer | No containers or IaC exist in the template; include when assets appear (TD-0005). |
| 5 | Action SHAs | Resolve via `gh api` at implementation time | Phase-1/2 lesson: never trust recalled SHAs. |
| 6 | Dependency audit auto-detect | Reuse stack-detection pattern | `npm audit` / `pip-audit` / `govulncheck` run only when the matching manifest exists; no-op otherwise. |

## 3. Workflow inventory

| Workflow | Trigger | Tool | Blocking | Notes |
|---|---|---|---|---|
| `secret-scan.yml` | PR + push main + weekly cron | gitleaks (gitleaks/gitleaks-action) | **Block on any finding** | PR scans current changes; cron scans full history. Never prints raw secret (gitleaks masks). |
| `dependency-review.yml` | PR | GitHub Dependency Review API (actions/dependency-review-action) | **Block on critical/high** (`fail-on-severity: high`) | No-ops when no dependency change. |
| `dependency-audit.yml` | weekly cron + workflow_dispatch | npm audit / pip-audit / govulncheck (auto-detected) | Advisory (promotable) | Skips when no manifest present. |
| `license-check.yml` | PR (manifest paths) | `scripts/license-check.sh` (allowlist/denylist) | Advisory (promotable) | Allow: MIT, Apache-2.0, ISC, BSD-2/3-Clause, LGPL-2.1+. Deny: GPL-3.0, AGPL-3.0, SSPL, Commons-Clause. |
| `codeql.yml` | PR + push main + weekly cron | github/codeql-action (init/autobuild/analyze) | **Graceful-degrade** (continue-on-error) | On private-no-GHAS: reports clearly, does not block. Blocks normally when GHAS enabled. |
| `scorecard.yml` | push main + weekly cron | ossf/scorecard-action | Advisory; SARIF upload `continue-on-error` | Best on public repos; limited on private. |

## 4. File structure

```text
.github/workflows/
├── secret-scan.yml          # NEW
├── dependency-review.yml    # NEW
├── dependency-audit.yml     # NEW
├── license-check.yml        # NEW
├── codeql.yml               # NEW
└── scorecard.yml            # NEW

scripts/
└── license-check.sh         # NEW — allowlist/denylist license policy
```

Modified existing files: `Makefile`, `scripts/ci-local.sh`, `AGENTS.md`, `docs/security/vulnerability-management.md`, `docs/security/dependency-policy.md`, `docs/plans/technical-debt.md`, `CHANGELOG.md`.

## 5. Workflow designs

### 5.1 `secret-scan.yml`
- `permissions: contents: read`.
- Jobs:
  - `secret-scan-pr` (on `pull_request`): checkout → `gitleaks-action` scanning the PR diff (current changes only).
  - `secret-scan-history` (on `schedule` + `workflow_dispatch`): checkout full history → `gitleaks detect --source . --verbose`.
- Both block on any finding. Gitleaks masks secret values by default; the workflow never prints a raw secret.

### 5.2 `dependency-review.yml`
- Trigger: `pull_request`.
- `permissions: contents: read`.
- Steps: checkout → `actions/dependency-review-action@<sha>` with `fail-on-severity: high`, `comment-verbosity: verbose`, `deny-licenses: ''` (license handled separately).
- Naturally no-ops when the PR has no dependency changes.

### 5.3 `dependency-audit.yml`
- Trigger: `schedule` (weekly, Wed 03:00 UTC) + `workflow_dispatch`.
- `permissions: contents: read`.
- Steps: checkout → detect stack → run the matching audit (`npm audit --audit-level=high`, `pip-audit`, `govulncheck ./...`) → print a summary. Never blocks (advisory). Skips cleanly when no manifest present.

### 5.4 `license-check.yml`
- Trigger: `pull_request` with paths filter for manifest files.
- `permissions: contents: read`.
- Steps: checkout → run `scripts/license-check.sh` which inspects manifests (package.json `license`, `pip-audit -f json` for python, `go list -m -json all` for go) and reports findings. **Advisory in Phase 3**: the script always exits 0 (prints allow/deny matches; warn on denylist match). Promotable to blocking (exit 1 on denylist) in a later phase once the policy is validated.

### 5.5 `codeql.yml`
- Trigger: `pull_request`, `push: main`, `schedule` (weekly).
- `permissions: contents: read, security-events: write`.
- Steps: checkout → `codeql-action/init@<sha>` (languages auto-detected) → `autobuild@<sha>` → `analyze@<sha>` with `continue-on-error: true` and a clear message when Code Scanning is not enabled.
- Job-level `if: always()` not required; the analyze step's failure is non-fatal.

### 5.6 `scorecard.yml`
- Trigger: `push: main` (branch default), `schedule` (weekly).
- `permissions: contents: read, security-events: write`.
- Steps: `ossf/scorecard-action@<sha>` → `github/codeql-action/upload-sarif@<sha>` with `continue-on-error: true`.
- Comment notes the private-repo limitation.

## 6. `scripts/license-check.sh`

POSIX `sh`. Best-effort license inspection across stacks; advisory in Phase 3 (prints findings, exits 0). Logic:
- node: read `license` field from each `package.json` (and `npm ls --json` for transitive where practical).
- python: `pip-audit -f json` (or `pip install pip-licenses`).
- go: `go list -m -json all` → `License` field.
- java: parse `<licenses>` in `pom.xml` (Maven `license-maven-plugin` if available).
- dotnet: `<PackageReference>` License (nuget license info where available).
When no manifest or no license info found → print "no license info available" and exit 0. Denylist match → print warning + exit 0 (advisory now; flip to exit 1 when promoted to blocking).

Allowlist: MIT, Apache-2.0, ISC, BSD-2-Clause, BSD-3-Clause, 0BSD, LGPL-2.1+, MPL-2.0, Unlicense.
Denylist: GPL-3.0, AGPL-3.0, SSPL, Commons-Clause, proprietary/unlicensed (when known).

## 7. Makefile + ci-local integration

- `Makefile` `secret-scan`: `@command -v gitleaks >/dev/null 2>&1 && gitleaks detect --source . --no-banner || echo '[stub] gitleaks runs in CI (.github/workflows/secret-scan.yml)'`.
- `make dependency-scan`: keep stub pointing to CI (no useful local tool without deps).
- `scripts/ci-local.sh`: add `run "gitleaks" gitleaks detect --source . --no-banner`.

## 8. Documentation updates

- `AGENTS.md` "Security rules": note Phase-3 controls (secret-scan blocks; critical/high dep blocks; rest advisory) and cross-ref `docs/security/`.
- `docs/security/vulnerability-management.md`: severity table + policy (critical/high block; medium/low advisory; waiver process).
- `docs/security/dependency-policy.md`: dependency-review + audit + license policy.
- `docs/plans/technical-debt.md`: TD-0004 (promote audit + license to blocking), TD-0005 (container/IaC scan deferred), TD-0006 (CodeQL/Scorecard SARIF limited on private repo).
- `CHANGELOG.md`: `### Added` Phase-3.

## 9. Out of scope

- Container scan (Trivy/Grype) — Phase 5 or when a Dockerfile exists.
- IaC scan (Checkov/tfsec/kube-linter) — when IaC exists.
- DAST, performance gates — Phase 6 or later.
- Codecov / 90% coverage gating — already deferred (TD-0002).

## 10. Assumptions

1. Repo is private + personal → GHAS/Code Scanning not available; CodeQL analyze and Scorecard SARIF upload will `continue-on-error`.
2. Template has no dependencies, containers, or IaC → audit/license/container/iac scans no-op or skip cleanly.
3. Gitleaks GitHub Action and the OSS Scorecard Action work on private repos for the scan step (they do); only SARIF storage to the GitHub Security tab needs GHAS.
4. Consumer can promote advisory checks to blocking by editing thresholds once baselines are measured.

## 11. Acceptance criteria

Phase 3 is complete when:
- All 6 workflows exist, SHA-pinned (resolved via `gh api`), least-privilege, with timeouts + concurrency.
- `scripts/license-check.sh` exists and runs on the empty template without error.
- On the empty template: secret-scan passes (0 secrets); dependency-review no-ops; dependency-audit skips; license-check skips/no-ops; codeql graceful-degrades (analyze continue-on-error); scorecard SARIF upload continue-on-error. All PR checks green.
- `make ci` and `make secret-scan` remain exit 0 on the empty template.
- All Phase-1 + Phase-2 checks remain green.
- Docs (AGENTS.md, security docs, technical-debt, CHANGELOG) updated.
- PR opened on a feature branch, all checks pass, owner merges to `main`.
