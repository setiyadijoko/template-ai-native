# Getting Started

This guide is for someone using `template-ai-native` for the first time. You
do not need to understand every security or AI term before starting. Complete
the first section, then return to the later sections as your application grows.

## 1. What you are creating

`template-ai-native` is a reusable GitHub template. It gives your application
documentation, coding rules, tests, security checks, and delivery guidance. It
does not contain your application, language, framework, database, AI provider,
or cloud platform.

There are two repositories to keep distinct:

| Repository | Purpose |
|---|---|
| Template repository | The reusable starting point maintained by the template owner |
| Consumer repository | The new application repository created with **Use this template** |

After creating a consumer repository, do your application work there—not in
the template repository.

## 2. Before you start

You need:

- a GitHub account with permission to create a repository;
- Git;
- `make`;
- Python 3 for metadata checks;
- the toolchain for your chosen application stack when you are ready to add it.

You do not need an AI provider, cloud account, Docker, Kubernetes, or a
production environment to complete the first setup.

## 3. Create and personalize the repository

### 3.1 Create the repository

1. Open the template repository on GitHub.
2. Select **Use this template** → **Create a new repository**.
3. Choose the owner, repository name, visibility, and then create it.
4. Clone the new repository:

   ```sh
   # Replace YOUR-ORG/YOUR-REPO with the repository you created from this template.
   git clone https://github.com/YOUR-ORG/YOUR-REPO.git
   cd YOUR-REPO
   ```

5. When the application will use environment variables, create a local file
   from the safe example. This is optional during the first setup:

   ```sh
   cp .env.example .env
   ```

   Replace placeholders locally, never commit `.env`, and use an approved
   secret manager for shared or production credentials.

### 3.2 Personalize the README

Run the initializer from the repository root:

```sh
./scripts/init-project.sh \
  --name my-app \
  --description "Short description of the application" \
  --stack auto \
  --layout single
```

Supported stack values are `auto`, `node`, `python`, `go`, `java`, `dotnet`,
and `other`. Layout values are `single`, `monorepo`, and `undecided`. Use
`auto` and `undecided` when you have not selected a stack or layout yet.

When the command is run interactively without `--layout`, it asks whether the
repository contains one application or multiple applications/services. A
monorepo uses the explicit version-2 component contract; provide each component
as `ID=PATH:STACK` (repeat `--component` as needed):

```sh
./scripts/init-project.sh \
  --name ev-charge-tracker \
  --description "EV charging tracker" \
  --stack auto \
  --layout monorepo \
  --primary-path src/backend \
  --component backend=src/backend:go \
  --component frontend=src/frontend:node
```

The primary path may be omitted when the first component should be primary.
Every generated component is required by default; optional components can be
declared later by editing the reviewed `.template/project.yaml` contract.
Single-stack and undecided layouts continue to generate the compatible
version-1 config.

The initializer changes only the marked project identity block in `README.md`
and writes the credential-free `.template/project.yaml` layout declaration. For
monorepos it validates and writes the explicit component list used by
`ci-monorepo.yml`. It does not create credentials, change workflows, or enable
profile-aware controls.
If you intentionally need to replace a generated identity and config, use
`--reconfigure`:

```sh
./scripts/init-project.sh --reconfigure --name my-app --stack python
```

Without `--reconfigure`, a second run stops instead of silently overwriting
the README identity or project config.

### 3.3 Activate component-aware monorepo CI

For a version-2 monorepo, keep both the caller workflow
(`.github/workflows/ci.yml`) and the reusable component workflow
(`.github/workflows/ci-monorepo.yml`) on the repository's default branch before
opening the first application PR that relies on component checks. GitHub notes
that some events require a workflow file to exist on the default branch, and a
local reusable workflow is resolved from the caller's commit. See the
[GitHub Actions workflow documentation](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows#triggering-a-workflow).

If the workflows are being added or migrated separately, use this sequence:

1. Merge the workflow files and the reviewed `.template/project.yaml` contract.
2. Run `make project-config-check` on the default branch.
3. Open a small follow-up PR that changes a component path and confirm the
   component checks run in their declared working directories.
4. Keep `monorepo / aggregate` advisory until runtime, check-name stability,
   fork behavior, artifact ownership, and CI cost have been measured. Do not
   add component contexts to branch protection during the pilot.

If a component check remains pending, first confirm that the reusable workflow
exists on the PR base branch and that every component path, stack, and artifact
name passes `.template/project.yaml` validation. Do not use
`pull_request_target` or add credentials to make the check run.

## 4. Describe the application before coding

Start with these files:

| File | Write this there |
|---|---|
| `PRODUCT.md` | Why the application exists, who uses it, scope, and success measures |
| `DESIGN.md` | Approved requirements, flows, boundaries, and acceptance criteria |
| `ARCHITECTURE.md` | Executive view of components and integrations |
| `docs/adr/` | Important decisions, alternatives, and consequences |
| `AGENTS.md` | Canonical working rules; read it before changing code |

Do not fill every document perfectly before starting. Capture the business
objective, target user, scope, and first acceptance criteria, then improve the
documents as the design becomes clearer.

## 5. Add the application code

Place consumer-owned application code under `src/`. Keep tests under the
existing `tests/` directories. Examples:

```text
src/                 application source code
tests/unit/          fast unit tests
tests/contract/      interface and adapter contract tests
tests/integration/   database, queue, or external-adapter tests
tests/e2e/           critical user journeys only
```

The template detects a primary Python, Node.js, Go, Java, or .NET stack from
supported manifests in the repository root or directly under `src/`. A version-1
monorepo remains safely `unknown`. A version-2 monorepo lists components
explicitly in `.template/project.yaml` and uses component-aware CI without
guessing nested manifests.

## 6. Run the local checks

Run these commands from the repository root:

```sh
make setup
make ci
make docs-check
```

Expected behavior before a stack is added:

| Command | Expected result |
|---|---|
| `make setup` | Reports that no stack is detected and exits cleanly |
| `make ci` | Runs documentation, readiness, and script checks; stack checks may no-op |
| `make docs-check` | Runs installed local tools and reports unavailable optional tools as skipped |

`production_ready=false` from the template readiness contract is expected. It
means that a real platform, evidence, approvals, and rollback details have not
yet been supplied; it is not a deployment failure.

After adding a supported stack, run its formatter, linter, tests, coverage, and
build commands as described in `Makefile` and `scripts/stack-tools.sh`.

### Python dependency setup

For Python consumers, put the dependency manifest in the repository root or
directly under `src/`, but not both. `make setup` and the inherited Python
quality, test, and build jobs use `scripts/setup-python-deps.sh` to install:

1. the editable project and its `dev` extra from `pyproject.toml`;
2. an editable `setup.py` project; or
3. `requirements.txt` followed by `requirements-dev.txt`.

Create and activate an isolated environment before local setup:

```sh
python3.12 -m venv .venv
. .venv/bin/activate
make setup
```

Do not install consumer dependencies into the system Python environment.

Declare Ruff, mypy, pytest, pytest-cov, and build in the consumer's development
dependencies so the project controls compatible versions. When a tool remains
missing, the helper installs the exact fallback pin from
`scripts/python-ci-tools.txt`. A Pipfile-only project fails explicitly because
the template cannot infer a reproducible Pipenv environment without a governed
lockfile and toolchain decision.

### Understand the first coverage result

The production baseline requires at least 80% unit coverage. This threshold
also applies to the first application pull request; there is no hidden
bootstrap bypass. For Python, the mapper evaluates `tests/unit`; integration
and end-to-end suites run as separate jobs and do not raise the unit-coverage
percentage. Coverage output states the active threshold before reporting the
measured result.

If a new component reports less than 80%, add meaningful tests for its actual
validation, domain, authorization, parsing, and error behavior. Do not add
assertion-free placeholder tests or lower the gate only to make CI green. The
checked-in [`consumer-monorepo` fixture](../tests/fixtures/consumer-monorepo/)
shows a minimal Go backend and Node.js frontend with real unit tests. It is a
regression example, not application source generated by the initializer.
The [`consumer-python` fixture](../tests/fixtures/consumer-python/) demonstrates
the runtime and development dependency contract used by hosted Python jobs.

For Go, reproduce the same gate from the component directory:

```sh
go test ./... -coverprofile=coverage.out
sh /path/to/repository/scripts/enforce-go-coverage.sh coverage.out
```

The helper reports `Required Go coverage threshold: 80%`. A missing coverage
profile fails as not measurable; a measured result below 80% also fails.
Other supported stacks use the pinned coverage command in
`scripts/stack-tools.sh` and follow the same 80% policy.

## 7. Work with GitHub

Use a branch for each change:

```sh
git switch -c feat/short-description
git add <files>
git commit -m "feat: describe the change"
git push -u origin feat/short-description
```

Open a pull request on GitHub. A pull request is a review request, not a
deployment. Required checks and at least one human approval protect `main`
after repository governance is configured.

To configure branch protection, an administrator can use:

```sh
gh auth login
scripts/setup-branch-protection.sh main --apply
```

The command requires appropriate repository administration permission. If you
do not have that permission, ask the repository owner; do not weaken the checks.
See [`docs/operations/branch-protection.md`](operations/branch-protection.md)
for the required status contexts and manual Environment settings.

## 8. Choose optional controls when they add value

| Control | When to use it | Important limitation |
|---|---|---|
| Code Review Graph | When you want advisory structural/risk review on PRs | It is not a merge authority by default |
| Alibaba OpenCodeReview | When an approved LLM endpoint may inspect the diff | Requires consumer-managed secrets and data policy |
| AI evaluations | When the application has prompts or model behavior to evaluate | The template runner validates fixtures; it does not call a provider |
| Graphify | When local codebase relationship exploration is useful | Keep generated output out of version control and review data egress |
| PostHog | When product analytics or feature flags are needed | It is optional and must follow data classification/redaction rules |

Do not configure these controls only because they exist. Select them when the
application risk, data policy, and expected value justify them.

## 9. Deployment is a later step

The deployment, smoke-test, and rollback workflows are skeletons. Before using
them, the consumer must select a platform and provide:

- OIDC authentication and least-privilege roles;
- development, staging, and production GitHub Environments;
- a health endpoint and smoke-test assertions;
- artifact identity and digest verification;
- production Required Reviewers;
- documented rollback and recovery evidence.

AI agents must not deploy to production without the human and environment gates
defined in `AGENTS.md`.

## 10. Common terms

| Term | Plain-language meaning |
|---|---|
| Stack | Your programming language and main toolchain, such as Go or Python |
| `src/` | The directory where your application source code belongs |
| Consumer repository | Your new application repository copied from the template |
| Pull request (PR) | A proposed change submitted for review before merging |
| Secret | A credential stored outside Git, such as an API token |
| GitHub Environment | A protected deployment boundary with its own approvals/secrets |
| OIDC | Short-lived identity from GitHub Actions to a cloud provider |
| Advisory | A report that informs review but does not block merging |
| Skeleton | A safe placeholder that needs consumer-specific implementation |
| Provider-neutral | Deliberately not tied to one AI vendor or API |

## 11. Troubleshooting

### `make setup` says no stack is detected

That is expected until a supported manifest exists in the repository root or
directly under `src/`. Add the application stack first, then rerun the command.

### The initializer says README markers are missing

Run it from the consumer repository root and confirm that `README.md` came from
this template. If the README has been heavily rewritten, preserve the identity
markers or update it manually instead of forcing the script.

### The detector reports a monorepo as `unknown`

This is expected for version-1 or incomplete configurations. Returning
`unknown` is safer than running Go tooling against a Node.js frontend or the
reverse. Migrate to version 2 with an explicit `components` list, run
`make project-config-check`, and let `ci-monorepo.yml` execute the component
jobs.

### `make docs-check` skips tools

Local checks are best-effort. Install `markdownlint-cli2`, `lychee`, `yamllint`,
`actionlint`, or `gitleaks` if you want those checks locally. GitHub Actions
runs the checks configured in each workflow independently of your local tool
installation.

### A branch-protection command returns a permission error

The command must be run by a repository administrator with the required GitHub
permission. Ask the owner to apply it; do not use a personal token in a file or
disable required checks.

## Next steps

- Read [`docs/development/testing-strategy.md`](development/testing-strategy.md)
  before adding tests.
- Read [`docs/security/secrets-management.md`](security/secrets-management.md)
  before adding credentials.
- Read [`docs/operations/deployment-guide.md`](operations/deployment-guide.md)
  before wiring a deployment target.
- Read [`AGENTS.md`](../AGENTS.md) before asking an AI coding agent to modify
  the repository.
