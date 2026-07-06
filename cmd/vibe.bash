#!/usr/bin/env bash

_vibe_usage() {
  cat <<'USAGE'
Usage:
  wgx vibe [options] <idea...>
  wgx vibe status
  wgx vibe doctor [--repo PATH]
  wgx vibe adopt --repo PATH [--branch NAME] [--worktree PATH] [--name NAME] <idea...>

Description:
  Builds and manages non-destructive Vibe lane receipts. The first lifecycle
  slice is intentionally conservative: plan/status/doctor are read-only, and
  adopt writes only a local receipt.

Options:
  --repo PATH    Source repository. Default: current git repository.
  --root PATH    Worktree root. Default: $WGX_VIBE_ROOT or ~/repos/.vibe-lab-worktrees.
  --name NAME    Stable slug override.
  -h, --help     Show this help.
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

_vibe_state_root() {
  printf '%s' "${WGX_VIBE_STATE_ROOT:-$HOME/.local/state/wgx/vibes}"
}

_vibe_repo_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

_vibe_json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

_vibe_write_receipt() {
  local path="$1" id="$2" state="$3" repo="$4" branch="$5" worktree="$6" idea="$7" stamp="$8"
  local idj statej repoj branchj worktreej ideaj stampj
  idj="$(printf '%s' "$id" | _vibe_json_escape)"
  statej="$(printf '%s' "$state" | _vibe_json_escape)"
  repoj="$(printf '%s' "$repo" | _vibe_json_escape)"
  branchj="$(printf '%s' "$branch" | _vibe_json_escape)"
  worktreej="$(printf '%s' "$worktree" | _vibe_json_escape)"
  ideaj="$(printf '%s' "$idea" | _vibe_json_escape)"
  stampj="$(printf '%s' "$stamp" | _vibe_json_escape)"

  cat >"$path" <<JSON
{
  "schema_version": 1,
  "id": ${idj},
  "state": ${statej},
  "created_at": ${stampj},
  "updated_at": ${stampj},
  "idea": ${ideaj},
  "repo": ${repoj},
  "branch": ${branchj},
  "worktree": ${worktreej},
  "exit_policy": {
    "abort_requires_clean": true,
    "close_requires_merged_or_explicit_reason": true
  },
  "does_not_establish": [
    "pull request opened",
    "merge approved",
    "worktree cleanup performed",
    "Bureau task created",
    "Chronik event delivered"
  ]
}
JSON
}

_vibe_plan() {
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
  repo_root="$(_vibe_repo_root "$repo")" || _vibe_die "--repo ist kein Git-Repo: $repo" || return 1
  repo_name="$(basename "$repo_root")"
  slug="${name:-$(_vibe_slug "$idea")}"
  slug="$(_vibe_slug "$slug")"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  vibe_id="vibe-${stamp}-${slug}"
  branch="vibe/${stamp}-${slug}"
  worktree="${root%/}/${repo_name}-${stamp}-${slug}"
  receipt="$(_vibe_state_root)/${vibe_id}.json"

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

_vibe_status() {
  local root
  root="$(_vibe_state_root)"
  if [ ! -d "$root" ]; then
    echo "VIBE_STATUS=empty"
    echo "state_root=${root}"
    return 0
  fi

  local count
  count="$(find "$root" -maxdepth 1 -type f -name 'vibe-*.json' | wc -l | tr -d ' ')"
  echo "VIBE_STATUS=ok"
  echo "state_root=${root}"
  echo "receipt_count=${count}"
  find "$root" -maxdepth 1 -type f -name 'vibe-*.json' -printf '%f\n' | sort
}

_vibe_doctor() {
  local repo="." root receipt_count missing_worktree=0
  while (($#)); do
    case "$1" in
    --repo)
      [ $# -ge 2 ] || _vibe_die "--repo braucht einen Pfad" || return 1
      repo="$2"
      shift 2
      ;;
    -h | --help)
      echo "Usage: wgx vibe doctor [--repo PATH]"
      return 0
      ;;
    *)
      _vibe_die "Unbekannte Option: $1" || return 1
      ;;
    esac
  done

  local repo_root current_branch
  repo_root="$(_vibe_repo_root "$repo")" || _vibe_die "--repo ist kein Git-Repo: $repo" || return 1
  current_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
  root="$(_vibe_state_root)"
  receipt_count=0

  echo "VIBE_DOCTOR=ok"
  echo "repo=${repo_root}"
  echo "current_branch=${current_branch:-DETACHED}"
  echo "state_root=${root}"

  if [ -d "$root" ]; then
    receipt_count="$(find "$root" -maxdepth 1 -type f -name 'vibe-*.json' | wc -l | tr -d ' ')"
    while IFS= read -r receipt; do
      [ -n "$receipt" ] || continue
      worktree="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("worktree",""))' "$receipt")"
      if [ -n "$worktree" ] && [ ! -d "$worktree" ]; then
        missing_worktree=$((missing_worktree + 1))
        echo "missing_worktree_receipt=$(basename "$receipt")"
      fi
    done < <(find "$root" -maxdepth 1 -type f -name 'vibe-*.json' | sort)
  fi

  echo "receipt_count=${receipt_count}"
  echo "missing_worktree_count=${missing_worktree}"
  echo "note=doctor is read-only; no cleanup performed"
}

_vibe_adopt() {
  local repo="." branch="" worktree="" name="" idea=""
  while (($#)); do
    case "$1" in
    --repo)
      [ $# -ge 2 ] || _vibe_die "--repo braucht einen Pfad" || return 1
      repo="$2"
      shift 2
      ;;
    --branch)
      [ $# -ge 2 ] || _vibe_die "--branch braucht einen Namen" || return 1
      branch="$2"
      shift 2
      ;;
    --worktree)
      [ $# -ge 2 ] || _vibe_die "--worktree braucht einen Pfad" || return 1
      worktree="$2"
      shift 2
      ;;
    --name)
      [ $# -ge 2 ] || _vibe_die "--name braucht einen Wert" || return 1
      name="$2"
      shift 2
      ;;
    -h | --help)
      echo "Usage: wgx vibe adopt --repo PATH [--branch NAME] [--worktree PATH] [--name NAME] <idea...>"
      return 0
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
  has python3 || _vibe_die "python3 nicht installiert" || return 1

  local repo_root slug stamp id receipt root
  repo_root="$(_vibe_repo_root "$repo")" || _vibe_die "--repo ist kein Git-Repo: $repo" || return 1
  branch="${branch:-$(git -C "$repo_root" branch --show-current 2>/dev/null || true)}"
  [ -n "$branch" ] || _vibe_die "Detached HEAD kann nur mit --branch adoptiert werden" || return 1
  worktree="${worktree:-$repo_root}"

  [ -d "$worktree" ] || _vibe_die "Worktree existiert nicht: $worktree" || return 1
  slug="${name:-$(_vibe_slug "$branch")}"
  slug="$(_vibe_slug "$slug")"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  id="vibe-${stamp}-${slug}"
  root="$(_vibe_state_root)"
  receipt="${root}/${id}.json"

  mkdir -p "$root"
  [ ! -e "$receipt" ] || _vibe_die "Receipt existiert bereits: $receipt" || return 1

  _vibe_write_receipt "$receipt" "$id" "adopted" "$repo_root" "$branch" "$worktree" "$idea" "$stamp"

  cat <<ADOPTED
VIBE_ADOPTED=1
id=${id}
repo=${repo_root}
branch=${branch}
worktree=${worktree}
receipt=${receipt}
ADOPTED
}

cmd_vibe() {
  if (($# == 0)); then
    _vibe_usage
    return 0
  fi

  case "${1:-}" in
  -h | --help)
    _vibe_usage
    ;;
  status)
    shift
    _vibe_status "$@"
    ;;
  doctor)
    shift
    _vibe_doctor "$@"
    ;;
  adopt)
    shift
    _vibe_adopt "$@"
    ;;
  plan | start)
    shift
    _vibe_plan "$@"
    ;;
  *)
    _vibe_plan "$@"
    ;;
  esac
}
