# scripts/

Operational scripts for the `template-ai-native` repo. All are POSIX `sh`; the
quality/detection scripts no-op on the empty template, while
`init-project.sh` intentionally requires a consumer README and project name.

| Script | When to run | What it does |
|---|---|---|
| `resolve-python-project-dir.sh` | Called by Python setup, build, and packaging paths | Selects exactly one Python dependency boundary from the current directory or direct `src/`; ambiguous and absent boundaries fail explicitly. |
| `setup-python-deps.sh` | Called by Python quality, test, and build jobs | Consumes the shared project-directory resolver, installs the consumer project from a supported pip-installable manifest, then installs only CI tools still missing after consumer dependency setup. It uses the workflow-selected Python interpreter and fails explicitly for Pipfile-only projects. |
| `run-python-build.sh` | Called by the Python build mapper | Requires a package build manifest, resolves the selected interpreter before changing directories, and builds from the shared project boundary. |
| `python-ci-tools.txt` | Read by `setup-python-deps.sh` | Stores repository-controlled fallback pins as `distribution==version\|import_module`; consumer-provided compatible tools take precedence. |
| `detect-stack.sh` | Called by single-stack `Makefile` and CI compatibility paths; run manually to debug | Prints the detected stack token (`python \| node \| go \| java \| dotnet \| unknown`) from the repo root or direct `src/` manifests. A declared monorepo returns `unknown`; version-2 component CI resolves its explicit list separately. Always exits 0. |
| `resolve-components.sh` | Called by component-aware CI; run manually to validate a monorepo | Validates version-2 `.template/project.yaml` components and emits the explicit component list as `--tsv` or JSON with `--json`; it never discovers nested manifests. |
| `enforce-go-coverage.sh` | Called by single-stack and component-aware CI | Logs and enforces the shared 80% Go coverage threshold from `coverage.out`; fails closed when the profile is missing, malformed, or below threshold. The threshold is fixed rather than consumer-overridable. |
| `run-dotnet-coverage.sh` | Called by single-stack and component-aware .NET coverage mappings | Runs the consumer-owned XPlat collector in an isolated current-run results directory, validates all Cobertura reports, and enforces the fixed 80% weighted aggregate line threshold. Missing, malformed, zero-valid, impossible, and below-threshold evidence fails closed. |
| `run-node-test-category.sh` | Called by Node.js integration/e2e mappings | Runs local Vitest when matching files exist under `tests/integration` or `tests/e2e`; otherwise exits successfully with an explicit optional-category skip message. Unit tests remain required and are not routed through this helper. |
| `ci-local.sh` | `make ci` / `make docs-check` | Runs the best-effort local quality gate (markdownlint, lychee link check, yamllint, actionlint). Reports missing tools but does not fail on them; fails only when an installed tool reports failure. |
| `init-project.sh` | After creating a repository from this template | Requires selection of `starter\|standard\|enterprise` and never infers it: non-interactive use must pass `--profile`, while interactive use prompts for the profile. It replaces the marked consumer project identity block in `README.md` and writes credential-free `.template/project.yaml` and `.template/profile.yaml` together. `--project-type` defaults to `other` and `--ai-enabled` to `false`; Enterprise requires a non-`none` `--deployment-target`. Single/undecided layouts use version 1, while monorepos require repeatable `--component ID=PATH:STACK` options and use version 2. It does not edit workflows, source code, credentials, or branch protection. Profile values select reusable jobs in the advisory aggregate while direct baseline execution stays unchanged. Use `--reconfigure` for an intentional replacement. |
| `validate-project-config.sh` | `make project-config-check` / `make ci` | Validates the credential-free `.template/project.yaml` layout declaration; version 1 remains compatible and version 2 requires an explicit monorepo component list. Missing config keeps compatibility mode. |
| `validate-profile-config.sh` | `make profile-config-check` / `make ci` | Validates the credential-free `.template/profile.yaml` maturity-profile contract. Missing config keeps template compatibility mode; an initialized consumer missing a profile fails the policy check. Profile values select reusable jobs in the aggregate; applying the recommended branch protection remains owner-controlled. |
| `resolve-profile-policy.sh` | `sh scripts/resolve-profile-policy.sh [PROFILE_PATH] [MAPPING_PATH] [PROJECT_PATH]` or `make profile-policy-check` | Resolves the central deterministic effective-policy contract, including compatibility mode and consumer profile alignment; it fails closed when an initialized consumer is missing or has an invalid profile. |
| `resolve-profile-shadow.sh` | Called by the advisory profile-shadow workflow; run manually to inspect a profile | Presents the central effective-policy resolution as hypothetical decisions and never controls workflow execution. |
| `resolve-profile-execution-plan.sh` | `sh scripts/resolve-profile-execution-plan.sh` | Converts the validated effective policy and repository layout into fixed, credential-free boundary decisions for the advisory `Profile policy / Required controls` aggregate. It is safe to run locally for diagnostics and does not call GitHub or a provider. |
| `evaluate-profile-required-controls.sh` | Called by `Profile policy / Required controls` after its reusable jobs finish | Validates the execution plan and fixed boundary conclusions, then fails closed when they violate the contract, including a non-successful required control. It is aggregate wiring, not a branch-protection configuration command. |
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
