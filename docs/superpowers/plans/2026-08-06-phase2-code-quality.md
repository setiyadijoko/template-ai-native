# Phase 2 — Code-quality baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Level-2 code-quality baseline to `template-ai-native`: a dispatcher + three reusable workflows that detect the consumer's stack and run format-check, lint, typecheck, unit/integration/e2e tests, an 80% coverage gate, and build — blocking when a tool is present, no-oping cleanly when the stack is unknown.

**Architecture:** A dispatcher workflow (`ci.yml`) detects the stack once and calls three reusable workflows (`ci-quality.yml`, `ci-test.yml`, `build.yml`) via `workflow_call`. The per-stack tool mapping lives in a single pure-mapper shell script (`scripts/stack-tools.sh`) so language logic is in one testable place, not duplicated across YAML conditionals. Downstream jobs skip when `stack == unknown` (empty template).

**Tech Stack:** GitHub Actions (YAML), POSIX shell (`scripts/stack-tools.sh`, Makefile, test script). Per-stack tools: python(ruff/mypy/pytest), node(prettier/eslint/tsc/vitest), go(gofmt/golangci-lint/go), java(maven/spotless/checkstyle/jacoco), dotnet(dotnet CLI).

**Reference spec:** `docs/superpowers/specs/2026-08-06-phase2-code-quality-design.md` (authoritative; this plan references its section numbers).

## Global Constraints

- **Stack-agnostic:** `src/` may be empty; when `stack == unknown` all quality/test/build jobs SKIP cleanly (dispatcher green, no noise). Enforced via `if: needs.detect.outputs.stack != 'unknown'`.
- **Workflow security (Phase-1 lesson):** every `uses:` pinned to a commit SHA resolved via `gh api repos/<repo>/git/refs/tags/<tag>` at implementation time — NEVER trust recalled SHAs. Annotated tags must be dereferenced to the commit SHA (`.../git/tags/<tagsha>` → `.object.sha`).
- **Least privilege:** `permissions: contents: read` default; `actions: read` only where a step needs workflow-run metadata; no `pull_request_target`.
- **Coverage gate:** `fail-under=80` overall when a coverage tool is present; skip silently when not. 90% critical/changed-lines deferred (TD-0002/0003).
- **Make no-op preserved:** on `unknown` stack, `make lint`/`make test`/etc. stay exit 0 with a `[skip]` message.
- **POSIX `sh`:** all scripts run on macOS `/bin/sh` and Linux CI; no Bashisms.
- **Conventional Commits:** `feat:`, `ci:`, `test:`, `docs:`, `chore:`.
- Build on branch `phase-2-code-quality` (already created; spec committed at `61b526b`). Base = `main` (`8bf6339`). Do NOT push to `main` directly.

## File Structure

| Task | Cohesion | Key files |
|---|---|---|
| 1 | `stack-tools.sh` mapper + its tests (TDD — the only real code) | `scripts/stack-tools.sh`, `scripts/test/test-stack-detection.sh`, `scripts/test/lib.sh` |
| 2 | Dispatcher + reusable workflow scaffolding (SHA-pinned, least-privilege) | `.github/workflows/{ci,ci-quality,ci-test,build}.yml` |
| 3 | Per-stack setup + tool execution inside the reusable workflows | (edits to the 3 reusable workflows from Task 2) |
| 4 | Makefile + ci-local integration | `Makefile`, `scripts/ci-local.sh` |
| 5 | Cross-cutting docs + debt log + changelog + PR | `AGENTS.md`, `docs/development/testing-strategy.md`, `docs/plans/technical-debt.md`, `CHANGELOG.md`, open PR |

---

## Task 1: `stack-tools.sh` mapper + shell tests (TDD)

**Files:**
- Create: `scripts/stack-tools.sh`
- Create: `scripts/test/lib.sh` (shared assert helpers)
- Test: `scripts/test/test-stack-detection.sh`

**Interfaces:**
- Consumes: `scripts/detect-stack.sh` (already exists; prints `python|node|go|java|dotnet|unknown`).
- Produces: `scripts/stack-tools.sh` with CLI `stack-tools.sh <action>` (action ∈ `format|format-check|lint|typecheck|test|test-unit|test-integration|test-e2e|coverage|build`). Prints the command line(s) for the detected stack+action to stdout, or `no-op` for unknown. Exits `0` on success/usage-print, `64` on invalid action. Pure mapper — does NOT execute tools.

- [ ] **Step 1: Write the failing test** — create `scripts/test/lib.sh` and `scripts/test/test-stack-detection.sh`.

`scripts/test/lib.sh`:
```sh
# Minimal POSIX test helpers. No framework dependency.
# Counters
PASS=0
FAIL=0

# assert_eq <label> <actual> <expected>
assert_eq() {
  label="$1"; actual="$2"; expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$label" "$expected" "$actual" >&2
  fi
}

# assert_exit <label> <expected_code> <command...>
assert_exit() {
  label="$1"; expected="$2"; shift 2
  "$@" >/dev/null 2>&1
  assert_eq "$label (exit)" "$?" "$expected"
}

report() {
  printf 'passed=%d failed=%d\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
```

`scripts/test/test-stack-detection.sh`:
```sh
#!/usr/bin/env sh
# Tests for detect-stack.sh and stack-tools.sh. Creates temp manifests and
# asserts the mapper returns the right command per (stack, action).
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

# Run from a temp dir so manifest detection is isolated.
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
cd "$WORK"
TOOL="sh $ROOT/scripts/stack-tools.sh"
DET="sh $ROOT/scripts/detect-stack.sh"

# --- detect-stack.sh ---
printf '' > pyproject.toml
assert_eq "detect python" "$($DET)" "python"
rm -f pyproject.toml
printf '{}' > package.json
assert_eq "detect node" "$($DET)" "node"
rm -f package.json
printf 'module x\n' > go.mod
assert_eq "detect go" "$($DET)" "go"
rm -f go.mod
printf '<project></project>' > pom.xml
assert_eq "detect java" "$($DET)" "java"
rm -f pom.xml
printf '<Project Sdk="Microsoft.NET.Sdk"></Project>' > app.csproj
assert_eq "detect dotnet" "$($DET)" "dotnet"
rm -f app.csproj
assert_eq "detect unknown (empty)" "$($DET)" "unknown"

# --- stack-tools.sh: unknown stack -> no-op, exit 0 ---
for action in format lint typecheck test test-unit test-integration test-e2e coverage build; do
  out=$($TOOL "$action" 2>&1 || true)
  assert_eq "unknown/$action output" "$out" "no-op"
  assert_exit "unknown/$action exit" 0 sh "$ROOT/scripts/stack-tools.sh" "$action"
done

# --- stack-tools.sh: invalid action -> exit 64 ---
assert_exit "invalid action exit" 64 sh "$ROOT/scripts/stack-tools.sh" frobnicate

# --- per-stack mapping (representative actions) ---
printf '' > pyproject.toml
assert_eq "python lint" "$($TOOL lint)" "ruff check ."
assert_eq "python coverage" "$($TOOL coverage)" "pytest --cov=src --cov-report=xml --cov-report=term --cov-fail-under=80 tests/unit"
assert_eq "python build" "$($TOOL build)" "python -m build"
rm -f pyproject.toml

printf '{}' > package.json
assert_eq "node format-check" "$($TOOL format-check)" "prettier --check ."
assert_eq "node typecheck" "$($TOOL typecheck)" "tsc --noEmit"
assert_eq "node test-unit" "$($TOOL test-unit)" "vitest run --dir tests/unit"
rm -f package.json

printf 'module x\n' > go.mod
assert_eq "go lint" "$($TOOL lint)" "golangci-lint run"
assert_eq "go typecheck" "$($TOOL typecheck)" "go vet ./..."
assert_eq "go build" "$($TOOL build)" "go build -o bin/ ./..."
rm -f go.mod

printf '<project></project>' > pom.xml
assert_eq "java format-check" "$($TOOL format-check)" "mvn -q spotless:check"
assert_eq "java test-unit" "$($TOOL test-unit)" "mvn -q test"
assert_eq "java build" "$($TOOL build)" "mvn -q -DskipTests package"
rm -f pom.xml

printf '<Project Sdk="Microsoft.NET.Sdk"></Project>' > app.csproj
assert_eq "dotnet format-check" "$($TOOL format-check)" "dotnet format --verify-no-changes"
assert_eq "dotnet test-unit" "$($TOOL test-unit)" "dotnet test --filter Category=Unit"
assert_eq "dotnet build" "$($TOOL build)" "dotnet build -c Release"
rm -f app.csproj

report
```

- [ ] **Step 2: Run test to verify it fails** — `sh scripts/test/test-stack-detection.sh` → expect FAIL (script doesn't exist yet; detect-stack assertions pass, but stack-tools assertions error).

- [ ] **Step 3: Write minimal implementation** — create `scripts/stack-tools.sh`:

```sh
#!/usr/bin/env sh
# stack-tools.sh — pure mapper: prints the tool command for a given action
# based on the detected stack (see detect-stack.sh). Does NOT execute tools.
#
# Usage: stack-tools.sh <action>
#   actions: format | format-check | lint | typecheck | test | test-unit |
#            test-integration | test-e2e | coverage | build
# Exits: 0 (printed command or "no-op"), 64 (invalid action).
set -eu

ACTION="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STACK="$(sh "$HERE/detect-stack.sh")"

case "$ACTION" in
  format) ;;
  format-check) ;;
  lint) ;;
  typecheck) ;;
  test) ACTION=test-unit ;;   # `test` is an alias for the full unit run
  test-unit) ;;
  test-integration) ;;
  test-e2e) ;;
  coverage) ;;
  build) ;;
  *)
    printf 'usage: stack-tools.sh <action>\n  actions: format|format-check|lint|typecheck|test|test-unit|test-integration|test-e2e|coverage|build\n' >&2
    exit 64
    ;;
esac

# Per-(stack, action) command table. Unknown stack => no-op.
case "$STACK:$ACTION" in
  python:format)            echo "ruff format ." ;;
  python:format-check)      echo "ruff format --check ." ;;
  python:lint)              echo "ruff check ." ;;
  python:typecheck)         echo "mypy src" ;;
  python:test-unit)         echo "pytest -q tests/unit" ;;
  python:test-integration)  echo "pytest -q tests/integration" ;;
  python:test-e2e)          echo "pytest -q tests/e2e" ;;
  python:coverage)          echo "pytest --cov=src --cov-report=xml --cov-report=term --cov-fail-under=80 tests/unit" ;;
  python:build)             echo "python -m build" ;;

  node:format)              echo "prettier --write ." ;;
  node:format-check)        echo "prettier --check ." ;;
  node:lint)                echo "eslint ." ;;
  node:typecheck)           echo "tsc --noEmit" ;;
  node:test-unit)           echo "vitest run --dir tests/unit" ;;
  node:test-integration)    echo "vitest run --dir tests/integration" ;;
  node:test-e2e)            echo "vitest run --dir tests/e2e" ;;
  node:coverage)            echo "vitest run --coverage --coverage.thresholds.lines=80" ;;
  node:build)               echo "npm run build" ;;

  go:format)                echo "gofmt -w ." ;;
  go:format-check)          echo "gofmt -l ." ;;
  go:lint)                  echo "golangci-lint run" ;;
  go:typecheck)             echo "go vet ./..." ;;
  go:test-unit)             echo "go test -short ./..." ;;
  go:test-integration)      echo "go test -run Integration ./..." ;;
  go:test-e2e)              echo "go test -run E2E ./..." ;;
  go:coverage)              echo "go test -coverprofile=coverage.out -covermode=atomic ./..." ;;
  go:build)                 echo "go build -o bin/ ./..." ;;

  java:format)              echo "mvn -q spotless:apply" ;;
  java:format-check)        echo "mvn -q spotless:check" ;;
  java:lint)                echo "mvn -q checkstyle:check" ;;
  java:typecheck)           echo "mvn -q compile" ;;
  java:test-unit)           echo "mvn -q test" ;;
  java:test-integration)    echo "mvn -q verify -Dtest='*IT'" ;;
  java:test-e2e)            echo "mvn -q verify -Dtest='*E2E'" ;;
  java:coverage)            echo "mvn -q verify -Pcoverage" ;;
  java:build)               echo "mvn -q -DskipTests package" ;;

  dotnet:format)            echo "dotnet format" ;;
  dotnet:format-check)      echo "dotnet format --verify-no-changes" ;;
  dotnet:lint)              echo "dotnet format --verify-no-changes" ;;
  dotnet:typecheck)         echo "dotnet build" ;;
  dotnet:test-unit)         echo "dotnet test --filter Category=Unit" ;;
  dotnet:test-integration)  echo "dotnet test --filter Category=Integration" ;;
  dotnet:test-e2e)          echo "dotnet test --filter Category=E2E" ;;
  dotnet:coverage)          echo 'dotnet test --collect:"XPlat Code Coverage" /p:CoverletOutputFormat=cobertura' ;;
  dotnet:build)             echo "dotnet build -c Release" ;;

  *:*)
    echo "no-op"
    ;;
esac
```
`chmod +x scripts/stack-tools.sh`.

- [ ] **Step 4: Run test to verify it passes** — `sh scripts/test/test-stack-detection.sh` → expect `passed=N failed=0` and exit 0.

- [ ] **Step 5: Commit**
```sh
git add scripts/stack-tools.sh scripts/test/
git commit -m "feat(scripts): add stack-tools.sh per-stack tool mapper with shell tests"
```

---

## Task 2: Dispatcher + reusable workflow scaffolding (SHA-pinned)

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/ci-quality.yml`
- Create: `.github/workflows/ci-test.yml`
- Create: `.github/workflows/build.yml`

**Interfaces:**
- Consumes: `scripts/detect-stack.sh` (from Phase 1), `scripts/stack-tools.sh` (Task 1).
- Produces: three reusable workflows with `on: { workflow_call: { inputs: { stack: { type: string, required: true } } } }`, callable by `ci.yml`.

**Critical (Phase-1 lesson):** before writing any `uses:`, resolve each action's commit SHA at implementation time:
```sh
# For each action+tag, run and paste the COMMIT sha (not the annotated-tag sha):
repo="actions/checkout"; tag="v4.2.2"
t=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.sha')
ty=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.type')
if [ "$ty" = "tag" ]; then gh api "repos/$repo/git/tags/$t" --jq '.object.sha'; else echo "$t"; fi
```
Use the same SHA-verification loop from Phase 1 (`gh api repos/<repo>/git/commits/<sha>` returns 200) before committing.

- [ ] **Step 1: Resolve & record SHAs** for: `actions/checkout`, `actions/setup-python`, `actions/setup-node`, `actions/setup-go`, `actions/setup-java`, `actions/setup-dotnet`, `actions/upload-artifact`. Record each `<repo>@<sha> # <tag>` in a scratch note (the values go directly into the YAML).

- [ ] **Step 2: Create `.github/workflows/ci.yml`** (dispatcher):
```yaml
name: ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  detect:
    name: Detect stack
    runs-on: ubuntu-latest
    timeout-minutes: 3
    outputs:
      stack: ${{ steps.d.outputs.stack }}
    steps:
      - name: Checkout
        uses: actions/checkout@<SHA> # <tag>
      - id: d
        name: Detect stack
        run: |
          stack="$(sh scripts/detect-stack.sh)"
          echo "stack=$stack" >> "$GITHUB_OUTPUT"
          echo "Detected stack: $stack"

  quality:
    name: Quality (format/lint/typecheck/unit)
    needs: detect
    if: needs.detect.outputs.stack != 'unknown'
    uses: ./.github/workflows/ci-quality.yml
    with:
      stack: ${{ needs.detect.outputs.stack }}

  test:
    name: Tests + coverage
    needs: detect
    if: needs.detect.outputs.stack != 'unknown'
    uses: ./.github/workflows/ci-test.yml
    with:
      stack: ${{ needs.detect.outputs.stack }}

  build:
    name: Build
    needs: detect
    if: needs.detect.outputs.stack != 'unknown'
    uses: ./.github/workflows/build.yml
    with:
      stack: ${{ needs.detect.outputs.stack }}
```

- [ ] **Step 3: Create `.github/workflows/ci-quality.yml`** (reusable scaffold — Task 3 fills the per-stack setup + execution):
```yaml
name: ci-quality

on:
  workflow_call:
    inputs:
      stack:
        type: string
        required: true
  workflow_dispatch:
    inputs:
      stack:
        description: "Stack to run for (python|node|go|java|dotnet)"
        type: string
        required: true

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  quality:
    name: ${{ inputs.stack }} format/lint/typecheck/unit
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@<SHA> # <tag>
      # Task 3 adds: setup toolchain (by inputs.stack), install dev deps,
      # and run stack-tools.sh format-check / lint / typecheck / test-unit.
```

- [ ] **Step 4: Create `.github/workflows/ci-test.yml`** (reusable scaffold — analogous to ci-quality; Task 3 fills setup + test-integration/test-e2e/coverage).
```yaml
name: ci-test

on:
  workflow_call:
    inputs:
      stack:
        type: string
        required: true
  workflow_dispatch:
    inputs:
      stack:
        description: "Stack to run for (python|node|go|java|dotnet)"
        type: string
        required: true

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  test:
    name: ${{ inputs.stack }} integration/e2e/coverage
    runs-on: ubuntu-latest
    timeout-minutes: 25
    steps:
      - name: Checkout
        uses: actions/checkout@<SHA> # <tag>
      # Task 3 adds: setup toolchain, install dev deps,
      # run stack-tools.sh test-integration / test-e2e / coverage,
      # upload coverage artifact.
```

- [ ] **Step 5: Create `.github/workflows/build.yml`** (reusable scaffold — Task 3 fills setup + build + artifact upload).
```yaml
name: build

on:
  workflow_call:
    inputs:
      stack:
        type: string
        required: true
  workflow_dispatch:
    inputs:
      stack:
        description: "Stack to run for (python|node|go|java|dotnet)"
        type: string
        required: true

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true

jobs:
  build:
    name: ${{ inputs.stack }} build
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@<SHA> # <tag>
      # Task 3 adds: setup toolchain, run stack-tools.sh build,
      # upload build artifact (per-stack output dir).
```

- [ ] **Step 6: Verify** — YAML validity + SHA resolves:
```sh
/tmp/yamlcheck/bin/python -c "import yaml,glob; [list(yaml.safe_load_all(open(f))) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
# SHA verification loop (same as Phase 1):
grep -rhoE 'uses: [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[0-9a-f]{40}' .github/workflows/{ci,ci-quality,ci-test,build}.yml | sort -u | while IFS= read -r line; do
  repo=$(echo "$line" | sed -E 's|uses: ([^@]+)@.*|\1|'); sha=$(echo "$line" | sed -E 's|.*@([0-9a-f]{40})|\1|')
  gh api "repos/$repo/git/commits/$sha" >/dev/null 2>&1 && echo "OK   $repo@${sha:0:12}" || echo "FAIL $repo@${sha:0:12}"
done
```

- [ ] **Step 7: Commit**
```sh
git add .github/workflows/ci.yml .github/workflows/ci-quality.yml .github/workflows/ci-test.yml .github/workflows/build.yml
git commit -m "ci: add Phase-2 dispatcher and reusable quality/test/build scaffolding"
```

---

## Task 3: Per-stack setup + tool execution in reusable workflows

**Files:**
- Modify: `.github/workflows/ci-quality.yml`
- Modify: `.github/workflows/ci-test.yml`
- Modify: `.github/workflows/build.yml`

**Interfaces:**
- Consumes: `inputs.stack` from the dispatcher; `scripts/stack-tools.sh` (Task 1).
- Produces: working per-stack execution steps.

**Shared setup block** (paste into each workflow's job after checkout; uses `if:` to pick the right setup action per `inputs.stack`). Use the SHAs resolved in Task 2 Step 1.

- [ ] **Step 1: Fill `ci-quality.yml`** — after checkout, add:

```yaml
      - name: Setup Python
        if: inputs.stack == 'python'
        uses: actions/setup-python@<SHA> # <tag>
        with:
          python-version: "3.12"
      - name: Install Python dev deps
        if: inputs.stack == 'python'
        run: pip install ruff mypy pytest pytest-cov build

      - name: Setup Node
        if: inputs.stack == 'node'
        uses: actions/setup-node@<SHA> # <tag>
        with:
          node-version: "lts/*"
          cache: npm
      - name: Install Node dev deps
        if: inputs.stack == 'node'
        run: [ -f package.json ] && npm ci || true

      - name: Setup Go
        if: inputs.stack == 'go'
        uses: actions/setup-go@<SHA> # <tag>
        with:
          go-version-file: go.mod
          cache: true

      - name: Setup Java
        if: inputs.stack == 'java'
        uses: actions/setup-java@<SHA> # <tag>
        with:
          distribution: temurin
          java-version: "21"
          cache: maven

      - name: Setup .NET
        if: inputs.stack == 'dotnet'
        uses: actions/setup-dotnet@<SHA> # <tag>
        with:
          dotnet-version: "8.0.x"

      # Run quality gates via the stack mapper.
      - name: format-check
        run: sh -c "$(sh scripts/stack-tools.sh format-check)"
      - name: lint
        run: sh -c "$(sh scripts/stack-tools.sh lint)"
      - name: typecheck
        run: sh -c "$(sh scripts/stack-tools.sh typecheck)"
      - name: test-unit
        run: sh -c "$(sh scripts/stack-tools.sh test-unit)"
```
Note: `sh -c "$(sh scripts/stack-tools.sh <action>)"` resolves the mapper's printed command and executes it. If the command is `no-op`, the step runs `sh -c "no-op"` — to keep it clean, wrap with `|| true` is NOT desired (we want real failures to fail); instead guard the run with `if:` on a computed `has-stack` output, OR rely on the dispatcher's `if: stack != 'unknown'` (already enforced upstream). Use the dispatcher guard.

- [ ] **Step 2: Fill `ci-test.yml`** — same setup block as Step 1 (reuse the exact steps), then:
```yaml
      - name: test-integration
        run: sh -c "$(sh scripts/stack-tools.sh test-integration)"
      - name: test-e2e
        run: sh -c "$(sh scripts/stack-tools.sh test-e2e)"
      - name: coverage
        run: sh -c "$(sh scripts/stack-tools.sh coverage)"
      - name: Upload coverage report
        if: always()
        uses: actions/upload-artifact@<SHA> # <tag>
        with:
          name: coverage-${{ inputs.stack }}
          path: |
            coverage.xml
            coverage.out
            coverage.cobertura.xml
            target/site/jacoco/jacoco.xml
          if-no-files-found: ignore
```
For go, coverage threshold (<80 fails) is computed in a follow-up step:
```yaml
      - name: Enforce go coverage >= 80%
        if: inputs.stack == 'go' && hashFiles('coverage.out') != ''
        run: |
          pct=$(go tool cover -func=coverage.out | awk '/^total:/ {gsub("%","",$3); print $3}')
          echo "Go coverage: ${pct}%"
          awk "BEGIN {exit !($pct >= 80)}" || { echo "::error::Go coverage ${pct}% < 80%"; exit 1; }
```

- [ ] **Step 3: Fill `build.yml`** — same setup block, then:
```yaml
      - name: build
        run: sh -c "$(sh scripts/stack-tools.sh build)"
      - name: Upload build artifact
        if: hashFiles('dist','bin','target/*.jar','*.nupkg') != ''
        uses: actions/upload-artifact@<SHA> # <tag>
        with:
          name: build-${{ inputs.stack }}
          path: |
            dist/
            bin/
            target/*.jar
            *.nupkg
          if-no-files-found: ignore
```

- [ ] **Step 4: Verify** — YAML validity + SHA resolves (same loops as Task 2 Step 6).

- [ ] **Step 5: Commit**
```sh
git add .github/workflows/ci-quality.yml .github/workflows/ci-test.yml .github/workflows/build.yml
git commit -m "ci: wire per-stack setup and tool execution into reusable workflows"
```

---

## Task 4: Makefile + ci-local integration

**Files:**
- Modify: `Makefile`
- Modify: `scripts/ci-local.sh`

**Interfaces:**
- Consumes: `scripts/stack-tools.sh` (Task 1).
- Produces: `make` targets that run real tools when a stack is detected, no-op cleanly otherwise.

- [ ] **Step 1: Update `Makefile`** — replace the stub bodies so each target executes `stack-tools.sh` output and preserves the unknown-stack no-op. Replace the `ifeq ($(STACK),unknown) ... else ... endif` block's else-branch bodies and the `ci` target.

Current `else` branch has `@echo "TODO: configure ..."` lines. Change the else-branch bodies to:
```makefile
else
setup:            ; @sh -c "$$(sh scripts/stack-tools.sh format >/dev/null 2>&1; echo 'setup ready for $(STACK)')"
dev:              ; @echo "configure dev server for $(STACK)"
format:           ; @sh -c "$$(sh scripts/stack-tools.sh format)"
format-check:     ; @sh -c "$$(sh scripts/stack-tools.sh format-check)"
lint:             ; @sh -c "$$(sh scripts/stack-tools.sh lint)"
typecheck:        ; @sh -c "$$(sh scripts/stack-tools.sh typecheck)"
test:             ; @sh -c "$$(sh scripts/stack-tools.sh test-unit)"
test-unit:        ; @sh -c "$$(sh scripts/stack-tools.sh test-unit)"
test-contract:    ; @sh -c "$$(sh scripts/stack-tools.sh test-integration)"
test-integration: ; @sh -c "$$(sh scripts/stack-tools.sh test-integration)"
test-e2e:         ; @sh -c "$$(sh scripts/stack-tools.sh test-e2e)"
test-coverage:    ; @sh -c "$$(sh scripts/stack-tools.sh coverage)"
eval:             ; @echo "configure AI eval for $(STACK)"
eval-regression:  ; @echo "configure eval-regression"
eval-safety:      ; @echo "configure eval-safety"
dependency-scan:  ; @echo "[stub] dependency-review runs in CI"
container-scan:   ; @echo "[stub] trivy runs in CI when containers exist"
iac-scan:         ; @echo "[stub] checkov runs in CI when IaC exists"
build:            ; @sh -c "$$(sh scripts/stack-tools.sh build)"
run:              ; @echo "configure run for $(STACK)"
smoke-test:       ; @echo "configure smoke-test"
endif
```
Note the `$$` (escaped for make) so the shell sees `$(sh scripts/stack-tools.sh ...)`.

- [ ] **Step 2: Add `test-scripts` target** to the Makefile (anywhere in `.PHONY` + body):
```makefile
test-scripts:     ; @sh scripts/test/test-stack-detection.sh
```
And add `test-scripts` to the `.PHONY` line.

- [ ] **Step 3: Update `scripts/ci-local.sh`** — extend the `run` block to also call `stack-tools.sh` for format-check and lint when a stack is detected. After the existing `run "actionlint" actionlint` line, add:
```sh
# Run per-stack format-check + lint when a stack is detected.
if [ "$(sh scripts/detect-stack.sh)" != "unknown" ]; then
  printf '%s\n' ":: per-stack format-check ::"
  sh -c "$(sh scripts/stack-tools.sh format-check)" || fail=1
  printf '%s\n' ":: per-stack lint ::"
  sh -c "$(sh scripts/stack-tools.sh lint)" || fail=1
fi
```

- [ ] **Step 4: Verify**
```sh
# Empty template: targets still no-op (stack=unknown)
make lint       # → [skip] no stack detected...  exit 0
make test       # → [skip] ... exit 0
make ci         # exit 0
make test-scripts  # → passed=N failed=0, exit 0
```

- [ ] **Step 5: Commit**
```sh
git add Makefile scripts/ci-local.sh
git commit -m "feat: wire Makefile + ci-local to stack-tools.sh; add test-scripts target"
```

---

## Task 5: Cross-cutting docs + debt log + changelog + PR

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/development/testing-strategy.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update `AGENTS.md`** — under the "Setup, test, build, and security commands" section, after the existing `make` table, add:
```markdown
> CI runs these via the `ci.yml` dispatcher, which detects the stack once and calls the `ci-quality` / `ci-test` / `build` reusable workflows. The per-stack tool commands live in `scripts/stack-tools.sh` (single source of truth); change a tool there, not in each workflow.
```

- [ ] **Step 2: Update `docs/development/testing-strategy.md`** — in the "Thresholds" section, replace the existing threshold note with:
```markdown
## Thresholds (spec §8, partially phased)

- Overall unit coverage ≥ 80% — **enforced in Phase 2** (`fail-under=80`) when a coverage tool is present; skipped when stack is unknown.
- Critical domain modules ≥ 90% — deferred to Codecov (TD-0002).
- Changed-lines coverage ≥ 90% — deferred to Codecov (TD-0002).
- Critical security findings = 0 (Phase 3).
- Committed secrets = 0 (Phase 3).
- Blocking lint/type errors = 0 — enforced in Phase 2.
- Failed required AI evaluations = 0 (Phase 4).
- Undocumented breaking API changes = 0.

No meaningless coverage-only tests.
```

- [ ] **Step 3: Update `docs/plans/technical-debt.md`** — add two rows to the table:
```markdown
| TD-0002 | Coverage thresholds for critical modules (≥90%) and changed-lines (≥90%) require a coverage service (Codecov). Phase 2 enforces only ≥80% overall via each tool's native `fail-under`. | `scripts/stack-tools.sh`, `.github/workflows/ci-test.yml` | Open | Wire Codecov (`.codecov.yml` + token) and per-module/patch gating in a later phase. |
| TD-0003 | Go has no native `--cov-fail-under`; coverage threshold is enforced by an inline `awk` step in ci-test.yml. Centralize this if more stacks need similar post-processing. | `.github/workflows/ci-test.yml` | Open | Move threshold computation into a small helper script if a second stack needs it. |
```

- [ ] **Step 4: Update `CHANGELOG.md`** — under `## [Unreleased]`, add an `### Added` section (create the heading if absent):
```markdown
### Added
- Phase 2 code-quality baseline: `ci.yml` dispatcher + `ci-quality` / `ci-test` / `build` reusable workflows that auto-detect the consumer's stack (python/node/go/java/dotnet) and run format-check, lint, typecheck, unit/integration/e2e tests, an 80% coverage gate, and build. All jobs skip cleanly on the empty template (stack unknown).
- `scripts/stack-tools.sh` — single-source-of-truth per-stack tool mapper.
- `scripts/test/test-stack-detection.sh` — shell tests for the detection/mapper scripts.
- `make test-scripts` target; Makefile + ci-local now execute real tools when a stack is present.

### Changed
- `AGENTS.md` and `docs/development/testing-strategy.md` cross-reference the Phase-2 dispatcher and coverage phasing.
```

- [ ] **Step 5: Local verification**
```sh
make ci           # exit 0
make test-scripts # passed=N failed=0
make docs-check   # exit 0 (no new markdown issues)
# YAML validity:
/tmp/yamlcheck/bin/python -c "import yaml,glob; [list(yaml.safe_load_all(open(f))) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
# SHA resolves (loop from Task 2 Step 6) — all OK
```

- [ ] **Step 6: Commit + push + open PR**
```sh
git add AGENTS.md docs/development/testing-strategy.md docs/plans/technical-debt.md CHANGELOG.md
git commit -m "docs: cross-reference Phase-2 dispatcher, coverage phasing, debt entries, changelog"
git push -u origin phase-2-code-quality
gh pr create --base main --head phase-2-code-quality \
  --title "feat: Phase 2 — code-quality baseline (auto-detect reusable workflows)" \
  --body "<filled from .github/pull_request_template.md>"
```

- [ ] **Step 7: Verify PR checks** — wait for the 5 Phase-1 checks + the new `ci` dispatcher (which should skip all downstream jobs because the template's `src/` is empty → stack unknown → green). Report actual check results; never fabricate. If any check fails, diagnose from logs and push a fix commit (same loop as Phase 1).

- [ ] **Step 8: Hand off** — report the PR URL and check status to the owner for merge.

---

## Self-Review (run after writing)

**1. Spec coverage:**
- Multi-language auto-detect → Task 1 (`stack-tools.sh`) + Task 2 (`ci.yml` detect job) ✓
- Dispatcher calls reusable workflows → Task 2 (`ci.yml` calls ci-quality/ci-test/build) ✓
- Coverage gate (80% now, defer 90%) → Task 3 (ci-test coverage step) + Task 5 (TD-0002) ✓
- Script tests → Task 1 (test-stack-detection.sh) ✓
- Per-stack tool map (9 actions × 5 stacks) → Task 1 case table ✓
- Makefile integration preserving no-op → Task 4 ✓
- Cross-cutting docs/debt/changelog → Task 5 ✓
- SHA pinning via gh api → Task 2 Step 1 + Step 6 verification ✓

**2. Placeholder scan:** the `<SHA> # <tag>` markers in Task 2/3 are intentional "resolve at implementation time" instructions (the Phase-1 lesson forbids recalling SHAs); they are NOT placeholders in the plan-failure sense because Step 1 of Task 2 makes resolution a concrete, ordered step. ✓ All other steps have complete code.

**3. Consistency:** `stack-tools.sh` action names (`format`, `format-check`, `lint`, `typecheck`, `test`, `test-unit`, `test-integration`, `test-e2e`, `coverage`, `build`) match across Task 1 (case table), Task 3 (workflow steps), Task 4 (Makefile targets). `sh -c "$$(sh scripts/stack-tools.sh <action>)"` pattern is identical in Task 3 and Task 4. ✓

No gaps found.
