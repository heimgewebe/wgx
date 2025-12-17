# AI Contexts (Heimgewebe) – v1.1

Ziel: Kurze, maschinen- und menschenlesbare Orientierung für Agenten.
Diese Dateien sind **nicht** die Lang-Doku. Sie sind der Einstieg: Wo anfangen? Was ist tabu?

## Prinzipien
- **Kurz & prüfbar**: lieber wenige Felder, die stimmen, als viele, die driften.
- **Contracts-first**: Wenn es ein Schema/Interface gibt, verweise darauf.
- **WGX-Erwartung sichtbar**: Fleet-Repos sollen WGX-Profil/Guard/Smoke implizieren.
- **Grenzen explizit**: Was dieses Repo *nicht* macht (damit Agenten nicht “kreativ falsch” werden).

## Version
- v1.0 hatte bereits: project / dependencies / architecture / conventions / documentation / ai_guidance.
- v1.1 ergänzt: heimgewebe (Achse/Fleet/WGX), interfaces (produces/consumes), contracts, boundaries.

## Rollout-Regel (wichtig)
Dieses Verzeichnis `ai-contexts/` ist **metarepo-zentriert** gedacht: hier liegen Templates und Beispiele.
Wenn du denselben Patch in alle Repos einspeist:
- **NON-metarepo Repos** müssen nur `/.ai-context.yml` korrekt pflegen.
- Template-Dateien in `ai-contexts/` sind dort **nicht zwingend**.
- Der CI-Guard ist so gebaut, dass er Template-Checks nur ausführt, wenn `ai-contexts/` existiert.

## Pflege-Regeln
- Änderungen an Repo-Rolle oder Contracts -> ai-context aktualisieren.
- Wenn du unsicher bist: lieber “unknown” markieren als halluzinieren.

## Template
Siehe: ai-contexts/_template.ai-context.yml
