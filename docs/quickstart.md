# WGX Quickstart

WGX erstellt keine Repository-Profile mehr selbst. Der kanonische Profil- und
Fleet-Vertrag gehört zu Metarepo; das Ziel-Repository versioniert sein
`.wgx/profile.yml` zusammen mit dem eigenen Code.

Für einen bestehenden Checkout genügen die Runner-Frontdoors:

```bash
wgx doctor
wgx validate
wgx tasks
wgx task smoke
```

`wgx run <task>` und `wgx task <task>` führen ausschließlich bereits im
Repository deklarierte Tasks aus. Git-, Branch-, PR- und Cleanup-Effekte gehören
nicht zur WGX-CLI und werden über Repository-Workflows bzw. den autorisierten
Operator ausgeführt.
