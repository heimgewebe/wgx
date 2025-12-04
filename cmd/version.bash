#!/usr/bin/env bash

# Helper to read the current version from supported files
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
    # Simple Cargo.toml parsing (assumes [package] section version is first 'version =' line)
    v="$(grep '^version =' Cargo.toml | head -n1 | awk -F'"' '{print $2}')"
  fi
  echo "${v//[[:space:]]/}"
}

# Helper to write version to supported files
_version_write() {
  local new_ver="$1"
  local updated=0

  if [ -f "VERSION" ]; then
    echo "$new_ver" >VERSION
    info "Updated VERSION to $new_ver"
    updated=1
  fi

  if [ -f "package.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      local tmp
      tmp="$(mktemp)"
      jq --arg v "$new_ver" '.version = $v' package.json >"$tmp" && mv "$tmp" package.json
      info "Updated package.json to $new_ver"
      updated=1
    else
      # Fallback sed replacement (risky but better than nothing for basic files)
      sed -i "s/\"version\": \".*\"/\"version\": \"$new_ver\"/" package.json
      info "Updated package.json to $new_ver (via sed)"
      updated=1
    fi
  fi

  if [ -f "Cargo.toml" ]; then
    # Careful replacement: only the first occurrence which is usually under [package]
    # This is a heuristic.
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "0,/^version = .*/s/^version = .*/version = \"$new_ver\"/" Cargo.toml
    else
      # GNU sed
      sed -i "0,/^version = .*/s/^version = .*/version = \"$new_ver\"/" Cargo.toml
    fi
    info "Updated Cargo.toml to $new_ver"
    updated=1
  fi

  if [ "$updated" -eq 0 ]; then
    die "No supported version file found (VERSION, package.json, Cargo.toml)."
  fi
}

cmd_version() {
  local cmd="${1:-}"

  if [[ "$cmd" == "-h" || "$cmd" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx version
  wgx version bump <level>
  wgx version set <version>

Description:
  Reads or modifies the project version.
  Supported files: VERSION, package.json, Cargo.toml.

Subcommands:
  (none)         Show current version.
  bump <level>   Bump version (patch, minor, major).
  set <version>  Set exact version.

Options:
  -h, --help     Show this help.
USAGE
    return 0
  fi

  # Default: Show version
  if [[ -z "$cmd" ]]; then
    local current
    current="$(_version_read)"
    if [[ -n "$current" ]]; then
      echo "$current"
    else
      # Fallback for wgx self-versioning
      if [ -n "${WGX_VERSION:-}" ]; then
        echo "$WGX_VERSION"
      elif git rev-parse --git-dir >/dev/null 2>&1; then
        git describe --tags --always 2>/dev/null || git rev-parse --short HEAD
      else
        echo "wgx (unversioned)"
      fi
    fi
    return 0
  fi

  # Subcommands
  case "$cmd" in
  bump)
    local level="${2:-}"
    if [[ -z "$level" ]]; then
      die "Usage: wgx version bump <patch|minor|major>"
    fi
    local current
    current="$(_version_read)"
    if [[ -z "$current" ]]; then
      die "Could not determine current version from files."
    fi

    # Load semver module if not already loaded (defensive)
    if ! declare -f semver_bump >/dev/null; then
      # Attempt to locate module relative to this file or WGX_DIR
      # But since this is run by cli/wgx which loads libs, it should be fine.
      # If semver functions are in modules/semver.bash, we might need to source it.
      # cli/wgx only sources lib/*.bash by default. modules/ are usually on demand?
      # Let's try to source it if needed.
      local mod_path="${WGX_DIR}/modules/semver.bash"
      if [ -f "$mod_path" ]; then
        # shellcheck disable=SC1090
        source "$mod_path"
      else
        die "Module semver.bash not found."
      fi
    fi

    if ! semver_validate "$current"; then
      die "Current version '$current' is not valid SemVer."
    fi

    local new_ver
    new_ver="$(semver_bump "$current" "$level")" || die "Invalid bump level: $level"
    _version_write "$new_ver"
    ;;

  set)
    local new_ver="${2:-}"
    if [[ -z "$new_ver" ]]; then
      die "Usage: wgx version set <version>"
    fi
    _version_write "$new_ver"
    ;;

  *)
    die "Unknown command: $cmd"
    ;;
  esac
}
