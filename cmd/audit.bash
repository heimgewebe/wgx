#!/usr/bin/env bash

# audit command dispatch
cmd_audit() {
  local audit_type="${1:-}"
  shift 1 || true

  if [[ -z "$audit_type" || "$audit_type" == "-h" || "$audit_type" == "--help" ]]; then
    cat <<USAGE
Usage:
  wgx audit <type> [options]

Types:
  git    Audit git repository state (read-only)

Options:
  --json    Output results as JSON artifact (default behavior for 'git')
USAGE
    return 0
  fi

  if [ -z "${WGX_DIR:-}" ]; then
    WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # shellcheck source=lib/core.bash
  source "${WGX_DIR}/lib/core.bash"

  case "$audit_type" in
  git)
    # shellcheck source=lib/audit_git.bash
    source "${WGX_DIR}/lib/audit_git.bash"
    wgx_audit_git "$@"
    ;;
  *)
    printf 'wgx audit: unknown audit type %s\n' "$audit_type" >&2
    return 1
    ;;
  esac
}

wgx_command_main() {
  cmd_audit "$@"
}
