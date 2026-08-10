#!/usr/bin/env sh
# Collect and enforce the repository's overall .NET line-coverage threshold.
set -eu

MINIMUM_PERCENT=80
RESULTS_PARENT=TestResults
RESULTS_DIR="$RESULTS_PARENT/template-ai-native-coverage"
DOTNET_BIN="${DOTNET_BIN:-dotnet}"
USAGE_ERROR=65

printf 'Required .NET coverage threshold: %s%%\n' "$MINIMUM_PERCENT"

if ! dotnet_exec="$(command -v "$DOTNET_BIN" 2>/dev/null)"; then
  printf '::error::.NET coverage executable is unavailable: %s\n' "$DOTNET_BIN" >&2
  exit "$USAGE_ERROR"
fi

case "$dotnet_exec" in
  /*) ;;
  *)
    dotnet_exec="$(cd "$(dirname "$dotnet_exec")" && pwd)/$(basename "$dotnet_exec")"
    ;;
esac

if [ -L "$RESULTS_PARENT" ]; then
  printf '::error::Refusing .NET coverage results through symlink: %s\n' \
    "$RESULTS_PARENT" >&2
  exit "$USAGE_ERROR"
fi

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

"$dotnet_exec" test \
  '--collect:XPlat Code Coverage' \
  --results-directory "$RESULTS_DIR" \
  /p:CoverletOutputFormat=cobertura

REPORT_LIST="$(mktemp "${TMPDIR:-/tmp}/dotnet-coverage-reports.XXXXXX")"
cleanup() { rm -f "$REPORT_LIST"; }
trap cleanup EXIT HUP INT TERM

find "$RESULTS_DIR" -type f -name coverage.cobertura.xml -print \
  | LC_ALL=C sort > "$REPORT_LIST"

if [ ! -s "$REPORT_LIST" ]; then
  printf '::error::No current-run .NET coverage report found under %s.\n' \
    "$RESULTS_DIR" >&2
  exit 1
fi

total_covered=0
total_valid=0

while IFS= read -r report; do
  coverage_tag="$(awk '
    BEGIN { RS = ">" }
    /<coverage[[:space:]]/ {
      gsub(/[\r\n]/, " ")
      print
      exit
    }
  ' "$report")"
  covered="$(printf '%s>\n' "$coverage_tag" \
    | sed -n 's/.*lines-covered="\([0-9][0-9]*\)".*/\1/p')"
  valid="$(printf '%s>\n' "$coverage_tag" \
    | sed -n 's/.*lines-valid="\([0-9][0-9]*\)".*/\1/p')"

  case "$covered" in
    ''|*[!0-9]*)
      printf '::error::Malformed .NET coverage lines-covered value: %s\n' \
        "$report" >&2
      exit 1
      ;;
  esac
  case "$valid" in
    ''|*[!0-9]*)
      printf '::error::Malformed .NET coverage lines-valid value: %s\n' \
        "$report" >&2
      exit 1
      ;;
  esac
  if [ "$covered" -gt "$valid" ]; then
    printf '::error::Impossible .NET coverage counters in %s: %s/%s\n' \
      "$report" "$covered" "$valid" >&2
    exit 1
  fi

  total_covered=$((total_covered + covered))
  total_valid=$((total_valid + valid))
done < "$REPORT_LIST"

if [ "$total_valid" -eq 0 ]; then
  printf '::error::.NET coverage has zero valid lines.\n' >&2
  exit 1
fi

percentage="$(awk -v covered="$total_covered" -v valid="$total_valid" \
  'BEGIN { printf "%.2f", (covered * 100) / valid }')"

if awk -v covered="$total_covered" -v valid="$total_valid" \
  -v minimum="$MINIMUM_PERCENT" \
  'BEGIN { exit !((covered * 100) >= (valid * minimum)) }'; then
  printf '.NET coverage: %s%% (%s/%s lines)\n' \
    "$percentage" "$total_covered" "$total_valid"
  exit 0
fi

printf '::error::.NET coverage %s%% < %s%% (%s/%s lines)\n' \
  "$percentage" "$MINIMUM_PERCENT" "$total_covered" "$total_valid" >&2
exit 1
