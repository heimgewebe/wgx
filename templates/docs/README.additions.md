# WGX-Kurzstart

Dieses Repository kann WGX als schlanken Profil-/Task-Runner verwenden. Das
Repository selbst versioniert `.wgx/profile.yml`.

```bash
wgx validate
wgx tasks
wgx task smoke
```

Tasknamen wie `guard`, `lint`, `smoke` oder `test` sind repository-eigene
Frontdoors und keine WGX-Subcommands. Fleet-Policy und Starterdistribution
werden von Metarepo gepflegt.
