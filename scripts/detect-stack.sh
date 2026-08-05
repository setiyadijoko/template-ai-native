#!/usr/bin/env sh
# Detects the primary stack in the repo root. Prints a single token to stdout
# (python | node | go | java | dotnet | unknown). Used by Makefile + CI to
# decide which tooling to run. Exit 0 always.
set -eu

if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ] || [ -f "Pipfile" ]; then
  echo "python"; exit 0
fi
if [ -f "package.json" ]; then
  echo "node"; exit 0
fi
if [ -f "go.mod" ]; then
  echo "go"; exit 0
fi
if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  echo "java"; exit 0
fi
# shellcheck disable=SC2046
if [ -n "$(ls *.csproj 2>/dev/null)" ] || [ -n "$(ls *.sln 2>/dev/null)" ]; then
  echo "dotnet"; exit 0
fi
echo "unknown"
