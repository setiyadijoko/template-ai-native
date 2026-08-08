# Local Setup

**Status:** Adapt to your project.

If this is your first consumer repository, start with the
[getting-started guide](../getting-started.md). This page is the short command
reference.

```sh
git clone <your-repo>
cd <your-repo>
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
