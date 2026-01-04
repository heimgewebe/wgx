#!/usr/bin/env bash

# Guard: Contracts Ownership & Marker Invariants
#
# Enforces:
# 1. metarepo identification (fleet/repos.yml existence).
# 2. Contract ownership:
#    - metarepo: Exclusive owner of contracts/** (internal truth).
#    - contracts-mirror: Allowed to change json/** etc., but NOT contracts/**.
#    - others: FORBIDDEN to change contracts/**.

set -euo pipefail

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}INFO:${NC} $*" >&2; }
die() {
  echo -e "${RED}FAIL:${NC} $*" >&2
  exit 1
}
ok() { echo -e "${GREEN}OK:${NC} $*" >&2; }

# --- 1. Identify Repo ---

REPO_NAME=""

# Strategy 1: CI Environment (GitHub Actions)
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  # Format: owner/repo
  REPO_NAME="${GITHUB_REPOSITORY##*/}"
  info "Detected repository via GITHUB_REPOSITORY: ${REPO_NAME}"
fi

# Strategy 2: Test Override / Explicit Env
if [[ -z "$REPO_NAME" ]] && [[ -n "${HG_REPO_NAME:-}" ]]; then
  REPO_NAME="$HG_REPO_NAME"
  info "Detected repository via HG_REPO_NAME: ${REPO_NAME}"
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
       git fetch origin "$GITHUB_BASE_REF" --depth=1 >/dev/null 2>&1 || true
    fi

    if git rev-parse --verify "$TARGET_REF" >/dev/null 2>&1; then
       # Triple-dot diff finding the merge base automatically
       while IFS= read -r file; do CHANGED_FILES+=("$file"); done < <(git diff --name-only "$TARGET_REF"...HEAD)
    else
       # Fallback: HEAD~1
       info "Target ref $TARGET_REF not found. Falling back to HEAD~1."
       while IFS= read -r file; do CHANGED_FILES+=("$file"); done < <(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
    fi
  else
    # Strategy B: CI but not a PR (e.g. push to main) or unknown CI
    # Attempt to diff against previous commit
    info "CI: No GITHUB_BASE_REF. Diffing HEAD~1..."
    while IFS= read -r file; do CHANGED_FILES+=("$file"); done < <(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
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
  sorted_unique_files=$(printf "%s\n" "${CHANGED_FILES[@]}" | sort -u)
  mapfile -t CHANGED_FILES <<<"$sorted_unique_files"
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
  if [[ $has_contract_changes -eq 1 ]]; then
    die "Dieses Repo spiegelt externe Contracts; interne Organismus-Contracts gehören ins metarepo."
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
