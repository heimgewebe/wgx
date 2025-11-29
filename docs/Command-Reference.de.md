# Befehlsreferenz für `wgx`

Diese Übersicht fasst die wichtigsten Subcommands zusammen, inklusive Zweck und zentraler Optionen. Die Beschreibungen basieren auf dem aktuellen Stand der Skripte unter `cmd/` sowie den portierten Funktionen aus `archiv/wgx`.

> ⚠️ **Umbau-Hinweis:** Einige Kommandos – insbesondere `wgx quick`, `wgx hooks` sowie der `wgx version`/`wgx release`-Pfad – befinden sich in aktiver Überarbeitung. Sie sind funktional, können aber kurzfristig Breaking Changes oder erweiterte Optionen erhalten. Kennzeichnungen erfolgen in den jeweiligen Abschnitten.

## Schnellüberblick

| Kommando | Kurzbeschreibung |
| --- | --- |
| `wgx status` | Zeigt Branch, Ahead/Behind sowie erkannte Projektpfade an. |
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

### `wgx send`

- **Zweck:** Erstellt Pull/Merge Requests inklusive Body-Rendering und Reviewer-/Label-Logik.
- **Wichtige Optionen:**
  - `--draft` oder automatische Draft-Umschaltung bei Guard-Warnungen.
  - `--scope`, `--title`, `--why`, `--tests`, `--notes` für den PR-Body.
  - `--reviewers auto|foo,bar`, `--label`, `--issue`/`--issues` für Metadaten.
  - `--ci` triggert optionale Workflows (`$WGX_CI_WORKFLOW`).
  - `--open` öffnet den PR/MR im Browser.
  - `--auto-branch` legt bei Bedarf einen Arbeits-Branch auf Basis von `wgx start` an.
- **Besonderheiten:** Erzwingt vorher `wgx guard`; unterstützt GitHub (`gh`) und GitLab (`glab`).

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
>
> **Status:** Funktionsumfang wird aktuell neu strukturiert (Release-Workflows sind im Aufbau).

- **Zweck:** Erstellt SemVer-Tags und (optional) Releases auf GitHub/GitLab.
- **Wichtige Optionen:**
  - `--version vX.Y.Z` oder `--auto-version patch|minor|major` (SemVer-Bump).
  - `--push`, `--sign-tag`, `--latest`, `--allow-prerelease` für erweiterten Release-Flow.
  - `--notes <file>` oder automatische Release Notes aus dem Git-Log.

### `wgx version`
>
> **Status:** Versionierungspipeline im Umbau, CLI-Optionen können sich kurzfristig ändern.

- **Zweck:** Synchronisiert Projektversionen in `package.json` und `Cargo.toml`.
- **Unterbefehle:**
  - `bump patch|minor|major [--commit]`
  - `set vX.Y.Z [--commit]`
- **Besonderheiten:** Nutzt `jq` bzw. `cargo set-version` wenn verfügbar, fallback auf sed/awk.

### `wgx hooks`
>
> **Status:** Erweiterte Subcommands sind geplant; derzeit nur Installation verfügbar.

- **Zweck:** Installiert lokale Git-Hooks via `cli/wgx/install.sh`.
- **Unterbefehl:** `install` (weitere Subcommands sind aktuell nicht implementiert).

### `wgx env doctor`

- **Zweck:** Prüft Umgebungen, insbesondere Termux, auf notwendige Pakete.
- **Optionen:**
  - `--fix` schlägt Termux-spezifische Remediations (Storage, Paketinstallation, `core.filemode`) vor.
- **Generic Mode:** Auf Desktop-Systemen erfolgt eine reine Statusausgabe ohne Fixes.

### `wgx quick`
>
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
