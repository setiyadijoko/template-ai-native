<!--
Pull Request template — complete every section. See CONTRIBUTING.md and AGENTS.md.
-->

## Business purpose

<!-- What business problem does this solve? Who benefits? -->

## Linked requirement / issue

<!-- "Closes #123" or a reference to a design doc / requirement. -->

## Scope

<!-- What this PR includes. -->

## Out of scope

<!-- What this PR deliberately does NOT include. -->

## Design reference

<!-- Link to docs/plans/active/<design>.md, DESIGN.md section, or ADR. -->

## Impact

- **Architecture impact:** <!-- e.g. none / component X added -->
- **Security impact:** <!-- e.g. none / authz rule changed (describe) -->
- **Data & privacy impact:** <!-- e.g. none / new PII stored (describe) -->
- **AI behavior impact:** <!-- e.g. none / prompt or model routing changed -->
- **Deployment impact:** <!-- e.g. none / migration required -->
- **Migration requirements:** <!-- e.g. none / expand-then-contract step 2 -->

## Testing performed

<!-- Which tests ran, which were added, coverage delta. -->

## Evaluation results

<!-- AI eval results if prompt/model/agent changed; else "N/A". -->

## Rollback plan

<!-- How to revert safely. Note DB rollback limitations. -->

## Evidence

<!-- Screenshots, command output, links. -->

## Documentation changes

<!-- Which docs/ADR/changelog were updated. -->

## Risk level

<!-- Low | Medium | High — and why. -->

## Confirmations

- [ ] No secret or sensitive data is committed in this PR.
- [ ] No undocumented breaking API change is introduced.

## AI discipline checklist

- [ ] Material assumptions are documented.
- [ ] The simplest viable solution was selected.
- [ ] Unnecessary abstractions were avoided.
- [ ] Every changed file is relevant.
- [ ] Unrelated refactoring was avoided.
- [ ] Acceptance criteria are measurable.
- [ ] Tests were executed.
- [ ] The complete diff was reviewed.
- [ ] Deferred technical debt is recorded separately.
- [ ] No command result has been fabricated.
