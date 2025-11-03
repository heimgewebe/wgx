### 📄 docs/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 docs/ADR-0001__central-cli-contract.de.md

**Größe:** 2 KB | **md5:** `d314d8eb7ce8f693bc874ea680b879a8`

```markdown
# ADR-0001: Zentrales CLI-Contract

> Englische Version: [ADR-0001__central-cli-contract.en.md](ADR-0001__central-cli-contract.en.md)

## Status

Akzeptiert

## Kontext

Die wgx-Toolchain unterstützt mehrere Projekte und Arbeitsplätze. Bisher existierten unterschiedliche Varianten des
CLI-Vertrags (Command Line Interface Contract) in einzelnen Repositories, was zu inkonsistentem Verhalten und
wiederholtem Abstimmungsaufwand führte. Neue Funktionen mussten mehrfach dokumentiert und abgestimmt werden, und
automatisierte Tests konnten nicht zuverlässig wiederverwendet werden. Darüber hinaus nutzen Mitarbeiter verschiedene
Entwicklungsumgebungen (Termux, VS Code Remote, klassische Linux-Setups), wodurch Abweichungen in der CLI-Konfiguration
schnell zu Fehlern führen.

## Entscheidung

Wir etablieren einen zentral gepflegten CLI-Contract innerhalb von wgx. Der Contract wird in `docs` versioniert,
beschreibt erwartete Befehle, Konfigurationsdateien (z. B. `profile.yml`) und deren Schnittstellen, und dient als
Referenz für alle abhängigen Projekte. Änderungen am Contract erfolgen über Pull Requests inklusive ADR-Aktualisierung,
wodurch Transparenz und Nachvollziehbarkeit gewährleistet werden.

## Konsequenzen

- Einheitliches Verhalten: Alle Projekte orientieren sich am selben Contract und können kompatible Tooling-Skripte
  bereitstellen.
- Geringerer Abstimmungsaufwand: Dokumentation, Tests und Runbooks müssen nur einmal gepflegt werden.
- Schnellere Onboarding-Prozesse: Neue Teammitglieder erhalten eine zentrale Referenz.
- Höhere Wartbarkeit: Inkompatible Änderungen werden frühzeitig erkannt, weil sie über den zentralen Contract
  abgestimmt werden müssen.

## Offene Fragen

- Wie werden ältere Projekte migriert, die noch eigene CLI-Definitionen haben?
- Welche automatisierten Validierungen sollen beim Ändern des Contracts verpflichtend sein?
```

### 📄 docs/ADR-0002__python-env-manager-uv.de.md

**Größe:** 2 KB | **md5:** `4d448ba977e204c71386ce61d1c75a38`

```markdown
# ADR-0002: Python-Umgebungen mit uv verwalten

## Status

Akzeptiert

## Kontext

- wgx bedient heterogene Zielumgebungen (Termux, Codespaces, klassische Linux-Hosts).
- Bisher wurden Python-Setups mit einer Kombination aus `pyenv`, `pip`, `pip-tools`, `venv` und `pipx` orchestriert.
- Die Vielzahl an Tools erzeugt lange Installationszeiten und erhöht den Pflegeaufwand (Updates, Caches, Pfade).
- Projekte benötigen reproduzierbare Python-Installationen inklusive Lockfiles für CI/CD.

## Entscheidung

Wir setzen [uv](https://docs.astral.sh/uv/) als standardmäßigen Python-Manager für wgx ein. uv liefert:

- Verwaltung passender Python-Versionen (on demand, ohne separates `pyenv`).
- Projektverwaltung inklusive `pyproject.toml`, Locking (`uv.lock`) und deterministischem `uv sync`.
- Tool-Installation via `uv tool install`, womit `pipx` entfällt.
- Sehr schnelle Installationszeiten dank nativer Builds und globalem Cache.

wgx bietet dafür Wrapper-Kommandos (`wgx py up`, `wgx py sync`, `wgx py run`, `wgx tool add`). Repository-Profile können per `.wgx/profile.yml` alternative Manager deklarieren, fallen aber standardmäßig auf uv zurück.

## Konsequenzen

- Reproduzierbare Umgebungen: `uv.lock` ist verpflichtender Bestandteil im Versionskontrollsystem.
- CI-Pipelines installieren uv einmalig und verwenden `uv sync --frozen` plus `uv run` für Testläufe.
- Entwickler:innen benötigen nur ein Binary; Startzeiten in Devcontainern/Termux sinken erheblich.
- Bestehende Workflows mit `requirements.txt` können schrittweise migriert werden (`uv pip sync`, `uv pip compile`).

## Risiken / Mitigations

- **Disziplin beim Lockfile**: Änderungen müssen via `wgx py sync` und committedem `uv.lock` erfolgen. wgx-Contracts prüfen dies.
- **Koexistenz mit Legacy-Tools**: uv überschreibt keine Fremdinstallationen ohne `--force`. Dokumentation weist auf uv als Owner hin.
- **Schulungsbedarf**: Kurzreferenzen in README/Runbook erläutern neue Kommandos und Migrationspfade.
```

### 📄 docs/Command-Reference.de.md

**Größe:** 9 KB | **md5:** `f1ccd704b80a4760f333868f4c61b604`

```markdown
# Befehlsreferenz für `wgx`

Diese Übersicht fasst die wichtigsten Subcommands zusammen, inklusive Zweck und zentraler Optionen. Die Beschreibungen basieren auf dem aktuellen Stand der Skripte unter `cmd/` sowie den portierten Funktionen aus `archiv/wgx`.

> ⚠️ **Umbau-Hinweis:** Einige Kommandos – insbesondere `wgx quick`, `wgx hooks` sowie der `wgx version`/`wgx release`-Pfad – befinden sich in aktiver Überarbeitung. Sie sind funktional, können aber kurzfristig Breaking Changes oder erweiterte Optionen erhalten. Kennzeichnungen erfolgen in den jeweiligen Abschnitten.

## Schnellüberblick

| Kommando | Kurzbeschreibung |
| --- | --- |
| `wgx status` | Zeigt Branch, Ahead/Behind sowie erkannte Projektpfade an. |
| `wgx sync` | Staged/committet Änderungen, führt Rebase & Push aus. |
| `wgx send` | Erstellt PR/MR nach Guard-Checks und Sync. |
| `wgx guard` | Führt Sicherheitsprüfungen (Secrets, Lint, Tests) aus. |
| `wgx heal` | Räumt Rebase-/Merge-Konflikte auf oder holt Updates nach. |
| `wgx clean` | Bereinigt Workspace, Build-Artefakte und ggf. Git-Branches. |
| `wgx doctor` | Diagnostik (Status, Tools, optional Clean/Heal-Abkürzungen). |
| `wgx lint` / `wgx test` | Lint- bzw. Test-Läufe für alle erkannten Teilprojekte. |
| `wgx start` | Legt Feature-Branches nach Naming-Guard an. |
| `wgx release` / `wgx version` | Versionierung und Release-Automation *(Umbau, Funktionsumfang variiert)*. |
| `wgx env doctor` | Plattformabhängiger Umgebungscheck (Termux-Fokus). |
| `wgx quick` | Pipeline aus Guard → Sync → PR/MR inklusive CI-Trigger *(Preview)*. |
| `wgx task(s)` | Liest Tasks aus `.wgx/profile.yml` und führt sie aus. |
| `wgx config` | Zeigt bzw. setzt Werte in `.wgx.conf`. |
| `wgx selftest` | Verifiziert Basisfunktionalität des CLI. |

## Detailbeschreibungen

### `wgx status`
- **Zweck:** Kompakter Snapshot von Branch, Ahead/Behind zum Basis-Branch, erkannte Web/API-Verzeichnisse und globale Flags.
- **Besonderheiten:** Funktioniert auch außerhalb von Git-Repositories und markiert Offline-Modus.

### `wgx sync`
- **Zweck:** Bündelt Commit, optionales Signieren, Rebase auf `origin/$WGX_BASE` und Push.
- **Wichtige Optionen:**
  - `--staged-only` lässt unstaged Dateien unangetastet.
  - `--wip` kennzeichnet Commits mit einem WIP-Präfix.
  - `--amend` hängt an den letzten Commit an.
  - `--scope <name>` setzt den Prefix im Commit-Subject; Standard ist Auto-Erkennung.
  - `--sign` erzwingt signierte Commits.
- **Hinweise:** Offline-Modus überspringt Remote-Operationen und verweist auf `wgx heal`.

### `wgx send`
- **Zweck:** Erstellt Pull/Merge Requests inklusive Body-Rendering und Reviewer-/Label-Logik.
- **Wichtige Optionen:**
  - `--draft` oder automatische Draft-Umschaltung bei Guard-Warnungen.
  - `--scope`, `--title`, `--why`, `--tests`, `--notes` für den PR-Body.
  - `--reviewers auto|foo,bar`, `--label`, `--issue`/`--issues` für Metadaten.
  - `--ci` triggert optionale Workflows (`$WGX_CI_WORKFLOW`).
  - `--open` öffnet den PR/MR im Browser.
  - `--auto-branch` legt bei Bedarf einen Arbeits-Branch auf Basis von `wgx start` an.
- **Besonderheiten:** Erzwingt vorher `wgx guard` und `wgx sync`; unterstützt GitHub (`gh`) und GitLab (`glab`).

### `wgx guard`
- **Zweck:** Sicherheitsnetz vor PRs: sucht nach Secrets, Konfliktmarkern, übergroßen Dateien und prüft Pflichtartefakte.
- **Wichtige Optionen:**
  - `--lint` bzw. `--test` lassen sich einzeln aktivieren; Standard ist beides.
- **Besonderheiten:** Ruft `wgx lint`/`wgx test` nur auf, wenn die Kommandos verfügbar sind.

### `wgx heal`
- **Zweck:** Konfliktlösung oder Rebase-/Merge-Helfer nach fehlgeschlagenem Sync.
- **Wichtige Modi:**
  - Standard/Rebase (ohne Argument) zieht `origin/$WGX_BASE` neu.
  - `ours`, `theirs`, `ff-only` bieten alternative Merge-Strategien.
  - `--continue`/`--abort` steuern laufende Rebase-/Merge-Sessions.
  - `--stash` erstellt vorab ein Snapshot/Stash.

### `wgx reload`
- **Zweck:** Startet eine neue Login-Shell im aktuellen oder im Repo-Root-Kontext.
- **Wichtige Optionen:**
  - `here` (Standard) ersetzt die aktuelle Shell.
  - `root` wechselt ins Repo-Root und startet dort.
  - `new` öffnet eine neue Shell (optional `--tmux`).

### `wgx clean`
- **Zweck:** Entfernt Build- und Cache-Artefakte sowie (optional) gemergte Branches.
- **Wichtige Optionen:**
  - `--safe` (Default) löscht ungefährliche Caches.
  - `--build` räumt Build-Verzeichnisse.
  - `--git` löscht gemergte Branches und pruned Remotes.
  - `--deep` kombiniert `git clean -xfd` (mit Rückfrage, Snapshot-Empfehlung).

### `wgx doctor`
- **Zweck:** Diagnostik-Panel mit Branch-/Tool-Informationen.
- **Unterbefehle:**
  - `clean` zeigt `wgx clean` im Dry-Run und fragt nach Bestätigung.
  - `heal` führt direkt `wgx heal rebase` aus.
- **Ausgabe:** listet u. a. Vale/GitHub/GitLab/Node/Cargo-Versionen, erkennt Offline-Modus.

### `wgx init`
- **Zweck:** Legt `.wgx.conf` sowie PR-Template unter `.wgx/` an, falls fehlend.
- **Besonderheiten:** Verwendet aktuelle Defaults aus den Umgebungseinstellungen.

### `wgx setup`
- **Zweck:** Hilft bei der Erstinstallation – insbesondere unter Termux.
- **Verhalten:** Installiert/prüft Kernpakete (git, gh, glab, jq, vale …) und weist auf fehlende Tools hin; außerhalb Termux dient der Befehl als Checkliste.

### `wgx lint`
- **Zweck:** Aggregiertes Linting für Markdown, Vale, Frontend (Prettier/ESLint), Rust, Shell, Dockerfiles und GitHub Actions.
- **Besonderheiten:** Erkennt Paketmanager automatisch, versucht Offline-Fallbacks, kennzeichnet fehlende Tools als Warnungen.

### `wgx test`
- **Zweck:** Führt parallele Web-Tests (npm/pnpm/yarn) und Rust-Tests (`cargo test`) aus, sofern Verzeichnisse erkannt werden.
- **Hinweis:** Aggregiert Exit-Codes und meldet getrennt Web-/Rust-Fehler.

### `wgx start`
- **Zweck:** Erstellt neue Feature-Branches nach validiertem Slug, optional mit Issue-Präfix.
- **Besonderheiten:** Normalisiert Sonderzeichen, schützt gegen Base-Branch-Missbrauch und fetches vorher den Basisbranch (sofern nicht offline).

### `wgx release`
> **Status:** Funktionsumfang wird aktuell neu strukturiert (Release-Workflows sind im Aufbau).
- **Zweck:** Erstellt SemVer-Tags und (optional) Releases auf GitHub/GitLab.
- **Wichtige Optionen:**
  - `--version vX.Y.Z` oder `--auto-version patch|minor|major` (SemVer-Bump).
  - `--push`, `--sign-tag`, `--latest`, `--allow-prerelease` für erweiterten Release-Flow.
  - `--notes <file>` oder automatische Release Notes aus dem Git-Log.

### `wgx version`
> **Status:** Versionierungspipeline im Umbau, CLI-Optionen können sich kurzfristig ändern.
- **Zweck:** Synchronisiert Projektversionen in `package.json` und `Cargo.toml`.
- **Unterbefehle:**
  - `bump patch|minor|major [--commit]`
  - `set vX.Y.Z [--commit]`
- **Besonderheiten:** Nutzt `jq` bzw. `cargo set-version` wenn verfügbar, fallback auf sed/awk.

### `wgx hooks`
> **Status:** Erweiterte Subcommands sind geplant; derzeit nur Installation verfügbar.
- **Zweck:** Installiert lokale Git-Hooks via `cli/wgx/install.sh`.
- **Unterbefehl:** `install` (weitere Subcommands sind aktuell nicht implementiert).

### `wgx env doctor`
- **Zweck:** Prüft Umgebungen, insbesondere Termux, auf notwendige Pakete.
- **Optionen:**
  - `--fix` schlägt Termux-spezifische Remediations (Storage, Paketinstallation, `core.filemode`) vor.
- **Generic Mode:** Auf Desktop-Systemen erfolgt eine reine Statusausgabe ohne Fixes.

### `wgx quick`
> **Status:** Preview-Flow, Änderungen an Flags und Ablauffolge möglich.
- **Zweck:** End-to-End-Automation für „Guard → Sync → PR/MR → CI“.
- **Optionen:**
  - `-i`/`--interactive` öffnet den PR-Body im Editor.
- **Besonderheit:** Wandelt Warnungen automatisch in Draft-PRs um.

### `wgx task`
- **Zweck:** Führt einen Task aus `.wgx/profile.yml` aus.
- **Benutzung:** `wgx task <name> [--] [args…]`; benötigt ein geladenes Profil.
- **Manifest:** `tasks.<name>.cmd` kann als Shell-String oder als Array angegeben werden. String-Varianten
  werden unverändert übergeben; optionale `args`-Einträge werden separat gequotet angehängt.
  Array-Kommandos bleiben Listen und werden inklusive `args` als JSON-Payload ausgegeben.

### `wgx tasks`
- **Zweck:** Listet Tasks aus dem Profil.
- **Optionen:**
  - `--json` liefert maschinenlesbare Ausgabe.
  - `--safe` filtert auf Tasks mit `safe: true`.
  - `--groups` gruppiert nach `group`-Metadaten.

### `wgx config`
- **Zweck:** Zeigt oder setzt Schlüssel in `.wgx.conf`.
- **Benutzung:**
  - `wgx config`/`wgx config show` → aktuelle Werte.
  - `wgx config set KEY=VALUE` → persistiert Wert mit sed-basiertem Update.

### `wgx selftest`
- **Zweck:** Mini-Sanity-Check für CLI, Abhängigkeiten und Git-Kontext.
- **Prüft:** Ausführbarkeit von `wgx`, `git`, `jq` usw., sowie das Vorhandensein eines Git-Repos.
```

### 📄 docs/Glossar.de.md

**Größe:** 712 B | **md5:** `54f0588fecc694d2fdc2cf93523202f9`

```markdown
# Glossar

> Englische Version: [Glossary.en.md](Glossary.en.md)

## wgx
Interne Toolchain und Sammel-Repository, das Build-Skripte, Templates und Dokumentation für verbundene Projekte bereitstellt.

## `profile.yml`
Zentrale Konfigurationsdatei, mit der lokale Profile (z. B. für Dev, CI oder spezielle Kunden) gesteuert werden. Sie definiert CLI-Parameter, Umgebungsvariablen und Pfade und dient als Bindeglied zwischen zentralem Contract und projektspezifischen Einstellungen.

## Contract (CLI-Contract)
Vereinbarung über Befehle, Optionen, Dateistrukturen und Seiteneffekte des wgx-CLI. Er legt fest, welche Schnittstellen stabil bleiben müssen, damit abhängige Projekte konsistent arbeiten können.
```

### 📄 docs/Glossary.en.md

**Größe:** 1 KB | **md5:** `0e59f7103d87d0ad7ed5912d978fde16`

```markdown
# Glossary

> Deutsche Version: [Glossar.de.md](Glossar.de.md)

## wgx
Internal toolchain and umbrella repository that delivers build scripts, templates and documentation for the connected projects.

## `profile.yml`
Central configuration file that controls local profiles (e.g. Dev, CI or customer specific setups). It defines CLI parameters, environment variables and paths and therefore ties the central contract to project specific settings.

## Contract (CLI contract)
Agreement about commands, options, directory structures and side effects of the wgx CLI. It defines which interfaces must remain stable so that downstream projects continue to operate consistently.

## Guard checklist
Set of minimal repository requirements (e.g. committed `uv.lock`, presence of `templates/profile.template.yml`, CI workflows) that `wgx guard` verifies before automation tasks are allowed to proceed.

## `wgx send`
High level command that prepares and submits pull or merge requests. It enforces guard checks, pushes the current branch and triggers the appropriate hosting CLI (`gh` or `glab`).
```

### 📄 docs/Language-Policy.md

**Größe:** 2 KB | **md5:** `f57d473c3cba8d169257961c97eb9a58`

```markdown
# Sprach-Policy

Dieses Repository nutzt aktuell **Deutsch** als bevorzugte Sprache für neu hinzukommende
benutzernahe Texte, Dokumentation und Code-Kommentare. Bereits vorhandene Inhalte
in Englisch dürfen bestehen bleiben. Das Team plant mittelfristig eine Umstellung auf
Englisch; bis dahin soll eine konsistente deutschsprachige Oberfläche Reibungen in PR-
Reviews vermeiden.

## Leitlinien

- **Neuer Inhalt**: Verfasse neue Benutzertexte und Dokumentation auf Deutsch. Nutze eine
  klare, gut verständliche Sprache und verzichte auf unnötige Anglizismen.
- **Bestehende englische Passagen**: Lass englische Stellen unverändert, sofern sie nicht
  unmittelbar von deiner Änderung betroffen sind. Falls du sie ohnehin anfasst, darfst du
  sie auf Deutsch übertragen.
- **CLI-Ausgaben & Skripte**: Richte neue Meldungen auf Deutsch aus. Bei bestehenden
  englischen Meldungen gilt die gleiche Regel wie oben: nur bei inhaltlichen Änderungen
  eindeutschen.
- **Commits & PRs**: Verwende nach Möglichkeit ebenfalls Deutsch. Stimmen alle Beteiligten
  zu, kann die Kommunikation für einzelne Beiträge auf Englisch erfolgen.

**Hinweis:** Gender-Schreibweisen (z. B. Doppelpunkt, Stern, Binnen-I) sind im gesamten
Repository nicht erlaubt. Nutze stattdessen die klassische Rechtschreibung.

## Übergang zur zukünftigen Englisch-Policy

Damit die spätere Migration zurück zu Englisch planbar bleibt, dokumentiere größere
Änderungen weiterhin so, dass sie leicht übersetzbar sind (z. B. klare Struktur,
sprechende Variablen). Sobald die Umstellung startet, wird diese Policy entsprechend
aktualisiert und vorhandene Texte sukzessive migriert.
```

### 📄 docs/Leitlinie.Quoting.de.md

**Größe:** 2 KB | **md5:** `38cffcd1d926aac0dee70c60c622906e`

```markdown
# Leitlinie: Shell-Quoting

Diese Leitlinie definiert einen verpflichtenden Grundstock für sicheres
Quoting in allen Bash-Skripten des Repositories. Sie ergänzt ShellCheck und
shfmt, ersetzt sie aber nicht.

## Zielsetzung

- **Vermeidung von Word-Splitting und Globbing:** Unkontrollierte
  Parameter-Expansion darf keine zusätzlichen Argumente erzeugen.
- **Stabile Übergabe von Daten:** Ausgaben von Subkommandos werden immer als
  ganze Zeichenketten übergeben.
- **Reproduzierbare Linter-Ergebnisse:** ShellCheck bleibt Referenz für neue
  Regeln; diese Leitlinie legt das Minimum fest, bevor ShellCheck greift.

## Baseline-Regeln

1. **Alle Variablen-Expansions quoten** – selbst bei offensichtlichen Fällen.
   ```bash
   printf '%s\n' "${repo_root}"
   mapfile -t lines < <(git status --short)
   ```
2. **Arrays immer mit `[@]` und Quotes verwenden.**
   ```bash
   for path in "${files[@]}"; do
     printf '→ %s\n' "$path"
   done
   ```
3. **Command-Substitutions sofort quoten.**
   ```bash
   latest_tag="$(git describe --tags --abbrev=0)"
   ```
4. **`printf` statt `echo` für kontrollierte Ausgaben nutzen.** So bleiben
   Backslashes, führende Bindestriche oder `-n` wörtlich erhalten.
5. **`read` nur mit `-r` verwenden.** Damit werden Backslashes nicht
   interpretiert:
   ```bash
   while IFS= read -r line; do
     printf '%s\n' "$line"
   done <"$file"
   ```
6. **Pfadangaben vor Globbing schützen.** Vor dem Gebrauch `set -f` bzw.
   `noglob` oder frühzeitig quoten:
   ```bash
   cp -- "$src" "$dst"
   ```
7. **Keine nackten `eval`-Aufrufe.** Falls unvermeidbar: dokumentieren,
   Eingabe vorher streng validieren.

## Überprüfung

- ShellCheck muss ohne Ignorieren von Quoting-Warnungen (`SC2086`, `SC2046`,
  `SC2016`, …) bestehen.
- shfmt darf keine Änderungen an bereits formatierten Quoting-Blöcken vornehmen.
- Neue Shell-Komponenten liefern einen kurzen Selfcheck (`wgx lint`) vor dem
  Commit.

## Quick-Check

Vor jedem Commit folgende Fragen beantworten:

- Sind alle Expansions (Variablen, Command-Substitutions, Pfade) gequotet?
- Wird beim Iterieren über Arrays `"${array[@]}"` benutzt?
- Besteht `wgx lint` ohne neue ShellCheck-Ausnahmen?

Wenn eine dieser Fragen mit „nein“ beantwortet wird, muss der Code nachgebessert
werden.
```

### 📄 docs/Module-Uebersicht.de.md

**Größe:** 2 KB | **md5:** `f2510e4c1e4f2b63ef52f8b28b05b120`

```markdown
# Module & Hilfsbibliotheken

Kurze Übersicht über die wichtigsten Dateien in `modules/`, `lib/`, `etc/` und `templates/`, damit Beitragende schneller die richtigen Einstiegspunkte finden.

## `modules/`

| Datei | Zweck |
| --- | --- |
| `modules/doctor.bash` | Enthält den Minimal-Doctor (Repo-Prüfung, Remote-Checks). Wird aktuell vom Legacy-Monolithen gerufen. |
| `modules/env.bash` | Neues Environment-Modul mit JSON/strict-Ausgaben sowie Termux-Fixups. Setzt `env_cmd` für `wgx env`. |
| `modules/guard.bash` | Port der Guard-Pipeline (Secrets, Konflikte, Pflichtdateien, optional Lint/Test). Wird von `wgx guard` sowie `wgx send`/`wgx quick` verwendet. |
| `modules/json.bash` | Hilfsfunktionen für JSON-Ausgabe (u. a. von Profil-/Task-Befehlen). |
| `modules/profile.bash` | Lädt `.wgx/profile.yml`, normalisiert Task-Namen und führt Task-Skripte aus. Grundlage für `wgx task`/`wgx tasks`. |
| `modules/semver.bash` | SemVer-Bump-Logik (Bump/Set, Tag-Parsing) für `wgx version` & `wgx release`. |
| `modules/status.bash` | Liefert Status-Zusammenfassungen, z. B. Ahead/Behind und Pfad-Erkennung. Wird von `wgx status` genutzt. |
| `modules/sync.bash` | Implementiert `sync_cmd` inklusive Commit-, Rebase- und Push-Flows. |

## `lib/`

| Datei | Zweck |
| --- | --- |
| `lib/core.bash` | Allgemeine Hilfsfunktionen (Logging, Fehlerbehandlung, Pfadauflösung, Snapshot-Logik), die von mehreren Kommandos shared werden. |

## `etc/`

| Datei | Zweck |
| --- | --- |
| `etc/config.example` | Default-Konfiguration, die `wgx init` nach `~/.config/wgx/config` kopiert. Dient als Vorlage für neue Installationen. |
| `etc/profile.example.yml` | Referenz-Profil für Projekte; dokumentiert unterstützte Sektionen (`python`, `contracts`, `tasks`). |

## `templates/`

| Datei | Zweck |
| --- | --- |
| `templates/profile.template.yml` | Minimal-Template, das Projekte in ihre Repositories kopieren sollen. Wird vom Guard als Muss-Kriterium geprüft. |
| `templates/docs/` | Ergänzende Dokumentations-Vorlagen (z. B. für ADRs). |

## Verwandte Artefakte

- `docs/Runbook.*` & `docs/Glossar.*` dienen als Einstiegspunkte für Onboarding und Terminologie (jetzt zweisprachig verfügbar).
- `docs/Command-Reference.de.md` (neu) listet alle Kommandos samt Optionen auf.

Diese Übersicht soll als Navigationshilfe dienen; Detailverhalten findet sich jeweils in den Quellskripten oder in der Befehlsreferenz.
```

### 📄 docs/Runbook.de.md

**Größe:** 4 KB | **md5:** `9a35d64b77627abc8cf384fcc2780f9f`

```markdown
# Runbook: wgx CLI

> Englische Version: [Runbook.en.md](Runbook.en.md)

## Quick-Links

- Contract-Kompatibilität prüfen: `wgx validate`
- Linting ausführen (auch für Git-Hooks): `wgx lint`
- Umgebung diagnostizieren: `wgx doctor`

## Häufige Fehler und Lösungen

### `profile.yml` wird nicht gefunden

- Prüfen, ob das Arbeitsverzeichnis korrekt gesetzt ist (z. B. Projektwurzel).
- Mit `wgx profile list` sicherstellen, dass das Profil geladen werden kann.
- Falls mehrere Profile vorhanden sind, den Pfad per `WGX_PROFILE_PATH` explizit setzen.

### `wgx`-Befehl schlägt mit Python-Fehlern fehl

- `wgx py up` ausführen, damit uv die im Profil hinterlegte Python-Version bereitstellt.
- `wgx py sync` starten, um Abhängigkeiten anhand des `uv.lock`-Files konsistent zu installieren.
- Falls ein Repository noch kein Lockfile besitzt, `uv pip sync requirements.txt` verwenden und anschließend `wgx py sync` etablieren.
- Bei globaler Installation prüfen, ob Version mit zentralem Contract kompatibel ist.

### `sudo apt-get update -y` schlägt mit „unsigned/403 responses" fehl

- Tritt häufig in abgeschotteten Netzen oder nach dem Hinzufügen externer Repositories auf. Prüfe zunächst die Systemzeit und ob ein Proxy/TLS-Intercepter im Einsatz ist (`echo $https_proxy`).
- Alte Paketlisten entfernen und neu herunterladen:

  ```bash
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get clean
  sudo apt-get update
  ```

- Für zusätzliche Repositories sicherstellen, dass der passende Signatur-Schlüssel hinterlegt ist (statt `apt-key` den neuen Keyring-Weg nutzen):

  ```bash
  # Beispiel: Docker-Repository hinzufügen
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update
  # Ersetze ggf. 'docker', die URL, 'jammy' (Distribution) und 'stable' (Komponenten) entsprechend deiner Quelle.
  ```

- Bleibt der Fehler bestehen, das Log (`/var/log/apt/term.log`) prüfen. Bei 403-Antworten hilft oft ein Mirror-Wechsel oder das Entfernen veralteter Einträge in `/etc/apt/sources.list.d/`.

### Git-Hooks blockieren Commits

- `wgx lint` manuell ausführen, um Fehler zu sehen.
- Falls Hook veraltet ist, Repository aktualisieren und `wgx setup` erneut laufen lassen.

## Tipps für Termux

- Termux-Repo aktualisieren (`pkg update`), bevor Python/Node installiert wird.
- Essentials installieren: `pkg install jq git python`.
- `uv` als Single-Binary in `$HOME/.local/bin` installieren:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
  . ~/.profile
  ```

- Danach `wgx py up` ausführen – uv verwaltet Python-Versionen und virtuelle Umgebungen ohne zusätzliche Tools.
- Speicherzugriff auf das Projektverzeichnis gewähren (`termux-setup-storage`).

## Leitfaden: Von `requirements.txt` zu uv

1. Vorhandene Abhängigkeiten synchronisieren:

   ```bash
   uv pip sync requirements.txt
   ```

2. Projektmetadaten definieren (`pyproject.toml`), sofern noch nicht vorhanden.
3. Lockfile erzeugen und ins Repository aufnehmen:

   ```bash
   uv lock
   git add uv.lock
   ```

4. Für CI und lokale Entwickler `wgx py sync` dokumentieren; im Fehlerfall `uv sync --frozen` nutzen.
5. Optional weiterhin Artefakte exportieren (`uv pip compile --output-file requirements.txt`).

## CI mit uv (Kurzüberblick)

- uv installieren (z. B. per `curl -LsSf https://astral.sh/uv/install.sh | sh`).
- Globalen Cache cachen: `~/.cache/uv` mit einem Key aus uv-Version (`uv --version | awk '{print $2}'`) sowie `pyproject.toml` + `uv.lock`.
- Abhängigkeiten strikt via `uv sync --frozen` installieren.
- Tests mit `uv run …` starten (z. B. `uv run pytest -q`).

## Tipps für VS Code (Remote / Dev Containers)

- Die `profile.yml` als Workspace-File markieren, damit Änderungen synchronisiert werden.
- Aufgaben (`wgx`-Tasks) als VS Code Tasks integrieren, um Befehle mit einem Klick zu starten.
- Bei Dev Containers sicherstellen, dass das Volume die `~/.wgx`-Konfiguration persistiert, z. B.:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.wgx,target=/home/vscode/.wgx,type=bind,consistency=cached"
  ]
}
```
- Nutze `.devcontainer/setup.sh ensure-uv`, damit uv nach dem Container-Start verfügbar ist (inklusive PATH-Anpassung).
```

### 📄 docs/Runbook.en.md

**Größe:** 4 KB | **md5:** `87acec2050c41e882bbbc6389a87fe78`

```markdown
# Runbook: wgx CLI (English Edition)

> Deutsche Version: [Runbook.de.md](Runbook.de.md)

## Quick Links

- Validate CLI contract compliance: `wgx validate`
- Run linting (also used by Git hooks): `wgx lint`
- Diagnose the local environment: `wgx doctor`

## Common issues and remedies

### `profile.yml` cannot be located

- Make sure you execute the command from the project root (or the directory that contains the profile).
- Use `wgx profile list` to verify that the profile is discoverable.
- When multiple profiles exist, set an explicit path via `WGX_PROFILE_PATH`.

### `wgx` aborts with Python related errors

- Execute `wgx py up` so that uv installs the Python version that is declared in the profile.
- Follow up with `wgx py sync` to install dependencies based on `uv.lock`.
- Repositories without a lockfile can migrate by running `uv pip sync requirements.txt` and establishing `wgx py sync` afterwards.
- Global or system wide installs should be checked for contract compatibility.

### `sudo apt-get update -y` fails with “unsigned/403 responses”

- This often happens in locked down networks or after adding external repositories. Confirm that the system clock is correct and whether a proxy/TLS interceptor is used (`echo $https_proxy`).
- Remove cached package lists before retrying:

  ```bash
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get clean
  sudo apt-get update
  ```

- Ensure that any additional repository ships the proper signing key (prefer the keyring workflow over `apt-key`):

  ```bash
  # Example: adding the Docker repository on Ubuntu Jammy
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update
  # Adjust the repository URL, distribution ("jammy") and components ("stable") to your target platform.
  ```

- If the problem persists, inspect `/var/log/apt/term.log`. HTTP 403 responses are often resolved by switching mirrors or by pruning stale entries in `/etc/apt/sources.list.d/`.

### Git hooks block commits

- Run `wgx lint` manually to see the failures.
- If a hook is outdated, update the repository and re-run `wgx setup`.

## Tips for Termux

- Update the Termux package registry (`pkg update`) before installing Python/Node.
- Install core dependencies: `pkg install jq git python`.
- Install `uv` as a single binary under `$HOME/.local/bin`:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
  . ~/.profile
  ```

- Afterwards run `wgx py up` – uv manages Python versions and virtual environments without additional tools.
- Grant storage access to the project directory (`termux-setup-storage`).

## Migration guide: from `requirements.txt` to uv

1. Synchronise the existing dependencies:

   ```bash
   uv pip sync requirements.txt
   ```

2. Define project metadata in `pyproject.toml` if it does not exist yet.
3. Create a lockfile and add it to version control:

   ```bash
   uv lock
   git add uv.lock
   ```

4. Document `wgx py sync` for CI and local developers; in case of failures fall back to `uv sync --frozen`.
5. Optionally export compatibility artefacts (`uv pip compile --output-file requirements.txt`).

## CI with uv (quick reference)

- Install uv (e.g. `curl -LsSf https://astral.sh/uv/install.sh | sh`).
- Cache the global uv cache: `~/.cache/uv` with a key derived from the uv version (`uv --version | awk '{print $2}'`) plus `pyproject.toml` and `uv.lock`.
- Install dependencies strictly via `uv sync --frozen`.
- Execute tests with `uv run …` (e.g. `uv run pytest -q`).

## Tips for VS Code (Remote / Dev Containers)

- Mark `profile.yml` as a workspace file so that changes sync correctly.
- Expose `wgx` tasks as VS Code tasks to make the commands discoverable from the UI.
- Persist the `~/.wgx` configuration when using Dev Containers, e.g.:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.wgx,target=/home/vscode/.wgx,type=bind,consistency=cached"
  ]
}
```

- Use `.devcontainer/setup.sh ensure-uv` to guarantee that uv is available (including PATH adjustments) after the container starts.
```

### 📄 docs/Runbook.md

**Größe:** 589 B | **md5:** `fbb1f67a83985f30f233774081c54515`

```markdown
# WGX Runbook (Kurzfassung)

## Erstlauf
1. `wgx doctor` ausführen → prüft Umgebung (bash, git, shellcheck, shfmt, bats).
2. `wgx init` → legt `~/.config/wgx/config` an (aus `etc/config.example`).
3. `wgx sync` → holt Updates; `wgx send "msg"` → Commit & Push Helper.

## Python (uv)
* `wgx py up` / `wgx py sync --frozen` / `wgx py run <cmd>`

## Guard-Checks (Mindest-Standards)
* `uv.lock` committed
* CI mit shellcheck/shfmt/bats
* Markdownlint + Vale
* templates/profile.template.yml vorhanden

## Troubleshooting
* `wgx selftest` starten; Logs unter `~/.local/state/wgx/`.
```

### 📄 docs/audit-ledger.md

**Größe:** 786 B | **md5:** `d20517eb267e0cf137dd5f960a501b57`

```markdown
# Audit Ledger

`lib/audit.bash` stellt mit `audit::log` und `audit::verify` eine
JSONL-basierte Audit-Kette bereit. Jeder Eintrag enthält UTC-Zeitstempel,
Git-Commit, das Ereignis und optionales Payload-JSON; ein SHA256-Hash schützt
die Verkettung (`prev_hash` → `hash`). Der Befehl `wgx audit verify`
überprüft die Kette und gibt standardmäßig nur Warnungen aus. Mit
`AUDIT_VERIFY_STRICT=1` oder `wgx audit verify --strict` wird ein Fehlerstatus
ausgelöst, wenn die Hash-Kette unterbrochen ist.

Das produktive Ledger lebt unter `.wgx/audit/ledger.jsonl` und wird
automatisch erweitert. Da es sich bei jedem Lauf ändert, ist die Datei von
Git ausgeschlossen. Für Dokumentationszwecke gibt es stattdessen
`docs/audit-ledger.sample.jsonl`, das den Aufbau exemplarisch zeigt.
```

### 📄 docs/audit-ledger.sample.jsonl

**Größe:** 939 B | **md5:** `7d6ace43130a7ad2119e84f9ea8eb4c5`

```plaintext
{"timestamp":"2024-01-01T12:00:00Z","event":"guard_start","git_sha":"0123456789abcdef0123456789abcdef01234567","payload":{"args":["--help"],"phase":"start"},"prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","hash":"d3c8d7cf90be119bb40df6a5b7c11d5a4c6f1aa7da03fbe4b60980b3d3c4a1a0"}
{"timestamp":"2024-01-01T12:00:02Z","event":"guard_finish","git_sha":"0123456789abcdef0123456789abcdef01234567","payload":{"status":"ok","exit_code":0},"prev_hash":"d3c8d7cf90be119bb40df6a5b7c11d5a4c6f1aa7da03fbe4b60980b3d3c4a1a0","hash":"3d3e3a1c27e190aa81a7ed0423161bbd10bfc9972e231e9d86f8a62d0f49ff97"}
{"timestamp":"2024-01-01T12:05:00Z","event":"task_finish","git_sha":"fedcba9876543210fedcba9876543210fedcba98","payload":{"task":"test","status":"error","exit_code":1},"prev_hash":"3d3e3a1c27e190aa81a7ed0423161bbd10bfc9972e231e9d86f8a62d0f49ff97","hash":"4c41a4c9f72367dfefc6c1c9a83063f1ba026af8966a2f7f4eb5b3ddf6e44a35"}
```

### 📄 docs/cli.md

**Größe:** 11 KB | **md5:** `31af02f00311dfdf4655457a9c3fcf88`

```markdown
# wgx CLI Reference

> Generated by `scripts/gen-cli-docs.sh`. Do not edit manually.

## Global usage

```
wgx — Workspace Helper

Usage:
  wgx <command> [args]

Commands:
  audit
  clean
  config
  doctor
  env
  guard
  heal
  help
  hooks
  init
  lint
  quick
  release
  reload
  selftest
  send
  setup
  start
  status
  sync
  task
  tasks
  test
  validate
  version

Env:
  WGX_BASE       Basis-Branch für reload (default: main)

More:
  wgx --list     Nur verfügbare Befehle anzeigen
```

## Commands

### audit

```
Usage:
  wgx audit verify [--strict]

Verwaltet das Audit-Ledger von wgx.
```

### clean

```
Usage:
  wgx clean [--safe] [--build] [--git] [--deep] [--dry-run] [--force]

Options:
  --safe       Entfernt temporäre Cache-Verzeichnisse (Standard).
  --build      Löscht Build-Artefakte (dist, build, target, ...).
  --git        Räumt gemergte Branches und Remote-Referenzen auf (nur sauberer Git-Tree).
  --deep       Führt ein destruktives `git clean -xfd` aus (erfordert --force, nur sauberer Git-Tree).
  --dry-run    Zeigt nur an, was passieren würde.
  --force      Bestätigt destruktive Operationen (für --deep).
```

### config

```
Usage:
  wgx config [show]
  wgx config set <KEY>=<VALUE>

Description:
  Zeigt die aktuelle Konfiguration an oder setzt einen Wert in der
  '.wgx.conf'-Datei.
  Die Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### doctor

```
Usage:
  wgx doctor

Description:
  Führt eine grundlegende Diagnose des Repositorys und der Umgebung durch.
  Prüft, ob 'git' installiert ist, ob der Befehl innerhalb eines Git-Worktrees
  ausgeführt wird und ob ein 'origin'-Remote konfiguriert ist.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### env

```
Usage: wgx env doctor [--fix] [--strict] [--json]
  doctor     Inspect the local environment (default)
  --fix      Apply recommended platform specific tweaks (Termux only)
  --strict   Exit non-zero if essential tools are missing (e.g., git)
  --json     Machine-readable output (minimal JSON)
```

### guard

```
Usage:
  wgx guard [--lint] [--test]

Description:
  Führt eine Reihe von Sicherheits- und Qualitätsprüfungen für das Repository aus.
  Dies ist ein Sicherheitsnetz, das vor dem Erstellen eines Pull Requests ausgeführt wird.
  Standardmäßig werden sowohl Linting als auch Tests ausgeführt.

Checks:
  - Sucht nach potentiellen Secrets im Staging-Bereich.
  - Sucht nach verbleibenden Konfliktmarkern im Code.
  - Prüft auf übergroße Dateien (>= 1MB).
  - Verifiziert das Vorhandensein von wichtigen Repository-Dateien (z.B. uv.lock).
  - Führt 'wgx lint' aus (falls --lint angegeben oder Standard).
  - Führt 'wgx test' aus (falls --test angegeben oder Standard).

Options:
  --lint        Nur die Linting-Prüfungen ausführen.
  --test        Nur die Test-Prüfungen ausführen.
  -h, --help    Diese Hilfe anzeigen.
```

### heal

```
Usage:
  wgx heal [ours|theirs|ff-only|--continue|--abort]

Description:
  Hilft bei der Lösung von Merge- oder Rebase-Konflikten.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Für eine detaillierte Beschreibung der geplanten Funktionalität,
  siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### help

```
wgx — Workspace Helper

Usage:
  wgx <command> [args]

Commands:
  audit
  clean
  config
  doctor
  env
  guard
  heal
  help
  hooks
  init
  lint
  quick
  release
  reload
  selftest
  send
  setup
  start
  status
  sync
  task
  tasks
  test
  validate
  version

Env:
  WGX_BASE       Basis-Branch für reload (default: main)

More:
  wgx --list     Nur verfügbare Befehle anzeigen
```

### hooks

```
Usage:
  wgx hooks [install]

Description:
  Verwaltet die Git-Hooks für das Repository.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.
  Aktuell ist nur die 'install'-Aktion geplant.
  Für Details, siehe 'docs/Command-Reference.de.md'.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### init

```
Usage:
  wgx init [--wizard]

Description:
  Initialisiert die 'wgx'-Konfiguration im Repository. Mit `--wizard` wird
  ein interaktiver Assistent gestartet, der `.wgx/profile.yml` erstellt.

Options:
  --wizard      Interaktiven Profil-Wizard starten.
  -h, --help    Diese Hilfe anzeigen.
```

### lint

```
Usage:
  wgx lint

Description:
  Führt Linting-Prüfungen für verschiedene Dateitypen im Repository aus.
  Dies umfasst Shell-Skripte (Syntax-Prüfung mit bash -n, Formatierung mit shfmt,
  statische Analyse mit shellcheck) und potenziell weitere linter.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### quick

```
Usage: wgx quick [-i|--interactive] [--help]

Run repository guards (lint + tests) and open the PR/MR helper.

Options:
  -i, --interactive  Open the PR body in $EDITOR before sending
  -h, --help         Show this help message
```

### release

```
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
```

### reload

```
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
```

### selftest

```
Usage:
  wgx selftest

Description:
  Führt einen Mini-Sanity-Check für die 'wgx'-CLI und ihre Umgebung durch.
  Prüft, ob 'wgx' ausführbar ist, ob die Version abgerufen werden kann und
  ob kritische Abhängigkeiten wie 'git' und 'jq' verfügbar sind.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### send

```
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
```

### setup

```
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
```

### start

```
Usage:
  wgx start <branch_name>

Description:
  Erstellt einen neuen Feature-Branch nach einem validierten Schema.
  Der Name wird normalisiert (Sonderzeichen entfernt, etc.) und optional
  mit einer Issue-Nummer versehen.
  Die vollständige Implementierung dieses Befehls ist noch in Arbeit.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### status

```
Usage:
  wgx status

Description:
  Zeigt einen kompakten Snapshot des Repository-Status an.
  Dies umfasst den aktuellen Branch, den Ahead/Behind-Status im Vergleich zum
  Upstream-Branch, erkannte Projektverzeichnisse (Web, API, etc.) und
  globale Flags wie den OFFLINE-Modus.

Options:
  -h, --help    Diese Hilfe anzeigen.
```

### sync

```
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
```

### task

```
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
```

### tasks

```
Usage: wgx tasks [--json] [--safe] [--groups]
  --json    Output machine readable JSON
  --safe    Only include tasks marked as safe
  --groups  Include group metadata (JSON) or group headings (text)
```

### test

```
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
```

### validate

```
Usage:
  wgx validate [--json]

Validiert das Manifest (.wgx/profile.*) im aktuellen Repository.
Exit-Status: 0 bei gültigem Manifest, sonst >0.

Optionen:
  --json   Kompakte maschinenlesbare Ausgabe:
           {"ok":bool,"errors":[...],"missingCapabilities":[...]}
```

### version

```
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
```
```

### 📄 docs/quickstart.md

**Größe:** 510 B | **md5:** `755e6b126a33423fdebb7cee9802ffed`

```markdown
# WGX Quickstart Wizard

Die Option `wgx init --wizard` führt Schritt für Schritt durch die Erstellung
eines `.wgx/profile.yml` im Repository. Nach der Auswahl des Repository-Typs
und der gewünschten Standard-Tasks (z. B. `test`, `lint`, `build`) erzeugt der
Wizard ein Profil im Format `apiVersion: v1.1` mit getrennten `cmd`- und
`args`-Feldern. Zum Abschluss wird automatisch `wgx validate` gestartet; bei
Fehlern zeigt der Wizard den Diff zur erzeugten Datei, damit Anpassungen
schnell möglich sind.
```

### 📄 docs/readiness.md

**Größe:** 654 B | **md5:** `dc20d9c7e8a589a3beef31d459f0ddd6`

```markdown
# Readiness Matrix

`scripts/gen-readiness.sh` analysiert die Verzeichnisse `modules/`, `cmd/`,
`tests/` und `docs/` und erzeugt daraus `artifacts/readiness.json`, eine
Markdown-Tabelle sowie ein SVG-Badge. Die JSON-Datei enthält für jedes Modul
den Status (`ready`, `progress`, `partial`, `seed`), die Anzahl vorhandener
Tests/Dokumente sowie einen 0–100 % Score. Wird die Matrix nicht erzeugt
(z. B. in Repos ohne Shell-Module), meldet das Skript nur eine Warnung und
liefert Exit-Code 0, damit CI-Läufe nicht brechen. Die Artefakte werden nicht
eingecheckt, sondern landen als CI-Artefakt bzw. lokal im gitignored
`artifacts/`-Verzeichnis.
```

### 📄 docs/uv-integration-audit.de.md

**Größe:** 3 KB | **md5:** `a477a846012f02ce4af64a3ef16c88f8`

```markdown
# UV-Integration im wgx-Repository – Kurzbewertung

## Aktueller Stand

- Die README bewirbt uv als Standard für Python-Laufzeiten, Lockfiles und Tooling und verweist auf Wrapper-Kommandos wie `wgx py up`, `wgx py sync` sowie `wgx tool add`. Damit werden klare Erwartungen an das CLI kommuniziert.[README.md (L50–L110)](./README.md#L50-L110)
- Das Devcontainer-Skript `.devcontainer/setup.sh` bringt einen automatisierten Installer (`setup.sh ensure-uv`) mit, der uv bei Bedarf nachzieht und `$HOME/.local/bin` dauerhaft in die Shell-Profile schreibt. So steht das Binary in Container-Umgebungen zuverlässig zur Verfügung.【F:.devcontainer/setup.sh†L1-L120】
- `wgx env doctor` überprüft uv neben weiteren Kernwerkzeugen und meldet Verfügbarkeit samt Version. Das erleichtert Fehlersuche auf Entwickler-Systemen.【F:modules/env.bash†L38-L100】
- Der GitHub-Workflow [`wgx-guard`](../.github/workflows/wgx-guard.yml) setzt die in der README erwähnten Verträge technisch durch: Existiert `pyproject.toml`, wird `uv` installiert, `uv.lock` erzwungen und `uv sync --frozen` ausgeführt. Ohne Python-Projekt greifen die Checks nicht – so entstehen keine Fehlalarme.【F:.github/workflows/wgx-guard.yml†L66-L126】【F:README.md†L66-L105】
- Da `$GITHUB_PATH` erst im Folge-Step wirkt, exportiert der Installationsschritt `~/.local/bin` zusätzlich lokal in den PATH. Damit steht `uv` auch im selben Step sicher zur Verfügung.【F:.github/workflows/wgx-guard.yml†L84-L107】
- Runbook und ADR erläutern Migration und Motivation für uv. Sie liefern gute Hintergründe und Migrationspfade von `requirements.txt` zu `uv.lock` sowie Empfehlungen für CI-Pipelines.【F:docs/Runbook.de.md†L21-L109】【F:docs/ADR-0002__python-env-manager-uv.de.md†L1-L36】

## Festgestellte Lücken

- Im `cmd/`-Verzeichnis existiert bislang kein `py.bash` oder `tool.bash`. Die in der README beworbenen Wrapper sind daher noch nicht implementiert und Nutzer:innen müssen uv manuell bedienen.【F:cmd/py.bash†L1-L4】
- Das Template `.wgx/profile.yml` enthält keinen `python`-Block. Neue Repos erhalten somit keine Startkonfiguration für uv-Version, Lockfile-Pflicht oder Tool-Liste, obwohl die Dokumentation dies erwartet.【F:templates/.wgx/profile.yml†L1-L7】

## Potenziale zur Verbesserung

1. **CLI-Kommandos für uv ergänzen**: Ein dediziertes `cmd/py.bash` (und optional `cmd/tool.bash`) sollte die häufigsten uv-Workflows kapseln (`up`, `sync`, `run`, `pip sync`, Tool-Management). Damit erfüllt das CLI die README-Versprechen.
2. **Contracts implementieren**: `wgx guard` sollte Regeln kennen, die `uv.lock` im Repository erzwingen und CI-Skripte auf `uv sync --frozen` prüfen. So wird die dokumentierte Governance technisch abgesichert.
3. **Profile-Template erweitern**: Das Standard-Profil kann einen kommentierten `python`-Block mit uv als Manager, gewünschter Version und Tool-Liste enthalten. Neue Projekte starten dadurch mit konsistenter Basiskonfiguration.
4. **Optionale Ergänzungen**: Beispiele für `pyproject.toml` + `uv.lock` oder ein `uv pip compile`-Howto könnten im Templates-Ordner landen. Das erleichtert Teams den Einstieg in uv-gesteuerte Repos.

Mit diesen Ergänzungen wird die uv-Integration nicht nur dokumentiert, sondern auch durch das CLI und Standardprofile erlebbar. Die vorhandenen Installations- und Diagnose-Hilfen bilden dafür bereits eine solide Grundlage.
```

### 📄 docs/wgx-konzept.md

**Größe:** 624 B | **md5:** `8165cc7a8610d408c20ec1fa548b4542`

```markdown

## Semantische Erweiterungen: semantAH

semantAH ist ein Ableger-Projekt für semantisches Indexing und Wissensgraphen (Text-Embedding, Obsidian-Integration, Graph-Daten, QA-Reports).  
Es ergänzt WGX um eine **Bedeutungsschicht**: Inhalte werden verstanden, geclustert und verknüpft.

- **WGX orchestriert, semantAH denkt.**
- semantAH-Tasks lassen sich via `wgx run index:obsidian` oder `wgx run semantah:qa` starten.
- Ergebnisse von semantAH können in WGX-Flows erscheinen (Evidence-Packs, Shadowmap-Erweiterungen).
- Empfehlung: semantAH in den WGX-Dokumenten als **optionale Schwesterkomponente** aufführen.

---
```

### 📄 docs/wgx-mycelium-v-omega.de.md

**Größe:** 22 KB | **md5:** `0bca8dd338261878873f324c546de7f3`

```markdown
# WGX — Mycelium **v Ω**

Version: vΩ (2025-10-05) · Status-Legende: 🟢 Core · 🟡 Next · 🔬 Experimental

## Inhalt

- [0. Executive Summary (Kurzfassung)](#0-executive-summary-kurzfassung)
- [1. Problem → Prinzipien](#1-problem--prinzipien)
- [2. Bedienkanon (Kern → „Ultra“)](#2-bedienkanon-kern--ultra)
- [3. Erweiterungen (Zutrag-Synthese, neu integriert)](#3-erweiterungen-zutrag-synthese-neu-integriert)
- [4. HausKI-Memory (Gedächtnis-Ops)](#4-hauski-memory-gedächtnis-ops)
- [5. Kommandoreferenz (Index, Status, Nutzen)](#5-kommandoreferenz-index-status-nutzen)
- [6. Profile v1 / v1.1 (Minimal → Reich)](#6-profile-v1--v11-minimal--reich)
- [7. Reproduzierbarkeit & Seeds](#7-reproduzierbarkeit--seeds)
- [8. Sichtbarkeit & Evidenz](#8-sichtbarkeit--evidenz)
- [9. Fleet-Operationen](#9-fleet-operationen)
- [10. Offline, Teleport & Mobile](#10-offline-teleport--mobile)
- [11. Developer Experience (Begreifbarkeit & Sicherheit)](#11-developer-experience-begreifbarkeit--sicherheit)
- [12. Onboarding-Fahrplan (MVP → Next → Extended)](#12-onboarding-fahrplan-mvp--next--extended)
- [13. Sicherheitsmodell (Kurz)](#13-sicherheitsmodell-kurz)
- [14. Canvas-Appendix (optionale Visualisierung)](#14-canvas-appendix-optionale-visualisierung)
- [15. Für Dummies (ein Absatz)](#15-für-dummies-ein-absatz)
- [16. Verdichtete Essenz](#16-verdichtete-essenz)
- [17. Ironische Auslassung](#17-ironische-auslassung)
- [18. ∆-Radar (Regel-Evolution)](#18--radar-regel-evolution)
- [19. ∴fores Ungewissheit](#19-fores-ungewissheit)
- [20. Anhang: Kommandokarte als Einzeiler (Merkliste)](#20-anhang-kommandokarte-als-einzeiler-merkliste)

> **Leitbild:** Ein Knopf. Ein Vokabular. Ein Cockpit. Ein Gedächtnis.  
> **WGX** ist das **Repo-Betriebssystem**: vereinheitlichte Bedienung über alle Repositories und Geräte (Pop!_OS, Codespaces, Termux) – verstärkt durch **HausKI-Memory** für Personalisierung, Reproduzierbarkeit, Evidenz und Fleet-Orchestrierung.

---

## 0. Executive Summary (Kurzfassung)

- **WGX normalisiert Bedienung:** immer dieselben Knöpfe (`up | list | run | guard | smoke | doctor`), egal ob Just/Task/Make/npm/cargo.  
- **WGX härtet Qualität:** Contracts, Auto-Fixes, schnelle Sanity-Checks, Policy-Explain.  
- **WGX sieht Zusammenhänge:** Shadowmap (Repos ↔ Workflows ↔ Secrets ↔ Dienste), Lighthouse (Policies), Evidence-Packs für PRs.  
- **WGX lernt & erinnert:** Memory speichert Runs, Policies, Seeds, Artefakte; `suggest`, `optimize`, `forecast`, `preview`.  
- **WGX skaliert:** Fleet-Kommandos für viele Repos; Budget-Steuerung, Quarantäne, Konvois, Benchmarking.  
- **WGX bleibt portabel:** Teleport zwischen Pop!_OS, Codespaces, Termux; Offline-Bundles und Delta-Sync.

**Essenz:** Ein Bedienkanon + Policies + Sichtbarkeit + Gedächtnis ⇒ **schnellere, sichere, reproduzierbare Entwicklung** – vom Ein-Repo bis zur Fleet.

---

## 1. Problem → Prinzipien

**Fragmentierung** (Toolzoo, Plattformen), **Unsichtbarkeit** (unklare Policies/Secrets/Abhängigkeiten), **Nicht-Reproduzierbarkeit** (flaky, „läuft nur bei mir“), **Skalierungs-Schmerz** (viele Repos, viele Teams).

**Prinzipien:**
1. **Universal-Knöpfe** statt Tool-Sonderwissen.  
2. **Contracts first:** Guard, Auto-Fix, Explain.  
3. **Beweisbarkeit:** Evidence-Packs an PRs.
4. **Gedächtnis-Ops:** Memory macht WGX personalisiert und reproduzierbar.  
5. **Fleet-Wirkung:** Orchestrierung mit Budget, Quarantäne, Konvois.  
6. **Offline-First & Portabilität:** Phone-Bundles, Wormhole-Gleichverhalten.  

---

## 2. Bedienkanon (Kern → „Ultra“)

### 2.1 Core (heute unverzichtbar)
- `wgx up` – Umgebung erkennen & bereitmachen (Devcontainer/Devbox/mise/direnv Fallback-Logik).  
- `wgx list` – Tasks autodiscovern (Just/Task/Make/npm/cargo) und taggen (`fast | safe | slow`).  
- `wgx run <task | freitext>` – Universal-Runner; Freitext→Semantik→Adapter (Alias-Map je Repo).  
- `wgx guard` – Contracts prüfen & **auto-fixen** (fmt, lint, vale, cspell, shellcheck, cargo fmt …).  
- `wgx smoke` – 30–90-Sekunden-Sanity (bauen, 1–2 Tests, Ports/Env OK).  
- `wgx doctor | validate` – Vertrauen in System & Repo (Prereqs, Pfade, Tokens, Profile).

### 2.2 Orchestrierung & Fluss
- `wgx fleet status|fix` – Multi-Repo Cockpit; parallele Standard-Reparaturen.  
- `wgx runbook` – klickbare Runbooks aus Markdown (Checks, Prompts, Rollbacks).  
- `wgx rituals` – goldene Pfade, z. B. `ritual ship-it` (Version→Changelog→Tag→Release Notes→CI-Gates).

### 2.3 Intelligenz & Lernfähigkeit
- `wgx suggest` – nächste sinnvolle Schritte anhand Diff/Logs/Nutzung.  
- `wgx profile learn` – Repo-Genome (Top-Tasks, Painpoints, bevorzugte Umgebungen).  
- `wgx morph` – Repo an WGX-Standards angleichen (Stil, CI, Tasks, Profile).

### 2.4 Zeit, Budget, Repro
- `wgx chrono` – Night-Queues, CPU-Budget, CI-Minutes-Autopilot.  
- `wgx timecapsule` – Zeitreise-Runs mit Versions-Pinning (mise/devbox/devcontainer-Metadaten).  
- `wgx chaos` – Fail-Fast-Sandbox (Low-RAM/Slow-IO) auf wichtigste Pfade.

### 2.5 Teleport & Ephemeres
- `wgx wormhole` – gleiches Verhalten Pop!_OS ↔ Codespaces ↔ Termux.  
- `wgx spin #123` – Issue/PR → ephemere Dev-Env (Ports, Seeds, Fixtures).

### 2.6 Sichtbarkeit & Sicherheit
- `wgx shadowmap` – Repos ↔ Workflows ↔ Secrets ↔ Dienste visualisieren (siehe [Abschnitt 8](#8-sichtbarkeit--evidenz)).
- `wgx lighthouse` – Policy-Diff erklären + One-Click-Fix; Compliance-Modes (`strict | balanced | fast`).
- `wgx patchbay` – signierte Mini-PRs; `patchbay guardfix` für Serien-Fixes.

### 2.7 Brücken & Offline
- `wgx bridge` – HausKI/Codex/NATS-Backchannel (Agenten koordinieren Patches/Reviews).  
- `wgx phone` – Offline-Bundles für Termux (Docs/Lints/Seeds), später Sync.

### 2.8 „Ultra“ Module (Visionär, aber konkret anschlussfähig)
- **WGX Studio** (TUI/Web-UI): Tasks, Fleet-Status, Shadowmap, Ritual-Knöpfe.  
- **Ritual-Recorder → Runbook-Generator**: ausführen, aufzeichnen, wiederholen.  
- **WGX Registry**: Profile/Rituale als Snippets teilen („Rust-Starter“, „SvelteKit-Docs-Lint“, „Audio-Bitperfect“).  
- **Evidence-Packs**: `wgx evidence` hängt Logs/Smoke/Guard/Coverage kompakt an PRs.  
- **Smoke-Orchard**: Fleet-Parallelisierung mit Budget/Quoten (`--budget`, `--concurrency=auto`).  
- **Seeds**: `wgx seeds snapshot|apply` (kleine, anonymisierte, deterministische Datensätze).

---

## 3. Erweiterungen (Zutrag-Synthese, neu integriert)

> **Status-Legende:** 🟢 Core · 🟡 Next · 🔬 Experimental

### 3.1 Erklärbarkeit & Simulation
- **`wgx explain <topic>`** 🟡 – erklärt Aktionen/Fehler/Policies kontextuell; verlinkt Run-Historie & Docs.  
- **`wgx diff <A>..<B>`** 🟡 – vergleicht Env/Seeds/Artefakte/Timecapsule-Runs/Repos.  
- **`wgx simulate run <task>`** 🔬 – Kosten-/Fehler-Vorschau (nutzt `chrono` & `smoke`-Historie).

### 3.2 Repro & Snapshots
- **`wgx checkpoint save|restore <name>`** 🟡 – Ad-hoc-Schnappschüsse (Code, Env, Seeds, Artefakte).  
- **`wgx timecapsule diff <t1> <t2>`** 🟡 – Tool-/Seed-Änderungen zwischen zwei Runs.

### 3.3 Fleet & Skalierung
- **`wgx fleet sync`** 🟡 – `.wgx/profile.yml`/`rituals` über Repos synchronisieren (mit Merge-Strategie).  
- **`wgx fleet benchmark`** 🟡 – vergleicht Smoke-Dauer, CI-Minuten, Flakiness, schlägt Optimierungen vor.  
- **`wgx fleet ripple`** 🟡 – Änderungs-Ausbreitung (Dependency-Kaskaden) erkennen.  
- **`wgx convoy`** 🔬 – koordinierte Multi-Repo-Releases mit atomarem Rollback.  
- **`wgx quarantine`** 🟡 – isoliert „rote“ Repos, blockiert sie nicht fleet-weit.

### 3.4 Vorhersage & Optimierung
- **`wgx preview`** 🟡 – Preflight-Analyse vor PR (Bruchrisiken, Doku-Drift, Downstream-Impact; siehe [Abschnitt 12](#12-onboarding-fahrplan-mvp--next--extended) für MVP-Staffelung).
- **`wgx forecast`** 🟡 – Flakiness-/Dauer-/Risikoprognose (historische Muster).  
- **`wgx optimize`** 🟡 – Vorschläge: Parallelisierung, Caches, geänderte Testpfade; misst Einsparungen.  
- **`wgx fuel --show|--limit`** 🟡 – Ressourcen/„Kosten“ (CI-Minuten, Spin-Runtime, Cache-Größe) sichtbar begrenzen.

### 3.5 Sichtbarkeit, Sicherheit & Compliance
- **`wgx audit`** 🟡 – Security/Compliance-Report (veraltete Secrets, ungenutzte Tokens, Scope-Drift).  
- **`wgx shadowmap --interactive`** 🟡 – interaktive TUI/Web-UI für Abhängigkeits-Graph.  
- **Secret-Rotation-Trigger** 🟡 – `lighthouse` empfiehlt Rotation (Alter, Wiederverwendung, Scope).  
- **`wgx policy simulate`** 🔬 – Wirkung neuer Policies auf Historiendaten simulieren.  
- **`wgx compliance diff`** 🔬 – Policy-Deckung über Repos/Teams vergleichen.  
- **`wgx audit trail`** 🔬 – forensische Nachvollziehbarkeit aller WGX-Aktionen.

### 3.6 Offline & Mobility
- **`wgx phone mirror`** 🟡 – Delta-Sync von Memory/Artefakten/Runbooks auf Termux (sparsam).  
- **`wgx phone suggest`** 🟡 – komprimierter Offline-Speicher mit lokalen Vorschlägen.  
- **`wgx bundle export|import`** 🟡 – komplette WGX-Umgebung paketieren/transferieren.

### 3.7 Community & Registry
- **WGX Registry (Marketplace)** 🟡 – Snippets/„Community Rituals“ mit Ratings & Kompatibilitäts-Tags.
- **`wgx federate`** 🔬 – Multi-Org-Fleet-Status koordinieren (Partner-Teams).  
- **`wgx vendor`** 🟡 – Dependency-Scanner/Advisories in WGX-Flows integriert.

### 3.8 Developer Experience
- **`wgx undo`** 🟡 – Transaktions-Wrapper für schreibende Aktionen (`guardfix`, `morph`, `patchbay`).  
- **`wgx shell`** 🟡 – interaktive REPL-ähnliche Shell mit Kontext/Autovervollständigung.  
- **`wgx aliases learn`** 🟡 – beobachtet Muster/Tippfehler, schlägt personalisierte Aliase vor.  
- **`wgx replay <session>`** 🟡 – Sitzung aufzeichnen → Runbook.  
- **Onboarding Wizard (`wgx tour`)** 🟢 – geführtes Setup + Profile-Generator.  
- **Gamification (`wgx stats`)** 🔬 – zeigt Einsparungen/Erfolge, motiviert „Goldene Pfade“.

### 3.9 Automation & Resilienz
- **`wgx autopilot`** 🔬 – supervised Mode; Routine-Tasks selbständig, nur bei Anomalien prompten.  
- **`wgx scheduler cron`** 🟡 – zeitgesteuerte Fleet-Operationen (z. B. wöchentliche Smoke-Orchard).  
- **`wgx emergency`** 🔬 – Incident-Protokoll: Auto-Rollback, Benachrichtigungen, Berichte.

### 3.10 Visualisierung (weitere)
- **`wgx topology`** 🔬 – 2D/3D-Dependency-Maps, Critical-Path-Highlighting.  
- **`wgx heatmap realtime`** 🔬 – Live-Dashboard (Last, Flakiness, Deploy-Status).  
- **`wgx story`** 🟡 – Release Notes aus Git/PR/Evidence generieren.

### 3.11 Advanced & Experimental
- **`wgx ai pair`** 🔬 – Code-Assistenz mit WGX-Kontext.  
- **`wgx quantum test`** 🔬 – probabilistischer Readiness-Score.  
- **`wgx blockchain evidence`** 🔬 – unveränderliche Evidence-Packs (High-Assurance-Umgebungen).

---

## 4. HausKI-Memory (Gedächtnis-Ops)

### 4.1 Wirkung (auf Kommandos gemappt)
- `up` – **Device-Profile** laden; bewährte Toolchains/Flags pro Gerät.  
- `list | run` – **semantisches Aliasing** je Repo („docs prüfen“ → `vale+cspell+linkcheck`).  
- `guard` – **Policy-Historie** priorisiert häufige Verstöße + direkte Fix-Shortcuts.  
- `smoke` – **kürzester aussagekräftiger Pfad** aus Mess-Historie.  
- `chrono` – **billige Zeitfenster** für teure Jobs.  
- `timecapsule` – **Env-Pins** (Tool-/Seed-Fingerprints) für echte Zeitreisen.  
- `runbook | rituals` – **klickbare Abläufe** mit Erfolgsscores.  
- `fleet` – **Trends/Heatmaps/Budget** aus Fleet-Gedächtnis.

### 4.2 Minimal-Datenmodell (vereinfachte Entitäten)
- **repo**: id, url, tags, default_tasks  
- **env**: os, cpu/gpu, toolversions, devcontainer_hash  
- **run**: ts, task, args, duration, exit, artefacts[], logs_hash  
- **policy_event**: rule, outcome, fix_link, auto_fixable?  
- **evidence_pack**: files[], summary, linked_pr  
- **seed_snapshot**: name, schema_version, export_cmd, checksum  
- **secret_ref**: provider-Ref, kein Klartext  
- **preference**: key→value („prefer_nextest“, „db_light“)

### 4.3 On-Disk (git-freundlich, lokal)
```
.hauski/
  memory.sqlite          # Runs, Policies, Prefs
  vector/                # Textindex (Logs/Docs)
  cas/xx/xx/<sha256>     # Artefakte (content-addressed)
  seeds/<name>@<ver>.tgz # deterministische Testdaten
  evidence/<pr#>-<ts>.zip
  profiles/<repo>.yml    # learned aliases
```

### 4.4 Security
- **Keine Klartext-Secrets.** Nur **secret_ref** (sops/age/Provider-IDs).  
- Policies prüfen Vorhandensein/Konfiguration, **nie** Inhalte.

### 4.5 API-Kleber
- local-first Dienst: `hauski-memoryd` (HTTP/NATS).  
- WGX spricht via `wgx … --use-memory` (RW).  
- Sync als **Memory Packs** (`zip/tar`, ohne Secrets) für Transfer/Git/rsync.

---

## 5. Kommandoreferenz (Index, Status, Nutzen)

| Kategorie | Kommando | Status | Nutzen (Einzeiler) |
|---|---|:---:|---|
| Core | `up` | 🟢 | Umgebung erkennen & fertig machen |
| Core | `list` | 🟢 | Tasks autodiscovern & taggen |
| Core | `run <task|text>` | 🟢 | Intent → richtiges Kommando |
| Core | `guard` | 🟢 | Contracts prüfen + auto-fix |
| Core | `smoke` | 🟢 | 30–90s Gesundheitscheck |
| Core | `doctor | validate` | 🟢 | System/Repo-Diagnose |
| Flow | `runbook` | 🟡 | Klickbare Abläufe aus Markdown |
| Flow | `rituals` | 🟡 | Goldene Pfade (Release etc.) |
| Fleet | `fleet status|fix` | 🟡 | Multi-Repo-Cockpit |
| Fleet | `fleet benchmark` | 🟡 | Dauer/Flake/CI-Vergleich |
| Fleet | `fleet ripple` | 🟡 | Abhängigkeits-Kaskaden |
| Fleet | `convoy` | 🔬 | Koordinierte Releases |
| Fleet | `quarantine` | 🟡 | Isoliert rote Repos |
| Intel | `suggest` | 🟡 | Nächste sinnvolle Schritte |
| Intel | `profile learn` | 🟡 | Repository-Genome |
| Intel | `morph` | 🟡 | Migration zu Standards |
| Repro | `chrono` | 🟡 | Zeit/CPU/CI-Budget |
| Repro | `timecapsule` | 🟡 | Versions-Pinning |
| Repro | `checkpoint` | 🟡 | Ad-hoc-Snapshot |
| Teleport | `wormhole` | 🟡 | Gleichverhalten über Geräte |
| Teleport | `spin` | 🟡 | Ephemere Dev-Env |
| Sichtb. | `shadowmap` | 🟡 | Beziehungen sichtbar |
| Sichtb. | `lighthouse` | 🟡 | Policy-Diff + Fix |
| Sichtb. | `patchbay` | 🟡 | signierte Mini-PRs |
| Offline | `phone` | 🟡 | Offline-Bundles |
| Offline | `bundle` | 🟡 | Export/Import WGX-Setup |
| Explain | `explain` | 🟡 | Kontexte/Fehler erklären |
| Simul. | `simulate run` | 🔬 | Kosten/Fehler-Vorschau |
| Diff | `diff` | 🟡 | Env/Artefakt/TC-Diff |
| Opt. | `optimize` | 🟡 | Laufzeit-/Ressourcen-Tipps |
| Forecast | `preview` | 🟡 | Pre-PR Wirkung |
| Forecast | `forecast` | 🟡 | Flake/Dauer-Prognose |
| Budget | `fuel` | 🟡 | Kosten sichtbar/Limit |
| Audit | `audit` | 🟡 | Sec/Compliance Report |
| Policy | `policy simulate` | 🔬 | Regeldry-run |
| Policy | `compliance diff` | 🔬 | Team-Vergleich |
| Trail | `audit trail` | 🔬 | Forensik |
| Team | `sync` | 🟡 | Team-Gedächtnis |
| Knowl. | `knowledge` | 🟡 | Vektor-Q&A (Docs/Logs) |
| UX | `undo` | 🟡 | „Oops“-Taste |
| UX | `shell` | 🟡 | Interaktiver Modus |
| UX | `aliases learn` | 🟡 | Komfort-Aliase |
| UX | `replay` | 🟡 | Session → Runbook |
| Auto | `autopilot` | 🔬 | supervised Automation |
| Auto | `scheduler cron` | 🟡 | Zeitpläne |
| Resil. | `emergency` | 🔬 | Incident-Protokoll |
| Viz | `topology` | 🔬 | 2D/3D-Graph |
| Viz | `heatmap realtime` | 🔬 | Live-Status |
| Viz | `story` | 🟡 | Release Notes |
| Exp. | `ai pair` | 🔬 | Code-Assistent |
| Exp. | `quantum test` | 🔬 | Prob. Readiness |
| Exp. | `blockchain evidence` | 🔬 | Unveränderliche Beweise |

---

## 6. Profile v1 / v1.1 (Minimal → Reich)

**Minimal v1**
```yaml
# .wgx/profile.yml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  repoKind: "generic"
  tasks:
    dev:   "just dev || npm run dev || cargo run"
    test:  "just test || npm test || cargo test --workspace"
    lint:  "just lint || npm run lint || cargo clippy -- -D warnings"
    fmt:   "just fmt  || npm run fmt  || cargo fmt"
alias:
  "docs prüfen": ["vale", "cspell", "linkcheck"]
```

**Erweitert v1.1**
```yaml
wgx:
  apiVersion: v1.1
  requiredWgx: { semver: "^2.0", mode: "strict" }
  repoKind: "rust-app"
  tasks:
    test:
      cmd: ["cargo", "nextest", "run", "--workspace"]
      desc: "Schneller Testlauf"
      group: "ci"
      safe: true
  envDefaults:
    prefer: [devcontainer, devbox, mise]
  contracts:
    style: true
    format: true
  ci:
    template: "github-actions-basic"
```

---

## 7. Reproduzierbarkeit & Seeds

**Timecapsule:** speichert Toolversions/Env-Hash/Seeds/Artefakt-Fingerprints → `wgx timecapsule run --at=2025-06-12`.  
**Seeds:** kleine, anonymisierte Datensätze → `wgx seeds snapshot|apply`.  
**Checkpoint:** *ad hoc* Snapshots für Refactor/Debug → `save "pre-refactor"` → `restore`.

---

## 8. Sichtbarkeit & Evidenz

- **Shadowmap:** gerichteter Graph (Repos↔Workflows↔Secrets↔Dienste) als TUI/Web-UI.  
- **Lighthouse:** erklärt Policy-Diffs, **One-Click-Fix**, Moduswahl (`strict|balanced|fast`).  
- **Evidence-Packs:** Zip mit Logs/Smoke/Guard/Coverage an PRs anhängen (`wgx evidence attach #123`).  
- **Audit/Audit-Trail:** Reports + forensische Kette für Compliance-Teams.

---

## 9. Fleet-Operationen

- **Status/Fix:** Health Überblick; Standard-Heilungen parallel.  
- **Smoke-Orchard:** `--budget` & adaptive `--concurrency`.  
- **Benchmark:** Dauer/Flake/CI-Minuten pro Repo; Optimierungsvorschläge.  
- **Ripple/Convoy/Quarantine:** Kaskaden erkennen; koordinierte Releases; Isolation kranker Repos.

---

## 10. Offline, Teleport & Mobile

- **Wormhole:** identische Semantik der Knöpfe über Geräte.  
- **Phone:** Offline-Bundles (Docs/Lints/Seeds), später Sync.  
- **Mirror/Bundle:** Delta-Updates; komplette WGX-Export/Import.

---

## 11. Developer Experience (Begreifbarkeit & Sicherheit)

- **Explain:** konkrete Ursachen, letzte Vorkommen, Fix-Knopf.  
- **Undo:** Transaktion für schreibende Aktionen.  
- **Shell:** kontextbewusste REPL mit `suggest`/Runbook-Schritten.  
- **Tour/Playground:** geführter Start; gefahrloses Ausprobieren.  
- **Stats/Gamification:** Einsparungen sichtbar machen.

---

## 12. Onboarding-Fahrplan (MVP → Next → Extended)

**MVP (Woche 1):**
`up · list · run · guard · smoke · doctor|validate` + `.wgx/profile.yml v1`.

**Next Ring:**
`fleet status|fix · rituals ship-it · runbook · suggest · checkpoint · optimize`.

**Extended:**
`chrono · timecapsule · chaos · spin · lighthouse · shadowmap · patchbay · phone · audit · fuel · forecast · preview`.

```text
MVP Woche 1 → up · list · run · guard · smoke · doctor|validate + .wgx/profile.yml (v1)
Next Ring  → fleet status|fix · rituals ship-it · runbook · suggest · checkpoint · optimize
Extended   → chrono · timecapsule · chaos · spin · lighthouse · shadowmap · patchbay · phone · audit · fuel · forecast · preview
```

**Done-Kriterien (Kern):**  
- `wgx run` mappt Just/Task/npm/cargo und propagiert Exit-Codes korrekt.  
- `guard` mit ≥3 Auto-Fix-Typen (fmt/lint/docs) + Explain-Links.  
- `smoke` ≤90 s, klarer Ampel-Status.  
- `.wgx/profile.yml` enthält `topTasks`, `env.prefer`, `contracts`, optional `ci.template`.

---

## 13. Sicherheitsmodell (Kurz)

- Secrets nur als **Referenzen** (sops/age/Provider).  
- `lighthouse` kann Rotation vorschlagen + Regelerfüllung prüfen.  
- `audit trail` für Prüfbarkeit; **Evidence-Packs** ohne personenbezogene Daten.  
- **Least Privilege** Defaults in CI-Vorlagen (Templates).

---

## 14. Canvas-Appendix (optionale Visualisierung)

- **Farben:** Blau=Zentrum/Meta, Grau=Grundlagen, Gelb=Prozesse, Rot=Hindernisse, Grün=Ziele, Violett=Ebenen.  
- **Logik:** Links Grundlagen, Mitte Prozesse, Rechts Ziele (optional). Vertikal: unten konkret, oben abstrakt.  
- **Knoten:** Root enthält Quelle; Essenz-Knoten prägnant; Meta-Knoten ohne Allverbindungen.  
- **Verbindungen:** nur sachdienlich, sparsam; Labels nutzen.  
- **Legende-Knoten (verpflichtend):** Farbzuordnung, Achsen-Logik, Freiheiten.

---

## 15. Für Dummies (ein Absatz)

**WGX ist deine Universalfernbedienung fürs Coden.** Du merkst dir drei Knöpfe: `wgx up` (Bühne hinstellen), `wgx list` (Knöpfe anzeigen), `wgx run <…>` (richtig ausführen). `guard` räumt automatisch Kleinkram weg, `smoke` prüft fix, ob alles gesund ist. WGX merkt sich, was bei **dir** funktioniert, erklärt Fehler und liefert Belege für PRs. Läuft am Laptop, im Browser (Codespaces) und auf dem Handy (Termux).

---

## 16. Verdichtete Essenz

**WGX = Bedienkanon + Policies + Sichtbarkeit + Gedächtnis.**  
Einheitliche Knöpfe → sichere Abläufe → sichtbare Beweise → reproduzierbare Ergebnisse – vom Einzelrepo zur Fleet.

---

## 17. Ironische Auslassung

Andere schreiben Playbooks, die niemand liest.  
WGX **spielt** sie – mit Applaus-Knopf: `ritual ship-it`. 🎬

---

## 18. ∆-Radar (Regel-Evolution)

- **Verstärkung:** Ein-Knopf-Rituale, Fleet-Skalierung, Policy-Transparenz, Evidence als erste Klasse.  
- **Seitwärtsmutation:** Studio/Registry/Marketplace, Seeds, Smoke-Orchard, Explain/Optimize/Forecast.  
- **Straffung:** Kern auf 6–7 Kommandos verdichtet; alles weitere dockt an und bleibt optional.

---

## 19. ∴fores Ungewissheit

**Grad:** ▮▮▮▯▯ ≈ 35–40 %  
**Ursachen:** Adapter-Feinheiten (npm/just/task/cargo), sauberes Versions-Pinning, Seed-Governance, sops/age-Schlüssel, Offline-Sync-Konflikte, Fleet-Semantik in Edge-Fällen.  
**Charakter:** **produktive** Unschärfe → optimal für MVP-Spikes mit echten Repos/PRs; modular ausbaubar.

---

## 20. Anhang: Kommandokarte als Einzeiler (Merkliste)

`up` Bühne · `list` Knöpfe · `run` drücken · `guard` aufräumen · `smoke` gesund? ·  
`doctor|validate` vertrauen · `runbook` klickbar · `rituals` choreografiert · `fleet` Überblick ·  
`chrono` günstig · `timecapsule` reproduzierbar · `checkpoint` sichern · `chaos` stressen · `spin` ephemer ·  
`wormhole` überall gleich · `lighthouse` erklärt · `shadowmap` sichtbar · `patchbay` heilt ·  
`explain` versteht · `diff` vergleicht · `simulate` prognostiziert · `optimize` spart · `preview/forecast` warnt ·  
`fuel` deckelt · `audit` prüft · `policy simulate` testet · `compliance diff` vergleicht ·  
`undo` beruhigt · `shell` begleitet · `replay` lehrt · `phone/bundle` nimmt offline mit.
```

