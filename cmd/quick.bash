#!/usr/bin/env bash

_quick_usage() {
  cat <<'USAGE'
Usage: wgx quick [-i|--interactive] [--help]

Run repository guards (lint + tests) and open the PR/MR helper.

Options:
  -i, --interactive  Open the PR body in $EDITOR before sending
  -h, --help         Show this help message
USAGE
}

_quick_require_repo() {
  if ! command -v git >/dev/null 2>&1; then
    die "quick: git is not installed."
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "quick: not inside a git repository."
  fi
}

_quick_guard_available() {
  declare -F guard_run >/dev/null 2>&1
}

_quick_send_available() {
  declare -F send_cmd >/dev/null 2>&1
}

cmd_quick() {
  local interactive=0

  while (($#)); do
    case "$1" in
      -i | --interactive)
        interactive=1
        ;;
      -h | --help)
        _quick_usage
        return 0
        ;;
      --)
        shift || true
        break
        ;;
      *)
        die "Usage: wgx quick [-i|--interactive]"
        ;;
    esac
    shift || true
  done

  _quick_require_repo

  local guard_status=0
  if _quick_guard_available; then
    guard_run --lint --test || guard_status=$?
  else
    warn "guard command not available; skipping lint/test checks."
  fi

  if ((guard_status > 1)); then
    return $guard_status
  fi

  if ! _quick_send_available; then
    warn "send command not available; skipping PR helper."
    return 0
  fi

  local -a send_args=()
  if ((guard_status == 1)); then
    send_args+=(--draft)
  fi
  send_args+=(--ci --open)
  if ((interactive)); then
    send_args+=(-i)
  fi

  local send_status=0
  if ! send_cmd "${send_args[@]}"; then
    send_status=$?
  fi

  if ((send_status != 0)); then
    return $send_status
  fi

  return 0
}

wgx_command_main() {
  cmd_quick "$@"
}
