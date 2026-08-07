# Phase 6 Production-Readiness Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a vendor-neutral, machine-verifiable production-readiness contract and a manual rollback workflow that fails closed until a consumer wires a real platform.

**Architecture:** A constrained `KEY=VALUE` manifest under `observability/` is parsed as data by a POSIX validator. Template and active modes validate contract/reference shape only and always report `production_ready=false`; active mode additionally fails unless required ownership, SLO, alerting, recovery, and rollback references are complete. A read-only workflow runs the validator, while a separate manual rollback workflow validates immutable identity and audit inputs before deliberately failing at an unwired sentinel.

**Tech Stack:** POSIX `sh`, standard `awk`/`grep`/`sed`, Make, GitHub Actions YAML, actionlint, shellcheck, zizmor, Markdown.

## Global constraints

- Design source: `docs/plans/completed/2026-08-07-production-readiness-baseline-design.md`.
- Keep the repository stack-, platform-, and observability-vendor-agnostic.
- Do not modify any `deploy-*.yml` workflow or `smoke-test.yml`.
- Do not add a runtime, package dependency, endpoint, OIDC permission, credential, secret, or production mutation.
- Parse the manifest as data; never use `source`, `.`, `eval`, or generated shell.
- Both valid statuses exit zero with `readiness_contract_valid=true` and
  `production_ready=false`.
- Active status validates required values and reference shape, never production
  approval, human review, evidence freshness, or content approval.
- Rollback remains `workflow_dispatch` only, uses `contents: read`, and fails at an explicit unwired sentinel.
- Use `pull_request`, never `pull_request_target`; use no `continue-on-error` on integrity paths.
- Disable checkout credential persistence and pin Actions to immutable SHAs with release-tag comments.
- Use Conventional Commits; separate tests, implementation, workflows, and documentation.
- Do not create source-grep tests for human prose.

## File structure

| File | Responsibility |
|---|---|
| `observability/production-readiness.conf` | Readiness state and evidence references. |
| `scripts/validate-production-readiness.sh` | Parser and template/active semantic validator. |
| `scripts/test/test-production-readiness.sh` | Behavioral validator tests and workflow contracts. |
| `Makefile` | `readiness-check` and local CI integration. |
| `.github/workflows/production-readiness.yml` | Read-only PR/main/manual contract check. |
| `.github/workflows/rollback.yml` | Manual environment-bound fail-closed rollback request. |
| `observability/README.md`, `docs/operations/*.md` | Operational policy and activation guidance. |
| `AGENTS.md`, `CHANGELOG.md`, `docs/plans/technical-debt.md` | Canonical policy and traceability. |

---

### Task 1: Define the failing validator behavior

**Files:**
- Create: `scripts/test/test-production-readiness.sh`
- Modify: `Makefile`
- Test target: `scripts/validate-production-readiness.sh` (absent at RED)
- Test input: `observability/production-readiness.conf` (absent at RED)

**Interfaces:**
- Consumes: `PASS`, `FAIL`, `assert_eq`, and `report` from `scripts/test/lib.sh`.
- Produces: `sh scripts/test/test-production-readiness.sh`.
- Produces test helpers: `new_fixture`, `write_active_manifest`, `set_value`, `remove_key`, `run_validator`.
- Produces globals `RUN_STATUS` and `RUN_OUTPUT` after validator execution.

- [ ] **Step 1: Create the behavioral test harness**

Create a POSIX script with `set -eu`, source `scripts/test/lib.sh`, allocate a
directory with `mktemp -d`, and remove it with a trap. Use the real validator
path and create each fixture as a Git worktree:

```sh
VALIDATOR="$ROOT/scripts/validate-production-readiness.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/readiness-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

new_fixture() {
  name="$1"
  FIXTURE="$TMP_ROOT/$name"
  mkdir -p "$FIXTURE/observability" "$FIXTURE/docs/operations" "$FIXTURE/evidence"
  git -C "$FIXTURE" init -q
  printf '%s\n' '# Alert Policy' 'Every alert identifies severity, owner, and runbook.' > "$FIXTURE/docs/operations/alerting.md"
  printf '%s\n' '# Runbook' 'Diagnose, mitigate, escalate, communicate, and preserve evidence.' > "$FIXTURE/docs/operations/runbook.md"
  printf '%s\n' '# Rollback' 'Verify identity, restore, and verify recovery.' > "$FIXTURE/docs/operations/rollback.md"
  printf '%s\n' '# Rollback Evidence' 'Exercise passed.' > "$FIXTURE/evidence/rollback.md"
  printf '%s\n' '# Restore Evidence' 'Restore and integrity checks passed.' > "$FIXTURE/evidence/restore.md"
}
```

`write_active_manifest recovery` writes all 18 schema keys. Use these literal
valid values: owner `platform-team`, environment `production`, backend
`otlp-gateway`, availability `99.9`, latency `500`, window `30`, rollback date
`2025-01-15`, RTO `60`, and repository-relative policy/evidence paths. For
`recovery=yes`, use RPO `15`, restore date `2025-01-15`, and
`evidence/restore.md`; for `no`, use `NOT_APPLICABLE` for all three fields.

```sh
write_active_manifest() {
  recovery="$1"
  if [ "$recovery" = yes ]; then
    rpo=15
    restore_date=2025-01-15
    restore_path=evidence/restore.md
  else
    rpo=NOT_APPLICABLE
    restore_date=NOT_APPLICABLE
    restore_path=NOT_APPLICABLE
  fi
  printf '%s\n' \
    'READINESS_SCHEMA_VERSION=1' \
    'READINESS_STATUS=active' \
    'SERVICE_OWNER=platform-team' \
    'PRODUCTION_ENVIRONMENT=production' \
    'OBSERVABILITY_BACKEND=otlp-gateway' \
    'SLO_AVAILABILITY_PERCENT=99.9' \
    'SLO_LATENCY_P95_MS=500' \
    'ERROR_BUDGET_WINDOW_DAYS=30' \
    'ALERT_POLICY_PATH=docs/operations/alerting.md' \
    'ALERT_RUNBOOK_PATH=docs/operations/runbook.md' \
    'ROLLBACK_RUNBOOK_PATH=docs/operations/rollback.md' \
    'ROLLBACK_TEST_DATE=2025-01-15' \
    'ROLLBACK_TEST_EVIDENCE_PATH=evidence/rollback.md' \
    'RTO_MINUTES=60' \
    "DATA_RECOVERY_REQUIRED=$recovery" \
    "RPO_MINUTES=$rpo" \
    "RESTORE_TEST_DATE=$restore_date" \
    "RESTORE_TEST_EVIDENCE_PATH=$restore_path" \
    > "$FIXTURE/observability/production-readiness.conf"
}
```

Implement mutations portably:

```sh
set_value() {
  file="$1" key="$2" value="$3"
  awk -F= -v key="$key" -v value="$value" '
    $1 == key { print key "=" value; next }
    { print }
  ' "$file" > "$file.next"
  mv "$file.next" "$file"
}

remove_key() {
  file="$1" key="$2"
  awk -F= -v key="$key" '$1 != key { print }' "$file" > "$file.next"
  mv "$file.next" "$file"
}

run_validator() {
  manifest="$1"
  set +e
  RUN_OUTPUT="$(sh "$VALIDATOR" "$manifest" 2>&1)"
  RUN_STATUS=$?
  set -e
}
```

Add `assert_output_contains label regex` and `assert_nonzero label` helpers
that update `PASS`/`FAIL` without aborting.

- [ ] **Step 2: Add success cases**

Assert the committed template exits zero with these exact lines:

```text
readiness_status=template
readiness_contract_valid=true
production_ready=false
```

Assert generated active stateful and active stateless fixtures both exit zero
with:

```text
readiness_status=active
readiness_contract_valid=true
production_ready=false
```

- [ ] **Step 3: Add explicit failure cases**

Create a new valid active-stateful fixture for each mutation, run the real
validator, and assert non-zero plus a targeted diagnostic:

```text
append duplicate SERVICE_OWNER
append unknown READY_APPROVER
remove SLO_LATENCY_P95_MS
empty SERVICE_OWNER
append a line without equals
schema version 2
state ready
active OBSERVABILITY_BACKEND=UNSET
availability 100.1
latency 0
window 366
RTO -1
RPO -1
calendar date 2025-02-30
future date 2999-01-01
stateful restore date NOT_APPLICABLE
stateless RPO 0
absolute runbook path
parent-traversal runbook path
missing rollback evidence
generic rollback document containing Status: Adapt to your project.
alert policy containing a standalone TODO marker
rollback evidence symlinked outside the fixture
manifest copied under a non-Git directory
```

For the symlink case, create the target under `$TMP_ROOT`, remove the fixture's
regular evidence file, then link the original evidence path to that external
target. The test must receive a validator diagnostic, not a shell crash.

- [ ] **Step 4: Integrate and verify RED**

End the test with `report`. Add this line after the current security test in
`make test-scripts`:

```make
    @sh scripts/test/test-production-readiness.sh
```

Run:

```bash
sh scripts/test/test-production-readiness.sh
make test-scripts
```

Expected: non-zero because the three success cases cannot find the manifest or
validator. Mutation cases remain contained and do not abort the harness.

- [ ] **Step 5: Commit the red contract**

```bash
git add Makefile scripts/test/test-production-readiness.sh
git diff --cached --check
git commit -m "test: define production readiness behavior"
```

---

### Task 2: Implement the readiness manifest and validator

**Files:**
- Create: `observability/production-readiness.conf`
- Create: `scripts/validate-production-readiness.sh`
- Modify: `Makefile`
- Test: `scripts/test/test-production-readiness.sh`

**Interfaces:**
- Consumes optional `manifest_path`; defaults to the committed manifest.
- Produces deterministic readiness lines on stdout and targeted errors on stderr.
- Produces Make target `readiness-check`.

- [ ] **Step 1: Add the template manifest**

Create exactly:

```properties
# Production-readiness contract. Never store secrets or production data here.
READINESS_SCHEMA_VERSION=1
READINESS_STATUS=template
SERVICE_OWNER=UNSET
PRODUCTION_ENVIRONMENT=production
OBSERVABILITY_BACKEND=UNSET
SLO_AVAILABILITY_PERCENT=UNSET
SLO_LATENCY_P95_MS=UNSET
ERROR_BUDGET_WINDOW_DAYS=UNSET
ALERT_POLICY_PATH=docs/operations/alerting.md
ALERT_RUNBOOK_PATH=docs/operations/runbook.md
ROLLBACK_RUNBOOK_PATH=docs/operations/rollback.md
ROLLBACK_TEST_DATE=UNSET
ROLLBACK_TEST_EVIDENCE_PATH=UNSET
RTO_MINUTES=UNSET
DATA_RECOVERY_REQUIRED=UNSET
RPO_MINUTES=UNSET
RESTORE_TEST_DATE=UNSET
RESTORE_TEST_EVIDENCE_PATH=UNSET
```

- [ ] **Step 2: Implement the parser trust boundary**

Use this exact key list once for allowlisting and completeness:

```sh
KEYS='READINESS_SCHEMA_VERSION READINESS_STATUS SERVICE_OWNER PRODUCTION_ENVIRONMENT OBSERVABILITY_BACKEND SLO_AVAILABILITY_PERCENT SLO_LATENCY_P95_MS ERROR_BUDGET_WINDOW_DAYS ALERT_POLICY_PATH ALERT_RUNBOOK_PATH ROLLBACK_RUNBOOK_PATH ROLLBACK_TEST_DATE ROLLBACK_TEST_EVIDENCE_PATH RTO_MINUTES DATA_RECOVERY_REQUIRED RPO_MINUTES RESTORE_TEST_DATE RESTORE_TEST_EVIDENCE_PATH'
```

The script uses `set -eu`, resolves the manifest's physical parent, rejects a
manifest symlink, obtains the worktree root with
`git -C "$MANIFEST_DIR" rev-parse --show-toplevel`, canonicalizes the root, and
requires the manifest path to begin with `"$REPO_ROOT"/`.

Parse into a private `mktemp -d` file. Ignore blank/comment lines. Reject CRLF,
anything other than one `=`, keys outside `^[A-Z][A-Z0-9_]*$`, unknown or
duplicate keys, empty values, and values outside `^[A-Za-z0-9._/@:+-]+$`.
Never export, source, evaluate, or echo parsed values. After parsing, require
every key in `KEYS`. Implement `value_for KEY` with a bounded `sed` lookup.

- [ ] **Step 3: Implement scalar and path validation**

Implement functions with these contracts:

```text
is_positive_integer value       digits only and > 0
is_nonnegative_integer value    digits only and >= 0
is_availability value           decimal syntax, > 0 and <= 100
is_calendar_date_not_future     real Gregorian YYYY-MM-DD and <= current UTC date
validate_repo_file key markers  regular, non-symlink, canonical path under root
```

Use `awk` for number/calendar checks. Calendar validation handles leap years.
Path validation rejects reserved values, absolute paths, `..` segments,
missing files, final-component symlinks, and canonical parents outside the
worktree. With `markers=yes`, reject case-insensitive standalone
`TODO|TBD|FIXME|UNSET` and the literal `Adapt to your project` without printing
file content.

- [ ] **Step 4: Implement state semantics**

Always require schema `1`, status `template|active`, environment `production`,
and valid alert-policy, alert-runbook, and rollback-runbook paths.

Template success prints exactly:

```sh
printf '%s\n' 'readiness_status=template' 'readiness_contract_valid=true' 'production_ready=false'
```

Active mode rejects every `UNSET`; allows `NOT_APPLICABLE` only for RPO and the
two restore fields when recovery is `no`; validates owner/backend, availability,
positive latency/RTO, window `1..365`, rollback date/evidence, and all
operational document markers. Recovery `yes` requires non-negative RPO plus
valid restore date/evidence. Recovery `no` requires all three recovery fields
to be exactly `NOT_APPLICABLE`.

Active success prints exactly:

```sh
printf '%s\n' 'readiness_status=active' 'readiness_contract_valid=true' 'production_ready=false'
```

- [ ] **Step 5: Add the Make interface**

Add `readiness-check` to `.PHONY`, define:

```make
readiness-check:   ; @sh scripts/validate-production-readiness.sh
```

Change the local gate to:

```make
ci: format-check lint docs-check readiness-check test-scripts
```

- [ ] **Step 6: Verify GREEN and commit**

```bash
sh scripts/test/test-production-readiness.sh
make readiness-check
make test-scripts
shellcheck -x scripts/validate-production-readiness.sh scripts/test/test-production-readiness.sh
git diff --check
git add Makefile observability/production-readiness.conf scripts/validate-production-readiness.sh
git diff --cached --check
git commit -m "feat: add production readiness contract"
```

Expected: all behavioral tests pass and the committed manifest prints
template/false. Do not stage tests, workflows, or deploy/smoke files.

---

### Task 3: Define failing workflow security contracts

**Files:**
- Modify: `scripts/test/test-production-readiness.sh`
- Test targets: `.github/workflows/production-readiness.yml`, `.github/workflows/rollback.yml` (absent at RED)

**Interfaces:**
- Consumes: validator tests from Tasks 1–2.
- Produces: workflow assertions for triggers, least privilege, safe input handling, environment binding, and the rollback sentinel.

- [ ] **Step 1: Add file-aware assertions**

Add helpers that fail cleanly when a workflow is absent:

```sh
assert_file_contains() {
  label="$1" file="$2" pattern="$3"
  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_file_not_contains() {
  label="$1" file="$2" pattern="$3"
  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}
```

Define `READINESS_WORKFLOW` and `ROLLBACK_WORKFLOW` with their exact repository
paths. Extract bounded trigger/permission/run sections with `sed`/`awk`; do not
let an unrelated line satisfy an assertion.

- [ ] **Step 2: Assert the readiness workflow contract**

Add explicit assertions for:

```text
pull_request targets main
push targets main
workflow_dispatch exists and schedule does not
pull_request_target is absent
workflow permissions are contents: read with no write
concurrency contains PR number or ref and cancel-in-progress: true
job name is Production-readiness contract
timeout-minutes is 10
checkout uses 3d3c42e5aac5ba805825da76410c181273ba90b1 with # v7.0.1
persist-credentials is false
validation runs make readiness-check and writes GITHUB_STEP_SUMMARY
continue-on-error is absent
```

- [ ] **Step 3: Assert the rollback workflow contract**

Add explicit assertions for:

```text
workflow_dispatch is the only trigger
inputs are exactly environment, release_ref, artifact_digest, reason, confirm
environment is a required choice of development, staging, production
every identity/audit input is required
workflow and job permissions are contents: read only
job environment uses inputs.environment
concurrency uses inputs.environment and cancel-in-progress: false
timeout-minutes is 5
id-token, attestations, security-events, secrets, checkout, uses, services, and container are absent
each input is mapped through step env
run blocks contain no GitHub inputs expression
confirmation validation requires ROLLBACK
release validation carries the approved SHA/tag grammar
digest validation requires lowercase sha256 with 64 hex characters
reason validation rejects whitespace-only input
unwired step emits an error annotation and exits 1
continue-on-error and pull_request_target are absent
```

Extract all `run: |` bodies and assert they do not contain the literal
`${{ inputs.`. Expressions remain allowed in YAML `env`, `environment`, and
`concurrency` fields.

- [ ] **Step 4: Verify RED and commit**

```bash
sh scripts/test/test-production-readiness.sh
git add scripts/test/test-production-readiness.sh
git diff --cached --check
git commit -m "test: define production readiness workflow contracts"
```

Expected: validator behavior stays green; workflow assertions are red only
because both YAML files are absent. Commit only the expanded test.

---

### Task 4: Add the readiness and rollback workflows

**Files:**
- Create: `.github/workflows/production-readiness.yml`
- Create: `.github/workflows/rollback.yml`
- Test: `scripts/test/test-production-readiness.sh`

**Interfaces:**
- Consumes: `make readiness-check`.
- Produces check `Production-readiness contract`.
- Produces manual inputs `environment`, `release_ref`, `artifact_digest`, `reason`, `confirm`.

- [ ] **Step 1: Create the production-readiness workflow**

Use this complete workflow:

```yaml
name: production-readiness

# Validates the repository contract; a green template-mode run is not a
# production approval and still reports production_ready=false.
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  readiness:
    name: Production-readiness contract
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Validate production-readiness contract
        shell: sh
        run: |
          result="$(make readiness-check)"
          printf '%s\n' "$result"
          {
            printf '%s\n' '## Production-readiness contract' '```text'
            printf '%s\n' "$result"
            printf '%s\n' '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 2: Create the rollback workflow**

Use this complete workflow:

```yaml
name: rollback

# SKELETON. Validates an audited rollback request, then fails closed until the
# consumer wires artifact retrieval, verification, platform auth, and rollback.
on:
  workflow_dispatch:
    inputs:
      environment:
        description: Environment protected by the matching GitHub Environment
        required: true
        type: choice
        options:
          - development
          - staging
          - production
      release_ref:
        description: 40-char commit SHA or v-prefixed release tag
        required: true
        type: string
      artifact_digest:
        description: Immutable lowercase sha256 digest
        required: true
        type: string
      reason:
        description: Non-empty audit reason for rollback
        required: true
        type: string
      confirm:
        description: Type ROLLBACK to confirm the request
        required: true
        type: string

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  rollback:
    name: Rollback request validation (unwired)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    environment: ${{ inputs.environment }}
    permissions:
      contents: read
    steps:
      - name: Validate rollback request
        shell: sh
        env:
          ROLLBACK_ENVIRONMENT: ${{ inputs.environment }}
          ROLLBACK_RELEASE_REF: ${{ inputs.release_ref }}
          ROLLBACK_ARTIFACT_DIGEST: ${{ inputs.artifact_digest }}
          ROLLBACK_REASON: ${{ inputs.reason }}
          ROLLBACK_CONFIRM: ${{ inputs.confirm }}
        run: |
          set -eu
          [ "$ROLLBACK_CONFIRM" = ROLLBACK ] || {
            echo '::error::Rollback confirmation must equal ROLLBACK.'
            exit 1
          }
          printf '%s\n' "$ROLLBACK_RELEASE_REF" |
            grep -Eq '^([0-9a-f]{40}|v[0-9][0-9A-Za-z._-]*)$' || {
              echo '::error::Release ref must be a lowercase commit SHA or v-prefixed tag.'
              exit 1
            }
          printf '%s\n' "$ROLLBACK_ARTIFACT_DIGEST" |
            grep -Eq '^sha256:[0-9a-f]{64}$' || {
              echo '::error::Artifact digest must be lowercase sha256.'
              exit 1
            }
          case "$ROLLBACK_REASON" in
            *[![:space:]]*) ;;
            *)
              echo '::error::Rollback reason must contain a non-whitespace character.'
              exit 1
              ;;
          esac
          case "$ROLLBACK_ENVIRONMENT" in
            development|staging|production) ;;
            *)
              echo '::error::Unknown rollback environment.'
              exit 1
              ;;
          esac
      - name: Refuse unwired rollback
        shell: sh
        run: |
          echo '::error::Rollback target is not configured. Wire artifact verification, platform authentication, rollback execution, and recovery verification through an approved design.'
          exit 1
```

- [ ] **Step 3: Verify GREEN and commit**

```bash
sh scripts/test/test-production-readiness.sh
actionlint .github/workflows/production-readiness.yml .github/workflows/rollback.yml
uvx zizmor --pedantic .github/workflows/production-readiness.yml .github/workflows/rollback.yml
git diff --check
git add .github/workflows/production-readiness.yml .github/workflows/rollback.yml
git diff --cached --check
git commit -m "feat: add production readiness workflows"
```

Expected: all validator/workflow assertions pass; actionlint, plain pedantic
zizmor, and diff check exit zero. No deploy/smoke workflow is staged.

---

### Task 5: Replace operational placeholders with enforceable guidance

**Files:**
- Modify: `observability/README.md`
- Modify: `docs/operations/observability.md`
- Modify: `docs/operations/monitoring.md`
- Modify: `docs/operations/alerting.md`
- Modify: `docs/operations/runbook.md`
- Modify: `docs/operations/rollback.md`
- Modify: `docs/operations/backup-and-recovery.md`
- Modify: `docs/operations/disaster-recovery.md`
- Modify: `docs/operations/capacity-management.md`
- Modify: `docs/operations/deployment-guide.md`
- Modify: `AGENTS.md`, `CHANGELOG.md`, `docs/plans/technical-debt.md`

**Interfaces:**
- Consumes: manifest field names and failure semantics from Tasks 1–4.
- Produces: operational policy referenced by the committed manifest.
- Produces: TD-0011 while leaving TD-0009 and TD-0010 unchanged.

- [ ] **Step 1: Document readiness and observability lifecycle**

Replace adaptation-only content in `observability/README.md` and
`docs/operations/observability.md`. State that the check validates a contract,
not production approval; both valid statuses always report false; active
validates required values and evidence-reference shape. Human review, evidence
freshness, content approval, and platform authorization remain separate. Define logs with timestamp, level,
service, environment, version, deploy id, correlation id, event, and safe error
classification. Define RED/dependency/saturation/business/AI metrics,
cross-boundary traces, and AI telemetry for provider/model/prompt version,
completion, latency, tokens, cost, fallback, tools, guardrails, eval score, and
feedback. Prohibit raw sensitive prompts/responses, credentials, tokens, and
customer payloads by default. Include:

```bash
make readiness-check
sh scripts/validate-production-readiness.sh observability/production-readiness.conf
```

- [ ] **Step 2: Define monitoring/SLO and alerting policy**

Expand `monitoring.md` with SLIs for request rate, error rate, latency,
dependency health, saturation, business outcomes, and AI cost/quality. Require
owner, scope, query, target, window, exclusions, data source, and review date
for each SLO. Define error-budget responses: at 50% review burn and deploy
correlation; at 75% restrict risky releases and assign mitigation; at 100% stop
non-recovery releases and invoke incident/change authority.

Expand `alerting.md` with SEV-1 through SEV-4, human routing,
deduplication/grouping/hysteresis/maintenance rules, quarterly and
post-incident review, and required fields: severity, service, environment,
symptom, start time, value, threshold, deploy id, dashboard, runbook, owner.
Prohibit secrets and customer payloads.

- [ ] **Step 3: Define incident and rollback policy**

Expand `runbook.md` so every entry has owner, scope, symptoms, severity,
prerequisites, diagnosis, safe mitigation, rollback/stop criteria, escalation,
communications, recovery verification, evidence, and post-incident link.
Rewrite the existing high-error and elevated-AI-cost examples accordingly.

Expand `rollback.md` with decision authority, environment, current/target
release, sha256 digest, attestation verification, rollback type, stop
conditions, recovery checks, immutable evidence, database forward recovery,
and exercise date/evidence. State that the unwired workflow fails closed.

- [ ] **Step 4: Define recovery, DR, and capacity policy**

Expand `backup-and-recovery.md` with inventory, owner, schedule, retention,
encryption, access, immutable/offsite needs, restore order, integrity checks,
test cadence, evidence, and escalation. Expand `disaster-recovery.md` with
RTO/RPO, authority, dependency order, communications, failover/failback,
exercise cadence, evidence, and corrective action. Expand
`capacity-management.md` with demand/saturation signals, scaling thresholds,
lead time, cost ceilings, quotas, forecasts, owner, monthly review, and
post-incident review. Do not invent numeric targets.

- [ ] **Step 5: Link Phase 6 from deployment and agent policy**

Append this table to `deployment-guide.md`:

| Control | Status | Meaning |
|---|---|---|
| `production-readiness.yml` | Active | Validates the contract; not production approval. |
| `rollback.yml` | Skeleton, fail closed | Manual and environment-bound; performs no rollback. |
| `production-readiness.conf` | Template | Contract-valid and explicitly not production-ready. |

State that deploy/smoke remain Phase 5 skeletons. Add this paragraph after the
Phase 5 policy in `AGENTS.md`:

```text
Phase 6 production-readiness baseline: `production-readiness.yml` validates the
vendor-neutral manifest. `template` and `active` can be contract-valid but both
remain explicitly not production-ready; `active` additionally fails closed
unless required SLO, alert, recovery, and rollback references are complete.
The validator does not verify human review, freshness, or content approval.
`rollback.yml` is manual, environment-bound, and
must fail at the unwired sentinel until an approved platform-specific design
adds artifact verification, authentication, execution, and recovery checks.
```

- [ ] **Step 6: Record deferred activation and changelog**

Append TD-0011 without editing TD-0009/TD-0010:

```markdown
| TD-0011 | The Phase 6 readiness manifest ships in `template` status, validation is approval-neutral, and the rollback workflow intentionally fails closed; no observability backend or rollback command exists until a consumer adopts a platform. | `observability/production-readiness.conf`, `.github/workflows/production-readiness.yml`, `.github/workflows/rollback.yml` | Open | Select the production platform and observability backend through approved designs, supply and separately approve SLO/recovery/rollback evidence, change the manifest to `active` for contract validation, and replace the rollback sentinel with verified artifact retrieval, job-scoped authentication, rollback execution, and recovery verification. Human/environment approval remains external. |
```

Add under `CHANGELOG.md` `Unreleased`:

```markdown
- Added the Phase 6 vendor-neutral production-readiness contract, read-only readiness workflow, fail-closed manual rollback skeleton, executable validation tests, and operational observability/recovery baseline; platform activation remains tracked by TD-0011.
```

- [ ] **Step 7: Validate and commit documentation**

```bash
make readiness-check
make docs-check
rg -n "Adapt to your project" observability/README.md docs/operations/{observability,monitoring,alerting,runbook,rollback,backup-and-recovery,disaster-recovery,capacity-management}.md
git diff --check
```

Expected: readiness prints template/false; docs-check/diff exit zero; `rg` exits
one with no matches. Report unavailable optional documentation tools as skipped.

```bash
git add AGENTS.md CHANGELOG.md observability/README.md \
  docs/operations/observability.md docs/operations/monitoring.md \
  docs/operations/alerting.md docs/operations/runbook.md \
  docs/operations/rollback.md docs/operations/backup-and-recovery.md \
  docs/operations/disaster-recovery.md docs/operations/capacity-management.md \
  docs/operations/deployment-guide.md docs/plans/technical-debt.md
git diff --cached --check
git commit -m "docs: add Phase 6 operational baseline"
```

---

### Task 6: Run the complete gate and prepare Draft PR evidence

**Files:**
- Review: every path changed from `origin/main..HEAD`
- Verify unchanged: `.github/workflows/deploy-development.yml`
- Verify unchanged: `.github/workflows/deploy-staging.yml`
- Verify unchanged: `.github/workflows/deploy-production.yml`
- Verify unchanged: `.github/workflows/smoke-test.yml`

**Interfaces:**
- Consumes: all commits from Tasks 1–5.
- Produces: a clean branch with local evidence.
- Produces after publication approval: a Draft PR and remote readiness result.

- [ ] **Step 1: Run fresh local gates**

```bash
make readiness-check
make test-scripts
make ci
make docs-check
actionlint .github/workflows/*.yml
shellcheck -x scripts/validate-production-readiness.sh scripts/test/test-production-readiness.sh
uvx zizmor --pedantic .github/workflows/production-readiness.yml .github/workflows/rollback.yml
git diff --check origin/main..HEAD
```

Expected: every command exits zero. Record exact assertion counts. Readiness
output is template/false. Record optional tools skipped by docs-check.

- [ ] **Step 2: Prove deploy/smoke are unchanged**

```bash
git diff --exit-code origin/main..HEAD -- \
  .github/workflows/deploy-development.yml \
  .github/workflows/deploy-staging.yml \
  .github/workflows/deploy-production.yml \
  .github/workflows/smoke-test.yml
```

Expected: exit zero with no output.

- [ ] **Step 3: Review the complete diff**

```bash
git diff --stat origin/main..HEAD
git diff origin/main..HEAD
git status --short --branch
```

Confirm every line maps to the design; manifest data is never evaluated;
workflows have no write/OIDC/secret/production command; shell bodies contain no
input expression; rollback always reaches a non-zero sentinel; template mode
cannot print true; fixtures cover stateful/stateless recovery; TD-0009 and
TD-0010 remain open; and no unrelated file changed.

- [ ] **Step 4: Request scoped review**

Review validator/path-boundary correctness, workflow input/permission safety,
and spec/implementation/document consistency separately. Apply at most one
justified fix wave, then repeat Step 1. Do not broaden into deploy, smoke,
vendor selection, or unrelated debt.

- [ ] **Step 5: Publish only after the finishing-branch choice**

If the owner selects Draft PR publication:

```bash
git push -u origin feat/phase6-production-readiness-baseline
```

Create a Draft PR against `main`; do not merge. Include business purpose,
scope/out-of-scope, design, TDD red/green evidence, local gates, security and
rollback implications, TD-0011, and unchanged deploy/smoke confirmation.

- [ ] **Step 6: Verify remote behavior and hand off**

Require `Production-readiness contract` to succeed and show:

```text
readiness_status=template
readiness_contract_valid=true
production_ready=false
```

Require actionlint, zizmor, docs, secret, and existing required checks to pass.
Do not dispatch `rollback.yml`; success is intentionally impossible until a
platform is wired, and the local contract is the acceptance evidence.

Report branch SHA/commits, changed files, red/green evidence, assertion counts,
local/remote checks, PR and run URLs, unavailable local tools, TD-0011, and
unchanged deploy/smoke skeletons. Never claim the repository is production-ready.
