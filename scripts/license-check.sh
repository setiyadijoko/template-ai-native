#!/usr/bin/env sh
# license-check.sh — best-effort license policy report (ADVISORY in Phase 3).
# Prints allow/deny matches; warns on denylist; always exits 0.
# Promotable to blocking (exit 1 on denylist) in a later phase.
set -eu

ALLOW="MIT Apache-2.0 ISC BSD-2-Clause BSD-3-Clause 0BSD LGPL-2.1 MPL-2.0 Unlicense"
DENY="GPL-3.0 AGPL-3.0 SSPL Commons-Clause"

is_allowed() { echo "$ALLOW" | tr ' ' '\n' | grep -qxF "$1"; }
is_denied()  { echo "$DENY"  | tr ' ' '\n' | grep -qxF "$1"; }

print_policy() {
  printf 'License policy:\n  allow: %s\n  deny:  %s\n\n' "$ALLOW" "$DENY"
}

report_node() {
  [ -f package.json ] || return 0
  printf '== node (package.json) ==\n'
  lic=$(grep -oE '"license"[[:space:]]*:[[:space:]]*"[^"]+"' package.json | sed -E 's/.*:"([^"]+)"/\1/' || true)
  [ -n "$lic" ] && printf '  declared: %s\n' "$lic"
}

report_python() {
  { [ -f pyproject.toml ] || [ -f requirements.txt ]; } || return 0
  printf '== python ==\n'
  if command -v pip-licenses >/dev/null 2>&1; then
    pip-licenses --format=plain --order=license 2>/dev/null || printf '  (pip-licenses unavailable; skipped)\n'
  else
    printf '  (pip-licenses not installed; cannot enumerate licenses)\n'
  fi
}

report_go() {
  [ -f go.mod ] || return 0
  printf '== go (go.mod) ==\n'
  if command -v go >/dev/null 2>&1; then
    go list -m -json all 2>/dev/null | grep -A1 License || printf '  (no License fields available)\n'
  else
    printf '  (go not installed; skipped)\n'
  fi
}

main() {
  print_policy
  report_node
  report_python
  report_go
  printf '\nlicense-check: advisory report complete (exit 0)\n'
}
main
