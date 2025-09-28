#!/usr/bin/env bash

_wgx_find_bats() {
  local candidate
  local -a candidates=()

  for candidate in "${BATS_CMD:-}" "${BATS_BIN:-}" "${BATS:-}"; do
    if [ -n "$candidate" ]; then
      candidates+=("$candidate")
    fi
  done

  candidates+=(bats bats-core)

  if [ -n "${WGX_DIR:-}" ]; then
    candidates+=("$WGX_DIR/node_modules/.bin/bats")
  fi
  candidates+=("node_modules/.bin/bats")

  for candidate in "${candidates[@]}"; do
    if [ -z "$candidate" ]; then
      continue
    fi

    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi

    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

cmd_test() {
  local bats_cmd
  if ! bats_cmd=$(_wgx_find_bats); then
    log_error "Kein 'bats' gefunden. Bitte bats-core installieren (z.B. 'npm install -g bats')."
    return 127
  fi

  local project_dir="${WGX_DIR:-$(pwd)}"
  local -a bats_args=()
  if [ "$#" -gt 0 ]; then
    bats_args=("$@")
  else
    local default_suite="${project_dir}/tests"
    if [ ! -d "$default_suite" ]; then
      log_warn "Kein tests/-Verzeichnis gefunden – nichts zu testen."
      return 0
    fi
    bats_args=("$default_suite")
  fi

  local pretty_cmd
  printf -v pretty_cmd '%q ' "$bats_cmd" "${bats_args[@]}"
  log_info "Starting tests with: ${pretty_cmd% }"

  (
    cd "$project_dir" || exit 1
    "$bats_cmd" "${bats_args[@]}"
  )
}

wgx_command_main() {
  cmd_test "$@"
}
