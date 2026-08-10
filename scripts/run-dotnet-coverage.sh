#!/usr/bin/env sh
# Collect and enforce the repository's overall .NET line-coverage threshold.
set -eu

MINIMUM_PERCENT=80
MAX_SAFE_COUNTER=2147483647
MAX_ROOT_TAG_LENGTH=4096
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

is_safe_counter() {
  printf '%s\n' "$1" | awk '
    {
      value = $0
      sub(/^0+/, "", value)
      if (value == "") value = "0"
      if (length(value) < 10) exit 0
      if (length(value) > 10) exit 1

      limit = "2147483647"
      for (position = 1; position <= 10; position++) {
        digit = substr(value, position, 1)
        limit_digit = substr(limit, position, 1)
        if (digit < limit_digit) exit 0
        if (digit > limit_digit) exit 1
      }
      exit 0
    }
    END { if (NR != 1) exit 1 }
  '
}

parse_coverage_values() {
  LC_ALL=C od -An -v -tu1 "$1" | awk -v maximum="$MAX_ROOT_TAG_LENGTH" '
    BEGIN { state = "before" }
    function is_space(value) {
      return value ~ /^[[:space:]]$/
    }
    function is_name_start(value) {
      return value ~ /^[A-Za-z_:]$/
    }
    function is_name_character(value) {
      return value ~ /^[A-Za-z0-9_.:-]$/
    }
    function append_tag(value) {
      if (length(tag) >= maximum) {
        invalid = 1
        return
      }
      tag = tag value
    }
    function emit_attributes(    position, tag_length, value, attribute, quote) {
      position = 10
      tag_length = length(tag)
      while (position <= tag_length) {
        while (position <= tag_length && is_space(substr(tag, position, 1))) position++
        if (position > tag_length) return
        value = substr(tag, position, 1)
        if (value == ">") {
          position++
          break
        }
        if (value == "/") {
          position++
          while (position <= tag_length && is_space(substr(tag, position, 1))) position++
          if (substr(tag, position, 1) != ">") return
          position++
          break
        }
        if (!is_name_start(value)) return

        attribute = ""
        while (position <= tag_length && is_name_character(substr(tag, position, 1))) {
          attribute = attribute substr(tag, position, 1)
          position++
        }
        while (position <= tag_length && is_space(substr(tag, position, 1))) position++
        if (substr(tag, position, 1) != "=") return
        position++
        while (position <= tag_length && is_space(substr(tag, position, 1))) position++
        quote = substr(tag, position, 1)
        if (quote != "\"" && quote != "\047") return
        position++

        value = ""
        while (position <= tag_length && substr(tag, position, 1) != quote) {
          value = value substr(tag, position, 1)
          position++
        }
        if (substr(tag, position, 1) != quote) return
        position++
        if (attribute == "lines-covered") {
          if (have_covered) return
          covered = value
          have_covered = 1
        } else if (attribute == "lines-valid") {
          if (have_valid) return
          valid = value
          have_valid = 1
        }
        if (position <= tag_length && !is_space(substr(tag, position, 1)) && \
          substr(tag, position, 1) != "/" && substr(tag, position, 1) != ">") return
      }
      if (position != tag_length + 1 || !have_covered || !have_valid || \
        covered !~ /^[0-9][0-9]*$/ || valid !~ /^[0-9][0-9]*$/) return
      print covered " " valid
    }
    {
      for (field = 1; field <= NF; field++) {
        value = sprintf("%c", $field)
        if (invalid || done) continue

        if (state == "before") {
        if (is_space(value)) continue
        if (value != "<") {
          invalid = 1
          continue
        }
        state = "open"
        } else if (state == "open") {
        if (value == "?") {
          state = "processing_instruction"
        } else if (value == "!") {
          state = "comment_first_dash"
        } else {
          tag = "<"
          append_tag(value)
          if (value != "c") invalid = 1
          else state = "root_name"
        }
        } else if (state == "processing_instruction") {
        if (previous == "?" && value == ">") {
          state = "before"
          previous = ""
        } else {
          previous = value
        }
        } else if (state == "comment_first_dash") {
        if (value == "-") state = "comment_second_dash"
        else invalid = 1
        } else if (state == "comment_second_dash") {
        if (value == "-") {
          state = "comment"
          previous = ""
          before_previous = ""
        } else invalid = 1
        } else if (state == "comment") {
        if (before_previous == "-" && previous == "-" && value == ">") {
          state = "before"
          previous = ""
          before_previous = ""
        } else {
          before_previous = previous
          previous = value
        }
        } else if (state == "root_name") {
        append_tag(value)
        name_length = length(tag) - 1
        if (value != substr("coverage", name_length, 1)) invalid = 1
        else if (name_length == length("coverage")) state = "root_boundary"
        } else if (state == "root_boundary") {
        append_tag(value)
        if (is_space(value) || value == "/") state = "root_tag"
        else invalid = 1
        } else if (state == "root_tag") {
        append_tag(value)
        if (invalid) continue
        if (quote != "") {
          if (value == quote) quote = ""
        } else if (value == "\"" || value == "\047") {
          quote = value
        } else if (value == ">") {
          emit_attributes()
          done = 1
          exit
        }
        }
      }
    }
  '
}

while IFS= read -r report; do
  coverage_values="$(parse_coverage_values "$report")"
  set -- $coverage_values
  if [ "$#" -ne 2 ]; then
    printf '::error::Malformed .NET coverage root tag: %s\n' "$report" >&2
    exit 1
  fi
  covered="$1"
  valid="$2"

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
  if ! is_safe_counter "$covered" || ! is_safe_counter "$valid"; then
    printf '::error::.NET coverage counter exceeds safe shell range: %s\n' \
      "$report" >&2
    exit 1
  fi
  if [ "$covered" -gt "$valid" ]; then
    printf '::error::Impossible .NET coverage counters in %s: %s/%s\n' \
      "$report" "$covered" "$valid" >&2
    exit 1
  fi
  if [ "$covered" -gt "$((MAX_SAFE_COUNTER - total_covered))" ] || \
    [ "$valid" -gt "$((MAX_SAFE_COUNTER - total_valid))" ]; then
    printf '::error::.NET coverage aggregate exceeds safe shell range: %s\n' \
      "$report" >&2
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
