#!/usr/bin/env bash

cmd_lint() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local oldpwd="$PWD"
  if ! cd "$base_dir" >/dev/null 2>&1; then
    die "Lint: Basisverzeichnis '$base_dir' nicht erreichbar."
  fi

  local -a shell_files=()

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      shell_files+=("$file")
    done < <(git ls-files -z -- '*.sh' '*.bash' 'wgx' 'cli/wgx')
  else
    while IFS= read -r -d '' file; do
      case "$file" in
      ./*) shell_files+=("${file#./}") ;;
      *) shell_files+=("$file") ;;
      esac
    done < <(find . -type f \( -name '*.sh' -o -name '*.bash' -o -name 'wgx' -o -path './cli/wgx' \) -print0)
  fi

  if [ ${#shell_files[@]} -eq 0 ]; then
    warn "No shell scripts found to lint."
    if ! cd "$oldpwd" >/dev/null 2>&1; then
      warn "Failed to return to original directory '$oldpwd'."
    fi
    return 0
  fi

  local rc=0

  if command -v bash >/dev/null 2>&1; then
    if [ ${#shell_files[@]} -ne 0 ]; then
      if ! bash -n "${shell_files[@]}"; then
        rc=1
      fi
    fi
  else
    warn "bash not found, skipping syntax check."
  fi

  if command -v shfmt >/dev/null 2>&1; then
    if ! shfmt -d "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shfmt not found, skipping formatting check."
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    local -a shellcheck_args=(--severity=style --shell=bash --external-sources --format=gcc)
    if ! shellcheck "${shellcheck_args[@]}" "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shellcheck not found, skipping lint step."
  fi

  cd "$oldpwd" >/dev/null 2>&1 || true
  return $rc
}

lint_cmd() {
  cmd_lint "$@"
}

wgx_command_main() {
  cmd_lint "$@"
}
