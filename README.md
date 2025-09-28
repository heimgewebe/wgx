# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS). Lizenz: MIT (projektintern).

## Quickstart

```bash
git clone <DEIN-REPO>.git wgx
cd wgx

# (optional) im Devcontainer öffnen
# VS Code → „Reopen in Container“

# wgx in den PATH verlinken
mkdir -p "$HOME/.local/bin"
ln -sf "$PWD/cli/wgx" "$HOME/.local/bin/wgx"
export PATH="$HOME/.local/bin:$PATH"

# Smoke-Test
wgx --help
wgx doctor

# Erstlauf
wgx init
wgx clean
wgx send "feat: initial test run"
```

Falls ein Befehl unbekannt ist, kannst du die verfügbaren Subcommands auflisten:

```bash
wgx --list 2>/dev/null || wgx commands 2>/dev/null || ls -1 cmd/
```

## Dev quick start

- Open in VS Code → “Reopen in Container”
- Run CI locally:
  ```bash
  shfmt -d $(git ls-files '*.sh' '*.bash')
  shellcheck -S style $(git ls-files '*.sh' '*.bash')
  bats -r tests
  ```

## Commands

### reload
Destruktiv: setzt den Workspace hart auf `origin/$WGX_BASE` zurück (`git reset --hard` + `git clean -fdx`).

**Alias**: `sync-remote`.

## Repository-Layout

```
.
├─ cli/                 # Einstieg: ./cli/wgx (Dispatcher)
├─ cmd/                 # EIN Subcommand = EINE Datei
├─ lib/                 # Wiederverwendbare Bash-Bibliotheken
├─ modules/             # Optionale Erweiterungen
├─ etc/                 # Default-Konfigurationen
├─ templates/           # Vorlagen (PR-Text, Hooks, ...)
├─ tests/               # Automatisierte Shell-Tests
├─ installers/          # Installations-Skripte
└─ docs/                # Handbücher, ADRs
```

Der eigentliche Dispatcher liegt unter `cli/wgx`. Alle Subcommands werden über die Dateien im Ordner `cmd/` geladen und greifen dabei auf die Bibliotheken in `lib/` zurück. Wiederkehrende Helfer (Logging, Git-Hilfen, Environment-Erkennung usw.) sind im Kernmodul `lib/core.bash` gebündelt.

## Konfiguration

Standardwerte liegen unter `etc/config.example`. Beim ersten Lauf von `wgx init` werden die Werte nach `~/.config/wgx/config` kopiert und können dort projektspezifisch angepasst werden.

## Tests

Automatisierte Tests werden über `tests/` organisiert (z. B. mit [Bats](https://bats-core.readthedocs.io/)). Ergänzende Checks kannst du via `wgx selftest` starten.

## Architecture Note — Modular Only
Seit 2025-09-25 ist die modulare Struktur verbindlich (`cli/`, `cmd/`, `lib/`, `etc/`, `modules/`).
Der alte Monolith wurde archiviert: `docs/archive/wgx_monolith_*.md`.
