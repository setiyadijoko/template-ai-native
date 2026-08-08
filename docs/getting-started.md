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
   git clone https://github.com/<owner>/<new-repository>.git
   cd <new-repository>
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
repository contains one application or multiple applications/services. For a
monorepo, also provide the primary component path:

```sh
./scripts/init-project.sh \
  --name ev-charge-tracker \
  --description "EV charging tracker" \
  --stack go \
  --layout monorepo \
  --primary-path src/backend
```

The initializer changes only the marked project identity block in `README.md`
and writes the credential-free `.template/project.yaml` layout declaration. It
does not create credentials, change workflows, or enable profile-aware controls.
If you intentionally need to replace a generated identity and config, use
`--reconfigure`:

```sh
./scripts/init-project.sh --reconfigure --name my-app --stack python
```

Without `--reconfigure`, a second run stops instead of silently overwriting
the README identity or project config.

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
supported manifests in the repository root or directly under `src/`. A
declared monorepo currently fails safe as `unknown`; component-aware CI is a
future step and will not guess which service to build.

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

This is intentional for now. The repository records the layout and primary
path, but the current reusable workflows execute one stack from the repository
root or `src/`. Returning `unknown` is safer than running Go tooling against a
Node.js frontend or the reverse. Component-aware CI will be added only after
the execution contract is approved.

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
