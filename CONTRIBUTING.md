# Contributing

Thanks for your interest in contributing to `template-ai-native`! This document
explains how to work effectively in this repository.

## How to contribute

* **Start with an issue.** Before opening a pull request for any substantial
  change (new feature, refactor of existing behavior, breaking change), open an
  issue first so the change can be discussed. Trivial fixes (typos, small docs
  tweaks) can go straight to a PR.
* Keep issues and pull requests focused: one logical change per PR.
* Provide enough context in the issue for someone else to understand the
  problem and the proposed solution.

## Branching strategy

* This repository uses a **trunk-based** workflow. `main` is the single
  integration branch and is always intended to be in a releasable state.
* All changes land through a **pull request** against `main`.
* **No direct pushes to `main`.** Branch protection prevents this; even
  maintainers must use a PR.
* Branch from the latest `main` and use a descriptive branch name
  (e.g. `feat/add-tooling`, `fix/changelog-typo`).

## Commit convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/).
Each commit message should be structured as `<type>: <description>`.

Allowed types:

* `feat` — a new feature
* `fix` — a bug fix
* `docs` — documentation-only changes
* `test` — adding or correcting tests
* `refactor` — code change that neither fixes a bug nor adds a feature
* `perf` — code change that improves performance
* `build` — changes affecting the build system or dependencies
* `ci` — changes to CI configuration files and scripts
* `chore` — other non-source changes (tooling, repo config)
* `security` — vulnerability or security-hardening fix
* `revert` — reverts a previous commit

Example: `feat: add license-headers CI check`.

## Pull requests

* Every change goes through a pull request. Open your PR against `main`.
* Follow the checklist in the PR template
  ([`.github/pull_request_template.md`](.github/pull_request_template.md)) — it
  lists what reviewers expect before approval.
* **Conventional PR title required.** The PR title becomes the squashed commit
  message, so it must follow the same `<type>: <description>` form as commits.
* **Squash merge is the default.** One commit per PR keeps `main` history
  linear and readable.

## Code review

* Every PR requires **at least one reviewer** approval before merging.
* Changes to sensitive paths require review from the assigned **CODEOWNERS**
  (for example, governance files, CI configuration, security policy).
* Address review feedback by pushing new commits to the same branch; do not
  force-push while a review is in progress unless asked.
* Be kind and specific in review comments; focus on the change, not the author.

## AI-agent contributors

* AI agents (and the humans directing them) **must read and follow
  [`AGENTS.md`](AGENTS.md)** before modifying this repository.
* Agents should respect the same workflow as human contributors: open an issue
  first for substantial changes, use a PR, follow commit conventions, and never
  push directly to `main`.
* Never commit real secrets, credentials, or non-public data. See
  [`SECURITY.md`](SECURITY.md).

## Code of conduct

Participation in this project is governed by the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating
you agree to uphold its standards.
