#!/usr/bin/env bash

# send_cmd (from archiv/wgx)
send_cmd() {
  # Handle help first
  case "${1-}" in
    -h | --help | help)
      cat <<'USAGE'
Usage:
  wgx send [options]

Description:
  Führt Guard-Checks aus, synchronisiert mit Remote und erstellt einen PR/MR.

Options:
  --draft           PR als Draft erstellen
  -i, --interactive PR-Body im Editor bearbeiten
  --title <text>    PR-Titel überschreiben
  --why <text>      Begründung für den PR
  --tests <text>    Beschreibung der durchgeführten Tests
  --notes <text>    Zusätzliche Notizen
  --label <name>    Label hinzufügen (mehrfach möglich)
  --issue <num>     Issue-Nummer verknüpfen
  --reviewers <u>   Reviewer zuweisen (kommasepariert oder 'auto')
  --scope <scope>   Scope überschreiben (auto|web|api|infra|devx|docs|meta|repo)
  --no-sync-first   Sync vor PR überspringen
  --sign            Commits signieren
  --base <branch>   Basis-Branch überschreiben
  --ci              CI-Workflow triggern (falls WGX_CI_WORKFLOW gesetzt)
  --open            PR nach Erstellung im Browser öffnen
  --auto-branch     Automatisch Branch erstellen, wenn auf Base
  -h, --help        Diese Hilfe anzeigen
USAGE
      return 0
      ;;
  esac

  require_repo
  local DRAFT=0 TITLE="" WHY="" TESTS="" NOTES="" SCOPE="auto" LABELS="${WGX_PR_LABELS-}" ISSUE="" BASE="" SYNC_FIRST=1 SIGN=0 INTERACTIVE=0 REVIEWERS="" TRIGGER_CI=0 OPEN_PR=0 AUTO_BRANCH=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --draft) DRAFT=1 ;;
      -i | --interactive) INTERACTIVE=1 ;;
      --title)
        if [[ -n "${2-}" ]]; then
          TITLE="$2"
          shift
        fi
        ;;
      --why)
        if [[ -n "${2-}" ]]; then
          WHY="$2"
          shift
        fi
        ;;
      --tests)
        if [[ -n "${2-}" ]]; then
          TESTS="$2"
          shift
        fi
        ;;
      --notes)
        if [[ -n "${2-}" ]]; then
          NOTES="$2"
          shift
        fi
        ;;
      --label)
        if [[ -n "${2-}" ]]; then
          LABELS="${LABELS:+$LABELS,}$2"
          shift
        fi
        ;;
      --issue | --issues)
        if [[ -n "${2-}" ]]; then
          ISSUE="$2"
          shift
        fi
        ;;
      --reviewers)
        if [[ -n "${2-}" ]]; then
          REVIEWERS="$2"
          shift
        fi
        ;;
      --scope)
        if [[ -n "${2-}" ]]; then
          SCOPE="$2"
          shift
        fi
        ;;
      --no-sync-first) SYNC_FIRST=0 ;;
      --sign) SIGN=1 ;;
      --base)
        shift
        BASE="${1-}"
        ;;
      --ci) TRIGGER_CI=1 ;;
      --open) OPEN_PR=1 ;;
      --auto-branch) AUTO_BRANCH=1 ;;
      *) ;;
    esac
    shift || true
  done
  [[ -n "$BASE" ]] && WGX_BASE="$BASE"

  ((OFFLINE)) && die "send: Offline – PR/MR kann nicht erstellt werden."

  # Schutz: nicht direkt von Base & kein leeres Diff
  local current
  current="$(git_current_branch)"
  local AUTO_BRANCH_FLAG=$((AUTO_BRANCH || ${WGX_AUTO_BRANCH:-0}))
  if [[ "$current" == "$WGX_BASE" ]]; then
    if ((AUTO_BRANCH_FLAG)); then
      local slug
      slug="auto-pr-$(date +%Y%m%d-%H%M%S)"
      info "Base-Branch ($WGX_BASE) erkannt → auto Branch: $slug"
      git switch -c "$slug" || die "auto-branch fehlgeschlagen"
    else
      die "send: Du stehst auf Base ($WGX_BASE). Erst 'wgx start <slug>' – oder 'wgx send --auto-branch'."
    fi
  fi

  git fetch -q origin "$WGX_BASE" >/dev/null 2>&1 || true
  if git rev-parse --verify -q "origin/$WGX_BASE" >/dev/null; then
    git diff --quiet "origin/$WGX_BASE"...HEAD && die "send: Kein Diff zu origin/$WGX_BASE → Nichts zu senden."
  fi

  guard_run
  local rc=$?
  ((rc == 1 && (ASSUME_YES || ${WGX_DRAFT_ON_WARN:-0}))) && DRAFT=1
  if ((SYNC_FIRST)); then
    if ! cmd_sync ${SIGN:+--sign} --scope "${SCOPE}" --base "$WGX_BASE"; then
      warn "Sync fehlgeschlagen → PR abgebrochen."
      return 1
    fi
  fi

  local files scope short
  files="$(git diff --name-only "origin/$WGX_BASE"...HEAD 2>/dev/null || true)"
  scope="$([[ "$SCOPE" == "auto" ]] && (auto_scope "$files" || echo "repo") || echo "$SCOPE")"
  local last_subject
  last_subject="$(git log -1 --pretty=%s 2>/dev/null || true)"
  short="${TITLE:-${last_subject:-"Änderungen an ${scope}"}}"
  local TITLE2="[${scope}] ${short}"

  local body
  body="$(render_pr_body "$TITLE2" "$short" "${WHY:-"—"}" "${TESTS:-"—"}" "${ISSUE:-""}" "${NOTES:-""}")"
  if ((INTERACTIVE)); then
    local tmpf
    tmpf="$(mktemp -t wgx-pr.XXXXXX)"
    printf "%s" "$body" >"$tmpf"
    bash -lc "${WGX_EDITOR:-${EDITOR:-nano}} $(printf '%q' "$tmpf")"
    body="$(cat "$tmpf")"
    rm -f "$tmpf"
  fi
  [[ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]] && die "PR-Body ist leer oder nur Whitespace – abgebrochen."

  local autoL
  autoL="$(derive_labels "$scope")"
  [[ -n "$autoL" ]] && LABELS="${LABELS:+$LABELS,}$autoL"
  LABELS="$(_sanitize_csv "$LABELS")"

  case "$(host_kind)" in
    gitlab)
      if has glab; then
        glab auth status >/dev/null 2>&1 || warn "glab nicht eingeloggt (glab auth login) – MR könnte scheitern."
        local args=(mr create --title "$TITLE2" --description "$body" --source-branch "$(git_current_branch)" --target-branch "$WGX_BASE")
        ((DRAFT)) && args+=(--draft)
        [[ -n "$ISSUE" ]] && args+=(--issue "$ISSUE")
        if [[ -n "$LABELS" ]]; then
          IFS=, read -r -a _labels <<<"$LABELS"
          local _l
          for _l in "${_labels[@]}"; do
            _l="$(trim "$_l")"
            [[ -n "$_l" ]] && args+=(--label "$_l")
          done
        fi
        if [[ "$REVIEWERS" == "auto" ]]; then
          local rlist="" r
          rlist="$(printf "%s\n" "$files" | _codeowners_reviewers || true)"
          [[ -n "$rlist" ]] && {
            while IFS= read -r r; do [[ -n "$r" ]] && args+=(--reviewer "$r"); done <<<"$rlist"
            info "Reviewer (auto): $(printf '%s' "$rlist" | tr '\n' ' ')"
          }
        elif [[ -n "$REVIEWERS" ]]; then
          IFS=, read -r -a rv <<<"$REVIEWERS"
          local r
          for r in "${rv[@]}"; do
            r="$(trim "$r")"
            [[ -n "$r" ]] && args+=(--reviewer "$r")
          done
        fi
        glab "${args[@]}" || die "glab mr create fehlgeschlagen."
        ok "Merge Request erstellt."
        ((OPEN_PR)) && glab mr view --web >/dev/null 2>&1 || true
      else
        warn "glab CLI nicht gefunden. MR manuell im GitLab anlegen."
        local url
        url="$(compare_url)"
        [[ -n "$url" ]] && echo "Vergleich: $url"
      fi
      ;;
    github | *)
      if has gh; then
        gh auth status >/dev/null 2>&1 || warn "gh nicht eingeloggt (gh auth login) – PR könnte scheitern."
        local args=(pr create --title "$TITLE2" --body "$body" --base "$WGX_BASE")
        ((DRAFT)) && args+=(--draft)
        if [[ -n "$LABELS" ]]; then
          IFS=, read -r -a L <<<"$LABELS"
          local l
          for l in "${L[@]}"; do
            l="$(trim "$l")"
            [[ -n "$l" ]] && args+=(--label "$l")
          done
        fi
        [[ -n "$ISSUE" ]] && args+=(--issue "$ISSUE")
        if [[ "$REVIEWERS" == "auto" ]]; then
          local rlist="" r2
          rlist="$(printf "%s\n" "$files" | _codeowners_reviewers || true)"
          if [[ -n "$rlist" ]]; then
            while IFS= read -r r2; do [[ -n "$r2" ]] && args+=(--reviewer "$r2"); done <<<"$rlist"
            info "Reviewer (auto): $(printf '%s' "$rlist" | tr '\n' ' ')"
          else warn "CODEOWNERS ohne User-Reviewer."; fi
        elif [[ -n "$REVIEWERS" ]]; then
          IFS=, read -r -a rvw2 <<<"$REVIEWERS"
          local r3
          for r3 in "${rvw2[@]}"; do
            r3="$(trim "$r3")"
            [[ -n "$r3" ]] && args+=(--reviewer "$r3")
          done
        fi
        gh "${args[@]}" || die "gh pr create fehlgeschlagen."
        local pr_url
        pr_url="$(gh pr view --json url -q .url 2>/dev/null || true)"
        [[ -n "$pr_url" ]] && info "PR: $pr_url"
        ok "PR erstellt."
        ((TRIGGER_CI)) && [[ -n "${WGX_CI_WORKFLOW-}" ]] && gh workflow run "$WGX_CI_WORKFLOW" >/dev/null 2>&1 || true
        ((OPEN_PR)) && gh pr view -w >/dev/null 2>&1 || true
      else
        local url
        url="$(compare_url)"
        echo "gh CLI nicht gefunden. PR manuell anlegen."
        [[ -n "$url" ]] && echo "URL: $url"
        echo "Labels: $LABELS"
        echo "--- PR Text ---"
        echo "$body"
      fi
      ;;
  esac
}

cmd_send() {
    send_cmd "$@"
}
