# WGX-Fähigkeiten und Systemgrenzen

Die maschinenlesbare Inventur liegt in
[`operator-ecosystem-capabilities.v1.json`](operator-ecosystem-capabilities.v1.json).
`scripts/validate_operator_capabilities.py` erzwingt folgende Regeln:

- Jede beibehaltene Fähigkeit hat mindestens zwei belegte Repository-Consumer
  oder einen quellengebundenen Fleet-Invarianzvorteil.
- Jeder direkte Consumer nennt seinen repository-nativen CI-Einstieg.
- Eine ausgemusterte Fähigkeit nennt Eigentümer, Distribution und CI-Abdeckung
  des Ersatzes; ausgemusterte WGX-Flächen dürfen nicht wieder auftauchen.
- WGX beansprucht weder Task-Koordination noch Deploy-Autorität oder generische
  Host-Mutation.

## Ergebnis der Inventur

| Fähigkeit | Entscheidung | Belegte Consumer oder Invarianz | Repository-nativer Weg |
| --- | --- | --- | --- |
| Guard-Router | behalten | 10 direkte Reusable-Workflow-Caller | CI-Workflow oder Build-Frontdoor jedes Repositories |
| Smoke-Router | behalten | 7 direkte Reusable-Workflow-Caller | Smoke-/CI-Workflow jedes Repositories |
| Statische Guard-Invarianten | behalten | `semantAH`, `sichter`; gemeinsame Contract- und Datenflussregeln | repository-eigene CI- und Contract-Workflows |
| Metrics-Contract-Kompatibilität | behalten, eingegrenzt | gemeinsames Metarepo-Schema und 10 repository-native Producer | Metarepo-Reusable-Workflow beziehungsweise lokaler `metrics.yml` |
| Kompatibilitätsmatrix | behalten | `hausKI`, `weltgewebe` | jeweiliger `ci.yml` |
| WGX-Profil-Startertemplates | ausgemustert | keine direkten oder byte-identischen Consumer im geprüften Primärbestand | Metarepo `templates/.wgx/profile.yml`, `sync-templates.sh`, `validate-templates.yml` |

Die vollständigen Repository- und Quellpfade stehen im JSON-Dokument. Lokale
Duplikat-Worktrees wurden nicht als zusätzliche Consumer gezählt.

## Autoritätsgrenze

WGX parst Repository-Profile und routet Verifikation zu einem vom Ziel-Repo
deklarierten Einstieg. Das ist keine Task-Queue und keine Ausführungsfreigabe.
[Bureau besitzt Koordination, Reihenfolge und Claims](https://github.com/heimgewebe/bureau/blob/b70bd7a4bdbc1a113bab1e7fce2ddcf2645ebf43/docs/ownership.md).
[Grabowski besitzt Host-/Prozessausführung und typisierte Git-, Service- und
Deploy-Effekte](https://github.com/heimgewebe/grabowski/blob/afc0a6f67ac553aaaa140ca2785aee3d47843636/README.md).
GitHub und die repository-native CI bleiben Quelle für Check-Ergebnisse.

Das Metrics-Workflow läuft deshalb nur noch als Contract-Kompatibilitätscheck.
Er plant keine stündliche Hostbeobachtung, sendet keine Daten an einen
Ingest-Endpunkt und behauptet keine Live- oder Deployment-Wahrheit.

## Ersetzter Template-Pfad

Die WGX-eigenen Starterkopien hatten im geprüften Primärbestand keinen
nachweisbaren Consumer und drifteten neben dem vorhandenen Fleet-Eigentümer.
Der Ersatz ist direkt belegt:

- [kanonisches Profil im Metarepo](https://github.com/heimgewebe/metarepo/blob/1be27a95e8ade74670150315243afd34c32e277e/templates/.wgx/profile.yml)
- [Distribution durch `sync-templates.sh`](https://github.com/heimgewebe/metarepo/blob/1be27a95e8ade74670150315243afd34c32e277e/scripts/sync-templates.sh)
- [CI-Abdeckung durch `validate-templates.yml`](https://github.com/heimgewebe/metarepo/blob/1be27a95e8ade74670150315243afd34c32e277e/.github/workflows/validate-templates.yml)

WGX-Tests verwenden nun `fixtures/profile.valid.yml`; diese Datei ist
ausdrücklich nur eine Test-Fixture und keine Fleet-Distributionsquelle.
