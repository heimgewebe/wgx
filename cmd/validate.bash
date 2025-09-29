# shellcheck shell=bash

if ! declare -F require_repo >/dev/null 2>&1; then
  require_repo() {
    if ! command -v git >/dev/null 2>&1; then
      die "git nicht installiert."
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      die "Nicht im Git-Repo."
    fi
  }
fi

validate::run() {
  require_repo

  local json_mode=0
  if [[ "${1-}" == "--json" ]]; then
    json_mode=1
    shift || true
  fi

  if ! profile::load; then
    if (( json_mode )); then
      echo '{"ok":false,"errors":["profile_missing"]}'
    else
      die "Profile fehlt (.wgx/profile.yml|yaml|json)"
    fi
    return 1
  fi

  local ok=true
  local errs=()

  if ! profile::ensure_version; then
    ok=false
    errs+=("version_mismatch")
  fi

  local tasks_count=0
  if declare -p WGX_TASK_CMD >/dev/null 2>&1; then
    tasks_count=${#WGX_TASK_CMD[@]}
  elif declare -p WGX_TASK_CMDS >/dev/null 2>&1; then
    tasks_count=${#WGX_TASK_CMDS[@]}
  fi
  if (( tasks_count == 0 )); then
    ok=false
    errs+=("no_tasks")
  fi

  if (( json_mode )); then
    printf '{'
    if [[ $ok == true ]]; then
      printf '"ok":true'
    else
      printf '"ok":false'
    fi
    printf ',"errors":['
    local first=1
    local e
    for e in "${errs[@]}"; do
      if (( first )); then
        first=0
      else
        printf ','
      fi
      printf '"%s"' "$e"
    done
    printf ']}'
    printf '\n'
  else
    if [[ $ok == true ]]; then
      echo "manifest OK"
    else
      echo "manifest ungültig: ${errs[*]}"
      return 1
    fi
  fi
}
