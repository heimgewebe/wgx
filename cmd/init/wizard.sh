#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WGX_BIN="${WGX_DIR:-$REPO_DIR}/wgx"
PROFILE_DIR="$REPO_DIR/.wgx"
PROFILE_PATH="$PROFILE_DIR/profile.yml"

mkdir -p "$PROFILE_DIR"

if [[ -f "$PROFILE_PATH" ]]; then
  read -rp "Es existiert bereits ein .wgx/profile.yml. Überschreiben? [y/N] " answer
  case "${answer:-}" in
  y | Y | yes | YES) ;;
  *)
    echo "Abgebrochen."
    exit 0
    ;;
  esac
fi

read -rp "Repository-Typ [generic]: " repo_kind
repo_kind=${repo_kind:-generic}
read -rp "Bevorzugter Env-Manager (z. B. uv/pip/npm) [system]: " env_prefer
env_prefer=${env_prefer:-system}

declare -a selected_tasks=()
declare -A task_cmd=()
declare -A task_args=()
declare -A task_safe=()

declare -a default_tasks=(test lint build)
for task in "${default_tasks[@]}"; do
  read -rp "Befehl für Task '${task}' (leer zum Überspringen): " cmd
  if [[ -z "$cmd" ]]; then
    continue
  fi
  read -rp "Argumente für '${task}' (Leerzeichen getrennt, leer für keine): " arg_line
  read -rp "Als 'safe' markieren? [Y/n]: " safe_answer
  case "${safe_answer:-}" in
  n | N | no | NO) safe=false ;;
  *) safe=true ;;
  esac
  selected_tasks+=("$task")
  task_cmd["$task"]="$cmd"
  task_args["$task"]="$arg_line"
  task_safe["$task"]="$safe"
done

if ((${#selected_tasks[@]} == 0)); then
  echo "Keine Tasks ausgewählt – breche ab." >&2
  exit 1
fi

yaml_escape() {
  local input="$1"
  local dq='"'
  input=${input//\\/\\\\}
  input=${input//${dq}/\"}
  printf '%s' "$input"
}

format_args() {
  local line="$1"
  if [[ -z "$line" ]]; then
    printf '[]'
    return
  fi
  local -a items
  read -r -a items <<<"$line"
  printf '['
  local first=1
  local item
  for item in "${items[@]}"; do
    if ((first)); then
      first=0
    else
      printf ', '
    fi
    printf '"%s"' "$(yaml_escape "$item")"
  done
  printf ']'
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

{
  printf 'wgx:\n'
  printf '  apiVersion: v1.1\n'
  printf '  repoKind: "%s"\n' "$(yaml_escape "$repo_kind")"
  printf '  envDefaults:\n'
  printf '    WGX_ENV_PREFER: "%s"\n' "$(yaml_escape "$env_prefer")"
  printf '  tasks:\n'
  for task in "${selected_tasks[@]}"; do
    printf '    %s:\n' "$task"
    printf '      desc: "%s"\n' "$(yaml_escape "Wizard task: $task")"
    printf '      safe: %s\n' "${task_safe[$task]}"
    printf '      cmd: "%s"\n' "$(yaml_escape "${task_cmd[$task]}")"
    printf '      args: %s\n' "$(format_args "${task_args[$task]}")"
  done
} >"$tmp_file"

mv "$tmp_file" "$PROFILE_PATH"
trap - EXIT

if "$WGX_BIN" validate >/dev/null 2>&1; then
  echo "Profil erfolgreich erstellt: $PROFILE_PATH"
else
  echo "wgx validate meldete Fehler:" >&2
  "$WGX_BIN" validate || true
  echo "Diff (neu erzeugte Datei):" >&2
  diff -u /dev/null "$PROFILE_PATH" || true
  exit 1
fi
