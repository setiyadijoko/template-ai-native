#!/usr/bin/env sh
# Structural contract for the advisory profile-shadow observation workflow.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORKFLOW="$ROOT/.github/workflows/profile-shadow.yml"
BRANCH_PROTECTION="$ROOT/scripts/setup-branch-protection.sh"

assert_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq -- "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq -- "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

permissions="$(sed -n '/^permissions:/,/^$/p' "$WORKFLOW")"
pr_trigger="$(sed -n '/^  pull_request:/,/^  push:/p' "$WORKFLOW")"
push_trigger="$(sed -n '/^  push:/,/^  workflow_dispatch:/p' "$WORKFLOW")"

assert_contains "workflow name" "$WORKFLOW" '^name: Profile shadow$'
assert_contains "pull requests enabled" "$WORKFLOW" '^  pull_request:$'
assert_contains "pull requests target main" /dev/stdin 'branches: \[main\]' <<EOF
$pr_trigger
EOF
assert_contains "pushes enabled" "$WORKFLOW" '^  push:$'
assert_contains "pushes target main" /dev/stdin 'branches: \[main\]' <<EOF
$push_trigger
EOF
assert_contains "manual dispatch enabled" "$WORKFLOW" '^  workflow_dispatch:$'
assert_eq "workflow permissions are exactly read-only" "$permissions" \
  "$(printf 'permissions:\n  contents: read')"
assert_contains "observation job name" "$WORKFLOW" \
  'name: Profile shadow / Profile policy observation'
assert_contains "short timeout" "$WORKFLOW" 'timeout-minutes: 3'
assert_contains "checkout pin" "$WORKFLOW" \
  'uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7\.0\.1'
assert_contains "checkout credentials disabled" "$WORKFLOW" 'persist-credentials: false'
assert_contains "resolver command" "$WORKFLOW" \
  'sh scripts/resolve-profile-shadow\.sh'
assert_contains "report writes job summary" "$WORKFLOW" '>> "[$]GITHUB_STEP_SUMMARY"'

assert_not_contains "workflow has no pull_request_target" "$WORKFLOW" 'pull_request_target'
assert_not_contains "workflow has no paths filter" "$WORKFLOW" 'paths:'
assert_not_contains "workflow has no secrets context" "$WORKFLOW" 'secrets\.'
assert_not_contains "workflow has no write permission" "$WORKFLOW" ': write'
assert_not_contains "workflow has no error suppression" "$WORKFLOW" 'continue-on-error'
assert_not_contains "workflow has no artifact upload" "$WORKFLOW" 'upload-artifact'
assert_not_contains "workflow has no github script" "$WORKFLOW" 'github-script'
assert_not_contains "workflow has no curl" "$WORKFLOW" 'curl'
assert_not_contains "branch protection excludes advisory observation" \
  "$BRANCH_PROTECTION" 'Profile shadow / Profile policy observation'

report
