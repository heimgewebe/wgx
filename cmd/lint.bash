#!/usr/bin/env bash

cmd_lint() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local -a shell_files=()

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      shell_files+=("$file")
    done < <(git ls-files -z -- '*.sh' '*.bash' 'wgx' 'cli/wgx')
  else
    while IFS= read -r -d '' file; do
      case "$file" in
      "${base_dir}/"*) shell_files+=("${file#"${base_dir}/"}") ;;
      *) shell_files+=("$file") ;;
      esac
    done < <(find "$base_dir" -type f \( -name '*.sh' -o -name '*.bash' -o -name 'wgx' -o -path "${base_dir}/cli/wgx" \) -print0)
  fi

  if [ ${#shell_files[@]} -eq 0 ]; then
    warn "No shell scripts found to lint."
    return 0
  fi

  local rc=0

  if command -v shfmt >/dev/null 2>&1; then
    if ! shfmt -d "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shfmt not found, skipping formatting check."
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    if ! shellcheck -S style "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shellcheck not found, skipping lint step."
  fi

  return $rc
}

lint_cmd() {
  cmd_lint "$@"
}

wgx_command_main() {
  cmd_lint "$@"
}
