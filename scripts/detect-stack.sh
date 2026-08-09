#!/usr/bin/env sh
# Detects the primary stack in the repo root or under src/. Prints a single
# token to stdout (python | node | go | java | dotnet | unknown). Used by
# Makefile + CI to decide which tooling to run. Exit 0 always.
set -eu

# A monorepo declaration is explicit. Return unknown here rather than guessing
# a nested service or running the single-stack toolchain against the wrong
# directory; the CI dispatcher resolves version-2 components separately.
if [ -f ".template/project.yaml" ]; then
  layout="$(awk -F ':[[:space:]]*' '$1 == "layout" { print $2; exit }' .template/project.yaml)"
  if [ "$layout" = "monorepo" ]; then
    version="$(awk -F ':[[:space:]]*' '$1 == "version" { print $2; exit }' .template/project.yaml)"
    if [ "$version" = '2' ]; then
      printf '%s\n' 'monorepo layout selected; component-aware CI resolves explicit components, so single-stack detection is skipped.' >&2
    else
      printf '%s\n' 'monorepo layout selected; migrate to version 2 components before enabling component-aware CI.' >&2
    fi
    echo "unknown"
    exit 0
  fi
fi

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
