#!/usr/bin/env bash

cmd_clean() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local oldpwd="$PWD"
  if ! cd "$base_dir" >/dev/null 2>&1; then
    die "Clean: Basisverzeichnis '$base_dir' nicht erreichbar."
  fi

  local dry_run=0 safe=0 build=0 git_cleanup=0 deep=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
    --safe)
      safe=1
      ;;
    --build)
      build=1
      ;;
    --git)
      git_cleanup=1
      ;;
    --deep)
      deep=1
      ;;
    --dry-run | -n)
      dry_run=1
      ;;
    --force | -f)
      force=1
      ;;
    --help | -h)
      cat <<'USAGE'
Usage:
  wgx clean [--safe] [--build] [--git] [--deep] [--dry-run] [--force]

Options:
  --safe       Entfernt temporäre Cache-Verzeichnisse (Standard).
  --build      Löscht Build-Artefakte (dist, build, target, ...).
  --git        Räumt gemergte Branches und Remote-Referenzen auf.
  --deep       Führt ein destruktives `git clean -xfd` aus (erfordert --force).
  --dry-run    Zeigt nur an, was passieren würde.
  --force      Bestätigt destruktive Operationen (für --deep).
USAGE
      cd "$oldpwd" >/dev/null 2>&1 || true
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      warn "Unbekannte Option: $1"
      cd "$oldpwd" >/dev/null 2>&1 || true
      return 2
      ;;
    *)
      warn "Ignoriere unerwartetes Argument: $1"
      ;;
    esac
    shift || true
  done

  if [ $safe -eq 0 ] && [ $build -eq 0 ] && [ $git_cleanup -eq 0 ] && [ $deep -eq 0 ]; then
    safe=1
  fi

  local rc=0
  local performed=0

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
    local removed_any=0 path
    for path in "$@"; do
      if _remove_path "$path"; then
        removed_any=1
      fi
    done
    if [ $removed_any -eq 1 ]; then
      info "$desc entfernt."
    fi
  }

  if [ $safe -eq 1 ]; then
    _remove_paths "Temporäre Caches" \
      .pytest_cache \
      .ruff_cache \
      .mypy_cache \
      .coverage \
      coverage \
      .hypothesis \
      .cache

    if [ -d "${TMPDIR:-/tmp}" ]; then
      if [ $dry_run -eq 1 ]; then
        printf 'DRY: find "%s" -maxdepth 1 -type f -name %q -mtime +1 -delete\n' "${TMPDIR:-/tmp}" 'wgx-*.log'
      else
        find "${TMPDIR:-/tmp}" -maxdepth 1 -type f -name 'wgx-*.log' -mtime +1 -exec rm -f -- {} + 2>/dev/null || true
      fi
    fi
  fi

  if [ $build -eq 1 ]; then
    _remove_paths "Build-Artefakte" \
      build \
      dist \
      target \
      .tox \
      .nox \
      .venv \
      .uv \
      .pdm-build \
      node_modules/.cache

    if [ $dry_run -eq 1 ]; then
      printf 'DRY: find . -maxdepth 1 -type d -name %q -exec rm -rf -- {} +\n' '*.egg-info'
    else
      find . -maxdepth 1 -type d -name '*.egg-info' -exec rm -rf -- {} + 2>/dev/null || true
    fi
  fi

  if [ $git_cleanup -eq 1 ]; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local current_branch
      current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
      local branch
      while IFS= read -r branch; do
        [ -n "$branch" ] || continue
        case "$branch" in
        "$current_branch"|main|master|dev)
          continue
          ;;
        esac
        performed=1
        if [ $dry_run -eq 1 ]; then
          printf 'DRY: git branch -d -- %q\n' "$branch"
        else
          git branch -d "$branch" >/dev/null 2>&1 || true
        fi
      done < <(git for-each-ref --format='%(refname:short)' --merged 2>/dev/null)

      if git remote | grep -qx 'origin'; then
        performed=1
        if [ $dry_run -eq 1 ]; then
          echo 'DRY: git remote prune origin'
        else
          git remote prune origin >/dev/null 2>&1 || true
        fi
      fi
    else
      warn "--git verlangt ein Git-Repository."
      rc=1
    fi
  fi

  if [ $deep -eq 1 ]; then
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if [ $dry_run -eq 1 ]; then
        git clean -nfxd || rc=$?
      else
        if [ $force -eq 0 ]; then
          warn "--deep ist destruktiv und benötigt --force."
          rc=1
        else
          git clean -xfd || rc=$?
        fi
      fi
      performed=1
    else
      warn "--deep verlangt ein Git-Repository."
      rc=1
    fi
  fi

  cd "$oldpwd" >/dev/null 2>&1 || true

  if [ $rc -eq 0 ]; then
    if [ $dry_run -eq 1 ]; then
      ok "Clean (Dry-Run) abgeschlossen."
    else
      if [ $performed -eq 0 ]; then
        info "Nichts zu tun."
      else
        ok "Clean abgeschlossen."
      fi
    fi
  fi

  return $rc
}

clean_cmd() {
  cmd_clean "$@"
}

wgx_command_main() {
  cmd_clean "$@"
}
