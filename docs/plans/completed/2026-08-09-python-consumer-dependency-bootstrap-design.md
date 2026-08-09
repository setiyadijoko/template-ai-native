# Python Consumer Dependency Bootstrap Design

**Status:** Completed on 2026-08-09; hosted consumer revalidation remains external evidence.

## Problem

A real Python consumer created from this template could build a wheel, but its
hosted quality and test jobs failed before application checks ran. The reusable
workflows installed Ruff, mypy, pytest, pytest-cov, and build, but did not
install the consumer package or its runtime dependencies. FastAPI was therefore
unavailable to pytest and the Pydantic mypy plugin could not import Pydantic.

This breaks the documented single-stack Python adoption path. The same inline
tool-only setup also exists in component-aware Python jobs, so the fix must use
one dependency-bootstrap contract rather than repair only one workflow.

The pilot also exposed inconsistent coverage wording. The canonical policy is
unit coverage of at least 80%, and the mapper correctly evaluates
`tests/unit`. Documentation that calls this overall test-suite coverage is
incorrect; broadening the measured test scope is not part of this change.

## Decision

Add a focused POSIX-shell Python dependency bootstrap helper owned by the
template. Local `make setup` plus single-stack and component-aware quality,
test, and build jobs call the helper after Python setup and before mapper
commands.

The helper operates from the current project or component directory and:

1. locates a Python manifest in the current directory or its direct `src/`
   child, matching the single-stack detector boundary;
2. installs an editable project with its `dev` extra when a PEP 621
   `pyproject.toml` declares that extra;
3. otherwise installs the editable project plus template-owned, version-pinned
   fallback CI tools;
4. installs `requirements.txt` and `requirements-dev.txt` when that is the
   selected dependency format, then supplies only missing fallback CI tools;
5. supports editable `setup.py` projects with the same missing-tool fallback;
6. fails with an actionable error for a detected dependency format that cannot
   be installed safely, rather than reporting a misleading successful setup.

The helper does not add caching, select a package manager, alter coverage
thresholds, or activate profile-aware controls. Pipfile automation remains
outside this P0 because safely reproducing it requires a committed lockfile and
a separately governed Pipenv toolchain; a Pipfile-only consumer receives an
explicit unsupported-bootstrap error.

## Components

### Python bootstrap helper

`scripts/setup-python-deps.sh` is the single executable contract. It uses
`python -m pip`, never a bare `pip`, so installation targets the Python selected
by the workflow. Its current working directory is the project boundary: the
repository root for single-stack jobs and the component directory for monorepo
jobs.

`scripts/python-ci-tools.txt` contains exact fallback versions for Ruff, mypy,
pytest, pytest-cov, and build. Consumer-declared development dependencies take
precedence. The fallback is used only for tools that are not already
importable, avoiding an unnecessary override of a consumer's compatible tool
versions.

### Workflow integration

The existing check names, triggers, permissions, SHA-pinned Actions,
concurrency groups, mapper commands, and artifact behavior remain unchanged.
Only the duplicated Python installation steps are replaced with calls to the
shared helper. Local `make setup` calls the same helper for Python and preserves
the existing setup message for other detected stacks.

### Regression fixture

A checked-in single-stack Python fixture represents the reported failure:

- a PEP 621 package with runtime dependencies;
- a `dev` extra containing the CI tools;
- a Pydantic mypy plugin configuration;
- a minimal import-based test showing that runtime dependencies must be
  installed before hosted checks.

Shell tests exercise dependency-format selection without network access by
recording installer calls. Workflow contract tests ensure every supported
Python job calls the shared helper and no inline tool-only installation remains.

## Alternatives considered

### Duplicate `pip install -e '.[dev]'` in each workflow

Rejected. It duplicates policy across single-stack and component-aware jobs and
assumes every Python consumer defines a `dev` extra.

### Add an arbitrary install command to project configuration

Rejected for this P0. Executing consumer-configured shell text expands the
security surface and overlaps the deferred profile-aware architecture.

### Require one Python package manager only

Rejected. Mandating Poetry, uv, Pipenv, or another manager would violate the
template's stack-agnostic and consumer-owned dependency policy. The P0 supports
the existing pip-installable formats and fails explicitly outside that bounded
contract.

## Error handling and security

- Missing or ambiguous manifests fail before quality/test commands run.
- Installer failures propagate unchanged; the helper does not silently fall
  back after a real dependency-resolution error.
- No credentials, indexes, tokens, or trusted-host settings are generated.
- Workflow permissions remain read-only and fork behavior is unchanged.
- All shell paths are quoted, and no PR-controlled value is interpolated into
  executable workflow shell text.

## Acceptance criteria

1. The reported PEP 621 consumer contract installs its runtime and development
   dependencies before Python quality and tests.
2. Local setup plus single-stack and component-aware Python jobs use the same
   helper.
3. Empty templates and non-Python stacks retain their existing behavior.
4. Requirements-based and `setup.py` projects have deterministic tested
   bootstrap paths.
5. Pipfile-only projects fail with an actionable message instead of a false
   success.
6. Unit coverage remains at least 80% over `tests/unit`; user guidance uses the
   same terminology.
7. Fixture, workflow, shell, documentation, and security contracts pass.
8. The complete diff contains no profile-aware, deployment, or unrelated stack
   changes.

## Remaining compatibility boundary

The helper can install a Python dependency manifest directly under `src/`, but
the pre-existing build mapper still invokes `python -m build` from the current
working directory. Hosted packaging for a single-stack direct-`src/` manifest
is therefore not claimed by this change and is tracked as TD-0018. A nested
service that needs independently governed packaging should use an explicit
version-2 component path meanwhile.

## Rollback

Revert the helper, fallback-tool manifest, fixture, workflow calls, and
documentation together. The previous inline tool installation can be restored
without changing check names or artifact contracts, although doing so would
reintroduce the verified Python consumer failure.
