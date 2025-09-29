#!/usr/bin/env bash

cmd_tasks() {
  local json=0 safe_only=0 include_groups=0
  while (( $# )); do
    case "$1" in
    --json) json=1 ;;
    --safe) safe_only=1 ;;
    --groups) include_groups=1 ;;
    -h | --help)
      cat <<'USAGE'
Usage: wgx tasks [--json] [--safe] [--groups]
  --json    Output machine readable JSON
  --safe    Only include tasks marked as safe
  --groups  Include group metadata (JSON) or group headings (text)
USAGE
      return 0
      ;;
    *)
      warn "unknown option: $1"
      return 1
      ;;
    esac
    shift
  done

  if ! profile::ensure_loaded; then
    warn ".wgx/profile manifest not found."
    return 1
  fi

  if (( json )); then
    profile::tasks_json "$safe_only" "$include_groups"
    return $?
  fi

  local -a _task_names=()
  mapfile -t _task_names < <(profile::_task_keys)
  if (( ${#_task_names[@]} == 0 )); then
    warn "No tasks defined in manifest."
    return 0
  fi

  if (( include_groups )); then
    declare -A _groups=()
    declare -A _order_seen=()
    local -a _order=()
    local name group safe
    for name in "${_task_names[@]}"; do
      safe="$(profile::_task_safe "$name")"
      if (( safe_only )) && [[ "$safe" != "1" ]]; then
        continue
      fi
      group="$(profile::_task_group "$name")"
      [[ -n $group ]] || group="default"
      _groups["$group"]+="$name"$'\n'
      if [[ -z ${_order_seen[$group]:-} ]]; then
        _order_seen[$group]=1
        _order+=("$group")
      fi
    done
    if (( ${#_order[@]} == 0 )); then
      warn "No tasks matched filters."
      return 0
    fi
    local group_name
    for group_name in "${_order[@]}"; do
      printf '%s:\n' "$group_name"
      printf '%s' "${_groups[$group_name]}" | sort | while IFS= read -r task; do
        [[ -n $task ]] && printf '  %s\n' "$task"
      done
    done
    return 0
  fi

  local -a filtered=()
  local task safe
  for task in "${_task_names[@]}"; do
    safe="$(profile::_task_safe "$task")"
    if (( safe_only )) && [[ "$safe" != "1" ]]; then
      continue
    fi
    filtered+=("$task")
  done
  if (( ${#filtered[@]} == 0 )); then
    warn "No tasks matched filters."
    return 0
  fi
  printf '%s\n' "${filtered[@]}" | sort
}
