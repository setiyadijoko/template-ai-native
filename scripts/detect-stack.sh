#!/usr/bin/env sh
# Detects the primary stack in the repo root or under src/. Prints a single
# token to stdout (python | node | go | java | dotnet | unknown). Used by
# Makefile + CI to decide which tooling to run. Exit 0 always.
set -eu

has_manifest() {
  [ -f "$1" ] || [ -f "src/$1" ]
}

if has_manifest pyproject.toml || has_manifest setup.py || has_manifest requirements.txt || has_manifest Pipfile; then
  echo "python"; exit 0
fi
if has_manifest package.json; then
  echo "node"; exit 0
fi
if has_manifest go.mod; then
  echo "go"; exit 0
fi
if has_manifest pom.xml || has_manifest build.gradle || has_manifest build.gradle.kts; then
  echo "java"; exit 0
fi
if [ -n "$(find . -maxdepth 1 -name '*.csproj' -print -quit 2>/dev/null)" ] \
  || [ -n "$(find src -maxdepth 1 -name '*.csproj' -print -quit 2>/dev/null)" ] \
  || [ -n "$(find . -maxdepth 1 -name '*.sln' -print -quit 2>/dev/null)" ] \
  || [ -n "$(find src -maxdepth 1 -name '*.sln' -print -quit 2>/dev/null)" ]; then
  echo "dotnet"; exit 0
fi
echo "unknown"
