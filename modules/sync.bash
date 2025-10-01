#!/usr/bin/env bash

sync_cmd() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Bitte innerhalb eines Git-Repositories ausführen (kein Git-Repository erkannt)."
  fi

  local force=0 dry_run=0 base_override=""
  local -a positional=()

  while [ $# -gt 0 ]; do
    case "$1" in
    --force|-f)
      force=1
      shift
      ;;
    --dry-run|-n)
      dry_run=1
      shift
      ;;
    --base)
      shift
      if [ $# -eq 0 ]; then
        printf 'sync: option --base requires an argument\n' >&2
        return 2
      fi
      base_override="$1"
      shift
      ;;
    --base=*)
      base_override="${1#--base=}"
      shift
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        positional+=("$1")
        shift
      done
      break
      ;;
    -*)
      printf 'sync: unknown option %s\n' "$1" >&2
      return 2
      ;;
    *)
      positional+=("$1")
      ;;
    esac
  done

  if [ -n "$base_override" ] && [ "${#positional[@]}" -gt 0 ]; then
    warn "--base überschreibt den angegebenen Branch '${positional[0]}'."
  fi

  local base="${base_override:-${positional[0]:-$WGX_BASE}}"
  [ -z "$base" ] && base="main"

  if git_workdir_dirty; then
    local status
    status="$(git_workdir_status_short)"
    if ((force)); then
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – --force (-f) aktiv, Git stasht ggf. automatisch."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
    else
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – Sync abgebrochen."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
      warn "Nutze 'wgx sync --force/-f', wenn du trotzdem fortfahren willst (Änderungen werden ggf. gestasht)."
      # Maschinenlesbarer Marker für aufrufende Prozesse.
      printf 'sync aborted: working directory contains uncommitted changes\n'
      return 1
    fi
  fi

  local branch
  branch="$(git_current_branch)"
  if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
    die "Aktuell im detached HEAD – wechsle auf einen Branch oder nutze 'wgx reload'."
  fi

  if ((dry_run)); then
    log_info "[DRY-RUN] git pull --rebase --autostash --ff-only"
    log_info "[DRY-RUN] Fallback: git fetch origin ${base} && git rebase origin/${base}"
    return 0
  fi

  git_has_remote || die "Kein origin-Remote gefunden."

  log_info "Pull (rebase, autostash) vom Remote…"
  if git pull --rebase --autostash --ff-only; then
    log_info "Sync abgeschlossen (${branch})."
    return 0
  fi

  warn "Fast-Forward nicht möglich – versuche Rebase auf origin/${base}."
  log_info "Fetch von origin/${base}…"
  git fetch origin "$base" || die "git fetch origin ${base} fehlgeschlagen"

  log_info "Rebase auf origin/${base}…"
  git rebase "origin/${base}" || die "Rebase fehlgeschlagen – bitte Konflikte manuell lösen oder 'wgx heal' (falls verfügbar) verwenden."

  log_info "Sync abgeschlossen (${branch})."
}
