# WGX Quickstart

WGX erstellt keine Repository-Profile. Das Ziel-Repository versioniert sein
`.wgx/profile.yml`; Fleet-Policy und Starterprofile gehören zu Metarepo.

Die öffentliche WGX-CLI hat genau drei operative Frontdoors:

```bash
wgx validate
wgx tasks
wgx task smoke
```

`wgx validate --profile quick|full` führt die im Profil für das jeweilige
Validierungsprofil deklarierten Tasks über dieselbe `task`-Frontdoor aus und
erzeugt einen deterministischen Receipt.

WGX besitzt keine eigenen Git-, PR-, Cleanup-, Guard-, Lint-, Test- oder
Environment-Subcommands. Namen wie `guard`, `lint`, `smoke` oder `test` können
weiterhin repository-eigene Tasks sein und werden dann mit `wgx task <name>`
ausgeführt.
