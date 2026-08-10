#!/usr/bin/env sh
# Structural contracts for the governed build, attestation, and release chain.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

BUILD="$ROOT/.github/workflows/build.yml"
CI_TEST="$ROOT/.github/workflows/ci-test.yml"
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

assert_text_contains() {
  label="$1"
  value="$2"
  pattern="$3"

  if printf '%s\n' "$value" | grep -Eq "$pattern"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

assert_text_not_contains() {
  label="$1"
  value="$2"
  pattern="$3"

  if printf '%s\n' "$value" | grep -Eq "$pattern"; then
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     forbidden pattern: %s\n' "$label" "$pattern" >&2
  else
    PASS=$((PASS+1))
  fi
}

assert_action_pins() {
  label="$1"
  shift
  invalid="$({
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$@" |
      sed '/^\.\//d' |
      grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}([[:space:]]+#.*)?$'
  } || true)"

  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL %s\n     unpinned action references:\n%s\n' "$label" "$invalid" >&2
  fi
}

extract_step_run_script() {
  workflow="$1"
  step_id="$2"
  output="$3"

  awk -v marker="      - id: $step_id" '
    $0 == marker { in_step = 1; next }
    in_step && $0 == "        run: |" { in_run = 1; next }
    in_run && /^      - / { exit }
    in_run {
      sub(/^          /, "")
      print
    }
  ' "$workflow" > "$output"
}

write_portable_tar_adapter() {
  output="$1"
  cat > "$output" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

archive=""
args=()
while (( "$#" > 0 )); do
  case "$1" in
    --sort=*|--mtime=*|--owner=*|--group=*|--numeric-owner)
      shift
      ;;
    -czf)
      archive="$2"
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

exec "$SYSTEM_TAR" -czf "$archive" "${args[@]}"
EOF
  chmod +x "$output"
}

run_single_stack_python_package() {
  layout="$1"
  case_root="$DELIVERY_TMP/$layout"
  project="$case_root/project"
  runner_temp="$case_root/runner"
  github_output="$case_root/github-output"

  mkdir -p "$project/scripts" "$runner_temp"
  cp "$ROOT/scripts/resolve-python-project-dir.sh" "$project/scripts/"
  case "$layout" in
    root)
      mkdir -p "$project/dist"
      : > "$project/pyproject.toml"
      printf 'fixture\n' > "$project/dist/example.whl"
      ;;
    src)
      mkdir -p "$project/src/dist"
      : > "$project/src/pyproject.toml"
      printf 'fixture\n' > "$project/src/dist/example.whl"
      ;;
  esac

  (
    cd "$project"
    PATH="$DELIVERY_TMP/bin:$PATH" \
      SYSTEM_TAR="$SYSTEM_TAR" \
      STACK=python \
      RUNNER_TEMP="$runner_temp" \
      GITHUB_OUTPUT="$github_output" \
      bash "$DELIVERY_PACKAGE_SCRIPT"
  )

  "$SYSTEM_TAR" -tzf "$runner_temp/template-ai-native-build-python.tar.gz"
}

# --- build.yml: one fail-closed packaged artifact with reusable outputs ---
assert_contains "build exports artifact name" "$BUILD" 'artifact-name:'
assert_contains "build exports upload state" "$BUILD" 'artifact-uploaded:'
assert_contains "build installs Python consumer dependencies" "$BUILD" \
  'run: sh scripts/setup-python-deps\.sh'
assert_not_contains "build has no inline Python tool-only install" "$BUILD" \
  'pip install ruff mypy pytest pytest-cov build'
assert_contains "Python packaging resolves project directory" "$BUILD" \
  'project_dir="[$][(]sh scripts/resolve-python-project-dir\.sh[)]"'
assert_contains "Python packaging selects literal root dist" "$BUILD" \
  '[.][)] artifact_dir=dist ;;'
assert_contains "Python packaging selects direct-src dist" "$BUILD" \
  'src[)] artifact_dir=src/dist ;;'
assert_contains "Python packaging adds normalized dist" "$BUILD" \
  'add_tree "[$]artifact_dir"'
assert_not_contains "Python packaging rejects dot-prefixed dist input" "$BUILD" \
  'add_tree "[$]project_dir/dist"'
assert_not_contains "Python packaging does not hardcode root dist" "$BUILD" \
  'python[)] add_tree dist'
assert_contains "build packages one file" "$BUILD" 'template-ai-native-build-.*\.tar\.gz'
assert_contains "build fails without output" "$BUILD" 'No supported build output found'
assert_contains "upload fails without package" "$BUILD" 'if-no-files-found: error'
assert_contains "single-stack retains recursive .NET coverage" "$CI_TEST" \
  'TestResults/[*][*]/coverage[.]cobertura[.]xml'

# --- ci.yml: same-run attestation only for governed main pushes ---
assert_contains "ci calls attestation" "$CI" 'uses: ./\.github/workflows/artifact-attestation\.yml'
assert_contains "ci attestation needs build and skips monorepo" "$CI" 'needs: \[detect, build, monorepo\]'
assert_contains "ci attestation skips component workflow" "$CI" "needs\.monorepo\.result == 'skipped'"
assert_contains "ci passes artifact name" "$CI" 'artifact-name:.*needs\.build\.outputs\.artifact-name'
assert_contains "ci passes upload state" "$CI" 'artifact-uploaded:.*needs\.build\.outputs\.artifact-uploaded'
assert_contains "ci limits attestation to push" "$CI" "github\.event_name == 'push'"
assert_contains "ci limits attestation to main" "$CI" "github\.ref == 'refs/heads/main'"
assert_contains "ci explains attestation contents permission" "$CI" '^[[:space:]]{6}contents: read[[:space:]]+#'
assert_contains "ci explains attestation OIDC permission" "$CI" '^[[:space:]]{6}id-token: write[[:space:]]+#'
assert_contains "ci explains provenance write permission" "$CI" '^[[:space:]]{6}attestations: write[[:space:]]+#'

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

# --- release.yml: exact-SHA promotion without rebuild or manual bypass ---
# shellcheck disable=SC2016 # `$asset` is the literal workflow contract.
asset_block="$(sed -n '/asset="template-ai-native-/,/echo "path=\$asset"/p' "$RELEASE")"
unknown_asset_block="$(
  printf '%s\n' "$asset_block" |
    sed -n '/^[[:space:]]*unknown)/,/^[[:space:]]*;;/p'
)"
known_asset_block="$(
  printf '%s\n' "$asset_block" |
    sed -n '/^[[:space:]]*python|node|go|java|dotnet)/,/^[[:space:]]*;;/p'
)"
release_files="$(sed -n '/^[[:space:]]*files: |$/,$p' "$RELEASE" | sed '1d')"
release_workflow_permissions="$(sed -n '/^permissions:/,/^$/p' "$RELEASE")"
release_job_permissions="$(sed -n '/^    permissions:/,/^$/p' "$RELEASE")"

assert_not_contains "release has no manual bypass" "$RELEASE" 'workflow_dispatch:'
assert_text_contains "release workflow defaults to read-only" "$release_workflow_permissions" '^  contents: read([[:space:]]|$)'
assert_text_not_contains "release workflow has no default write" "$release_workflow_permissions" 'contents: write'
assert_text_contains "release job can create drafts" "$release_job_permissions" '^      contents: write[[:space:]]+#'
assert_text_contains "release job reads Actions evidence" "$release_job_permissions" '^      actions: read[[:space:]]+#'
assert_contains "release queries ci workflow" "$RELEASE" 'actions/workflows/ci\.yml/runs'
assert_contains "release filters exact SHA" "$RELEASE" 'head_sha=.*GITHUB_SHA'
assert_contains "release filters push event" "$RELEASE" 'event=push'
assert_contains "release requires success" "$RELEASE" 'conclusion.*success'
# shellcheck disable=SC2016 # `$stack` is the literal workflow contract.
assert_contains "release maps artifact to stack" "$RELEASE" 'expected_artifact="build-\$stack"'
assert_contains "release downloads prior run" "$RELEASE" 'run-id:.*steps\..*\.outputs\.run-id'
assert_contains "release authorizes prior-run download" "$RELEASE" 'github-token:.*github\.token'
assert_contains "release permits unknown source archive" "$RELEASE" 'git archive'
assert_text_contains "source fallback is inside unknown branch" "$unknown_asset_block" 'git archive'
assert_text_not_contains "known stack never creates source archive" "$known_asset_block" 'git archive'
assert_text_contains "known stack uses exact downloaded package" "$known_asset_block" 'source="downloaded-artifact/template-ai-native-build-\$\{STACK\}\.tar\.gz"'
# shellcheck disable=SC2016 # `$source` and `$asset` are literal contracts.
assert_text_contains "known stack preserves package bytes" "$known_asset_block" 'mv "\$source" "\$asset"'
assert_contains "release creates digest manifest" "$RELEASE" 'digests\.txt'
assert_contains "release publishes versioned package" "$RELEASE" 'template-ai-native-.*\.tar\.gz'
assert_contains "release publishes resolved package" "$RELEASE" '^[[:space:]]+\$\{\{ steps\.asset\.outputs\.path \}\}$'
assert_contains "release publishes SBOM" "$RELEASE" '^[[:space:]]+sbom\.spdx\.json$'
assert_contains "release publishes digest manifest" "$RELEASE" '^[[:space:]]+digests\.txt$'
assert_eq "release publishes exactly three assets" "$(printf '%s\n' "$release_files" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')" "3"
assert_contains "release remains a human-reviewed draft" "$RELEASE" '^[[:space:]]+draft: true$'
assert_not_contains "release does not rebuild" "$RELEASE" 'stack-tools\.sh build'
assert_not_contains "release does not request OIDC" "$RELEASE" 'id-token: write'

assert_action_pins "delivery workflows pin third-party actions" \
  "$BUILD" "$CI_TEST" "$CI" "$ATTEST" "$RELEASE"

# Execute the real package step against controlled root and direct-src fixtures.
# macOS ships BSD tar, so the test adapter removes GNU metadata flags while
# preserving the workflow-selected input paths and creating a real archive.
DELIVERY_TMP="$(mktemp -d "${TMPDIR:-/tmp}/delivery-workflows.XXXXXX")"
trap 'rm -rf "$DELIVERY_TMP"' EXIT HUP INT TERM
DELIVERY_PACKAGE_SCRIPT="$DELIVERY_TMP/package-build.sh"
SYSTEM_TAR="$(command -v tar)"
mkdir -p "$DELIVERY_TMP/bin"
extract_step_run_script "$BUILD" artifact "$DELIVERY_PACKAGE_SCRIPT"
write_portable_tar_adapter "$DELIVERY_TMP/bin/tar"

root_members="$(run_single_stack_python_package root)"
assert_text_contains "root Python archive keeps dist member path" "$root_members" \
  '^dist/example\.whl$'
assert_text_not_contains "root Python archive has no dot-prefixed members" "$root_members" \
  '^\./dist/'

src_members="$(run_single_stack_python_package src)"
assert_text_contains "direct-src Python archive keeps src/dist member path" "$src_members" \
  '^src/dist/example\.whl$'
assert_text_not_contains "direct-src Python archive has no root dist member" "$src_members" \
  '^dist/example\.whl$'

report
