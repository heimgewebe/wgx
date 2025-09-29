#!/usr/bin/env bash

set -euo pipefail

readonly BASE_PACKAGES=(jq moreutils)
readonly OPTIONAL_PACKAGES=(shellcheck shfmt bats)

usage() {
  cat <<'USAGE'
Usage: setup.sh [command] [options]

Commands:
  check                 Report availability of base and optional development tools.
  install [targets...]  Install tool groups or individual packages. Defaults to "base".
  base|optional|all     Shortcut for "install" with the matching target(s). 
  <package>             Shortcut for "install" with a specific package.

Targets:
  base       Install baseline development helpers (jq, moreutils).
  optional   Install optional tooling (shellcheck, shfmt, bats).
  all        Install both base and optional tool groups.
  <package>  Install a specific apt package from the base/optional lists.

Examples:
  setup.sh check
  setup.sh install                  # install baseline helpers
  setup.sh install optional         # install optional tooling
  setup.sh install all              # install everything
  setup.sh install shellcheck bats  # install a subset
USAGE
}

package_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

package_version() {
  dpkg-query --showformat='${Version}' --show "$1" 2>/dev/null || true
}

ensure_packages() {
  local -a missing_packages=()
  local pkg
  for pkg in "$@"; do
    if [[ -z "$pkg" ]]; then
      continue
    fi
    if ! package_installed "$pkg"; then
      missing_packages+=("$pkg")
    fi
  done

  if ((${#missing_packages[@]} == 0)); then
    echo "All requested packages are already installed."
    return 0
  fi

  echo "Installing packages: ${missing_packages[*]}"
  sudo apt-get update -y
  sudo apt-get install -y "${missing_packages[@]}"
}

print_group_header() {
  local label=$1
  printf '\n%s\n' "$label"
  printf '%*s\n' "${#label}" '' | tr ' ' '-'
}

print_tool_status() {
  local package=$1
  local binary=$2
  local description=$3
  local installed="✗"
  local version=""

  if package_installed "$package"; then
    installed="✓"
    version="$(package_version "$package")"
  fi

  if [[ -n "$version" ]]; then
    printf '  %s %-12s (%s) %s\n' "$installed" "$binary" "$package" "$version"
  else
    printf '  %s %-12s (%s)\n' "$installed" "$binary" "$package"
  fi

  if [[ $installed == "✗" ]]; then
    printf '      %s\n' "$description"
  fi
}

collect_packages() {
  local -n _out=$1
  shift || true

  local target
  for target in "$@"; do
    case "$target" in
      '')
        continue
        ;;
      check)
        echo "Ignoring 'check' target during installation. Run './.devcontainer/setup.sh check' separately." >&2
        continue
        ;;
      base)
        _out+=("${BASE_PACKAGES[@]}")
        ;;
      optional)
        _out+=("${OPTIONAL_PACKAGES[@]}")
        ;;
      all)
        _out+=("${BASE_PACKAGES[@]}" "${OPTIONAL_PACKAGES[@]}")
        ;;
      jq|moreutils|shellcheck|shfmt|bats)
        _out+=("$target")
        ;;
      *)
        echo "Unknown install target: $target" >&2
        return 1
        ;;
    esac
  done
  return 0
}

run_check() {
  print_group_header "Baseline tools"
  print_tool_status jq jq "Install with './.devcontainer/setup.sh install base'"
  print_tool_status moreutils sponge "Install with './.devcontainer/setup.sh install base'"

  print_group_header "Optional tools"
  print_tool_status shellcheck shellcheck "Install with './.devcontainer/setup.sh install optional'"
  print_tool_status shfmt shfmt "Install with './.devcontainer/setup.sh install optional'"
  print_tool_status bats bats "Install with './.devcontainer/setup.sh install optional'"
}

run_install() {
  shift || true

  local default_to_base=0
  if (($# == 0)); then
    default_to_base=1
  fi

  local -a collected=()
  if ! collect_packages collected "$@"; then
    return 1
  fi

  local -a targets=()
  if ((${#collected[@]} > 0)); then
    targets=("${collected[@]}")
  fi
  if ((${#targets[@]} == 0)); then
    if ((default_to_base)); then
      targets=("${BASE_PACKAGES[@]}")
    else
      echo "No packages selected for installation." >&2
      return 0
    fi
  fi

  # Deduplicate while preserving order.
  local -a unique=()
  declare -A seen_map=()
  local pkg
  for pkg in "${targets[@]}"; do
    if [[ -z "$pkg" ]]; then
      continue
    fi
    if [[ -z "${seen_map[$pkg]:-}" ]]; then
      seen_map[$pkg]=1
      unique+=("$pkg")
    fi
  done

  ensure_packages "${unique[@]}"
}

main() {
  case "${1-}" in
    '')
      usage
      exit 1
      ;;
    check)
      run_check
      ;;
    install)
      run_install "$@"
      ;;
    base|optional|all|jq|moreutils|shellcheck|shfmt|bats)
      run_install install "$@"
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown command: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
