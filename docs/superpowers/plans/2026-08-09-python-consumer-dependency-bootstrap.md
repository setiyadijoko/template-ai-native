# Python Consumer Dependency Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make supported Python consumers install their application and runtime
dependencies before inherited quality, test, and build commands run.

**Architecture:** Add one POSIX-shell Python bootstrap helper that runs from a
single-stack repository root or a monorepo component directory. It selects an
existing pip-installable dependency format, installs the consumer project, and
adds exact fallback CI tool versions only when their import modules remain
unavailable. All Python workflow jobs call the helper; mapper commands and
coverage policy remain unchanged.

**Tech Stack:** POSIX shell, Python 3.12 standard library, pip, GitHub Actions,
Make, shell contract tests.

## Global Constraints

- Preserve stack-agnostic empty-template behavior and version-1 compatibility.
- Preserve unit coverage of at least 80% over `tests/unit`.
- Preserve check names, triggers, least-privilege permissions, fork safety,
  concurrency groups, and immutable Action SHA pins.
- Do not add caching, profiles, deployment behavior, arbitrary consumer shell
  hooks, or another package manager.
- Use fallback pins `ruff==0.15.22`, `mypy==2.3.0`, `pytest==9.1.1`,
  `pytest-cov==7.1.0`, and `build==1.5.0` only when the matching import module is
  unavailable after consumer dependency installation.
- Pipfile-only consumers fail with an actionable unsupported-bootstrap error.

---

### Task 1: Define the Python bootstrap behavior with failing tests

**Files:**

- Create: `scripts/test/test-python-dependency-bootstrap.sh`
- Modify: `Makefile`

**Interfaces:**

- Consumes: a Python project boundary in the current working directory and
  optional `src/` child manifests.
- Produces: executable behavior expected from
  `scripts/setup-python-deps.sh`, with `PYTHON_BIN` available as a test-only and
  toolchain-selection override.

- [x] **Step 1: Write a fake Python wrapper used by the tests**

  In the test's temporary `bin/python-fixture`, intercept only
  `python -m pip ...`, append the exact arguments to `$PIP_LOG`, and otherwise
  delegate to `$REAL_PYTHON`. When `$FAKE_PROJECT_PROVIDES_TOOLS=1`, an editable
  install creates importable dummy modules under `$FAKE_SITE` for `ruff`,
  `mypy`, `pytest`, `pytest_cov`, and `build`.

- [x] **Step 2: Add behavior cases**

  Assert the missing helper causes the focused suite to fail, then cover:

  ```text
  root pyproject with dev extra -> editable .[dev], no fallback tools
  root pyproject without dev extra -> editable project, five missing fallbacks
  src/pyproject -> editable src project
  requirements.txt + requirements-dev.txt -> both installed in order
  setup.py -> editable project
  Pipfile only -> exit 65 and actionable message
  root and src manifests -> exit 65 as ambiguous
  no manifest -> exit 65
  pip failure -> original non-zero status propagates
  ```

- [x] **Step 3: Register the focused suite**

  Add `sh scripts/test/test-python-dependency-bootstrap.sh` to
  `make test-scripts` immediately after the stack detection suite.

- [x] **Step 4: Verify RED**

  Run:

  ```sh
  sh scripts/test/test-python-dependency-bootstrap.sh
  ```

  Expected: FAIL because `scripts/setup-python-deps.sh` and its fallback tool
  manifest do not exist.

### Task 2: Implement the minimal dependency bootstrap helper

**Files:**

- Create: `scripts/setup-python-deps.sh`
- Create: `scripts/python-ci-tools.txt`
- Modify: `scripts/README.md`
- Test: `scripts/test/test-python-dependency-bootstrap.sh`

**Interfaces:**

- Consumes: `PYTHON_BIN` or `python`, the current project directory, and
  `scripts/python-ci-tools.txt` lines in `distribution==version|module` format.
- Produces: installed consumer dependencies and required CI tools, or exit 65
  for unsupported/ambiguous input; dependency installer failures propagate.

- [x] **Step 1: Add the exact fallback tool manifest**

  Write:

  ```text
  ruff==0.15.22|ruff
  mypy==2.3.0|mypy
  pytest==9.1.1|pytest
  pytest-cov==7.1.0|pytest_cov
  build==1.5.0|build
  ```

- [x] **Step 2: Implement project-boundary selection**

  Treat `pyproject.toml`, `setup.py`, `requirements.txt`,
  `requirements-dev.txt`, and `Pipfile` as Python dependency manifests. Select
  the current directory when it contains any; otherwise select direct `src/`.
  Fail with exit 65 when both boundaries contain manifests or neither does.

- [x] **Step 3: Implement dependency-format installation**

  Use `"$PYTHON_BIN" -m pip install` throughout. For `pyproject.toml`, use
  Python `tomllib` to detect `project.optional-dependencies.dev`, then install
  `-e "$project_dir[dev]"` or `-e "$project_dir"`. Prefer pyproject over
  setup.py and requirements files in the same boundary; setup.py is editable;
  requirements files install runtime first and development second. A Pipfile
  with no pip-installable manifest exits 65 with guidance to adopt a locked,
  reviewed install contract.

- [x] **Step 4: Install only missing fallback tools**

  For each manifest line, use `importlib.util.find_spec(module)`. Install the
  exact distribution pin only when the module cannot be found. Invalid fallback
  lines fail closed with exit 65.

- [x] **Step 5: Verify GREEN and document the helper**

  Run:

  ```sh
  sh scripts/test/test-python-dependency-bootstrap.sh
  sh scripts/test/test-stack-detection.sh
  ```

  Expected: both suites exit 0. Add the helper and fallback manifest ownership
  to `scripts/README.md`.

### Task 3: Route every Python workflow job through the helper

**Files:**

- Modify: `.github/workflows/ci-quality.yml`
- Modify: `.github/workflows/ci-test.yml`
- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/ci-monorepo.yml`
- Modify: `scripts/test/test-monorepo-ci.sh`
- Modify: `scripts/test/test-delivery-workflows.sh`
- Test: `scripts/test/test-python-dependency-bootstrap.sh`

**Interfaces:**

- Consumes: `scripts/setup-python-deps.sh` from a checked-out repository and
  each job's existing Python 3.12 setup.
- Produces: project dependencies available after local Python setup and before
  all mapper-based Python quality, test, and build commands.

- [x] **Step 1: Add failing workflow contracts**

  Assert all three single-stack Python jobs call:

  ```sh
  sh scripts/setup-python-deps.sh
  ```

  Assert all three component-aware jobs call:

  ```sh
  sh "$GITHUB_WORKSPACE/scripts/setup-python-deps.sh"
  ```

  Also assert the four workflow files contain no inline
  `pip install ruff mypy pytest pytest-cov build` command.

- [x] **Step 2: Verify RED**

  Run:

  ```sh
  sh scripts/test/test-monorepo-ci.sh
  sh scripts/test/test-delivery-workflows.sh
  ```

  Expected: the new helper-call contracts fail against the inline installation
  steps.

- [x] **Step 3: Replace the duplicated workflow steps**

  Keep every job-level `if`, name, permission, timeout, and working directory.
  Replace only the Python dependency command. Component jobs continue running
  from `${{ matrix.component.path }}` while resolving the helper through
  `$GITHUB_WORKSPACE`.

  Route local `make setup` through the same helper only when the detected stack
  is Python; preserve the existing setup message for other stacks.

- [x] **Step 4: Verify GREEN and workflow security**

  Run:

  ```sh
  sh scripts/test/test-monorepo-ci.sh
  sh scripts/test/test-delivery-workflows.sh
  sh scripts/test/test-security-workflows.sh
  ```

  Expected: all suites exit 0 with existing workflow security contracts intact.

### Task 4: Add the real Python consumer regression and synchronize guidance

**Files:**

- Create: `tests/fixtures/consumer-python/pyproject.toml`
- Create: `tests/fixtures/consumer-python/src/example_service/__init__.py`
- Create: `tests/fixtures/consumer-python/tests/unit/test_runtime_dependency.py`
- Modify: `scripts/test/test-consumer-regressions.sh`
- Modify: `docs/getting-started.md`
- Modify: `docs/development/local-setup.md`
- Modify: `docs/development/version-pinning.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`
- Archived after verification:
  `docs/plans/completed/2026-08-09-python-consumer-dependency-bootstrap-design.md`

**Interfaces:**

- Consumes: the inherited PEP 621 `[project]` and
  `[project.optional-dependencies].dev` contract.
- Produces: a checked-in fixture that structurally reproduces the FastAPI and
  Pydantic mypy dependency boundary without adding Python dependencies to the
  template root.

- [x] **Step 1: Add fixture assertions first**

  Require the fixture to declare Python 3.12, FastAPI and Pydantic runtime
  dependencies, the `pydantic.mypy` plugin, and all five CI tools in a `dev`
  extra. Require its unit test to import FastAPI and Pydantic so a tool-only
  environment cannot execute collection successfully.

- [x] **Step 2: Verify RED**

  Run:

  ```sh
  sh scripts/test/test-consumer-regressions.sh
  ```

  Expected: FAIL because the Python consumer fixture does not exist.

- [x] **Step 3: Add the minimal fixture**

  Define package `template-python-consumer-fixture` with source package
  `example_service`. The source exports a Pydantic `HealthResponse`; the test
  constructs a FastAPI app, registers `/health`, and verifies the response model
  value without network access.

- [x] **Step 4: Align documentation and debt tracking**

  Document the supported Python bootstrap formats, consumer-first tooling,
  fallback pins, Pipfile boundary, and lack of default pip caching. Change
  “overall coverage” in the beginner guide to “unit coverage”. Record Pipenv
  and lockfile-specific cache activation as deferred consumer decisions, not a
  delivered capability. Add an Unreleased changelog entry.

- [x] **Step 5: Verify the fixture contract**

  Run:

  ```sh
  sh scripts/test/test-consumer-regressions.sh
  make test-scripts
  ```

  Expected: both commands exit 0.

### Task 5: Complete repository verification and diff review

**Files:**

- Modify: this plan's checkboxes as execution evidence.
- Review: every changed file.

**Interfaces:**

- Consumes: all implementation and documentation from Tasks 1–4.
- Produces: a reviewable branch with local evidence and explicit hosted-runner
  validation remaining after push.

- [x] **Step 1: Run repository-native checks**

  ```sh
  make test-scripts
  make docs-check
  make ci
  git diff --check
  ```

- [x] **Step 2: Run workflow syntax and security tooling when installed**

  ```sh
  command -v actionlint >/dev/null 2>&1 && actionlint .github/workflows/*.yml
  command -v zizmor >/dev/null 2>&1 && zizmor --pedantic .github/workflows/ci-quality.yml .github/workflows/ci-test.yml .github/workflows/build.yml .github/workflows/ci-monorepo.yml
  ```

  Record unavailable optional tools as unavailable; do not claim they passed.

- [x] **Step 3: Review the complete diff**

  Confirm no secret, temporary fixture output, unrelated formatting,
  profile-aware behavior, deployment change, mutable Action reference, check
  rename, or coverage-policy change is present.

- [x] **Step 4: Archive the approved design and report remote boundary**

  Move the active design to completed only after local verification succeeds.
  Hosted proof remains the rebased Service Desk Triage Pilot PR followed by
  post-merge artifact attestation; local tests cannot claim those outcomes.
