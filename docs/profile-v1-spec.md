# WGX v1 compatibility profile

Dieses Dokument beschreibt den **aktuellen Runner-Vertrag** von WGX. Neue
Fleet-Policy, Templates und reusable CI werden nicht mehr in diesem Repository
definiert; WGX bleibt während des Boundary-v2-Cutovers der kompatible Runner.

## Kanonische Form

Neue oder bereinigte Profile verwenden ausschließlich den verschachtelten
`wgx`-Block:

```yaml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  repoKind: generic
  validate:
    quick:
      - smoke
    full:
      - guard
      - smoke
  tasks:
    guard: "git diff --check"
    smoke: "git rev-parse --is-inside-work-tree >/dev/null"
```

`wgx.tasks` ist die Menge repository-eigener Frontdoors. WGX besitzt deren
fachliche Semantik nicht; `wgx task <name>` führt nur den explizit deklarierten
Task aus.

## Validierungsprofile

`wgx.validate.quick` und `wgx.validate.full` enthalten geordnete Tasknamen.
`unsupported` und `ciOnly` ordnen Tasknamen einer nichtleeren Begründung zu.
`wgx validate --profile quick|full --json` erzeugt daraus einen deterministischen
Receipt.

## Legacy-Kompatibilität

Root-Level-Schlüssel wie `tasks`, `requiredWgx`, `repoKind`, `env` oder
`workflows` werden vom v1-Parser weiterhin als Übergang akzeptiert. Sie sind
**keine empfohlene neue Form**. Falls sowohl `wgx.*` als auch Root-Level-Werte
vorhanden sind, gewinnt die verschachtelte Form; bestehende Parser-Fallbacks
bleiben bis zum Fleet-Cutover getestet.

Die lokale Kompatibilitätsprojektion liegt in
[`profile.schema.json`](profile.schema.json). Sie muss dieselben aktiven
Beispiele akzeptieren wie der Parser und darf keinen zweiten, widersprüchlichen
Profilvertrag definieren.
