#!/usr/bin/env bash

cmd_validate() {
  local json=0 profile_path=""
  while (($#)); do
    case "$1" in
    --json) json=1 ;;
    --profile)
      shift || { die "--profile requires a path"; }
      profile_path="$1"
      ;;
    -h | --help)
      cat <<'USAGE'
Usage: wgx validate [--json] [--profile <path>]
  --json       Emit JSON output
  --profile    Validate an explicit manifest file
USAGE
      return 0
      ;;
    *)
      warn "unknown option: $1"
      return 1
      ;;
    esac
    shift || true
  done

  if [[ -n $profile_path ]]; then
    if ! profile::load "$profile_path"; then
      die "could not load manifest: $profile_path"
    fi
  else
    if ! profile::ensure_loaded; then
      die "no manifest found"
    fi
  fi

  local -a errors=()
  local -a missing_caps=()
  profile::validate_manifest errors missing_caps || true

  local ok=0
  if ((${#errors[@]} == 0)); then
    ok=1
  fi

  if ((json)); then
    if ! declare -F json_escape >/dev/null 2>&1; then
      source "${WGX_DIR:-.}/modules/json.bash"
    fi
    local ok_value
    ok_value=$([[ $ok -eq 1 ]] && echo true || echo false)
    printf '{"ok":%s,"errors":[' "$ok_value"
    local sep=""
    local entry
    for entry in "${errors[@]}"; do
      printf '%s"%s"' "$sep" "$(json_escape "$entry")"
      sep=','
    done
    printf '],"caps":{"required":['
    sep=""
    for entry in "${WGX_REQUIRED_CAPS[@]}"; do
      printf '%s"%s"' "$sep" "$(json_escape "$entry")"
      sep=','
    done
    printf '],"available":['
    sep=""
    local -a _caps_available=()
    mapfile -t _caps_available < <(profile::available_caps)
    local cap
    for cap in "${_caps_available[@]}"; do
      [[ -z $cap ]] && continue
      printf '%s"%s"' "$sep" "$(json_escape "$cap")"
      sep=','
    done
    printf '],"missing":['
    sep=""
    for entry in "${missing_caps[@]}"; do
      printf '%s"%s"' "$sep" "$(json_escape "$entry")"
      sep=','
    done
    printf ']}}\n'
    ((ok)) && return 0 || return 1
  fi

  if ((ok)); then
    echo "Manifest OK"
    return 0
  fi

  echo "Manifest issues detected:"
  local issue
  for issue in "${errors[@]}"; do
    echo " - $issue"
  done
  if ((${#missing_caps[@]})); then
    echo "Missing capabilities: ${missing_caps[*]}"
  fi
  return 1
}
