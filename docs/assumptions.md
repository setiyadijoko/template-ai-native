# Assumptions

**Status:** Template baseline — record project-specific assumptions here.

## Template assumptions

1. **Stack-agnostic:** no concrete formatter/linter/type-checker runs in CI until a consumer populates `src/`. Workflows no-op cleanly when no stack is detected.
2. **No real deployment target** in the template. `deploy-*` workflows are skeletons; the consumer fills OIDC + deploy action.
3. **AI-evaluation skeleton** does not call a real model; the consumer wires an endpoint via secret.
4. **CodeQL language detection and Autobuild** work for common languages when the `languages` input is omitted; the consumer adjusts for custom builds.
5. **Branch protection/Rulesets** cannot be applied from a template file; delivered via `scripts/setup-branch-protection.sh`.
6. **OpenCodeReview** requires a model endpoint + secret; shipped as advisory with safe placeholders.
7. **Scorecard publication:** the repository is public; Scorecard publishes authenticated results through GitHub OIDC and stores SARIF in Code Scanning.
8. **MIT license** for the template; consumers may replace it.

## Project assumptions

<!-- Record material assumptions for your project here. Never mark assumptions as facts. -->
