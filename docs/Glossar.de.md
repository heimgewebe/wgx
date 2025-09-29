# Glossar

> Englische Version: [Glossary.en.md](Glossary.en.md)

## wgx
Interne Toolchain und Sammel-Repository, das Build-Skripte, Templates und Dokumentation für verbundene Projekte bereitstellt.

## `profile.yml`
Zentrale Konfigurationsdatei, mit der lokale Profile (z. B. für Dev, CI oder spezielle Kunden) gesteuert werden. Sie definiert CLI-Parameter, Umgebungsvariablen und Pfade und dient als Bindeglied zwischen zentralem Contract und projektspezifischen Einstellungen.

## Contract (CLI-Contract)
Vereinbarung über Befehle, Optionen, Dateistrukturen und Seiteneffekte des wgx-CLI. Er legt fest, welche Schnittstellen stabil bleiben müssen, damit abhängige Projekte konsistent arbeiten können.
