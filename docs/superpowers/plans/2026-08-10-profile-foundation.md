# Profile Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a credential-free, versioned maturity-profile contract that can be validated and reviewed without changing the current CI workflow behavior.

**Architecture:** A strict, line-oriented POSIX-shell validator will validate the small canonical YAML shape without adding a YAML runtime dependency. The template will ship a schema and a Standard example as documentation-only assets; existing repositories without `.template/profile.yaml` will exit successfully in compatibility mode. Starter/Standard/Enterprise control mappings and the deferred activation policy will be recorded in one ADR.

**Tech Stack:** POSIX `sh`, `awk`, `grep`, Markdown, YAML examples, repository shell-test harness.

## Global Constraints

- Do not add workflow conditions, rename check contexts, or change branch-protection behavior.
- Do not add credentials, provider settings, cloud resources, framework dependencies, or mutable Action references.
- Preserve no-config compatibility mode and current security defaults.
- Treat profile configuration as declarative foundation only until a later approved activation ADR.
- Follow the existing project-config validation style and `make test-scripts` contract.

---

### Task 1: Define the profile contract

**Files:**
- Create: `.template/profile.schema.yaml`
- Create: `.template/profile-controls.yaml`
- Create: `.template/profile.yaml.example`
- Test: `scripts/test/test-profile-config.sh`

**Interfaces:**
- Produces the canonical keys `version`, `profile`, `project`, `stack`, `ai`, `deployment`, and `controls`.
- Supported profiles are `starter`, `standard`, and `enterprise`.
- The example is documentation-only and is not copied into consumers automatically.

- [x] Write failing shell assertions for a valid Standard example, each profile value, missing-config compatibility, and rejection of unknown/credential keys.
- [x] Run `sh scripts/test/test-profile-config.sh` and confirm it fails because the validator and example do not exist.
- [x] Add the schema and credential-free Standard example with explicit allowed values and the declarative-only warning.
- [x] Run the focused test and confirm the fixture-level contract is ready for the validator.

### Task 2: Implement profile validation

**Files:**
- Create: `scripts/validate-profile-config.sh`
- Modify: `scripts/test/test-profile-config.sh`
- Modify: `Makefile`
- Modify: `scripts/README.md`

**Interfaces:**
- `sh scripts/validate-profile-config.sh [PATH]` validates the default `.template/profile.yaml` or an explicit path.
- Missing config prints a compatibility-mode message and exits `0`.
- Valid configs print `Profile config valid: PATH` and exit `0`; malformed, unsupported, duplicate, or credential-bearing configs exit non-zero.

- [x] Extend the failing tests to cover duplicate keys, missing required nested keys, invalid booleans/enums, malformed indentation, and unsafe scalar values.
- [x] Run the focused test and confirm each new assertion fails for the missing validator or expected invalid input.
- [x] Implement the smallest line-oriented validator using only POSIX shell utilities; reject unknown fields and credentials.
- [x] Run the focused test until all profile contract assertions pass (`passed=12 failed=0`).

### Task 3: Record mappings and activation boundaries

**Files:**
- Create: `docs/adr/0008-profile-foundation.md`
- Modify: `docs/adr/README.md`
- Modify: `README.md`
- Modify: `docs/plans/roadmap.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- The ADR documents profile control mappings, blocking/advisory/scheduled/manual policy, required-check compatibility, migration, and rollback.
- README explains how to validate an optional profile file and explicitly states that activation is deferred.
- Roadmap marks foundation as complete while keeping profile-aware workflow activation future work.

- [x] Add the ADR with the schema, mappings, no-config fallback, alternatives, security implications, and migration gate.
- [x] Update README and roadmap without claiming profile controls are active.
- [x] Add one Unreleased changelog entry referencing the validator and deferred activation.
- [x] Run documentation checks available in the repository; optional markdown/link/YAML tools were unavailable, while actionlint/gitleaks and the best-effort gate passed.

### Task 4: Full verification and diff review

**Files:**
- Verify all changed files; no additional implementation files are expected.

- [x] Run `sh scripts/test/test-profile-config.sh` (`passed=12 failed=0`).
- [x] Run `make test-scripts`, `make docs-check`, `make ci`, `git diff --check`, and `gitleaks detect --no-banner --redact --source .`; all executed gates passed, with optional documentation tools skipped.
- [x] Run `git diff` over the complete change and confirm no workflow, secret, or unrelated refactor was introduced.
- [x] Record remaining activation/deployment risks in ADR-0008 and the roadmap.
