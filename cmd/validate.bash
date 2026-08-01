#!/usr/bin/env bash
#
# wgx validate — prüft das .wgx/profile.* Manifest und führt deklarierte
# Validierungsprofile über repository-eigene Kommandos aus.
#

WGX_VALIDATE_DEFAULT_TIMEOUT_QUICK=120
WGX_VALIDATE_DEFAULT_TIMEOUT_FULL=900

validate::_usage() {
  cat <<'USAGE'
Usage:
  wgx validate [--json]
  wgx validate --profile quick|full [--json] [--timeout SECONDS] [--dry-run] [--output PATH]

Validiert das Manifest (.wgx/profile.*) im aktuellen Repository. Mit --profile
werden zusätzlich die im Manifest deklarierten repository-eigenen Checks des
Profils ausgeführt und ein stabiles JSON-Receipt erzeugt.

Profile werden im Manifest deklariert; wgx erfindet keine Checks:

  wgx:
    validate:
      quick: [lint, guard]
      full:  [lint, guard, test]
      unsupported:
        bench: "kein Benchmark-Harness"
      ciOnly:
        integration: "braucht Cloud-Credentials"

Optionen:
  --profile NAME   quick (begrenztes Agenten-Feedback) oder full (merge-taugliche
                   lokale Validierung)
  --json           Maschinenlesbare Ausgabe. Ohne --profile:
                   {"ok":bool,"errors":[...],"missingCapabilities":[...]}
                   Mit --profile: das vollständige Receipt.
  --timeout SEC    Zeitlimit je Check (Standard: quick 120, full 900)
  --dry-run        Nur die aufgelöste Check-Reihenfolge zeigen, nichts ausführen
  --output PATH    Receipt zusätzlich in eine Datei schreiben
  -h, --help       Diese Hilfe

Exit-Status: 0 wenn Manifest gültig ist und alle Checks bestehen, sonst >0.
USAGE
}

validate::_module_dir() {
  local dir="${WGX_DIR:-}"
  if [[ -n $dir && -d "$dir/modules" ]]; then
    printf '%s' "$dir/modules"
    return 0
  fi
  cd "$(dirname "${BASH_SOURCE[0]}")/../modules" && pwd
}

validate::_repo_root() {
  local root="${WGX_TARGET_ROOT:-$PWD}"
  if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$root" rev-parse --show-toplevel
  else
    printf '%s' "$root"
  fi
}

validate::_commit() {
  git -C "$1" rev-parse HEAD 2>/dev/null || printf ''
}

validate::_dirty() {
  if ! git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'false'
    return 0
  fi
  if [[ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

validate::_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

validate::_epoch_ms() {
  local raw
  raw="$(date +%s%N 2>/dev/null || printf '')"
  if [[ $raw =~ ^[0-9]+$ ]] && ((${#raw} > 10)); then
    printf '%s' $((raw / 1000000))
  else
    printf '%s' $(($(date +%s) * 1000))
  fi
}

# Append one NUL-separated 6-field record for the receipt builder.
validate::_record() {
  local file="$1"
  shift
  local field
  for field in "$@"; do
    printf '%s\0' "$field" >>"$file"
  done
}

# Resolve the declared checks of a profile into ordered run/skip decisions.
# Prints "run<TAB>name" or "skip<TAB>name<TAB>kind<TAB>reason" per line, so the
# discovery order is deterministic and inspectable without executing anything.
validate::_resolve() {
  local profile="$1"
  local name skip kind reason spec
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    skip="$(profile::validate_skip_reason "$name")"
    if [[ -n $skip ]]; then
      kind="${skip%%:*}"
      reason="${skip#*:}"
      printf 'skip\t%s\t%s\t%s\n' "$name" "$kind" "$reason"
      continue
    fi
    spec="$(profile::_task_spec "$name")"
    if [[ -z $spec ]]; then
      printf 'skip\t%s\t%s\t%s\n' "$name" "undeclared" "profile lists a task the manifest does not define"
      continue
    fi
    printf 'run\t%s\n' "$name"
  done < <(profile::validate_profile_checks "$profile")
}

validate::_run_check() {
  # Run one declared task under a wall-clock timeout, in this shell so the
  # profile API stays available. Echoes "<status> <exit> <duration_ms>".
  local name="$1" timeout_seconds="$2"
  local started ended status exit_code=0 pid watchdog flag

  # A watchdog rather than a poll loop, so a fast check reports its real
  # duration instead of the polling interval. The flag file distinguishes a
  # timeout kill from a task that legitimately exits with a signal status.
  flag="$(mktemp "${TMPDIR:-/tmp}/wgx-validate-timeout.XXXXXX")"
  rm -f "$flag"

  # Both background jobs must release the caller's stdio and fd 3: this runs
  # inside a command substitution (and under bats), which blocks until every
  # process holding those descriptors exits.
  #
  # The watchdog polls so it terminates as soon as the task does, leaving no
  # lingering sleep behind. The measured duration stays exact because the main
  # shell waits on the task itself rather than on the poll interval.
  started="$(validate::_epoch_ms)"
  (profile::run_task "$name") >/dev/null 2>&1 3>&- &
  pid=$!
  (
    local elapsed=0
    local limit=$((timeout_seconds * 10))
    while kill -0 "$pid" 2>/dev/null; do
      if ((elapsed >= limit)); then
        : >"$flag"
        kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
        break
      fi
      sleep 0.1
      elapsed=$((elapsed + 1))
    done
  ) >/dev/null 2>&1 3>&- &
  watchdog=$!
  wait "$pid" 2>/dev/null || exit_code=$?
  ended="$(validate::_epoch_ms)"
  wait "$watchdog" 2>/dev/null || true

  if [[ -e $flag ]]; then
    status="timeout"
    ((exit_code)) || exit_code=124
  elif ((exit_code == 0)); then
    status="passed"
  else
    status="failed"
  fi
  rm -f "$flag"
  printf '%s %s %s' "$status" "$exit_code" "$((ended - started))"
}

validate::_profile_run() {
  local profile="$1" json="$2" timeout_seconds="$3" dry_run="$4" output="$5"

  if ! profile::validate_profile_declared "$profile"; then
    if ((json)); then
      printf '{"ok":false,"errors":["validate_profile_not_declared:%s"],"missingCapabilities":[]}\n' "$profile"
    else
      warn "Profil '$profile' ist im Manifest nicht deklariert (wgx.validate.${profile})."
      printf 'Deklariere die auszuführenden repository-eigenen Tasks unter wgx.validate.%s.\n' "$profile" >&2
    fi
    return 2
  fi

  local -a _errors=() _missing=()
  local manifest_ok="true"
  profile::validate_manifest _errors _missing || true
  ((${#_errors[@]} == 0)) || manifest_ok="false"

  local -a plan=()
  mapfile -t plan < <(validate::_resolve "$profile")

  if ((dry_run)); then
    local line kind name
    for line in "${plan[@]}"; do
      IFS=$'\t' read -r kind name _ _ <<<"$line"
      printf '%s\t%s\n' "$kind" "$name"
    done
    return 0
  fi

  local records
  records="$(mktemp "${TMPDIR:-/tmp}/wgx-validate-records.XXXXXX")"
  local started_at
  started_at="$(validate::_now)"

  local line kind name skip_kind reason result_line status exit_code duration
  local failures=0
  for line in "${plan[@]}"; do
    IFS=$'\t' read -r kind name skip_kind reason <<<"$line"
    case "$kind" in
    skip)
      validate::_record "$records" "skip" "$name" "$skip_kind" "$reason" "" ""
      if [[ $skip_kind == "undeclared" ]]; then
        failures=$((failures + 1))
      fi
      ;;
    run)
      ((json)) || printf '→ %s\n' "$name" >&2
      result_line="$(validate::_run_check "$name" "$timeout_seconds")"
      read -r status exit_code duration <<<"$result_line"
      validate::_record "$records" "check" "$name" "$status" "$exit_code" "$duration" \
        "$(profile::_task_spec "$name")"
      [[ $status == "passed" ]] || failures=$((failures + 1))
      ((json)) || printf '  %s (%s ms)\n' "$status" "$duration" >&2
      ;;
    esac
  done

  local finished_at repo_root repo_name commit dirty receipt module_dir
  finished_at="$(validate::_now)"
  repo_root="$(validate::_repo_root)"
  repo_name="$(basename "$repo_root")"
  commit="$(validate::_commit "$repo_root")"
  dirty="$(validate::_dirty "$repo_root")"
  module_dir="$(validate::_module_dir)"

  local errors_joined="" missing_joined=""
  ((${#_errors[@]})) && errors_joined="$(printf '%s\n' "${_errors[@]}")"
  ((${#_missing[@]})) && missing_joined="$(printf '%s\n' "${_missing[@]}")"

  local receipt_status=0
  receipt="$(WGX_BASH_VERSION="${BASH_VERSION:-unknown}" python3 "${module_dir}/validate_receipt.py" \
    "$profile" "$repo_root" "$repo_name" "$commit" "$dirty" \
    "$started_at" "$finished_at" "$manifest_ok" "$errors_joined" "$missing_joined" \
    "$timeout_seconds" "$records")" || receipt_status=$?
  rm -f "$records"

  if ((receipt_status > 1)); then
    warn "Receipt konnte nicht erzeugt werden."
    return 3
  fi

  if [[ -n $output ]]; then
    printf '%s\n' "$receipt" >"$output"
  fi

  if ((json)); then
    printf '%s\n' "$receipt"
  else
    if ((receipt_status == 0)); then
      ok "Profil '$profile' bestanden."
    else
      warn "Profil '$profile' fehlgeschlagen."
    fi
    [[ -n $output ]] && printf 'Receipt: %s\n' "$output"
  fi

  # The receipt builder is the single source of the pass/fail verdict; the local
  # failure counter only mirrors it for readable progress output.
  if ((receipt_status == 0)) && ((failures > 0)); then
    warn "Receipt meldet bestanden, obwohl $failures Check(s) fehlschlugen."
    return 3
  fi
  return $receipt_status
}

cmd_validate() {
  local json=0 help=0 dry_run=0 ok_bool
  local profile="" timeout_seconds="" output=""

  while [ $# -gt 0 ]; do
    case "$1" in
    --json) json=1 ;;
    --dry-run) dry_run=1 ;;
    --profile)
      shift || true
      profile="${1:-}"
      ;;
    --profile=*) profile="${1#--profile=}" ;;
    --timeout)
      shift || true
      timeout_seconds="${1:-}"
      ;;
    --timeout=*) timeout_seconds="${1#--timeout=}" ;;
    --output)
      shift || true
      output="${1:-}"
      ;;
    --output=*) output="${1#--output=}" ;;
    -h | --help) help=1 ;;
    --)
      shift
      break
      ;;
    *) break ;;
    esac
    shift
  done

  if ((help)); then
    validate::_usage
    return 0
  fi

  # Profil sicherstellen
  if ! profile::ensure_loaded; then
    if ((json)); then
      printf '{"ok":false,"errors":["no_manifest"],"missingCapabilities":[]}\n'
    else
      warn "Kein Profil gefunden (.wgx/profile.yml|.yaml|.json)."
    fi
    return 1
  fi

  if [[ -n $profile ]]; then
    case "$profile" in
    quick | full) ;;
    *)
      warn "Unbekanntes Validierungsprofil: $profile (erlaubt: quick, full)"
      return 2
      ;;
    esac
    if [[ -z $timeout_seconds ]]; then
      if [[ $profile == "quick" ]]; then
        timeout_seconds="$WGX_VALIDATE_DEFAULT_TIMEOUT_QUICK"
      else
        timeout_seconds="$WGX_VALIDATE_DEFAULT_TIMEOUT_FULL"
      fi
    fi
    if ! [[ $timeout_seconds =~ ^[0-9]+$ ]] || ((timeout_seconds == 0)); then
      warn "--timeout erwartet eine positive ganze Zahl (Sekunden)."
      return 2
    fi
    validate::_profile_run "$profile" "$json" "$timeout_seconds" "$dry_run" "$output"
    return $?
  fi

  # Manifest prüfen (nutzt vorhandene Profil-API)
  local -a _errors=() _missing=()
  profile::validate_manifest _errors _missing || true

  local ok=1
  if ((${#_errors[@]})); then ok=0; fi

  if ((json)); then
    # JSON-Ausgabe
    ok_bool="false"
    ((ok)) && ok_bool="true"
    printf '{"ok":%s,"errors":[' "$ok_bool"
    local i
    for i in "${!_errors[@]}"; do
      printf '%s"%s"' "$([ "$i" -gt 0 ] && echo ,)" "${_errors[$i]}"
    done
    printf '],"missingCapabilities":['
    for i in "${!_missing[@]}"; do
      printf '%s"%s"' "$([ "$i" -gt 0 ] && echo ,)" "${_missing[$i]}"
    done
    printf ']}\n'
  else
    # Menschlich lesbar
    if ((ok)); then
      ok "Manifest ist gültig."
    else
      warn "Manifest ist NICHT gültig."
      local e
      for e in "${_errors[@]}"; do
        printf '  - %s\n' "$e" >&2
      done
      if ((${#_missing[@]})); then
        printf 'Fehlende Capabilities:\n' >&2
        for e in "${_missing[@]}"; do
          printf '  - %s\n' "$e" >&2
        done
      fi
    fi
  fi
  return $((ok ? 0 : 1))
}
