# Glossar

> Englische Version: [Glossary.en.md](Glossary.en.md)

## WGX

Minimaler Repository-Verifikationsrunner für bestehende `.wgx/profile.yml`-
Verträge. Die öffentliche operative ABI besteht aus `validate`, `tasks` und
`task`.

## Profil

Ein repository-eigenes `.wgx/profile.yml` deklariert Tasks und optional
Validierungsprofile. Namen wie `guard`, `lint`, `smoke` oder `test` sind
Repository-Tasks und keine WGX-Subcommands.

## Task

Ein vom Ziel-Repository explizit deklarierter Shell-Befehl, ausgeführt mit
`wgx task <name>`. WGX sandboxed dessen Hosteffekte nicht.

## Validierungsprofil

Eine geordnete `quick`- oder `full`-Taskmenge, die `wgx validate --profile ...`
mit Timeout- und Receipt-Vertrag ausführt.
