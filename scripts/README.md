# scripts/

Operational scripts for the `template-ai-native` repo. All are POSIX `sh`; the
quality/detection scripts no-op on the empty template, while
`init-project.sh` intentionally requires a consumer README and project name.

| Script | When to run | What it does |
|---|---|---|
| `detect-stack.sh` | Called by single-stack `Makefile` and CI compatibility paths; run manually to debug | Prints the detected stack token (`python \| node \| go \| java \| dotnet \| unknown`) from the repo root or direct `src/` manifests. A declared monorepo returns `unknown`; version-2 component CI resolves its explicit list separately. Always exits 0. |
| `resolve-components.sh` | Called by component-aware CI; run manually to validate a monorepo | Validates version-2 `.template/project.yaml` components and emits the explicit component list as `--tsv` or JSON with `--json`; it never discovers nested manifests. |
| `enforce-go-coverage.sh` | Called by single-stack and component-aware CI | Logs and enforces the shared 80% Go coverage threshold from `coverage.out`; fails closed when the profile is missing, malformed, or below threshold. The threshold is fixed rather than consumer-overridable. |
| `run-node-test-category.sh` | Called by Node.js integration/e2e mappings | Runs local Vitest when matching files exist under `tests/integration` or `tests/e2e`; otherwise exits successfully with an explicit optional-category skip message. Unit tests remain required and are not routed through this helper. |
| `ci-local.sh` | `make ci` / `make docs-check` | Runs the best-effort local quality gate (markdownlint, lychee link check, yamllint, actionlint). Reports missing tools but does not fail on them; fails only when an installed tool reports failure. |
| `init-project.sh` | After creating a repository from this template | Replaces the marked consumer project identity block in `README.md` and writes a credential-free `.template/project.yaml`; single/undecided layouts use version 1, while monorepos require explicit repeatable `--component ID=PATH:STACK` options and use version 2. It does not configure workflows, profiles, source code, or credentials. Use `--reconfigure` for an intentional replacement. |
| `validate-project-config.sh` | `make project-config-check` / `make ci` | Validates the credential-free `.template/project.yaml` layout declaration; version 1 remains compatible and version 2 requires an explicit monorepo component list. Missing config keeps compatibility mode. |
| `setup-branch-protection.sh` | After you create your repo on GitHub | Prints the recommended `gh` CLI commands to configure `main` branch protection and a `production` GitHub Environment. Pass `--apply` to execute the branch-protection call; configure Environment reviewers/OIDC in the GitHub UI afterward. |
| `lib/` | Internal shared helpers | Reserved for shared shell helpers as scripts grow. |

## Notes

- These scripts intentionally avoid Bashisms so they run on macOS (`/bin/sh`) and Linux CI alike.
- Never hardcode secrets into these scripts; read from environment or approved secret managers.
- When you adopt a stack, replace the `Makefile` stub targets with real commands that call your toolchain — `detect-stack.sh` already routes by stack.
- Node.js quality, typecheck, and test mappings use `npx --no-install`; declare
  the required formatter, linter, compiler, and test runner in the consumer's
  `devDependencies` so CI fails clearly when a tool is not configured.
- GitHub Actions installs `golangci-lint` v2.12.2 deterministically before the
  existing Go lint mapping runs. Local developers install the same version or
  invoke it through their approved tool manager.
