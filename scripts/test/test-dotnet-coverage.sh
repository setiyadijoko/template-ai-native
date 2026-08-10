#!/usr/bin/env sh
# Contract tests for current-run .NET coverage collection and enforcement.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dotnet-coverage.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

HELPER="$ROOT/scripts/run-dotnet-coverage.sh"
FAKE_BIN="$WORK/bin"
mkdir -p "$FAKE_BIN"

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"
  if printf '%s\n' "$value" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

write_report() {
  directory="$1"
  covered="$2"
  valid="$3"
  mkdir -p "$directory"
  printf '<coverage line-rate="0" lines-covered="%s" lines-valid="%s"></coverage>\n' \
    "$covered" "$valid" > "$directory/coverage.cobertura.xml"
}

cat > "$FAKE_BIN/dotnet" <<'EOF'
#!/usr/bin/env sh
set -eu

printf '%s\n' "$@" > "$DOTNET_LOG"
result_root="$PWD/TestResults/template-ai-native-coverage"

case "$DOTNET_FIXTURE_MODE" in
  exact)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="8" lines-valid="10"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  below)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="79" lines-valid="100"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  weighted-pass)
    mkdir -p "$result_root/run-a" "$result_root/run-b"
    printf '<coverage lines-covered="100" lines-valid="100"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    printf '<coverage lines-covered="700" lines-valid="900"></coverage>\n' \
      > "$result_root/run-b/coverage.cobertura.xml"
    ;;
  weighted-fail)
    mkdir -p "$result_root/run-a" "$result_root/run-b"
    printf '<coverage lines-covered="100" lines-valid="100"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    printf '<coverage lines-covered="620" lines-valid="900"></coverage>\n' \
      > "$result_root/run-b/coverage.cobertura.xml"
    ;;
  missing)
    ;;
  malformed)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="8"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  prefixed)
    mkdir -p "$result_root/run-a"
    printf '<coverage data-lines-covered="8" lines-valid="10"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  truncated)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="8" lines-valid="10"\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  nested)
    mkdir -p "$result_root/run-a"
    printf '<not-coverage><coverage lines-covered="8" lines-valid="10"></coverage></not-coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  oversized)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="18446744073709551617" lines-valid="18446744073709551617"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  impossible)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="11" lines-valid="10"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  zero)
    mkdir -p "$result_root/run-a"
    printf '<coverage lines-covered="0" lines-valid="0"></coverage>\n' \
      > "$result_root/run-a/coverage.cobertura.xml"
    ;;
  collector-fail)
    exit 42
    ;;
  *)
    printf 'unsupported fixture mode: %s\n' "$DOTNET_FIXTURE_MODE" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/dotnet"

run_case() {
  name="$1"
  mode="$2"
  case_dir="$WORK/$name"
  mkdir -p "$case_dir"
  (
    cd "$case_dir"
    PATH="$FAKE_BIN:$PATH" \
      DOTNET_BIN=dotnet \
      DOTNET_FIXTURE_MODE="$mode" \
      DOTNET_LOG="$case_dir/dotnet.log" \
      sh "$HELPER"
  )
}

set +e
exact_output="$(run_case exact exact 2>&1)"
exact_status=$?
set -e
assert_eq "coverage at threshold status" "$exact_status" "0"
assert_text_contains "coverage at threshold output" "$exact_output" \
  '[.]NET coverage: 80[.]00% [(]8/10 lines[)]'
assert_text_contains "coverage threshold is visible" "$exact_output" \
  'Required [.]NET coverage threshold: 80%'
assert_text_contains "collector uses test command" "$(cat "$WORK/exact/dotnet.log")" '^test$'
assert_text_contains "collector uses XPlat" "$(cat "$WORK/exact/dotnet.log")" \
  '^--collect:XPlat Code Coverage$'
assert_text_contains "collector uses controlled results option" \
  "$(cat "$WORK/exact/dotnet.log")" '^--results-directory$'
assert_text_contains "collector uses controlled results path" \
  "$(cat "$WORK/exact/dotnet.log")" '^TestResults/template-ai-native-coverage$'
assert_text_contains "collector requests cobertura" "$(cat "$WORK/exact/dotnet.log")" \
  '^/p:CoverletOutputFormat=cobertura$'

set +e
below_output="$(run_case below below 2>&1)"
below_status=$?
set -e
assert_eq "below threshold status" "$below_status" "1"
assert_text_contains "below threshold output" "$below_output" \
  '[.]NET coverage 79[.]00% < 80%'

set +e
weighted_pass_output="$(run_case weighted-pass weighted-pass 2>&1)"
weighted_pass_status=$?
set -e
assert_eq "weighted threshold status" "$weighted_pass_status" "0"
assert_text_contains "weighted threshold output" "$weighted_pass_output" \
  '[.]NET coverage: 80[.]00% [(]800/1000 lines[)]'

set +e
weighted_fail_output="$(run_case weighted-fail weighted-fail 2>&1)"
weighted_fail_status=$?
set -e
assert_eq "weighted calculation rejects unweighted false pass" \
  "$weighted_fail_status" "1"
assert_text_contains "weighted failure output" "$weighted_fail_output" \
  '[.]NET coverage 72[.]00% < 80%'

for failure_mode in missing malformed prefixed truncated nested oversized impossible zero; do
  set +e
  failure_output="$(run_case "$failure_mode" "$failure_mode" 2>&1)"
  failure_status=$?
  set -e
  assert_eq "$failure_mode evidence status" "$failure_status" "1"
  assert_text_contains "$failure_mode evidence is CI error" "$failure_output" '^::error::'
done

stale_dir="$WORK/stale/TestResults/template-ai-native-coverage/old-run"
write_report "$stale_dir" 10 10
set +e
stale_output="$(run_case stale missing 2>&1)"
stale_status=$?
set -e
assert_eq "stale report is removed" "$stale_status" "1"
assert_text_contains "stale report cannot satisfy gate" "$stale_output" \
  'No current-run [.]NET coverage report found'

set +e
run_case collector-fail collector-fail >/dev/null 2>&1
collector_status=$?
set -e
assert_eq "collector failure is preserved" "$collector_status" "42"

missing_bin_dir="$WORK/missing-bin"
mkdir -p "$missing_bin_dir"
set +e
missing_bin_output="$(
  cd "$missing_bin_dir"
  DOTNET_BIN="$WORK/does-not-exist" sh "$HELPER" 2>&1
)"
missing_bin_status=$?
set -e
assert_eq "missing dotnet status" "$missing_bin_status" "65"
assert_text_contains "missing dotnet is explicit" "$missing_bin_output" \
  '^::error::[.]NET coverage executable is unavailable'

PROJECT="$WORK/mapper"
mkdir -p "$PROJECT"
printf '<Project Sdk="Microsoft.NET.Sdk"></Project>\n' > "$PROJECT/app.csproj"
mapper_output="$(cd "$PROJECT" && sh "$ROOT/scripts/stack-tools.sh" coverage)"
assert_eq "dotnet coverage mapper uses helper" "$mapper_output" \
  "sh \"$ROOT/scripts/run-dotnet-coverage.sh\""

report
