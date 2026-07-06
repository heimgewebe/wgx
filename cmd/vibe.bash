#!/usr/bin/env bash

_vibe_usage() {
  cat <<'USAGE'
Usage:
  wgx vibe [options] <idea...>

Description:
  Builds a deterministic Vibe lane plan for one idea: id, branch name,
  proposed ephemeral worktree path, and local receipt path. This first MVP is
  intentionally plan-first: it creates no branch, no worktree, no PR, and no
  external task. It turns vague intent into a bounded lifecycle contract.

Options:
  --repo PATH    Source repository. Default: current git repository.
  --root PATH    Worktree root. Default: $WGX_VIBE_ROOT or ~/repos/.vibe-lab-worktrees.
  --name NAME    Stable slug override.
  -h, --help     Show this help.

Example:
  wgx vibe --repo ~/repos/chronik "add event healthcheck"
USAGE
}

_vibe_slug() {
  local input="$*" slug
  slug="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  slug="${slug:0:48}"
  [ -n "$slug" ] || slug="idea"
  printf '%s' "$slug"
}

_vibe_die() {
  printf '❌ %s\n' "$*" >&2
  return 1
}

cmd_vibe() {
  local repo="." root="${WGX_VIBE_ROOT:-$HOME/repos/.vibe-lab-worktrees}" name="" idea=""

  while (($#)); do
    case "$1" in
    -h | --help)
      _vibe_usage
      return 0
      ;;
    --repo)
      [ $# -ge 2 ] || _vibe_die "--repo braucht einen Pfad" || return 1
      repo="$2"
      shift 2
      ;;
    --root)
      [ $# -ge 2 ] || _vibe_die "--root braucht einen Pfad" || return 1
      root="$2"
      shift 2
      ;;
    --name)
      [ $# -ge 2 ] || _vibe_die "--name braucht einen Wert" || return 1
      name="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      _vibe_die "Unbekannte Option: $1" || return 1
      ;;
    *)
      break
      ;;
    esac
  done

  idea="$*"
  [ -n "$(printf '%s' "$idea" | tr -d '[:space:]')" ] || _vibe_die "Idee fehlt" || return 1
  has git || _vibe_die "git nicht installiert" || return 1

  local repo_root repo_name slug stamp vibe_id branch worktree receipt
  repo_root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || _vibe_die "--repo ist kein Git-Repo: $repo" || return 1
  repo_name="$(basename "$repo_root")"
  slug="${name:-$(_vibe_slug "$idea")}" 
  slug="$(_vibe_slug "$slug")"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  vibe_id="vibe-${stamp}-${slug}"
  branch="vibe/${stamp}-${slug}"
  worktree="${root%/}/${repo_name}-${stamp}-${slug}"
  receipt="${WGX_VIBE_STATE_ROOT:-$HOME/.local/state/wgx/vibes}/${vibe_id}.json"

  cat <<PLAN
VIBE_PLAN=1
id=${vibe_id}
repo=${repo_root}
branch=${branch}
worktree=${worktree}
receipt=${receipt}
idea=${idea}
PLAN
}
