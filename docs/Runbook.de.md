# Runbook: wgx CLI

> Englische Version: [Runbook.en.md](Runbook.en.md)

## Laufzeitabhängigkeiten

WGX v1 nutzt Bash als CLI-Kern, setzt für das Parsen von `.wgx/profile.yml` aber bewusst auf Python 3 mit dem `pyyaml`-Modul.
In der CI und im Devcontainer werden diese Pakete automatisch installiert (z.B. über das Paket `python3-yaml` unter Debian/Ubuntu).

Auf lokalen Maschinen sollten mindestens folgende Komponenten vorhanden sein:

- Bash ≥ 4
- Git und gängige Coreutils (`sed`, `awk`, `grep`, `find`, …)
- Python 3 mit `pyyaml`

Beispiele:

- Debian/Ubuntu: `sudo apt install python3-yaml`
- macOS (Homebrew): `brew install python && pip3 install pyyaml`

## Quick-Links

- Contract-Kompatibilität prüfen: `wgx validate`
- Linting ausführen (auch für Git-Hooks): `wgx lint`
- Umgebung diagnostizieren: `wgx doctor`

## Häufige Fehler und Lösungen

### `profile.yml` wird nicht gefunden

- Prüfen, ob das Arbeitsverzeichnis korrekt gesetzt ist (z. B. Projektwurzel).
- Mit `wgx profile list` sicherstellen, dass das Profil geladen werden kann.
- Falls mehrere Profile vorhanden sind, den Pfad per `WGX_PROFILE_PATH` explizit setzen.

### `wgx`-Befehl schlägt mit Python-Fehlern fehl

- `wgx py up` ausführen, damit uv die im Profil hinterlegte Python-Version bereitstellt.
- `wgx py sync` starten, um Abhängigkeiten anhand des `uv.lock`-Files konsistent zu installieren.
- Falls ein Repository noch kein Lockfile besitzt, `uv pip sync requirements.txt` verwenden und anschließend
  `wgx py sync` etablieren.
- Bei globaler Installation prüfen, ob Version mit zentralem Contract kompatibel ist.

### `sudo apt-get update -y` schlägt mit „unsigned/403 responses" fehl

- Tritt häufig in abgeschotteten Netzen oder nach dem Hinzufügen externer Repositories auf. Prüfe zunächst die
  Systemzeit und ob ein Proxy/TLS-Intercepter im Einsatz ist (`echo $https_proxy`).
- Alte Paketlisten entfernen und neu herunterladen:

  ```bash
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get clean
  sudo apt-get update
  ```

- Für zusätzliche Repositories sicherstellen, dass der passende Signatur-Schlüssel hinterlegt ist (statt `apt-key`
  den neuen Keyring-Weg nutzen):

  ```bash
  # Beispiel: Docker-Repository hinzufügen
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update
  # Ersetze ggf. 'docker', die URL, 'jammy' (Distribution) und 'stable' (Komponenten) entsprechend deiner Quelle.
  ```

- Bleibt der Fehler bestehen, das Log (`/var/log/apt/term.log`) prüfen. Bei 403-Antworten hilft oft ein
  Mirror-Wechsel oder das Entfernen veralteter Einträge in `/etc/apt/sources.list.d/`.

### Git-Hooks blockieren Commits

- `wgx lint` manuell ausführen, um Fehler zu sehen.
- Falls Hook veraltet ist, Repository aktualisieren und `wgx setup` erneut laufen lassen.

## Tipps für Termux

- Termux-Repo aktualisieren (`pkg update`), bevor Python/Node installiert wird.
- Essentials installieren: `pkg install jq git python`.
- `uv` als Single-Binary in `$HOME/.local/bin` installieren:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
  . ~/.profile
  ```

- Danach `wgx py up` ausführen – uv verwaltet Python-Versionen und virtuelle Umgebungen ohne zusätzliche Tools.
- Speicherzugriff auf das Projektverzeichnis gewähren (`termux-setup-storage`).

## Leitfaden: Von `requirements.txt` zu uv

1. Vorhandene Abhängigkeiten synchronisieren:

   ```bash
   uv pip sync requirements.txt
   ```

2. Projektmetadaten definieren (`pyproject.toml`), sofern noch nicht vorhanden.
3. Lockfile erzeugen und ins Repository aufnehmen:

   ```bash
   uv lock
   git add uv.lock
   ```

4. Für CI und lokale Entwickler `wgx py sync` dokumentieren; im Fehlerfall `uv sync --frozen` nutzen.
5. Optional weiterhin Artefakte exportieren (`uv pip compile --output-file requirements.txt`).

## CI mit uv (Kurzüberblick)

- uv installieren (z. B. per `curl -LsSf https://astral.sh/uv/install.sh | sh`).
- Globalen Cache cachen: `~/.cache/uv` mit einem Key aus uv-Version (`uv --version | awk '{print $2}'`) sowie
  `pyproject.toml` + `uv.lock`.
- Abhängigkeiten strikt via `uv sync --frozen` installieren.
- Tests mit `uv run …` starten (z. B. `uv run pytest -q`).

## Tipps für VS Code (Remote / Dev Containers)

- Die `profile.yml` als Workspace-File markieren, damit Änderungen synchronisiert werden.
- Aufgaben (`wgx`-Tasks) als VS Code Tasks integrieren, um Befehle mit einem Klick zu starten.
- Bei Dev Containers sicherstellen, dass das Volume die `~/.wgx`-Konfiguration persistiert, z. B.:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.wgx,target=/home/vscode/.wgx,type=bind,consistency=cached"
  ]
}
```

- Nutze `.devcontainer/setup.sh ensure-uv`, damit uv nach dem Container-Start verfügbar ist (inklusive PATH-Anpassung).
