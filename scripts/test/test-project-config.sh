#!/usr/bin/env sh
# Contract tests for the explicit project-layout configuration.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-config.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

mkdir -p "$WORK/.template"
mkdir -p "$WORK/src/backend" "$WORK/src/frontend"

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 1
layout: single
primary_stack: go
primary_path: src
EOF

if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL accepts valid single-layout config\n' >&2
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 1
layout: undecided
primary_stack: auto
primary_path: .
EOF

if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL accepts valid undecided config\n' >&2
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 1
layout: monorepo
primary_stack: go
primary_path: src/backend
EOF

if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL accepts valid monorepo config\n' >&2
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 1
layout: invalid
primary_stack: go
primary_path: src
EOF

if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects invalid layout\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 1
layout: monorepo
primary_stack: auto
primary_path: .
EOF

if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects monorepo path at repository root\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && sh "$ROOT/scripts/detect-stack.sh" >/dev/null 2>"$WORK/detect.err") \
  && [ "$(cd "$WORK" && sh "$ROOT/scripts/detect-stack.sh")" = "unknown" ] \
  && grep -Fq 'monorepo layout selected' "$WORK/detect.err"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL monorepo detection fails safe with guidance\n' >&2
fi

rm -f "$WORK/.template/project.yaml"
if [ "$(cd "$WORK" && sh "$ROOT/scripts/detect-stack.sh")" = "unknown" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL missing config preserves unknown fallback\n' >&2
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
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
  - id: frontend
    path: src/frontend
    stack: node
    required: true
    artifact: frontend
EOF

if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL accepts valid v2 component config\n' >&2
fi

TAB=$(printf '\t')
EXPECTED_TSV="backend${TAB}src/backend${TAB}go${TAB}true${TAB}backend
frontend${TAB}src/frontend${TAB}node${TAB}true${TAB}frontend"
if [ "$(sh "$ROOT/scripts/resolve-components.sh" --tsv "$WORK/.template/project.yaml" 2>/dev/null)" = "$EXPECTED_TSV" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL resolves v2 components as TSV\n' >&2
fi

EXPECTED_JSON='[{"id":"backend","path":"src/backend","stack":"go","required":true,"artifact":"backend"},{"id":"frontend","path":"src/frontend","stack":"node","required":true,"artifact":"frontend"}]'
if [ "$(sh "$ROOT/scripts/resolve-components.sh" --json "$WORK/.template/project.yaml" 2>/dev/null)" = "$EXPECTED_JSON" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL resolves v2 components as JSON\n' >&2
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
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
  - id: backend
    path: src/frontend
    stack: node
    required: true
    artifact: frontend
EOF
if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts duplicate component id\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: ../backend
    stack: go
    required: true
    artifact: backend
EOF
if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts unsafe component path\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: src/backend
    stack: rust
    required: true
    artifact: backend
EOF
if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts unsupported component stack\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: src/backend
    stack: go
    required: true
EOF
if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts component without artifact\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 2
layout: monorepo
primary_stack: auto
primary_path: src/backend
components:
  - id: backend
    path: src/backend
    stack: go
    required: true
    artifact: shared
  - id: frontend
    path: src/frontend
    stack: node
    required: true
    artifact: shared
EOF
if sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts duplicate artifact\n' >&2
else
  PASS=$((PASS+1))
fi

cat > "$WORK/.template/project.yaml" <<'EOF'
version: 1
layout: monorepo
primary_stack: go
primary_path: src/backend
EOF
if sh "$ROOT/scripts/resolve-components.sh" --validate "$WORK/.template/project.yaml" >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL resolves version-1 monorepo without components\n' >&2
else
  PASS=$((PASS+1))
fi

report
