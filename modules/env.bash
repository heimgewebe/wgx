#!/usr/bin/env bash
set -e
set -u
set -E
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "env module: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi

export LC_ALL="${LC_ALL:-C}"

# Environment inspection utilities.

env::_detect_platform() {
  local name
  if command -v uname >/dev/null 2>&1; then
    name="$(uname -s 2>/dev/null || echo unknown)"
  else
    name="unknown"
  fi
  printf '%s' "$name"
}

env::_is_termux() {
  [[ -n ${TERMUX_VERSION:-} ]] && return 0
  [[ ${PREFIX:-} == */com.termux/* ]] && return 0
  [[ -n ${ANDROID_ROOT:-} && -n ${ANDROID_DATA:-} ]] && [[ ${HOME:-} == */com.termux/* ]] && return 0
  return 1
}

env::_have() {
  command -v "$1" >/dev/null 2>&1
}

env::_tool_status() {
  local tool="$1" label="${2:-$1}"
  shift 2 || true
  if env::_have "$tool"; then
    local version=""
    if (($#)); then
      version="$("$@" 2>/dev/null | head -n1 | tr -d '\r')"
    fi
    if [[ -n $version ]]; then
      printf '• %s: available (%s)\n' "$label" "$version"
    else
      printf '• %s: available\n' "$label"
    fi
  else
    printf '• %s: missing\n' "$label"
  fi
}

env::_doctor_report() {
  local platform
  platform="$(env::_detect_platform)"
  printf '=== wgx env doctor (%s) ===\n' "$platform"
  printf 'WGX_DIR : %s\n' "${WGX_DIR:-$(pwd)}"
  printf 'OFFLINE : %s\n' "${OFFLINE:-0}"
  env::_tool_status git "git" git --version
  env::_tool_status gh "gh" gh --version
  env::_tool_status glab "glab" glab --version
  env::_tool_status node "node" node --version
  env::_tool_status npm "npm" npm --version
  env::_tool_status python3 "python3" python3 --version
  env::_tool_status uv "uv" uv --version
  env::_tool_status docker "docker" docker --version
  printf '\nPaths:\n'
  printf '  PATH: %s\n' "${PATH:-}"
}

env::_json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

env::_doctor_json() {
  printf '{'
  printf '"platform":'
  env::_json_escape "$(env::_detect_platform)"
  printf ',"offline":'
  env::_json_escape "${OFFLINE:-0}"
  printf ',"tools":{'
  local first=1
  local tool
  for tool in git gh glab node npm python3 uv docker; do
    local have="missing" ver=""
    if env::_have "$tool"; then
      have="available"
      case "$tool" in
      git) ver="$(git --version 2>/dev/null | head -n1)" ;;
      gh) ver="$(gh --version 2>/dev/null | head -n1)" ;;
      glab) ver="$(glab --version 2>/dev/null | head -n1)" ;;
      node) ver="$(node --version 2>/dev/null | head -n1)" ;;
      npm) ver="$(npm --version 2>/dev/null | head -n1)" ;;
      python3) ver="$(python3 --version 2>/dev/null | head -n1)" ;;
      uv) ver="$(uv --version 2>/dev/null | head -n1)" ;;
      docker) ver="$(docker --version 2>/dev/null | head -n1)" ;;
      esac
    fi
    ((first)) || printf ','
    first=0
    printf '"%s":{' "$tool"
    printf '"status":'
    env::_json_escape "$have"
    printf ',"version":'
    env::_json_escape "$ver"
    printf '}'
  done
  printf '},"path":'
  env::_json_escape "${PATH:-}"
  printf '}'
  printf '\n'
}

env::_termux_fixups() {
  local rc=0
  if ! env::_have git; then
    warn "git is not available – unable to apply git defaults."
    return 1
  fi

  if git config --global --get core.filemode >/dev/null 2>&1; then
    log_info "git core.filemode already configured."
  else
    if git config --global core.filemode false >/dev/null 2>&1; then
      log_info "Configured git core.filemode=false for Termux."
    else
      warn "Failed to configure git core.filemode for Termux."
      rc=1
    fi
  fi

  return $rc
}

env::_fix_unsupported_msg() {
  printf '%s\n' "--fix is currently only supported on Termux"
}

env::_apply_fixes() {
  if env::_is_termux; then
    if env::_termux_fixups; then
      ok "Termux fixes applied."
      return 0
    fi
    warn "Some Termux fixes failed."
    return 1
  fi

  env::_fix_unsupported_msg
  return 0
}

env_cmd() {
  local sub="doctor" fix=0 strict=0 json=0
  local apply_fixes=0

  while (($#)); do
    case "$1" in
    doctor)
      sub="doctor"
      ;;
    --fix)
      fix=1
      ;;
    --strict)
      strict=1
      ;;
    --json)
      json=1
      ;;
    -h | --help)
      cat <<'USAGE'
Usage: wgx env doctor [--fix] [--strict] [--json]
  doctor     Inspect the local environment (default)
  --fix      Apply recommended platform specific tweaks (Termux only)
  --strict   Exit non-zero if essential tools are missing (e.g., git)
  --json     Machine-readable output (minimal JSON)
USAGE
      return 0
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Usage: wgx env doctor [--fix] [--strict] [--json]"
      ;;
    esac
    shift
  done

  if ((fix)); then
    if env::_is_termux; then
      apply_fixes=1
    else
      env::_fix_unsupported_msg
    fi
  fi

  case "$sub" in
  doctor)
    if ((json)); then
      env::_doctor_json
    else
      env::_doctor_report
    fi
    if ((apply_fixes)); then
      env::_apply_fixes || return $?
    fi
    if [[ $strict -ne 0 ]]; then
      if ! env::_have git; then
        warn "git missing (strict mode)"
        return 2
      fi
    fi
    return 0
    ;;
  *)
    die "Usage: wgx env doctor [--fix] [--strict] [--json]"
    ;;
  esac
}

wgx_command_main() {
  env_cmd "$@"
}
