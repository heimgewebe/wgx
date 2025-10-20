#!/usr/bin/env bash

# Wrapper to expose sync command via cmd/ dispatcher.
cmd_sync() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Bitte innerhalb eines Git-Repositories ausführen (kein Git-Repository erkannt)."
  fi

  local force=0 dry_run=0 base_override=""
  local -a positional=()

  while [ $# -gt 0 ]; do
    case "$1" in
    --force | -f)
      force=1
      shift
      ;;
    --dry-run | -n)
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
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx sync [--force] [--dry-run] [--base <branch>]

Description:
  Holt Änderungen vom Remote-Repository. Führt 'git pull --rebase --autostash' aus.
  Wenn dies fehlschlägt, wird ein Rebase auf den angegebenen Basis-Branch
  (Standard: $WGX_BASE oder 'main') versucht.

Options:
  --force, -f      Erzwingt den Sync, auch wenn das Arbeitsverzeichnis unsauber ist
                   (lokale Änderungen werden temporär gestasht).
  --dry-run, -n    Zeigt nur die geplanten Git-Befehle an.
  --base <branch>  Setzt den Fallback-Branch für den Rebase explizit.
  -h, --help       Diese Hilfe anzeigen.
USAGE
      return 0
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
      shift
      ;;
    esac
  done

  local base_spec="${base_override:-${positional[0]:-$WGX_BASE}}"
  [ -z "$base_spec" ] && base_spec="main"

  local base_remote base_branch
  read -r base_remote base_branch < <(_git_parse_remote_branch_spec "$base_spec" "origin")
  if [ -z "$base_branch" ]; then
    die "sync: Ungültiger Basis-Branch '${base_spec}'."
  fi
  local base_display="${base_remote}/${base_branch}"

  if [ -n "$base_override" ] && [ "${#positional[@]}" -gt 0 ]; then
    warn "--base überschreibt den angegebenen Branch '${positional[0]}'. Nutze ${base_display} als Basis."
  fi

  debug "cmd_sync: force=${force} dry_run=${dry_run} base_spec='${base_spec}' -> remote='${base_remote}' branch='${base_branch}'"

  local stash_ref=""
  local stash_required=0

  restore_stash() {
    [ -z "$stash_ref" ] && return

    debug "restore_stash: attempting apply --index für ${stash_ref}"
    if git -c merge.renames=true -c rerere.enabled=true stash apply --index "$stash_ref" >/dev/null 2>&1; then
      debug "stash apply --index für ${stash_ref} erfolgreich"
      git stash drop "$stash_ref" >/dev/null 2>&1 || true
      stash_ref=""
      info "Lokale Änderungen wiederhergestellt."
      return
    fi

    debug "restore_stash: attempting apply ohne --index für ${stash_ref}"
    if git -c merge.renames=true -c rerere.enabled=true stash apply "$stash_ref" >/dev/null 2>&1; then
      git add -A >/dev/null 2>&1 || true
      git stash drop "$stash_ref" >/dev/null 2>&1 || true
      stash_ref=""
      warn "Änderungen angewendet (ohne --index). Bitte Konflikte prüfen und ggf. auflösen."
      return
    fi

    warn "Automatisches Wiederherstellen aus ${stash_ref} ist fehlgeschlagen – bitte 'git stash pop --index ${stash_ref}' manuell ausführen und Konflikte lösen."
    stash_ref=""
  }

  if git_workdir_dirty; then
    local status
    status="$(git_workdir_status_short)"
    if ((force)); then
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – --force (-f) aktiv, wgx stasht temporär automatisch."
      stash_required=1
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
    info "[DRY-RUN] Geplante Schritte:"
    if ((stash_required)); then
      info "[DRY-RUN] git stash push --include-untracked --message wgx-sync-autostash"
      info "[DRY-RUN] (anschließend Wiederherstellung des Stash nach erfolgreichem Sync)"
    fi
    info "[DRY-RUN] git pull --rebase --autostash"
    info "[DRY-RUN] Fallback: git fetch ${base_remote} ${base_branch} && git rebase ${base_display}"
    return 0
  fi

  git_has_remote "$base_remote" || die "Kein ${base_remote}-Remote gefunden."

  if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    die "Kein Upstream für ${branch} konfiguriert. Setze ihn mit: git branch --set-upstream-to=${base_display} ${branch}"
  fi

  if ((stash_required)); then
    debug "cmd_sync: creating autostash vor Pull"
    if ! git stash push --include-untracked --message "wgx-sync-autostash" >/dev/null; then
      die "Konnte lokale Änderungen nicht automatisch stashen."
    fi
    stash_ref="$(git stash list --pretty='%gD' | head -n1)"
    debug "cmd_sync: erzeugter Stash ${stash_ref}"
  fi

  info "Pull (rebase, autostash) vom Remote…"
  if git pull --rebase --autostash; then
    restore_stash
    info "Sync abgeschlossen (${branch})."
    return 0
  fi

  warn "git pull --rebase --autostash fehlgeschlagen – versuche Rebase auf ${base_display}."
  info "Fetch von ${base_display}…"
  if ! git fetch "$base_remote" "$base_branch"; then
    restore_stash
    die "git fetch ${base_display} fehlgeschlagen"
  fi

  info "Rebase auf ${base_display}…"
  if ! git rebase "${base_display}"; then
    restore_stash
    die "Rebase fehlgeschlagen – bitte Konflikte manuell lösen oder 'wgx heal' (falls verfügbar) verwenden."
  fi

  restore_stash
  info "Sync abgeschlossen (${branch})."
}
