# Local Setup

**Status:** Adapt to your project.

If this is your first consumer repository, start with the
[getting-started guide](../getting-started.md). This page is the short command
reference.

```sh
# Replace YOUR-ORG/YOUR-REPO with the repository you created from this template.
git clone https://github.com/YOUR-ORG/YOUR-REPO.git
cd YOUR-REPO
cp .env.example .env     # edit with real values (never commit)
./scripts/init-project.sh --name my-app --description "My application" --stack auto --layout undecided
make setup
make dev
```

The initializer updates the marked identity block in `README.md` and writes the
credential-free `.template/project.yaml` layout declaration. It does not write
credentials or activate profile-aware workflows. Use `--reconfigure` when
intentionally replacing an identity and layout generated earlier.

Tooling no-ops until a stack is wired (`scripts/detect-stack.sh`).

For a detected Python project, `make setup` calls
`scripts/setup-python-deps.sh`. Prefer a root `pyproject.toml` with a `dev`
optional-dependency group that includes Ruff, mypy, pytest, pytest-cov, and
build. The helper also supports an editable `setup.py` project or
`requirements.txt` plus an optional `requirements-dev.txt`. Keep the Python
dependency boundary in either the repository root or direct `src/`, not both.
The shared resolver also recognizes a `Pipfile` as a dependency boundary, but
that does not make its environment installable by this template.

Package builds additionally require `pyproject.toml` or `setup.py` at that
boundary. The build wrapper resolves the selected interpreter before changing
to the boundary, then runs the package build there. Root projects produce
`dist/`; direct-src projects produce `src/dist/`. Missing, ambiguous, and
non-buildable boundaries fail explicitly. Pytest discovery remains
consumer-owned and is independent of the build boundary.

Activate an isolated Python 3.12 environment before running the helper locally:

```sh
python3.12 -m venv .venv
. .venv/bin/activate
make setup
```

The GitHub workflows use the interpreter selected by `actions/setup-python`;
local developers must not install consumer dependencies into system Python.

Pipfile-only automation is intentionally unsupported until the consumer adopts
a reviewed Pipenv and lockfile contract. The helper exits with guidance instead
of letting local setup and hosted CI resolve dependencies differently.
