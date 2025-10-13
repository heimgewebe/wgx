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
