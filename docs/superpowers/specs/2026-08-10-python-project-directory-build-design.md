# Python Project-Directory Build Design

**Status:** Approved
**Date:** 2026-08-10
**Owner:** Project owner (@setiyadijoko)
**Tracks:** TD-0018

## Problem

Single-stack detection and Python dependency bootstrap accept a project manifest
in either the repository root or its direct `src/` directory. The build mapper,
however, always runs `python -m build` from the current directory, and the
single-stack artifact step only searches `dist/`.

A consumer with `src/pyproject.toml` can therefore be detected and installed
successfully but fail during build or artifact packaging. This makes the
documented direct-`src/` boundary internally inconsistent.

## Decision

Introduce one POSIX-shell resolver for the Python project directory and use it
for dependency bootstrap, build execution, and artifact discovery.

The resolver prints exactly one relative path:

- `.` when a supported Python manifest exists in the current directory;
- `src` when a supported Python manifest exists directly under `src/`.

It fails explicitly when neither or both locations contain supported manifests.
Recursive discovery remains prohibited. A deeper service must use the explicit
version-2 monorepo component contract.

Python tests remain consumer-owned. Their location and discovery continue to be
controlled by pytest configuration; the resolver does not move tests or infer a
test directory.

## Components

### Project-directory resolver

Add `scripts/resolve-python-project-dir.sh` as the single boundary resolver.
It recognizes the same dependency manifests already supported by bootstrap:

- `pyproject.toml`;
- `setup.py`;
- `requirements.txt`;
- `requirements-dev.txt`;
- `Pipfile`.

The script has no network access, does not modify files, and writes only the
resolved directory to stdout. Diagnostics go to stderr. Invalid or ambiguous
boundaries exit with usage error code 65.

### Dependency bootstrap

Refactor `scripts/setup-python-deps.sh` to call the resolver instead of owning a
second copy of root-versus-`src/` detection. Installation behavior remains
unchanged:

- PEP 621 projects use editable installation and the `dev` extra when declared;
- `setup.py` projects use editable installation;
- requirements files are installed in their existing order;
- Pipfile-only projects fail with the existing governed-toolchain guidance;
- missing CI tools use the repository-controlled exact fallback pins.

### Build wrapper

Add `scripts/run-python-build.sh`. It resolves the project directory, verifies
that the selected boundary contains `pyproject.toml` or `setup.py`, changes to
that directory, and runs:

```sh
${PYTHON_BIN:-python} -m build
```

The wrapper resolves the selected executable to an absolute path before
changing directories, so a consumer-provided virtual-environment path remains
valid from either boundary.

Requirements-only and Pipfile-only consumers remain valid dependency
boundaries, but they are not package build contracts. The wrapper fails with an
explicit diagnostic rather than relying on an opaque backend error.

The Python `build` entry in `scripts/stack-tools.sh` delegates to this wrapper.
Other stack commands remain unchanged.

### Artifact discovery

The Python packaging branches in `.github/workflows/build.yml` and
`.github/workflows/ci-monorepo.yml` call the same resolver and add
`<project-directory>/dist` to the archive inputs.

The artifact name, archive name, deterministic tar options, upload behavior,
workflow outputs, check names, and attestation handoff remain unchanged. Build
output is not copied from `src/dist/` into the repository root.

## Execution flow

For a single-stack consumer:

1. stack detection identifies Python from a root or direct-`src/` manifest;
2. dependency bootstrap resolves and installs the selected project;
3. the stack mapper invokes the Python build wrapper;
4. the wrapper builds from the same selected project directory;
5. artifact packaging resolves that directory again and archives its `dist/`;
6. the existing upload and same-run attestation flow continues unchanged.

For a version-2 monorepo, the component working directory remains the outer
boundary. The same resolver may select that component root or its direct `src/`
child. It never searches sibling or nested components.

## Error behavior

The following conditions fail closed:

- manifests in both the current directory and `src/`;
- no supported Python dependency manifest;
- a selected boundary without `pyproject.toml` or `setup.py` at build time;
- a successful build that produces no files under the selected `dist/`;
- a packaging step that resolves a different or invalid boundary.

Messages identify the boundary problem without printing credentials,
environment contents, or consumer source.

## Compatibility and security

- Existing root Python projects keep the same effective build command and
  `dist/` artifact contents.
- Empty templates and non-Python stacks retain existing behavior.
- Stable workflow names, job names, artifact names, and branch-protection check
  contexts do not change.
- No consumer-provided command string is evaluated.
- `PYTHON_BIN` remains the only executable override and is already part of the
  Python bootstrap contract.
- No new GitHub Action or external dependency is introduced.
- Least-privilege workflow permissions and the attestation trust boundary are
  unchanged.

## Testing strategy

Add executable shell contracts covering:

1. root manifest resolves to `.`;
2. direct-`src/` manifest resolves to `src`;
3. simultaneous root and `src/` manifests exit 65;
4. an absent manifest exits 65;
5. dependency bootstrap uses the shared resolver without changing install
   behavior;
6. the build wrapper runs the selected Python executable from the resolved
   directory;
7. requirements-only and Pipfile-only boundaries fail explicitly for build;
8. the stack mapper delegates Python build to the wrapper;
9. single-stack packaging resolves `dist/` or `src/dist/` without renaming the
   uploaded artifact;
10. component-aware packaging uses the same resolver from the component working
    directory;
11. existing stack detection, Python bootstrap, monorepo, and delivery workflow
    contracts continue to pass.

Verification before completion:

```sh
make test-scripts
make docs-check
make ci
```

The complete diff must also pass `git diff --check` and contain no unrelated
workflow, dependency, profile, deployment, or stack changes.

## Documentation changes

Update:

- `scripts/README.md` with the resolver and build-wrapper contracts;
- Python build guidance where root/direct-`src/` boundaries are described;
- `CHANGELOG.md` under `Unreleased`;
- TD-0018 after all implementation and regression checks pass.

## Out of scope

- recursive Python project discovery;
- profile-aware workflow activation;
- Pipenv automation;
- Python caching or lockfile policy changes;
- changing pytest discovery or coverage thresholds;
- Java, .NET, Node.js, or Go mapper changes;
- deployment, smoke-test, or production-readiness activation;
- renaming build artifacts or changing provenance policy.

## Acceptance criteria

1. Root and direct-`src/` Python projects use one deterministic resolver.
2. Dependency installation and build execution select the same boundary.
3. A direct-`src/` build is executed from `src/` and packaged from `src/dist/`.
4. Root Python behavior remains backward-compatible.
5. Ambiguous, absent, and non-buildable boundaries fail with actionable errors.
6. Single-stack and component-aware build paths share the same contracts.
7. Artifact identity, deterministic packaging, and same-run attestation inputs
   remain unchanged.
8. Required local verification passes with no unrelated changes.

## Rollback

Revert the resolver, wrapper, mapper, workflow packaging, tests, and associated
documentation as one coherent change. Existing root-project behavior can then
return to the previous direct `python -m build` command without data migration
or external-state cleanup.
