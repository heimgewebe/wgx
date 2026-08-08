# WGX-Fähigkeiten und Systemgrenzen

Die fail-closed Inventur liegt in
[`operator-ecosystem-capabilities.v1.json`](operator-ecosystem-capabilities.v1.json).
Historische Consumerbelege vom 27. Juli 2026 bleiben darin als Migrationsbelege
erhalten und sind ausdrücklich keine aktuelle Fleet-Caller-Liste.

## Aktuelle öffentliche CLI

WGX hat genau drei operative Subcommands:

| Command | Rolle |
| --- | --- |
| `validate` | Profil prüfen; optional `quick`/`full`-Tasks mit Timeout und Receipt ausführen |
| `tasks` | repository-deklarierte Tasks auflisten |
| `task` | genau einen repository-deklarierten Task ausführen |

`validate --profile` verwendet intern dieselbe `task`-Frontdoor. Es gibt keine
zweite allgemeine Ausführungs-API.

Aktuell belegter externer Runner-Consumer ist Metarepos
`reusable-repo-verify.yml`: Dort werden WGX `validate`, `tasks` und `task`
verwendet. Frühere Guard-/Smoke-Consumerbelege dokumentieren die Migration; die
WGX-eigenen `wgx-guard.yml`/`wgx-smoke.yml` sind heute nur gepinnte
Kompatibilitätsshims zu Metarepo.

## Entfernte self-only Fähigkeiten

Die frühere öffentliche `wgx guard`-Pipeline samt `modules/guard.bash`,
`guards/*` und ausschließlich selbstreferenzierten Tests wurde entfernt. Für
diese Schicht existierte kein aktiver Workflow-, Script- oder externer
Consumer mehr; ihre Existenz wurde zuletzt nur durch das eigene Capability-
Inventar und eigene Tests begründet.

Dasselbe gilt für frühere Doctor-, Env-, Lint-, Run-, Selftest-, Status-, Test-,
Version- und Audit-Frontdoors. Repository-Tasknamen wie `guard`, `lint`, `smoke`
oder `test` bleiben weiterhin zulässig und werden über `wgx task <name>`
ausgeführt.

## Verbleibende WGX-eigene Repository-Fähigkeiten

Diese Pfade warten WGX selbst und sind **keine** zusätzlichen CLI-Commands:

- Metrics-Contract-Fixture und deren Workflow;
- Kompatibilitätsmatrix;
- `.wgx-tools`-Modulprüfung;
- geplante Integrity-Publikation über `scripts/generate-integrity-report.sh`;
- GitHub-Release-Publikation;
- historische Guard-/Smoke-Workflow-URLs als Metarepo-Shims;
- Profil-/Dokumenttemplates, solange deren Ausmusterung nicht revisionssicher
  belegt ist.

## Autoritätsgrenze

Metarepo besitzt Fleet-Vertrag, Starterdistribution und reusable
Verifikationspolicy. Bureau besitzt Taskkoordination. Grabowski/GitHub besitzen
Git-, Worktree-, Prozess- und Deploy-Effekte. RepoGround besitzt
repository-übergreifenden Codekontext.

WGX beansprucht keine dieser Autoritäten. `wgx task` sandboxed den vom
Repository deklarierten Befehl nicht; mögliche Hosteffekte stammen deshalb aus
dem Ziel-Repository und der Autorität des aufrufenden Operators, nicht aus einer
eigenständigen WGX-Policy.

## Maschinenlesbare Ratchets

`scripts/validate_operator_capabilities.py` erzwingt unter anderem:

- exakte Übereinstimmung von `cmd/*.bash` mit der Command-Inventur;
- die Klassifikationen von `validate`, `tasks` und `task`;
- Offenlegung der nicht sandboxed Taskausführung;
- Pflichtflächen der verbleibenden WGX-eigenen Maintenance-Capabilities;
- source-gepinnte historische Evidenz für externe Consumerclaims;
- Trigger-Abdeckung der aktuellen Authority- und Validatorpfade.
