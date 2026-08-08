# Für Dummies – Was macht dieses Repo?

Dieses Projekt nutzt **WGX** als schlanken Repository-Verifikationsrunner.
Ein `/.wgx/profile.yml` beschreibt die repository-eigenen Tasks und Checks; WGX
liest den Vertrag, listet Frontdoors auf und führt deklarierte Aufgaben aus.

## WGX-Kurzstart

```bash
wgx --help
wgx doctor
wgx validate
wgx tasks
wgx task smoke
```

Git-, Cleanup-, Branch- und PR-Effekte gehören nicht zur WGX-CLI. Fleet-Vorlagen
und reusable Verifikationspolicy werden von Metarepo gepflegt.
