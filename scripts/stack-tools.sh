#!/usr/bin/env sh
# stack-tools.sh — pure mapper: prints the tool command for a given action
# based on the detected stack (see detect-stack.sh). Does NOT execute tools.
#
# Usage: stack-tools.sh <action>
#   actions: format | format-check | lint | typecheck | test | test-unit |
#            test-integration | test-e2e | coverage | build
# Exits: 0 (printed command or "no-op"), 64 (invalid action).
set -eu

ACTION="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
STACK="$(sh "$HERE/detect-stack.sh")"

case "$ACTION" in
  format) ;;
  format-check) ;;
  lint) ;;
  typecheck) ;;
  test) ACTION=test-unit ;;   # `test` is an alias for the unit run
  test-unit) ;;
  test-integration) ;;
  test-e2e) ;;
  coverage) ;;
  build) ;;
  *)
    printf 'usage: stack-tools.sh <action>\n  actions: format|format-check|lint|typecheck|test|test-unit|test-integration|test-e2e|coverage|build\n' >&2
    exit 64
    ;;
esac

# Per-(stack, action) command table. Unknown stack => no-op.
case "$STACK:$ACTION" in
  python:format)            echo "ruff format ." ;;
  python:format-check)      echo "ruff format --check ." ;;
  python:lint)              echo "ruff check ." ;;
  python:typecheck)         echo "mypy src" ;;
  python:test-unit)         echo "pytest -q tests/unit" ;;
  python:test-integration)  echo "pytest -q tests/integration" ;;
  python:test-e2e)          echo "pytest -q tests/e2e" ;;
  python:coverage)          echo "pytest --cov=src --cov-report=xml --cov-report=term --cov-fail-under=80 tests/unit" ;;
  python:build)             echo "python -m build" ;;

  node:format)              echo "prettier --write ." ;;
  node:format-check)        echo "prettier --check ." ;;
  node:lint)                echo "eslint ." ;;
  node:typecheck)           echo "tsc --noEmit" ;;
  node:test-unit)           echo "vitest run --dir tests/unit" ;;
  node:test-integration)    echo "vitest run --dir tests/integration" ;;
  node:test-e2e)            echo "vitest run --dir tests/e2e" ;;
  node:coverage)            echo "vitest run --coverage --coverage.thresholds.lines=80" ;;
  node:build)               echo "npm run build" ;;

  go:format)                echo "gofmt -w ." ;;
  go:format-check)          echo "gofmt -l ." ;;
  go:lint)                  echo "golangci-lint run" ;;
  go:typecheck)             echo "go vet ./..." ;;
  go:test-unit)             echo "go test -short ./..." ;;
  go:test-integration)      echo "go test -run Integration ./..." ;;
  go:test-e2e)              echo "go test -run E2E ./..." ;;
  go:coverage)              echo "go test -coverprofile=coverage.out -covermode=atomic ./..." ;;
  go:build)                 echo "go build -o bin/ ./..." ;;

  java:format)              echo "mvn -q spotless:apply" ;;
  java:format-check)        echo "mvn -q spotless:check" ;;
  java:lint)                echo "mvn -q checkstyle:check" ;;
  java:typecheck)           echo "mvn -q compile" ;;
  java:test-unit)           echo "mvn -q test" ;;
  java:test-integration)    echo "mvn -q verify -Dtest='*IT'" ;;
  java:test-e2e)            echo "mvn -q verify -Dtest='*E2E'" ;;
  java:coverage)            echo "mvn -q verify -Pcoverage" ;;
  java:build)               echo "mvn -q -DskipTests package" ;;

  dotnet:format)            echo "dotnet format" ;;
  dotnet:format-check)      echo "dotnet format --verify-no-changes" ;;
  dotnet:lint)              echo "dotnet format --verify-no-changes" ;;
  dotnet:typecheck)         echo "dotnet build" ;;
  dotnet:test-unit)         echo "dotnet test --filter Category=Unit" ;;
  dotnet:test-integration)  echo "dotnet test --filter Category=Integration" ;;
  dotnet:test-e2e)          echo "dotnet test --filter Category=E2E" ;;
  dotnet:coverage)          echo 'dotnet test --collect:"XPlat Code Coverage" /p:CoverletOutputFormat=cobertura' ;;
  dotnet:build)             echo "dotnet build -c Release" ;;

  *:*)
    echo "no-op"
    ;;
esac
