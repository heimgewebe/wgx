# wgx – Flottenmotor des Heimgewebes

Status: Konzept v1 (Bash-CLI, kein Rust-Crate)  
Scope: Orchestrierung, nicht Business-Logik

---

## 1. Rolle von wgx im Heimgewebe

**wgx** ist der Flottenmotor des Heimgewebes:

- steuert alle Repos mit denselben Befehlen,
- bündelt wiederkehrende Dev- und CI-Aufgaben,
- spricht mit Templates und Reusable-Workflows aus dem **metarepo**,
- ist selbst kein Service und macht keine KI-Logik.

Kurz: wgx ist der **Bordcomputer**, der die Flotte bedient – nicht das Gehirn (hausKI) und nicht das Gedächtnis (leitstand).

Abgrenzung:

- **hausKI**: orchestriert Denkprozesse und Agenten (Planen, Entscheiden, Reviews anstoßen).
- **leitstand**: speichert und zeigt Ereignisse (Events, Panels, Metriken).
- **wgx**: startet, überprüft, synchronisiert – lokal und in CI.

---

## 2. Was ist wgx technisch?

Aktueller Stand (v1):

- wgx ist eine **Bash-basierte CLI** (Command Line Interface),
- besteht aus Skripten und Modulen (z. B. `wgx`, `cmd/*.bash`, `lib/*.bash`),
- nutzt Konfigurationsdateien in jedem Repo, z. B. `.wgx/profile.yml`.

### CLI – kurz „für Dummies“

- CLI = Programm, das im Terminal per Textbefehlen läuft.
- Beispiele: `git status`, `just test`, `wgx doctor`.
- Du tippst einen Befehl, das Programm macht eine Aufgabe und zeigt Textausgabe.

wgx reiht sich da ein:

- `wgx doctor` – Zustand der Fleet prüfen  
- `wgx smoke` – schnelle Checks in allen Repos  
- `wgx metrics snapshot` – Metriken einsammeln  

---

## 3. Kernaufgaben von wgx

### 3.1 Fleet-Orchestrierung

wgx sorgt dafür, dass alle Repos nach denselben Mustern bedient werden können:

- einheitliche Tasks (z. B. `smoke`, `metrics`, `lint`) über `.wgx/profile.yml`,
- zentrale Befehle wie:
  - `wgx run --all just smoke`
  - `wgx metrics snapshot`
- optionaler Dry-Run-Modus, damit größere Änderungen erst simuliert werden.

### 3.2 Brücke zum metarepo

wgx arbeitet eng mit dem metarepo zusammen:

- metarepo liefert Templates und Reusable-Workflows,
- wgx hilft, diese in die Ziel-Repos auszurollen oder zu prüfen,
- typische Kombination:
  - `just up` (aus metarepo) → Templates verteilen,
  - `wgx smoke` → prüfen, ob alles noch konsistent ist.

### 3.3 CI-Unterstützung

wgx wird in CI-Jobs eingesetzt, um:

- Fleet-Healthchecks auszulösen,
- Metriken zu erfassen (`metrics.snapshot`),
- bestimmte wiederkehrende Aktionen einheitlich auszuführen.

Wichtig:  
wgx selbst ist aktuell kein Rust-Projekt. CI, die versucht, ein Rust-`wgx` zu installieren, ist fehlkonfiguriert und soll bereinigt werden.

---

## 4. Architektur (v1 – Bash)

Bausteine:

- `wgx` – Einstiegsskript (Dispatcher/Wrapper)
- `cmd/` – Unterbefehle (z. B. `metrics`, `run`, `doctor`)
- `lib/` – Hilfsfunktionen (Logging, Parallelisierung, JSONL-Helfer)
- `.wgx/profile.yml` im Repo – beschreibt:
  - Namen und Klasse des Repos,
  - welche Tasks verfügbar sind,
  - wie Standard-Tasks auszuführen sind.

Beispielhafte Profil-Information:

- Repo-Typ (z. B. `rust-service`, `python-tool`, `docs-only`),
- Standard-Task für `smoke` (z. B. `just smoke` oder `pytest`),
- Konfiguration für `metrics snapshot`.

---

## 5. Abgrenzung: „Rust-wgx“ vs. aktuelles wgx

In manchen CI-Workflows wurde versucht, wgx als Rust-Crate zu installieren:

- `cargo install wgx`  
oder
- `cargo install --git https://github.com/heimgewebe/wgx --locked wgx`

Das führt zu Problemen, weil:

- das wgx-Repo aktuell **kein `Cargo.toml`** hat,
- es keinen Rust-Crate `wgx` auf crates.io gibt.

**Klare Festlegung für v1:**

- wgx ist ein **Bash-CLI-Tool**.
- Es gibt aktuell **keinen offiziellen Rust-Nachfolger**.
- CI-Workflows sollen wgx nicht als Rust-Crate behandeln.

Erst wenn ein eigenständiges Projekt „wgx v2 (Rust)“ bewusst beschlossen wird, ändert sich das.

---

## 6. Roadmap und mögliche v2-Pfade

### 6.1 v1 – Bash stabilisieren

Kurzfristige Ziele:

- Profile-Konventionen (`.wgx/profile.yml`) vereinheitlichen,
- doppelte Skripte abbauen (z. B. mehrere Varianten von `wgx-metrics-snapshot.sh`),
- Schnittstellen zum metarepo dokumentieren (z. B. welche Reusable-Workflows von wgx typischerweise gerufen werden),
- CI-Jobs aufräumen, die ein Rust-`wgx` installieren wollen.

### 6.2 v2 – mögliche Rust-Variante (optional, später)

Ein Rust-`wgx` wäre dann sinnvoll, wenn:

- mehr State-Handling nötig ist (z. B. Cache, TUI, interaktive Menüs),
- parallele Orchestrierung komplexer wird (viele Repos, viele Jobs),
- robustere Fehlerbehandlung und strukturierte Logs gebraucht werden.

Mögliche Features einer späteren v2:

- TUI (Terminal UI) für Repo- und Task-Auswahl,
- persistenter Cache für Metriken und Fleet-Zustände,
- feingranulare Parallelisierung und Priorisierung,
- direkte Anbindung an semantAH (z. B. wgx weiß, welche Repos logisch zusammengehören).

Wichtig:  
Solange diese Anforderungen nicht wirklich anstehen, bleibt wgx bewusst in der Bash-Welt – einfacher zu pflegen, gut sichtbar, leicht zu debuggen.

---

## 7. „Für Dummies“ – wgx in einem Absatz

wgx ist ein kleines Programm für das Terminal, mit dem du alle deine Heimgewebe-Repos über dieselben Befehle steuern kannst.  
Statt in jedem Repo eigene Skripte zu merken, sagst du einfach `wgx doctor` oder `wgx smoke`, und wgx führt die passenden Kommandos pro Repo aus.  
Es ist kein Zauber, eher eine gut sortierte Werkzeugkiste für wiederkehrende Aufgaben.

---

## 8. Ungewissheitsanalyse

Quellen der Ungewissheit:

- **Übergangsphase:** Einige Repos und CI-Jobs sind noch nicht vollständig auf einheitliche wgx-/Profile-Konventionen umgestellt.
- **Zukunft von wgx:** Noch nicht klar, ob und wann ein Rust-basiertes wgx v2 wirklich nötig ist.
- **Komplexität der Fleet:** Zahl und Vielfalt der Repos kann wachsen, Anforderungen können sich ändern.

Einschätzung:

- Unsicherheitsgrad zur aktuellen Rolle von wgx: niedrig (≈ 0,2) – wgx ist klar als Bash-CLI definiert.
- Unsicherheitsgrad zur langfristigen Ausrichtung (Bash vs. Rust): mittel (≈ 0,5) – hängt von zukünftigen Anforderungen ab.

Diese Ungewissheit ist weitgehend **produktive Unschärfe**: sie erlaubt, wgx pragmatisch weiterzuentwickeln, ohne sich zu früh auf eine schwere Architektur festzulegen.

---

## 9. Essenz

wgx ist der pragmatische Flottenmotor des Heimgewebes:  
ein Bash-CLI, das Repos und Aufgaben orchestriert, ohne selbst ein weiterer komplexer Dienst zu werden.

---

## 10. Kleine Pointe

Wenn hausKI der Denker ist und leitstand das Tagebuch,  
ist wgx derjenige, der morgens den Laden aufsperrt, das Licht anmacht  
und leise fragt: „Na, wen soll ich heute zuerst antreiben?“
