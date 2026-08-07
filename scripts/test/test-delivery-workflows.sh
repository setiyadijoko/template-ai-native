#!/usr/bin/env sh
# Structural contracts for the governed build, attestation, and release chain.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

BUILD="$ROOT/.github/workflows/build.yml"
CI="$ROOT/.github/workflows/ci.yml"
ATTEST="$ROOT/.github/workflows/artifact-attestation.yml"
RELEASE="$ROOT/.github/workflows/release.yml"

assert_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq "$pattern" "$file"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_not_contains() {
  label="$1"
  file="$2"
  pattern="$3"

  if grep -Eq "$pattern" "$file"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

# --- build.yml: one fail-closed packaged artifact with reusable outputs ---
assert_contains "build exports artifact name" "$BUILD" 'artifact-name:'
assert_contains "build exports upload state" "$BUILD" 'artifact-uploaded:'
assert_contains "build packages one file" "$BUILD" 'template-ai-native-build-.*\.tar\.gz'
assert_contains "build fails without output" "$BUILD" 'No supported build output found'
assert_contains "upload fails without package" "$BUILD" 'if-no-files-found: error'

# --- ci.yml: same-run attestation only for governed main pushes ---
assert_contains "ci calls attestation" "$CI" 'uses: ./\.github/workflows/artifact-attestation\.yml'
assert_contains "ci attestation needs build" "$CI" 'needs: \[detect, build\]'
assert_contains "ci passes artifact name" "$CI" 'artifact-name:.*needs\.build\.outputs\.artifact-name'
assert_contains "ci passes upload state" "$CI" 'artifact-uploaded:.*needs\.build\.outputs\.artifact-uploaded'
assert_contains "ci limits attestation to push" "$CI" "github\.event_name == 'push'"
assert_contains "ci limits attestation to main" "$CI" "github\.ref == 'refs/heads/main'"

# --- artifact-attestation.yml: reusable, allowlisted, and fail closed ---
assert_contains "attestation is reusable" "$ATTEST" 'workflow_call:'
assert_contains "attestation accepts name" "$ATTEST" 'artifact-name:'
assert_contains "attestation accepts upload state" "$ATTEST" 'artifact-uploaded:'
assert_contains "attestation validates name" "$ATTEST" 'build-\(python\|node\|go\|java\|dotnet\)'
assert_contains "attestation writes provenance" "$ATTEST" 'attestations: write'
assert_contains "attestation receives OIDC" "$ATTEST" 'id-token: write'
assert_not_contains "attestation has no workflow_run" "$ATTEST" 'workflow_run:'
assert_not_contains "attestation has no fabricated unknown artifact" "$ATTEST" 'build-unknown'
assert_not_contains "attestation has no integrity bypass" "$ATTEST" 'continue-on-error:'

report
