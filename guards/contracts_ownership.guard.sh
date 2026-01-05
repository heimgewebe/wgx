#!/usr/bin/env bash

# Guard: Contracts Ownership & Marker Invariants
#
# Enforces:
# 1. metarepo identification (fleet/repos.yml existence).
# 2. Contract ownership:
#    - metarepo: Exclusive owner of contracts/** (internal truth).
#    - contracts-mirror: Explicitly forbidden to change contracts/**. Other changes are implicitly allowed.
#    - others: FORBIDDEN to change contracts/**.

set -euo pipefail

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}INFO:${NC} $*" >&2; }
warn() { echo -e "${YELLOW}WARN:${NC} $*" >&2; }
die() {
  echo -e "${RED}FAIL:${NC} $*" >&2
  exit 1
}
ok() { echo -e "${GREEN}OK:${NC} $*" >&2; }

# --- 1. Identify Repo ---

REPO_NAME=""

# Strategy 1: Test Override / Explicit Env (highest priority for tests)
if [[ -n "${HG_REPO_NAME:-}" ]]; then
  REPO_NAME="$HG_REPO_NAME"
  info "Detected repository via HG_REPO_NAME: ${REPO_NAME}"
fi

# Strategy 2: CI Environment (GitHub Actions)
if [[ -z "$REPO_NAME" ]] && [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  # Format: owner/repo
  REPO_NAME="${GITHUB_REPOSITORY##*/}"
  info "Detected repository via GITHUB_REPOSITORY: ${REPO_NAME}"
fi

# Strategy 3: Remote origin URL
if [[ -z "$REPO_NAME" ]]; then
  if git remote get-url origin >/dev/null 2>&1; then
    REPO_NAME=$(basename "$(git remote get-url origin)" .git)
  fi
fi

# Strategy 4: Root directory name
if [[ -z "$REPO_NAME" ]]; then
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
  fi
fi

if [[ -z "$REPO_NAME" ]]; then
  info "Could not determine repo name. Assuming 'unknown'."
  REPO_NAME="unknown"
fi

info "Final repository identity: ${REPO_NAME}"

# --- 2. Determine Changed Files ---

CHANGED_FILES=()

# CI or Local Diff Strategy
if [[ -n "${CI:-}" ]]; then
  # Strategy A: GitHub Actions PR
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    TARGET_REF="origin/$GITHUB_BASE_REF"
    info "CI: PR detected. Diffing against $TARGET_REF..."

    # Try to fetch if missing (shallow clones)
    if ! git rev-parse --verify "$TARGET_REF" >/dev/null 2>&1; then
      info "Fetching $TARGET_REF..."
      if ! git fetch origin "$GITHUB_BASE_REF" --depth=1 >/dev/null 2>&1; then
        warn "Failed to fetch $TARGET_REF. Diff comparison might be inaccurate."
      fi
    fi

    if git rev-parse --verify "$TARGET_REF" >/dev/null 2>&1; then
      # Triple-dot diff finding the merge base automatically
      while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only "$TARGET_REF"...HEAD)
    else
      # Fallback: HEAD~1
      warn "Target ref $TARGET_REF not found. Falling back to HEAD~1."
      while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only HEAD~1 HEAD 2>/dev/null)
    fi
  else
    # Strategy B: CI but not a PR (e.g. push to main)
    # Check if we have a range from environment
    # Note: GITHUB_EVENT_BEFORE is not standard, but if provided, we use it.
    BEFORE_SHA="${GITHUB_EVENT_BEFORE:-}"

    if [[ -n "$BEFORE_SHA" ]] && [[ "$BEFORE_SHA" != "0000000000000000000000000000000000000000" ]]; then
      info "CI: Push detected (before: $BEFORE_SHA). Diffing $BEFORE_SHA...HEAD"

      # Fetch if needed
      if ! git cat-file -t "$BEFORE_SHA" >/dev/null 2>&1; then
        info "Fetching $BEFORE_SHA..."
        if ! git fetch origin "$BEFORE_SHA" --depth=1 >/dev/null 2>&1; then
          warn "Failed to fetch $BEFORE_SHA. Diff comparison might be inaccurate."
        fi
      fi

      if git cat-file -t "$BEFORE_SHA" >/dev/null 2>&1; then
        while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only "$BEFORE_SHA" HEAD)
      else
        warn "Previous commit $BEFORE_SHA not available. Falling back to HEAD~1."
        while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only HEAD~1 HEAD 2>/dev/null)
      fi
    else
      info "CI: No GITHUB_BASE_REF or GITHUB_EVENT_BEFORE. Diffing HEAD~1..."
      while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only HEAD~1 HEAD 2>/dev/null)
    fi
  fi
else
  # Strategy C: Local Development
  # Staged + Unstaged
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only --cached)
    while IFS= read -r file; do [[ -n "$file" ]] && CHANGED_FILES+=("$file"); done < <(git diff --name-only)
  fi
fi

# Remove duplicates
if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
  mapfile -t CHANGED_FILES < <(printf "%s\n" "${CHANGED_FILES[@]}" | sort -u)
fi

# --- 3. Rules Implementation ---

has_contract_changes=0
for f in "${CHANGED_FILES[@]}"; do
  if [[ "$f" == contracts/* ]]; then
    has_contract_changes=1
    break
  fi
done

case "$REPO_NAME" in
metarepo)
  # Rule 1: Must contain fleet/repos.yml
  if [[ ! -f "fleet/repos.yml" ]]; then
    die "Invariant violation: 'metarepo' MUST contain 'fleet/repos.yml'."
  fi

  # Rule 2: Allowed to change contracts (Implicitly OK)
  if [[ $has_contract_changes -eq 1 ]]; then
    ok "Contract changes allowed in metarepo."
  fi
  ;;

contracts-mirror)
  # Rule 1: NO changes in contracts/**
  # We only explicitly forbid contracts/**. Other paths (like json/**) are allowed by default.
  if [[ $has_contract_changes -eq 1 ]]; then
    die "Dieses Repo spiegelt externe Contracts. Interne Organismus-Contracts dürfen nur im metarepo geändert werden. Bitte Schema nach metarepo/contracts verschieben und in diesem Repo nur konsumieren bzw. spiegeln."
  fi
  ;;

*)
  # All other repos
  # Rule 1: NO changes in contracts/**
  if [[ $has_contract_changes -eq 1 ]]; then
    die "Contracts dürfen nur im metarepo geändert werden. Bitte Schema nach metarepo/contracts verschieben und in diesem Repo nur konsumieren."
  fi
  ;;
esac

ok "Contracts ownership check passed."
exit 0
