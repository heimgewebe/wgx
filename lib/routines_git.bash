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
  before="$(git show-ref --heads --tags --remotes 2>/dev/null | sha256sum | awk '{print $1}')"

  local log=""
  while IFS= read -r cmd; do
    log+="$cmd"$'\n'
    bash -c "$cmd" 2>&1 | tee -a /dev/stderr || true
  done < <(jq -r '.[].cmd' <<<"$steps")

  local after
  after="$(git show-ref --heads --tags --remotes 2>/dev/null | sha256sum | awk '{print $1}')"

  jq -n --arg id "git.repair.remote-head" --arg mode "$mode" --arg risk "low" \
    --arg before "$before" --arg after "$after" --arg log "$log" \
    --argjson steps "$steps" \
    '{
      kind:"routine.result",
      id:$id,
      mode:$mode,
      mutating:true,
      risk:$risk,
      steps:$steps,
      state_hash:{before:$before, after:$after},
      stdout:$log
    }' >"$out_dir/routine.result.json"

  echo "$out_dir/routine.result.json"
}
