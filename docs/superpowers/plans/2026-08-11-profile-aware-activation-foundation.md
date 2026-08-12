# Profile-Aware Activation Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require every newly initialized consumer to receive an explicit, policy-aligned maturity profile and establish one deterministic effective-policy resolver without changing workflow execution or branch protection.

**Architecture:** `scripts/init-project.sh` writes project and profile configuration together from explicit consumer choices. A new POSIX resolver validates project/profile state, evaluates the normative mapping, and emits the future orchestrator contract; the existing shadow script becomes a presentation-only wrapper over that resolver.

**Tech Stack:** POSIX `sh`, `awk`, `sed`, `grep`, Make, YAML, existing shell-test helpers.

## Global Constraints

- This plan is the first implementation PR under ADR-0010; it does not implement the orchestrator or required-controls aggregate.
- Do not modify workflow triggers, workflow permissions, branch protection, `scripts/setup-branch-protection.sh`, deployment behavior, or production environments.
- Do not suppress any existing baseline workflow or control.
- The template repository has neither `.template/project.yaml` nor `.template/profile.yaml` and must remain green in compatibility mode.
- Every initializer run must select exactly one of `starter`, `standard`, or `enterprise`; non-interactive execution without `--profile` fails.
- New consumers receive both `.template/project.yaml` and `.template/profile.yaml` in the same successful initializer run.
- Enterprise initialization requires a non-`none` deployment target so the initializer never creates a profile below the Enterprise minimum posture.
- A consumer project config without a profile config fails the policy resolver; no profile is inferred.
- Stronger-than-default declarations are allowed; weaker-than-minimum declarations are reported as `policy-mismatch` for the later aggregate to reject.
- The central resolver is the only component that interprets profile mapping and alignment.
- Unit tests remain an invariant mandatory outcome outside the profile mapping; the later orchestrator must aggregate them with the mapped controls.
- Preserve POSIX `/bin/sh` compatibility on macOS and Linux; add no package or YAML-parser dependency.
- Keep profile configuration credential-free and reject unknown, duplicate, or secret-like fields through the existing validator.
- Historical disposable consumer pilots are not migrated.

---

### Task 1: Require and generate an aligned profile during initialization

**Files:**
- Modify: `scripts/test/test-init-project.sh`
- Modify: `scripts/init-project.sh`

**Interfaces:**
- Consumes: `--profile starter|standard|enterprise`, optional `--project-type`, `--ai-enabled`, and `--deployment-target` arguments.
- Produces: `.template/profile.yaml` version `1`, validated by `scripts/validate-profile-config.sh`.
- Preserves: current README identity and `.template/project.yaml` behavior, including explicit `--reconfigure` protection.

- [ ] **Step 1: Add failing initializer contracts**

Update every invocation in `scripts/test/test-init-project.sh` that is not
explicitly testing a missing or invalid profile to pass `--profile standard`.
This prevents unrelated negative tests from passing for the wrong reason.
Extend the first successful Standard case with these exact assertions:

```sh
if grep -Fq 'profile: standard' "$WORK/.template/profile.yaml" \
  && grep -Fq 'type: other' "$WORK/.template/profile.yaml" \
  && grep -Fq 'primary: node' "$WORK/.template/profile.yaml" \
  && grep -Fq 'enabled: false' "$WORK/.template/profile.yaml" \
  && grep -Fq 'semantic_review: advisory' "$WORK/.template/profile.yaml" \
  && grep -Fq 'structural_review: advisory' "$WORK/.template/profile.yaml" \
  && grep -Fq 'codeql: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'coverage: true' "$WORK/.template/profile.yaml" \
  && sh "$ROOT/scripts/validate-profile-config.sh" \
    "$WORK/.template/profile.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL writes a valid Standard profile\n' >&2
fi
```

Add these negative contracts using a fresh README fixture for each case:

```sh
if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  rm -f .template/project.yaml .template/profile.yaml && \
  sh "$ROOT/scripts/init-project.sh" --name missing-profile \
    --layout single) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts non-interactive init without profile\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  rm -f .template/project.yaml .template/profile.yaml && \
  sh "$ROOT/scripts/init-project.sh" --name bad-profile \
    --profile premium --layout single) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts unsupported profile\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  rm -f .template/project.yaml .template/profile.yaml && \
  sh "$ROOT/scripts/init-project.sh" --name enterprise-without-target \
    --profile enterprise --layout single) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts Enterprise without deployment target\n' >&2
else
  PASS=$((PASS+1))
fi
```

Extend the existing explicit reconfiguration case with
`--profile enterprise --project-type api --ai-enabled true
--deployment-target cloud`, then assert Enterprise AI review, SBOM,
attestation, Scorecard, deployment, and target values are enabled.

- [ ] **Step 2: Run the initializer test and verify RED**

Run:

```sh
sh scripts/test/test-init-project.sh
```

Expected: non-zero because `--profile`, `--project-type`, `--ai-enabled`, and
`--deployment-target` are unknown and no profile file is written.

- [ ] **Step 3: Add bounded initializer arguments and validation**

Add these defaults and usage entries to `scripts/init-project.sh`:

```sh
PROFILE=''
PROJECT_TYPE='other'
AI_ENABLED='false'
DEPLOYMENT_TARGET='none'

# usage text
--profile PROFILE           starter|standard|enterprise (required)
--project-type TYPE         web-app|api|worker|library|data-app|integration|other
--ai-enabled BOOLEAN        true|false (default: false)
--deployment-target TARGET  none|docker|kubernetes|cloud|self-hosted|other
```

Parse each option with the same missing-value guard used by `--stack`. After
argument parsing, prompt only when stdin is interactive:

```sh
if [ -z "$PROFILE" ] && [ -t 0 ]; then
  printf '%s' 'Maturity profile (starter/standard/enterprise): '
  IFS= read -r PROFILE || true
fi
[ -n "$PROFILE" ] || die '--profile is required (starter, standard, or enterprise)'

case "$PROFILE" in
  starter|standard|enterprise) ;;
  *) die "unsupported profile '$PROFILE' (use starter, standard, or enterprise)" ;;
esac
case "$PROJECT_TYPE" in
  web-app|api|worker|library|data-app|integration|other) ;;
  *) die "unsupported project type '$PROJECT_TYPE'" ;;
esac
case "$AI_ENABLED" in true|false) ;; *) die '--ai-enabled must be true or false' ;; esac
case "$DEPLOYMENT_TARGET" in
  none|docker|kubernetes|cloud|self-hosted|other) ;;
  *) die "unsupported deployment target '$DEPLOYMENT_TARGET'" ;;
esac
if [ "$PROFILE" = enterprise ] && [ "$DEPLOYMENT_TARGET" = none ]; then
  die 'enterprise profile requires a non-none --deployment-target'
fi
```

Derive `DEPLOYMENT_ENABLED=true` for non-`none` targets and `false` otherwise.

- [ ] **Step 4: Generate exact per-profile values without parsing YAML**

Before temporary files are created, set the normative values with one bounded
case statement:

```sh
case "$PROFILE" in
  starter)
    SEMANTIC_REVIEW=off; STRUCTURAL_REVIEW=off
    CODEQL=false; COVERAGE=false; SBOM=false
    ARTIFACT_ATTESTATION=false; SCORECARD=false
    ;;
  standard)
    SEMANTIC_REVIEW=advisory; STRUCTURAL_REVIEW=advisory
    CODEQL=true; COVERAGE=true; SBOM=false
    ARTIFACT_ATTESTATION=false; SCORECARD=false
    ;;
  enterprise)
    SEMANTIC_REVIEW=enabled; STRUCTURAL_REVIEW=enabled
    CODEQL=true; COVERAGE=true; SBOM=true
    ARTIFACT_ATTESTATION=true; SCORECARD=true
    ;;
esac
```

Set `AI_EVALUATION` equal to `AI_ENABLED`. Add
`PROFILE_FILE=.template/profile.yaml` and a same-directory temporary file to
the existing trap. Write this exact shape:

```yaml
# Generated by scripts/init-project.sh; keep credentials out of this file.
version: 1
profile: <PROFILE>
project:
  type: <PROJECT_TYPE>
stack:
  primary: <STACK>
ai:
  enabled: <AI_ENABLED>
  evaluation: <AI_EVALUATION>
  semantic_review: <SEMANTIC_REVIEW>
  structural_review: <STRUCTURAL_REVIEW>
deployment:
  enabled: <DEPLOYMENT_ENABLED>
  target: <DEPLOYMENT_TARGET>
controls:
  secret_scan: true
  dependency_review: true
  codeql: <CODEQL>
  coverage: <COVERAGE>
  sbom: <SBOM>
  artifact_attestation: <ARTIFACT_ATTESTATION>
  scorecard: <SCORECARD>
```

Validate both temporary config files before replacing README or either live
config:

```sh
sh scripts/validate-project-config.sh "$CONFIG_TEMP" >/dev/null 2>&1 \
  || die 'generated project config is invalid'
sh scripts/validate-profile-config.sh "$PROFILE_TEMP" >/dev/null 2>&1 \
  || die 'generated profile config is invalid'
```

Treat an existing profile like an existing project config: refuse without
`--reconfigure`. On success move README, project config, and profile config,
then print the selected profile in the completion message.

- [ ] **Step 5: Verify initializer GREEN and no partial writes**

Run:

```sh
sh -n scripts/init-project.sh
sh -n scripts/test/test-init-project.sh
sh scripts/test/test-init-project.sh
```

Expected: all assertions pass. Inspect the failed Enterprise-without-target
fixture and confirm neither live config nor generated README identity changed.

- [ ] **Step 6: Commit the initializer slice**

```sh
git diff --check
git diff -- scripts/init-project.sh scripts/test/test-init-project.sh
git add scripts/init-project.sh scripts/test/test-init-project.sh
git commit -m "feat: require profile during project initialization"
```

---

### Task 2: Create the central effective-policy resolver

**Files:**
- Create: `scripts/resolve-profile-policy.sh`
- Create: `scripts/test/test-profile-policy.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `sh scripts/resolve-profile-policy.sh [PROFILE_PATH] [MAPPING_PATH] [PROJECT_PATH]`.
- Produces: deterministic key/value output with `mode`, `profile`, `status`, and seven fields per control.
- Fails: prefix `profile-policy:` for invalid mapping/configuration or an initialized consumer missing its profile.

- [ ] **Step 1: Write the failing policy contract test**

Create `scripts/test/test-profile-policy.sh` using `scripts/test/lib.sh`. Copy
the `assert_output_contains` helper from `test-profile-shadow.sh`, then assert:

```sh
POLICY="$ROOT/scripts/resolve-profile-policy.sh"
MAPPING="$ROOT/.template/profile-controls.yaml"

# Empty template state remains compatible.
template="$(sh "$POLICY" "$WORK/missing-profile.yaml" "$MAPPING" \
  "$WORK/missing-project.yaml")"
assert_output_contains "template compatibility" "$template" '^mode=compatibility$'
assert_output_contains "template baseline" "$template" \
  '^control\.secret_scan\.enabled=current-baseline$'

# A consumer marker without a profile fails closed.
printf 'version: 1\nlayout: single\nprimary_stack: node\nprimary_path: src\n' \
  > "$WORK/project.yaml"
assert_exit "consumer missing profile fails" 1 sh "$POLICY" \
  "$WORK/missing-profile.yaml" "$MAPPING" "$WORK/project.yaml"

# Standard produces blocking CodeQL and advisory semantic review.
standard="$(sh "$POLICY" "$ROOT/.template/profile.yaml.example" \
  "$MAPPING" "$WORK/project.yaml")"
assert_output_contains "standard mode" "$standard" '^mode=profile$'
assert_output_contains "codeql enabled" "$standard" \
  '^control\.codeql\.enabled=true$'
assert_output_contains "codeql PR required" "$standard" \
  '^control\.codeql\.pr_required=true$'
assert_output_contains "semantic review not PR blocking" "$standard" \
  '^control\.semantic_review\.pr_required=false$'

# A stronger Starter declaration remains valid.
sed 's/^profile: standard$/profile: starter/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/starter.yaml"
starter="$(sh "$POLICY" "$WORK/starter.yaml" "$MAPPING" "$WORK/project.yaml")"
assert_output_contains "stronger Starter CodeQL" "$starter" \
  '^control\.codeql\.alignment=stronger-than-default$'

# A weakened Enterprise declaration reports warning deterministically.
sed 's/^profile: standard$/profile: enterprise/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/enterprise.yaml"
enterprise="$(sh "$POLICY" "$WORK/enterprise.yaml" "$MAPPING" \
  "$WORK/project.yaml" 2>"$WORK/enterprise.err")"
assert_output_contains "Enterprise warning" "$enterprise" '^status=warning$'
assert_output_contains "Enterprise SBOM mismatch" "$enterprise" \
  '^control\.sbom\.alignment=policy-mismatch$'
assert_output_contains "Enterprise SBOM required" "$enterprise" \
  '^control\.sbom\.policy_required=true$'
```

Also assert malformed mappings, directory paths, invalid profiles, and profile
without project config fail; run the Standard case twice and compare byte-for-
byte output.

- [ ] **Step 2: Run the policy test and verify RED**

```sh
sh scripts/test/test-profile-policy.sh
```

Expected: non-zero because `scripts/resolve-profile-policy.sh` does not exist.

- [ ] **Step 3: Implement the central resolver contract**

Create an executable POSIX script with:

```sh
PROFILE_CONFIG="${1:-.template/profile.yaml}"
CONTROL_MAP="${2:-.template/profile-controls.yaml}"
PROJECT_CONFIG="${3:-.template/project.yaml}"
CONTROLS='secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard ai_evaluation semantic_review structural_review production_governance'

die() {
  printf 'profile-policy: %s\n' "$1" >&2
  exit 1
}
```

Move the mapping validation, normalized profile readers, Boolean alignment,
review ranking, and deterministic control loop from
`scripts/resolve-profile-shadow.sh` into this script. Do not source executable
scripts or create a shared library with mutable global state.

Use these exact execution classes:

```sh
case "$1" in
  secret_scan|dependency_review|codeql|coverage|ai_evaluation)
    echo pull-request-blocking ;;
  semantic_review|structural_review) echo pull-request-advisory ;;
  sbom|artifact_attestation) echo post-merge ;;
  scorecard) echo scheduled-push ;;
  production_governance) echo manual-environment ;;
  *) die "unsupported control '$1'" ;;
esac
```

Missing-state behavior is exact:

```sh
if [ ! -e "$PROJECT_CONFIG" ] && [ ! -e "$PROFILE_CONFIG" ]; then
  printf 'mode=compatibility\nprofile=none\nstatus=current-baseline\n'
  for control in $CONTROLS; do
    printf 'control.%s.enabled=current-baseline\n' "$control"
  done
  exit 0
fi
[ -f "$PROJECT_CONFIG" ] || die "project config required at $PROJECT_CONFIG"
[ -f "$PROFILE_CONFIG" ] || die "initialized consumer requires profile config at $PROFILE_CONFIG"
```

Run both canonical validators. For a valid profile emit:

```text
mode=profile
profile=<starter|standard|enterprise>
status=<aligned|warning>
control.<name>.declared=<source value>
control.<name>.default=<mapping value>
control.<name>.enabled=<true|false>
control.<name>.class=<execution class>
control.<name>.policy_required=<true|false>
control.<name>.pr_required=<true|false>
control.<name>.alignment=<aligned|stronger-than-default|policy-mismatch>
```

Set `policy_required=true` when the selected profile requires the control or an
optional/stronger control is explicitly enabled. Set `pr_required=true` only
when `policy_required=true`, `enabled=true`, and the class is
`pull-request-blocking`. Semantic/structural review is never PR-blocking.
Emit the same warning annotations as shadow mode for every policy mismatch but
exit `0`; the future aggregate, not this foundation PR, will turn mismatches
into enforcement failures.

- [ ] **Step 4: Register and verify the resolver test**

Add `scripts/test/test-profile-policy.sh` immediately before the shadow tests in
`Makefile:test-scripts`. Run:

```sh
chmod +x scripts/resolve-profile-policy.sh scripts/test/test-profile-policy.sh
sh -n scripts/resolve-profile-policy.sh
sh -n scripts/test/test-profile-policy.sh
sh scripts/test/test-profile-policy.sh
```

Expected: syntax and contract tests pass; template compatibility and consumer
fail-closed behavior match the assertions.

- [ ] **Step 5: Commit the central resolver slice**

```sh
git diff --check
git diff -- scripts/resolve-profile-policy.sh scripts/test/test-profile-policy.sh Makefile
git add scripts/resolve-profile-policy.sh scripts/test/test-profile-policy.sh Makefile
git commit -m "feat: add effective profile policy resolver"
```

---

### Task 3: Make shadow observation consume the central policy

**Files:**
- Modify: `scripts/resolve-profile-shadow.sh`
- Modify: `scripts/test/test-profile-shadow.sh`

**Interfaces:**
- Consumes: complete output from `scripts/resolve-profile-policy.sh`.
- Produces: the existing shadow output contract and GitHub warnings without independently interpreting mapping policy.

- [ ] **Step 1: Add a failing single-source contract**

In `scripts/test/test-profile-shadow.sh`, add source-structure assertions:

```sh
if grep -Fq 'sh scripts/resolve-profile-policy.sh' "$RESOLVER" \
  && ! grep -Fq 'mapping_value()' "$RESOLVER" \
  && ! grep -Fq 'review_alignment()' "$RESOLVER"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL shadow delegates all policy resolution\n' >&2
fi
```

Keep every current output and determinism assertion. Add an initialized
consumer missing-profile case and expect prefix `profile-shadow:` with non-zero
exit. Create one valid version-1 project fixture and change `run_shadow()` to
pass it as the third argument for every present-profile case:

```sh
PROJECT="$WORK/project.yaml"
printf 'version: 1\nlayout: single\nprimary_stack: node\nprimary_path: src\n' \
  > "$PROJECT"

run_shadow() {
  sh "$RESOLVER" "$1" "${2:-$MAPPING}" "$PROJECT"
}
```

Call the compatibility case directly with a separate missing project path so
it still proves template behavior rather than consumer behavior.

- [ ] **Step 2: Run the shadow test and verify RED**

```sh
sh scripts/test/test-profile-shadow.sh
```

Expected: failure because the current shadow script still owns mapping and
alignment helpers.

- [ ] **Step 3: Replace shadow policy logic with a presentation wrapper**

The wrapper accepts the existing first two arguments and an optional third
project path:

```sh
PROFILE_CONFIG="${1:-.template/profile.yaml}"
CONTROL_MAP="${2:-.template/profile-controls.yaml}"
PROJECT_CONFIG="${3:-.template/project.yaml}"
REPORT="$(mktemp "${TMPDIR:-/tmp}/template-ai-native-profile-shadow.XXXXXX")"
ERROR="${REPORT}.err"
trap 'rm -f "$REPORT" "$ERROR"' EXIT HUP INT TERM

if ! sh scripts/resolve-profile-policy.sh "$PROFILE_CONFIG" "$CONTROL_MAP" \
  "$PROJECT_CONFIG" > "$REPORT" 2> "$ERROR"; then
  printf 'profile-shadow: effective policy resolution failed\n' >&2
  cat "$ERROR" >&2
  exit 1
fi
cat "$ERROR" >&2
```

For `mode=compatibility`, retain `mode=compatibility`, `profile=none`,
`status=current-baseline`, and map every `.enabled=current-baseline` field to
the existing `.decision=current-baseline` field.

For `mode=profile`, print `mode=shadow`, the same profile/status, and for every
control copy `declared`, `default`, `class`, and `alignment`. Convert
`.enabled=true` to `.decision=would-run` and `.enabled=false` to
`.decision=would-skip`. Use one bounded `report_value CONTROL FIELD` awk helper;
do not restore mapping or alignment functions.

- [ ] **Step 4: Verify policy and shadow contracts together**

```sh
sh -n scripts/resolve-profile-shadow.sh
sh scripts/test/test-profile-policy.sh
sh scripts/test/test-profile-shadow.sh
sh scripts/test/test-profile-shadow-workflow.sh
```

Expected: all pass and the workflow contract remains unchanged.

- [ ] **Step 5: Commit the shadow delegation slice**

```sh
git diff --check
git diff -- scripts/resolve-profile-shadow.sh scripts/test/test-profile-shadow.sh
git add scripts/resolve-profile-shadow.sh scripts/test/test-profile-shadow.sh
git commit -m "refactor: centralize profile policy resolution"
```

---

### Task 4: Add local policy validation and synchronize consumer guidance

**Files:**
- Modify: `Makefile`
- Modify: `README.md`
- Modify: `docs/getting-started.md`
- Modify: `scripts/README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/plans/roadmap.md`
- Modify: `docs/plans/technical-debt.md`

**Interfaces:**
- Produces: `make profile-policy-check` and updated initialization examples that always include `--profile`.
- Preserves: profile-aware workflow execution and branch protection remain unchanged.

- [ ] **Step 1: Add the local policy gate**

Add `profile-policy-check` to `.PHONY`, then define and register it after the
shape validator:

```make
profile-config-check:  ; @sh scripts/validate-profile-config.sh
profile-policy-check:  ; @sh scripts/resolve-profile-policy.sh >/dev/null

ci: format-check lint docs-check readiness-check project-config-check profile-config-check profile-policy-check test-scripts
```

Run:

```sh
make profile-policy-check
```

Expected: exit `0` in template compatibility mode.

- [ ] **Step 2: Update exact consumer commands and behavior descriptions**

Update every `scripts/init-project.sh` example in `README.md` and
`docs/getting-started.md` to include `--profile starter|standard|enterprise`.
Document:

- selection is mandatory and never inferred;
- `--project-type` and `--ai-enabled` defaults;
- Enterprise requires `--deployment-target` with a non-`none` value;
- initializer writes both project and profile configs;
- template compatibility mode remains valid;
- consumer missing/invalid profile fails `make ci`;
- workflow execution remains unchanged in this PR.

Replace the stale `scripts/README.md` statements that the initializer does not
configure profiles and that profiles are optional for initialized consumers.
Add the central resolver row with its exact command and output purpose.

- [ ] **Step 3: Update governance records without claiming activation**

Under `CHANGELOG.md` `[Unreleased]`, record required profile initialization,
central effective-policy resolution, and shadow delegation. In the roadmap,
mark only the activation foundation implemented and keep advisory orchestrator,
hosted pilots, enforcement, branch protection, and duplicate-workflow removal
pending. Update TD-0015 with the same boundary.

- [ ] **Step 4: Run focused documentation and local contracts**

```sh
sh scripts/test/test-init-project.sh
sh scripts/test/test-profile-config.sh
sh scripts/test/test-profile-policy.sh
sh scripts/test/test-profile-shadow.sh
sh scripts/test/test-profile-shadow-workflow.sh
make docs-check
```

Expected: all focused tests and docs check pass. Report optional local tooling
skips exactly as observed; do not describe a skipped tool as executed.

- [ ] **Step 5: Commit the local-gate and documentation slice**

```sh
git diff --check
git diff -- Makefile README.md docs/getting-started.md scripts/README.md CHANGELOG.md docs/plans/roadmap.md docs/plans/technical-debt.md
git add Makefile README.md docs/getting-started.md scripts/README.md CHANGELOG.md docs/plans/roadmap.md docs/plans/technical-debt.md
git commit -m "docs: require explicit consumer profiles"
```

---

### Task 5: Verify the complete activation-foundation diff

**Files:**
- Review: every file changed by Tasks 1–4
- Do not create implementation files in this task.

**Interfaces:**
- Produces: evidence that the first ADR-0010 implementation slice is safe to publish for review.

- [ ] **Step 1: Run the complete repository-native gates**

```sh
make test-scripts
make docs-check
make ci
```

Expected: all commands exit `0`. The empty template reports compatibility mode,
`readiness_status=template`, and `production_ready=false`.

- [ ] **Step 2: Run syntax and whitespace checks**

```sh
sh -n scripts/init-project.sh
sh -n scripts/resolve-profile-policy.sh
sh -n scripts/resolve-profile-shadow.sh
sh -n scripts/test/test-init-project.sh
sh -n scripts/test/test-profile-policy.sh
sh -n scripts/test/test-profile-shadow.sh
git diff --check
```

Expected: every command exits `0` with no output from syntax or whitespace
checks.

- [ ] **Step 3: Review the full branch diff against ADR-0010**

```sh
git status --short
git diff main...HEAD --stat
git diff main...HEAD
```

Confirm all of the following:

- initializer profile selection is mandatory and idempotent;
- generated profiles pass the canonical validator and meet profile minimums;
- template compatibility remains explicit;
- initialized consumers cannot omit profiles silently;
- one resolver owns mapping/alignment decisions;
- shadow output remains observational and backward-compatible;
- no workflow execution, required context, branch protection, permission,
  deployment, provider, or production behavior changed;
- no secret, debug output, placeholder, unrelated refactor, or dependency was
  introduced.

- [ ] **Step 4: Stop before orchestration or enforcement**

Report the actual checks, residual risks, and the next separate plan boundary:
an advisory `Profile policy / Required controls` orchestrator that preserves all
baseline workflow execution. Do not implement that orchestrator, create hosted
pilots, update branch protection, or remove duplicate execution in this plan.

## Follow-up plan boundaries

After this plan merges, create separate reviewed plans in this order:

1. advisory orchestrator plus stable aggregate and reusable control boundaries;
2. three disposable hosted profile pilots plus rerun, push, fork, and required-
   failure evidence;
3. branch-protection migration and rollback rehearsal;
4. enforcement and duplicate-execution removal only after every ADR-0010 gate
   passes.
