# Coding Standards

**Status:** Adapt to your project.

- Follow existing conventions; one coherent change per PR.
- Conventional Commits: `feat, fix, docs, test, refactor, perf, build, ci, chore, security, revert`.
- No unrelated refactoring; no speculative features (see `AGENTS.md`).
- Keep business logic out of controllers/UI; validate AI output before use.

## License headers

For source files where copyright attribution is required, use the SPDX header
format in [`docs/templates/license-header.txt`](../templates/license-header.txt).
Replace the owner, year, and license identifier with values approved for the
consumer project. The header must match the repository `LICENSE`; it does not
replace the full license file. Do not add a header to generated files or
third-party code unless the applicable license requires it.
