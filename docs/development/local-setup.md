# Local Setup

**Status:** Adapt to your project.

```sh
git clone <your-repo>
cd <your-repo>
cp .env.example .env     # edit with real values (never commit)
make setup
make dev
```

Tooling no-ops until a stack is wired (`scripts/detect-stack.sh`).
