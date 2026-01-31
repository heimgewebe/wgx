#!/usr/bin/env bash
set -euo pipefail

wgx_routine_git_repair_remote_head() {
  local mode="${1:-dry-run}" # dry-run | apply
  local out_dir=".wgx/out"
  mkdir -p "$out_dir"

  local steps='[
    {"cmd":"git remote set-head origin --auto","why":"Restore origin/HEAD from remote HEAD"},
    {"cmd":"git fetch origin --prune","why":"Rebuild remote-tracking refs after head repair"}
  ]'

  # Check for jq presence
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for wgx routines" >&2
    exit 1
  fi

  if [[ "$mode" == "dry-run" ]]; then
    jq -n --arg id "git.repair.remote-head" --arg mode "$mode" --arg risk "low" \
      --argjson steps "$steps" \
      '{kind:"routine.preview", id:$id, mode:$mode, mutating:true, risk:$risk, steps:$steps}' \
      >"$out_dir/routine.preview.json"
    echo "$out_dir/routine.preview.json"
    exit 0
  fi

  # apply
  local before
  before="$(git show-ref 2>/dev/null | sha256sum | awk '{print $1}')"

  local log_stdout=""
  local log_stderr=""
  local ok="true"

  while IFS= read -r cmd; do
    log_stdout+="> $cmd"$'\n'
    # Execute command, capture stdout and stderr, check exit code
    local out err rc
    # Use temporary files for capturing output to avoid subshell variable scope issues or complex piping
    local t_out t_err
    t_out="$(mktemp)"
    t_err="$(mktemp)"

    set +e # Disable exit-on-error for the command execution
    bash -c "$cmd" >"$t_out" 2>"$t_err"
    rc=$?
    set -e

    out="$(cat "$t_out")"
    err="$(cat "$t_err")"
    rm -f "$t_out" "$t_err"

    if [[ -n "$out" ]]; then log_stdout+="$out"$'\n'; fi
    if [[ -n "$err" ]]; then log_stderr+="$err"$'\n'; fi

    if [[ $rc -ne 0 ]]; then
      ok="false"
      log_stderr+="Command failed with exit code $rc: $cmd"$'\n'
      break
    fi
  done < <(jq -r '.[].cmd' <<<"$steps")

  local after
  after="$(git show-ref 2>/dev/null | sha256sum | awk '{print $1}')"

  jq -n --arg id "git.repair.remote-head" --arg mode "$mode" --arg risk "low" \
    --arg before "$before" --arg after "$after" \
    --arg stdout "$log_stdout" --arg stderr "$log_stderr" \
    --argjson ok "$ok" \
    --argjson steps "$steps" \
    '{
      kind:"routine.result",
      id:$id,
      mode:$mode,
      mutating:true,
      risk:$risk,
      steps:$steps,
      ok:$ok,
      state_hash:{before:$before, after:$after},
      stdout:$stdout,
      stderr:$stderr
    }' >"$out_dir/routine.result.json"

  echo "$out_dir/routine.result.json"

  if [[ "$ok" != "true" ]]; then
    exit 1
  fi
}
