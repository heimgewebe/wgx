#!/usr/bin/env bash

# sync_cmd (from archiv/wgx)
sync_cmd() {
  require_repo
  local STAGED_ONLY=0 WIP=0 AMEND=0 SCOPE="auto" BASE="" signflag="" had_upstream=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --staged-only) STAGED_ONLY=1 ;;
      --wip) WIP=1 ;;
      --amend) AMEND=1 ;;
      --scope)
        if [[ -n "${2-}" ]]; then
          SCOPE="$2"
          shift
        else
          die "sync: --scope requires an argument."
        fi
        ;;
      --base)
        if [[ -n "${2-}" ]]; then
          BASE="$2"
          shift
        else
          die "sync: --base requires an argument."
        fi
        ;;
      --sign) signflag="-S" ;;
    esac
    shift || true
  done
  [[ -n "$BASE" ]] && WGX_BASE="$BASE"
  [[ "$(git_branch)" == "HEAD" ]] && die "Detached HEAD – bitte Branch anlegen."

  ((STAGED_ONLY == 0)) && git add -A
  [[ -f ".vale.ini" ]] && vale_maybe --staged || true

  local staged list scope n msg nf="files"
  staged="$(changed_files_cached || echo "")"
  list="${staged:-$(changed_files_all || echo "")}"
  scope="$([[ "$SCOPE" == "auto" ]] && (auto_scope "$list" || echo "repo") || echo "$SCOPE")"
  n=0
  [[ -n "$list" ]] && n=$(printf "%s\n" "$list" | wc -l | tr -d ' ')
  ((n == 1)) && nf="file"
  msg="feat(${scope}): sync @ $(date +"%Y-%m-%d %H:%M") [+${n} ${nf}]"
  ((WIP)) && msg="wip: ${msg}"

  if [[ -n "$staged" ]]; then
    local sf="${signflag:-$(maybe_sign_flag || true)}"
    if [[ -n "${sf-}" ]]; then
      git commit ${AMEND:+--amend} "$sf" -m "$msg" || die "Commit/Sign fehlgeschlagen."
    else
      git commit ${AMEND:+--amend} -m "$msg" || die "Commit fehlgeschlagen."
    fi
  else
    info "Nichts zu committen."
  fi

  if ((OFFLINE)); then
    warn "Offline: rebase/push übersprungen. (wgx heal rebase nachholen)"
  else
    _fetch_guard
    local base_ref="origin/$WGX_BASE"
    git rev-parse --verify -q "$base_ref" >/dev/null || base_ref="$WGX_BASE"
    git rev-parse --verify -q "$base_ref" >/dev/null || die "Basisbranch $WGX_BASE nicht gefunden (weder lokal noch origin/)."
    git rebase "$base_ref" || {
      warn "Rebase-Konflikt → wgx heal rebase"
      return 2
    }

    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then had_upstream=1; else had_upstream=0; fi
    if ((had_upstream)); then
      git push || die "Push fehlgeschlagen. Prüfe Zugriffsrechte/Netzwerk."
    else
      if git remote | grep -qx "origin"; then
        git push --set-upstream origin "$(git_branch)" || die "Push/Upstream fehlgeschlagen. Remote/ACL?"
      else
        warn "Kein 'origin' Remote → Push übersprungen."
      fi
    fi
  fi

  ok "Sync erledigt."
  local behind=0 ahead=0
  local IFS=' '
  read -r behind ahead < <(git_ahead_behind "$(git_branch)") || true
  info "Upstream: ahead=$ahead behind=$behind"
}

cmd_sync() {
    sync_cmd "$@"
}
