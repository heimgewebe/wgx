![WGX](https://img.shields.io/badge/wgx-enabled-blue)

# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS). Lizenz: MIT (projektintern).

## Schnellstart

> 📘 **Language policy:** New contributions should use English for user-facing text.
> See [docs/Language-Policy.md](docs/Language-Policy.md) for the detailed guidance.

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
  bash -n $(git ls-files '*.sh' '*.bash')
  shfmt -d $(git ls-files '*.sh' '*.bash')
  shellcheck -S style $(git ls-files '*.sh' '*.bash')
  bats -r tests
  ```
- Node.js tooling ist nicht erforderlich; npm-/pnpm-Workflows sind deaktiviert, und es existiert kein `package.json` mehr.

## Python-Stack (uv als Standard)

- wgx nutzt [uv](https://docs.astral.sh/uv/) als Default-Laufzeit für Python-Versionen, Lockfiles und Tools.
- Die wichtigsten Wrapper-Kommandos:

  ```bash
  wgx py up         # gewünschte Python-Version via uv bereitstellen
  wgx py sync       # Abhängigkeiten anhand von uv.lock installieren
  wgx py run test   # uv run <task>, z. B. Tests
  wgx tool add ruff # CLI-Tools wie pipx, nur über uv
  ```

- Projekte deklarieren das Verhalten in `.wgx/profile.yml`:

  ```yaml
  python:
    manager: uv
    version: "3.12"
    lock: true
    tools:
      - ruff
      - pyright
  contracts:
    uv_lock_present: true
    uv_sync_frozen: true
  ```

- Die `contracts`-Einträge lassen sich via `wgx guard` automatisiert überprüfen.
- Übergang aus bestehenden `requirements.txt`: `uv pip sync requirements.txt`, anschließend `uv lock`.
- Optional für Fremdsysteme: `uv pip compile --output-file requirements.txt` erzeugt kompatible Artefakte.
- Wer eine alternative Toolchain benötigt, kann in `profile.yml` auf `manager: pip` zurückfallen.
- `python.version` akzeptiert exakte Versionen (`3.12`) oder Bereiche (`3.12.*`).

- CI-Empfehlung (GitHub Actions, gekürzt):

  ```yaml
  - name: Install uv
    run: |
      curl -LsSf https://astral.sh/uv/install.sh | sh
      echo "UV_VERSION=$($HOME/.local/bin/uv --version | awk '{print $2}')" >> "$GITHUB_ENV"
  - name: Cache uv
    uses: actions/cache@v4
    with:
      path: ~/.cache/uv
      key: uv-${{ runner.os }}-${{ env.UV_VERSION || 'latest' }}-${{ hashFiles('**/pyproject.toml', '**/uv.lock') }}
  - name: Sync deps (frozen)
    run: ~/.local/bin/uv sync --frozen
  - name: Test
    run: ~/.local/bin/uv run pytest -q
  ```

- WGX-Contracts (durchsetzbar via `wgx guard`):
  - `contract:uv_lock_present` → `uv.lock` ist committed
  - `contract:uv_sync_frozen` → Pipelines nutzen `uv sync --frozen`

- Beispiele für `wgx py run`:

  ```bash
  wgx py run "python -m http.server"
  wgx py run pytest -q
  ```

- Devcontainer-Hinweis: kombiniere die Installation mit dem Sync, z. B. `"postCreateCommand": "bash -lc '.devcontainer/setup.sh ensure-uv && ~/.local/bin/uv sync'"`.
- Für regulierte Umgebungen kann die Installation statt `curl | sh` über gepinnte Paketquellen erfolgen.
- Weitere Hintergründe stehen in [docs/ADR-0002__python-env-manager-uv.de.md](docs/ADR-0002__python-env-manager-uv.de.md) und im [Runbook](docs/Runbook.de.md#leitfaden-von-requirementstxt-zu-uv).

## Kommandos

### reload

Destruktiv: setzt den Workspace hart auf `origin/$WGX_BASE` zurück (`git reset --hard` + `git clean -fdx`).

- Bricht ab, wenn das Arbeitsverzeichnis nicht sauber ist (außer mit `--force`).
- Mit `--dry-run` werden nur die Schritte angezeigt, ohne etwas zu verändern.
- Optional sichert `--snapshot` vorher in einen Git-Stash.

**Alias**: `sync-remote`.

### sync

Holt Änderungen vom Remote (`git pull --rebase --autostash --ff-only`). Scheitert das, wird automatisch auf `origin/$WGX_BASE` rebased.

- Schützt vor unbeabsichtigtem Lauf auf einem „dirty“ Working Tree (Abbruch ohne `--force`).
- `--dry-run` zeigt nur die geplanten Git-Kommandos.
- Über `--base <branch>` lässt sich der Fallback-Branch für den Rebase explizit setzen.
- Gibt es zusätzlich ein Positionsargument, hat `--base` Vorrang und weist mit einer Warnung darauf hin.

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

## Vision & Manifest

Für die vollständige, integrierte Produktvision („Repo-Betriebssystem“) lies
**[docs/wgx-mycelium-v-omega.de.md](docs/wgx-mycelium-v-omega.de.md)**.
Sie bündelt Bedienkanon, Fleet, Memory, Policies, Offline, Registry und Roadmap.
WGX macht Abläufe reproduzierbar, erklärt Policies und liefert Evidence-Packs für PRs – im Einzelrepo und in der Fleet.

## Konfiguration

Standardwerte liegen unter `etc/config.example`.
Beim ersten Lauf von `wgx init` werden die Werte nach `~/.config/wgx/config` kopiert.
Anschließend kannst du sie dort projektspezifisch anpassen.

## .wgx/profile (v1 / v1.1)

- **Datei**: `.wgx/profile.yml` (oder `.yaml` / `.json`)
- **Details**: Kapitel [6. Profile v1 / v1.1](docs/wgx-mycelium-v-omega.de.md#6-profile-v1--v11-minimal--reich) im Mycelium-Manifest erläutert Struktur, Defaults und Erweiterungen.
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
Die Quoting-Grundregeln sind in der [Leitlinie: Shell-Quoting](docs/Leitlinie.Quoting.de.md)
gebündelt.

## Architekturhinweis — nur modulare Struktur

Seit 2025-09-25 ist die modulare Struktur verbindlich (`cli/`, `cmd/`, `lib/`, `etc/`, `modules/`).
Der alte Monolith wurde archiviert: `docs/archive/wgx_monolith_*.md`.
