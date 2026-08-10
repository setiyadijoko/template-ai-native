# Python Project-Directory Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make root and direct-`src/` Python consumers use one deterministic project boundary for dependency installation, build execution, and artifact packaging.

**Architecture:** Add a read-only POSIX-shell resolver that returns `.` or `src`, refactor dependency bootstrap to consume it, and route Python builds through a focused wrapper. Single-stack and component-aware packaging resolve the same boundary before selecting its `dist/` output; artifact identity and workflow check contexts remain unchanged.

**Tech Stack:** POSIX `sh`, Bash inside existing GitHub Actions packaging steps, GitHub Actions YAML, existing shell contract harness.

## Global Constraints

- Support only the current directory or its direct `src/` child; recursive discovery remains prohibited.
- Recognize `pyproject.toml`, `setup.py`, `requirements.txt`, `requirements-dev.txt`, and `Pipfile` as dependency-boundary manifests.
- Require `pyproject.toml` or `setup.py` for package build execution.
- Exit 65 for absent, ambiguous, or non-buildable Python boundaries.
- Preserve root Python behavior, artifact names, deterministic tar options, workflow outputs, attestation inputs, and stable check contexts.
- Do not change pytest discovery, coverage thresholds, caching, Pipenv automation, profiles, deployment, or non-Python stack mappings.
- Add no external dependency or GitHub Action.

---

## File structure

**Create:**

- `scripts/resolve-python-project-dir.sh` — read-only root/direct-`src/` boundary resolver.
- `scripts/run-python-build.sh` — validates the selected build contract and executes the chosen Python interpreter from that boundary.
- `scripts/test/test-python-project-build.sh` — behavioral contracts for resolver and build wrapper.

**Modify:**

- `scripts/setup-python-deps.sh` — consume the shared resolver.
- `scripts/stack-tools.sh` — route Python build to the wrapper.
- `scripts/test/test-python-dependency-bootstrap.sh` — prove bootstrap behavior remains unchanged after resolver extraction.
- `scripts/test/test-stack-detection.sh` — pin the new Python build mapping.
- `scripts/test/test-delivery-workflows.sh` — require resolver-based single-stack artifact discovery.
- `scripts/test/test-monorepo-ci.sh` — require resolver-based component artifact discovery.
- `.github/workflows/build.yml` — package `<project-directory>/dist`.
- `.github/workflows/ci-monorepo.yml` — package the resolved Python component output.
- `Makefile` — include the new behavior contract in `make test-scripts`.
- `scripts/README.md` — document resolver and wrapper ownership.
- `docs/getting-started.md` — explain direct-`src/` build output.
- `docs/development/local-setup.md` — align dependency and build boundaries.
- `docs/development/artifact-conventions.md` — document root/direct-`src/` Python artifacts.
- `docs/plans/technical-debt.md` — close TD-0018 with evidence.
- `docs/superpowers/specs/2026-08-10-python-project-directory-build-design.md` — mark implemented after verification.
- `CHANGELOG.md` — record the fix under `Unreleased`.

---

### Task 1: Shared Python project-directory resolver

**Files:**

- Create: `scripts/resolve-python-project-dir.sh`
- Create: `scripts/test/test-python-project-build.sh`
- Modify: `scripts/setup-python-deps.sh`
- Modify: `scripts/test/test-python-dependency-bootstrap.sh`
- Modify: `Makefile`

**Interfaces:**

- Produces: `sh scripts/resolve-python-project-dir.sh` prints `.` or `src` and exits 0; invalid boundaries print diagnostics to stderr and exit 65.
- Consumes: current working directory and the five allowed manifest names from Global Constraints.
- Preserves: `scripts/setup-python-deps.sh` installation ordering, fallback pins, `PYTHON_BIN`, and existing exit-code propagation.

- [ ] **Step 1: Write the failing resolver behavior contract**

Create `scripts/test/test-python-project-build.sh` with the existing test harness and these literal cases:

```sh
#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-python-project-dir.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-python-build.XXXXXX")"
PROJECT="$WORK/project"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

reset_project() {
  rm -rf "$PROJECT"
  mkdir -p "$PROJECT"
}

run_resolver() {
  set +e
  RUN_OUTPUT="$(cd "$PROJECT" && sh "$RESOLVER" 2>&1)"
  RUN_STATUS=$?
  set -e
}

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

reset_project
: > "$PROJECT/pyproject.toml"
run_resolver
assert_eq "root project status" "$RUN_STATUS" "0"
assert_eq "root project directory" "$RUN_OUTPUT" "."

reset_project
mkdir -p "$PROJECT/src"
: > "$PROJECT/src/requirements-dev.txt"
run_resolver
assert_eq "src project status" "$RUN_STATUS" "0"
assert_eq "src project directory" "$RUN_OUTPUT" "src"

reset_project
: > "$PROJECT/setup.py"
mkdir -p "$PROJECT/src"
: > "$PROJECT/src/requirements.txt"
run_resolver
assert_eq "ambiguous project status" "$RUN_STATUS" "65"
assert_text_contains "ambiguous project guidance" "$RUN_OUTPUT" \
  'both the current directory and src/'

reset_project
run_resolver
assert_eq "missing project status" "$RUN_STATUS" "65"
assert_text_contains "missing project guidance" "$RUN_OUTPUT" \
  'No supported Python dependency manifest found'

report
```

- [ ] **Step 2: Add the new contract to the local gate**

Insert after the stack-detection contract in `Makefile`:

```make
	@sh scripts/test/test-python-project-build.sh
```

- [ ] **Step 3: Run the contract and verify RED**

Run:

```sh
sh scripts/test/test-python-project-build.sh
```

Expected: FAIL because `scripts/resolve-python-project-dir.sh` does not exist.

- [ ] **Step 4: Implement the minimal resolver**

Create `scripts/resolve-python-project-dir.sh`:

```sh
#!/usr/bin/env sh
set -eu

USAGE_ERROR=65

has_manifest() {
  directory="$1"
  [ -f "$directory/pyproject.toml" ] \
    || [ -f "$directory/setup.py" ] \
    || [ -f "$directory/requirements.txt" ] \
    || [ -f "$directory/requirements-dev.txt" ] \
    || [ -f "$directory/Pipfile" ]
}

root_has=false
src_has=false
has_manifest . && root_has=true
has_manifest src && src_has=true

if [ "$root_has" = true ] && [ "$src_has" = true ]; then
  printf '%s\n' \
    'Python dependency manifests exist in both the current directory and src/; keep one project boundary or use the explicit monorepo contract.' >&2
  exit "$USAGE_ERROR"
fi

if [ "$root_has" = true ]; then
  printf '%s\n' '.'
elif [ "$src_has" = true ]; then
  printf '%s\n' 'src'
else
  printf '%s\n' \
    'No supported Python dependency manifest found in the current directory or src/.' >&2
  exit "$USAGE_ERROR"
fi
```

Mark it executable.

- [ ] **Step 5: Refactor dependency bootstrap to consume the resolver**

In `scripts/setup-python-deps.sh`, replace its `has_manifest`, `root_has`,
`src_has`, and project-directory selection block with:

```sh
RESOLVER="$HERE/resolve-python-project-dir.sh"

if [ ! -x "$RESOLVER" ]; then
  printf 'Python project-directory resolver is unavailable: %s\n' "$RESOLVER" >&2
  exit "$USAGE_ERROR"
fi

project_dir="$(sh "$RESOLVER")"
```

Keep all installation branches below that block unchanged.

- [ ] **Step 6: Pin resolver delegation in the bootstrap contract**

Add these definitions and assertion to
`scripts/test/test-python-dependency-bootstrap.sh`:

```sh
RESOLVER="$ROOT/scripts/resolve-python-project-dir.sh"

if [ -x "$RESOLVER" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1))
  printf 'FAIL Python project-directory resolver is executable\n' >&2
fi
```

The existing root, direct-`src/`, ambiguous, missing, Pipfile, and installer
failure cases remain the behavioral regression coverage for bootstrap.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run:

```sh
sh scripts/test/test-python-project-build.sh
sh scripts/test/test-python-dependency-bootstrap.sh
```

Expected: both report zero failures; bootstrap keeps the existing install
arguments such as `-e .[dev]` and `-e src[dev]`.

- [ ] **Step 8: Commit the resolver slice**

```sh
git add Makefile scripts/resolve-python-project-dir.sh \
  scripts/setup-python-deps.sh \
  scripts/test/test-python-project-build.sh \
  scripts/test/test-python-dependency-bootstrap.sh
git commit -m "fix: share Python project-directory resolution"
```

---

### Task 2: Python build wrapper and mapper integration

**Files:**

- Create: `scripts/run-python-build.sh`
- Modify: `scripts/test/test-python-project-build.sh`
- Modify: `scripts/stack-tools.sh`
- Modify: `scripts/test/test-stack-detection.sh`

**Interfaces:**

- Consumes: `resolve-python-project-dir.sh`, `${PYTHON_BIN:-python}`, and a selected `pyproject.toml` or `setup.py`.
- Produces: build output under `<resolved-project-directory>/dist` or exits 65 before invoking a backend for a non-buildable boundary.
- Mapper output: `sh "<repository>/scripts/run-python-build.sh"` for `python:build`.

- [ ] **Step 1: Extend the behavior contract with failing build cases**

Append a fake Python executable and build runner to
`scripts/test/test-python-project-build.sh` before `report`:

```sh
BUILD_HELPER="$ROOT/scripts/run-python-build.sh"
BUILD_LOG="$WORK/build.log"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/python-build-fixture" <<'EOF'
#!/usr/bin/env sh
set -eu
printf 'cwd=%s args=%s\n' "$PWD" "$*" > "$BUILD_LOG"
mkdir -p dist
: > dist/fixture.whl
EOF
chmod +x "$WORK/bin/python-build-fixture"

run_build() {
  python_bin="$1"
  set +e
  RUN_OUTPUT="$({
    cd "$PROJECT" &&
      BUILD_LOG="$BUILD_LOG" PYTHON_BIN="$python_bin" sh "$BUILD_HELPER"
  } 2>&1)"
  RUN_STATUS=$?
  set -e
}

assert_file_contains() {
  label="$1"
  file="$2"
  pattern="$3"
  if [ -f "$file" ] && grep -Eq -- "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_file_exists() {
  label="$1"
  file="$2"
  if [ -f "$file" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing file: %s\n' "$label" "$file" >&2
  fi
}

reset_project
mkdir -p "$PROJECT/.venv/bin"
cp "$WORK/bin/python-build-fixture" "$PROJECT/.venv/bin/python"
: > "$PROJECT/pyproject.toml"
run_build '.venv/bin/python'
assert_eq "root build status" "$RUN_STATUS" "0"
assert_file_contains "root build cwd" "$BUILD_LOG" \
  "^cwd=$PROJECT args=-m build$"
assert_file_exists "root build output" "$PROJECT/dist/fixture.whl"

reset_project
mkdir -p "$PROJECT/src"
: > "$PROJECT/src/setup.py"
run_build "$WORK/bin/python-build-fixture"
assert_eq "src build status" "$RUN_STATUS" "0"
assert_file_contains "src build cwd" "$BUILD_LOG" \
  "^cwd=$PROJECT/src args=-m build$"
assert_file_exists "src build output" "$PROJECT/src/dist/fixture.whl"

reset_project
: > "$PROJECT/requirements.txt"
run_build "$WORK/bin/python-build-fixture"
assert_eq "requirements-only build status" "$RUN_STATUS" "65"
assert_text_contains "requirements-only build guidance" "$RUN_OUTPUT" \
  'requires pyproject.toml or setup.py'

reset_project
: > "$PROJECT/Pipfile"
run_build "$WORK/bin/python-build-fixture"
assert_eq "Pipfile-only build status" "$RUN_STATUS" "65"
assert_text_contains "Pipfile-only build guidance" "$RUN_OUTPUT" \
  'requires pyproject.toml or setup.py'
```

- [ ] **Step 2: Change the expected mapper contract and verify RED**

Change the Python build assertion in `scripts/test/test-stack-detection.sh` to:

```sh
assert_eq "python build" "$($TOOL build)" \
  "sh \"$ROOT/scripts/run-python-build.sh\""
```

Run:

```sh
sh scripts/test/test-python-project-build.sh
sh scripts/test/test-stack-detection.sh
```

Expected: FAIL because the wrapper is absent and the mapper still emits
`python -m build`.

- [ ] **Step 3: Implement the build wrapper**

Create `scripts/run-python-build.sh`:

```sh
#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="$HERE/resolve-python-project-dir.sh"
USAGE_ERROR=65
PYTHON_BIN="${PYTHON_BIN:-python}"

project_dir="$(sh "$RESOLVER")"
if [ ! -f "$project_dir/pyproject.toml" ] \
  && [ ! -f "$project_dir/setup.py" ]; then
  printf 'Python package build requires pyproject.toml or setup.py under %s.\n' \
    "$project_dir" >&2
  exit "$USAGE_ERROR"
fi

if ! python_exec="$(command -v "$PYTHON_BIN" 2>/dev/null)"; then
  printf 'Python build executable is unavailable: %s\n' "$PYTHON_BIN" >&2
  exit "$USAGE_ERROR"
fi

case "$python_exec" in
  /*) ;;
  *)
    python_exec="$(cd "$(dirname "$python_exec")" && pwd)/$(basename "$python_exec")"
    ;;
esac

(cd "$project_dir" && "$python_exec" -m build)
```

Mark it executable.

- [ ] **Step 4: Route the mapper to the wrapper**

Replace the Python build entry in `scripts/stack-tools.sh` with:

```sh
python:build) printf 'sh "%s/run-python-build.sh"\n' "$HERE" ;;
```

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```sh
sh scripts/test/test-python-project-build.sh
sh scripts/test/test-stack-detection.sh
```

Expected: all resolver, build cwd, output, error, and mapper assertions pass.

- [ ] **Step 6: Commit the build slice**

```sh
git add scripts/run-python-build.sh scripts/stack-tools.sh \
  scripts/test/test-python-project-build.sh \
  scripts/test/test-stack-detection.sh
git commit -m "fix: build Python from the resolved project directory"
```

---

### Task 3: Resolver-based artifact packaging

**Files:**

- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/ci-monorepo.yml`
- Modify: `scripts/test/test-delivery-workflows.sh`
- Modify: `scripts/test/test-monorepo-ci.sh`

**Interfaces:**

- Consumes: `sh scripts/resolve-python-project-dir.sh` in the repository root or `sh "$GITHUB_WORKSPACE/scripts/resolve-python-project-dir.sh"` from a component working directory.
- Produces: the existing deterministic tar archive from `<resolved-project-directory>/dist`.
- Preserves: `build-python`, `build-<component-id>`, uploaded filenames, metadata, workflow outputs, and attestation input identity.

- [ ] **Step 1: Add failing single-stack packaging contracts**

Add to `scripts/test/test-delivery-workflows.sh`:

```sh
assert_contains "Python packaging resolves project directory" "$BUILD" \
  'project_dir="[$][(]sh scripts/resolve-python-project-dir\.sh[)]"'
assert_contains "Python packaging selects resolved dist" "$BUILD" \
  'add_tree "[$]project_dir/dist"'
assert_not_contains "Python packaging does not hardcode root dist" "$BUILD" \
  'python[)] add_tree dist'
```

- [ ] **Step 2: Add failing monorepo packaging contracts**

Add to `scripts/test/test-monorepo-ci.sh`:

```sh
assert_contains "component Python packaging resolves project directory" "$MONO" \
  'project_dir="[$][(]sh "[$]GITHUB_WORKSPACE/scripts/resolve-python-project-dir\.sh"[)]"'
assert_contains "component Python packaging selects resolved dist" "$MONO" \
  'add_tree "[$]project_dir/dist"'
```

- [ ] **Step 3: Run structural contracts and verify RED**

Run:

```sh
sh scripts/test/test-delivery-workflows.sh
sh scripts/test/test-monorepo-ci.sh
```

Expected: new resolver-based artifact assertions fail; existing delivery and
monorepo assertions remain green.

- [ ] **Step 4: Update single-stack artifact discovery**

Replace the Python case in `.github/workflows/build.yml` with:

```bash
python)
  project_dir="$(sh scripts/resolve-python-project-dir.sh)"
  add_tree "$project_dir/dist"
  ;;
```

- [ ] **Step 5: Update component-aware artifact discovery**

Replace the Python case in `.github/workflows/ci-monorepo.yml` with:

```bash
python)
  project_dir="$(sh "$GITHUB_WORKSPACE/scripts/resolve-python-project-dir.sh")"
  add_tree "$project_dir/dist"
  ;;
```

Keep component metadata and deterministic tar creation unchanged.

- [ ] **Step 6: Run workflow contracts and syntax checks**

Run:

```sh
sh scripts/test/test-delivery-workflows.sh
sh scripts/test/test-monorepo-ci.sh
command -v actionlint >/dev/null 2>&1 && actionlint
```

Expected: both shell contracts pass. When actionlint is installed it exits 0;
when unavailable, record that the optional local syntax tool was skipped and
rely on the repository CI workflow for hosted validation.

- [ ] **Step 7: Commit the workflow slice**

```sh
git add .github/workflows/build.yml .github/workflows/ci-monorepo.yml \
  scripts/test/test-delivery-workflows.sh scripts/test/test-monorepo-ci.sh
git commit -m "fix: package resolved Python build artifacts"
```

---

### Task 4: Documentation, debt closure, and full verification

**Files:**

- Modify: `scripts/README.md`
- Modify: `docs/getting-started.md`
- Modify: `docs/development/local-setup.md`
- Modify: `docs/development/artifact-conventions.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `docs/superpowers/specs/2026-08-10-python-project-directory-build-design.md`
- Modify: `CHANGELOG.md`

**Interfaces:**

- Documents: root/direct-`src/` resolution, buildable manifests, output paths, explicit failure behavior, and unchanged artifact identity.
- Closes: TD-0018 only after all focused and repository-wide checks pass.
- Does not claim: hosted consumer verification, Java/.NET pilot results, deployment readiness, or profile activation.

- [ ] **Step 1: Update script reference with exact responsibilities**

Add rows to `scripts/README.md`:

```markdown
| `resolve-python-project-dir.sh` | Called by Python setup, build, and packaging paths | Selects exactly one Python dependency boundary from the current directory or direct `src/`; ambiguous and absent boundaries fail explicitly. |
| `run-python-build.sh` | Called by the Python build mapper | Requires a package build manifest, resolves the selected interpreter before changing directories, and builds from the shared project boundary. |
```

Update the `setup-python-deps.sh` row to state that it consumes the shared
resolver.

- [ ] **Step 2: Align consumer build and artifact guidance**

Document these exact statements in the relevant existing Python sections:

```text
A Python dependency boundary may be the repository root or direct src/, but not both.
Package builds additionally require pyproject.toml or setup.py at that boundary.
Root projects produce dist/; direct-src projects produce src/dist/.
The uploaded artifact name remains build-python in both layouts.
Pytest discovery remains consumer-owned and is independent of the build boundary.
```

- [ ] **Step 3: Record the fix and close TD-0018**

Under `CHANGELOG.md` → `Fixed`, add:

```markdown
- Unified root/direct-`src/` Python project resolution across dependency
  bootstrap, build execution, and artifact packaging; non-buildable and
  ambiguous boundaries now fail with explicit diagnostics.
```

Change TD-0018 status to `Closed 2026-08-10` and resolution to:

```text
A shared resolver now selects the root or direct-src Python boundary. The build wrapper executes from that boundary, and single-stack/component packaging archives its dist output with regression coverage.
```

Change the design spec status to `Implemented 2026-08-10` only after Step 5
succeeds.

- [ ] **Step 4: Run focused regression contracts**

Run:

```sh
sh scripts/test/test-python-project-build.sh
sh scripts/test/test-python-dependency-bootstrap.sh
sh scripts/test/test-stack-detection.sh
sh scripts/test/test-delivery-workflows.sh
sh scripts/test/test-monorepo-ci.sh
```

Expected: every contract reports zero failures.

- [ ] **Step 5: Run required repository gates**

Run:

```sh
make test-scripts
make docs-check
make ci
git diff --check
```

Expected:

- every shell assertion group reports zero failures;
- installed documentation/workflow/security tools report no errors;
- unavailable optional local tools are reported accurately as skipped;
- readiness remains contract-valid with `production_ready=false` for the empty
  template;
- `git diff --check` exits 0.

- [ ] **Step 6: Self-review the complete implementation diff**

Run:

```sh
git status --short
git diff --stat 958221e..HEAD
git diff 958221e..HEAD
```

Confirm every changed line maps to TD-0018, scripts contain no credential or
consumer command evaluation, workflow permissions and action pins are
unchanged, tests cover both boundaries and failure modes, and documentation
does not claim hosted validation that has not occurred.

- [ ] **Step 7: Commit documentation and debt closure**

```sh
git add CHANGELOG.md scripts/README.md docs/getting-started.md \
  docs/development/local-setup.md \
  docs/development/artifact-conventions.md \
  docs/plans/technical-debt.md \
  docs/superpowers/specs/2026-08-10-python-project-directory-build-design.md
git commit -m "docs: close Python project-directory build debt"
```

- [ ] **Step 8: Verify final branch state**

Run:

```sh
git status --short --branch
git log -5 --oneline
```

Expected: branch `fix/python-project-directory-build` has no uncommitted files
and contains the design, plan, resolver, wrapper, workflow, test, and
documentation commits. Push and PR creation remain a separate explicit user
action.
