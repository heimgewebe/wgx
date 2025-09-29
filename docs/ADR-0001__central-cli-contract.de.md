# ADR-0001: Zentrales CLI-Contract

> Englische Version: [ADR-0001__central-cli-contract.en.md](ADR-0001__central-cli-contract.en.md)

## Status

Akzeptiert

## Kontext

Die wgx-Toolchain unterstützt mehrere Projekte und Arbeitsplätze. Bisher existierten unterschiedliche Varianten des
CLI-Vertrags (Command Line Interface Contract) in einzelnen Repositories, was zu inkonsistentem Verhalten und
wiederholtem Abstimmungsaufwand führte. Neue Funktionen mussten mehrfach dokumentiert und abgestimmt werden, und
automatisierte Tests konnten nicht zuverlässig wiederverwendet werden. Darüber hinaus nutzen Mitarbeiter verschiedene
Entwicklungsumgebungen (Termux, VS Code Remote, klassische Linux-Setups), wodurch Abweichungen in der CLI-Konfiguration
schnell zu Fehlern führen.

## Entscheidung

Wir etablieren einen zentral gepflegten CLI-Contract innerhalb von wgx. Der Contract wird in `docs` versioniert,
beschreibt erwartete Befehle, Konfigurationsdateien (z. B. `profile.yml`) und deren Schnittstellen, und dient als
Referenz für alle abhängigen Projekte. Änderungen am Contract erfolgen über Pull Requests inklusive ADR-Aktualisierung,
wodurch Transparenz und Nachvollziehbarkeit gewährleistet werden.

## Konsequenzen

- Einheitliches Verhalten: Alle Projekte orientieren sich am selben Contract und können kompatible Tooling-Skripte
  bereitstellen.
- Geringerer Abstimmungsaufwand: Dokumentation, Tests und Runbooks müssen nur einmal gepflegt werden.
- Schnellere Onboarding-Prozesse: Neue Teammitglieder erhalten eine zentrale Referenz.
- Höhere Wartbarkeit: Inkompatible Änderungen werden frühzeitig erkannt, weil sie über den zentralen Contract
  abgestimmt werden müssen.

## Offene Fragen

- Wie werden ältere Projekte migriert, die noch eigene CLI-Definitionen haben?
- Welche automatisierten Validierungen sollen beim Ändern des Contracts verpflichtend sein?
