#!/usr/bin/env sh
# Structural contracts for explicit component-aware monorepo CI.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

CI="$ROOT/.github/workflows/ci.yml"
CI_QUALITY="$ROOT/.github/workflows/ci-quality.yml"
CI_TEST="$ROOT/.github/workflows/ci-test.yml"
BUILD="$ROOT/.github/workflows/build.yml"
MONO="$ROOT/.github/workflows/ci-monorepo.yml"
RESOLVER="$ROOT/scripts/resolve-components.sh"

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

run_component_python_package() {
  layout="$1"
  case_root="$MONOREPO_TMP/$layout"
  project="$case_root/project"
  runner_temp="$case_root/runner"
  github_output="$case_root/github-output"

  mkdir -p "$project" "$runner_temp"
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
    PATH="$MONOREPO_TMP/bin:$PATH" \
      SYSTEM_TAR="$SYSTEM_TAR" \
      GITHUB_WORKSPACE="$ROOT" \
      COMPONENT_ID=fixture \
      COMPONENT_PATH=. \
      COMPONENT_STACK=python \
      GITHUB_SHA=0123456789abcdef \
      RUNNER_TEMP="$runner_temp" \
      GITHUB_OUTPUT="$github_output" \
      bash "$MONOREPO_PACKAGE_SCRIPT"
  )

  "$SYSTEM_TAR" -tzf "$runner_temp/build-fixture.tar.gz"
}

assert_pins() {
  invalid="$(sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$CI_QUALITY" "$MONO" | grep -Ev '^[^[:space:]#]+@[0-9a-f]{40}([[:space:]]+#.*)?$' || true)"
  if [ -z "$invalid" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL Go quality workflows pin actions\n%s\n' "$invalid" >&2
  fi
}

assert_golangci_installer() {
  gci_label="$1"
  gci_file="$2"
  assert_contains "$gci_label pins official action" "$gci_file" \
    'uses: golangci/golangci-lint-action@ba0d7d2ec06a0ea1cb5fa41b2e4a3ab91d21278a[[:space:]]+# v9\.3\.0'
  assert_contains "$gci_label pins linter version" "$gci_file" \
    'version:[[:space:]]+v2\.12\.2([[:space:]]|$)'
  assert_contains "$gci_label installs without duplicate lint run" "$gci_file" \
    'install-only:[[:space:]]+true([[:space:]]|$)'
}

assert_concurrency_suffix() {
  label="$1"
  file="$2"
  suffix="$3"
  group="$(awk '
    /^concurrency:[[:space:]]*$/ { inside=1; next }
    inside && /^[^[:space:]]/ { exit }
    inside && /^[[:space:]]+group:/ {
      sub(/^[[:space:]]+group:[[:space:]]*/, "")
      print
      exit
    }
  ' "$file")"
  case "$group" in
    *"-$suffix-"*) PASS=$((PASS+1)) ;;
    *)
      FAIL=$((FAIL+1))
      printf 'FAIL %s\n     concurrency group lacks unique suffix %s: %s\n' \
        "$label" "$suffix" "$group" >&2
      ;;
  esac
}

assert_contains "dispatcher exposes layout" "$CI" 'layout:.*steps\.d\.outputs\.layout'
assert_contains "dispatcher calls monorepo workflow" "$CI" 'uses: ./\.github/workflows/ci-monorepo\.yml'
assert_contains "dispatcher exposes safe component output" "$CI" 'component_ready:.*steps\.d\.outputs\.component_ready'
assert_contains "dispatcher gates monorepo workflow" "$CI" "component_ready == 'true'"
assert_contains "resolver is executable" "$RESOLVER" 'version: 2'

# Called workflows inherit github.workflow from the caller. A reusable workflow
# must therefore add its own stable suffix or its cancel-in-progress group can
# cancel the top-level dispatcher for the same ref.
assert_concurrency_suffix "quality workflow isolates concurrency" "$CI_QUALITY" 'ci-quality'
assert_concurrency_suffix "test workflow isolates concurrency" "$CI_TEST" 'ci-test'
assert_concurrency_suffix "build workflow isolates concurrency" "$BUILD" 'build'
assert_concurrency_suffix "monorepo workflow isolates concurrency" "$MONO" 'ci-monorepo'

assert_contains "monorepo workflow is reusable" "$MONO" 'workflow_call:'
assert_contains "monorepo workflow validates config" "$MONO" 'resolve-components\.sh --validate'
assert_contains "monorepo workflow emits JSON" "$MONO" 'resolve-components\.sh --json'
assert_contains "monorepo matrix uses explicit components" "$MONO" 'fromJSON\(needs\.resolve\.outputs\.components\)'
assert_contains "monorepo quality check name" "$MONO" 'monorepo / quality /'
assert_contains "monorepo test check name" "$MONO" 'monorepo / test /'
assert_contains "monorepo build check name" "$MONO" 'monorepo / build /'
assert_contains "monorepo aggregate check" "$MONO" 'monorepo / aggregate'
assert_contains "monorepo preserves Go coverage gate" "$MONO" 'Enforce go coverage >= 80%'
assert_contains "monorepo retains recursive .NET coverage" "$MONO" \
  'matrix[.]component[.]path.*TestResults/[*][*]/coverage[.]cobertura[.]xml'
assert_contains "single-stack quality uses Python dependency helper" "$CI_QUALITY" \
  'run: sh scripts/setup-python-deps\.sh'
assert_contains "single-stack test uses Python dependency helper" "$CI_TEST" \
  'run: sh scripts/setup-python-deps\.sh'
assert_contains "single-stack build uses Python dependency helper" "$BUILD" \
  'run: sh scripts/setup-python-deps\.sh'
assert_eq "all component Python jobs use dependency helper" \
  "$(grep -Ec 'run: sh "[$]GITHUB_WORKSPACE/scripts/setup-python-deps\.sh"' "$MONO" || true)" \
  "3"
assert_not_contains "quality has no inline Python tool install" "$CI_QUALITY" \
  'pip install ruff mypy pytest pytest-cov build'
assert_not_contains "test has no inline Python tool install" "$CI_TEST" \
  'pip install ruff mypy pytest pytest-cov build'
assert_not_contains "build has no inline Python tool install" "$BUILD" \
  'pip install ruff mypy pytest pytest-cov build'
assert_not_contains "monorepo has no inline Python tool install" "$MONO" \
  'pip install ruff mypy pytest pytest-cov build'
assert_contains "single-stack workflow uses shared Go coverage helper" "$CI_TEST" 'run: sh scripts/enforce-go-coverage\.sh'
assert_contains "monorepo workflow uses shared Go coverage helper" "$MONO" 'run: sh "[$]GITHUB_WORKSPACE/scripts/enforce-go-coverage\.sh"'
assert_contains "component working directory" "$MONO" 'working-directory:.*matrix\.component\.path'
assert_contains "component artifact upload" "$MONO" 'build-\$\{\{ matrix\.component\.id \}\}'
assert_contains "artifact metadata commit" "$MONO" 'GITHUB_SHA'
assert_contains "component Python packaging resolves project directory" "$MONO" \
  'project_dir="[$][(]sh "[$]GITHUB_WORKSPACE/scripts/resolve-python-project-dir\.sh"[)]"'
assert_contains "component Python packaging selects literal root dist" "$MONO" \
  '[.][)] artifact_dir=dist ;;'
assert_contains "component Python packaging selects direct-src dist" "$MONO" \
  'src[)] artifact_dir=src/dist ;;'
assert_contains "component Python packaging adds normalized dist" "$MONO" \
  'add_tree "[$]artifact_dir"'
assert_not_contains "component Python packaging rejects dot-prefixed dist input" "$MONO" \
  'add_tree "[$]project_dir/dist"'
assert_not_contains "monorepo workflow has no pull request target" "$MONO" 'pull_request_target:'
assert_golangci_installer "single-stack Go lint" "$CI_QUALITY"
assert_golangci_installer "monorepo Go lint" "$MONO"
assert_pins

# Execute the real component package step against controlled root and
# direct-src fixtures. The local adapter only removes GNU tar flags unsupported
# by macOS BSD tar; it preserves the workflow-selected paths in a real archive.
MONOREPO_TMP="$(mktemp -d "${TMPDIR:-/tmp}/monorepo-ci.XXXXXX")"
trap 'rm -rf "$MONOREPO_TMP"' EXIT HUP INT TERM
MONOREPO_PACKAGE_SCRIPT="$MONOREPO_TMP/package-component.sh"
SYSTEM_TAR="$(command -v tar)"
mkdir -p "$MONOREPO_TMP/bin"
extract_step_run_script "$MONO" package "$MONOREPO_PACKAGE_SCRIPT"
write_portable_tar_adapter "$MONOREPO_TMP/bin/tar"

root_members="$(run_component_python_package root)"
assert_text_contains "component root Python archive keeps dist member path" "$root_members" \
  '^dist/example\.whl$'
assert_text_not_contains "component root Python archive has no dot-prefixed members" "$root_members" \
  '^\./dist/'

src_members="$(run_component_python_package src)"
assert_text_contains "component direct-src Python archive keeps src/dist member path" "$src_members" \
  '^src/dist/example\.whl$'
assert_text_not_contains "component direct-src Python archive has no root dist member" "$src_members" \
  '^dist/example\.whl$'

report
