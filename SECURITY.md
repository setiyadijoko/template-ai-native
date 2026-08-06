# Security Policy

## Supported versions

This repository is a template. Security fixes are applied only to the active
`main` branch.

| Version | Supported          |
| ------- | ------------------ |
| `main`  | :white_check_mark: |
| older   | :x:                |

## Reporting a vulnerability

**Please report security vulnerabilities privately — do NOT open a public
GitHub issue.**

Preferred reporting channels, in order:

1. **GitHub Security Advisory** (preferred). Use the GitHub web UI
   (Security → Advisories → "Report a vulnerability") or the CLI:
   ```bash
   gh security-advisory
   ```
2. **Email**. If Security Advisories are unavailable to you, email the
   maintainer directly with a description of the issue and reproduction steps.

When you report, please include:

* A description of the vulnerability and its potential impact.
* Steps to reproduce, or a proof of concept.
* Affected versions or commits.

**Response timelines:**

* We will acknowledge your report within **48 hours**.
* We will provide an initial assessment within **5 business days**.
* We will work with you on coordinated disclosure and credit.

Do not publicly disclose a vulnerability until a fix has been released and you
have been notified.

## Scope

In scope: security vulnerabilities in **this template repository**, including
its documentation, generated scaffold, CI configuration, and any sample code
shipped here.

Out of scope:

* Vulnerabilities in applications that consumers build **from** this template —
  consumers are responsible for running their own security policy for the
  systems they ship.
* Theoretical issues without a realistic attack path.
* Tooling versions maintained by upstream projects (report those upstream).

## Safe disclosure

* **Never include real secrets in issues, PRs, code samples, or
  screenshots.** This includes API keys, tokens, passwords, and private keys.
  See [`.env.example`](.env.example) for the list of expected variables — all
  values there are placeholders.
* If you need to demonstrate a bug that requires credentials, use clearly fake
  placeholder values (e.g. `REDACTED`, `example-key`).
* Sanitize any logs, stack traces, or configuration you share.
