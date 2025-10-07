#!/usr/bin/env bash
# shellcheck shell=bash

if ! declare -F require_repo >/dev/null 2>&1; then
  require_repo() {
    if ! command -v git >/dev/null 2>&1; then
      die "git not installed."
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      die "Not in a git repository."
    fi
  }
fi

VALIDATE_LAST_JSON=""

validate::_trim_quotes() {
  local value="$1"
  value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [[ ${#value} -ge 2 ]]; then
    if [[ $value == "\""*"\"" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ $value == "'"*"'" ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s' "$value"
}

validate::_line_indent() {
  local line="$1"
  local indent=0
  local i char
  local length=${#line}
  for (( i=0; i<length; i++ )); do
    char="${line:i:1}"
    if [[ $char == ' ' ]]; then
      ((indent++))
      continue
    fi
    if [[ $char == $'\t' ]]; then
      ((indent+=2))
      continue
    fi
    break
  done
  printf '%d' "$indent"
}

validate::_format_json() {
  local label="$1"
  local ok="$2"
  local meta_json="$3"
  shift 3 || true
  python3 - "$label" "$ok" "$meta_json" "$@" <<'PY_FMT'
import json
import sys

label = sys.argv[1]
ok = sys.argv[2].lower() == "true"
meta = sys.argv[3]
errors = list(sys.argv[4:])

payload = {"ok": ok, "errors": errors}
if label:
    payload["repo"] = label
if meta:
    try:
        extra = json.loads(meta)
    except json.JSONDecodeError:
        extra = {}
    for key, value in extra.items():
        if value not in (None, ""):
            payload[key] = value

print(json.dumps(payload, ensure_ascii=False, separators=(',', ':')))
PY_FMT
}

validate::_inline_map_entries() {
  local map="$1"
  local content="${map#\{}"
  content="${content%\}}"
  local depth=0
  local in_quote=""
  local prev=""
  local entry=""
  local i char
  local length=${#content}
  for (( i=0; i<length; i++ )); do
    char="${content:i:1}"
    if [[ -n $in_quote ]]; then
      entry+="$char"
      if [[ $char == $in_quote && $prev != '\\' ]]; then
        in_quote=""
      fi
      prev="$char"
      continue
    fi
    case "$char" in
      "\""|"'")
        in_quote="$char"
        entry+="$char"
        ;;
      '{'|'[')
        ((depth++))
        entry+="$char"
        ;;
      '}'|']')
        if (( depth > 0 )); then
          ((depth--))
        fi
        entry+="$char"
        ;;
      ',')
        if (( depth == 0 )); then
          printf '%s\n' "$(printf '%s' "$entry" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
          entry=""
        else
          entry+="$char"
        fi
        ;;
      *)
        entry+="$char"
        ;;
    esac
    prev="$char"
  done
  if [[ -n $entry ]]; then
    printf '%s\n' "$(printf '%s' "$entry" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  fi
}

validate::_read_profile_fields_raw() {
  local dir="$1"
  local file=""
  local candidate
  for candidate in "$dir/.wgx/profile.yml" "$dir/.wgx/profile.yaml" "$dir/.wgx/profile.json"; do
    if [[ -f $candidate ]]; then
      file="$candidate"
      break
    fi
  done
  [[ -n $file ]] || return 1

  local ext="${file##*.}"
  local api="" req_range="" req_min="" kind="" tasks_count=""

  if [[ $ext == json ]]; then
    local json_output
    if ! json_output="$(python3 - "$file" <<'PY' 2>/dev/null
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as handle:
    data = json.load(handle) or {}

wgx = data.get('wgx') or {}
api = str(wgx.get('apiVersion') or '')
req = wgx.get('requiredWgx')
req_range = ''
req_min = ''
if isinstance(req, str):
    req_range = str(req)
elif isinstance(req, dict):
    if req.get('range') not in (None, ''):
        req_range = str(req.get('range'))
    if req.get('min') not in (None, ''):
        req_min = str(req.get('min'))
kind = str(wgx.get('repoKind') or '')
tasks = wgx.get('tasks') or {}
if isinstance(tasks, dict):
    tasks_count = len(tasks)
elif isinstance(tasks, list):
    tasks_count = len(tasks)
elif isinstance(tasks, str):
    tasks_count = 1
else:
    tasks_count = 0

print('\n'.join([api, req_range, req_min, kind, str(tasks_count)]))
PY
    )"; then
      return 2
    fi
    printf '%s' "$json_output"
    return 0
  fi

  local in_wgx=0 required_indent=-1 tasks_indent=-1 task_entry_indent=-1 required_open=0
  local line trimmed indent raw
  while IFS= read -r raw || [[ -n $raw ]]; do
    line="${raw%%$'\r'}"
    trimmed="$(printf '%s' "$line" | sed 's/#.*$//; s/[[:space:]]*$//')"
    trimmed="${trimmed#${trimmed%%[![:space:]]*}}"
    [[ -z $trimmed ]] && continue
    indent=$(validate::_line_indent "$line")

    if (( in_wgx )) && (( indent <= tasks_indent )); then
      tasks_indent=-1
      task_entry_indent=-1
    fi
    if (( in_wgx )) && (( indent <= required_indent )); then
      required_indent=-1
      required_open=0
    fi

    if [[ ${trimmed} == wgx:* ]]; then
      in_wgx=1
      continue
    fi

    if (( ! in_wgx )); then
      continue
    fi

    if [[ $trimmed =~ ^apiVersion:[[:space:]]*(.*)$ ]]; then
      api="$(validate::_trim_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ $trimmed =~ ^requiredWgx:[[:space:]]*(.*)$ ]]; then
      local raw_value="${BASH_REMATCH[1]}"
      local cleaned="$(printf '%s' "$raw_value" | sed 's/[[:space:]]*$//')"
      if [[ -z $cleaned ]]; then
        required_indent=$indent
        required_open=1
      elif [[ $cleaned == \{* && $cleaned == *\} ]]; then
        local entry
        while IFS= read -r entry; do
          [[ -z $entry ]] && continue
          if [[ $entry =~ ^([[:alnum:]_-]+)[[:space:]]*:(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="$(validate::_trim_quotes "${BASH_REMATCH[2]}")"
            case "$key" in
            range) req_range="$val" ;;
            min) req_min="$val" ;;
            esac
          fi
        done < <(validate::_inline_map_entries "$cleaned")
        required_indent=-1
        required_open=0
      else
        required_indent=$indent
        required_open=1
        local value="$(validate::_trim_quotes "$cleaned")"
        if [[ -n $value && $value != "{" ]]; then
          req_range="$value"
        fi
      fi
      continue
    fi

    if (( required_open )); then
      if [[ $trimmed =~ ^range:[[:space:]]*(.*)$ ]]; then
        req_range="$(validate::_trim_quotes "${BASH_REMATCH[1]}")"
        continue
      fi
      if [[ $trimmed =~ ^min:[[:space:]]*(.*)$ ]]; then
        req_min="$(validate::_trim_quotes "${BASH_REMATCH[1]}")"
        continue
      fi
      continue
    fi

    if [[ $trimmed =~ ^repoKind:[[:space:]]*(.*)$ ]]; then
      kind="$(validate::_trim_quotes "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ $trimmed =~ ^tasks:[[:space:]]*(.*)$ ]]; then
      local rest="${BASH_REMATCH[1]}"
      local cleaned_tasks="$(printf '%s' "$rest" | sed 's/[[:space:]]*$//')"
      tasks_indent=$indent
      task_entry_indent=-1
      if [[ -n $cleaned_tasks && $cleaned_tasks == \{* && $cleaned_tasks == *\} ]]; then
        local entry count=0
        while IFS= read -r entry; do
          [[ -z $entry ]] && continue
          ((count++))
        done < <(validate::_inline_map_entries "$cleaned_tasks")
        if [[ -z $tasks_count ]]; then
          tasks_count=0
        fi
        ((tasks_count+=count))
      elif [[ -n $cleaned_tasks && $cleaned_tasks == \[* && $cleaned_tasks == *\] ]]; then
        local seq="${cleaned_tasks#\[}"
        seq="${seq%\]}"
        local depth=0 in_quote="" prev="" char
        local length=${#seq} count=0 token=""
        for (( i=0; i<length; i++ )); do
          char="${seq:i:1}"
          if [[ -n $in_quote ]]; then
            if [[ $char == $in_quote && $prev != '\\' ]]; then
              in_quote=""
            fi
            prev="$char"
            continue
          fi
          case "$char" in
            "\""|"'") in_quote="$char" ;;
            '['|'{' ) ((depth++)) ;;
            ']'|'}' ) if (( depth > 0 )); then ((depth--)); fi ;;
            ',') if (( depth == 0 )); then ((count++)); fi ;;
          esac
          prev="$char"
        done
        if [[ ${#seq} -gt 0 ]]; then
          ((count++))
        fi
        if [[ -z $tasks_count ]]; then
          tasks_count=0
        fi
        ((tasks_count+=count))
      else
        if [[ -z $tasks_count ]]; then
          tasks_count=0
        fi
      fi
      continue
    fi

    if (( tasks_indent >= 0 )) && (( indent > tasks_indent )); then
      if [[ $trimmed =~ ^- ]]; then
        if [[ -z $tasks_count ]]; then
          tasks_count=0
        fi
        ((tasks_count++))
        continue
      fi
      if [[ $trimmed =~ ^([^:]+): ]]; then
        if (( task_entry_indent < 0 )); then
          task_entry_indent=$indent
        fi
        if (( indent == task_entry_indent )); then
          if [[ -z $tasks_count ]]; then
            tasks_count=0
          fi
          ((tasks_count++))
        fi
      fi
      continue
    fi
  done <"$file"

  printf '%s\n%s\n%s\n%s\n%s\n' "$api" "$req_range" "$req_min" "$kind" "$tasks_count"
  return 0
}

validate::_require_semver_module() {
  if ! declare -F semver_norm >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    source "${WGX_DIR:-.}/modules/semver.bash"
  fi
}

validate::_valid_semver_range() {
  local range="$1"
  if [[ -z $range ]]; then
    return 1
  fi
  if [[ $range == ^* ]]; then
    range="${range#^}"
  fi
  [[ $range =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]
}

validate::_valid_semver_value() {
  local version="$1"
  [[ -z $version ]] && return 1
  [[ $version =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]
}

validate::_build_meta_json() {
  local api="$1" req_range="$2" req_min="$3" kind="$4" tasks="$5"
  python3 - "$api" "$req_range" "$req_min" "$kind" "$tasks" <<'PY'
import json
import sys

api, req_range, req_min, kind, tasks = sys.argv[1:6]
payload = {}
if api:
    payload["apiVersion"] = api
if req_range:
    payload["requiredRange"] = req_range
if req_min:
    payload["requiredMin"] = req_min
if kind:
    payload["repoKind"] = kind
try:
    count = int(tasks)
except ValueError:
    count = None
if count is not None:
    payload["tasks"] = count
print(json.dumps(payload))
PY
}

validate::_check_dir() {
  local dir="$1"
  local label="$2"
  local json_mode="$3"

  local ok=true
  local -a errs=()
  local meta_json="{}"

  if [[ ! -d $dir ]]; then
    ok=false
    errs+=("path_not_found")
  else
    local -a fields=()
    local rc=0
    local tmp_output
    tmp_output="$(mktemp)"
    if validate::_read_profile_fields_raw "$dir" >"$tmp_output"; then
      mapfile -t fields <"$tmp_output"
      rc=0
    else
      rc=$?
    fi
    rm -f "$tmp_output"
    if (( rc != 0 )); then
      ok=false
      case $rc in
      1) errs+=("profile_missing") ;;
      2) errs+=("profile_unreadable") ;;
      *) errs+=("profile_error") ;;
      esac
    else
      local api="${fields[0]:-}" req_range="${fields[1]:-}" req_min="${fields[2]:-}" kind="${fields[3]:-}" tasks_count="${fields[4]:-}"
      meta_json="$(validate::_build_meta_json "$api" "$req_range" "$req_min" "$kind" "$tasks_count")"

      if [[ $api != v1 && $api != v1.1 ]]; then
        ok=false
        errs+=("version_unknown")
      fi

      local have_version="${WGX_VERSION:-0.0.0}"

      if [[ -n $req_range ]]; then
        if ! validate::_valid_semver_range "$req_range"; then
          ok=false
          errs+=("required_range_invalid")
        else
          validate::_require_semver_module
          if [[ $req_range == ^* ]]; then
            if ! semver_in_caret_range "$have_version" "$req_range"; then
              ok=false
              errs+=("required_range_unmet")
            fi
          else
            if ! semver_ge "$have_version" "$req_range"; then
              ok=false
              errs+=("required_range_unmet")
            fi
          fi
        fi
      fi

      if [[ -n $req_min ]]; then
        if ! validate::_valid_semver_value "$req_min"; then
          ok=false
          errs+=("required_min_invalid")
        else
          validate::_require_semver_module
          if ! semver_ge "$have_version" "$req_min"; then
            ok=false
            errs+=("required_min_unmet")
          fi
        fi
      fi

      if [[ -z $req_range && -z $req_min ]]; then
        ok=false
        errs+=("required_missing")
      fi

      if [[ -z $kind ]]; then
        ok=false
        errs+=("repoKind_missing")
      fi

      if [[ -z $tasks_count ]]; then
        ok=false
        errs+=("no_tasks")
      elif [[ $tasks_count =~ ^[0-9]+$ ]]; then
        if (( tasks_count == 0 )); then
          ok=false
          errs+=("no_tasks")
        fi
      fi
    fi
  fi

  if (( json_mode )); then
    local ok_str="false"
    [[ $ok == true ]] && ok_str="true"
    VALIDATE_LAST_JSON="$(validate::_format_json "$label" "$ok_str" "$meta_json" "${errs[@]}")"
  else
    local prefix=""
    if [[ -n $label ]]; then
      prefix+="$label: "
    fi
    if [[ $ok == true ]]; then
      echo "${prefix}manifest OK"
    else
      if ((${#errs[@]} > 0)); then
        echo "${prefix}manifest invalid: ${errs[*]}"
      else
        echo "${prefix}manifest invalid"
      fi
    fi
  fi

  [[ $ok == true ]]
  return $?
}

validate::_is_git_url() {
  local target="$1"
  [[ $target =~ ^(git@|ssh://|https?://|file://|git\+ssh://) ]]
}

validate::run() {
  local json_mode=0
  local -a targets=()
  local output_file=""

  while (($#)); do
    case "$1" in
    --json)
      json_mode=1
      ;;
    --out|--output)
      shift || true
      if [[ -z ${1-} ]]; then
        die "--out requires a path"
      fi
      output_file="$1"
      ;;
    --repo)
      shift || true
      if [[ -z ${1-} ]]; then
        die "--repo requires an argument"
      fi
      targets+=("$1")
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: wgx validate [--json] [--out FILE] [<path-or-git-url>...]

Validate the local manifest or additional repositories.

Examples:
  wgx validate
  wgx validate ../weltgewebe ../hauski
  wgx validate https://github.com/heimgewebe/weltgewebe
  wgx validate --json -- \
    https://github.com/heimgewebe/weltgewebe \
    https://github.com/heimgewebe/hausKI
USAGE
      return 0
      ;;
    --)
      shift || true
      while (($#)); do
        targets+=("$1")
        shift || true
      done
      break
      ;;
    *)
      targets+=("$1")
      ;;
    esac
    shift || true
  done

  if [[ -n $output_file && $json_mode -eq 0 ]]; then
    die "--out requires --json"
  fi

  if ((${#targets[@]} == 0)); then
    require_repo
    local rc=0
    if ! validate::_check_dir "." "" "$json_mode"; then
      rc=1
    fi
    if (( json_mode )); then
      printf '%s\n' "$VALIDATE_LAST_JSON"
      if [[ -n $output_file ]]; then
        mkdir -p "$(dirname "$output_file")"
        printf '%s\n' "$VALIDATE_LAST_JSON" >"$output_file"
      fi
    fi
    return $rc
  fi

  local status=0
  local -a json_results=()

  local target label clone_dir
  for target in "${targets[@]}"; do
    label="$target"
    if validate::_is_git_url "$target"; then
      clone_dir="$(mktemp -d)"
      local clone_output
      if ! clone_output="$(git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=30 clone --depth 1 --no-tags "$target" "$clone_dir" 2>&1)"; then
        rm -rf "$clone_dir"
        status=1
        if (( json_mode )); then
          local reason="clone_failed"
          if [[ $clone_output == *"Repository not found"* || $clone_output == *"not found"* ]]; then
            reason="repo_not_found"
          elif [[ $clone_output == *"Authentication"* || $clone_output == *"Permission denied"* ]]; then
            reason="auth_failed"
          fi
          VALIDATE_LAST_JSON="$(validate::_format_json "$label" "false" "{}" "$reason")"
          json_results+=("$VALIDATE_LAST_JSON")
        else
          echo "$label: failed to clone repository"
        fi
        continue
      fi

      if ! validate::_check_dir "$clone_dir" "$label" "$json_mode"; then
        status=1
      fi
      if (( json_mode )); then
        json_results+=("$VALIDATE_LAST_JSON")
      fi
      rm -rf "$clone_dir"
    elif [[ -d $target ]]; then
      if ! validate::_check_dir "$target" "$label" "$json_mode"; then
        status=1
      fi
      if (( json_mode )); then
        json_results+=("$VALIDATE_LAST_JSON")
      fi
    else
      if ! validate::_check_dir "$target" "$label" "$json_mode"; then
        status=1
      fi
      if (( json_mode )); then
        json_results+=("$VALIDATE_LAST_JSON")
      fi
    fi
  done

  if (( json_mode )); then
    if ((${#json_results[@]} == 1)); then
      printf '%s\n' "${json_results[0]}"
      VALIDATE_LAST_JSON="${json_results[0]}"
    else
      local overall_flag="false"
      if (( status == 0 )); then
        overall_flag="true"
      fi
      VALIDATE_LAST_JSON="$(python3 - "$overall_flag" "${json_results[@]}" <<'PY_AGG'
import json
import sys

overall = sys.argv[1].lower() == "true"
results = [json.loads(item) for item in sys.argv[2:]]
print(json.dumps({"ok": overall, "results": results}, ensure_ascii=False, separators=(',', ':')))
PY_AGG
      )"
      printf '%s\n' "$VALIDATE_LAST_JSON"
    fi
    if [[ -n $output_file ]]; then
      mkdir -p "$(dirname "$output_file")"
      printf '%s\n' "$VALIDATE_LAST_JSON" >"$output_file"
    fi
  fi

  return $status
}
