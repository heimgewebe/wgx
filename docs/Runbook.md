# WGX Runbook

## Voraussetzungen

WGX benötigt Bash, Git und Python 3. Für das Parsen von `.wgx/profile.yml`
wird PyYAML verwendet.

## Normaler Ablauf

```bash
wgx validate
wgx tasks
wgx task smoke
```

Für merge-nahe lokale Verifikation kann ein Repository `quick`- und
`full`-Profile deklarieren:

```bash
wgx validate --profile quick --json
wgx validate --profile full --json
```

`validate --profile` führt die im Profil genannten Tasks über dieselbe
`wgx task`-Frontdoor aus. Timeouts und Receipts werden vom Validator verwaltet.

## Fehlerdiagnose

1. `wgx validate --json` prüft den Profilvertrag.
2. `wgx tasks --json` zeigt, welche Tasks WGX tatsächlich sieht.
3. `wgx task <name>` reproduziert genau einen deklarierten Task.
4. Repository-native CI entscheidet anschließend über den eigentlichen Build-
   oder Merge-Status.

WGX hat keine eigenen Doctor-, Env-, Guard-, Lint-, Test-, Git- oder
Cleanup-Subcommands mehr. Entsprechende Prüfungen gehören in die Tasks bzw. CI
des Ziel-Repositories.
