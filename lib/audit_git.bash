#!/usr/bin/env bash
set -euo pipefail

wgx_audit_git() {
  local repo="${1:-}"
  local cwd
  cwd="$(pwd)"

  # helper to append check/routine (needs jq)
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for wgx audit git" >&2
    exit 1
  fi

  local head_sha head_ref local_branch detached_bool
  head_sha="$(git rev-parse --short=12 HEAD 2>/dev/null || echo "")"
  head_ref="$(git rev-parse --symbolic-full-name HEAD 2>/dev/null || echo "")"
  local_branch="$(git branch --show-current 2>/dev/null || true)"
  detached_bool="false"
  [[ -z "$local_branch" ]] && detached_bool="true"

  local origin_present_bool="false"
  git remote get-url origin >/dev/null 2>&1 && origin_present_bool="true"

  # fetch
  local fetch_ok_bool="false"
  if [[ "$origin_present_bool" == "true" ]]; then
    if git fetch origin --prune >/dev/null 2>&1; then
      fetch_ok_bool="true"
    fi
  fi

  local origin_head_bool="false"
  git show-ref --verify --quiet refs/remotes/origin/HEAD && origin_head_bool="true"

  local origin_main_bool="false"
  git show-ref --verify --quiet refs/remotes/origin/main && origin_main_bool="true"

  local remote_default_branch=""
  if [[ "$origin_head_bool" == "true" ]]; then
    remote_default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)"
  fi

  # upstream
  local upstream=""
  local upstream_exists_bool="false"
  local origin_upstream_bool="false"
  if [[ -n "$local_branch" ]]; then
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
    if [[ -n "$upstream" ]]; then
      upstream_exists_bool="true"
      origin_upstream_bool="true"
    fi
  fi

  local ahead=0 behind=0
  if [[ "$upstream_exists_bool" == "true" ]]; then
    # ahead behind
    local ab
    ab="$(git rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo "0 0")"
    behind="$(awk '{print $1}' <<<"$ab")"
    ahead="$(awk '{print $2}' <<<"$ab")"
  fi

  # worktree
  local staged unstaged untracked clean_bool
  staged="$(git diff --cached --name-only | wc -l | tr -d ' ')"
  unstaged="$(git diff --name-only | wc -l | tr -d ' ')"
  untracked="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
  clean_bool="false"
  [[ "$staged" == "0" && "$unstaged" == "0" && "$untracked" == "0" ]] && clean_bool="true"

  # checks + routines
  local status="ok"
  local checks_json="[]"
  local routines_json="[]"

  checks_json="$(jq -c --arg id "git.repo.present" --arg st "ok" --arg msg "Repo detected." \
    '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"

  if [[ "$origin_present_bool" != "true" ]]; then
    status="error"
    checks_json="$(jq -c --arg id "git.remote.origin.present" --arg st "error" --arg msg "Remote origin missing." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  else
    checks_json="$(jq -c --arg id "git.remote.origin.present" --arg st "ok" --arg msg "Remote origin present." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  if [[ "$origin_present_bool" == "true" && "$fetch_ok_bool" != "true" ]]; then
    status="error"
    checks_json="$(jq -c --arg id "git.fetch.ok" --arg st "error" --arg msg "git fetch origin failed." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  else
    checks_json="$(jq -c --arg id "git.fetch.ok" --arg st "ok" --arg msg "Fetched remote refs." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  if [[ "$origin_head_bool" != "true" ]]; then
    status="error"
    checks_json="$(jq -c --arg id "git.remote_head.discoverable" --arg st "error" --arg msg "origin/HEAD missing or dangling." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
    routines_json="$(jq -c \
      --arg id "git.repair.remote-head" \
      --arg risk "low" \
      --arg reason "origin/HEAD missing/dangling; restore remote head + refs." \
      '. + [{"id":$id,"risk":$risk,"mutating":true,"dry_run_supported":true,"reason":$reason,"requires":["git","jq"]}]' \
      <<<"$routines_json")"
  else
    checks_json="$(jq -c --arg id "git.remote_head.discoverable" --arg st "ok" --arg msg "origin/HEAD present." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  if [[ "$origin_main_bool" != "true" ]]; then
    status="error"
    checks_json="$(jq -c --arg id "git.origin_main.present" --arg st "error" --arg msg "refs/remotes/origin/main missing." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
    # same routine helps
    routines_json="$(jq -c \
      --arg id "git.repair.remote-head" \
      --arg risk "low" \
      --arg reason "origin/main missing; likely remote head/ref tracking broken locally." \
      '(. + [{"id":$id,"risk":$risk,"mutating":true,"dry_run_supported":true,"reason":$reason,"requires":["git","jq"]}]) | unique_by(.id)' \
      <<<"$routines_json")"
  else
    checks_json="$(jq -c --arg id "git.origin_main.present" --arg st "ok" --arg msg "origin/main present." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  # uncertainty
  local u_level="0.15"
  local u_meta="productive"
  local u_causes='[{"kind":"remote_ref_inconsistency","note":"Remote tracking refs may be incomplete or pruned unexpectedly."}]'
  if [[ "$origin_present_bool" != "true" || "$fetch_ok_bool" != "true" ]]; then
    u_level="0.35"
    u_meta="systemic"
    u_causes='[{"kind":"environment_variance","note":"Remote or network/tooling state prevents reliable ref discovery."}]'
  fi

  # Handle nulls for jq args
  local local_branch_json="null"
  if [[ -n "$local_branch" ]]; then local_branch_json="\"$local_branch\""; fi

  local upstream_json="null"
  if [[ -n "$upstream" ]]; then upstream_json="{\"name\":\"$upstream\", \"exists_locally\":true}"; fi

  local remote_default_branch_json="null"
  if [[ -n "$remote_default_branch" ]]; then remote_default_branch_json="\"$remote_default_branch\""; fi

  # write artifact
  mkdir -p .wgx/out
  jq -n \
    --arg kind "audit.git" \
    --arg schema_version "v1" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg repo "${repo:-unknown}" \
    --arg cwd "$cwd" \
    --arg status "$status" \
    --arg head_sha "$head_sha" \
    --arg head_ref "$head_ref" \
    --argjson detached "$detached_bool" \
    --argjson local_branch "$local_branch_json" \
    --argjson upstream "$upstream_json" \
    --argjson origin_head "$origin_head_bool" \
    --argjson origin_main "$origin_main_bool" \
    --argjson origin_upstream "$origin_upstream_bool" \
    --argjson remote_default_branch "$remote_default_branch_json" \
    --argjson staged "$staged" \
    --argjson unstaged "$unstaged" \
    --argjson untracked "$untracked" \
    --argjson clean "$clean_bool" \
    --argjson ahead "$ahead" \
    --argjson behind "$behind" \
    --argjson checks "$checks_json" \
    --argjson routines "$routines_json" \
    --argjson u_level "$u_level" \
    --argjson u_causes "$u_causes" \
    --arg u_meta "$u_meta" \
    '{
      kind:$kind,
      schema_version:$schema_version,
      ts:$ts,
      repo:$repo,
      cwd:$cwd,
      status:$status,
      facts:{
        head_sha:$head_sha,
        head_ref:$head_ref,
        is_detached_head:$detached,
        local_branch:$local_branch,
        upstream:$upstream,
        remotes:(["origin"]),
        remote_default_branch:$remote_default_branch,
        remote_refs:{
          origin_main:$origin_main,
          origin_head:$origin_head,
          origin_upstream:$origin_upstream
        },
        working_tree:{is_clean:$clean, staged:$staged, unstaged:$unstaged, untracked:$untracked},
        ahead_behind:{ahead:$ahead, behind:$behind}
      },
      checks:$checks,
      uncertainty:{level:$u_level, causes:$u_causes, meta:$u_meta},
      suggested_routines:$routines
    }' >.wgx/out/audit.git.v1.json

  echo ".wgx/out/audit.git.v1.json"
}
