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
  local target
  local -a packages=()
  for target in "$@"; do
    case "$target" in
      base)
        packages+=("${BASE_PACKAGES[@]}")
        ;;
      optional)
        packages+=("${OPTIONAL_PACKAGES[@]}")
        ;;
      all)
        packages+=("${BASE_PACKAGES[@]}" "${OPTIONAL_PACKAGES[@]}")
        ;;
      jq|moreutils|shellcheck|shfmt|bats)
        packages+=("$target")
        ;;
      check)
        echo "Ignoring 'check' target during installation. Run './.devcontainer/setup.sh check' separately." >&2
        ;;
      "")
        ;;
      *)
        echo "Unknown install target: $target" >&2
        exit 1
        ;;
    esac
  done

  if ((${#packages[@]} == 0)); then
    packages+=("${BASE_PACKAGES[@]}")
  fi

  printf '%s\n' "${packages[@]}"
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
  mapfile -t targets < <(collect_packages "$@")

  if ((${#targets[@]} == 0)); then
    echo "No packages selected for installation." >&2
    exit 1
  fi

  # Deduplicate while preserving order.
  local -a unique=()
  declare -A seen_map=()
  local pkg
  for pkg in "${targets[@]}"; do
    if [[ -z "${seen_map[$pkg]:-}" ]]; then
      seen_map[$pkg]=1
      unique+=("$pkg")
    fi
  done

  ensure_packages "${unique[@]}"
}

main() {
  if (($# == 0)); then
    usage
    exit 1
  fi

  case "$1" in
    check)
      run_check
      ;;
    install)
      run_install "$@"
      ;;
    -h|--help)
      usage
      ;;
    base|optional|all|jq|moreutils|shellcheck|shfmt|bats)
      run_install "$@"
      ;;
    *)
      echo "Unknown command: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
