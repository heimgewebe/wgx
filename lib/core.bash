#!/usr/bin/env bash

# ---------- Logging ----------
log_info()  { printf '[INFO] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
die()       { log_error "$*"; exit 1; }

# ---------- Env / Defaults ----------
: "${WGX_BASE:=main}"

# ---------- Git helpers ----------
git_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""; }
git_is_repo_root() {
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(pwd -P)" = "$top" ]
}
git_has_remote()     { git remote -v | grep -q '^origin' 2>/dev/null; }

# Hard Reset auf origin/$WGX_BASE + Cleanup
git_hard_reload() {
  git_has_remote || die "Kein origin-Remote gefunden."
  local base="${1:-$WGX_BASE}"

  log_info "Fetch von origin…"
  git fetch --prune origin || die "git fetch fehlgeschlagen"

  log_info "Kompletter Reset auf origin/${base}… (alle lokalen Änderungen gehen verloren)"
  git reset --hard "origin/${base}" || die "git reset --hard fehlgeschlagen"

  log_info "Untracked/ignored aufräumen (clean -fdx)…"
  git clean -fdx || die "git clean fehlgeschlagen"

  log_info "Reload fertig."
}

# Optional: Safety Snapshot (Stash), nicht default-aktiv
snapshot_make() {
  git stash push -u -m "wgx snapshot $(date -u +%FT%TZ)" >/dev/null 2>&1 || true
  log_info "Snapshot (Stash) erstellt."
}

# ---------- Router ----------
wgx_usage() {
  cat <<USAGE
wgx — Workspace Helper

Usage:
  wgx <command> [args]

Commands:
  help           Diese Hilfe
  reload         Remote gewinnt: git fetch + reset --hard origin/\$WGX_BASE + clean -fdx
  doctor         Basis-Checks (git/remote/branch)
  version        Versionsinfo (falls vorhanden)
  sync-remote    Alias für reload
  # weitere Subcommands via cmd/*.bash

Env:
  WGX_BASE       Basis-Branch für reload (default: main)

USAGE
}

wgx_dispatch() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    help|-h|--help) wgx_usage ;;
    *)
      # plug-in Subcommands:
      local f="$WGX_DIR/cmd/${cmd}.bash"
      if [ -r "$f" ]; then
        source "$f"
        local func="cmd_${cmd//-/_}"
        if command -v "$func" >/dev/null 2>&1; then
          "$func" "$@"
        elif command -v wgx_command_main >/dev/null 2>&1; then
          wgx_command_main "$@"
          unset -f wgx_command_main
        else
          die "Subcommand-Datei ${cmd}.bash geladen, aber Funktion $func fehlt."
        fi
      else die "Unbekannter Befehl: $cmd"
      fi
      ;;
  esac
}

wgx_main() { wgx_dispatch "$@"; }
