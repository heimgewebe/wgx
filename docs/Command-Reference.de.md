# Befehlsreferenz für `wgx`

Die vollständig generierte Referenz liegt in [`cli.md`](cli.md). Diese Seite
ordnet die aktive Oberfläche nach ihrer Rolle ein.

## Verifikationskern

| Kommando | Zweck |
| --- | --- |
| `wgx tasks` | Deklarierte Repository-Tasks auflisten. |
| `wgx task <name>` | Genau einen deklarierten Task ausführen, ohne implizite WGX-Telemetrie. |
| `wgx run <name>` | Kompatibilitätsalias für profilbasierte Taskausführung mit Dry-Run. |
| `wgx validate` | Profilstruktur bzw. `quick`/`full`-Validierungsprofile prüfen. |
| `wgx doctor` | Runner-/Repository-Voraussetzungen diagnostizieren. |
| `wgx env` / `wgx status` | Lokale Runner- und Repositoryinformationen lesen. |

Die fachlichen Checks gehören dem Ziel-Repository. Ein Python-Repo kann etwa
`uv run pytest`, ein Rust-Repo `cargo test` und ein Dokumentationsrepo seinen
eigenen Linter als Task deklarieren.

## WGX-eigene Entwicklungsbefehle

`wgx lint`, `wgx test` und `wgx selftest` prüfen den WGX-Quellbaum selbst. Sie
sind keine generische Fleet-Policy und werden nicht als repository-native
Frontdoors anderer Repositories interpretiert.

## Übergangsflächen

`audit`, `clean`, `guard`, `heal`, `init`, `integrity`, `quick`, `reload`,
`routine`, `send`, `sync-remote`, `version` und `vibe` bleiben vorerst aus
Kompatibilitätsgründen vorhanden. Einige davon mutieren Git- oder
Repositoryzustand. Sie gehören **nicht** zum langfristigen schlanken
Verifikationsrunner und werden erst nach revisionsgebundener Consumerprüfung
entfernt oder zu ihrem zuständigen System migriert.

## Entfernte Platzhalter

`config`, `hooks`, `release`, `setup` und `start` waren öffentliche
Placeholder-Kommandos ohne Implementierung. Sie wurden entfernt, statt eine
nicht vorhandene Fähigkeit weiter vorzutäuschen. Git-Branches, Hooks, Releases
und Setup bleiben bei repository-nativen Werkzeugen bzw. dem zuständigen
Operator.
