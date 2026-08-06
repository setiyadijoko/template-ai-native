# Design Spec — Phase 2: Code-quality baseline

**Status:** Approved
**Date:** 2026-08-06
**Owner:** Project owner (@setiyadijoko)
**Builds on:** Phase 1 (repository governance, merged at `cd785fd`; PR #2 dependabot update merged at `8bf6339`)

---

## 1. Goal

Add the Level-2 code-quality baseline to `template-ai-native`: a dispatcher + three reusable workflows that detect the consumer's stack and run formatter-check, linter, type checker, tests (unit/integration/e2e), coverage gate, and build — blocking when a tool is present, no-oping cleanly when the stack is unknown (empty template).

## 2. Key decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Stack scope | Multi-language auto-detect (python/node/go/java/dotnet) | Honors the template's stack-agnostic promise; every consumer gets working CI |
| 2 | Trigger model | Dispatcher (`ci.yml`) calls reusable workflows (`workflow_call`) | One place to change triggers; reusable workflows stay pure |
| 3 | Coverage gate | Block when a coverage tool is present, skip silently otherwise | Strict when measurable, lenient when nothing to measure |
| 4 | Coverage threshold | 80% overall (`fail-under=80`) now; defer 90% critical-module + 90% changed-lines to Codecov later | 90% thresholds need a coverage service; recorded as technical debt |
| 5 | Script testing | Yes — shell tests for `stack-tools.sh` + `detect-stack.sh` | They are the only real code in Phase 2; cheap regression protection |
| 6 | Tool installation | CI installs toolchains via `setup-*` actions; local dev assumes tools present (graceful skip if not) | Keeps CI reproducible; preserves no-op-friendly local UX |
| 7 | Third-party action pinning | All `uses:` pinned to commit SHA resolved via `gh api` at implementation time | Phase-1 lesson: never trust recalled SHAs |

## 3. Per-stack tool map

Single source of truth = `scripts/stack-tools.sh`. Each action prints the command(s) to run for the detected stack, or `no-op` if unknown.

| action | python | node | go | java (maven) | dotnet |
|---|---|---|---|---|---|
| format | `ruff format .` | `prettier --write .` | `gofmt -w .` | `mvn -q spotless:apply` | `dotnet format` |
| format-check | `ruff format --check .` | `prettier --check .` | `gofmt -l .` | `mvn -q spotless:check` | `dotnet format --verify-no-changes` |
| lint | `ruff check .` | `eslint .` | `golangci-lint run` | `mvn -q checkstyle:check` | `dotnet format --verify-no-changes` (built-in analyzers) |
| typecheck | `mypy src` | `tsc --noEmit` | `go vet ./...` | (compiler, via `mvn -q compile`) | (compiler, via `dotnet build`) |
| test-unit | `pytest -q tests/unit` | `vitest run --dir tests/unit` | `go test -short ./...` | `mvn -q test` | `dotnet test --filter Category=Unit` |
| test-integration | `pytest -q tests/integration` | `vitest run --dir tests/integration` | `go test -run Integration ./...` | `mvn -q verify -Dtest='*IT'` | `dotnet test --filter Category=Integration` |
| test-e2e | `pytest -q tests/e2e` | `vitest run --dir tests/e2e` | `go test -run E2E ./...` | `mvn -q verify -Dtest='*E2E'` | `dotnet test --filter Category=E2E` |
| coverage | `pytest --cov=src --cov-report=xml --cov-report=term --cov-fail-under=80 tests/unit` | `vitest run --coverage --coverage.thresholds.lines=80` | `go test -coverprofile=coverage.out -covermode=atomic ./...` (>=80% enforced by a follow-up step) | `mvn -q verify -Pcoverage` (jacoco `min=0.80`) | `dotnet test --collect:"XPlat Code Coverage" /p:CoverletOutputFormat=cobertura` |
| build | `python -m build` | `npm run build` | `go build -o bin/ ./...` | `mvn -q -DskipTests package` | `dotnet build -c Release` |

Notes:
- Consumers may swap any tool via an ADR + Makefile/workflow override.
- For stacks where the type-checker is the compiler (go/java/dotnet), the typecheck action delegates to the build/compile step.
- Go has no native `--cov-fail-under`; the coverage action emits the profile and a small follow-up step computes the percentage and fails if <80.

## 4. File structure

```text
.github/workflows/
├── ci.yml                 # NEW — dispatcher (PR/push → detect → call reusable)
├── ci-quality.yml         # NEW — reusable: format-check + lint + typecheck + unit
├── ci-test.yml            # NEW — reusable: integration + e2e + coverage gate
└── build.yml              # NEW — reusable: build artifact

scripts/
├── stack-tools.sh         # NEW — stack → tool command mapping (single source of truth)
└── test/
    └── test-stack-detection.sh   # NEW — shell tests for detect-stack + stack-tools
```

Modified existing files: `Makefile`, `scripts/ci-local.sh`, `AGENTS.md` (cross-ref), `docs/development/testing-strategy.md` (cross-ref + coverage deferral note), `CHANGELOG.md`.

## 5. Workflow design

### 5.1 `ci.yml` (dispatcher)

- **Triggers:** `pull_request` (branches `[main]`), `push` (branches `[main]`), `workflow_dispatch`.
- **Permissions:** `contents: read`.
- **Concurrency:** `${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true`.
- **Jobs:**
  - `detect` (ubuntu-latest): checkout, run `scripts/detect-stack.sh` → output `stack`; also compute `has-src` (true if `src/` contains any non-`.gitkeep` file) so an empty template short-circuits cleanly.
  - `quality`, `test`, `build`: `needs: detect`, `if: needs.detect.outputs.stack != 'unknown'`, `uses: ./.github/workflows/<reusable>.yml`, `with: { stack: ... }`.
- When `stack == unknown`, all three downstream jobs skip → the dispatcher is green with no noise. Once a consumer adds a manifest file, everything activates automatically.

### 5.2 `ci-quality.yml` (reusable)

- **Triggers:** `workflow_call` with input `stack` (string); `workflow_dispatch`.
- **Permissions:** `contents: read`.
- **Job `quality`** (ubuntu-latest, timeout 15m):
  1. checkout (pinned SHA)
  2. setup toolchain by `stack` (matrix of `if:` steps using `setup-python`/`setup-node`/`setup-go`/`setup-java`/`setup-dotnet` — all SHA-pinned)
  3. install dev deps (e.g. python: `pip install ruff mypy pytest pytest-cov build`; node: `npm ci`; etc.)
  4. `format-check` via `stack-tools.sh format-check` (fail on unformatted)
  5. `lint` via `stack-tools.sh lint`
  6. `typecheck` via `stack-tools.sh typecheck`
  7. `test-unit` via `stack-tools.sh test-unit`

### 5.3 `ci-test.yml` (reusable)

- **Triggers:** `workflow_call` with input `stack`; `workflow_dispatch`.
- **Permissions:** `contents: read`.
- **Job `test`** (ubuntu-latest, timeout 25m):
  1. checkout + setup toolchain + dev deps (same setup block)
  2. `test-integration` via `stack-tools.sh test-integration`
  3. `test-e2e` via `stack-tools.sh test-e2e`
  4. `coverage` via `stack-tools.sh coverage` — fails if overall coverage < 80%. Uploads coverage report (`coverage.xml`/`coverage.out`/`cobertura.xml`) as an artifact for later Codecov wiring.

### 5.4 `build.yml` (reusable)

- **Triggers:** `workflow_call` with input `stack`; `workflow_dispatch`.
- **Permissions:** `contents: read`.
- **Job `build`** (ubuntu-latest, timeout 15m):
  1. checkout + setup toolchain
  2. `build` via `stack-tools.sh build`
  3. upload build artifact: a step that checks for the per-stack output directory (`dist/` for node/python, `bin/` for go, `target/*.jar` for java, `*.nupkg`+`bin/` for dotnet) and uploads it via `actions/upload-artifact` if present; if the directory does not exist after build, the step uses `if: hashFiles(...)` to skip cleanly (no failure).

## 6. `scripts/stack-tools.sh`

POSIX `sh`. Reads subcommand `$1`, calls `detect-stack.sh`, and prints the command line(s) for that action+stack to stdout (caller executes). Prints `no-op` and exits 0 when stack is `unknown` or the action has no mapping. Exit codes:
- 0 — printed command(s) or no-op.
- 64 — invalid usage (unknown action).

The script does **not** execute tools itself; it is a pure mapper. This keeps it testable without needing the tools installed.

## 7. Makefile integration

The `format`/`format-check`/`lint`/`typecheck`/`test*`/`build` targets change from generic no-op messages to invoking `scripts/stack-tools.sh` and executing the printed command. The `unknown`-stack path still no-ops cleanly (script prints `no-op`, target exits 0). `make ci` now also runs the real quality gate when a stack is present.

`scripts/ci-local.sh` is extended to call `stack-tools.sh` for format-check/lint when a stack is detected (in addition to its existing markdownlint/lychee/actionlint best-effort checks).

## 8. Testing

`scripts/test/test-stack-detection.sh` — a POSIX shell test (no test framework; uses `assert` helper functions) that:
- Creates a temp repo with a `pyproject.toml` → asserts `detect-stack.sh` prints `python` and `stack-tools.sh lint` prints `ruff check .`.
- Repeats for `package.json`→node, `go.mod`→go, `pom.xml`→java, `*.csproj`→dotnet.
- Asserts `unknown` stack + any action → `no-op`, exit 0.
- Asserts invalid action → exit 64.

Invoked by a new `make test-scripts` target and added to `ci-local.sh`. Runs in CI (no extra dependencies — pure shell).

## 9. Cross-cutting updates

- `AGENTS.md` — under "Setup, test, build, and security commands", add a one-line note that CI uses `ci.yml` dispatcher + `scripts/stack-tools.sh` for per-stack tooling.
- `docs/development/testing-strategy.md` — note that coverage gating is 80% overall in Phase 2; 90% critical-module + 90% changed-lines deferred to Codecov (TD).
- `docs/plans/technical-debt.md` — add TD-0002 (deferred Codecov 90% gating) and TD-0003 (Go coverage threshold computation step).
- `CHANGELOG.md` — `### Added` Phase 2 entry.

## 10. Out of scope (deferred to later phases)

- Security-scan workflows (Phase 3): codeql, secret-scan, dependency-review, dependency-audit, license-check, scorecard.
- AI evaluation (Phase 4): ai-evaluation.yml, open-code-review.yml, prompts content.
- Delivery pipeline (Phase 5): sbom, artifact-attestation, release, deploy-dev/staging, smoke-test.
- Production readiness (Phase 6): deploy-production, rollback, observability wiring.

## 11. Assumptions

1. `src/` may be empty (template not yet adopted by a consumer) — all quality/test/build jobs skip cleanly via the `if: stack != 'unknown'` guard.
2. When a consumer adopts a stack, they add the standard manifest (`pyproject.toml`/`package.json`/`go.mod`/`pom.xml`/`*.csproj`) — this is what `detect-stack.sh` keys on.
3. The default tool choices (ruff/prettier/golangci-lint/checkstyle/dotnet-format) are sane modern defaults; consumers can override via ADR.
4. CI runner has network access to install tools via `setup-*` actions and package managers.

## 12. Acceptance criteria

Phase 2 is complete when:
- `ci.yml` dispatcher + `ci-quality.yml` + `ci-test.yml` + `build.yml` exist, are SHA-pinned, least-privilege, with timeouts + concurrency.
- `scripts/stack-tools.sh` maps all 9 actions × 5 stacks (+ unknown no-op).
- `scripts/test/test-stack-detection.sh` passes for all stacks + edge cases.
- On the empty template (`stack == unknown`), `ci.yml` runs green with all downstream jobs skipped (no noise).
- `make ci` / `make lint` / `make test` remain exit-0 on the empty template and would execute real tools once a stack is added.
- All Phase-1 checks remain green.
- `AGENTS.md`, testing-strategy doc, technical-debt log, and CHANGELOG updated.
- A new PR is opened on a feature branch, all checks pass, and the owner merges it to `main`.
