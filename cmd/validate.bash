#!/usr/bin/env bash
#
# Validiert ein wgx-Profil.
#
# SYNOPSIS
#   validate::run [--json] [--out <pfad>] [<repo_dir>]
#
# BEMERKUNGEN
#   - Prüft .wgx/profile.yml gegen .wgx/schema/profile.v1.json
#   - Nutzt `ajv` (bevorzugt) oder `yq` (Fallback)
#   - CLI-Entrypoint: `wgx-validate`
#
# SUBKOMMANDO: lints
#   - Führt Shell-Linter (bash -n, shfmt, shellcheck) aus.
#   - SYNOPSIS: wgx-validate-lints [-c] [-q]
#     -c -> nur geänderte Dateien
#     -q -> leise
#     -> Bash -n, shfmt -d, shellcheck -S style
# ================================================================

log() { printf '%s\n' "$*" >&2; }
die() {
  log "ERR: $*"
  exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "Fehlt Tool: $1"; }

# ---------------------- JSON Helper ------------------------------
_json_escape() { jq -Rrs . <<<"${1:-}"; } 2>/dev/null || true
json_emit() { # json_emit status msg details
  local status="${1:-error}" msg="${2:-}" details="${3:-}"
  local s m d
  s="$status"
  m="$msg"
  d="$details"
  printf '{"status":%s,"message":%s,"details":%s}\n' \
    "$(_json_escape "$s")" "$(_json_escape "$m")" "$(_json_escape "$d")"
}

# ---------------- Manifest Validation ---------------------------
validate_manifest() {
  local repo="${1:-.}" json="${2:-0}" out_path="${3:-}"
  local prof="$repo/.wgx/profile.yml"
  local schema_json="$repo/.wgx/schema/profile.v1.json"

  if [[ ! -f "$prof" ]]; then
    local msg="Profil fehlt: $prof"
    if ((json)); then json_emit "error" "$msg" "{}"; else die "$msg"; fi
    return 1
  fi

  # Tools optional prüfen
  local have_ajv=0 have_yq=0
  command -v ajv >/dev/null 2>&1 && have_ajv=1
  command -v yq >/dev/null 2>&1 && have_yq=1

  # 1) Bevorzugt: ajv mit Schema (wenn vorhanden)
  if ((have_ajv)) && [[ -f "$schema_json" ]]; then
    if ((have_yq)); then
      local _tmp_json
      _tmp_json="$(mktemp -t wgx-prof-XXXX.json)"
      if ! yq -o=json '.' "$prof" >"$_tmp_json" 2>/dev/null; then
        local err="Konnte YAML nicht nach JSON konvertieren (yq)."
        rm -f -- "$_tmp_json"
        if ((json)); then
          json_emit "error" "$err" "{\"validator\":\"yq\"}" | tee "${out_path:-/dev/null}"
        else
          log "$err"
        fi
        return 1
      fi
      if ajv validate -s "$schema_json" -d "$_tmp_json" >/dev/null 2>&1; then
        rm -f -- "$_tmp_json"
        local ok="Manifest ist valide (ajv + Schema; YAML→JSON via yq)."
        if ((json)); then
          json_emit "ok" "$ok" "{\"validator\":\"ajv\",\"schema\":\"$schema_json\"}" | tee "${out_path:-/dev/null}"
        else
          log "$ok"
        fi
        return 0
      else
        rm -f -- "$_tmp_json"
        local err="Manifest ungültig laut ajv (nach YAML→JSON-Konvertierung)."
        if ((json)); then
          json_emit "error" "$err" "{\"validator\":\"ajv\",\"schema\":\"$schema_json\"}" | tee "${out_path:-/dev/null}"
        else
          log "$err"
        fi
        return 1
      fi
    fi # Ende 'have_yq' Block für Konvertierung
  fi

  # 2) Fallback: Minimalchecks mit yq
  if ((have_yq)); then
    # Minimal: .wgx.apiVersion und .wgx.requiredWgx vorhanden?
    local api req
    api="$(yq -r '.wgx.apiVersion // empty' "$prof" 2>/dev/null || true)"
    req="$(yq -r '.wgx.requiredWgx // empty' "$prof" 2>/dev/null || true)"
    if [[ -n "$api" && -n "$req" ]]; then
      local ok="Manifest besteht Minimalchecks (yq)."
      if ((json)); then
        json_emit "ok" "$ok" "{\"validator\":\"yq\",\"apiVersion\":\"$api\",\"requiredWgx\":\"$req\"}" | tee "${out_path:-/dev/null}"
      else
        log "$ok"
      fi
      return 0
    else
      local err="Manifest-Keys fehlen (wgx.apiVersion / wgx.requiredWgx)."
      if ((json)); then
        json_emit "error" "$err" "{\"validator\":\"yq\"}" | tee "${out_path:-/dev/null}"
      else
        log "$err"
      fi
      return 1
    fi
  fi

  # 3) Kein Validator verfügbar
  local warn="Weder ajv (mit Schema) noch yq verfügbar – keine Validierung möglich."
  if ((json)); then
    json_emit "warn" "$warn" "{}" | tee "${out_path:-/dev/null}"
  else
    log "$warn"
  fi
  return 2
}

# ----------------- Öffentliche API: validate::run ----------------
validate::run() { # [--json] [--out <pfad>] [<repo>]
  local json=0 out_path="" repo="."
  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
    --json)
      json=1
      shift
      ;;
    --out)
      out_path="${2:-}"
      [[ -n "$out_path" ]] || die "--out braucht Pfad"
      shift 2
      ;;
    -h | --help)
      cat <<'USAGE'
validate::run [--json] [--out <pfad>] [<repo_dir>]
  Validiert <repo_dir>/.wgx/profile.yml gegen Schema (ajv) oder via Minimalchecks (yq).
  Rückgabe: Exit 0 (ok), 1 (ungültig), 2 (keine Validierung möglich).
USAGE
      return 0
      ;;
    *)
      repo="$1"
      shift
      ;;
    esac
  done

  validate_manifest "$repo" "$json" "$out_path"
}

# -------------------- Zusatz: Shell-Lints CLI --------------------
wgx-validate-lints() { # [-c] [-q]
  local changed_only=0 quiet=0
  while getopts ':cqh' opt; do
    case "$opt" in
    c) changed_only=1 ;;
    q) quiet=1 ;;
    h)
      cat <<'USAGE'
wgx-validate-lints [-c] [-q]
  -c   Nur geänderte Dateien prüfen (gegen HEAD)
  -q   Ruhiger Modus (nur Fehlerausgabe)
USAGE
      return 0
      ;;
    \?) die "Unbekannte Option: -$OPTARG (nutze -h)" ;;
    esac
  done
  shift $((OPTIND - 1))

  need git
  need bash
  need shfmt
  need shellcheck

  local -a files=()
  if ((changed_only)); then
    while IFS= read -r -d '' f; do
      case "$f" in *.sh | *.bash) files+=("$f") ;; esac
    done < <(git diff --name-only -z --diff-filter=ACMRTUXB HEAD --)
  else
    while IFS= read -r -d '' f; do files+=("$f"); done < <(git ls-files -z -- '*.sh' '*.bash')
  fi

  if ((${#files[@]} == 0)); then
    log "Keine passenden Shell-Dateien gefunden."
    return 0
  fi

  if ! ((quiet)); then
    log "Dateien:"
    printf ' - %s\n' "${files[@]}" >&2
  fi

  local rc=0
  bash -n "${files[@]}" || rc=1
  shfmt -d -i 2 -ci -sr "${files[@]}" || rc=1
  shellcheck -S style "${files[@]}" || rc=1

  return $rc
}

# ----------------------- Main Entry -----------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Direkter CLI-Entry:
  #  - Falls erstes Argument "lints" ist -> Lint-Subkommando
  if [[ "${1:-}" == "lints" ]]; then
    shift
    wgx-validate-lints "$@"
  else
    validate::run "$@"
  fi
fi