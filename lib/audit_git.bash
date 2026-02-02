#!/usr/bin/env bash

wgx_audit_git() {
  local repo=""
  local correlation_id=""
  local stdout_json="false"
  local do_fetch="false"
  local jq_bin="${WGX_JQ_BIN:-jq}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --correlation-id)
      correlation_id="$2"
      shift 2
      ;;
    --stdout-json)
      stdout_json="true"
      shift
      ;;
    --fetch)
      do_fetch="true"
      shift
      ;;
    *)
      # Ignore unknown args or break? For now break to allow other flags if needed
      break
      ;;
    esac
  done

  # Generate ID if missing
  if [[ -z "$correlation_id" ]]; then
    if [[ -r /proc/sys/kernel/random/uuid ]]; then
      correlation_id="$(cat /proc/sys/kernel/random/uuid)"
    else
      correlation_id="$(date +%s)-$RANDOM"
    fi
  fi

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local cwd
  cwd="$(pwd)"

  # Facts gathering
  local head_sha head_ref local_branch detached
  head_sha="$(git rev-parse --short=12 HEAD 2>/dev/null || echo "")"
  head_ref="$(git rev-parse --symbolic-full-name HEAD 2>/dev/null || echo "")"
  local_branch="$(git branch --show-current 2>/dev/null || true)"
  detached="false"
  [[ -z "$local_branch" ]] && detached="true"

  local origin_url=""
  local origin_present="false"
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -n "$origin_url" ]]; then origin_present="true"; fi

  # Fetch only if requested
  local fetch_ok="false"
  local fetch_skipped="true"
  if [[ "$do_fetch" == "true" ]]; then
    fetch_skipped="false"
    if [[ "$origin_present" == "true" ]]; then
      if git fetch origin --prune >/dev/null 2>&1; then
        fetch_ok="true"
      fi
    fi
  fi

  local origin_head="false"
  git show-ref --verify --quiet refs/remotes/origin/HEAD && origin_head="true"

  local origin_main="false"
  git show-ref --verify --quiet refs/remotes/origin/main && origin_main="true"

  local remote_default_branch=""
  if [[ "$origin_head" == "true" ]]; then
    # sed to strip 'refs/remotes/' prefix for cleaner reading if desired,
    # but symbolic-ref output is canonical
    remote_default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)"
  fi

  # Upstream
  local upstream=""
  local upstream_exists="false"
  if [[ -n "$local_branch" ]]; then
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
    [[ -n "$upstream" ]] && upstream_exists="true"
  fi

  local ahead=0 behind=0
  if [[ "$upstream_exists" == "true" ]]; then
    local ab
    ab="$(git rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo "0 0")"
    behind="$(echo "$ab" | awk '{print $1}')"
    ahead="$(echo "$ab" | awk '{print $2}')"
  fi

  # Worktree
  local staged unstaged untracked clean
  # Use porcelain for robustness
  staged="$(git diff --cached --name-only | wc -l | tr -d ' ')"
  unstaged="$(git diff --name-only | wc -l | tr -d ' ')"
  untracked="$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')"
  clean="false"
  [[ "$staged" == "0" && "$unstaged" == "0" && "$untracked" == "0" ]] && clean="true"

  # Logic: Checks & Routines
  local status="ok"
  local checks_json="[]"
  local routines_json="[]"
  local u_level="0.0"
  local u_causes="[]"
  local u_meta="productive"

  # 1. Repo present
  # shellcheck disable=SC2016
  checks_json="$("$jq_bin" -c --arg id "git.repo.present" --arg st "ok" --arg msg "Repo detected." \
    '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"

  # 2. Remote origin
  if [[ "$origin_present" != "true" ]]; then
    status="error"
    # shellcheck disable=SC2016
    checks_json="$("$jq_bin" -c --arg id "git.remote.origin.present" --arg st "error" --arg msg "Remote origin missing." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  else
    # shellcheck disable=SC2016
    checks_json="$("$jq_bin" -c --arg id "git.remote.origin.present" --arg st "ok" --arg msg "Remote origin present." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  # 3. Fetch status (conditional)
  if [[ "$fetch_skipped" == "true" ]]; then
    # shellcheck disable=SC2016
    checks_json="$("$jq_bin" -c --arg id "git.fetch.skipped" --arg st "ok" --arg msg "Fetch skipped (default/read-only)." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"

    # If we didn't fetch, remote refs might be stale. Increase uncertainty.
    u_level="0.2"
    # shellcheck disable=SC2016
    u_causes="$("$jq_bin" -c '. + [{"kind":"stale_data","note":"Remote refs not refreshed (use --fetch to sync)."}]' <<<"$u_causes")"
  else
    if [[ "$origin_present" == "true" && "$fetch_ok" != "true" ]]; then
      status="error"
      # shellcheck disable=SC2016
      checks_json="$("$jq_bin" -c --arg id "git.fetch.performed" --arg st "error" --arg msg "git fetch origin failed." \
        '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
      u_level="0.35"
      # shellcheck disable=SC2016
      u_causes="$("$jq_bin" -c '. + [{"kind":"environment_variance","note":"Fetch failed, remote state uncertain."}]' <<<"$u_causes")"
    else
      # shellcheck disable=SC2016
      checks_json="$("$jq_bin" -c --arg id "git.fetch.performed" --arg st "ok" --arg msg "Fetched remote refs." \
        '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
    fi
  fi

  # 4. Remote HEAD
  if [[ "$origin_head" != "true" ]]; then
    # If not fetched, this might be expected stale state, but still technically an error for operations relying on it.
    # However, if origin is missing completely, we already flagged that.
    if [[ "$origin_present" == "true" ]]; then
      status="error"
      # shellcheck disable=SC2016
      checks_json="$("$jq_bin" -c --arg id "git.remote_head.discoverable" --arg st "error" --arg msg "origin/HEAD missing or dangling." \
        '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"

      # Suggest routine
      # shellcheck disable=SC2016
      routines_json="$("$jq_bin" -c \
        --arg id "git.repair.remote-head" \
        --arg risk "low" \
        --arg reason "origin/HEAD missing/dangling; restore remote head + refs." \
        '. + [{"id":$id,"risk":$risk,"mutating":true,"dry_run_supported":true,"reason":$reason,"requires":["git","jq"]}]' \
        <<<"$routines_json")"
    else
      # If origin missing, remote head missing is consequent
      # shellcheck disable=SC2016
      checks_json="$("$jq_bin" -c --arg id "git.remote_head.discoverable" --arg st "warn" --arg msg "Cannot check origin/HEAD (no origin)." \
        '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
    fi
  else
    # shellcheck disable=SC2016
    checks_json="$("$jq_bin" -c --arg id "git.remote_head.discoverable" --arg st "ok" --arg msg "origin/HEAD present." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  # 5. Remote main (canonical check)
  if [[ "$origin_main" != "true" ]]; then
    # similar logic, if origin present but main missing -> likely weird fetch state or different default branch
    if [[ "$origin_present" == "true" ]]; then
      # We don't error hard on 'main' missing if 'master' exists, but currently we just check main.
      # Let's emit a warning or info if we think it's just naming.
      # But for this specific audit scope (repair remote head often fixes this too), we flag it.
      # shellcheck disable=SC2016
      checks_json="$("$jq_bin" -c --arg id "git.origin_main.present" --arg st "warn" --arg msg "refs/remotes/origin/main missing." \
        '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"

      # Suggest routine if not already suggested?
      # We assume repair-remote-head helps here too.
      # shellcheck disable=SC2016
      routines_json="$("$jq_bin" -c \
        --arg id "git.repair.remote-head" \
        --arg risk "low" \
        --arg reason "origin/main missing; likely remote head/ref tracking broken locally." \
        '(. + [{"id":$id,"risk":$risk,"mutating":true,"dry_run_supported":true,"reason":$reason,"requires":["git","jq"]}]) | unique_by(.id)' \
        <<<"$routines_json")"
    fi
  else
    # shellcheck disable=SC2016
    checks_json="$("$jq_bin" -c --arg id "git.origin_main.present" --arg st "ok" --arg msg "origin/main present." \
      '. + [{"id":$id,"status":$st,"message":$msg}]' <<<"$checks_json")"
  fi

  # Construct artifacts
  # Ensure valid JSON numbers for stats
  local fact_staged
  fact_staged=$(("$staged" + 0))
  local fact_unstaged
  fact_unstaged=$(("$unstaged" + 0))
  local fact_untracked
  fact_untracked=$(("$untracked" + 0))
  local fact_ahead
  fact_ahead=$(("$ahead" + 0))
  local fact_behind
  fact_behind=$(("$behind" + 0))

  # Booleans for jq need to be raw true/false or --argjson
  # We used strings "true"/"false" above. Convert for JSON construction.
  local json_detached="$detached"
  local json_clean="$clean"
  # local json_origin_present="$origin_present" # Removed unused variable
  local json_origin_head="$origin_head"
  local json_origin_main="$origin_main"
  local json_upstream_exists="$upstream_exists"

  local artifact
  # shellcheck disable=SC2016
  artifact="$("$jq_bin" -n \
    --arg kind "audit.git" \
    --arg schema_version "v1" \
    --arg ts "$ts" \
    --arg correlation_id "$correlation_id" \
    --arg repo "${repo:-unknown}" \
    --arg cwd "$cwd" \
    --arg status "$status" \
    --arg head_sha "$head_sha" \
    --arg head_ref "$head_ref" \
    --argjson detached "$json_detached" \
    --arg local_branch "${local_branch:-null}" \
    --arg upstream "${upstream:-}" \
    --argjson upstream_exists "$json_upstream_exists" \
    --argjson origin_head "$json_origin_head" \
    --argjson origin_main "$json_origin_main" \
    --arg remote_default_branch "$remote_default_branch" \
    --argjson staged "$fact_staged" \
    --argjson unstaged "$fact_unstaged" \
    --argjson untracked "$fact_untracked" \
    --argjson clean "$json_clean" \
    --argjson ahead "$fact_ahead" \
    --argjson behind "$fact_behind" \
    --argjson checks "$checks_json" \
    --argjson routines "$routines_json" \
    --argjson u_level "$u_level" \
    --argjson u_causes "$u_causes" \
    --arg u_meta "$u_meta" \
    '{
      kind:$kind,
      schema_version:$schema_version,
      ts:$ts,
      correlation_id:$correlation_id,
      repo:$repo,
      cwd:$cwd,
      status:$status,
      facts:{
        head_sha:$head_sha,
        head_ref:$head_ref,
        is_detached_head:$detached,
        local_branch:(if $local_branch=="null" or $local_branch=="" then null else $local_branch end),
        upstream:(if $upstream=="" then null else {name:$upstream, exists_locally:true} end),
        remotes:(["origin"]),
        remote_default_branch:(if $remote_default_branch=="" then null else $remote_default_branch end),
        remote_refs:{
          origin_main:$origin_main,
          origin_head:$origin_head,
          origin_upstream:$upstream_exists
        },
        working_tree:{is_clean:$clean, staged:$staged, unstaged:$unstaged, untracked:$untracked},
        ahead_behind:{ahead:$ahead, behind:$behind}
      },
      checks:$checks,
      uncertainty:{level:($u_level|tonumber), causes:$u_causes, meta:$u_meta},
      suggested_routines:$routines
    }')"

  if [[ "$stdout_json" == "true" ]]; then
    echo "$artifact"
  else
    local out_dir=".wgx/out"
    mkdir -p "$out_dir"
    local filename="audit.git.v1.${correlation_id}.json"
    echo "$artifact" >"$out_dir/$filename"
    echo "$out_dir/$filename"
  fi

  return 0
}
