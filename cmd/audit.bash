#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::verify >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

cmd_audit() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
  verify)
    local strict=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
      --strict)
        strict=1
        ;;
      -h | --help)
        cat <<'USAGE'
Usage:
  wgx audit verify [--strict]

Verifies the local WGX audit-ledger hash chain without modifying repository or
remote state. In non-strict mode a damaged ledger is reported as a warning;
--strict (or AUDIT_VERIFY_STRICT=1) makes verification failures non-zero.
USAGE
        return 0
        ;;
      --)
        shift
        break
        ;;
      --*)
        printf 'wgx audit verify: unknown option %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
      esac
      shift || true
    done
    if ((strict)); then
      audit::verify --strict "$@"
    else
      audit::verify "$@"
    fi
    ;;
  -h | --help | help | '')
    cat <<'USAGE'
Usage:
  wgx audit verify [--strict]

WGX audit is read-only. Git-state inspection belongs to Git/RepoGround or the
authorized operator; WGX no longer fetches remotes or writes Git-audit artifacts.
USAGE
    ;;
  *)
    printf 'wgx audit: unknown subcommand %s\n' "$sub" >&2
    return 1
    ;;
  esac
}

wgx_command_main() {
  cmd_audit "$@"
}
