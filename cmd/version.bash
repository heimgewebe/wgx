#!/usr/bin/env bash

# Read the current repository version without modifying repository state.
_version_read() {
  local v=""
  if [ -f "VERSION" ]; then
    v="$(cat VERSION)"
  elif [ -f "package.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      v="$(jq -r .version package.json)"
    else
      v="$(grep '"version":' package.json | head -n1 | awk -F'"' '{print $4}')"
    fi
  elif [ -f "Cargo.toml" ]; then
    v="$(grep '^version =' Cargo.toml | head -n1 | awk -F'"' '{print $2}')"
  fi
  echo "${v//[[:space:]]/}"
}

cmd_version() {
  local cmd="${1:-}"

  if [[ "$cmd" == "-h" || "$cmd" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx version

Description:
  Reads the current project or WGX version without modifying repository state.
  Version mutation belongs to repository-native language tooling or reviewed edits.

Options:
  -h, --help     Show this help.
USAGE
    return 0
  fi

  if [[ -n "$cmd" ]]; then
    die "wgx version is read-only; use repository-native version tooling for changes"
    return 1
  fi

  local current
  current="$(_version_read)"
  if [[ -n "$current" ]]; then
    echo "$current"
  elif [ -n "${WGX_VERSION:-}" ]; then
    echo "$WGX_VERSION"
  elif git rev-parse --git-dir >/dev/null 2>&1; then
    git describe --tags --always 2>/dev/null || git rev-parse --short HEAD
  else
    echo "wgx (unversioned)"
  fi
}
