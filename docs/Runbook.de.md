# Runbook: wgx CLI

> Englische Version: [Runbook.en.md](Runbook.en.md)

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

- Python-Umgebung aktivieren (`.venv/bin/activate` oder `pipx run`).
- Fehlende Abhängigkeiten mit `pip install -r requirements.txt` nachinstallieren.
- Bei globaler Installation prüfen, ob Version mit zentralem Contract kompatibel ist.

### `sudo apt-get update -y` schlägt mit „unsigned/403 responses" fehl

- Tritt häufig in abgeschotteten Netzen oder nach dem Hinzufügen externer Repositories auf. Prüfe zunächst die Systemzeit und ob ein Proxy/TLS-Intercepter im Einsatz ist (`echo $https_proxy`).
- Alte Paketlisten entfernen und neu herunterladen:

  ```bash
  sudo rm -rf /var/lib/apt/lists/*
  sudo apt-get clean
  sudo apt-get update
  ```

- Für zusätzliche Repositories sicherstellen, dass der passende Signatur-Schlüssel hinterlegt ist (statt `apt-key` den neuen Keyring-Weg nutzen):

  ```bash
  # Beispiel: Docker-Repository hinzufügen
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update
  # Ersetze ggf. 'docker', die URL, 'jammy' (Distribution) und 'stable' (Komponenten) entsprechend deiner Quelle.
  ```

- Bleibt der Fehler bestehen, das Log (`/var/log/apt/term.log`) prüfen. Bei 403-Antworten hilft oft ein Mirror-Wechsel oder das Entfernen veralteter Einträge in `/etc/apt/sources.list.d/`.

### Git-Hooks blockieren Commits

- `wgx lint` manuell ausführen, um Fehler zu sehen.
- Falls Hook veraltet ist, Repository aktualisieren und `wgx setup` erneut laufen lassen.

## Tipps für Termux

- Termux-Repo aktualisieren (`pkg update`), bevor Python/Node installiert wird.
- Essentials installieren: `pkg install jq git python`.
- `pipx` ergänzen (`pip install pipx && pipx ensurepath`), um `wgx` isoliert zu nutzen.
- Speicherzugriff auf das Projektverzeichnis gewähren (`termux-setup-storage`).

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
