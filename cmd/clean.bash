#!/usr/bin/env bash

cmd_clean() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local oldpwd="$PWD"
  if ! cd "$base_dir" >/dev/null 2>&1; then
    die "Clean: Basisverzeichnis '$base_dir' nicht erreichbar."
  fi

  local __cmd_clean_restore_errexit=0
  case $- in
  *e*)
    __cmd_clean_restore_errexit=1
    set +e
    ;;
  esac

  local dry_run=0 safe=0 build=0 git_cleanup=0 deep=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
    --safe) safe=1 ;;
    --build) build=1 ;;
    --git) git_cleanup=1 ;;
    --deep) deep=1 ;;
    --dry-run | -n) dry_run=1 ;;
    --force | -f) force=1 ;;
    --help | -h)
      cat <<'USAGE'
Usage:
  wgx clean [--safe] [--build] [--git] [--deep] [--dry-run] [--force]

Options:
  --safe       Entfernt temporäre Cache-Verzeichnisse (Standard).
  --build      Löscht Build-Artefakte (dist, build, target, ...).
  --git        Räumt gemergte Branches und Remote-Referenzen auf (nur sauberer Git-Tree).
  --deep       Führt ein destruktives `git clean -xfd` aus (erfordert --force, nur sauberer Git-Tree).
  --dry-run    Zeigt nur an, was passieren würde.
  --force      Bestätigt destruktive Operationen (für --deep).
USAGE
      cd "$oldpwd" >/dev/null 2>&1 || true
      if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
        set -e
      fi
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      warn "Unbekannte Option: $1"
      cd "$oldpwd" >/dev/null 2>&1 || true
      if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
        set -e
      fi
      return 2
      ;;
    *)
      warn "Ignoriere unerwartetes Argument: $1"
      ;;
    esac
    shift || true
  done

  # Standard: ungefährliche Caches
  if [ $safe -eq 0 ] && [ $build -eq 0 ] && [ $git_cleanup -eq 0 ] && [ $deep -eq 0 ]; then
    safe=1
  fi

  local rc=0
  local performed=0
  local skip_cleanup=0

  # Fehler protokollieren (vor erster Nutzung definiert)
  _record_error() {
    local status=${1:-1}
    if [ "$status" -eq 0 ]; then status=1; fi
    if [ $dry_run -eq 1 ]; then
      # Im Dry-Run wird nur der finale RC-Wert beeinflusst,
      # aber kein harter Fehler ausgelöst.
      :
    else
      if [ "$rc" -eq 0 ]; then rc=$status; fi
    fi
  }

  # Für reale Läufe ggf. sauberen Git-Tree verlangen
  local require_clean_tree=0 allow_untracked_dirty=0
  if [ $dry_run -eq 0 ]; then
    [ $git_cleanup -eq 1 ] && require_clean_tree=1
    [ $deep -eq 1 ] && allow_untracked_dirty=1
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local worktree_dirty=0
    if [ $require_clean_tree -eq 1 ]; then
      if git_workdir_dirty; then worktree_dirty=1; fi
    elif [ $allow_untracked_dirty -eq 1 ]; then
      # Nur getrackte Änderungen verhindern Deep-Clean
      if git status --porcelain=v1 --untracked-files=no 2>/dev/null | grep -q .; then
        worktree_dirty=1
      fi
    fi

    if [ $worktree_dirty -eq 1 ]; then
      warn "Git-Arbeitsverzeichnis ist nicht sauber. Bitte committe oder stash deine Änderungen und versuche es erneut."
      local status_output
      status_output="$(git status --short 2>/dev/null || true)"
      if [ -n "$status_output" ]; then
        while IFS= read -r line; do
          [ -n "$line" ] || continue
          printf '    %s\n' "$line" >&2
        done <<<"$status_output"
      fi
      skip_cleanup=1
      [ $dry_run -eq 0 ] && _record_error 1
    fi
  fi

  # --- Helpers ---------------------------------------------------------------

  _remove_path() {
    local target="$1"
    [ -e "$target" ] || return 1
    performed=1
    if [ $dry_run -eq 1 ]; then
      printf 'DRY: rm -rf -- %q\n' "$target"
      return 0
    fi
    rm -rf -- "$target"
  }

  _remove_paths() {
    local desc="$1"
    shift
    local removed_any=0 local_rc=0 status=0 path
    for path in "$@"; do
      if _remove_path "$path"; then
        removed_any=1
      else
        status=$?
        if [ $status -ne 1 ] && [ $local_rc -eq 0 ]; then
          local_rc=$status
          _record_error "$status"
        fi
      fi
    done
    [ $removed_any -eq 1 ] && info "$desc entfernt."
    return "$local_rc"
  }

  # --- Hauptlogik ------------------------------------------------------------

  if [ $skip_cleanup -eq 1 ]; then
    [ $dry_run -eq 1 ] && info "Dry-Run: Bereinigung aufgrund verschmutztem Git-Arbeitsverzeichnis übersprungen."
  else
    # --safe: ungefährliche Caches
    if [ $safe -eq 1 ]; then
      if _remove_paths "Temporäre Caches" \
        .pytest_cache .ruff_cache .mypy_cache .coverage coverage \
        .hypothesis .cache; then :; else
        local status=$?
        if [ $status -ne 0 ]; then
          [ $rc -eq 0 ] && rc=$status
          _record_error "$status"
        fi
      fi

      # alte wgx-Logs im TMP
      if [ $dry_run -eq 1 ]; then
        printf 'DRY: find "%s" -maxdepth 1 -type f -name %q -mtime +1 -delete\n' "${TMPDIR:-/tmp}" 'wgx-*.log'
      else
        find "${TMPDIR:-/tmp}" -maxdepth 1 -type f -name 'wgx-*.log' -mtime +1 -exec rm -f -- {} + 2>/dev/null || true
      fi
    fi

    # --git: gemergte Branches + prune origin
    if [ $git_cleanup -eq 1 ]; then
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local git_performed=0
        local current_branch
        current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
        local branch
        while IFS= read -r branch; do
          [ -n "$branch" ] || continue
          case "$branch" in "$current_branch" | main | master | dev) continue ;; esac
          git_performed=1
          if [ $dry_run -eq 1 ]; then
            printf 'DRY: git branch -d -- %q\n' "$branch"
          else
            git branch -d "$branch" >/dev/null 2>&1 || true
          fi
        done < <(git for-each-ref --format='%(refname:short)' --merged 2>/dev/null)

        if git remote | grep -qx 'origin'; then
          git_performed=1
          if [ $dry_run -eq 1 ]; then
            echo 'DRY: git remote prune origin'
          else
            git remote prune origin >/dev/null 2>&1 || true
          fi
        fi

        [ $git_performed -eq 1 ] && performed=1
      else
        if [ $dry_run -eq 1 ]; then
          info "--git übersprungen (kein Git-Repository, Dry-Run)."
        else
          warn "--git verlangt ein Git-Repository."
          _record_error 1
        fi
      fi
    fi

    # --build: Build-/Tool-Artefakte
    if [ $build -eq 1 ]; then
      if _remove_paths "Build-Artefakte" \
        build dist target .tox .nox .venv .uv .pdm-build node_modules/.cache; then :; else
        local status=$?
        if [ $status -ne 0 ]; then
          [ $rc -eq 0 ] && rc=$status
          _record_error "$status"
        fi
      fi

      if [ $dry_run -eq 1 ]; then
        printf 'DRY: find . -maxdepth 1 -type d -name %q -exec rm -rf -- {} +\n' '*.egg-info'
      else
        find . -maxdepth 1 -type d -name '*.egg-info' -exec rm -rf -- {} + 2>/dev/null || true
      fi
    fi

    # --deep: destruktiver Git-Clean
    if [ $deep -eq 1 ]; then
      if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [ $dry_run -eq 1 ]; then
          git clean -nfxd || true # Simulation, Dry-Run bleibt grün
        else
          if [ $force -eq 0 ]; then
            warn "--deep ist destruktiv und benötigt --force."
            _record_error 1
          else
            if ! git clean -xfd; then
              local clean_status=$?
              rc=$clean_status
              _record_error "$clean_status"
            fi
          fi
        fi
        performed=1
      else
        if [ $dry_run -eq 1 ]; then
          info "--deep übersprungen (kein Git-Repository, Dry-Run)."
        else
          warn "--deep verlangt ein Git-Repository."
          _record_error 1
        fi
      fi
    fi
  fi

  cd "$oldpwd" >/dev/null 2>&1 || true

  if [ $dry_run -eq 1 ]; then
    # Dry-Run: nie als Fehler enden (Tests erwarten Exit 0)
    info "Clean (Dry-Run) abgeschlossen."
    if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
      set -e
    fi
    return 0
  fi

  if [ "$rc" -eq 0 ]; then
    if [ $performed -eq 0 ]; then
      info "Nichts zu tun."
    else
      ok "Clean abgeschlossen."
    fi
  fi
  if [ "$__cmd_clean_restore_errexit" -eq 1 ]; then
    set -e
  fi
  return "$rc"
}

clean_cmd() {
  cmd_clean "$@"
}

wgx_command_main() {
  cmd_clean "$@"
}
