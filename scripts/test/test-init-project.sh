#!/usr/bin/env sh
# Contract tests for the README identity and project-layout initializer.
set -eu

# Automated contracts must not inherit an interactive terminal.
exec </dev/null

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"
README_FIXTURE="$HERE/fixtures/init-project-README.md"

if [ ! -f "$README_FIXTURE" ]; then
  printf 'FAIL dedicated fresh README fixture is available\n' >&2
  exit 1
fi
if grep -Fq '<!-- template-ai-native:project-identity:generated -->' "$README_FIXTURE"; then
  printf 'FAIL dedicated README fixture is already initialized\n' >&2
  exit 1
fi

TICK='`'
EXPECTED_NODE_STACK="**Stack:** ${TICK}node${TICK}"
EXPECTED_AUTO_STACK="**Stack:** ${TICK}auto${TICK}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/template-ai-native-init.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

profile_scalar() {
  file="$1"; key="$2"
  awk -v key="$key" '
    $0 ~ "^" key ":[[:space:]]*" {
      value = $0
      sub("^" key ":[[:space:]]*", "", value)
      print value
      exit
    }
  ' "$file"
}

profile_value() {
  file="$1"; section="$2"; key="$3"
  awk -v section="$section" -v key="$key" '
    $0 == section ":" { inside=1; next }
    inside && /^[^ ]/ { exit }
    inside && $0 ~ "^  " key ":[[:space:]]*" {
      value = $0
      sub("^  " key ":[[:space:]]*", "", value)
      print value
      exit
    }
  ' "$file"
}

assert_config_directory_rejected() {
  label="$1"; target="$2"; reconfigure="$3"
  case_work="$WORK/config-directory-$target-$reconfigure"
  mkdir -p "$case_work/.template/$target"
  cp "$README_FIXTURE" "$case_work/README.md"

  if [ "$reconfigure" = yes ]; then
    if (cd "$case_work" && sh "$ROOT/scripts/init-project.sh" \
      --reconfigure --name directory-target --profile standard \
      --layout single) >/dev/null 2>&1; then
      rejected=no
    else
      rejected=yes
    fi
  elif (cd "$case_work" && sh "$ROOT/scripts/init-project.sh" \
    --name directory-target --profile standard \
    --layout single) >/dev/null 2>&1; then
    rejected=no
  else
    rejected=yes
  fi

  target_entries="$(find "$case_work/.template/$target" -type f -print)"
  if [ "$rejected" = yes ] \
    && cmp -s "$README_FIXTURE" "$case_work/README.md" \
    && [ -d "$case_work/.template/$target" ] \
    && [ ! -f "$case_work/.template/project.yaml" ] \
    && [ ! -f "$case_work/.template/profile.yaml" ] \
    && [ -z "$target_entries" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$label" >&2
  fi
}

assert_config_symlink_rejected() {
  label="$1"; target="$2"; link_kind="$3"; reconfigure="$4"
  case_work="$WORK/config-symlink-$target-$link_kind-$reconfigure"
  link_path="$case_work/.template/$target"
  link_target="$case_work/$target-target"
  mkdir -p "$case_work/.template"
  cp "$README_FIXTURE" "$case_work/README.md"

  if [ "$link_kind" = regular ]; then
    printf '%s\n' 'preserve symlink target' > "$link_target"
  fi
  ln -s "../$target-target" "$link_path"

  if [ "$reconfigure" = yes ]; then
    if (cd "$case_work" && sh "$ROOT/scripts/init-project.sh" \
      --reconfigure --name symlink-target --profile standard \
      --layout single) >/dev/null 2>&1; then
      rejected=no
    else
      rejected=yes
    fi
  elif (cd "$case_work" && sh "$ROOT/scripts/init-project.sh" \
    --name symlink-target --profile standard \
    --layout single) >/dev/null 2>&1; then
    rejected=no
  else
    rejected=yes
  fi

  if [ "$link_kind" = regular ]; then
    if [ -L "$link_path" ] && [ -f "$link_path" ] \
      && grep -Fxq 'preserve symlink target' "$link_target"; then
      link_preserved=yes
    else
      link_preserved=no
    fi
  elif [ -L "$link_path" ] && [ ! -e "$link_path" ] \
    && [ ! -e "$link_target" ]; then
    link_preserved=yes
  else
    link_preserved=no
  fi

  if [ "$target" = project.yaml ]; then
    other_target="$case_work/.template/profile.yaml"
  else
    other_target="$case_work/.template/project.yaml"
  fi

  if [ "$rejected" = yes ] && [ "$link_preserved" = yes ] \
    && cmp -s "$README_FIXTURE" "$case_work/README.md" \
    && [ ! -e "$other_target" ] && [ ! -L "$other_target" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$label" >&2
  fi
}

cp "$README_FIXTURE" "$WORK/README.md"

if [ -x "$ROOT/scripts/init-project.sh" ]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL initializer is executable\n' >&2
fi

if (cd "$WORK" && sh "$ROOT/scripts/init-project.sh" \
  --name "sample-orders" \
  --description "Order processing service" \
  --stack node --layout single --primary-path src --profile standard) >/dev/null 2>&1; then
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

if grep -Fq 'profile: standard' "$WORK/.template/profile.yaml" \
  && grep -Fq 'type: other' "$WORK/.template/profile.yaml" \
  && grep -Fq 'primary: node' "$WORK/.template/profile.yaml" \
  && [ "$(profile_value "$WORK/.template/profile.yaml" ai enabled)" = false ] \
  && [ "$(profile_value "$WORK/.template/profile.yaml" deployment enabled)" = false ] \
  && grep -Fq 'semantic_review: advisory' "$WORK/.template/profile.yaml" \
  && grep -Fq 'structural_review: advisory' "$WORK/.template/profile.yaml" \
  && grep -Fq 'codeql: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'coverage: true' "$WORK/.template/profile.yaml" \
  && sh "$ROOT/scripts/validate-profile-config.sh" \
    "$WORK/.template/profile.yaml" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL writes a valid Standard profile\n' >&2
fi

if (cd "$WORK" && sh "$ROOT/scripts/init-project.sh" \
  --name "replacement" --description "Must not overwrite" \
  --profile standard) >/dev/null 2>&1; then
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
  --component frontend=src/frontend:node \
  --profile enterprise --project-type api --ai-enabled true \
  --deployment-target cloud) >/dev/null 2>&1 \
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
  && grep -Fq 'profile: enterprise' "$WORK/.template/profile.yaml" \
  && grep -Fq 'type: api' "$WORK/.template/profile.yaml" \
  && [ "$(profile_value "$WORK/.template/profile.yaml" ai enabled)" = true ] \
  && grep -Fq 'evaluation: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'semantic_review: enabled' "$WORK/.template/profile.yaml" \
  && grep -Fq 'structural_review: enabled' "$WORK/.template/profile.yaml" \
  && grep -Fq 'target: cloud' "$WORK/.template/profile.yaml" \
  && grep -Fq 'codeql: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'coverage: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'sbom: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'artifact_attestation: true' "$WORK/.template/profile.yaml" \
  && grep -Fq 'scorecard: true' "$WORK/.template/profile.yaml" \
  && [ "$(profile_value "$WORK/.template/profile.yaml" deployment enabled)" = true ] \
  && sh "$ROOT/scripts/validate-profile-config.sh" "$WORK/.template/profile.yaml" >/dev/null 2>&1 \
  && [ "$(sh "$ROOT/scripts/resolve-components.sh" --json "$WORK/.template/project.yaml")" = '[{"id":"backend","path":"src/backend","stack":"go","required":true,"artifact":"backend"},{"id":"frontend","path":"src/frontend","stack":"node","required":true,"artifact":"frontend"}]' ] \
  && [ "$(grep -F -c '<!-- template-ai-native:project-identity:generated -->' "$WORK/README.md")" -eq 1 ] \
  && grep -Fq 'Consumer documentation outside the identity block.' "$WORK/README.md"; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL explicitly reconfigures README\n' >&2
fi

assert_config_directory_rejected \
  'rejects project config directory target' project.yaml no
assert_config_directory_rejected \
  'rejects project config directory target with reconfigure' project.yaml yes
assert_config_directory_rejected \
  'rejects profile config directory target' profile.yaml no
assert_config_directory_rejected \
  'rejects profile config directory target with reconfigure' profile.yaml yes
assert_config_symlink_rejected \
  'rejects project config symlink to regular file' project.yaml regular no
assert_config_symlink_rejected \
  'rejects project config symlink to regular file with reconfigure' \
  project.yaml regular yes
assert_config_symlink_rejected \
  'rejects dangling profile config symlink' profile.yaml dangling no
assert_config_symlink_rejected \
  'rejects dangling profile config symlink with reconfigure' \
  profile.yaml dangling yes

STARTER_WORK="$WORK/starter-defaults"
mkdir -p "$STARTER_WORK"
cp "$README_FIXTURE" "$STARTER_WORK/README.md"
if (cd "$STARTER_WORK" && sh "$ROOT/scripts/init-project.sh" \
  --name starter-defaults --profile starter --layout single) >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL generates a default Starter profile\n' >&2
fi

STARTER_PROFILE="$STARTER_WORK/.template/profile.yaml"
STARTER_PROJECT="$STARTER_WORK/.template/project.yaml"
assert_eq 'Starter version' "$(profile_scalar "$STARTER_PROFILE" version)" '1'
assert_eq 'Starter profile' "$(profile_scalar "$STARTER_PROFILE" profile)" 'starter'
while IFS='|' read -r section key expected; do
  assert_eq "Starter $section.$key" \
    "$(profile_value "$STARTER_PROFILE" "$section" "$key")" "$expected"
done <<'STARTER_MATRIX'
project|type|other
stack|primary|auto
ai|enabled|false
ai|evaluation|false
ai|semantic_review|off
ai|structural_review|off
deployment|enabled|false
deployment|target|none
controls|secret_scan|true
controls|dependency_review|true
controls|codeql|false
controls|coverage|false
controls|sbom|false
controls|artifact_attestation|false
controls|scorecard|false
STARTER_MATRIX

if sh "$ROOT/scripts/validate-project-config.sh" "$STARTER_PROJECT" >/dev/null 2>&1 \
  && sh "$ROOT/scripts/validate-profile-config.sh" "$STARTER_PROFILE" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); printf 'FAIL generated Starter configs validate\n' >&2
fi

if STARTER_POLICY="$(sh "$ROOT/scripts/resolve-profile-policy.sh" \
  "$STARTER_PROFILE" "$ROOT/.template/profile-controls.yaml" \
  "$STARTER_PROJECT" 2>/dev/null)"; then
  assert_eq 'generated Starter policy mode' \
    "$(printf '%s\n' "$STARTER_POLICY" | sed -n 's/^mode=//p')" 'profile'
  assert_eq 'generated Starter policy profile' \
    "$(printf '%s\n' "$STARTER_POLICY" | sed -n 's/^profile=//p')" 'starter'
  assert_eq 'generated Starter policy alignment' \
    "$(printf '%s\n' "$STARTER_POLICY" | sed -n 's/^status=//p')" 'aligned'
else
  FAIL=$((FAIL+1)); printf 'FAIL resolves generated Starter policy\n' >&2
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  rm -f .template/project.yaml .template/profile.yaml && \
  sh "$ROOT/scripts/init-project.sh" --name missing-profile \
    --layout single </dev/null) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts non-interactive init without profile\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  rm -f .template/project.yaml .template/profile.yaml && \
  sh "$ROOT/scripts/init-project.sh" --name bad-profile \
    --profile premium --layout single) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts unsupported profile\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  rm -f .template/project.yaml .template/profile.yaml && \
  sh "$ROOT/scripts/init-project.sh" --name enterprise-without-target \
    --profile enterprise --layout single) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts Enterprise without deployment target\n' >&2
else
  PASS=$((PASS+1))
fi

cp "$README_FIXTURE" "$WORK/missing-marker.md"
sed '/template-ai-native:project-identity:start/,/template-ai-native:project-identity:end/d' \
  "$WORK/missing-marker.md" > "$WORK/README-no-marker.md"
if (cd "$WORK" && cp README-no-marker.md README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "missing-marker" \
    --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects README without identity markers\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "bad" --stack rust \
    --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects unsupported stack\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "missing-components" \
  --layout monorepo --primary-path src/backend --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts non-interactive monorepo without components\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "bad-component" \
  --layout monorepo --component backend=src/backend:rust \
  --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts unsupported component stack\n' >&2
else
  PASS=$((PASS+1))
fi

if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "duplicate-component" \
  --layout monorepo \
  --component backend=src/backend:go \
  --component backend=src/other:node --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL accepts duplicate component id\n' >&2
else
  PASS=$((PASS+1))
fi

MULTILINE='line one
line two'
if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "bad" --description "$MULTILINE" \
    --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects multiline description\n' >&2
else
  PASS=$((PASS+1))
fi

MULTILINE_NAME='bad
name'
if (cd "$WORK" && cp "$README_FIXTURE" README.md && \
  sh "$ROOT/scripts/init-project.sh" --name "$MULTILINE_NAME" \
    --profile standard) >/dev/null 2>&1; then
  FAIL=$((FAIL+1)); printf 'FAIL rejects multiline project name\n' >&2
else
  PASS=$((PASS+1))
fi

report
