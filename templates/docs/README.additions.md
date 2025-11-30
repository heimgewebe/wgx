# Für Dummies – Was macht dieses Repo?

Dieses Projekt nutzt **WGX** als schlanken Helfer: ein paar Standard-Kommandos (up | list | run | doctor | validate | smoke)
machen Arbeiten im Terminal einfacher. Du musst nicht „programmieren“ können – du führst nur Kommandos aus.

**Wichtigste Idee:** Ein `/.wgx/profile.yml` beschreibt, welche Tools/Checks für dieses Repo gelten.
WGX liest das ein und führt passende Aufgaben aus (z. B. Format, Lint, Tests).

## WGX-Kurzstart

```bash
wgx --help
wgx doctor     # prüft Umgebung
wgx clean      # räumt Temp-/Build-Artefakte auf
wgx send "feat: initial test run"  # Beispiel-Commit/Push-Helfer
```
