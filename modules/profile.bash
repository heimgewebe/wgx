#!/usr/bin/env bash
# shellcheck shell=bash
# Profile loader: reads .wgx/profile.yml and exposes contract data

# Trim helper
profile::_trim() {
  local s="$1"
  s="${s#${s%%[!$' \t\r\n']*}}"
  s="${s%${s##*[!$' \t\r\n']}}"
  printf '%s' "$s"
}

profile::_cleanup_value() {
  local v
  v="$(profile::_trim "$1")"
  if [[ $v == \"* && $v == *\" ]]; then
    v="${v:1:${#v}-2}"
  elif [[ $v == \'* && $v == *\' ]]; then
    v="${v:1:${#v}-2}"
  fi
  printf '%s' "$v"
}

profile::_set_dir_var() {
  local key="$1" value="$2"
  value="$(profile::_cleanup_value "$value")"
  case "$key" in
    web)  export WGX_DIR_WEB="$value" ;;
    api)  export WGX_DIR_API="$value" ;;
    data) export WGX_DIR_DATA="$value" ;;
  esac
}

profile::_parse_inline_map() {
  local content="$1" kind="$2"
  local IFS=','
  local -a _profile_parts=()
  read -ra _profile_parts <<< "$content"
  for part in "${_profile_parts[@]}"; do
    part="$(profile::_trim "$part")"
    [[ -z $part ]] && continue
    if [[ $part =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      case "$kind" in
        dirs) profile::_set_dir_var "$key" "$value" ;;
        tasks)
          key="${key//-/_}"; key="${key^^}"
          value="$(profile::_cleanup_value "$value")"
          export "WGX_TASK_${key}=$value"
          ;;
        env)
          key="$(profile::_trim "$key")"
          [[ $key =~ ^[A-Z0-9_]+$ ]] || continue
          value="$(profile::_cleanup_value "$value")"
          export "WGX_ENV_${key}=$value"
          ;;
      esac
    fi
  done
  unset _profile_parts
}

profile::has_manifest() {
  [[ -f .wgx/profile.yml ]]
}

profile::load() {
  local file=".wgx/profile.yml"
  local section=""
  [[ -f $file ]] || return 1
  if [[ -n ${WGX_PROFILE_LOADED:-} ]]; then
    return 0
  fi

  while IFS= read -r line || [[ -n $line ]]; do
    local raw="$line"
    raw="${raw%%#*}"
    raw="$(profile::_trim "$raw")"
    [[ -z $raw ]] && continue

    if [[ $raw =~ ^wgx:[[:space:]]*$ ]]; then
      section="root"
      continue
    fi

    if [[ $raw =~ ^apiVersion:[[:space:]]*(.*)$ ]]; then
      export WGX_PROFILE_API_VERSION="$(profile::_cleanup_value "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ $raw =~ ^requiredWgx:[[:space:]]*(.*)$ ]]; then
      export WGX_REQUIRED="$(profile::_cleanup_value "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ $raw =~ ^repoKind:[[:space:]]*(.*)$ ]]; then
      export WGX_REPO_KIND="$(profile::_cleanup_value "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ $raw =~ ^dirs:[[:space:]]*\{(.*)\}[[:space:]]*$ ]]; then
      profile::_parse_inline_map "${BASH_REMATCH[1]}" "dirs"
      section=""
      continue
    fi

    if [[ $raw =~ ^tasks:[[:space:]]*\{(.*)\}[[:space:]]*$ ]]; then
      profile::_parse_inline_map "${BASH_REMATCH[1]}" "tasks"
      section=""
      continue
    fi

    if [[ $raw =~ ^env:[[:space:]]*\{(.*)\}[[:space:]]*$ ]]; then
      profile::_parse_inline_map "${BASH_REMATCH[1]}" "env"
      section=""
      continue
    fi

    if [[ $raw =~ ^dirs:[[:space:]]*$ ]]; then
      section="dirs"
      continue
    fi

    if [[ $raw =~ ^tasks:[[:space:]]*$ ]]; then
      section="tasks"
      continue
    fi

    if [[ $raw =~ ^env:[[:space:]]*$ ]]; then
      section="env"
      continue
    fi

    if [[ $section == dirs && $raw =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      profile::_set_dir_var "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
      continue
    fi

    if [[ $section == tasks && $raw =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      key="${key//-/_}"; key="${key^^}"
      value="$(profile::_cleanup_value "$value")"
      export "WGX_TASK_${key}=$value"
      continue
    fi

    if [[ $section == env && $raw =~ ^([A-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      value="$(profile::_cleanup_value "$value")"
      export "WGX_ENV_${key}=$value"
      continue
    fi

    if [[ $section == root && $raw =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      # allow repoKind/requiredWgx even if indentation odd
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      case "$key" in
        repoKind)    export WGX_REPO_KIND="$(profile::_cleanup_value "$value")" ;;
        requiredWgx) export WGX_REQUIRED="$(profile::_cleanup_value "$value")" ;;
      esac
      continue
    fi
  done < "$file"

  export WGX_PROFILE_LOADED=1
  return 0
}

profile::ensure_version() {
  [[ -z ${WGX_REQUIRED:-} ]] && return 0
  [[ -z ${WGX_VERSION:-} ]] && return 0
  local req="$WGX_REQUIRED" have="$WGX_VERSION"
  if [[ $req == ^* ]]; then
    req="${req#^}"
  fi
  req="${req%%.*}"
  have="${have%%.*}"
  if [[ -n $req && -n $have && $req != "$have" ]]; then
    warn "wgx version incompatible (required $WGX_REQUIRED, have ${WGX_VERSION})."
    return 1
  fi
  return 0
}

profile::tasks() {
  compgen -A variable | grep -E '^WGX_TASK_' | sort |
    while IFS= read -r var; do
      local name="${var#WGX_TASK_}"
      name="${name//_/-}"
      name="${name,,}"
      printf '%s\n' "$name"
    done
}

profile::task_command() {
  local name="$1"
  [[ -z $name ]] && return 1
  local key="${name//-/_}"
  key="WGX_TASK_${key^^}"
  if [[ -n ${!key:-} ]]; then
    printf '%s' "${!key}"
    return 0
  fi
  return 1
}

profile::env_pairs() {
  compgen -A variable | grep -E '^WGX_ENV_' | sort |
    while IFS= read -r var; do
      local key="${var#WGX_ENV_}"
      printf '%s=%s\n' "$key" "${!var}"
    done
}

profile::run_task() {
  local name="$1"
  shift || true
  if ! profile::task_command "$name" >/dev/null; then
    return 1
  fi
  local base
  base="$(profile::task_command "$name")" || return 1
  local -a envs=()
  while IFS= read -r pair; do
    envs+=("${pair%%=*}=${pair#*=}")
  done < <(profile::env_pairs)
  : "${DRYRUN:=0}"
  if (( DRYRUN )); then
    printf 'DRY: '
    for e in "${envs[@]}"; do
      printf '%q ' "$e"
    done
    printf '%s' "$base"
    if (($#)); then
      printf ' '
      printf '%q ' "$@"
    fi
    printf '\n'
  else
    (
      if ((${#envs[@]})); then
        export "${envs[@]}"
      fi
      # Safely parse $base into an array and execute
      read -r -a _cmd <<< "$base"
      "${_cmd[@]}" "$@"
    )
  fi
}

profile::ensure_loaded() {
  if ! profile::has_manifest; then
    return 1
  fi
  profile::load
}

profile::_auto_init() {
  if profile::has_manifest; then
    if profile::load; then
      profile::ensure_version || true
    else
      warn "profile.yml could not be loaded."
    fi
  fi
}

profile::_auto_init

