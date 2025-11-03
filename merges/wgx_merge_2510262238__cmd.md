### 📄 cmd/audit.bash

**Größe:** 1 KB | **md5:** `400422108b43d01ccd39522a4c2a438e`

```bash
#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::verify >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

cmd_audit() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    verify)
      local strict=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --strict)
            strict=1
            ;;
          -h|--help)
            cat <<'USAGE'
Usage:
  wgx audit verify [--strict]

Prüft die Audit-Log-Kette (.wgx/audit/ledger.jsonl). Standardmäßig wird
nur eine Warnung ausgegeben, wenn die Kette beschädigt ist. Mit --strict
(oder AUDIT_VERIFY_STRICT=1) führt eine Verletzung zu einem Fehlercode.
USAGE
            return 0
            ;;
          --)
            shift
            break
            ;;
          --*)
            printf 'wgx audit verify: unknown option %s\n' "$1" >&2
            return 1
            ;;
          *)
            break
            ;;
        esac
        shift || true
      done
      if ((strict)); then
        audit::verify --strict "$@"
      else
        audit::verify "$@"
      fi
      ;;
    -h|--help|help|'')
      cat <<'USAGE'
Usage:
  wgx audit verify [--strict]

Verwaltet das Audit-Ledger von wgx.
USAGE
      ;;
    *)
      printf 'wgx audit: unknown subcommand %s\n' "$sub" >&2
      return 1
      ;;
  esac
}

wgx_command_main() {
  cmd_audit "$@"
}
```

### 📄 cmd/clean.bash

**Größe:** 8 KB | **md5:** `f3867f37418f1ad9446987d5e9dc78ee`

```bash
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
```

### 📄 cmd/config.bash

**Größe:** 668 B | **md5:** `2f58055472bf7ea39fd2f370965f8c3f`

```bash
#!/usr/bin/env bash

cmd_config() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx config [show]
  wgx config set <KEY>=<VALUE>

Description:
  Zeigt die aktuelle Konfiguration an oder setzt einen Wert in der
  '.wgx.conf'-Datei.
  Die Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'config'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # config_cmd "$@"
}

wgx_command_main() {
  cmd_config "$@"
}
```

### 📄 cmd/doctor.bash

**Größe:** 56 B | **md5:** `3ae517fcd9e460cfd239d3dff625a848`

```bash
#!/usr/bin/env bash

cmd_doctor() {
  doctor_cmd "$@"
}
```

### 📄 cmd/env.bash

**Größe:** 89 B | **md5:** `ea8e70510668067898a7db90188a693f`

```bash
#!/usr/bin/env bash

cmd_env() {
  env_cmd "$@"
}

wgx_command_main() {
  cmd_env "$@"
}
```

### 📄 cmd/guard.bash

**Größe:** 1 KB | **md5:** `41e09572c0137fdc30de9e93309d8cf2`

```bash
#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::log >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

if ! declare -F hauski::emit >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/hauski.bash"
fi

cmd_guard() {
  local -a args=("$@")
  local payload_start payload_finish
  if command -v python3 >/dev/null 2>&1; then
    payload_start=$(python3 - "${args[@]}" <<'PY'
import json
import sys
print(json.dumps({"args": list(sys.argv[1:]), "phase": "start"}))
PY
)
  else
    payload_start="{\"phase\":\"start\"}"
  fi
  audit::log "guard_start" "$payload_start" || true
  hauski::emit "guard.start" "$payload_start" || true

  guard_run "${args[@]}"
  local rc=$?

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(python3 - "$rc" <<'PY'
import json
import sys
print(json.dumps({"status": "ok" if int(sys.argv[1]) == 0 else "error", "exit_code": int(sys.argv[1])}))
PY
)
  else
    local status_word
    if ((rc == 0)); then
      status_word="ok"
    else
      status_word="error"
    fi
    printf -v payload_finish '{"status":"%s","exit_code":%d}' "$status_word" "$rc"
  fi
  audit::log "guard_finish" "$payload_finish" || true
  hauski::emit "guard.finish" "$payload_finish" || true
  return $rc
}
```

### 📄 cmd/heal.bash

**Größe:** 747 B | **md5:** `c47850477e5a749feb2c04f401c921df`

```bash
#!/usr/bin/env bash

cmd_heal() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx heal [ours|theirs|ff-only|--continue|--abort]

Description:
  Hilft bei der Lösung von Merge- oder Rebase-Konflikten.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'heal'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # heal_cmd "$@"
}

wgx_command_main() {
  cmd_heal "$@"
}
```

### 📄 cmd/hooks.bash

**Größe:** 702 B | **md5:** `889171f2e0b585db2e14f60f5487666b`

```bash
#!/usr/bin/env bash

cmd_hooks() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx hooks [install]

Description:
  Verwaltet die Git-Hooks für das Repository.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Aktuell ist nur die 'install'-Aktion geplant.
  Für Details, siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'hooks'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # hooks_cmd "$@"
}

wgx_command_main() {
  cmd_hooks "$@"
}
```

### 📄 cmd/init.bash

**Größe:** 1 KB | **md5:** `f0320e38342437cafd894ee4ce569c14`

```bash
#!/usr/bin/env bash

cmd_init() {
  local wizard=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wizard)
        wizard=1
        ;;
      -h|--help)
        cat <<'USAGE'
Usage:
  wgx init [--wizard]

Description:
  Initialisiert die 'wgx'-Konfiguration im Repository. Mit `--wizard` wird
  ein interaktiver Assistent gestartet, der `.wgx/profile.yml` erstellt.

Options:
  --wizard      Interaktiven Profil-Wizard starten.
  -h, --help    Diese Hilfe anzeigen.
USAGE
        return 0
        ;;
      --)
        shift
        break
        ;;
      --*)
        printf 'Unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
    shift || true
  done

  if ((wizard)); then
    "$WGX_DIR/cmd/init/wizard.sh"
    return $?
  fi

  echo "FEHLER: Der 'init'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
}

wgx_command_main() {
  cmd_init "$@"
}
```

### 📄 cmd/lint.bash

**Größe:** 2 KB | **md5:** `33cd0ac81eee3c58bcd0991d37ef6f4b`

```bash
#!/usr/bin/env bash

cmd_lint() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx lint

Description:
  Führt Linting-Prüfungen für verschiedene Dateitypen im Repository aus.
  Dies umfasst Shell-Skripte (Syntax-Prüfung mit bash -n, Formatierung mit shfmt,
  statische Analyse mit shellcheck) und potenziell weitere linter.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local oldpwd="$PWD"
  if ! cd "$base_dir" >/dev/null 2>&1; then
    die "Lint: Basisverzeichnis '$base_dir' nicht erreichbar."
  fi

  local -a shell_files=()

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      shell_files+=("$file")
    done < <(git ls-files -z -- '*.sh' '*.bash' 'wgx' 'cli/wgx')
  else
    while IFS= read -r -d '' file; do
      case "$file" in
      ./*) shell_files+=("${file#./}") ;;
      *) shell_files+=("$file") ;;
      esac
    done < <(find . -type f \( -name '*.sh' -o -name '*.bash' -o -name 'wgx' -o -path './cli/wgx' \) -print0)
  fi

  if [ ${#shell_files[@]} -eq 0 ]; then
    warn "No shell scripts found to lint."
    if ! cd "$oldpwd" >/dev/null 2>&1; then
      warn "Failed to return to original directory '$oldpwd'."
    fi
    return 0
  fi

  local rc=0

  if command -v bash >/dev/null 2>&1; then
    if [ ${#shell_files[@]} -ne 0 ]; then
      if ! bash -n "${shell_files[@]}"; then
        rc=1
      fi
    fi
  else
    warn "bash not found, skipping syntax check."
  fi

  if command -v shfmt >/dev/null 2>&1; then
    if ! shfmt -d "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shfmt not found, skipping formatting check."
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    local -a shellcheck_args=(--severity=style --shell=bash --external-sources --format=gcc)
    if ! shellcheck "${shellcheck_args[@]}" "${shell_files[@]}"; then
      rc=1
    fi
  else
    warn "shellcheck not found, skipping lint step."
  fi

  cd "$oldpwd" >/dev/null 2>&1 || true
  return $rc
}

lint_cmd() {
  cmd_lint "$@"
}

wgx_command_main() {
  cmd_lint "$@"
}
```

### 📄 cmd/quick.bash

**Größe:** 2 KB | **md5:** `5e024ac522df873835c5ad326a9d2198`

```bash
#!/usr/bin/env bash

_quick_usage() {
  cat <<'USAGE'
Usage: wgx quick [-i|--interactive] [--help]

Run repository guards (lint + tests) and open the PR/MR helper.

Options:
  -i, --interactive  Open the PR body in $EDITOR before sending
  -h, --help         Show this help message
USAGE
}

_quick_require_repo() {
  if ! command -v git >/dev/null 2>&1; then
    die "quick: git is not installed."
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "quick: not inside a git repository."
  fi
}

_quick_guard_available() {
  declare -F guard_run >/dev/null 2>&1
}

_quick_send_available() {
  declare -F send_cmd >/dev/null 2>&1
}

cmd_quick() {
  local interactive=0

  while (($#)); do
    case "$1" in
    -i | --interactive)
      interactive=1
      ;;
    -h | --help)
      _quick_usage
      return 0
      ;;
    --)
      shift || true
      break
      ;;
    *)
      die "Usage: wgx quick [-i|--interactive]"
      ;;
    esac
    shift || true
  done

  _quick_require_repo

  local guard_status=0
  if _quick_guard_available; then
    guard_run --lint --test || guard_status=$?
  else
    warn "guard command not available; skipping lint/test checks."
  fi

  if ((guard_status > 1)); then
    return $guard_status
  fi

  if ! _quick_send_available; then
    warn "send command not available; skipping PR helper."
    return 0
  fi

  local -a send_args=()
  if ((guard_status == 1)); then
    send_args+=(--draft)
  fi
  send_args+=(--ci --open)
  if ((interactive)); then
    send_args+=(-i)
  fi

  local send_status=0
  if ! send_cmd "${send_args[@]}"; then
    send_status=$?
  fi

  if ((send_status != 0)); then
    return $send_status
  fi

  return 0
}

wgx_command_main() {
  cmd_quick "$@"
}
```

### 📄 cmd/release.bash

**Größe:** 2 KB | **md5:** `c6d516604959b904f2531cbd25b62b87`

```bash
#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::log >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

if ! declare -F hauski::emit >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/hauski.bash"
fi

cmd_release() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx release [--version <tag>] [--auto-version <bump>] [...]

Description:
  Erstellt SemVer-Tags und GitHub/GitLab-Releases.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  --version <tag>    Die genaue Version für das Release (z.B. v1.2.3).
  --auto-version     Erhöht die Version automatisch (patch, minor, major).
  -h, --help         Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  local -a args=("$@")
  local payload_start payload_finish
  if command -v python3 >/dev/null 2>&1; then
    payload_start=$(python3 - "${args[@]}" <<'PY'
import json
import sys
print(json.dumps({"args": list(sys.argv[1:]), "phase": "start"}))
PY
)
  else
    payload_start="{\"phase\":\"start\"}"
  fi
  audit::log "release_start" "$payload_start" || true
  hauski::emit "release.start" "$payload_start" || true

  echo "FEHLER: Der 'release'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  local rc=1

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(python3 - "$rc" <<'PY'
import json
import sys
print(json.dumps({"status": "error", "exit_code": int(sys.argv[1])}))
PY
)
  else
    payload_finish="{\"status\":\"error\",\"exit_code\":${rc}}"
  fi
  audit::log "release_finish" "$payload_finish" || true
  hauski::emit "release.finish" "$payload_finish" || true
  return $rc
}

wgx_command_main() {
  cmd_release "$@"
}
```

### 📄 cmd/reload.bash

**Größe:** 3 KB | **md5:** `f7b0a9036db1617a7fd9ff7d77a3440c`

```bash
#!/usr/bin/env bash

cmd_reload() {
  local do_snapshot=0 force=0 dry_run=0

  while [ $# -gt 0 ]; do
    case "$1" in
    --snapshot)
      do_snapshot=1
      ;;
    --force | -f)
      force=1
      ;;
    --dry-run | -n)
      dry_run=1
      ;;
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx reload [--snapshot] [--force] [--dry-run] [<base_branch>]

Description:
  Setzt den Workspace hart auf den Stand des remote 'origin'-Branches zurück.
  Standardmäßig wird der in der Konfiguration festgelegte Basis-Branch ($WGX_BASE)
  oder 'main' verwendet.
  Dies ist ein destruktiver Befehl, der lokale Änderungen verwirft.

Options:
  --snapshot    Erstellt vor dem Reset einen Git-Stash als Sicherung.
  --force, -f   Erzwingt den Reset, auch wenn das Arbeitsverzeichnis unsauber ist.
  --dry-run, -n Zeigt nur die auszuführenden Befehle an, ohne Änderungen vorzunehmen.
  <base_branch> Der Branch, auf den zurückgesetzt werden soll (Standard: $WGX_BASE oder 'main').
  -h, --help    Diese Hilfe anzeigen.
USAGE
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'unbekannte Option: %s\n' "$1" >&2
      return 2
      ;;
    *)
      break
      ;;
    esac
    shift
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Bitte innerhalb eines Git-Repositories ausführen (kein Git-Repository erkannt)."
  fi

  local base="${1:-$WGX_BASE}"
  [ -z "$base" ] && base="main"

  debug "cmd_reload: force=${force} dry_run=${dry_run} snapshot=${do_snapshot} base='${base}'"

  if git_workdir_dirty; then
    local status
    status="$(git_workdir_status_short)"
    if ((force)); then
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – --force (-f) aktiv, Änderungen können verloren gehen."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
    else
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – reload abgebrochen."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
      warn "Nutze 'wgx reload --force/-f' (oder sichere mit --snapshot), wenn du wirklich alles verwerfen möchtest."
      return 1
    fi
  fi

  if ((do_snapshot)); then
    if ((dry_run)); then
      info "[DRY-RUN] Snapshot (Stash) würde erstellt."
    else
      snapshot_make
    fi
  fi

  local rc=0
  local -a reload_args=()
  ((dry_run)) && reload_args+=(--dry-run)

  git_hard_reload "${reload_args[@]}" "$base"
  rc=$?

  return $rc
}
```

### 📄 cmd/selftest.bash

**Größe:** 2 KB | **md5:** `2a2f4dd7f813d6f1fb859d372f6c9a06`

```bash
#!/usr/bin/env bash

selftest_ok() {
  printf '[OK] %s\n' "$1"
}

selftest_warn() {
  printf '[WARN] %s\n' "$1"
}

selftest_info() {
  printf '[INFO] %s\n' "$1"
}

selftest_check_bins() {
  local label="$1"
  shift || true
  local critical="$1"
  shift || true
  local miss=0 bin
  for bin in "$@"; do
    if command -v "$bin" >/dev/null 2>&1; then
      selftest_ok "$label: $bin found"
    else
      if ((critical)); then
        selftest_warn "$label: $bin missing"
        miss=1
      else
        selftest_warn "$label: $bin missing (optional)"
      fi
    fi
  done
  return "$miss"
}

cmd_selftest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx selftest

Description:
  Führt einen Mini-Sanity-Check für die 'wgx'-CLI und ihre Umgebung durch.
  Prüft, ob 'wgx' ausführbar ist, ob die Version abgerufen werden kann und
  ob kritische Abhängigkeiten wie 'git' und 'jq' verfügbar sind.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "=== wgx selftest ==="

  local had_warn=0
  local entry="${WGX_DIR}/wgx"

  if [[ -x "$entry" ]]; then
    selftest_ok "wgx ausführbar (${entry})"
  else
    selftest_warn "wgx nicht ausführbar (${entry})"
    had_warn=1
  fi

  if "$entry" version >/dev/null 2>&1; then
    selftest_ok "Version abrufbar"
  else
    selftest_warn "Version nicht abrufbar"
    had_warn=1
  fi

  if ! selftest_check_bins "Erforderlich" 1 git jq; then
    had_warn=1
  fi
  selftest_check_bins "Optional" 0 gh glab node pnpm || true

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    selftest_ok "Git-Repository erkannt (${branch})"
  else
    selftest_info "Hinweis: Selbsttest außerhalb eines Git-Repos – einige Kommandos erfordern eins."
  fi

  if ((had_warn == 0)); then
    selftest_ok "Selftest abgeschlossen."
    return 0
  fi

  selftest_warn "Selftest mit Hinweisen abgeschlossen."
  return 1
}
```

### 📄 cmd/send.bash

**Größe:** 1 KB | **md5:** `3b2e989ca96fed5df456f57d37196ccb`

```bash
#!/usr/bin/env bash

cmd_send() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx send [--draft] [--title <title>] [--why <reason>] [...]

Description:
  Erstellt einen Pull/Merge Request (PR/MR) auf GitHub oder GitLab.
  Vor dem Senden werden 'wgx guard' und 'wgx sync' ausgeführt.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  --draft       Erstellt den PR/MR als Entwurf.
  --title <t>   Setzt den Titel des PR/MR.
  --why <r>     Setzt den "Warum"-Teil im PR/MR-Body.
  --ci          Löst einen CI-Workflow aus (falls konfiguriert).
  --open        Öffnet den erstellten PR/MR im Browser.
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'send'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # send_cmd "$@"
}

wgx_command_main() {
  cmd_send "$@"
}
```

### 📄 cmd/setup.bash

**Größe:** 766 B | **md5:** `20b95955a4a03d02ada7f6bc324b57d3`

```bash
#!/usr/bin/env bash

cmd_setup() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx setup

Description:
  Hilft bei der Erstinstallation von 'wgx' und seinen Abhängigkeiten,
  insbesondere in Umgebungen wie Termux.
  Prüft auf das Vorhandensein von Kernpaketen (git, gh, glab, jq, etc.)
  und gibt Hinweise zur Installation.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'setup'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # setup_cmd "$@"
}

wgx_command_main() {
  cmd_setup "$@"
}
```

### 📄 cmd/start.bash

**Größe:** 734 B | **md5:** `558c2d70b5d0d44dedc0a6d4b2ebb9e6`

```bash
#!/usr/bin/env bash

cmd_start() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx start <branch_name>

Description:
  Erstellt einen neuen Feature-Branch nach einem validierten Schema.
  Der Name wird normalisiert (Sonderzeichen entfernt, etc.) und optional
  mit einer Issue-Nummer versehen.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  echo "FEHLER: Der 'start'-Befehl ist noch nicht vollständig implementiert." >&2
  echo "Eine Beschreibung der geplanten Funktionalität finden Sie in 'docs/Command-Reference.de.md'." >&2
  return 1
  # start_cmd "$@"
}

wgx_command_main() {
  cmd_start "$@"
}
```

### 📄 cmd/status.bash

**Größe:** 56 B | **md5:** `cd07f74d1a5386010e998d90cdc717c4`

```bash
#!/usr/bin/env bash

cmd_status() {
  status_cmd "$@"
}
```

### 📄 cmd/sync.bash

**Größe:** 6 KB | **md5:** `ab4cb871c7a0783962d1c4339eef487c`

```bash
#!/usr/bin/env bash

# Wrapper to expose sync command via cmd/ dispatcher.
cmd_sync() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Bitte innerhalb eines Git-Repositories ausführen (kein Git-Repository erkannt)."
  fi

  local force=0 dry_run=0 base_override=""
  local -a positional=()

  while [ $# -gt 0 ]; do
    case "$1" in
    --force | -f)
      force=1
      shift
      ;;
    --dry-run | -n)
      dry_run=1
      shift
      ;;
    --base)
      shift
      if [ $# -eq 0 ]; then
        printf 'sync: option --base requires an argument\n' >&2
        return 2
      fi
      base_override="$1"
      shift
      ;;
    --base=*)
      base_override="${1#--base=}"
      shift
      ;;
    -h | --help)
      cat <<'USAGE'
Usage:
  wgx sync [--force] [--dry-run] [--base <branch>]

Description:
  Holt Änderungen vom Remote-Repository. Führt 'git pull --rebase --autostash' aus.
  Wenn dies fehlschlägt, wird ein Rebase auf den angegebenen Basis-Branch
  (Standard: $WGX_BASE oder 'main') versucht.

Options:
  --force, -f      Erzwingt den Sync, auch wenn das Arbeitsverzeichnis unsauber ist
                   (lokale Änderungen werden temporär gestasht).
  --dry-run, -n    Zeigt nur die geplanten Git-Befehle an.
  --base <branch>  Setzt den Fallback-Branch für den Rebase explizit.
  -h, --help       Diese Hilfe anzeigen.
USAGE
      return 0
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        positional+=("$1")
        shift
      done
      break
      ;;
    -*)
      printf 'sync: unknown option %s\n' "$1" >&2
      return 2
      ;;
    *)
      positional+=("$1")
      shift
      ;;
    esac
  done

  local base_spec="${base_override:-${positional[0]:-$WGX_BASE}}"
  [ -z "$base_spec" ] && base_spec="main"

  local base_remote base_branch
  read -r base_remote base_branch < <(_git_parse_remote_branch_spec "$base_spec" "origin")
  if [ -z "$base_branch" ]; then
    die "sync: Ungültiger Basis-Branch '${base_spec}'."
  fi
  local base_display="${base_remote}/${base_branch}"

  if [ -n "$base_override" ] && [ "${#positional[@]}" -gt 0 ]; then
    warn "--base überschreibt den angegebenen Branch '${positional[0]}'. Nutze ${base_display} als Basis."
  fi

  debug "cmd_sync: force=${force} dry_run=${dry_run} base_spec='${base_spec}' -> remote='${base_remote}' branch='${base_branch}'"

  local stash_ref=""
  local stash_required=0

  restore_stash() {
    [ -z "$stash_ref" ] && return

    debug "restore_stash: attempting apply --index für ${stash_ref}"
    if git -c merge.renames=true -c rerere.enabled=true stash apply --index "$stash_ref" >/dev/null 2>&1; then
      debug "stash apply --index für ${stash_ref} erfolgreich"
      git stash drop "$stash_ref" >/dev/null 2>&1 || true
      stash_ref=""
      info "Lokale Änderungen wiederhergestellt."
      return 0
    fi

    debug "restore_stash: attempting apply ohne --index für ${stash_ref}"
    if git -c merge.renames=true -c rerere.enabled=true stash apply "$stash_ref" >/dev/null 2>&1; then
      git add -A >/dev/null 2>&1 || true
      git stash drop "$stash_ref" >/dev/null 2>&1 || true
      stash_ref=""
      warn "Änderungen angewendet (ohne --index). Bitte Konflikte prüfen und ggf. auflösen."
      return 0
    fi

    warn "Automatisches Wiederherstellen aus ${stash_ref} ist fehlgeschlagen – bitte 'git stash pop --index ${stash_ref}' manuell ausführen und Konflikte lösen."
    stash_ref=""
    return 0
  }

  if git_workdir_dirty; then
    local status
    status="$(git_workdir_status_short)"
    if ((force)); then
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – --force (-f) aktiv, wgx stasht temporär automatisch."
      stash_required=1
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
    else
      warn "Arbeitsverzeichnis enthält uncommittete Änderungen – Sync abgebrochen."
      if [ -n "$status" ]; then
        while IFS= read -r line; do
          printf '    %s\n' "$line" >&2
        done <<<"$status"
      fi
      warn "Nutze 'wgx sync --force/-f', wenn du trotzdem fortfahren willst (Änderungen werden ggf. gestasht)."
      # Maschinenlesbarer Marker für aufrufende Prozesse.
      printf 'sync aborted: working directory contains uncommitted changes\n'
      return 1
    fi
  fi

  local branch
  branch="$(git_current_branch)"
  if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
    die "Aktuell im detached HEAD – wechsle auf einen Branch oder nutze 'wgx reload'."
  fi

  if ((dry_run)); then
    info "[DRY-RUN] Geplante Schritte:"
    if ((stash_required)); then
      info "[DRY-RUN] git stash push --include-untracked --message wgx-sync-autostash"
      info "[DRY-RUN] (anschließend Wiederherstellung des Stash nach erfolgreichem Sync)"
    fi
    info "[DRY-RUN] git pull --rebase --autostash"
    info "[DRY-RUN] Fallback: git fetch ${base_remote} ${base_branch} && git rebase ${base_display}"
    return 0
  fi

  git_has_remote "$base_remote" || die "Kein ${base_remote}-Remote gefunden."

  if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    die "Kein Upstream für ${branch} konfiguriert. Setze ihn mit: git branch --set-upstream-to=${base_display} ${branch}"
  fi

  if ((stash_required)); then
    debug "cmd_sync: creating autostash vor Pull"
    if ! git stash push --include-untracked --message "wgx-sync-autostash" >/dev/null; then
      die "Konnte lokale Änderungen nicht automatisch stashen."
    fi
    stash_ref="$(git stash list --pretty='%gD' | head -n1)"
    debug "cmd_sync: erzeugter Stash ${stash_ref}"
  fi

  info "Pull (rebase, autostash) vom Remote…"
  if git pull --rebase --autostash; then
    restore_stash
    info "Sync abgeschlossen (${branch})."
    return 0
  fi

  warn "git pull --rebase --autostash fehlgeschlagen – versuche Rebase auf ${base_display}."
  info "Fetch von ${base_display}…"
  if ! git fetch "$base_remote" "$base_branch"; then
    restore_stash
    die "git fetch ${base_display} fehlgeschlagen"
  fi

  info "Rebase auf ${base_display}…"
  if ! git rebase "${base_display}"; then
    restore_stash
    die "Rebase fehlgeschlagen – bitte Konflikte manuell lösen oder 'wgx heal' (falls verfügbar) verwenden."
  fi

  restore_stash
  info "Sync abgeschlossen (${branch})."
  return 0
}
```

### 📄 cmd/task.bash

**Größe:** 4 KB | **md5:** `c9ed1d5ccfef901320a7e32f59b97ecf`

```bash
#!/usr/bin/env bash

if [ -z "${WGX_DIR:-}" ]; then
  WGX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if ! declare -F audit::log >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/audit.bash"
fi

if ! declare -F hauski::emit >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$WGX_DIR/lib/hauski.bash"
fi

wgx::_json_escape_fallback() {
  local input="${1:-}" output="" ch
  while IFS= read -r -n1 ch; do
    case "$ch" in
      \\)
        output+=$'\\\\'
        ;;
      '"')
        output+=$'\\"'
        ;;
      $'\n')
        output+=$'\\n'
        ;;
      $'\r')
        output+=$'\\r'
        ;;
      $'\t')
        output+=$'\\t'
        ;;
      *)
        output+="$ch"
        ;;
    esac
  done <<<"$input"
  printf '%s' "$output"
}

cmd_task() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    cat <<'USAGE'
Usage:
  wgx task <name> [--] [args...]

Description:
  Führt einen Task aus, der in der '.wgx/profile.yml'-Datei des Repositorys
  definiert ist. Alle Argumente nach dem Task-Namen (und einem optionalen '--')
  werden an den Task weitergegeben.

Example:
  wgx task test -- --verbose

Options:
  -h, --help    Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if ! profile::ensure_loaded; then
    die ".wgx/profile.yml not found."
  fi

  local name="$1"
  shift || true

  if [[ ${1:-} == -- ]]; then
    shift
  fi

  local -a forwarded=()
  if (($#)); then
    forwarded=("$@")
  fi

  local key
  key="$(profile::_normalize_task_name "$name")"
  local spec
  spec="$(profile::_task_spec "$key")"
  if [[ -z $spec ]]; then
    die "Task not defined: $name"
  fi

  local payload_start payload_finish
  if command -v python3 >/dev/null 2>&1; then
    payload_start=$(python3 - "$name" "${forwarded[@]}" <<'PY'
import json
import sys

task = sys.argv[1]
args = list(sys.argv[2:])
print(json.dumps({"task": task, "args": args, "phase": "start"}))
PY
)
  else
    local esc_name
    if type -t json_escape >/dev/null 2>&1; then
      esc_name=$(json_escape "$name")
    else
      esc_name=$(wgx::_json_escape_fallback "$name")
    fi
    payload_start="{\"task\":\"${esc_name}\",\"phase\":\"start\"}"
  fi
  audit::log "task_start" "$payload_start" || true
  hauski::emit "task.start" "$payload_start" || true

  # Run task, capture real exit code, then branch on it.
  # Important: The CLI wrapper enables `set -e` (errexit). If the task fails,
  # a plain invocation would abort the shell before we can capture `$?`.
  # We therefore (temporarily) disable errexit, run the task, grab rc, and
  # restore the original errexit state afterwards.
  local rc had_errexit=0
  if [[ $- == *e* ]]; then
    had_errexit=1
    set +o errexit
  fi
  profile::run_task "$name" "${forwarded[@]}"
  rc=$?
  if (( had_errexit )); then
    set -o errexit
  fi
  if (( rc != 0 )); then
    if command -v python3 >/dev/null 2>&1; then
      payload_finish=$(python3 - "$name" "$rc" <<'PY'
import json
import sys
print(json.dumps({"task": sys.argv[1], "status": "error", "exit_code": int(sys.argv[2])}))
PY
)
    else
      local esc
      if type -t json_escape >/dev/null 2>&1; then
        esc=$(json_escape "$name")
      else
        esc=$(wgx::_json_escape_fallback "$name")
      fi
      payload_finish="{\"task\":\"${esc}\",\"status\":\"error\",\"exit_code\":${rc}}"
    fi
    audit::log "task_finish" "$payload_finish" || true
    hauski::emit "task.finish" "$payload_finish" || true
    return $rc
  fi

  if command -v python3 >/dev/null 2>&1; then
    payload_finish=$(python3 - "$name" <<'PY'
import json
import sys
print(json.dumps({"task": sys.argv[1], "status": "ok", "exit_code": 0}))
PY
)
  else
    local esc
    if type -t json_escape >/dev/null 2>&1; then
      esc=$(json_escape "$name")
    else
      esc=$(wgx::_json_escape_fallback "$name")
    fi
    payload_finish="{\"task\":\"${esc}\",\"status\":\"ok\",\"exit_code\":0}"
  fi
  audit::log "task_finish" "$payload_finish" || true
  hauski::emit "task.finish" "$payload_finish" || true
  return 0
}
```

### 📄 cmd/tasks.bash

**Größe:** 2 KB | **md5:** `2dc82709a70b53329b01fa8bd8d25cf7`

```bash
#!/usr/bin/env bash

cmd_tasks() {
  local json=0 safe_only=0 include_groups=0
  while (($#)); do
    case "$1" in
    --json) json=1 ;;
    --safe) safe_only=1 ;;
    --groups) include_groups=1 ;;
    -h | --help)
      cat <<'USAGE'
Usage: wgx tasks [--json] [--safe] [--groups]
  --json    Output machine readable JSON
  --safe    Only include tasks marked as safe
  --groups  Include group metadata (JSON) or group headings (text)
USAGE
      return 0
      ;;
    *)
      warn "unknown option: $1"
      return 1
      ;;
    esac
    shift
  done

  if ! profile::ensure_loaded; then
    warn ".wgx/profile manifest not found."
    return 1
  fi

  if ((json)); then
    profile::tasks_json "$safe_only" "$include_groups"
    return $?
  fi

  local -a _task_names=()
  mapfile -t _task_names < <(profile::_task_keys)
  if ((${#_task_names[@]} == 0)); then
    warn "No tasks defined in manifest."
    return 0
  fi

  if ((include_groups)); then
    declare -A _groups=()
    declare -A _order_seen=()
    local -a _order=()
    local name group safe
    for name in "${_task_names[@]}"; do
      safe="$(profile::_task_safe "$name")"
      if ((safe_only)) && [[ "$safe" != "1" ]]; then
        continue
      fi
      group="$(profile::_task_group "$name")"
      [[ -n $group ]] || group="default"
      _groups["$group"]+="$name"$'\n'
      if [[ -z ${_order_seen[$group]:-} ]]; then
        _order_seen[$group]=1
        _order+=("$group")
      fi
    done
    if ((${#_order[@]} == 0)); then
      warn "No tasks matched filters."
      return 0
    fi
    local group_name
    for group_name in "${_order[@]}"; do
      printf '%s:\n' "$group_name"
      printf '%s' "${_groups[$group_name]}" | sort | while IFS= read -r task; do
        [[ -n $task ]] && printf '  %s\n' "$task"
      done
    done
    return 0
  fi

  local -a filtered=()
  local task safe
  for task in "${_task_names[@]}"; do
    safe="$(profile::_task_safe "$task")"
    if ((safe_only)) && [[ "$safe" != "1" ]]; then
      continue
    fi
    filtered+=("$task")
  done
  if ((${#filtered[@]} == 0)); then
    warn "No tasks matched filters."
    return 0
  fi
  printf '%s\n' "${filtered[@]}" | sort
}
```

### 📄 cmd/test.bash

**Größe:** 2 KB | **md5:** `61a2dee6136d1ddab92a234360ad680f`

```bash
#!/usr/bin/env bash

# Print usage information for `wgx test`.
_test_usage() {
  cat <<'USAGE'
Usage:
  wgx test [--list] [--] [BATS_ARGS...]
  wgx test --help

Runs the Bats test suite located under tests/.

Options:
  --list        Show discovered *.bats files without executing them.
  --help        Display this help text.
  --            Forward all following arguments directly to bats.

Examples:
  wgx test                 # run all Bats suites
  wgx test -- --filter foo # pass custom flags to bats
  wgx test --list          # list available test files
USAGE
}

# Collect all Bats test files in a directory.
_test_collect_files() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    return 1
  fi

  find "$dir" -maxdepth 1 -type f -name '*.bats' -print0 | sort -z
}

test_cmd() {
  local base_dir="${WGX_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local tests_dir="${base_dir}/tests"
  local show_list=0
  local -a bats_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      _test_usage
      return 0
      ;;
    --list)
      show_list=1
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        bats_args+=("$1")
        shift
      done
      break
      ;;
    *)
      bats_args+=("$1")
      ;;
    esac
    shift || true
  done

  local -a test_files=()
  local file
  while IFS= read -r -d '' file; do
    test_files+=("$file")
  done < <(_test_collect_files "$tests_dir") || true

  if [ ${#test_files[@]} -eq 0 ]; then
    warn "No Bats tests found under ${tests_dir}."
    return 0
  fi

  if [ "$show_list" -eq 1 ]; then
    local f
    for f in "${test_files[@]}"; do
      printf '%s\n' "${f#"${tests_dir}"/}"
    done
    return 0
  fi

  if ! command -v bats >/dev/null 2>&1; then
    warn "bats (https://github.com/bats-core/bats-core) is not installed. Please install bats-core to run tests."
    return 127
  fi

  info "Starting Bats tests..."
  bats "${bats_args[@]}" "${test_files[@]}"
}

wgx_command_main() {
  test_cmd "$@"
}
```

### 📄 cmd/validate.bash

**Größe:** 2 KB | **md5:** `cfc152f75bc5457d73c3f9d4419e04d5`

```bash
#!/usr/bin/env bash
#
# wgx validate — prüft das .wgx/profile.* Manifest
#

validate_cmd() {
  local json=0 help=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1 ;;
      -h|--help) help=1 ;;
      --) shift; break ;;
      *) break ;;
    esac
    shift
  done

  if ((help)); then
    cat <<'USAGE'
Usage:
  wgx validate [--json]

Validiert das Manifest (.wgx/profile.*) im aktuellen Repository.
Exit-Status: 0 bei gültigem Manifest, sonst >0.

Optionen:
  --json   Kompakte maschinenlesbare Ausgabe:
           {"ok":bool,"errors":[...],"missingCapabilities":[...]}
USAGE
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

  # Manifest prüfen (nutzt vorhandene Profil-API)
  local -a _errors=() _missing=()
  profile::validate_manifest _errors _missing || true

  local ok=1
  if ((${#_errors[@]})); then ok=0; fi

  if ((json)); then
    # JSON-Ausgabe
    printf '{"ok":%s,"errors":[' "$([ $ok -eq 1 ] && echo true || echo false)"
    local i
    for i in "${!_errors[@]}"; do
      printf '%s"%s"' "$([ $i -gt 0 ] && echo ,)" "${_errors[$i]}"
    done
    printf '],"missingCapabilities":['
    for i in "${!_missing[@]}"; do
      printf '%s"%s"' "$([ $i -gt 0 ] && echo ,)" "${_missing[$i]}"
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
  return $(( ok ? 0 : 1 ))
}

# Einheitlicher Einstiegspunkt – wie bei den anderen cmd/*-Skripten
wgx_command_main() {
  validate_cmd "$@"
}
```

### 📄 cmd/version.bash

**Größe:** 938 B | **md5:** `d1c8743196f6a81373260a0da245bc0d`

```bash
#!/usr/bin/env bash

cmd_version() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'USAGE'
Usage:
  wgx version [bump <level>] [set <version>]

Description:
  Zeigt die aktuelle Version von 'wgx' an oder manipuliert die Version
  in Projektdateien wie 'package.json' oder 'Cargo.toml'.
  Die Implementierung der Unterbefehle 'bump' und 'set' ist noch in Arbeit.

Subcommands:
  bump <level>   Erhöht die Version ('patch', 'minor', 'major').
  set <version>  Setzt die Version auf einen exakten Wert.

Options:
  -h, --help     Diese Hilfe anzeigen.
USAGE
    return 0
  fi

  if [ -n "${WGX_VERSION:-}" ]; then
    printf '%s\n' "$WGX_VERSION"
    return
  fi

  if [ -f "$WGX_DIR/VERSION" ]; then
    cat "$WGX_DIR/VERSION"
    return
  fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    git describe --tags --always 2>/dev/null || git rev-parse --short HEAD
  else
    printf 'wgx (unversioned)\n'
  fi
}
```

