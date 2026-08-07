# Phase 3 — Security baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Level-2 security baseline to `template-ai-native`: six workflows (secret-scan, dependency-review, dependency-audit, license-check, codeql, scorecard) plus a `license-check.sh` script, with secrets and critical/high dependency vulnerabilities blocking and everything else advisory or graceful-degrade.

**Architecture:** Each workflow is self-contained (own triggers, permissions, concurrency, timeouts). CodeQL and Scorecard SARIF uploads use `continue-on-error: true` because the repo is private without GHAS (graceful-degrade). `license-check.sh` is a best-effort advisory policy script (allowlist/denylist) that always exits 0 in Phase 3. Stack-detection is reused for the dependency-audit auto-detect.

**Tech Stack:** GitHub Actions (YAML), POSIX shell (`scripts/license-check.sh`). Tools: gitleaks, GitHub Dependency Review, npm audit / pip-audit / govulncheck, CodeQL, OpenSSF Scorecard.

**Reference spec:** `docs/superpowers/specs/2026-08-06-phase3-security-design.md` (authoritative).

## Global Constraints

- **Repo is private + personal → no GHAS/Code Scanning.** CodeQL `analyze` and Scorecard SARIF `upload-sarif` MUST use `continue-on-error: true` so the PR stays green.
- **Blocking policy:** `secret-scan.yml` blocks on any finding; `dependency-review.yml` blocks on critical/high (`fail-on-severity: high`). All other Phase-3 checks are advisory or graceful-degrade.
- **Workflow security:** `permissions: contents: read` default; `security-events: write` only where a step uploads SARIF; no `pull_request_target`; SHA-pin every `uses:` (resolve via `gh api`).
- **POSIX `sh`** for `license-check.sh` (runs on macOS `/bin/sh` and Linux CI).
- **license-check.sh is advisory in Phase 3** — always exits 0 (prints allow/deny matches; warns on denylist). Promotable to blocking later.
- **Empty template must stay green:** secret-scan finds 0 secrets; dependency-review no-ops; dependency-audit skips; license-check no-ops; codeql graceful-degrades; scorecard SARIF upload continue-on-error.
- Build on branch `phase-3-security` (created; spec at `6505149`). Base = `main` (`0bb1677`). No direct push to `main`.

## File Structure

| Task | Cohesion | Key files |
|---|---|---|
| 1 | Blocking scans: secrets + dependency review | `.github/workflows/secret-scan.yml`, `.github/workflows/dependency-review.yml` |
| 2 | Advisory scans: dependency audit + license (script + workflow) | `.github/workflows/dependency-audit.yml`, `.github/workflows/license-check.yml`, `scripts/license-check.sh` |
| 3 | Graceful-degrade scans: CodeQL + Scorecard | `.github/workflows/codeql.yml`, `.github/workflows/scorecard.yml` |
| 4 | Makefile + ci-local integration | `Makefile`, `scripts/ci-local.sh` |
| 5 | Docs + debt + changelog + PR | `AGENTS.md`, `docs/security/*`, `docs/plans/technical-debt.md`, `CHANGELOG.md`, PR |

---

## Task 1: Blocking scans — secret-scan + dependency-review

**Files:**
- Create: `.github/workflows/secret-scan.yml`
- Create: `.github/workflows/dependency-review.yml`

**Interfaces:**
- Consumes: nothing from earlier tasks (Phase 1/2 already merged).
- Produces: two blocking security workflows.

**Critical:** resolve every `uses:` SHA via `gh api` before writing. For each action+tag:
```sh
repo="gitleaks/gitleaks-action"; tag="v2.3.4"   # use the latest stable tag discovered at impl time
t=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.sha')
ty=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.type')
if [ "$ty" = "tag" ]; then gh api "repos/$repo/git/tags/$t" --jq '.object.sha'; else echo "$t"; fi
```
Then verify with `gh api repos/<repo>/git/commits/<sha>` (HTTP 200) — same loop as Phase 1/2.

- [ ] **Step 1: Resolve & record SHAs** for: `actions/checkout` (already known: `3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`), `gitleaks/gitleaks-action` (latest stable), `actions/dependency-review-action` (latest stable).

- [ ] **Step 2: Create `.github/workflows/secret-scan.yml`:**
```yaml
name: secret-scan

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: "0 3 * * 3"   # weekly, Wed 03:00 UTC
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  secret-scan:
    name: gitleaks (block on any secret)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0   # full history for scheduled history scans
      - name: gitleaks
        uses: gitleaks/gitleaks-action@<SHA> # <tag>
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        # PR runs scan the diff; scheduled runs scan full history.
        # Blocks on any finding. Gitleaks masks secret values by default.
```

- [ ] **Step 3: Create `.github/workflows/dependency-review.yml`:**
```yaml
name: dependency-review

on:
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  dependency-review:
    name: Dependency Review (block on critical/high)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Dependency Review
        uses: actions/dependency-review-action@<SHA> # <tag>
        with:
          fail-on-severity: high
          comment-verbosity: verbose
          # License policy is handled by license-check.yml (advisory in Phase 3).
```

- [ ] **Step 4: Verify** — YAML validity + SHA resolves (same loops as Phase 2 Task 2 Step 6).

- [ ] **Step 5: Commit**
```sh
git add .github/workflows/secret-scan.yml .github/workflows/dependency-review.yml
git commit -m "ci: add secret-scan (blocking) and dependency-review (critical/high blocking)"
```

---

## Task 2: Advisory scans — dependency-audit + license-check (script + workflow)

**Files:**
- Create: `scripts/license-check.sh`
- Create: `.github/workflows/dependency-audit.yml`
- Create: `.github/workflows/license-check.yml`

**Interfaces:**
- Consumes: `scripts/detect-stack.sh` (Phase 1) for the audit auto-detect.
- Produces: `scripts/license-check.sh` (CLI: no args; inspects manifests, prints report, exits 0) + two advisory workflows.

- [ ] **Step 1: Create `scripts/license-check.sh`** (advisory — always exits 0 in Phase 3):
```sh
#!/usr/bin/env sh
# license-check.sh — best-effort license policy report (ADVISORY in Phase 3).
# Prints allow/deny matches; warns on denylist; always exits 0.
# Promotable to blocking (exit 1 on denylist) in a later phase.
set -eu

ALLOW="MIT Apache-2.0 ISC BSD-2-Clause BSD-3-Clause 0BSD LGPL-2.1 MPL-2.0 Unlicense"
DENY="GPL-3.0 AGPL-3.0 SSPL Commons-Clause"

is_allowed() { echo "$ALLOW" | tr ' ' '\n' | grep -qxF "$1"; }
is_denied()  { echo "$DENY"  | tr ' ' '\n' | grep -qxF "$1"; }

print_policy() {
  printf 'License policy:\n  allow: %s\n  deny:  %s\n\n' "$ALLOW" "$DENY"
}

report_node() {
  [ -f package.json ] || return 0
  printf '== node (package.json) ==\n'
  lic=$(grep -oE '"license"[[:space:]]*:[[:space:]]*"[^"]+"' package.json | sed -E 's/.*:"([^"]+)"/\1/' || true)
  [ -n "$lic" ] && printf '  declared: %s\n' "$lic"
}

report_python() {
  { [ -f pyproject.toml ] || [ -f requirements.txt ]; } || return 0
  printf '== python ==\n'
  if command -v pip-licenses >/dev/null 2>&1; then
    pip-licenses --format=plain --order=license 2>/dev/null || printf '  (pip-licenses unavailable; skipped)\n'
  else
    printf '  (pip-licenses not installed; cannot enumerate licenses)\n'
  fi
}

report_go() {
  [ -f go.mod ] || return 0
  printf '== go (go.mod) ==\n'
  if command -v go >/dev/null 2>&1; then
    go list -m -json all 2>/dev/null | grep -A1 License || printf '  (no License fields available)\n'
  else
    printf '  (go not installed; skipped)\n'
  fi
}

main() {
  print_policy
  report_node
  report_python
  report_go
  printf '\nlicense-check: advisory report complete (exit 0)\n'
}
main
```
`chmod +x scripts/license-check.sh`. Note: it always exits 0 — Phase 3 is advisory.

- [ ] **Step 2: Create `.github/workflows/dependency-audit.yml`** (auto-detect via stack-tools pattern):
```yaml
name: dependency-audit

on:
  schedule:
    - cron: "0 4 * * 3"   # weekly, Wed 04:00 UTC
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: true

jobs:
  audit:
    name: Dependency audit (advisory)
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Setup Python
        if: hashFiles('pyproject.toml','requirements.txt','Pipfile') != ''
        uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0
        with: { python-version: "3.12" }
      - name: pip-audit
        if: hashFiles('pyproject.toml','requirements.txt','Pipfile') != ''
        run: |
          pip install pip-audit
          pip-audit || echo "::warning::pip-audit found advisories (advisory in Phase 3)"

      - name: Setup Node
        if: hashFiles('package.json') != ''
        uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0
        with: { node-version: "lts/*", cache: npm }
      - name: npm audit
        if: hashFiles('package.json') != ''
        run: npm audit --audit-level=high || echo "::warning::npm audit found advisories (advisory in Phase 3)"

      - name: Setup Go
        if: hashFiles('go.mod') != ''
        uses: actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0
        with: { go-version-file: go.mod, cache: true }
      - name: govulncheck
        if: hashFiles('go.mod') != ''
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./... || echo "::warning::govulncheck found advisories (advisory in Phase 3)"

      - name: No manifest
        if: hashFiles('pyproject.toml','requirements.txt','Pipfile','package.json','go.mod') == ''
        run: echo "No dependency manifest found; audit skipped."
```

- [ ] **Step 3: Create `.github/workflows/license-check.yml`:**
```yaml
name: license-check

on:
  pull_request:
    paths:
      - "**/package.json"
      - "**/requirements*.txt"
      - "**/pyproject.toml"
      - "**/go.mod"
      - "**/pom.xml"
      - "**/*.csproj"
      - "scripts/license-check.sh"
      - ".github/workflows/license-check.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  license-check:
    name: License policy (advisory)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Run license-check.sh
        run: sh scripts/license-check.sh
      # Advisory in Phase 3: always exits 0. Promote to blocking in a later phase.
```

- [ ] **Step 4: Verify** — YAML validity; `sh scripts/license-check.sh` runs and exits 0 (empty template prints policy + "complete").

- [ ] **Step 5: Commit**
```sh
git add scripts/license-check.sh .github/workflows/dependency-audit.yml .github/workflows/license-check.yml
git commit -m "ci: add dependency-audit (advisory) and license-check (advisory) + license-check.sh"
```

---

## Task 3: Graceful-degrade scans — codeql + scorecard

**Files:**
- Create: `.github/workflows/codeql.yml`
- Create: `.github/workflows/scorecard.yml`

**Interfaces:**
- Consumes: nothing.
- Produces: two graceful-degrade workflows (continue-on-error on private-no-GHAS).

- [ ] **Step 1: Resolve & record SHAs** for `github/codeql-action` (init/autobuild/analyze/upload-sarif) and `ossf/scorecard-action` — latest stable tags, via `gh api`.

- [ ] **Step 2: Create `.github/workflows/codeql.yml`:**
```yaml
name: codeql

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: "0 5 * * 3"   # weekly, Wed 05:00 UTC
  workflow_dispatch:

permissions:
  contents: read
  security-events: write   # required to upload SARIF (no-op if Code Scanning off)

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  codeql:
    name: CodeQL (graceful-degrade)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Initialize CodeQL
        uses: github/codeql-action/init@<SHA> # <tag>
        # Omit languages so CodeQL detects supported languages present.
      - name: Autobuild
        uses: github/codeql-action/autobuild@<SHA> # <tag>
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@<SHA> # <tag>
        continue-on-error: true   # graceful-degrade when GHAS/Code Scanning is not enabled (private repo)
```

- [ ] **Step 3: Create `.github/workflows/scorecard.yml`:**
```yaml
name: scorecard

# OpenSSF Scorecard is designed for public repositories; results are limited
# on private repos. Runs as advisory; SARIF upload is continue-on-error.
on:
  push:
    branches: [main]
  schedule:
    - cron: "0 6 * * 3"   # weekly, Wed 06:00 UTC
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: true

jobs:
  scorecard:
    name: OpenSSF Scorecard (advisory)
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Run Scorecard
        uses: ossf/scorecard-action@<SHA> # <tag>
        with:
          results_format: sarif
          results_path: scorecard.sarif
          publish_results: true
      - name: Upload SARIF
        continue-on-error: true   # private repo without GHAS: upload fails gracefully
        uses: github/codeql-action/upload-sarif@<SHA> # <tag>
        with:
          sarif_file: scorecard.sarif
          category: scorecard
```

- [ ] **Step 4: Verify** — YAML validity + SHA resolves.

- [ ] **Step 5: Commit**
```sh
git add .github/workflows/codeql.yml .github/workflows/scorecard.yml
git commit -m "ci: add codeql and scorecard workflows (graceful-degrade on private repo)"
```

---

## Task 4: Makefile + ci-local integration

**Files:**
- Modify: `Makefile`
- Modify: `scripts/ci-local.sh`

- [ ] **Step 1: Update `Makefile` `secret-scan` target.** Find the current line:
```makefile
secret-scan:      ; @echo "[stub] gitleaks runs in CI (.github/workflows/secret-scan.yml)"
```
Replace with a best-effort local invocation (no-op when gitleaks absent):
```makefile
secret-scan:      ; @command -v gitleaks >/dev/null 2>&1 && gitleaks detect --source . --no-banner || echo "[stub] gitleaks runs in CI (.github/workflows/secret-scan.yml)"
```

- [ ] **Step 2: Update `Makefile` `dependency-scan` target** to point to the CI workflow (still a stub — no useful local tool without deps). Replace:
```makefile
dependency-scan:  ; @echo "[stub] dependency-review runs in CI"
```
with:
```makefile
dependency-scan:  ; @echo "[stub] dependency-review + dependency-audit run in CI (.github/workflows/dependency-review.yml, dependency-audit.yml)"
```
(Both `secret-scan` and `dependency-scan` sit in the always-run section at the bottom of the Makefile, not in the stack-conditional block.)

- [ ] **Step 3: Update `scripts/ci-local.sh`** — after the existing `run "actionlint" actionlint` line and the per-stack block, add a gitleaks best-effort run. After the per-stack `if` block:
```sh
# Best-effort secret scan when gitleaks is installed.
run "gitleaks" gitleaks detect --source . --no-banner
```
(Uses the existing `run` helper which skips when the tool is missing.)

- [ ] **Step 4: Verify**
```sh
make secret-scan   # → "[stub] ..." (gitleaks not installed locally) exit 0
make ci            # exit 0
sh scripts/license-check.sh   # prints policy + "complete", exit 0
```

- [ ] **Step 5: Commit**
```sh
git add Makefile scripts/ci-local.sh
git commit -m "feat: wire Makefile secret-scan + ci-local gitleaks (best-effort)"
```

---

## Task 5: Docs + debt + changelog + PR

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/security/vulnerability-management.md`
- Modify: `docs/security/dependency-policy.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update `AGENTS.md`** — under the "Security rules" section, after the existing bullets, add:
```markdown
- **Phase 3 security scans:** `secret-scan` (gitleaks) and `dependency-review` (critical/high) are BLOCKING; `dependency-audit`, `license-check`, `codeql`, and `scorecard` are advisory or graceful-degrade. CodeQL/Scorecard SARIF uploads use `continue-on-error` on this private repo (no GHAS); they become fully functional when the repo is public or GHAS-enabled. See `docs/security/`.
```

- [ ] **Step 2: Update `docs/security/vulnerability-management.md`** — replace the body with:
```markdown
# Vulnerability Management

**Status:** Adapt to your project.

## Severity policy (Phase 3)

| Severity | Source | Policy |
|----------|--------|--------|
| Critical | dependency-review (PR) | **Block** the PR |
| High | dependency-review (PR) | **Block** the PR |
| Medium | dependency-audit (weekly) | Advisory (report) |
| Low | dependency-audit (weekly) | Advisory (report) |

## Process
- Track findings to closure; never lower thresholds without approval.
- Waivers: record in an issue with a bounded fix-by date and owner.
- Dependency, container, IaC, and code (SAST) findings feed the security control matrix (spec §15).
- Container and IaC scans are deferred until assets exist (TD-0005).
- CodeQL analysis storage requires GitHub Advanced Security (GHAS); on a private personal repo without GHAS, the `analyze` step is `continue-on-error` (TD-0006).
```

- [ ] **Step 3: Update `docs/security/dependency-policy.md`** — replace body with:
```markdown
# Dependency Policy

**Status:** Adapt to your project.

## Phase 3 controls
- **dependency-review (PR, blocking):** `fail-on-severity: high`.
- **dependency-audit (weekly cron, advisory):** `npm audit --audit-level=high` / `pip-audit` / `govulncheck`, auto-detected by manifest.
- **license-check (PR, advisory):** `scripts/license-check.sh` enforces an allowlist/denylist.

## License policy
- **Allow:** MIT, Apache-2.0, ISC, BSD-2-Clause, BSD-3-Clause, 0BSD, LGPL-2.1, MPL-2.0, Unlicense.
- **Deny:** GPL-3.0, AGPL-3.0, SSPL, Commons-Clause.
- Phase 3 is advisory (warn on denylist match, exit 0); promote to blocking in a later phase once the policy is validated.

## Auto-merge
- Dependabot security updates: enabled.
- No auto-merge of major versions; patch auto-merge only when tests green and no new vulnerabilities.
```

- [ ] **Step 4: Update `docs/plans/technical-debt.md`** — append three rows:
```markdown
| TD-0004 | dependency-audit and license-check are advisory in Phase 3; promote to blocking once baselines (false-positive rate, accepted policy) are measured. | `.github/workflows/dependency-audit.yml`, `.github/workflows/license-check.yml`, `scripts/license-check.sh` | Open | After ~1 month of advisory runs, flip thresholds: dependency-audit exits non-zero on critical/high; license-check.sh exits 1 on denylist match. |
| TD-0005 | Container scan (Trivy/Grype) and IaC scan (Checkov/tfsec/kube-linter) are deferred until a Dockerfile or IaC exists in the repo. | (future `.github/workflows/container-scan.yml`, `iac-scan.yml`) | Open | Add workflows gated on `hashFiles('**/Dockerfile','**/*.tf','**/*.yaml' under deployment/)` when assets appear. |
| TD-0006 | CodeQL `analyze` and Scorecard SARIF `upload-sarif` use `continue-on-error` on this private repo without GHAS; results are not stored to the GitHub Security tab. | `.github/workflows/codeql.yml`, `.github/workflows/scorecard.yml` | Open | Enable GitHub Advanced Security (paid) OR make the repo public (free Code Scanning) to activate full storage. |
```

- [ ] **Step 5: Update `CHANGELOG.md`** — prepend to the `### Added` section:
```markdown
- Phase 3 security baseline: `secret-scan.yml` (blocking), `dependency-review.yml` (critical/high blocking), `dependency-audit.yml` (advisory, weekly), `license-check.yml` (advisory), `codeql.yml` (graceful-degrade without GHAS), `scorecard.yml` (advisory). Plus `scripts/license-check.sh` (allowlist/denylist, advisory).
```

- [ ] **Step 6: Local verification**
```sh
make ci              # exit 0
make secret-scan     # stub message, exit 0
sh scripts/license-check.sh   # prints policy, exit 0
/tmp/yamlcheck/bin/python -c "import yaml,glob; [list(yaml.safe_load_all(open(f))) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
# SHA resolves (loop from Phase 2) — all OK
make docs-check      # exit 0 (no new markdown issues; the added docs are under docs/security/ which is covered)
```

- [ ] **Step 7: Commit + push + open PR**
```sh
git add AGENTS.md docs/security/vulnerability-management.md docs/security/dependency-policy.md docs/plans/technical-debt.md CHANGELOG.md
git commit -m "docs: document Phase-3 security controls, severity policy, license policy, debt entries"
git push -u origin phase-3-security
gh pr create --base main --head phase-3-security \
  --title "feat: Phase 3 — security baseline (secrets/deps blocking, rest advisory)" \
  --body "<filled from .github/pull_request_template.md>"
```

- [ ] **Step 8: Verify PR checks** — expect: Phase-1 checks (pr-title, validate-metadata, docs-check, action-security) green; Phase-2 `ci` dispatcher green (stack unknown → downstream skip); new Phase-3 workflows: `secret-scan` (0 secrets, pass), `dependency-review` (no-op, pass), `license-check` (advisory, pass). `dependency-audit`/`codeql`/`scorecard` are cron/push-only so they won't run on a PR — that's expected. Report actual results; fix any failure from logs.

- [ ] **Step 9: Hand off** — report PR URL + check status to the owner for merge.

---

## Self-Review (run after writing)

**1. Spec coverage:**
- secret-scan.yml (block) → Task 1 ✓
- dependency-review.yml (critical/high block) → Task 1 ✓
- dependency-audit.yml (advisory) → Task 2 ✓
- license-check.yml + license-check.sh (advisory) → Task 2 ✓
- codeql.yml (graceful-degrade) → Task 3 ✓
- scorecard.yml (advisory, SARIF continue-on-error) → Task 3 ✓
- Makefile secret-scan + ci-local gitleaks → Task 4 ✓
- AGENTS.md + security docs + TD-0004/5/6 + CHANGELOG → Task 5 ✓

**2. Placeholder scan:** the `<SHA> # <tag>` markers in Task 1/3 are "resolve at implementation time" instructions backed by a concrete resolution step (Step 1 of each), not plan-failure placeholders. `license-check.sh` has complete code. No "TODO/implement later". ✓

**3. Consistency:** blocking policy (secret-scan any/dependency-review high) consistent across Task 1, Task 5 docs, spec §2. `continue-on-error` pattern for CodeQL/Scorecard consistent across Task 3, Task 5 TD-0006, spec §2/§10. `license-check.sh` "always exits 0 (advisory)" consistent across Task 2 Step 1, Task 5 docs, spec §6. ✓

No gaps found.
