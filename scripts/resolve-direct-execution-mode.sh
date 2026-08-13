#!/usr/bin/env sh
set -eu

die() {
  printf 'direct-execution-mode: %s\n' "$1" >&2
  exit 1
}

[ "$#" -le 2 ] || die 'usage: resolve-direct-execution-mode.sh [PROJECT_PATH] [PROFILE_PATH]'
PROJECT_CONFIG="${1:-.template/project.yaml}"
PROFILE_CONFIG="${2:-.template/profile.yaml}"

case "${SOURCE_EVENT:-pull_request}" in
  schedule|workflow_dispatch)
    printf '%s\n' 'direct_profile_controls=true'
    exit 0
    ;;
  pull_request|push)
    ;;
  *)
    die 'unsupported source event'
    ;;
esac

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

project_exists=false
profile_exists=false
if path_exists "$PROJECT_CONFIG"; then project_exists=true; fi
if path_exists "$PROFILE_CONFIG"; then profile_exists=true; fi

case "$project_exists:$profile_exists" in
  false:false)
    printf '%s\n' 'direct_profile_controls=true'
    ;;
  true:true)
    [ -f "$PROJECT_CONFIG" ] && [ ! -L "$PROJECT_CONFIG" ] \
      || die 'project config must be a regular non-symlink file'
    [ -f "$PROFILE_CONFIG" ] && [ ! -L "$PROFILE_CONFIG" ] \
      || die 'profile config must be a regular non-symlink file'
    printf '%s\n' 'direct_profile_controls=false'
    ;;
  true:false)
    die 'initialized consumer is missing profile config'
    ;;
  false:true)
    die 'profile config requires project config'
    ;;
esac
