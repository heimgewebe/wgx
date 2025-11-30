#!/usr/bin/env bash

# heal_cmd (from archiv/wgx)
heal_cmd() {
  local MODE="${1-}"

  # Handle help first
  case "$MODE" in
  -h | --help | help)
    cat <<'USAGE'
Usage:
  wgx heal [rebase|ours|theirs|ff-only] [--stash] [--continue] [--abort] [--base <branch>]

Description:
  Löst Konflikte oder führt ein Rebase auf den Basis-Branch durch.

Modes:
  rebase      Rebase auf origin/$WGX_BASE (Standard)
  ours        Merge mit --ours Strategie
  theirs      Merge mit --theirs Strategie
  ff-only     Fast-Forward only Merge

Options:
  --stash       Vor dem Heal einen Snapshot (Stash) erstellen
  --continue    Laufenden Rebase fortsetzen
  --abort       Laufenden Rebase/Merge abbrechen
  --base <b>    Alternativen Basis-Branch verwenden
  -h, --help    Diese Hilfe anzeigen
USAGE
    return 0
    ;;
  esac

  require_repo

  # If MODE is a recognized mode, shift it; otherwise, keep it for parsing as an option
  case "$MODE" in
  rebase | ours | theirs | ff-only | "")
    shift || true
    ;;
  --*)
    # MODE is actually an option, leave MODE empty
    MODE=""
    ;;
  *)
    shift || true
    ;;
  esac

  local STASH=0 CONT=0 ABORT=0 BASE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --stash) STASH=1 ;;
    --continue) CONT=1 ;;
    --abort) ABORT=1 ;;
    --base)
      if [[ -n "${2-}" ]]; then
        BASE="$2"
        shift
      else
        die "heal: --base requires an argument."
      fi
      ;;
    *) ;;
    esac
    shift || true
  done
  [[ -n "$BASE" ]] && WGX_BASE="$BASE"

  if ((ABORT)); then
    if git rebase --abort 2>/dev/null || git merge --abort 2>/dev/null; then
      ok "Abgebrochen."
      return 0
    else
      warn "Kein Rebase/Merge zum Abbrechen gefunden."
      return 1
    fi
  fi

  ((CONT)) && {
    git add -A
    git rebase --continue || die "continue fehlgeschlagen."
    ok "Rebase fortgesetzt."
    return 0
  }
  ((STASH)) && snapshot_make

  _fetch_once
  case "$MODE" in
  "" | rebase)
    local base_ref="origin/$WGX_BASE"
    git rev-parse --verify -q "$base_ref" >/dev/null || base_ref="$WGX_BASE"
    git rev-parse --verify -q "$base_ref" >/dev/null || die "Basisbranch $WGX_BASE nicht gefunden."
    git rebase "$base_ref" || {
      warn "Konflikte. Löse sie, dann: wgx heal --continue | --abort"
      return 2
    }
    ;;
  ours) git merge -X ours "origin/$WGX_BASE" || {
    warn "Konflikte. manuell lösen + commit"
    return 2
  } ;;
  theirs) git merge -X theirs "origin/$WGX_BASE" || {
    warn "Konflikte. manuell lösen + commit"
    return 2
  } ;;
  ff-only) git merge --ff-only "origin/$WGX_BASE" || {
    warn "Fast-Forward nicht möglich."
    return 2
  } ;;
  *) die "Unbekannter heal-Modus: $MODE" ;;
  esac
  ok "Heal erfolgreich."
}

cmd_heal() {
  heal_cmd "$@"
}
