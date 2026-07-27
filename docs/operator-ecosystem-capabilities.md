# WGX-Fähigkeiten und Systemgrenzen

Die fail-closed Inventur liegt in
[`operator-ecosystem-capabilities.v1.json`](operator-ecosystem-capabilities.v1.json).
Sie trennt direkte Consumer, Fleet-Invarianz, WGX-lokale Nutzung,
Kompatibilitätsziele und ungeprüfte Kopien. Ein Repository ist nur dann
Consumer, wenn ein belegter Pfad die kanonische WGX-Fläche tatsächlich
aufruft. Ein Ziel einer WGX-Matrix und eine eingecheckte Kopie zählen nicht.

`scripts/validate_operator_capabilities.py` prüft unter anderem:

- eindeutige Fähigkeiten und alle einzeln erforderlichen Capability-IDs,
- exakte Zuordnung von Consumer-Repository, `evidence_path` und Quell-URL,
- nichtleere Authority- und Alternative-Owner sowie lokale Evidenzpfade,
- alle `cmd/*.bash`-Flächen und die Klassifikation mutierender Befehle,
- widerspruchsfreie Autoritätsaussagen und gültige Ersatzevidenz,
- Trigger-Abdeckung aller Flächen und Validatorverträge für Push und PR.

## Belegte Fähigkeiten

| Fähigkeit | Status | Reale Nutzung | Alternative |
| --- | --- | --- | --- |
| Guard-Router | behalten | zehn direkte Caller des WGX-Reusable-Workflows | CI/Build-Frontdoor des jeweiligen Repositories |
| Smoke-Router | behalten | sieben direkte Caller des WGX-Reusable-Workflows | Smoke-/CI-Frontdoor des jeweiligen Repositories |
| Statische Guard-Invarianten | behalten, lokal belegt | WGX-Tests; fremde Kopien werden nicht gezählt | repository-native Validatoren und CI |
| Metrics-Contract-Kompatibilität | behalten, lokal belegt | WGX-Workflow ruft den WGX-Producer auf | Metarepo-Schema und repository-native Producer |
| Kompatibilitätsmatrix | behalten, lokal belegt | WGX-Workflow ruft die WGX-Action auf | CI des jeweiligen Ziel-Repositories |
| WGX-Profil-Starter | erhalten, Consumer ungeprüft | keine externe Nutzung behauptet | kein kompatibler Ersatz nachgewiesen |

`hausKI` und `weltgewebe` sind in der Kompatibilitätsmatrix Ziele, nicht deren
Consumer. `semantAH` und `sichter` enthalten lokale WGX-ähnliche Runner oder
Kopien; diese belegen keine Nutzung der kanonischen statischen WGX-Guards.
Die exakten Commit- und Pfadbelege stehen im JSON.

## Operative CLI-Flächen

Die Inventur deckt jede Datei unter `cmd/*.bash` ab. Sie unterscheidet:

- Beobachtung/Verifikation: `doctor`, `env`, `guard`, `lint`, `selftest`,
  `status`, `tasks`, `validate` sowie die lesenden Modi von `audit`,
  `integrity`, `routine` und `version`.
- Repository-bezogene Mutation: `clean`, `heal`, `init`, `reload` sowie die
  mutierenden Modi von `audit`, `integrity`, `routine` und `version`.
- Forge-/Remote-Effekte: `send` und das darauf aufbauende `quick`.
- Delegierte Ausführung: `run` und `task` führen beliebige, vom Repository
  deklarierte Shell-Kommandos aus; `test` startet repository-eigene Bats-Tests.
  WGX erzwingt für deklarierte Tasks keine technische Host-Sandbox.
- Operator-State: `vibe adopt` schreibt einen Receipt in einen
  operatorgewählten WGX-State-Pfad; Plan, Status und Doctor lesen nur.
- Nicht implementiert: `config`, `hooks`, `release`, `setup`, `start`;
  `sync-remote` besitzt keinen ausführbaren Entrypoint.

Damit behauptet WGX nicht, frei von Host-Mutation zu sein. Die engere Grenze
lautet: WGX besitzt keine generische, repository-übergreifende Host-Autorität.
Die vorhandenen Mutationen sind Entwicklerbefehle für das aktuelle oder
explizit ausgewählte Repository beziehungsweise den Operator-State.

## Autoritätsgrenze

WGX beansprucht, ordnet, weist zu oder beendet keine Bureau-Tasks.
[Bureau besitzt die Task-Koordination](https://github.com/heimgewebe/bureau/blob/b70bd7a4bdbc1a113bab1e7fce2ddcf2645ebf43/docs/ownership.md).
WGX beansprucht außerdem keine Grabowski-Autorität für Deployments, Services
oder Prozesse.
[Grabowski besitzt diese typisierten Effekte](https://github.com/heimgewebe/grabowski/blob/afc0a6f67ac553aaaa140ca2785aee3d47843636/README.md).
Repository-Änderungen bleiben unter der Autorität des aufrufenden Operators
und des jeweiligen Repositories; GitHub und repository-native CI entscheiden
über Checks und Merges.

## Rücknahme der Template-Ausmusterung

Die zuvor entfernten WGX-Profile und Dokumentvorlagen sind wiederhergestellt.
Der vorher angeführte
[Metarepo-Kandidat](https://github.com/heimgewebe/metarepo/blob/1be27a95e8ade74670150315243afd34c32e277e/templates/.wgx/profile.yml)
definiert keine WGX-Tasks. Er bewahrt daher weder die ausführbare Semantik der
WGX-Templates noch eine dazu passende CI-Abdeckung. Die Migration ist als
`retirement_reversed` vermerkt; bis echte Consumer oder ein kompatibler Ersatz
belegt sind, lautet der ehrliche Status `preserved_unproven`. Ein fokussierter
Regressionstest lädt alle ausführbaren Profile und prüft ihre Task-Mengen.
