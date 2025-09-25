#!/usr/bin/env bash

cmd_version() {
  if [ -n "${WGX_VERSION:-}" ]; then
    printf '%s\n' "$WGX_VERSION"
    return
  fi

  if [ -f "$WGX_DIR/VERSION" ]; then
    cat "$WGX_DIR/VERSION"
    return
  fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    git describe --tags --always 2>/dev/null || git rev-parse --short HEAD
  else
    printf 'wgx (unversioned)\n'
  fi
}
