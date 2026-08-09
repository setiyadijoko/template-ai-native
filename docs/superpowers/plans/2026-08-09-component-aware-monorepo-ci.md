# Component-Aware Monorepo CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let an explicitly configured monorepo validate and run stack-aware CI per component without recursive manifest guessing or changing existing single-stack behavior.

**Architecture:** Version 2 of `.template/project.yaml` adds a validated `components` list. `scripts/resolve-components.sh` turns that list into safe TSV/JSON consumed by a reusable monorepo workflow. The dispatcher keeps version-1/single-stack compatibility and calls a separate component workflow only for a validated version-2 monorepo; the workflow publishes stable aggregate, quality, test, build, and per-component artifact checks.

**Tech Stack:** POSIX shell, YAML/GitHub Actions, existing stack mapper, SHA-pinned official Actions, shell contract tests.

**Status:** Implementation complete on `feat/component-aware-monorepo-ci`; the
consumer pilot and blocking branch-protection decision remain deferred.

## Global Constraints

- Do not recursively discover or select the first nested manifest.
- Preserve version-1 configs, no-config compatibility mode, existing single-stack workflows, SHA pinning, least privilege, and `pull_request` fork safety.
- Do not change branch protection contexts in this change.
- Component paths, IDs, stacks, required flags, and artifact names are credential-free and validated before workflow execution.
- Monorepo component jobs are advisory until a consumer pilot proves stable names, cost, and fork behavior.
- Use explicit component working directories; never add a root-level manifest symlink as a workaround.
- Add tests before implementation and run the repository-native checks before reporting completion.

---

### Task 1: Record the MangaHub pilot and approve the v2 contract

**Files:**
- Modify: `docs/adr/0007-component-aware-monorepo-ci-contract.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`
- Test: `scripts/test/test-project-config.sh`

**Interfaces:**
- Consumes: the existing proposed ADR-0007 and the merged MangaHub component-CI pilot.
- Produces: an accepted v2 component contract that later validator and workflow changes implement.

- [x] **Step 1: Add failing v2 contract assertions**

Add a temporary fixture to `scripts/test/test-project-config.sh` containing:

```yaml
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: src/backend
    stack: go
    required: true
    artifact: backend
  - id: frontend
    path: src/frontend
    stack: node
    required: true
    artifact: frontend
```

Assert that the validator accepts it and that the resolver emits both component IDs, paths, stacks, and artifacts.

- [x] **Step 2: Run the focused test and confirm RED**

Run:

```sh
sh scripts/test/test-project-config.sh
```

Expected: the new v2 assertions fail because version 2 and component resolution do not exist yet.

- [x] **Step 3: Update ADR-0007 with pilot evidence**

Change the status to `Accepted — implementation staged` and record that MangaHub required explicit backend/frontend working directories, a consumer-owned workflow while the template remained `unknown`, and no root-level symlink. Preserve the rejected recursive-discovery alternative.

- [x] **Step 4: Update technical debt and changelog**

Change TD-0016 from an unvalidated open proposal to an implementation-ready item tied to the accepted v2 contract. Add one `Unreleased` changelog entry describing explicit component-aware CI without claiming that profile-aware controls or production deployment are implemented.

- [x] **Step 5: Re-run the focused test and stage the documentation contract**

The test remains RED until Task 2; commit only after Task 2 makes it GREEN.

### Task 2: Implement and test the v2 component resolver

**Files:**
- Create: `scripts/resolve-components.sh`
- Modify: `scripts/validate-project-config.sh`
- Modify: `scripts/test/test-project-config.sh`
- Modify: `scripts/test/test-stack-detection.sh`
- Modify: `scripts/README.md`

**Interfaces:**
- Consumes: `.template/project.yaml` version 2.
- Produces: `sh scripts/resolve-components.sh --validate`, `--tsv`, `--json`, and `--layout`.

- [x] **Step 1: Add RED cases**

Cover these cases in shell tests:

```text
valid Go + Node components -> accepted
--tsv -> backend<TAB>src/backend<TAB>go<TAB>true<TAB>backend and frontend row
--json -> JSON array with the same five fields
duplicate component id -> rejected
unsafe path containing .. -> rejected
unsupported component stack -> rejected
missing required field -> rejected
duplicate artifact -> rejected
version 1 monorepo -> remains accepted by the old validator but resolver reports that v2 components are required
```

- [x] **Step 2: Run the focused tests and confirm RED**

Run:

```sh
sh scripts/test/test-project-config.sh
sh scripts/test/test-stack-detection.sh
```

Expected: the new resolver assertions fail with command-not-found or unsupported-version output.

- [x] **Step 3: Implement the minimal resolver**

Parse only the documented top-level keys and component fields with POSIX `awk`/shell. Enforce a maximum of 32 components, safe repository-relative paths, concrete supported stacks, boolean `required`, unique IDs, unique artifacts, and one occurrence of every field. Emit JSON only from validated characters so no shell or JSON injection is possible.

- [x] **Step 4: Extend project validation**

Keep version 1 behavior unchanged. For version 2 require `layout: monorepo`, `primary_stack: auto`, a non-root `primary_path`, and delegate component validation to the resolver. Continue rejecting secret-like keys and unsafe paths.

- [x] **Step 5: Make stack detection fail safe with a precise message**

Keep `unknown` for monorepos until the dispatcher calls the new resolver, but include the config path and the command needed to validate components. Do not inspect nested manifests.

- [x] **Step 6: Update script documentation and run GREEN tests**

Run the focused tests again and confirm all new assertions pass. Add the resolver to `scripts/README.md` and `make test-scripts`.

### Task 3: Add the reusable component-aware workflow and dispatcher routing

**Files:**
- Create: `.github/workflows/ci-monorepo.yml`
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/test/test-delivery-workflows.sh`
- Create: `scripts/test/test-monorepo-ci.sh`

**Interfaces:**
- Consumes: resolver JSON, existing stack mapper, and version-2 project config.
- Produces: stable checks `monorepo / aggregate`, `monorepo / quality / <id>`, `monorepo / test / <id>`, `monorepo / build / <id>`, and artifacts `build-<id>`.

- [x] **Step 1: Add workflow contract tests before YAML changes**

Assert that the dispatcher references the reusable monorepo workflow, the reusable workflow validates the config before matrix fan-out, all run steps use component working directories, all third-party actions are immutable SHAs, permissions remain least-privilege, and no `pull_request_target` is introduced.

- [x] **Step 2: Run the workflow contract test and confirm RED**

Run:

```sh
sh scripts/test/test-monorepo-ci.sh
```

Expected: it fails because the workflow and dispatcher routing do not exist.

- [x] **Step 3: Implement resolver and aggregate jobs**

The reusable workflow checks out once per job, validates the config, writes resolver JSON to `GITHUB_OUTPUT`, fans out only from validated components, and always runs an aggregate job. The aggregate reports component job results and fails when a required component fails; it remains visible even when a component list is empty or a path filter would otherwise skip work.

- [x] **Step 4: Implement quality, test, and build matrices**

Use the existing stack setup actions and mapper commands with `working-directory: ${{ matrix.component.path }}`. Support Python, Node, Go, Java, and .NET. Build uploads a deterministic `build-<id>` tarball containing the component output plus a metadata file with commit, component ID, path, and stack. Do not add deployment or provider secrets.

- [x] **Step 5: Route only validated v2 monorepos from `ci.yml`**

The existing detect job exposes layout. Single-stack and unknown/no-config paths keep their current jobs. A valid v2 monorepo calls `ci-monorepo.yml`; an invalid v2 config fails in the resolver rather than silently becoming green.

- [x] **Step 6: Run the workflow contract test and inspect the complete diff**

Run the new test plus the existing delivery/security tests. Confirm no required existing check context is renamed and no workflow runs with write permissions on fork code.

### Task 4: Verify the P0 slice and document migration boundaries

**Files:**
- Modify: `README.md`
- Modify: `docs/adr/0006-explicit-project-layout.md`
- Modify: `docs/plans/roadmap.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `scripts/README.md`

**Interfaces:**
- Consumes: the accepted v2 config and reusable workflow.
- Produces: consumer migration guidance without changing branch protection or profile-aware behavior.

- [x] **Step 1: Document the consumer config and migration**

Show a complete Go + Node example, explain that version 1 remains compatible, state that version 2 requires explicit components, and explain that component checks are advisory until a pilot confirms cost and check stability.

- [x] **Step 2: Add repository-native verification**

Run:

```sh
make test-scripts
make project-config-check
make docs-check
make ci
git diff --check
```

Run shell syntax checks and workflow security/syntax tools when installed. Record skipped optional tools truthfully.

- [x] **Step 3: Review acceptance criteria**

Confirm version-1/single-stack behavior, explicit v2 component validation, stable aggregate/component names, artifact ownership, fork safety, SHA pinning, no secrets, no branch-protection changes, and no profile-aware implementation.

- [ ] **Step 4: Commit the coherent P0 slice**

```sh
git add scripts .github/workflows docs/adr docs/plans README.md CHANGELOG.md
git commit -m "feat: add component-aware monorepo CI contract"
```
