#!/usr/bin/env bash

# Rolle: minimaler WGX-Kern fuer Logging, Modul-Laden und Command-Dispatch.

: "${WGX_NO_EMOJI:=0}"
: "${WGX_QUIET:=0}"
: "${WGX_VERSION:=2.0.3}"

if [[ "$WGX_NO_EMOJI" != 0 ]]; then
  _OK="[OK]"
  _WARN="[WARN]"
  _ERR="[ERR]"
  _DOT="*"
else
  _OK="✅"
  _WARN="⚠️"
  _ERR="❌"
  _DOT="•"
fi

info() {
  [[ ${WGX_QUIET:-0} != 0 ]] && return
  printf '%s %s\n' "$_DOT" "$*" >&2
}

ok() {
  [[ ${WGX_QUIET:-0} != 0 ]] && return
  printf '%s %s\n' "$_OK" "$*" >&2
}

warn() {
  printf '%s %s\n' "$_WARN" "$*" >&2
}

die() {
  printf '%s %s\n' "$_ERR" "$*" >&2
  exit 1
}

has() {
  command -v "$1" >/dev/null 2>&1
}

_load_modules() {
  local module_dir="${WGX_PROJECT_ROOT:-$WGX_DIR}/modules"
  if [ -d "$module_dir" ]; then
    local f
    for f in "$module_dir"/*.bash; do
      # shellcheck source=/dev/null
      [ -r "$f" ] && source "$f"
    done
  fi
}

wgx_command_files() {
  local cmd_dir="${WGX_PROJECT_ROOT:-$WGX_DIR}/cmd"
  [ -d "$cmd_dir" ] || return 0
  local f
  for f in "$cmd_dir"/*.bash; do
    [ -r "$f" ] || continue
    printf '%s\n' "$f"
  done
}

wgx_available_commands() {
  local -a commands=(help)
  local file name
  while IFS= read -r file; do
    name=$(basename "$file")
    name=${name%.bash}
    commands+=("$name")
  done < <(wgx_command_files)

  printf '%s\n' "${commands[@]}" | sort -u
}

wgx_print_command_list() {
  local command
  while IFS= read -r command; do
    printf '  %s\n' "$command"
  done < <(wgx_available_commands)
}

wgx_usage() {
  cat <<USAGE
wgx — Repository Verification Runner

Usage:
  wgx <command> [args]

Commands:
$(wgx_print_command_list)

More:
  wgx --list     Nur verfügbare Befehle anzeigen
  wgx --version  Runner-Version anzeigen

USAGE
}

wgx_main() {
  if (($# == 0)); then
    wgx_usage
    return 1
  fi

  local sub="$1"
  shift || true

  case "$sub" in
  help | -h | --help)
    wgx_usage
    return 0
    ;;
  --list | commands)
    wgx_available_commands
    return 0
    ;;
  esac

  _load_modules

  if declare -F "cmd_${sub}" >/dev/null 2>&1; then
    "cmd_${sub}" "$@"
    return
  fi

  local cmd_dir="${WGX_PROJECT_ROOT:-$WGX_DIR}/cmd"
  local file="${cmd_dir}/${sub}.bash"
  if [ -r "$file" ]; then
    # shellcheck source=/dev/null
    source "$file"
    if declare -F "cmd_${sub}" >/dev/null 2>&1; then
      "cmd_${sub}" "$@"
    elif declare -F "wgx_command_main" >/dev/null 2>&1; then
      wgx_command_main "$@"
    else
      printf '❌ Befehl %q definiert keinen Einstiegspunkt.\n' "$sub" >&2
      return 127
    fi
    return
  fi

  printf '❌ Unbekannter Befehl: %s\n' "$sub" >&2
  wgx_usage >&2
  return 1
}
