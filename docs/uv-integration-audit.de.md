# UV-Integration im wgx-Repository – Kurzbewertung

## Aktueller Stand

- Die README bewirbt uv als Standard für Python-Laufzeiten, Lockfiles und Tooling und verweist auf Wrapper-Kommandos wie `wgx py up`, `wgx py sync` sowie `wgx tool add`. Damit werden klare Erwartungen an das CLI kommuniziert.【F:README.md†L50-L110】
- Das Devcontainer-Skript `.devcontainer/setup.sh` bringt einen automatisierten Installer (`setup.sh ensure-uv`) mit, der uv bei Bedarf nachzieht und `$HOME/.local/bin` dauerhaft in die Shell-Profile schreibt. So steht das Binary in Container-Umgebungen zuverlässig zur Verfügung.【F:.devcontainer/setup.sh†L1-L120】
- `wgx env doctor` überprüft uv neben weiteren Kernwerkzeugen und meldet Verfügbarkeit samt Version. Das erleichtert Fehlersuche auf Entwickler-Systemen.【F:modules/env.bash†L38-L100】
- Runbook und ADR erläutern Migration und Motivation für uv. Sie liefern gute Hintergründe und Migrationspfade von `requirements.txt` zu `uv.lock` sowie Empfehlungen für CI-Pipelines.【F:docs/Runbook.de.md†L21-L109】【F:docs/ADR-0002__python-env-manager-uv.de.md†L1-L36】

## Festgestellte Lücken

- Im `cmd/`-Verzeichnis existiert bislang kein `py.bash` oder `tool.bash`. Die in der README beworbenen Wrapper sind daher noch nicht implementiert und Nutzer:innen müssen uv manuell bedienen.【8c6536†L1-L4】
- Die Guard-/Contract-Mechanik bietet derzeit keine konkreten Prüfschritte für `uv_lock_present` oder `uv_sync_frozen`, obwohl sie in der README als Vertragskürzel erwähnt werden. Damit lassen sich die versprochenen Sicherungen noch nicht erzwingen.【F:README.md†L66-L103】
- Das Template `.wgx/profile.yml` enthält keinen `python`-Block. Neue Repos erhalten somit keine Startkonfiguration für uv-Version, Lockfile-Pflicht oder Tool-Liste, obwohl die Dokumentation dies erwartet.【F:templates/.wgx/profile.yml†L1-L7】

## Potenziale zur Verbesserung

1. **CLI-Kommandos für uv ergänzen**: Ein dediziertes `cmd/py.bash` (und optional `cmd/tool.bash`) sollte die häufigsten uv-Workflows kapseln (`up`, `sync`, `run`, `pip sync`, Tool-Management). Damit erfüllt das CLI die README-Versprechen.
2. **Contracts implementieren**: `wgx guard` sollte Regeln kennen, die `uv.lock` im Repository erzwingen und CI-Skripte auf `uv sync --frozen` prüfen. So wird die dokumentierte Governance technisch abgesichert.
3. **Profile-Template erweitern**: Das Standard-Profil kann einen kommentierten `python`-Block mit uv als Manager, gewünschter Version und Tool-Liste enthalten. Neue Projekte starten dadurch mit konsistenter Basiskonfiguration.
4. **Optionale Ergänzungen**: Beispiele für `pyproject.toml` + `uv.lock` oder ein `uv pip compile`-Howto könnten im Templates-Ordner landen. Das erleichtert Teams den Einstieg in uv-gesteuerte Repos.

Mit diesen Ergänzungen wird die uv-Integration nicht nur dokumentiert, sondern auch durch das CLI und Standardprofile erlebbar. Die vorhandenen Installations- und Diagnose-Hilfen bilden dafür bereits eine solide Grundlage.
