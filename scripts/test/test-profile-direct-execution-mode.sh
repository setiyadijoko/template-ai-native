#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-direct-execution-mode.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-direct-mode.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

assert_mode() {
  case_label="$1"; fixture="$2"; case_expected="$3"
  stderr_file="$WORK/$case_label.stderr"
  set +e
  output="$(cd "$fixture" && sh "$RESOLVER" 2>"$stderr_file")"
  case_exit=$?
  set -e
  stderr_output="$(cat "$stderr_file")"
  assert_eq "$case_label exit" "$case_exit" 0
  assert_eq "$case_label output" "$output" "direct_profile_controls=$case_expected"
  assert_eq "$case_label stderr" "$stderr_output" ''
}

assert_event_mode() {
  case_label="$1"; fixture="$2"; source_event="$3"; case_expected="$4"
  stderr_file="$WORK/$case_label.stderr"
  set +e
  output="$(cd "$fixture" && SOURCE_EVENT="$source_event" sh "$RESOLVER" 2>"$stderr_file")"
  case_exit=$?
  set -e
  assert_eq "$case_label exit" "$case_exit" 0
  assert_eq "$case_label output" "$output" "direct_profile_controls=$case_expected"
  assert_eq "$case_label stderr" "$(cat "$stderr_file")" ''
}

assert_failure() {
  case_label="$1"; fixture="$2"
  stdout_file="$WORK/$case_label.stdout"
  stderr_file="$WORK/$case_label.stderr"
  set +e
  (cd "$fixture" && sh "$RESOLVER") >"$stdout_file" 2>"$stderr_file"
  case_exit=$?
  set -e
  stdout_output="$(cat "$stdout_file")"
  stderr_output="$(cat "$stderr_file")"
  assert_eq "$case_label exit" "$case_exit" 1
  assert_eq "$case_label stdout" "$stdout_output" ''
  case "$stderr_output" in
    direct-execution-mode:*) PASS=$((PASS+1)) ;;
    *)
      FAIL=$((FAIL+1))
      printf 'FAIL %s stderr prefix\n' "$case_label" >&2
      ;;
  esac
}

mkdir -p "$WORK/template"
assert_mode template "$WORK/template" true

mkdir -p "$WORK/consumer/.template"
printf '%s\n' 'version: 1' > "$WORK/consumer/.template/project.yaml"
printf '%s\n' 'version: 1' > "$WORK/consumer/.template/profile.yaml"
assert_mode consumer "$WORK/consumer" false
assert_event_mode consumer-pull-request "$WORK/consumer" pull_request false
assert_event_mode consumer-push "$WORK/consumer" push false
assert_event_mode consumer-schedule "$WORK/consumer" schedule true
assert_event_mode consumer-manual "$WORK/consumer" workflow_dispatch true

set +e
(cd "$WORK/consumer" && SOURCE_EVENT=unexpected sh "$RESOLVER") \
  >"$WORK/event.stdout" 2>"$WORK/event.stderr"
event_exit=$?
set -e
assert_eq "unsupported event exit" "$event_exit" 1
assert_eq "unsupported event stdout" "$(cat "$WORK/event.stdout")" ''
case "$(cat "$WORK/event.stderr")" in
  direct-execution-mode:*) PASS=$((PASS+1)) ;;
  *) FAIL=$((FAIL+1)); printf 'FAIL unsupported event stderr prefix\n' >&2 ;;
esac

mkdir -p "$WORK/project-only/.template"
printf '%s\n' 'version: 1' > "$WORK/project-only/.template/project.yaml"
assert_failure project-only "$WORK/project-only"

mkdir -p "$WORK/profile-only/.template"
printf '%s\n' 'version: 1' > "$WORK/profile-only/.template/profile.yaml"
assert_failure profile-only "$WORK/profile-only"

mkdir -p "$WORK/project-link/.template"
printf '%s\n' 'version: 1' > "$WORK/project-link/project.yaml"
ln -s ../project.yaml "$WORK/project-link/.template/project.yaml"
printf '%s\n' 'version: 1' > "$WORK/project-link/.template/profile.yaml"
assert_failure project-link "$WORK/project-link"

mkdir -p "$WORK/profile-link/.template"
printf '%s\n' 'version: 1' > "$WORK/profile-link/.template/project.yaml"
printf '%s\n' 'version: 1' > "$WORK/profile-link/profile.yaml"
ln -s ../profile.yaml "$WORK/profile-link/.template/profile.yaml"
assert_failure profile-link "$WORK/profile-link"

mkdir -p "$WORK/project-directory/.template/project.yaml"
printf '%s\n' 'version: 1' > "$WORK/project-directory/.template/profile.yaml"
assert_failure project-directory "$WORK/project-directory"

mkdir -p "$WORK/profile-directory/.template/profile.yaml"
printf '%s\n' 'version: 1' > "$WORK/profile-directory/.template/project.yaml"
assert_failure profile-directory "$WORK/profile-directory"

first="$(cd "$WORK/consumer" && sh "$RESOLVER")"
second="$(cd "$WORK/consumer" && sh "$RESOLVER")"
assert_eq "consumer output deterministic" "$second" "$first"

set +e
sh "$RESOLVER" one two three >"$WORK/arguments.stdout" 2>"$WORK/arguments.stderr"
arguments_exit=$?
set -e
assert_eq "too many arguments exit" "$arguments_exit" 1
assert_eq "too many arguments stdout" "$(cat "$WORK/arguments.stdout")" ''
case "$(cat "$WORK/arguments.stderr")" in
  direct-execution-mode:*) PASS=$((PASS+1)) ;;
  *) FAIL=$((FAIL+1)); printf 'FAIL too many arguments stderr prefix\n' >&2 ;;
esac

report
