#!/usr/bin/env sh
# Tests for detect-stack.sh and stack-tools.sh. Creates temp manifests and
# asserts the mapper returns the right command per (stack, action).
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
cd "$WORK"
TOOL="sh $ROOT/scripts/stack-tools.sh"
DET="sh $ROOT/scripts/detect-stack.sh"

# --- detect-stack.sh ---
printf '' > pyproject.toml
assert_eq "detect python" "$($DET)" "python"
rm -f pyproject.toml
printf '{}' > package.json
assert_eq "detect node" "$($DET)" "node"
rm -f package.json
printf 'module x\n' > go.mod
assert_eq "detect go" "$($DET)" "go"
rm -f go.mod
printf '<project></project>' > pom.xml
assert_eq "detect java" "$($DET)" "java"
rm -f pom.xml
printf '<Project Sdk="Microsoft.NET.Sdk"></Project>' > app.csproj
assert_eq "detect dotnet" "$($DET)" "dotnet"
rm -f app.csproj
assert_eq "detect unknown (empty)" "$($DET)" "unknown"

# Consumer stacks may live under src/ as documented by the template.
mkdir src
printf '' > src/pyproject.toml
assert_eq "detect python under src" "$($DET)" "python"
rm -f src/pyproject.toml
printf '{}' > src/package.json
assert_eq "detect node under src" "$($DET)" "node"
rm -f src/package.json
printf 'module x\n' > src/go.mod
assert_eq "detect go under src" "$($DET)" "go"
rm -f src/go.mod
printf '<project></project>' > src/pom.xml
assert_eq "detect java under src" "$($DET)" "java"
rm -f src/pom.xml
printf '<Project Sdk="Microsoft.NET.Sdk"></Project>' > src/app.csproj
assert_eq "detect dotnet under src" "$($DET)" "dotnet"
rm -f src/app.csproj
rmdir src

# --- stack-tools.sh: unknown stack -> no-op, exit 0 ---
for action in format format-check lint typecheck test test-unit test-integration test-e2e coverage build; do
  out=$($TOOL "$action" 2>&1 || true)
  assert_eq "unknown/$action output" "$out" "no-op"
  assert_exit "unknown/$action exit" 0 sh "$ROOT/scripts/stack-tools.sh" "$action"
done

# --- stack-tools.sh: invalid action -> exit 64 ---
assert_exit "invalid action exit" 64 sh "$ROOT/scripts/stack-tools.sh" frobnicate

# --- per-stack mapping (representative actions) ---
printf '' > pyproject.toml
assert_eq "python format" "$($TOOL format)" "ruff format ."
assert_eq "python lint" "$($TOOL lint)" "ruff check ."
assert_eq "python coverage" "$($TOOL coverage)" "pytest --cov=src --cov-report=xml --cov-report=term --cov-fail-under=80 tests/unit"
assert_eq "python build" "$($TOOL build)" "python -m build"
rm -f pyproject.toml

printf '{}' > package.json
assert_eq "node format-check" "$($TOOL format-check)" "prettier --check ."
assert_eq "node typecheck" "$($TOOL typecheck)" "tsc --noEmit"
assert_eq "node test-unit" "$($TOOL test-unit)" "vitest run --dir tests/unit"
rm -f package.json

printf 'module x\n' > go.mod
assert_eq "go lint" "$($TOOL lint)" "golangci-lint run"
assert_eq "go typecheck" "$($TOOL typecheck)" "go vet ./..."
assert_eq "go format-check" "$($TOOL format-check)" 'test -z "$(gofmt -l .)"'
assert_eq "go build" "$($TOOL build)" "go build -o bin/ ./..."
rm -f go.mod

printf '<project></project>' > pom.xml
assert_eq "java format-check" "$($TOOL format-check)" "mvn -q spotless:check"
assert_eq "java test-unit" "$($TOOL test-unit)" "mvn -q test"
assert_eq "java build" "$($TOOL build)" "mvn -q -DskipTests package"
rm -f pom.xml

printf '<Project Sdk="Microsoft.NET.Sdk"></Project>' > app.csproj
assert_eq "dotnet format-check" "$($TOOL format-check)" "dotnet format --verify-no-changes"
assert_eq "dotnet test-unit" "$($TOOL test-unit)" "dotnet test --filter Category=Unit"
assert_eq "dotnet build" "$($TOOL build)" "dotnet build -c Release"
rm -f app.csproj

# A version-2 monorepo is resolved by component-aware CI, not this
# single-stack detector.
mkdir -p .template src/backend
cat > .template/project.yaml <<'EOF'
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: src/backend
    stack: go
    required: true
    artifact: backend
EOF
assert_eq "detect declared v2 monorepo" "$($DET 2>/dev/null)" "unknown"
rm -rf .template src

report
