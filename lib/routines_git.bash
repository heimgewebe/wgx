#!/usr/bin/env bash

# shellcheck disable=SC2016
# jq filter expressions intentionally use single quotes so that jq interprets
# variables like $id, $mode, $risk as jq variables (passed via --arg), not shell expansions.
wgx_routine_git_repair_remote_head() {
  local mode="${1:-dry-run}" # internal: "dry-run" (CLI "preview") | "apply"
  local jq_bin="${WGX_JQ_BIN:-jq}"
  local git_bin="${WGX_GIT_BIN:-git}"
  local out_dir=".wgx/out"
  mkdir -p "$out_dir"

  if [[ "$mode" != "dry-run" && "$mode" != "apply" ]]; then
    echo "wgx routine git.repair.remote-head: invalid mode: $mode" >&2
    return 2
  fi

  # Check for dependencies early
  if ! command -v "$jq_bin" >/dev/null 2>&1; then
    echo "wgx routine: jq fehlt (setze WGX_JQ_BIN oder installiere jq)." >&2
    return 1
  fi
  if ! command -v "$git_bin" >/dev/null 2>&1; then
    echo "wgx routine: git fehlt (setze WGX_GIT_BIN oder installiere git)." >&2
    return 1
  fi

  # Detect SHA256 command
  local sha_cmd=""
  if command -v sha256sum >/dev/null 2>&1; then
    sha_cmd="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    sha_cmd="shasum -a 256"
  else
    echo "wgx routine: sha256sum or shasum required but not found." >&2
    return 1
  fi

  local routine_id="git.repair.remote-head"
  local ts
  ts="$(date -u +%s)"

  # NOTE: This routine assumes the remote is named "origin".
  # The audit logic currently makes the same assumption.

  local steps='[
    {"cmd":"git remote set-head origin --auto","why":"Restore origin/HEAD from remote HEAD"},
    {"cmd":"git fetch origin --prune","why":"Rebuild remote-tracking refs after head repair"}
  ]'

  # Policy:
  # - dry-run (preview): allowed even outside a git repo (viewer-mode).
  # - apply: must run inside a git repo (actor-mode).

  if [[ "$mode" == "dry-run" ]]; then
    local preview_file="routine.preview.${routine_id}.${ts}.json"

    "$jq_bin" -n --arg id "$routine_id" --arg mode "$mode" --arg risk "low" \
      --arg steps "$steps" \
      --arg note "Preview kann außerhalb eines Git-Repos erzeugt werden. Apply erfordert ein Git-Repo." \
      '{
        kind:"routine.preview",
        id:$id,
        mode:$mode,
        mutating:true,
        risk:$risk,
        steps:($steps|fromjson),
        note:$note
      }' \
      >"$out_dir/$preview_file"

    # Create generic fallback (best effort)
    cp "$out_dir/$preview_file" "$out_dir/routine.preview.json" 2>/dev/null || true

    echo "$out_dir/$preview_file"
    return 0
  fi

  # apply requires git repo
  if ! "$git_bin" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local err_msg="Apply abgebrochen: nicht in einem Git-Repo (work tree) ausgeführt."
    echo "$err_msg" >&2

    local result_file="routine.result.${routine_id}.${ts}.json"
    "$jq_bin" -n --arg id "$routine_id" --arg mode "$mode" --arg risk "low" \
      --arg stderr "$err_msg" \
      --arg steps "$steps" \
      '{
        kind:"routine.result",
        id:$id,
        mode:$mode,
        mutating:true,
        risk:$risk,
        steps:($steps|fromjson),
        ok:false,
        stderr:$stderr
      }' >"$out_dir/$result_file"
    cp "$out_dir/$result_file" "$out_dir/routine.result.json" 2>/dev/null || true
    echo "$out_dir/$result_file"
    return 1
  fi

  # apply
  local before
  before="$("$git_bin" show-ref 2>/dev/null | $sha_cmd | awk '{print $1}')"

  local log_stdout=""
  local log_stderr=""
  local ok=true

  # Validate steps JSON early (avoid jq hard-fail later)
  if ! "$jq_bin" -e . >/dev/null 2>&1 <<<"$steps"; then
    echo "Error: steps JSON invalid" >&2
    return 1
  fi

  while IFS= read -r cmd; do
    log_stdout+="> $cmd"$'\n'
    # Execute command, capture stdout and stderr, check exit code
    local out err rc=0
    # Use temporary files for capturing output to avoid subshell variable scope issues or complex piping
    local t_out t_err
    t_out="$(mktemp)"
    t_err="$(mktemp)"

    # Run command without aborting the script on error
    # Security: Allowlist specific git commands to prevent injection
    case "$cmd" in
    "git remote set-head origin --auto" | "git fetch origin --prune") ;;
    *)
      log_stderr+="Refusing unexpected command: $cmd"$'\n'
      ok=false
      break
      ;;
    esac

    bash -c "$cmd" >"$t_out" 2>"$t_err" || rc=$?

    out="$(cat "$t_out")"
    err="$(cat "$t_err")"
    rm -f "$t_out" "$t_err"

    if [[ -n "$out" ]]; then log_stdout+="$out"$'\n'; fi
    if [[ -n "$err" ]]; then log_stderr+="$err"$'\n'; fi

    if [[ $rc -ne 0 ]]; then
      ok=false
      log_stderr+="Command failed with exit code $rc: $cmd"$'\n'
      break
    fi
  done < <("$jq_bin" -r '.[].cmd' <<<"$steps")

  local after
  after="$("$git_bin" show-ref 2>/dev/null | $sha_cmd | awk '{print $1}')"

  local result_file="routine.result.${routine_id}.${ts}.json"

  "$jq_bin" -n --arg id "$routine_id" --arg mode "$mode" --arg risk "low" \
    --arg before "$before" --arg after "$after" \
    --arg stdout "$log_stdout" --arg stderr "$log_stderr" \
    --argjson ok "$ok" \
    --arg steps "$steps" \
    '{
      kind:"routine.result",
      id:$id,
      mode:$mode,
      mutating:true,
      risk:$risk,
      steps:($steps|fromjson),
      ok:$ok,
      state_hash:{before:$before, after:$after},
      stdout:$stdout,
      stderr:$stderr
    }' >"$out_dir/$result_file"

  # Create generic fallback (best effort)
  cp "$out_dir/$result_file" "$out_dir/routine.result.json" 2>/dev/null || true

  echo "$out_dir/$result_file"

  if [[ "$ok" != "true" ]]; then
    return 1
  fi
}
