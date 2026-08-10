#!/usr/bin/env sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

RESOLVER="$ROOT/scripts/resolve-profile-shadow.sh"
MAPPING="$ROOT/.template/profile-controls.yaml"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile-shadow.XXXXXX")"
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

run_shadow() {
  sh "$RESOLVER" "$1" "${2:-$MAPPING}"
}

# The missing profile is compatibility mode, not an inferred profile.
compatibility="$(run_shadow "$WORK/missing.yaml")"
assert_output_contains "compatibility mode" "$compatibility" '^mode=compatibility$'
assert_output_contains "compatibility has no profile" "$compatibility" '^profile=none$'
assert_output_contains "compatibility preserves secret scan" "$compatibility" \
  '^control\.secret_scan\.decision=current-baseline$'
compatibility_controls="$(printf '%s\n' "$compatibility" | grep -Ec '^control\.[^.]+\.decision=current-baseline$')"
assert_eq "compatibility reports every control" "$compatibility_controls" "11"

# Standard example resolves deterministically.
standard="$(run_shadow "$ROOT/.template/profile.yaml.example")"
assert_output_contains "standard shadow mode" "$standard" '^mode=shadow$'
assert_output_contains "standard profile" "$standard" '^profile=standard$'
assert_output_contains "standard codeql runs" "$standard" \
  '^control\.codeql\.decision=would-run$'
assert_output_contains "standard codeql class" "$standard" \
  '^control\.codeql\.class=pull-request-blocking$'

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
  "$(cat "$WORK/enterprise.err")" '^::warning.*sbom'

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
sed '/^[[:space:]]*codeql:/d' "$MAPPING" > "$WORK/malformed-controls.yaml"
assert_exit "malformed mapping fails" 1 run_shadow \
  "$ROOT/.template/profile.yaml.example" "$WORK/malformed-controls.yaml"

# Repeated runs are byte-identical.
standard_again="$(run_shadow "$ROOT/.template/profile.yaml.example")"
assert_eq "deterministic report" "$standard_again" "$standard"

report
