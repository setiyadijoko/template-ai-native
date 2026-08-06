#!/usr/bin/env sh
# Local mirror of the primary CI quality gate. Runs whatever is available.
# Exit non-zero only when a configured tool reports failure. Missing tools
# are reported but do not fail the run (template is stack-agnostic).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
run() { # run <label> <command...>
  label="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf '%s\n' ":: ${label} ::"; "$@" || fail=1
  else
    printf '%s\n' "-- ${label} skipped (tool '${1}' not installed)"
  fi
}

run "markdownlint" markdownlint-cli2 "**/*.md"
# lychee: best-effort link check on docs
run "link-check"   lychee --no-progress --exclude-loopback README.md docs
# yamllint: best-effort YAML lint (don't fail on style-only)
run "yaml-lint"    yamllint -d "{extends: default, rules: {line-length: disable, document-start: disable}}" .github 2>/dev/null || true
run "actionlint"   actionlint

# Run per-stack format-check + lint when a stack is detected.
if [ "$(sh scripts/detect-stack.sh)" != "unknown" ]; then
  printf '%s\n' ":: per-stack format-check ::"
  sh -c "$(sh scripts/stack-tools.sh format-check)" || fail=1
  printf '%s\n' ":: per-stack lint ::"
  sh -c "$(sh scripts/stack-tools.sh lint)" || fail=1
fi

# Best-effort secret scan when gitleaks is installed.
run "gitleaks" gitleaks detect --source . --no-banner

echo
if [ "$fail" -eq 0 ]; then echo "ci-local: OK (best-effort)"; else echo "ci-local: FAILURES"; fi
exit "$fail"
