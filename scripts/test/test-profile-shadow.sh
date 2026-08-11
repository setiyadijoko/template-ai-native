#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-profile-shadow.sh"
VALIDATOR="$ROOT/scripts/validate-profile-config.sh"
MAPPING="$ROOT/.template/profile-controls.yaml"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-shadow.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
PROJECT="$WORK/project.yaml"
printf 'version: 1\nlayout: single\nprimary_stack: node\nprimary_path: src\n' \
  > "$PROJECT"

assert_output_contains() {
  label="$1"; output="$2"; pattern="$3"
  if printf '%s\n' "$output" | grep -Eq -- "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

run_shadow() {
  sh "$RESOLVER" "$1" "${2:-$MAPPING}" "$PROJECT"
}

if grep -Fq 'sh "$HERE/resolve-profile-policy.sh' "$RESOLVER" \
  && ! grep -Fq 'mapping_value()' "$RESOLVER" \
  && ! grep -Fq 'review_alignment()' "$RESOLVER"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL shadow delegates all policy resolution\n' >&2
fi

# The missing profile is compatibility mode, not an inferred profile.
compatibility="$(sh "$RESOLVER" "$WORK/missing.yaml" "$MAPPING" \
  "$WORK/missing-project.yaml")"
assert_output_contains "compatibility mode" "$compatibility" '^mode=compatibility$'
assert_output_contains "compatibility has no profile" "$compatibility" '^profile=none$'
assert_output_contains "compatibility preserves secret scan" "$compatibility" \
  '^control\.secret_scan\.decision=current-baseline$'
compatibility_controls="$(printf '%s\n' "$compatibility" | grep -Ec '^control\.[^.]+\.decision=current-baseline$')"
assert_eq "compatibility reports every control" "$compatibility_controls" "11"

# A consumer marker without a profile fails closed through the shadow prefix.
assert_exit "consumer missing profile fails" 1 run_shadow "$WORK/missing.yaml"
missing_profile_output="$(run_shadow "$WORK/missing.yaml" 2>&1 || true)"
assert_output_contains "consumer missing profile error prefix" "$missing_profile_output" \
  '^profile-shadow:'

# Standard example resolves deterministically.
standard="$(run_shadow "$ROOT/.template/profile.yaml.example")"
assert_output_contains "standard shadow mode" "$standard" '^mode=shadow$'
assert_output_contains "standard profile" "$standard" '^profile=standard$'
assert_output_contains "standard codeql runs" "$standard" \
  '^control\.codeql\.decision=would-run$'
assert_output_contains "standard codeql class" "$standard" \
  '^control\.codeql\.class=pull-request-blocking$'

# Absolute configuration paths work when the caller is outside the repository.
mkdir "$WORK/external-cwd"
assert_exit "resolver runs outside repository cwd" 0 \
  sh -c 'cd "$1" && sh "$2" "$3" "$4" "$5"' shadow-test \
  "$WORK/external-cwd" "$RESOLVER" "$ROOT/.template/profile.yaml.example" \
  "$MAPPING" "$PROJECT"
external_standard="$(
  cd "$WORK/external-cwd"
  sh "$RESOLVER" "$ROOT/.template/profile.yaml.example" "$MAPPING" "$PROJECT" \
    2>"$WORK/external.err" || true
)"
assert_eq "external cwd preserves shadow output" "$external_standard" "$standard"

# Bare script names resolve through PATH from an external caller directory.
PATH_WITH_RESOLVER="$ROOT/scripts:$PATH"
mkdir "$WORK/path-cwd"
assert_exit "resolver runs through PATH from external cwd" 0 \
  sh -c 'cd "$1" && PATH="$2" sh resolve-profile-shadow.sh "$3" "$4" "$5"' shadow-test \
  "$WORK/path-cwd" "$PATH_WITH_RESOLVER" "$ROOT/.template/profile.yaml.example" \
  "$MAPPING" "$PROJECT"
path_standard="$(
  cd "$WORK/path-cwd"
  PATH="$PATH_WITH_RESOLVER" sh resolve-profile-shadow.sh \
    "$ROOT/.template/profile.yaml.example" "$MAPPING" "$PROJECT" \
    2>"$WORK/path.err" || true
)"
assert_eq "PATH invocation preserves shadow output" "$path_standard" "$standard"

# Profiles accepted by the canonical validator must resolve identically when
# comments and trailing whitespace are present.
sed \
  -e 's/^version: 1$/version: 1 # schema version   /' \
  -e 's/^profile: standard$/profile: standard # selected profile/' \
  -e 's/^project:$/project: # project settings/' \
  -e 's/^stack:$/stack: # stack settings/' \
  -e 's/^ai:$/ai: # AI settings/' \
  -e 's/^deployment:$/deployment: # deployment settings/' \
  -e 's/^controls:$/controls: # control settings/' \
  -e 's/^  enabled: true$/  enabled: true # enabled for this profile/' \
  -e 's/^  codeql: true$/  codeql: true # enabled in Standard/' \
  -e 's/^  scorecard: false$/  scorecard: false   /' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/commented.yaml"
assert_exit "canonical validator accepts comments and trailing whitespace" 0 \
  sh "$VALIDATOR" "$WORK/commented.yaml"
assert_exit "resolver accepts canonical commented profile" 0 \
  run_shadow "$WORK/commented.yaml"
commented="$(run_shadow "$WORK/commented.yaml" 2>"$WORK/commented.err" || true)"
assert_eq "commented profile resolves like Standard" "$commented" "$standard"

# Starter may choose stronger controls without a mismatch.
sed 's/^profile: standard$/profile: starter/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/starter.yaml"
starter="$(run_shadow "$WORK/starter.yaml" 2>"$WORK/starter.err")"
assert_output_contains "starter stronger codeql" "$starter" \
  '^control\.codeql\.alignment=stronger-than-default$'

# Enterprise defaults expose weakening declarations as warnings, not failure.
sed 's/^profile: standard$/profile: enterprise/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/enterprise.yaml"
enterprise="$(run_shadow "$WORK/enterprise.yaml" 2>"$WORK/enterprise.err")"
assert_output_contains "enterprise warning status" "$enterprise" '^status=warning$'
assert_output_contains "enterprise sbom mismatch" "$enterprise" \
  '^control\.sbom\.alignment=policy-mismatch$'
assert_output_contains "enterprise warning annotation" \
  "$(cat "$WORK/enterprise.err")" \
  '^::warning title=Profile shadow policy mismatch::sbom declaration differs from enterprise default$'

# AI-disabled Standard resolves evaluation and reviews to would-skip.
sed -e 's/^  enabled: true$/  enabled: false/' \
  -e 's/^  evaluation: true$/  evaluation: false/' \
  -e 's/^  semantic_review: advisory$/  semantic_review: off/' \
  -e 's/^  structural_review: advisory$/  structural_review: off/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/ai-disabled.yaml"
ai_disabled="$(run_shadow "$WORK/ai-disabled.yaml")"
assert_output_contains "AI evaluation skips" "$ai_disabled" \
  '^control\.ai_evaluation\.decision=would-skip$'

# Invalid profile and malformed policy fail closed.
cp "$ROOT/.template/profile.yaml.example" "$WORK/invalid.yaml"
printf 'provider: openai\n' >> "$WORK/invalid.yaml"
assert_exit "invalid profile fails" 1 run_shadow "$WORK/invalid.yaml"
mkdir "$WORK/profile-directory"
assert_exit "directory profile fails" 1 run_shadow "$WORK/profile-directory"
directory_output="$(run_shadow "$WORK/profile-directory" 2>&1 || true)"
assert_output_contains "directory profile error prefix" "$directory_output" '^profile-shadow:'
sed '/^[[:space:]]*codeql:/d' "$MAPPING" > "$WORK/malformed-controls.yaml"
assert_exit "malformed mapping fails" 1 run_shadow \
  "$ROOT/.template/profile.yaml.example" "$WORK/malformed-controls.yaml"

# Repeated runs are byte-identical.
standard_again="$(run_shadow "$ROOT/.template/profile.yaml.example")"
assert_eq "deterministic report" "$standard_again" "$standard"

report
