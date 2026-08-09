#!/usr/bin/env sh
# Enforce the repository's Go coverage threshold from a go tool cover profile.
set -eu

PROFILE="${1:-coverage.out}"
MINIMUM_PERCENT=80

printf 'Required Go coverage threshold: %s%%\n' "$MINIMUM_PERCENT"

if [ ! -f "$PROFILE" ]; then
  printf '::error::No Go coverage profile found; coverage gate is not measurable for this component.\n' >&2
  exit 1
fi

pct="$(go tool cover -func="$PROFILE" | awk '/^total:/ {gsub("%", "", $3); print $3}')"
if [ -z "$pct" ]; then
  printf '::error::Go coverage profile %s has no total coverage value.\n' "$PROFILE" >&2
  exit 1
fi

printf 'Go coverage: %s%%\n' "$pct"
if awk -v pct="$pct" -v minimum="$MINIMUM_PERCENT" 'BEGIN { exit !(pct >= minimum) }'; then
  exit 0
fi

printf '::error::Go coverage %s%% < %s%%\n' "$pct" "$MINIMUM_PERCENT" >&2
exit 1
