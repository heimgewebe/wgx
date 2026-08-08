# Module & Hilfsbibliotheken

WGX hält nur noch Module, die der Profil-/Task-/Validate-ABI dienen.

## `modules/`

| Datei | Zweck |
| --- | --- |
| `abspath.py` | Sichere absolute Pfadauflösung für den Profilparser. |
| `json.bash` | JSON-Hilfen für CLI-Ausgaben. |
| `profile.bash` | Lädt Profile und führt repository-deklarierte Tasks aus. |
| `profile_parser.py` | Parser für WGX-v1-Profile. |
| `semver.bash` | Versionsbereichsprüfung für `requiredWgx`. |
| `validate_receipt.py` | Deterministische/redigierte Validate-Receipts. |
| `validate_runner.py` | Timeout-gekapselte Ausführung über `wgx task`. |

## `lib/`

`lib/core.bash` enthält Dispatcher-, Logging- und gemeinsame Laufzeithilfen.

## Repository-Wartung

Integrity und Metrics laufen über eigene Skripte/Workflows und sind keine
öffentlichen WGX-Subcommands. Fleet-Policy und Starterdistribution gehören zu
Metarepo.

Siehe auch [CLI-Referenz](cli.md) und [Runbook](Runbook.md).
