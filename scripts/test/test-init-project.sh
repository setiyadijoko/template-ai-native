#!/usr/bin/env sh
# Contract tests for the README identity and project-layout initializer.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

TICK='`'
EXPECTED_NODE_STACK="**Stack:** ${TICK}node${TICK}"
EXPECTED_AUTO_STACK="**Stack:** ${TICK}auto${TICK}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-init.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

cp "$ROOT/README.md" "$WORK/README.md"

if [ -x "$ROOT/scripts/init-project.sh" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL initializer is executable\n' >&2
fi

if (cd "$WORK" && sh "$ROOT/scripts/init-project.sh" \
  --name "sample-orders" \
  --description "Order processing service" \
  --stack node --layout single --primary-path src) >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL initializes a fresh README\n' >&2
fi

if grep -Fq '# sample-orders' "$WORK/README.md" \
  && grep -Fq 'Order processing service' "$WORK/README.md" \
  && grep -Fq "$EXPECTED_NODE_STACK" "$WORK/README.md" \
  && grep -Fq 'layout: single' "$WORK/.template/project.yaml" \
  && grep -Fq 'primary_stack: node' "$WORK/.template/project.yaml" \
  && grep -Fq 'primary_path: src' "$WORK/.template/project.yaml"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL writes project identity to README\n' >&2
fi

if (cd "$WORK" && sh "$ROOT/scripts/init-project.sh" \
  --name "replacement" --description "Must not overwrite") >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL refuses implicit reconfiguration\n' >&2
else
  PASS=$((PASS+1))
fi

if grep -Fq '# sample-orders' "$WORK/README.md" \
  && ! grep -Fq '# replacement' "$WORK/README.md"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL preserves README after refused reconfiguration\n' >&2
fi

printf '\nConsumer documentation outside the identity block.\n' >> "$WORK/README.md"

if (cd "$WORK" && sh "$ROOT/scripts/init-project.sh" \
  --reconfigure --name "replacement" \
  --description "Replacement service" --stack auto \
  --layout monorepo \
  --component backend=src/backend:go \
  --component frontend=src/frontend:node) >/dev/null 2>&1 \
  && grep -Fq '# replacement' "$WORK/README.md" \
  && grep -Fq 'Replacement service' "$WORK/README.md" \
  && grep -Fq "$EXPECTED_AUTO_STACK" "$WORK/README.md" \
  && grep -Fq 'layout: monorepo' "$WORK/.template/project.yaml" \
  && grep -Fq 'version: 2' "$WORK/.template/project.yaml" \
  && grep -Fq 'primary_stack: auto' "$WORK/.template/project.yaml" \
  && grep -Fq 'primary_path: src/backend' "$WORK/.template/project.yaml" \
  && grep -Fq 'id: backend' "$WORK/.template/project.yaml" \
  && grep -Fq 'path: src/frontend' "$WORK/.template/project.yaml" \
  && grep -Fq 'stack: node' "$WORK/.template/project.yaml" \
  && sh "$ROOT/scripts/validate-project-config.sh" "$WORK/.template/project.yaml" >/dev/null 2>&1 \
  && [ "$(sh "$ROOT/scripts/resolve-components.sh" --json "$WORK/.template/project.yaml")" = '[{"id":"backend","path":"src/backend","stack":"go","required":true,"artifact":"backend"},{"id":"frontend","path":"src/frontend","stack":"node","required":true,"artifact":"frontend"}]' ] \
  && grep -Fq 'Consumer documentation outside the identity block.' "$WORK/README.md"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL explicitly reconfigures README\n' >&2
fi

cp "$ROOT/README.md" "$WORK/missing-marker.md"
sed '/template-ai-native:project-identity:start/,/template-ai-native:project-identity:end/d' \
  "$WORK/missing-marker.md" > "$WORK/README-no-marker.md"
if (cd "$WORK" && cp README-no-marker.md README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "missing-marker") >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects README without identity markers\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$ROOT/README.md" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "bad" --stack rust) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects unsupported stack\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$ROOT/README.md" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "missing-components" \
  --layout monorepo --primary-path src/backend) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts non-interactive monorepo without components\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$ROOT/README.md" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "bad-component" \
  --layout monorepo --component backend=src/backend:rust) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts unsupported component stack\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$ROOT/README.md" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "duplicate-component" \
  --layout monorepo \
  --component backend=src/backend:go \
  --component backend=src/other:node) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts duplicate component id\n' >&2
else
  PASS=$((PASS+1))
fi

MULTILINE='line one
line two'
if (cd "$WORK" && cp "$ROOT/README.md" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "bad" --description "$MULTILINE") >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects multiline description\n' >&2
else
  PASS=$((PASS+1))
fi

MULTILINE_NAME='bad
name'
if (cd "$WORK" && cp "$ROOT/README.md" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "$MULTILINE_NAME") >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects multiline project name\n' >&2
else
  PASS=$((PASS+1))
fi

report
