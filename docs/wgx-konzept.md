# WGX – minimaler Repository-Verifikationsrunner

WGX ist kein Fleet-Orchestrator und kein allgemeines Repository-Werkzeug. Es
ist die kleine Kompatibilitätsschicht für bestehende `.wgx/profile.yml`-Profile.

## Öffentliche ABI

WGX besitzt exakt drei operative Subcommands:

- `validate` – Profil bzw. `quick`/`full`-Validierung prüfen und Receipts erzeugen;
- `tasks` – repository-deklarierte Tasks auflisten;
- `task` – genau einen deklarierten Task ausführen.

`validate --profile` verwendet intern ebenfalls `task`; es gibt keine zweite
Ausführungsfrontdoor.

## Zuständigkeiten

Metarepo besitzt den kanonischen Fleet-Vertrag, Starterprofile und reusable
Guard-/Smoke-/Quick-/Full-Policy. Die früheren WGX-reusable Guard-/Smoke-URLs
sind nach abgeschlossener Caller-Migration entfernt; WGX konsumiert Metarepos
Workflow nur noch für die eigene Repository-Verifikation.

Bureau besitzt Taskkoordination. Grabowski/GitHub besitzen Git-, Worktree-,
Prozess- und Deploy-Effekte. RepoGround besitzt repository-übergreifenden
Codekontext. WGX beansprucht keine dieser Autoritäten.

Tasknamen wie `guard`, `lint`, `smoke` oder `test` können in Profilen vorkommen,
sind aber Repository-Tasks und keine WGX-Subcommands. WGX sandboxed deren
Befehle nicht.

## Repository-interne WGX-Wartung

Integrity-, Metrics-, Release-, Tools-Guard- und Kompatibilitätsworkflows warten
das WGX-Repository selbst. Diese Pfade sind nicht Teil der öffentlichen CLI.

Die frühere statische `wgx guard`-Implementierung und weitere Beobachtungs- oder
Developer-Commands wurden entfernt, nachdem keine aktuellen Consumer mehr
belegt waren.
