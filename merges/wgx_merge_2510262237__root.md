### 📄 .editorconfig

**Größe:** 188 B | **md5:** `9300170d1d2d72e9e9f67c4654217ad2`

```plaintext
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
```

### 📄 .gitattributes

**Größe:** 36 B | **md5:** `e6d0d1ca3507da50046da02aa2380b7b`

```plaintext
* text=auto eol=lf
*.sh text eol=lf
```

### 📄 .gitignore

**Größe:** 523 B | **md5:** `6e3c88d693b1164ff0c8d588b72a53d6`

```plaintext
# Logs & tmp
*.log
*.bak
*.swp
.DS_Store
.tmp/
metrics.json

# Local helper state
/.local/

# Local wgx profiles
.wgx/profile.yml
.wgx/profile.yaml
.wgx/profile.json

# Audit temp signatures
.wgx/audit/*.sig
.wgx/audit/ledger.jsonl

# Local cache directory (created by helper scripts)
/.local/*
!/.local/README.md

# Generated readiness artifacts (published via CI)
/artifacts/readiness.json
/artifacts/readiness-table.md
/artifacts/readiness-badge.svg

# Generated artifact directory (covers future additions)
/artifacts/
```

### 📄 .markdownlint.jsonc

**Größe:** 110 B | **md5:** `40b09b9f7920446e079580c72126008c`

```plaintext
{
  "default": true,
  "MD013": { "line_length": 120, "tables": false },
  "MD033": false,
  "MD041": false
}
```

### 📄 .pre-commit-config.yaml

**Größe:** 560 B | **md5:** `7979245efaf30c9ac79954b1cc725b99`

```yaml
repos:
  - repo: https://github.com/jumanjihouse/pre-commit-hooks
    rev: v4.2.0
    hooks:
      - id: shellcheck
        args: ["-S", "style"]
        files: "\\.(sh|bash)$"
      - id: shfmt
        args: ["-i", "2", "-ci", "-sr"]
        files: "\\.(sh|bash)$"
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.43.0
    hooks:
      - id: markdownlint
        files: "\\.(md|mdx)$"
  - repo: https://github.com/errata-ai/vale
    rev: v3.8.0
    hooks:
      - id: vale
        args: ["--no-exit", "."]
        files: "\\.(md|mdx)$"
```

### 📄 .vale.ini

**Größe:** 253 B | **md5:** `134893adb24951cb75e06d5ec76d1f78`

```plaintext
StylesPath = .vale/styles
MinAlertLevel = warning

# Code-Dateien (ohne Shell)
[*.{rs,ts,js,py}]
BasedOnStyles = wgxlint

[*.{md,mdx}]
BasedOnStyles = hauski/GermanProse

# Shell-Skripte (inkl. .bash)
[*.{sh,bash}]
BasedOnStyles = hauski/GermanComments
```

### 📄 CHANGELOG.md

**Größe:** 132 B | **md5:** `fa56d43184094ef2755ce69e0c5f8713`

```markdown
# Changelog

## 2.0.0 (YYYY-MM-DD)
- Initiale modulare Struktur; Shell & Docs CI; UV-Frozen-Sync in CI; guard-Checks; Runbook-Stub.
```

### 📄 CONTRIBUTING.md

**Größe:** 2 KB | **md5:** `9575003f4de752a6859d137b774655cc`

```markdown
# Beitrag zu wgx

**Rahmen:** wgx ist ein Bash-zentriertes Hilfstool für Linux/macOS, Termux, WSL und Codespaces.
Halte Änderungen klein, portabel und mit Tests abgesichert.

## Grundregeln

- **Sprache:** Dokumentation und Hilfetexte auf Deutsch verfassen; Commit-Nachrichten vorzugsweise auf Englisch für Tool-Kompatibilität.
- **Portabilität:** Termux/WSL/Codespaces nicht brechen. Keine GNU-only-Flags ohne Schutz.
- **Sicherheit:** Skripte aktivieren `set -e`/`set -u` und versuchen `pipefail`; wenn die Shell es nicht
  unterstützt, wird ohne weitergelaufen – aber niemals mit stillen Fehlern.
- **Quoting:** Die [Leitlinie: Shell-Quoting](docs/Leitlinie.Quoting.de.md) ist
  verbindlich, Ausnahmen müssen dokumentiert und begründet werden.
- **Hilfe:** Jeder Befehl muss `-h|--help` unterstützen.

## Entwicklungsumgebung

- Nutze den Dev-Container. Er enthält `shellcheck`, `shfmt`, `bats`.
- Lokale Entwicklung außerhalb des Containers: Werkzeuge manuell installieren.

## Lint & Tests

- Format-Check: `shfmt -d`.
- Lint: `shellcheck -f gcc`.
- Tests: Bats-Tests unter `tests/` ablegen und mit `bats -r tests` ausführen.

## Commits & PRs

- Konventioneller Prefix: `feat|fix|docs|refactor|chore(wgx:subcmd): ...`
- PRs fokussiert halten; „Wie getestet“ angeben.

## Definition of Done

- CI grün (`bash_lint_test`).
- Für neue/geänderte Befehle: Hilfetext + Bats-Test vorhanden.

## Lokale Checks (Spiegel der CI)
```bash
bash -n $(git ls-files "*.sh" "*.bash")
shfmt -d $(git ls-files "*.sh" "*.bash")
shellcheck -S style $(git ls-files "*.sh" "*.bash")
bats -r tests
markdownlint $(git ls-files "*.md" "*.mdx")
vale .
```

> Tipp: `pre-commit install` setzt das als Hook vor jeden Commit.
```

### 📄 Justfile

**Größe:** 1 KB | **md5:** `d97fb596e4c9f9a7fd4d2a59bcfeb1ac`

```plaintext
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: devcontainer-check

devcontainer-check:
    .devcontainer/setup.sh check

devcontainer-install:
    .devcontainer/setup.sh install all

METRICS_SCHEMA_URL := "https://raw.githubusercontent.com/heimgewebe/metarepo/contracts-v1/contracts/wgx/metrics.json"

wgx command +args:
    case "$command" in \
      metrics)
        just wgx-metrics {{args}}
        ;;
      *)
        echo "Unbekannter wgx-Befehl: $command" >&2
        exit 1
        ;;
    esac

wgx-metrics subcommand +args:
    case "$subcommand" in \
      snapshot)
        scripts/wgx-metrics-snapshot.sh {{args}}
        ;;
      *)
        echo "Unbekannter wgx metrics-Befehl: $subcommand" >&2
        exit 1
        ;;
    esac

contracts action +args:
    case "$action" in \
      validate)
        npx --yes ajv-cli@5 validate -s "${METRICS_SCHEMA_URL}" -d metrics.json {{args}}
        ;;
      *)
        echo "Unbekannter contracts-Befehl: $action" >&2
        exit 1
        ;;
    esac
```

### 📄 LICENSE

**Größe:** 1 KB | **md5:** `b1badb0d593eb56678704b11a573ddb2`

```plaintext
MIT License

Copyright (c) 2025 weltweberei.org

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

### 📄 README.md

**Größe:** 11 KB | **md5:** `8d5d0df49ae36a6d09ead11412777467`

```markdown
![WGX](https://img.shields.io/badge/wgx-enabled-blue)

# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS). License: MIT; intended for internal use but repository is publicly visible.

## Lizenz & Nutzung

Dieses Repository steht unter der **MIT-Lizenz** (siehe `./LICENSE`).
Die Lizenzdatei bleibt **unverändert**, damit gängige Tools die Lizenz korrekt erkennen.

**Beabsichtigte Nutzung:** WGX ist primär für den internen Einsatz innerhalb der
heimgewebe-Ökosphäre gedacht, das Repository ist jedoch öffentlich sichtbar.
Diese Klarstellung ändert **nicht** die Lizenzrechte, sondern dient nur der
Transparenz bezüglich Support-Erwartungen und Projektfokus.

**Hinweis für Beiträge/Dateiköpfe:** In neuen Dateien bitte nach Möglichkeit den
SPDX-Kurzidentifier verwenden, z. B.:

```
# SPDX-License-Identifier: MIT
```

## Schnellstart

> 📘 **Sprach-Policy:** Neue Beiträge sollen derzeit deutschsprachige, benutzernahe Texte verwenden.
> Details stehen in [docs/Language-Policy.md](docs/Language-Policy.md); eine spätere Umstellung auf Englisch ist dort skizziert.

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

### `wgx clean`

`wgx clean` räumt temporäre Dateien im Workspace auf. Standardmäßig werden nur sichere Caches entfernt (`--safe`). Weitere Modi lassen sich kombinieren:

- `--build` löscht Build-Artefakte wie `dist/`, `build/`, `.venv/`, `.uv/` usw.
- `--git` räumt gemergte Branches sowie Remote-Referenzen auf. Funktioniert nur in einem sauberen Git-Arbeitsverzeichnis.
- `--deep` führt ein destruktives `git clean -xfd` aus und benötigt zusätzlich `--force`. Ein sauberer Git-Tree ist Pflicht.
- `--dry-run` zeigt alle Schritte nur an – ideal, um vor destruktiven Varianten zu prüfen, was passieren würde.

💡 Tipp: `wgx clean --dry-run --git` hilft beim schnellen Check, welche Git-Aufräumarbeiten anstehen. Sobald der Tree sauber ist, kann `wgx clean --git` (oder `--deep --force`) sicher laufen.

Falls ein Befehl unbekannt ist, kannst du die verfügbaren Subcommands auflisten:

```bash
wgx --list 2>/dev/null || wgx commands 2>/dev/null || ls -1 cmd/
```

## WGX Readiness

Der Workflow [`wgx-guard`](.github/workflows/wgx-guard.yml) generiert pro Lauf
eine Readiness-Matrix und veröffentlicht sie als Artefakte (`readiness.json`,
`readiness-table.md`, `readiness-badge.svg`). Die Dateien werden nicht
versioniert, um Git-Lärm zu vermeiden. Du findest sie im neuesten erfolgreichen
CI-Lauf oder lokal nach `./scripts/gen-readiness.sh`; Details stehen in
[docs/readiness.md](docs/readiness.md). Ergänzend erklärt
[docs/audit-ledger.md](docs/audit-ledger.md) die Audit-Logs und Beispiele.

## Entwicklungs-Schnellstart

- In VS Code öffnen → „Reopen in Container“
- CI lokal ausführen (gespiegelt durch GitHub Actions, via `tests/shell_ci.bats` abgesichert):

  ```bash
  bash -n $(git ls-files '*.sh' '*.bash')
  shfmt -d $(git ls-files '*.sh' '*.bash')
  shellcheck -S style $(git ls-files '*.sh' '*.bash')
  bats -r tests
  ```
- Node.js tooling ist nicht erforderlich; npm-/pnpm-Workflows sind deaktiviert, und es existiert kein `package.json` mehr.

- Mehr Hinweise im [Quickstart](docs/quickstart.md).

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

## Dokumentation & Referenzen

- **Runbook (DE/EN):** [docs/Runbook.de.md](docs/Runbook.de.md) mit [englischer Kurzfassung](docs/Runbook.en.md) für internationales Onboarding.
- **Glossar (DE/EN):** [docs/Glossar.de.md](docs/Glossar.de.md) sowie [docs/Glossary.en.md](docs/Glossary.en.md) erklären Schlüsselbegriffe.
- **Befehlsreferenz:** [docs/Command-Reference.de.md](docs/Command-Reference.de.md) listet alle `wgx`-Subcommands samt Optionen.
- **Module & Vorlagen:** [docs/Module-Uebersicht.de.md](docs/Module-Uebersicht.de.md) beschreibt Aufbau und Zweck von `modules/`, `lib/`, `etc/` und `templates/`.

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
- **Fallback**: Falls keine `.wgx/profile.yml` eingecheckt ist, nutzt CI die versionierte `.wgx/profile.example.yml` als Vorlage – sie muss daher im Repository bleiben.
- **Hinweis**: Lokale Profile im Arbeitsbaum sind per `.gitignore` ausgeschlossen. Hinterlegt daher ein Beispielprofil (z.B. `profile.example.yml`) im Repo, wenn die Guard-Jobs ein manifestiertes Profil erwarten.
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
```

### 📄 uv.lock

**Größe:** 96 B | **md5:** `274f9223e08a5aa733e4b7d865f2face`

```plaintext
# Placeholder uv lockfile.
# Generate with `uv sync --frozen` once pyproject.toml is available.
```

### 📄 wgx

**Größe:** 277 B | **md5:** `894519f136d7f76ea167bffe40a8030e`

```plaintext
#!/usr/bin/env bash
set -e
set -u
if ! set -o pipefail 2>/dev/null; then
  if [[ ${WGX_DEBUG:-0} != 0 ]]; then
    echo "wgx wrapper: 'pipefail' wird nicht unterstützt; fahre ohne fort." >&2
  fi
fi
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/cli/wgx" "$@"
```

