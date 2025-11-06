#!/usr/bin/env bash

run::_print_usage() {
  cat <<'USAGE'
Usage:
  wgx run [--dry-run|-n] <task> [--] [args...]

Description:
  Execute a task defined in the current workspace profile. Additional
  arguments after an optional "--" are forwarded to the task.
USAGE
}

cmd_run() {
  if [ -z "${WGX_DIR:-}" ]; then
    WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # shellcheck disable=SC1091
  source "$WGX_DIR/lib/core.bash"

  if ! declare -F cmd_task >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source "$WGX_DIR/cmd/task.bash"
  fi

  local dryrun=0
  local -a positionals=()

  while (($#)); do
    case "$1" in
      --dry-run | -n)
        dryrun=1
        ;;
      -h | --help)
        run::_print_usage
        return 0
        ;;
      --)
        shift
        while (($#)); do
          positionals+=("$1")
          shift
        done
        break
        ;;
      -*)
        warn "unknown option: $1"
        return 2
        ;;
      *)
        positionals+=("$1")
        shift
        while (($#)); do
          positionals+=("$1")
          shift
        done
        break
        ;;
    esac
    shift || true
  done

  if ((${#positionals[@]} == 0)); then
    run::_print_usage >&2
    return 1
  fi

  local name="${positionals[0]}"
  if [[ -z "$(profile::_task_spec "$name")" ]]; then
    printf 'Task not defined: %s\n' "$name" >&2
    return 1
  fi
  local -a forwarded=()
  if ((${#positionals[@]} > 1)); then
    forwarded=("${positionals[@]:1}")
  fi

  if ((dryrun)); then
    DRYRUN=1 cmd_task "$name" "${forwarded[@]}"
  else
    cmd_task "$name" "${forwarded[@]}"
  fi
}
