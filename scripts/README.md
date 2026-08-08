# scripts/

Operational scripts for the `template-ai-native` repo. All are POSIX `sh`; the
quality/detection scripts no-op on the empty template, while
`init-project.sh` intentionally requires a consumer README and project name.

| Script | When to run | What it does |
|---|---|---|
| `detect-stack.sh` | Called by `Makefile` and CI automatically; run manually to debug | Prints the detected stack token (`python \| node \| go \| java \| dotnet \| unknown`) based on manifest files in the repo root. Always exits 0. |
| `ci-local.sh` | `make ci` / `make docs-check` | Runs the best-effort local quality gate (markdownlint, lychee link check, yamllint, actionlint). Reports missing tools but does not fail on them; fails only when an installed tool reports failure. |
| `init-project.sh` | After creating a repository from this template | Replaces only the marked consumer project identity block in `README.md`; it does not configure workflows, profiles, source code, or credentials. Use `--reconfigure` for an intentional replacement. |
| `setup-branch-protection.sh` | After you create your repo on GitHub | Prints the recommended `gh` CLI commands to configure `main` branch protection and a `production` GitHub Environment. Pass `--apply` to execute the branch-protection call; configure Environment reviewers/OIDC in the GitHub UI afterward. |
| `lib/` | Internal shared helpers | Reserved for shared shell helpers as scripts grow. |

## Notes

- These scripts intentionally avoid Bashisms so they run on macOS (`/bin/sh`) and Linux CI alike.
- Never hardcode secrets into these scripts; read from environment or approved secret managers.
- When you adopt a stack, replace the `Makefile` stub targets with real commands that call your toolchain — `detect-stack.sh` already routes by stack.
