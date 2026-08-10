#!/usr/bin/env sh
# Contract tests for the declarative maturity-profile configuration.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-profile.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

mkdir -p "$WORK/.template"

if [ -f "$ROOT/.template/profile.schema.yaml" ] \
  && [ -f "$ROOT/.template/profile.yaml.example" ] \
  && [ -f "$ROOT/.template/profile-controls.yaml" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL profile schema, mapping, and example exist\n' >&2
fi

if grep -Fq '  starter:' "$ROOT/.template/profile-controls.yaml" \
  && grep -Fq '  standard:' "$ROOT/.template/profile-controls.yaml" \
  && grep -Fq '  enterprise:' "$ROOT/.template/profile-controls.yaml"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL all maturity profiles are mapped\n' >&2
fi

if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$ROOT/.template/profile.yaml.example" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL validates the Standard example\n' >&2
fi

for profile in starter standard enterprise; do
  sed "s/^profile: standard$/profile: $profile/" \
    "$ROOT/.template/profile.yaml.example" > "$WORK/.template/$profile.yaml"
  if sh "$ROOT/scripts/validate-profile-config.sh" \
    "$WORK/.template/$profile.yaml" >/dev/null 2>&1; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); printf 'FAIL accepts profile %s\n' "$profile" >&2
  fi
done

if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$WORK/.template/missing.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL missing profile preserves compatibility mode\n' >&2
fi

cat > "$WORK/.template/unknown-key.yaml" <<'EOF'
version: 1
profile: standard
project:
  type: web-app
stack:
  primary: auto
ai:
  enabled: true
  evaluation: true
  semantic_review: advisory
  structural_review: advisory
deployment:
  enabled: false
  target: none
controls:
  secret_scan: true
  dependency_review: true
  codeql: true
  coverage: true
  sbom: false
  artifact_attestation: false
  scorecard: false
provider: openai
EOF
if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$WORK/.template/unknown-key.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts an unknown profile key\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/credential-key.yaml" <<'EOF'
version: 1
profile: standard
project:
  type: web-app
stack:
  primary: auto
ai:
  enabled: true
  evaluation: true
  semantic_review: advisory
  structural_review: advisory
deployment:
  enabled: false
  target: none
controls:
  secret_scan: true
  dependency_review: true
  codeql: true
  coverage: true
  sbom: false
  artifact_attestation: false
  scorecard: false
  api_key: none
EOF
if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$WORK/.template/credential-key.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts a credential-like key\n' >&2
else
  PASS=$((PASS+1))
fi

sed 's/^profile: standard$/profile: regulated/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/.template/invalid-profile.yaml"
if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$WORK/.template/invalid-profile.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts an unsupported profile\n' >&2
else
  PASS=$((PASS+1))
fi

sed 's/^  enabled: false$/  enabled: maybe/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/.template/invalid-boolean.yaml"
if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$WORK/.template/invalid-boolean.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts an invalid boolean\n' >&2
else
  PASS=$((PASS+1))
fi

sed 's/^  type: web-app$/    type: web-app/' \
  "$ROOT/.template/profile.yaml.example" > "$WORK/.template/invalid-indent.yaml"
if sh "$ROOT/scripts/validate-profile-config.sh" \
  "$WORK/.template/invalid-indent.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts malformed indentation\n' >&2
else
  PASS=$((PASS+1))
fi

report
