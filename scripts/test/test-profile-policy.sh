#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

POLICY="$ROOT/scripts/resolve-profile-policy.sh"
MAPPING="$ROOT/.template/profile-controls.yaml"
CONTROLS='secret_scan dependency_review codeql coverage sbom artifact_attestation scorecard ai_evaluation semantic_review structural_review production_governance'
CONTROL_FIELDS='declared default enabled class policy_required pr_required alignment'
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-policy.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

assert_output_contains() {
  label="$1"; output="$2"; pattern="$3"
  if printf '%s\n' "$output" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_output_count() {
  label="$1"; output="$2"; pattern="$3"; expected="$4"
  actual="$(printf '%s\n' "$output" | grep -Ec -- "$pattern" || true)"
  assert_eq "$label" "$actual" "$expected"
}

error_output() {
  set +e
  output="$(sh "$@" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"
  return "$status"
}

assert_policy_failure() {
  label="$1"; shift
  assert_exit "$label" 1 sh "$@"
  output="$(error_output "$@" || true)"
  assert_output_contains "$label error prefix" "$output" '^profile-policy:'
}

assert_control_field_matrix() {
  output="$1"
  for control in $CONTROLS; do
    for field in $CONTROL_FIELDS; do
      assert_output_count "$control has one $field field" "$output" \
        "^control\\.$control\\.$field=" "1"
    done
  done
}

printf 'version: 1\nlayout: single\nprimary_stack: node\nprimary_path: src\n' \
  > "$WORK/project.yaml"

# Empty template state remains compatible.
template="$(sh "$POLICY" "$WORK/missing-profile.yaml" "$MAPPING" \
  "$WORK/missing-project.yaml")"
assert_output_contains "template compatibility" "$template" '^mode=compatibility$'
assert_output_contains "template profile" "$template" '^profile=none$'
assert_output_contains "template baseline" "$template" \
  '^control\.secret_scan\.enabled=current-baseline$'
assert_output_count "template reports every current baseline control" "$template" \
  '^control\.[^.]+\.enabled=current-baseline$' "11"

# A consumer marker without a profile fails closed.
assert_policy_failure "consumer missing profile fails" "$POLICY" \
  "$WORK/missing-profile.yaml" "$MAPPING" "$WORK/project.yaml"

# A profile without a project marker also fails closed.
assert_policy_failure "profile without project config fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$MAPPING" "$WORK/missing-project.yaml"

# Standard produces blocking CodeQL and advisory semantic review.
standard="$(sh "$POLICY" "$ROOT/.template/profile.yaml.example" \
  "$MAPPING" "$WORK/project.yaml")"
assert_output_contains "standard mode" "$standard" '^mode=profile$'
assert_output_contains "standard profile" "$standard" '^profile=standard$'
assert_output_contains "standard aligned" "$standard" '^status=aligned$'
assert_output_contains "codeql declared" "$standard" '^control\.codeql\.declared=true$'
assert_output_contains "codeql default" "$standard" '^control\.codeql\.default=true$'
assert_output_contains "codeql enabled" "$standard" '^control\.codeql\.enabled=true$'
assert_output_contains "codeql pull request class" "$standard" \
  '^control\.codeql\.class=pull-request-blocking$'
assert_output_contains "codeql policy required" "$standard" \
  '^control\.codeql\.policy_required=true$'
assert_output_contains "codeql PR required" "$standard" \
  '^control\.codeql\.pr_required=true$'
assert_output_contains "codeql aligned" "$standard" \
  '^control\.codeql\.alignment=aligned$'
assert_output_contains "semantic review advisory class" "$standard" \
  '^control\.semantic_review\.class=pull-request-advisory$'
assert_output_contains "semantic review policy required" "$standard" \
  '^control\.semantic_review\.policy_required=true$'
assert_output_contains "semantic review not PR blocking" "$standard" \
  '^control\.semantic_review\.pr_required=false$'
assert_output_count "standard emits seven fields per control" "$standard" \
  '^control\.[^.]+\.(declared|default|enabled|class|policy_required|pr_required|alignment)=' \
  "77"
assert_control_field_matrix "$standard"

# A stronger Starter declaration remains valid.
sed 's/^profile: standard$/profile: starter/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/starter.yaml"
starter="$(sh "$POLICY" "$WORK/starter.yaml" "$MAPPING" "$WORK/project.yaml")"
assert_output_contains "stronger Starter CodeQL" "$starter" \
  '^control\.codeql\.alignment=stronger-than-default$'
assert_output_contains "stronger Starter CodeQL required" "$starter" \
  '^control\.codeql\.policy_required=true$'

# A weakened Enterprise declaration reports warning deterministically.
sed 's/^profile: standard$/profile: enterprise/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/enterprise.yaml"
enterprise="$(sh "$POLICY" "$WORK/enterprise.yaml" "$MAPPING" \
  "$WORK/project.yaml" 2>"$WORK/enterprise.err")"
assert_output_contains "Enterprise warning" "$enterprise" '^status=warning$'
assert_output_contains "Enterprise SBOM mismatch" "$enterprise" \
  '^control\.sbom\.alignment=policy-mismatch$'
assert_output_contains "Enterprise SBOM required" "$enterprise" \
  '^control\.sbom\.policy_required=true$'
assert_output_contains "Enterprise warning annotation" "$(cat "$WORK/enterprise.err")" \
  '^::warning.*sbom'

# Invalid mapping/configuration paths fail closed with the resolver prefix.
sed '/^    codeql:/d' "$MAPPING" > "$WORK/malformed-controls.yaml"
assert_policy_failure "malformed mapping fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$WORK/malformed-controls.yaml" "$WORK/project.yaml"
cp "$MAPPING" "$WORK/unknown-profile-controls.yaml"
printf '  premium:\n' >> "$WORK/unknown-profile-controls.yaml"
assert_policy_failure "unknown mapping profile fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$WORK/unknown-profile-controls.yaml" "$WORK/project.yaml"
cp "$MAPPING" "$WORK/duplicate-profile-controls.yaml"
printf '  starter:\n' >> "$WORK/duplicate-profile-controls.yaml"
assert_policy_failure "duplicate mapping profile fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$WORK/duplicate-profile-controls.yaml" "$WORK/project.yaml"
awk '1; /^    codeql: true$/ { print "    unknown_control: true" }' "$MAPPING" \
  > "$WORK/unknown-control-controls.yaml"
assert_policy_failure "unknown mapping control fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$WORK/unknown-control-controls.yaml" "$WORK/project.yaml"
awk '1; /^    codeql: true$/ { print }' "$MAPPING" \
  > "$WORK/duplicate-control-controls.yaml"
assert_policy_failure "duplicate mapping control fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$WORK/duplicate-control-controls.yaml" "$WORK/project.yaml"
mkdir "$WORK/profile-directory" "$WORK/mapping-directory" "$WORK/project-directory"
assert_policy_failure "profile directory fails" "$POLICY" \
  "$WORK/profile-directory" "$MAPPING" "$WORK/project.yaml"
assert_policy_failure "mapping directory fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$WORK/mapping-directory" "$WORK/project.yaml"
assert_policy_failure "project directory fails" "$POLICY" \
  "$ROOT/.template/profile.yaml.example" "$MAPPING" "$WORK/project-directory"
sed 's/^profile: standard$/profile: premium/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/invalid-profile.yaml"
assert_policy_failure "invalid profile fails" "$POLICY" \
  "$WORK/invalid-profile.yaml" "$MAPPING" "$WORK/project.yaml"

# Repeated policy decisions are byte-identical.
standard_again="$(sh "$POLICY" "$ROOT/.template/profile.yaml.example" \
  "$MAPPING" "$WORK/project.yaml")"
assert_eq "deterministic report" "$standard_again" "$standard"

report
