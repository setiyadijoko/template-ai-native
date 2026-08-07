# Public Code-Scanning Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close TD-0006 by making CodeQL execution and storage fail closed on public-repository pull requests and by giving OpenSSF Scorecard the least-privilege OIDC/SARIF path required for reliable publication.

**Architecture:** Keep CodeQL and Scorecard as independent GitHub Actions workflows. CodeQL becomes the pull-request SAST control with ref-isolated concurrency and no error suppression; Scorecard remains a trusted-event advisory signal whose execution and publication failures are blocking. A POSIX shell contract test protects triggers, permissions, failure semantics, Action pins, and current-state documentation.

**Tech Stack:** GitHub Actions YAML, POSIX `sh`, existing `scripts/test/lib.sh` assertions, GNU/BSD-compatible `sed` and `grep`, Make, actionlint, shellcheck, zizmor, GitHub CLI/API.

## Global Constraints

- The repository remains stack-agnostic; do not add a runtime, framework, dependency, or source file under `src/`.
- CodeQL uses `pull_request`, never `pull_request_target`.
- CodeQL omits the `languages` input so the pinned v4.37.6 Action performs
  supported implicit language detection; `autodetect` is not a valid language
  identifier.
- CodeQL execution and result-storage errors fail the workflow.
- Scorecard findings remain advisory; Scorecard execution, publication, and SARIF upload errors fail the workflow.
- Scorecard keeps `publish_results: true` and receives job-scoped `id-token: write` only.
- Write permissions are job-scoped and have explanatory comments.
- Both checkout steps set `persist-credentials: false`.
- Scorecard uses no top-level/job `env` or `defaults`, job environment,
  container, services, shell `run` step, or Action outside the approved three.
- Every third-party Action remains pinned to an immutable 40-character commit
  SHA with a trailing release-tag comment.
- Do not change branch protection, repository rules, dependency/license policy, deploy workflows, smoke tests, or Phase 6 behavior.
- Use Conventional Commits and keep test, workflow, and documentation commits separate.
- Design source: `docs/superpowers/specs/2026-08-07-public-code-scanning-enforcement-design.md`.

## File Structure

| File | Responsibility |
|------|----------------|
| `scripts/test/test-security-workflows.sh` | Structural contract for CodeQL/Scorecard triggers, concurrency, permissions, fail-closed behavior, pins, and documentation state. |
| `Makefile` | Runs the new security contract from the always-on `test-scripts` target. |
| `.github/workflows/codeql.yml` | Blocking CodeQL execution/storage for PR, main, schedule, and manual events. |
| `.github/workflows/scorecard.yml` | Advisory Scorecard findings with blocking OIDC publication/SARIF execution. |
| `AGENTS.md` | Canonical agent-facing security policy. |
| `docs/security/vulnerability-management.md` | Operator-facing scanning failure and finding policy. |
| `docs/assumptions.md` | Public-repository Code Scanning and Scorecard OIDC assumptions. |
| `docs/plans/technical-debt.md` | Closes TD-0006 while retaining history. |
| `CHANGELOG.md` | Records the enforcement change under `Unreleased`. |

---

### Task 1: Add the failing security-workflow contract

**Files:**
- Create: `scripts/test/test-security-workflows.sh`
- Modify: `Makefile:60-63`
- Reuse: `scripts/test/lib.sh`

**Interfaces:**
- Consumes: `PASS`, `FAIL`, `assert_eq`, and `report` from `scripts/test/lib.sh`.
- Produces: executable command `sh scripts/test/test-security-workflows.sh`, invoked by `make test-scripts`.
- Produces: structural failures that identify the missing CodeQL PR trigger, broad workflow write permissions, missing Scorecard OIDC, error suppression, and stale TD-0006 documentation.

- [ ] **Step 1: Create the complete failing contract test**

Create `scripts/test/test-security-workflows.sh` with this content:

```sh
#!/usr/bin/env sh
# Structural contracts for public CodeQL and OpenSSF Scorecard enforcement.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

CODEQL="$ROOT/.github/workflows/codeql.yml"
SCORECARD="$ROOT/.github/workflows/scorecard.yml"
AGENTS="$ROOT/AGENTS.md"
VULNERABILITY="$ROOT/docs/security/vulnerability-management.md"
ASSUMPTIONS="$ROOT/docs/assumptions.md"
DEBT="$ROOT/docs/plans/technical-debt.md"
CHANGELOG="$ROOT/CHANGELOG.md"

assert_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"

  if printf '%s\n' "$value" | grep -Eq "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_text_not_contains() {
  label="$1"
  value="$2"
  pattern="$3"

  if printf '%s\n' "$value" | grep -Eq "$pattern"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_text_count() {
  label="$1"
  value="$2"
  pattern="$3"
  expected="$4"
  actual="$(printf '%s\n' "$value" | grep -Ec "$pattern" || true)"

  assert_eq "$label" "$actual" "$expected"
}

assert_checkout_credentials() {
  label="$1"
  file="$2"
  actual="$(awk '
    function finish_step() {
      if (checkout) {
        total++
        if (hardened) secure++
      }
    }
    /^[[:space:]]*-[[:space:]]+name:/ {
      finish_step()
      checkout = 0
      hardened = 0
    }
    /^[[:space:]]*uses:[[:space:]]+actions\/checkout@/ { checkout = 1 }
    checkout && /^[[:space:]]*persist-credentials:[[:space:]]+false([[:space:]]|$)/ {
      hardened = 1
    }
    END {
      finish_step()
      printf "%d:%d\n", total, secure
    }
  ' "$file")"

  assert_eq "$label" "$actual" "1:1"
}

assert_action_pins() {
  label="$1"
  shift
  invalid="$({
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$@" |
      sed '/^\.\//d' |
      grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]+v[0-9]+(\.[0-9]+){1,2}([.+-][0-9A-Za-z.-]+)?$'
  } || true)"

  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     unpinned action references:\n%s\n' "$label" "$invalid" >&2
  fi
}

assert_scorecard_action_allowlist() {
  invalid="$({
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$SCORECARD" |
      grep -Ev '^(actions/checkout|ossf/scorecard-action|github/codeql-action/upload-sarif)@'
  } || true)"

  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL scorecard uses only approved actions\n     unapproved action references:\n%s\n' "$invalid" >&2
  fi
}

codeql_pr_trigger="$(sed -n '/^  pull_request:/,/^  push:/p' "$CODEQL")"
codeql_push_trigger="$(sed -n '/^  push:/,/^  schedule:/p' "$CODEQL")"
codeql_workflow_permissions="$(sed -n '/^permissions:/,/^$/p' "$CODEQL")"
codeql_job_permissions="$(sed -n '/^    permissions:/,/^$/p' "$CODEQL")"
scorecard_triggers="$(sed -n '/^on:/,/^permissions:/p' "$SCORECARD")"
scorecard_push_trigger="$(sed -n '/^  push:/,/^  schedule:/p' "$SCORECARD")"
scorecard_workflow_permissions="$(sed -n '/^permissions:/,/^$/p' "$SCORECARD")"
scorecard_job_permissions="$(sed -n '/^    permissions:/,/^$/p' "$SCORECARD")"

# CodeQL: public-repository PR scanning, isolated concurrency, and fail closed.
assert_contains "codeql runs for pull requests" "$CODEQL" '^  pull_request:$'
assert_not_contains "codeql forbids pull_request_target" "$CODEQL" 'pull_request_target:'
assert_text_contains "codeql pull requests target main" "$codeql_pr_trigger" 'branches: \[main\]'
assert_text_contains "codeql pushes target main" "$codeql_push_trigger" 'branches: \[main\]'
assert_contains "codeql retains schedule" "$CODEQL" '^  schedule:$'
assert_contains "codeql retains manual dispatch" "$CODEQL" '^  workflow_dispatch:$'
assert_contains "codeql isolates concurrency by PR or ref" "$CODEQL" 'group:.*github\.event\.pull_request\.number.*github\.ref'
assert_text_contains "codeql workflow defaults to read-only" "$codeql_workflow_permissions" '^  contents: read([[:space:]]|$)'
assert_text_not_contains "codeql workflow has no write permission" "$codeql_workflow_permissions" ': write'
assert_text_contains "codeql job reads contents" "$codeql_job_permissions" '^      contents: read[[:space:]]+#'
assert_text_contains "codeql job writes security events" "$codeql_job_permissions" '^      security-events: write[[:space:]]+#'
assert_contains "codeql is labeled blocking" "$CODEQL" 'name: CodeQL \(blocking\)'
assert_not_contains "codeql delegates language autodetection to the action" "$CODEQL" '^[[:space:]]+languages:'
assert_not_contains "codeql has no error suppression" "$CODEQL" 'continue-on-error:'
assert_contains "codeql retains timeout" "$CODEQL" 'timeout-minutes: 30'
assert_checkout_credentials "codeql checkout disables credential persistence" "$CODEQL"

# Scorecard: trusted events, OIDC publication, advisory findings, fail-closed execution.
assert_text_not_contains "scorecard does not run on pull requests" "$scorecard_triggers" 'pull_request:'
assert_contains "scorecard retains main push" "$SCORECARD" '^  push:$'
assert_text_contains "scorecard pushes target main" "$scorecard_push_trigger" 'branches: \[main\]'
assert_contains "scorecard retains schedule" "$SCORECARD" '^  schedule:$'
assert_contains "scorecard retains manual dispatch" "$SCORECARD" '^  workflow_dispatch:$'
assert_text_contains "scorecard workflow defaults to read-only" "$scorecard_workflow_permissions" '^  contents: read([[:space:]]|$)'
assert_text_not_contains "scorecard workflow has no write permission" "$scorecard_workflow_permissions" ': write'
assert_not_contains "scorecard has no top-level env or defaults" "$SCORECARD" '^(env|defaults):'
assert_not_contains "scorecard job has no forbidden execution context" "$SCORECARD" '^    (env|defaults|environment|container|services):'
assert_not_contains "scorecard has no shell run steps" "$SCORECARD" '^[[:space:]]*(-[[:space:]]+)?run:'
assert_text_contains "scorecard job reads contents" "$scorecard_job_permissions" '^      contents: read[[:space:]]+#'
assert_text_contains "scorecard job writes security events" "$scorecard_job_permissions" '^      security-events: write[[:space:]]+#'
assert_text_not_contains "scorecard workflow does not request OIDC" "$scorecard_workflow_permissions" '^  id-token:'
assert_text_count "scorecard job requests OIDC exactly once" "$scorecard_job_permissions" '^      id-token: write[[:space:]]+#' "1"
assert_contains "scorecard job label documents advisory findings" "$SCORECARD" 'name: OpenSSF Scorecard \(advisory\)'
assert_contains "scorecard publishes authenticated results" "$SCORECARD" 'publish_results: true'
assert_contains "scorecard uploads its SARIF category" "$SCORECARD" 'category: scorecard'
assert_not_contains "scorecard has no error suppression" "$SCORECARD" 'continue-on-error:'
assert_contains "scorecard retains timeout" "$SCORECARD" 'timeout-minutes: 15'
assert_checkout_credentials "scorecard checkout disables credential persistence" "$SCORECARD"
assert_scorecard_action_allowlist

assert_action_pins "security workflows pin actions with release tags" "$CODEQL" "$SCORECARD"

# Current-state documentation must close TD-0006 without private-repo claims.
assert_contains "agents defines fail-closed CodeQL" "$AGENTS" 'CodeQL.*fail[- ]closed'
assert_contains "agents preserves advisory Scorecard findings" "$AGENTS" 'Scorecard findings.*advisory'
assert_contains "vulnerability guide documents public storage" "$VULNERABILITY" 'public repository.*Code Scanning'
assert_contains "assumptions document Scorecard OIDC" "$ASSUMPTIONS" 'Scorecard.*OIDC'
assert_contains "technical debt closes TD-0006" "$DEBT" 'TD-0006.*Closed 2026-08-07'
assert_contains "changelog records CodeQL PR enforcement" "$CHANGELOG" 'CodeQL.*pull request'
assert_contains "changelog records Scorecard OIDC" "$CHANGELOG" 'Scorecard.*OIDC'
assert_not_contains "agents drops private-repo scanning state" "$AGENTS" 'private repo.*no GHAS|without GHAS'
assert_not_contains "vulnerability guide drops private-repo scanning state" "$VULNERABILITY" 'private personal repo|without GHAS'
assert_not_contains "assumptions drop private Scorecard limitation" "$ASSUMPTIONS" 'limited on private repos'

report
```

- [ ] **Step 2: Integrate the contract into the always-on script suite**

Modify `Makefile` so `test-scripts` becomes:

```make
test-scripts:
	@sh scripts/test/test-stack-detection.sh
	@sh scripts/test/test-delivery-workflows.sh
	@sh scripts/test/test-security-workflows.sh
```

- [ ] **Step 3: Run the new contract and confirm the expected red state**

Run:

```bash
sh scripts/test/test-security-workflows.sh
```

Expected: non-zero exit. The failures must include all of these root causes:

- CodeQL has no `pull_request` trigger;
- both checkout steps persist credentials;
- CodeQL has workflow-level `security-events: write`;
- CodeQL still contains `continue-on-error`;
- Scorecard has workflow-level `security-events: write`;
- Scorecard lacks job-level `id-token: write`;
- Scorecard still contains `continue-on-error`; and
- TD-0006/current-state documentation is still open and private-repository-specific.

Do not proceed if the test passes against the old workflows; correct the assertions first.

- [ ] **Step 4: Validate the test script itself**

Run:

```bash
shellcheck -x scripts/test/test-security-workflows.sh
git diff --check
```

Expected: both commands exit 0.

- [ ] **Step 5: Commit the red contract**

```bash
git add Makefile scripts/test/test-security-workflows.sh
git diff --cached --check
git commit -m "test: define public code scanning contracts"
```

Expected: one commit containing only the test and Makefile integration.

---

### Task 2: Make CodeQL and Scorecard execution fail closed

**Files:**
- Modify: `.github/workflows/codeql.yml:1-42`
- Modify: `.github/workflows/scorecard.yml:1-40`
- Test: `scripts/test/test-security-workflows.sh`

**Interfaces:**
- Consumes: the workflow-only assertions created in Task 1.
- Produces: PR/main CodeQL check `CodeQL (blocking)`.
- Produces: trusted-event Scorecard job `OpenSSF Scorecard (advisory)` with authenticated publication and SARIF storage.
- Produces: job-scoped permission comments required by workflow security linting.

- [ ] **Step 1: Replace the CodeQL graceful-degrade policy with the approved fail-closed workflow**

Update `.github/workflows/codeql.yml` to this exact structure while retaining the existing Action SHAs:

```yaml
name: codeql

# CodeQL SAST for the public template repository. Scanner execution and result
# storage fail closed; findings are surfaced through GitHub Code Scanning.
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  schedule:
    - cron: "0 5 * * 3"   # weekly, Wed 05:00 UTC
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  codeql:
    name: CodeQL (blocking)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read          # checkout repository source and workflows
      security-events: write  # upload CodeQL analysis to Code Scanning
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      # Omitting languages lets CodeQL detect every supported language present.
      - name: Initialize CodeQL
        uses: github/codeql-action/init@5595ccaf912efad79be6eef63a5619ff05969be3 # v4.37.6
      - name: Autobuild
        uses: github/codeql-action/autobuild@5595ccaf912efad79be6eef63a5619ff05969be3 # v4.37.6
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@5595ccaf912efad79be6eef63a5619ff05969be3 # v4.37.6
```

- [ ] **Step 2: Replace the Scorecard private-repository fallback with job-scoped OIDC/SARIF enforcement**

Update `.github/workflows/scorecard.yml` to this exact structure while retaining the existing Action SHAs:

```yaml
name: scorecard

# OpenSSF Scorecard findings remain advisory. Scanner execution, authenticated
# publication, and SARIF storage fail closed on this public repository.
on:
  push:
    branches: [main]
  schedule:
    - cron: "0 6 * * 3"   # weekly, Wed 06:00 UTC
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: true

jobs:
  scorecard:
    name: OpenSSF Scorecard (advisory)
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read          # inspect repository security posture
      security-events: write  # upload Scorecard SARIF to Code Scanning
      id-token: write         # authenticate publish_results through OIDC
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Run Scorecard
        uses: ossf/scorecard-action@2d1146689b8cda280b9bc96326124645441f03bc # v2.4.4
        with:
          results_format: sarif
          results_file: scorecard.sarif
          publish_results: true
      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@5595ccaf912efad79be6eef63a5619ff05969be3 # v4.37.6
        with:
          sarif_file: scorecard.sarif
          category: scorecard
```

- [ ] **Step 3: Run the contract and distinguish workflow green from expected documentation red**

Run:

```bash
sh scripts/test/test-security-workflows.sh
```

Expected: all CodeQL and Scorecard workflow assertions pass. The command remains non-zero only because Task 3 has not yet updated AGENTS/current-state documentation. Any workflow-related failure must be corrected before continuing.

- [ ] **Step 4: Validate workflow syntax and security posture**

Run:

```bash
actionlint .github/workflows/codeql.yml .github/workflows/scorecard.yml
uvx zizmor --pedantic .github/workflows/codeql.yml .github/workflows/scorecard.yml
git diff --check
```

Expected: actionlint, the plain pedantic zizmor audit, and diff check exit 0.

- [ ] **Step 5: Commit the workflow enforcement**

```bash
git add .github/workflows/codeql.yml .github/workflows/scorecard.yml
git diff --cached --check
git commit -m "security: enforce public code scanning execution"
```

Expected: one commit containing only the two security workflows.

---

### Task 3: Close TD-0006 and synchronize current-state documentation

**Files:**
- Modify: `AGENTS.md:119-127`
- Modify: `docs/security/vulnerability-management.md:14-19`
- Modify: `docs/assumptions.md:5-14`
- Modify: `docs/plans/technical-debt.md:5-13`
- Modify: `CHANGELOG.md:27-31`
- Test: `scripts/test/test-security-workflows.sh`

**Interfaces:**
- Consumes: documentation assertions from Task 1 and workflow behavior from Task 2.
- Produces: one consistent current-state policy: CodeQL execution/storage fail closed; Scorecard findings advisory; Scorecard execution/publication/storage fail closed; TD-0006 closed.

- [ ] **Step 1: Confirm the documentation assertions are still red before editing docs**

Run:

```bash
sh scripts/test/test-security-workflows.sh
```

Expected: non-zero exit only for current-state documentation assertions. Workflow assertions must already pass.

- [ ] **Step 2: Replace the Phase 3 scanning paragraph in `AGENTS.md`**

Replace the existing Phase 3 bullet with:

```markdown
- **Phase 3 security scans:** `secret-scan` (gitleaks) and `dependency-review` (critical/high) are blocking. CodeQL runs on pull requests to `main`, pushes to `main`, schedule, and manual dispatch; scanner execution and Code Scanning storage fail closed. Scorecard findings remain advisory, while Scorecard execution, OIDC publication, and SARIF storage fail closed. `dependency-audit` and `license-check` remain advisory. See `docs/security/`.
```

- [ ] **Step 3: Replace the stale CodeQL statement in vulnerability management**

Replace the final private-repository bullet with these bullets:

```markdown
- This public repository stores CodeQL and Scorecard SARIF in GitHub Code Scanning.
- CodeQL scanner execution and result storage fail closed on pull requests to `main`, pushes to `main`, schedule, and manual dispatch. Findings are triaged through Code Scanning and repository rules.
- Scorecard findings remain advisory; failure to execute, publish through OIDC, or upload SARIF fails the workflow.
```

- [ ] **Step 4: Update the Scorecard assumption**

Replace assumption 7 in `docs/assumptions.md` with:

```markdown
7. **Scorecard publication:** the repository is public; Scorecard publishes authenticated results through GitHub OIDC and stores SARIF in Code Scanning.
```

- [ ] **Step 5: Close TD-0006 without removing its history**

Replace the TD-0006 row in `docs/plans/technical-debt.md` with:

```markdown
| TD-0006 | (Closed) CodeQL and Scorecard initially used private-repository graceful degradation, suppressing analysis and SARIF upload failures and omitting CodeQL pull-request scans. | `.github/workflows/codeql.yml`, `.github/workflows/scorecard.yml` | Closed 2026-08-07 | The repository is public. CodeQL now runs on pull requests and fails closed for scanner/storage errors; Scorecard uses job-scoped OIDC and fails closed for execution/publication/storage errors while findings remain advisory. |
```

- [ ] **Step 6: Add the change under `CHANGELOG.md` → `Unreleased` → `Fixed`**

Add this bullet after the Phase 5 repair entry:

```markdown
- Activated public-repository security enforcement: CodeQL now scans pull requests and fails closed for execution/storage errors; Scorecard uses job-scoped OIDC and fails closed for publication/SARIF errors while findings remain advisory (TD-0006 closed).
```

- [ ] **Step 7: Run the complete contract and documentation gate**

Run:

```bash
sh scripts/test/test-security-workflows.sh
make test-scripts
make docs-check
git diff --check
```

Expected: all commands exit 0; the security contract reports `failed=0`.

- [ ] **Step 8: Scan affected current-state files for stale claims**

Run:

```bash
rg -n "private repo|private personal repo|without GHAS|continue-on-error" \
  AGENTS.md docs/security/vulnerability-management.md docs/assumptions.md \
  docs/plans/technical-debt.md .github/workflows/codeql.yml \
  .github/workflows/scorecard.yml
```

Expected: no output. The historical closed row uses the precise term
`private-repository` and explicitly starts its description with `(Closed)`.

- [ ] **Step 9: Commit the documentation resolution**

```bash
git add AGENTS.md CHANGELOG.md docs/assumptions.md \
  docs/plans/technical-debt.md docs/security/vulnerability-management.md
git diff --cached --check
git commit -m "docs: close public code scanning debt"
```

Expected: one commit containing only the five current-state documentation files.

---

### Task 4: Run the complete local gate and prepare remote evidence

**Files:**
- Review: every path changed from `origin/main..HEAD`
- Verify unchanged: `.github/workflows/deploy-development.yml`
- Verify unchanged: `.github/workflows/deploy-staging.yml`
- Verify unchanged: `.github/workflows/deploy-production.yml`
- Verify unchanged: `.github/workflows/smoke-test.yml`

**Interfaces:**
- Consumes: all commits from Tasks 1-3.
- Produces: a clean feature branch with local evidence ready for Draft PR publication.
- Produces after the owner chooses PR publication: CodeQL PR result and stored
  Code Scanning analysis evidence.
- Produces after merge: a default-branch Scorecard result with authenticated
  publication and stored SARIF evidence.

- [ ] **Step 1: Run every deterministic local verification command**

```bash
make test-scripts
make ci
make docs-check
actionlint .github/workflows/*.yml
shellcheck -x scripts/test/test-security-workflows.sh
uvx zizmor --pedantic .github/workflows/codeql.yml .github/workflows/scorecard.yml
git diff --check origin/main..HEAD
```

Expected: all installed gates exit 0, both the stack contract and delivery contract remain green, and the security contract reports `failed=0`.

- [ ] **Step 2: Prove deploy and smoke-test skeletons are untouched**

```bash
git diff --exit-code origin/main..HEAD -- \
  .github/workflows/deploy-development.yml \
  .github/workflows/deploy-staging.yml \
  .github/workflows/deploy-production.yml \
  .github/workflows/smoke-test.yml
```

Expected: exit 0 with no output.

- [ ] **Step 3: Review the complete diff for scope and security**

```bash
git diff --stat origin/main..HEAD
git diff origin/main..HEAD
git status --short --branch
```

Confirm every changed line maps to the approved spec, no secret or debug code exists, no Action SHA changed accidentally, no broad workflow write permission exists, and the worktree is clean.

- [ ] **Step 4: Publish only after the finishing-branch integration choice**

When the owner selects Draft PR publication, run:

```bash
git push -u origin security/public-code-scanning-enforcement
```

Create a Draft PR against `main` using the repository PR template. Do not merge it.

- [ ] **Step 5: Verify CodeQL on the Draft PR**

Wait for the PR check named `CodeQL (blocking)` and the separate Code Scanning result to complete. Require success; if either fails, retrieve the job log and Code Scanning annotation before changing code.

Expected: CodeQL initializes, autobuilds, analyzes the empty template, uploads results, and concludes success without `continue-on-error`.

- [ ] **Step 6: Verify Scorecard from the default branch after merge**

```bash
gh workflow run scorecard.yml \
  --repo setiyadijoko/template-ai-native \
  --ref main
```

Run this only after the PR is merged, unless the merge-triggered push run already
provides the evidence. Require `OpenSSF Scorecard (advisory)` to conclude
success. Confirm the action publishes through OIDC and the upload step stores
SARIF category `scorecard`. A low score or finding is reported but does not fail
the workflow. Do not use a feature-branch dispatch as acceptance evidence: the
Scorecard action rejects non-default refs.

- [ ] **Step 7: Record final evidence and hand off the Draft PR**

Report:

- commits and changed files;
- TDD red and green results;
- local `make ci`, actionlint, shellcheck, zizmor, and diff results;
- Draft PR URL and head SHA;
- CodeQL PR run URL/conclusion;
- post-merge default-branch Scorecard run URL/conclusion, or mark it explicitly
  pending while the PR remains unmerged;
- Code Scanning storage confirmation;
- optional local tools that were unavailable; and
- that deploy/smoke-test skeletons remain unchanged.

Do not claim branch protection enforcement, because repository rules remain owner-managed and out of scope.
