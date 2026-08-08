#!/usr/bin/env sh
# Prints recommended gh CLI commands to configure branch protection + a
# production Environment for a consumer repo created from this template.
# Use --apply to execute the branch-protection API call (the Environment
# requires UI configuration afterwards). Requires: gh CLI authenticated,
# repo created on GitHub.
#
# Usage: scripts/setup-branch-protection.sh [branch] [--apply]
set -eu
BRANCH="${1:-main}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "<owner>/<repo>")"

require_approvals="gh api -X PUT repos/${REPO}/branches/${BRANCH}/protection \
  -H 'Accept: application/vnd.github+json' \
  -F 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=PR Title Check' \
  -f 'required_status_checks[contexts][]=Validate required docs & metadata' \
  -f 'required_status_checks[contexts][]=Markdown lint + link check + TBD/TODO scan' \
  -f 'required_status_checks[contexts][]=actionlint (workflow syntax)' \
  -f 'required_status_checks[contexts][]=zizmor (workflow security)' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'required_pull_request_reviews[dismiss_stale_reviews]=true' \
  -F 'restrictions=null' \
  -F 'required_linear_history=true' \
  -F 'allow_force_pushes=false' \
  -F 'allow_deletions=false'"

echo "# Recommended branch protection for ${REPO} @ ${BRANCH}"
echo "${require_approvals}"
echo
echo "# Create a 'production' GitHub Environment requiring manual approval:"
echo "gh api -X PUT repos/${REPO}/environments/production"
echo "  # then in the UI: Settings > Environments > production > Required reviewers + OIDC"

if [ "${2:-}" = "--apply" ]; then
  echo "Applying branch protection..."
  sh -c "${require_approvals}" || { echo "apply failed"; exit 1; }
else
  echo "(dry-run; pass --apply as 2nd arg to execute the branch-protection call)"
fi
