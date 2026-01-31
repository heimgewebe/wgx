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
  git)
    if declare -F wgx_audit_git >/dev/null 2>&1; then
      wgx_audit_git "$@"
    else
      printf 'wgx audit git: logic not loaded.\n' >&2
      return 1
    fi
    ;;
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

Prüft die Audit-Log-Kette (.wgx/audit/ledger.jsonl). Standardmäßig wird
nur eine Warnung ausgegeben, wenn die Kette beschädigt ist. Mit --strict
(oder AUDIT_VERIFY_STRICT=1) führt eine Verletzung zu einem Fehlercode.
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
  wgx audit git

Verwaltet das Audit-Ledger von wgx und führt Audits aus.
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
