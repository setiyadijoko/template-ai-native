# Branch protection guidance

The template provides `scripts/setup-branch-protection.sh` because branch
protection is repository configuration, not a file that can be copied by
**Use this template**.

Run it after authenticating `gh` with an account that has repository
administration permission:

```sh
gh auth login
scripts/setup-branch-protection.sh main --apply
```

The script configures one approval, stale-approval dismissal, strict required
checks, enforced administrator rules, linear history, and disabled force-push
or branch deletion. Required check contexts must match the emitted GitHub
check-run names exactly; the current script uses job names rather than
workflow/job display labels.

For a fine-grained personal access token, grant the minimum repository
administration permission required to update branch protection. Prefer `gh`
device or browser authentication and short-lived credentials where available;
never commit a token or place it in workflow logs.

Verify the result:

```sh
gh api repos/OWNER/REPO/branches/main/protection
gh api repos/OWNER/REPO/rulesets
```

Branch protection does not configure GitHub Environments. Configure the
`production` Environment and its Required Reviewers separately when a deploy
target is adopted.
