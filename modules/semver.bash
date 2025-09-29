#!/usr/bin/env bash

# shellcheck shell=bash

# Minimal SemVer helper utilities.

semver_norm() {
  local v="${1#v}"
  local major minor patch
  IFS='.' read -r major minor patch <<<"$v"
  printf '%s.%s.%s' "${major:-0}" "${minor:-0}" "${patch:-0}"
}

semver_cmp() {
  local left right
  left="$(semver_norm "$1")"
  right="$(semver_norm "$2")"
  local l1 l2 l3 r1 r2 r3
  IFS='.' read -r l1 l2 l3 <<<"$left"
  IFS='.' read -r r1 r2 r3 <<<"$right"
  if (( l1 > r1 )) || (( l1 == r1 && l2 > r2 )) || (( l1 == r1 && l2 == r2 && l3 > r3 )); then
    return 1
  elif (( l1 < r1 )) || (( l1 == r1 && l2 < r2 )) || (( l1 == r1 && l2 == r2 && l3 < r3 )); then
    return 2
  fi
  return 0
}

semver_ge() {
  semver_cmp "$1" "$2"
  local cmp=$?
  [[ $cmp -eq 0 || $cmp -eq 1 ]]
}

semver_gt() {
  semver_cmp "$1" "$2"
  [[ $? -eq 1 ]]
}

semver_le() {
  semver_cmp "$1" "$2"
  local cmp=$?
  [[ $cmp -eq 0 || $cmp -eq 2 ]]
}

semver_lt() {
  semver_cmp "$1" "$2"
  [[ $? -eq 2 ]]
}

semver_in_caret_range() {
  local have="${1#v}" range="${2#^}"
  range="$(semver_norm "$range")"
  local major minor _patch
  IFS='.' read -r major minor _patch <<<"$range"
  local lower="$range"
  local upper

  if (( major > 0 )); then
    local next_major=$(( major + 1 ))
    upper="${next_major}.0.0"
  elif (( minor > 0 )); then
    local next_minor=$(( minor + 1 ))
    upper="0.${next_minor}.0"
  else
    # For 0.0.x ranges, we set the upper bound at the next minor version (0.${next_minor}.0),
    # so only patch updates within the current minor version are allowed, and we stop before the first minor release.
    local next_minor=$(( minor + 1 ))
    upper="0.${next_minor}.0"
  fi

  semver_ge "$have" "$lower" && semver_lt "$have" "$upper"
}
