# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS). Lizenz: MIT (projektintern).

## Schnellstart

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

## Entwicklungs-Schnellstart

- In VS Code öffnen → „Reopen in Container“
- CI lokal ausführen:

  ```bash
  shfmt -d $(git ls-files '*.sh' '*.bash')
  shellcheck -S style $(git ls-files '*.sh' '*.bash')
  bats -r tests
  ```

## Kommandos

### reload

Destruktiv: setzt den Workspace hart auf `origin/$WGX_BASE` zurück (`git reset --hard` + `git clean -fdx`).

**Alias**: `sync-remote`.

## Repository-Layout

```text
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

Der eigentliche Dispatcher liegt unter `cli/wgx`.
Alle Subcommands werden über die Dateien im Ordner `cmd/` geladen und greifen dabei auf die Bibliotheken in `lib/` zurück.
Wiederkehrende Helfer (Logging, Git-Hilfen, Environment-Erkennung usw.) sind im Kernmodul `lib/core.bash` gebündelt.

## Konfiguration

Standardwerte liegen unter `etc/config.example`.
Beim ersten Lauf von `wgx init` werden die Werte nach `~/.config/wgx/config` kopiert.
Anschließend kannst du sie dort projektspezifisch anpassen.

## .wgx/profile (v1 / v1.1)

- **Datei**: `.wgx/profile.yml` (oder `.yaml` / `.json`)
- **apiVersion**:
  - `v1`: einfache Strings für `tasks.<name>`
  - `v1.1`: reichere Spezifikation (Arrays, desc/group/safe, envDefaults/Overrides, requiredWgx-Objekt)

### Minimales Beispiel (v1)

```yaml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  repoKind: "generic"
  tasks:
    test: "cargo test --workspace"
```

### Erweitertes Beispiel (v1.1)

```yaml
wgx:
  apiVersion: v1.1
  requiredWgx:
    range: "^2.0"
    min: "2.0.3"
    caps: ["task-array","status-dirs"]
  repoKind: "hauski"
  dirs: { web: "", api: "crates", data: ".local/state/hauski" }
  env:
    RUST_LOG: "info,hauski=debug"
  envDefaults:
    RUST_BACKTRACE: "1"
  envOverrides: {}
  tasks:
    doctor: { desc: "Sanity-Checks", safe: true, cmd: ["cargo","run","-p","hauski-cli","--","doctor"] }
    test:   { desc: "Workspace-Tests", safe: true, cmd: ["cargo","test","--workspace","--","--nocapture"] }
    serve:  { desc: "Entwicklungsserver", cmd: ["cargo","run","-p","hauski-cli","--","serve"] }
```

## Tests

Automatisierte Tests werden über `tests/` organisiert (z. B. mit [Bats](https://bats-core.readthedocs.io/)).
Ergänzende Checks kannst du via `wgx selftest` starten.

## Architekturhinweis — nur modulare Struktur

Seit 2025-09-25 ist die modulare Struktur verbindlich (`cli/`, `cmd/`, `lib/`, `etc/`, `modules/`).
Der alte Monolith wurde archiviert: `docs/archive/wgx_monolith_*.md`.
