#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: run-with-files.sh [--per-file] <empty-message> <command> [args...]

Reads file paths (one per line) from standard input, filters out empty entries,
and executes the provided command with the resulting list of files.

Without --per-file the command is run once with all files as arguments. When
--per-file is supplied the command is invoked separately for each file.
USAGE
}

per_file=false
if [[ ${1:-} == "--per-file" ]]; then
  per_file=true
  shift
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

empty_message="$1"
shift

mapfile -t raw_files < /dev/stdin

files=()
for file in "${raw_files[@]}"; do
  # Normalize potential CRLF endings to gracefully handle Windows-edited files.
  file="${file%$'\r'}"
  [[ -z "$file" ]] && continue
  files+=("$file")
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "$empty_message"
  exit 0
fi

if [[ "$per_file" == true ]]; then
  printf '%s\0' "${files[@]}" | xargs -0 -r -n1 -- "$@"
else
  printf '%s\0' "${files[@]}" | xargs -0 -r -- "$@"
fi
