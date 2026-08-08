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
- kanonische Aufrufe gegen vollständige eingecheckte Git-Blobs sowie eine
  netzwerkfreie Objektkette vom exakten Commit über binär belegte Trees und
  jede Pfadkomponente bis zum Blob; Commit-, Tree- und Blob-IDs werden aus
  Typ, Länge und exakten Bytes nativ neu berechnet,
  beziehungsweise gegen aktuelle lokale WGX-Quellen,
- repository-relative Pfade ohne Absolut-, Parent- oder Symlink-Komponenten,
- nichtleere Authority- und Alternative-Owner sowie lokale Evidenzpfade,
- alle `cmd/*.bash`-Flächen und die Klassifikation mutierender Befehle,
- feste Capability-ID/Kategorie-Bindungen und Pflichtflächen für Tools,
  Integrity und Release-Publikation,
- widerspruchsfreie Autoritätsaussagen und gültige Ersatzevidenz,
- Trigger-Abdeckung aller Flächen und Validatorverträge für Push und PR.

## Belegte Fähigkeiten

| Fähigkeit | Status | Reale Nutzung | Alternative |
| --- | --- | --- | --- |
| Guard-Router | Kompatibilitätsshims behalten | direkte WGX-Caller bleiben während der Migration funktionsfähig; Policy liegt in Metarepo | Metarepo `reusable-repo-verify.yml` |
| Smoke-Router | Kompatibilitätsshims behalten | direkte WGX-Caller bleiben während der Migration funktionsfähig; Policy liegt in Metarepo | Metarepo `reusable-repo-verify.yml` |
| Statische Guard-Invarianten | behalten, lokal belegt | WGX-Tests; fremde Kopien werden nicht gezählt | repository-native Validatoren und CI |
| Metrics-Contract-Kompatibilität | behalten, lokal belegt | WGX-Workflow ruft den WGX-Producer auf | Metarepo-Schema und repository-native Producer |
| Kompatibilitätsmatrix | behalten, lokal belegt | WGX-Workflow ruft die WGX-Action auf | CI des jeweiligen Ziel-Repositories |
| WGX-Tools-Guard | behalten, lokal belegt | Workflow prüft vorhandene `.wgx-tools/modules` | kein unabhängiger Ersatz belegt |
| Integrity-Publikation | behalten, lokal belegt | tägliche/manuelle Erzeugung, Release-Asset und Verifikation | kein gleichwertiger Ersatz belegt |
| Versions-Release | behalten, lokal belegt | Tag-/manuell ausgelöste GitHub-Release-Publikation | kein unabhängiger Ersatz belegt |
| WGX-Profil-Starter | erhalten, Consumer ungeprüft | keine externe Nutzung behauptet | kein kompatibler Ersatz nachgewiesen |

`hausKI` und `weltgewebe` sind in der Kompatibilitätsmatrix Ziele, nicht deren
Consumer. `semantAH` enthält lokale WGX-ähnliche Runner oder Kopien; diese
belegen keine Nutzung der kanonischen statischen WGX-Guards. Sichters `ci.yml`
ruft nur seine WGX-Forwarder auf und ist deshalb ausdrücklich **keine**
unabhängige Alternative. Die exakten Commit-, Tree-, Blob-, Pfad- und
Aufrufbelege stehen im JSON und in
`operator-ecosystem-source-evidence.v1.json`.

## Operative CLI-Flächen

Die Inventur deckt jede Datei unter `cmd/*.bash` ab. Nach der Entkernung gilt:

- Beobachtung/Verifikation: `audit verify`, `doctor`, `env`, `guard`, `lint`,
  `selftest`, `status`, `tasks`, `validate` und das read-only `version`.
- Delegierte Ausführung: `run` und `task` führen vom Repository deklarierte
  Shell-Kommandos aus; `test` startet repository-eigene Bats-Tests. WGX
  erzwingt für diese delegierten Tasks keine technische Host-Sandbox.
- Repository-Wartung außerhalb der CLI: Der tägliche Integrity-Workflow nutzt
  `scripts/generate-integrity-report.sh`, validiert und veröffentlicht das
  Release-Asset. Dieser Schreibpfad gehört zum WGX-Repository selbst und ist
  keine allgemeine WGX-Command-ABI.
- Entfernte Mutations-/Placeholder-Flächen: `clean`, `config`, `heal`, `hooks`,
  `init`, `integrity`, `quick`, `reload`, `release`, `routine`, `send`, `setup`,
  `start`, `sync-remote` und `vibe` sind nicht Teil der öffentlichen CLI.

`audit` schreibt keine Ledger mehr und führt keinen Git-Fetch aus. Historische
Ledger können mit `wgx audit verify` geprüft werden. Damit besitzt die öffentliche
WGX-CLI keine eigene generische Git-, Forge-, Audit- oder Wartungsmutation mehr.
Hostwirkungen bleiben nur über explizit repository-delegierte `run`/`task`-
Kommandos möglich und liegen damit bei Repository und aufrufendem Operator.

Der stündliche Metrics-Workflow bleibt funktional erhalten: Er erzeugt und
validiert die eng als Contract-Fixture beschriebene Datei, führt bei
konfiguriertem Secret den optionalen best-effort POST aus und lädt
`metrics.json` sieben Tage als Artifact hoch. Die engeren Autoritätsclaims
ändern diese drei Basisverhalten nicht.

Die öffentliche WGX-CLI besitzt damit keine eigene generische Git-, Forge-,
Audit- oder Repository-Wartungsmutation. Hostwirkungen bleiben nur über
explizit repository-delegierte `run`/`task`-Kommandos möglich. Schreibende
WGX-eigene Wartungsworkflows wie Metrics- oder Integrity-Publikation gehören
zum WGX-Repository selbst und nicht zur öffentlichen Command-ABI.

## Autoritätsgrenze

WGX besitzt weder den Fleet-Verifikationsvertrag noch die reusable CI-Policy; beides liegt in Metarepo.
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

## Boundary-v2-Übergabe

Metarepo-Commit `31dbecc6c7b966faa73ad3dceb0ded7329187f36` stellt einen ausführbaren Ersatz für Contract,
Starterprofil und reusable CI bereit. Die historischen Consumerbelege in der maschinenlesbaren Inventur bleiben
als Migrationsbelege erhalten; aktuelle WGX-Guard-/Smoke-Workflows sind nur noch gepinnte Weiterleitungen.
