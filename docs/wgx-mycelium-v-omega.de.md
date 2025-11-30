# WGX — Mycelium **v Ω**

Version: vΩ (2025-10-05) · Status-Legende: 🟢 Core · 🟡 Next · 🔬 Experimental

## Inhalt

- [0. Executive Summary (Kurzfassung)](#0-executive-summary-kurzfassung)
- [1. Problem → Prinzipien](#1-problem--prinzipien)
- [2. Bedienkanon (Kern → „Ultra“)](#2-bedienkanon-kern--ultra)
- [3. Erweiterungen (Zutrag-Synthese, neu integriert)](#3-erweiterungen-zutrag-synthese-neu-integriert)
- [4. HausKI-Memory (Gedächtnis-Ops)](#4-hauski-memory-gedächtnis-ops)
- [5. Kommandoreferenz (Index, Status, Nutzen)](#5-kommandoreferenz-index-status-nutzen)
- [6. Profile v1 / v1.1 (Minimal → Reich)](#6-profile-v1--v11-minimal--reich)
- [7. Reproduzierbarkeit & Seeds](#7-reproduzierbarkeit--seeds)
- [8. Sichtbarkeit & Evidenz](#8-sichtbarkeit--evidenz)
- [9. Fleet-Operationen](#9-fleet-operationen)
- [10. Offline, Teleport & Mobile](#10-offline-teleport--mobile)
- [11. Developer Experience (Begreifbarkeit & Sicherheit)](#11-developer-experience-begreifbarkeit--sicherheit)
- [12. Onboarding-Fahrplan (MVP → Next → Extended)](#12-onboarding-fahrplan-mvp--next--extended)
- [13. Sicherheitsmodell (Kurz)](#13-sicherheitsmodell-kurz)
- [14. Canvas-Appendix (optionale Visualisierung)](#14-canvas-appendix-optionale-visualisierung)
- [15. Für Dummies (ein Absatz)](#15-für-dummies-ein-absatz)
- [16. Verdichtete Essenz](#16-verdichtete-essenz)
- [17. Ironische Auslassung](#17-ironische-auslassung)
- [18. ∆-Radar (Regel-Evolution)](#18--radar-regel-evolution)
- [19. ∴fores Ungewissheit](#19-fores-ungewissheit)
- [20. Anhang: Kommandokarte als Einzeiler (Merkliste)](#20-anhang-kommandokarte-als-einzeiler-merkliste)

> **Leitbild:** Ein Knopf. Ein Vokabular. Ein Cockpit. Ein Gedächtnis.  
> **WGX** ist das **Repo-Betriebssystem**: vereinheitlichte Bedienung über alle Repositories und Geräte
> (Pop!_OS, Codespaces, Termux) – verstärkt durch **HausKI-Memory** für Personalisierung,
> Reproduzierbarkeit, Evidenz und Fleet-Orchestrierung.

---

## 0. Executive Summary (Kurzfassung)

- **WGX normalisiert Bedienung:** immer dieselben Knöpfe (`up | list | run | guard | smoke | doctor`),
  egal ob Just/Task/Make/npm/cargo.  
- **WGX härtet Qualität:** Contracts, Auto-Fixes, schnelle Sanity-Checks, Policy-Explain.  
- **WGX sieht Zusammenhänge:** Shadowmap (Repos ↔ Workflows ↔ Secrets ↔ Dienste), Lighthouse
  (Policies), Evidence-Packs für PRs.  
- **WGX lernt & erinnert:** Memory speichert Runs, Policies, Seeds, Artefakte; `suggest`, `optimize`,
  `forecast`, `preview`.  
- **WGX skaliert:** Fleet-Kommandos für viele Repos; Budget-Steuerung, Quarantäne, Konvois, Benchmarking.  
- **WGX bleibt portabel:** Teleport zwischen Pop!_OS, Codespaces, Termux; Offline-Bundles und Delta-Sync.

**Essenz:** Ein Bedienkanon + Policies + Sichtbarkeit + Gedächtnis ⇒ **schnellere, sichere,
reproduzierbare Entwicklung** – vom Ein-Repo bis zur Fleet.

---

## 1. Problem → Prinzipien

**Fragmentierung** (Toolzoo, Plattformen), **Unsichtbarkeit** (unklare Policies/Secrets/Abhängigkeiten),
**Nicht-Reproduzierbarkeit** (flaky, „läuft nur bei mir"), **Skalierungs-Schmerz** (viele Repos, viele
Teams).

**Prinzipien:**

1. **Universal-Knöpfe** statt Tool-Sonderwissen.  
2. **Contracts first:** Guard, Auto-Fix, Explain.  
3. **Beweisbarkeit:** Evidence-Packs an PRs.
4. **Gedächtnis-Ops:** Memory macht WGX personalisiert und reproduzierbar.  
5. **Fleet-Wirkung:** Orchestrierung mit Budget, Quarantäne, Konvois.  
6. **Offline-First & Portabilität:** Phone-Bundles, Wormhole-Gleichverhalten.  

---

## 2. Bedienkanon (Kern → „Ultra“)

### 2.1 Core (heute unverzichtbar)

- `wgx up` – Umgebung erkennen & bereitmachen (Devcontainer/Devbox/mise/direnv Fallback-Logik).  
- `wgx list` – Tasks autodiscovern (Just/Task/Make/npm/cargo) und taggen (`fast | safe | slow`).  
- `wgx run <task | freitext>` – Universal-Runner; Freitext→Semantik→Adapter (Alias-Map je Repo).  
- `wgx guard` – Contracts prüfen & **auto-fixen** (fmt, lint, vale, cspell, shellcheck, cargo fmt …).  
- `wgx smoke` – 30–90-Sekunden-Sanity (bauen, 1–2 Tests, Ports/Env OK).  
- `wgx doctor | validate` – Vertrauen in System & Repo (Prereqs, Pfade, Tokens, Profile).

### 2.2 Orchestrierung & Fluss

- `wgx fleet status|fix` – Multi-Repo Cockpit; parallele Standard-Reparaturen.  
- `wgx runbook` – klickbare Runbooks aus Markdown (Checks, Prompts, Rollbacks).  
- `wgx rituals` – goldene Pfade, z. B. `ritual ship-it` (Version→Changelog→Tag→Release Notes→CI-Gates).

### 2.3 Intelligenz & Lernfähigkeit

- `wgx suggest` – nächste sinnvolle Schritte anhand Diff/Logs/Nutzung.  
- `wgx profile learn` – Repo-Genome (Top-Tasks, Painpoints, bevorzugte Umgebungen).  
- `wgx morph` – Repo an WGX-Standards angleichen (Stil, CI, Tasks, Profile).

### 2.4 Zeit, Budget, Repro

- `wgx chrono` – Night-Queues, CPU-Budget, CI-Minutes-Autopilot.  
- `wgx timecapsule` – Zeitreise-Runs mit Versions-Pinning (mise/devbox/devcontainer-Metadaten).  
- `wgx chaos` – Fail-Fast-Sandbox (Low-RAM/Slow-IO) auf wichtigste Pfade.

### 2.5 Teleport & Ephemeres

- `wgx wormhole` – gleiches Verhalten Pop!_OS ↔ Codespaces ↔ Termux.  
- `wgx spin #123` – Issue/PR → ephemere Dev-Env (Ports, Seeds, Fixtures).

### 2.6 Sichtbarkeit & Sicherheit

- `wgx shadowmap` – Repos ↔ Workflows ↔ Secrets ↔ Dienste visualisieren (siehe [Abschnitt 8](#8-sichtbarkeit--evidenz)).
- `wgx lighthouse` – Policy-Diff erklären + One-Click-Fix; Compliance-Modes (`strict | balanced | fast`).
- `wgx patchbay` – signierte Mini-PRs; `patchbay guardfix` für Serien-Fixes.

### 2.7 Brücken & Offline

- `wgx bridge` – HausKI/Codex/NATS-Backchannel (Agenten koordinieren Patches/Reviews).  
- `wgx phone` – Offline-Bundles für Termux (Docs/Lints/Seeds), später Sync.

### 2.8 „Ultra“ Module (Visionär, aber konkret anschlussfähig)

- **WGX Studio** (TUI/Web-UI): Tasks, Fleet-Status, Shadowmap, Ritual-Knöpfe.  
- **Ritual-Recorder → Runbook-Generator**: ausführen, aufzeichnen, wiederholen.  
- **WGX Registry**: Profile/Rituale als Snippets teilen („Rust-Starter“, „SvelteKit-Docs-Lint“, „Audio-Bitperfect“).  
- **Evidence-Packs**: `wgx evidence` hängt Logs/Smoke/Guard/Coverage kompakt an PRs.  
- **Smoke-Orchard**: Fleet-Parallelisierung mit Budget/Quoten (`--budget`, `--concurrency=auto`).  
- **Seeds**: `wgx seeds snapshot|apply` (kleine, anonymisierte, deterministische Datensätze).

---

## 3. Erweiterungen (Zutrag-Synthese, neu integriert)

> **Status-Legende:** 🟢 Core · 🟡 Next · 🔬 Experimental

### 3.1 Erklärbarkeit & Simulation

- **`wgx explain <topic>`** 🟡 – erklärt Aktionen/Fehler/Policies kontextuell; verlinkt Run-Historie & Docs.  
- **`wgx diff <A>..<B>`** 🟡 – vergleicht Env/Seeds/Artefakte/Timecapsule-Runs/Repos.  
- **`wgx simulate run <task>`** 🔬 – Kosten-/Fehler-Vorschau (nutzt `chrono` & `smoke`-Historie).

### 3.2 Repro & Snapshots

- **`wgx checkpoint save|restore <name>`** 🟡 – Ad-hoc-Schnappschüsse (Code, Env, Seeds, Artefakte).  
- **`wgx timecapsule diff <t1> <t2>`** 🟡 – Tool-/Seed-Änderungen zwischen zwei Runs.

### 3.3 Fleet & Skalierung

- **`wgx fleet sync`** 🟡 – `.wgx/profile.yml`/`rituals` über Repos synchronisieren (mit Merge-Strategie).  
- **`wgx fleet benchmark`** 🟡 – vergleicht Smoke-Dauer, CI-Minuten, Flakiness, schlägt Optimierungen vor.  
- **`wgx fleet ripple`** 🟡 – Änderungs-Ausbreitung (Dependency-Kaskaden) erkennen.  
- **`wgx convoy`** 🔬 – koordinierte Multi-Repo-Releases mit atomarem Rollback.  
- **`wgx quarantine`** 🟡 – isoliert „rote“ Repos, blockiert sie nicht fleet-weit.

### 3.4 Vorhersage & Optimierung

- **`wgx preview`** 🟡 – Preflight-Analyse vor PR (Bruchrisiken, Doku-Drift, Downstream-Impact; siehe
  [Abschnitt 12](#12-onboarding-fahrplan-mvp--next--extended) für MVP-Staffelung).
- **`wgx forecast`** 🟡 – Flakiness-/Dauer-/Risikoprognose (historische Muster).  
- **`wgx optimize`** 🟡 – Vorschläge: Parallelisierung, Caches, geänderte Testpfade; misst Einsparungen.  
- **`wgx fuel --show|--limit`** 🟡 – Ressourcen/„Kosten“ (CI-Minuten, Spin-Runtime, Cache-Größe) sichtbar begrenzen.

### 3.5 Sichtbarkeit, Sicherheit & Compliance

- **`wgx audit`** 🟡 – Security/Compliance-Report (veraltete Secrets, ungenutzte Tokens, Scope-Drift).  
- **`wgx shadowmap --interactive`** 🟡 – interaktive TUI/Web-UI für Abhängigkeits-Graph.  
- **Secret-Rotation-Trigger** 🟡 – `lighthouse` empfiehlt Rotation (Alter, Wiederverwendung, Scope).  
- **`wgx policy simulate`** 🔬 – Wirkung neuer Policies auf Historiendaten simulieren.  
- **`wgx compliance diff`** 🔬 – Policy-Deckung über Repos/Teams vergleichen.  
- **`wgx audit trail`** 🔬 – forensische Nachvollziehbarkeit aller WGX-Aktionen.

### 3.6 Offline & Mobility

- **`wgx phone mirror`** 🟡 – Delta-Sync von Memory/Artefakten/Runbooks auf Termux (sparsam).  
- **`wgx phone suggest`** 🟡 – komprimierter Offline-Speicher mit lokalen Vorschlägen.  
- **`wgx bundle export|import`** 🟡 – komplette WGX-Umgebung paketieren/transferieren.

### 3.7 Community & Registry

- **WGX Registry (Marketplace)** 🟡 – Snippets/„Community Rituals“ mit Ratings & Kompatibilitäts-Tags.
- **`wgx federate`** 🔬 – Multi-Org-Fleet-Status koordinieren (Partner-Teams).  
- **`wgx vendor`** 🟡 – Dependency-Scanner/Advisories in WGX-Flows integriert.

### 3.8 Developer Experience

- **`wgx undo`** 🟡 – Transaktions-Wrapper für schreibende Aktionen (`guardfix`, `morph`, `patchbay`).  
- **`wgx shell`** 🟡 – interaktive REPL-ähnliche Shell mit Kontext/Autovervollständigung.  
- **`wgx aliases learn`** 🟡 – beobachtet Muster/Tippfehler, schlägt personalisierte Aliase vor.  
- **`wgx replay <session>`** 🟡 – Sitzung aufzeichnen → Runbook.  
- **Onboarding Wizard (`wgx tour`)** 🟢 – geführtes Setup + Profile-Generator.  
- **Gamification (`wgx stats`)** 🔬 – zeigt Einsparungen/Erfolge, motiviert „Goldene Pfade“.

### 3.9 Automation & Resilienz

- **`wgx autopilot`** 🔬 – supervised Mode; Routine-Tasks selbständig, nur bei Anomalien prompten.  
- **`wgx scheduler cron`** 🟡 – zeitgesteuerte Fleet-Operationen (z. B. wöchentliche Smoke-Orchard).  
- **`wgx emergency`** 🔬 – Incident-Protokoll: Auto-Rollback, Benachrichtigungen, Berichte.

### 3.10 Visualisierung (weitere)

- **`wgx topology`** 🔬 – 2D/3D-Dependency-Maps, Critical-Path-Highlighting.  
- **`wgx heatmap realtime`** 🔬 – Live-Dashboard (Last, Flakiness, Deploy-Status).  
- **`wgx story`** 🟡 – Release Notes aus Git/PR/Evidence generieren.

### 3.11 Advanced & Experimental

- **`wgx ai pair`** 🔬 – Code-Assistenz mit WGX-Kontext.  
- **`wgx quantum test`** 🔬 – probabilistischer Readiness-Score.  
- **`wgx blockchain evidence`** 🔬 – unveränderliche Evidence-Packs (High-Assurance-Umgebungen).

---

## 4. HausKI-Memory (Gedächtnis-Ops)

### 4.1 Wirkung (auf Kommandos gemappt)

- `up` – **Device-Profile** laden; bewährte Toolchains/Flags pro Gerät.  
- `list | run` – **semantisches Aliasing** je Repo („docs prüfen“ → `vale+cspell+linkcheck`).  
- `guard` – **Policy-Historie** priorisiert häufige Verstöße + direkte Fix-Shortcuts.  
- `smoke` – **kürzester aussagekräftiger Pfad** aus Mess-Historie.  
- `chrono` – **billige Zeitfenster** für teure Jobs.  
- `timecapsule` – **Env-Pins** (Tool-/Seed-Fingerprints) für echte Zeitreisen.  
- `runbook | rituals` – **klickbare Abläufe** mit Erfolgsscores.  
- `fleet` – **Trends/Heatmaps/Budget** aus Fleet-Gedächtnis.

### 4.2 Minimal-Datenmodell (vereinfachte Entitäten)

- **repo**: id, url, tags, default_tasks  
- **env**: os, cpu/gpu, toolversions, devcontainer_hash  
- **run**: ts, task, args, duration, exit, artefacts[], logs_hash  
- **policy_event**: rule, outcome, fix_link, auto_fixable?  
- **evidence_pack**: files[], summary, linked_pr  
- **seed_snapshot**: name, schema_version, export_cmd, checksum  
- **secret_ref**: provider-Ref, kein Klartext  
- **preference**: key→value („prefer_nextest“, „db_light“)

### 4.3 On-Disk (git-freundlich, lokal)

```text
.hauski/
  memory.sqlite          # Runs, Policies, Prefs
  vector/                # Textindex (Logs/Docs)
  cas/xx/xx/<sha256>     # Artefakte (content-addressed)
  seeds/<name>@<ver>.tgz # deterministische Testdaten
  evidence/<pr#>-<ts>.zip
  profiles/<repo>.yml    # learned aliases
```

### 4.4 Security

- **Keine Klartext-Secrets.** Nur **secret_ref** (sops/age/Provider-IDs).  
- Policies prüfen Vorhandensein/Konfiguration, **nie** Inhalte.

### 4.5 API-Kleber

- local-first Dienst: `hauski-memoryd` (HTTP/NATS).  
- WGX spricht via `wgx … --use-memory` (RW).  
- Sync als **Memory Packs** (`zip/tar`, ohne Secrets) für Transfer/Git/rsync.

---

## 5. Kommandoreferenz (Index, Status, Nutzen)

| Kategorie | Kommando | Status | Nutzen (Einzeiler) |
|---|---|:---:|---|
| Core | `up` | 🟢 | Umgebung erkennen & fertig machen |
| Core | `list` | 🟢 | Tasks autodiscovern & taggen |
| Core | `run <task\|text>` | 🟢 | Intent → richtiges Kommando |
| Core | `guard` | 🟢 | Contracts prüfen + auto-fix |
| Core | `smoke` | 🟢 | 30–90s Gesundheitscheck |
| Core | `doctor \| validate` | 🟢 | System/Repo-Diagnose |
| Flow | `runbook` | 🟡 | Klickbare Abläufe aus Markdown |
| Flow | `rituals` | 🟡 | Goldene Pfade (Release etc.) |
| Fleet | `fleet status\|fix` | 🟡 | Multi-Repo-Cockpit |
| Fleet | `fleet benchmark` | 🟡 | Dauer/Flake/CI-Vergleich |
| Fleet | `fleet ripple` | 🟡 | Abhängigkeits-Kaskaden |
| Fleet | `convoy` | 🔬 | Koordinierte Releases |
| Fleet | `quarantine` | 🟡 | Isoliert rote Repos |
| Intel | `suggest` | 🟡 | Nächste sinnvolle Schritte |
| Intel | `profile learn` | 🟡 | Repository-Genome |
| Intel | `morph` | 🟡 | Migration zu Standards |
| Repro | `chrono` | 🟡 | Zeit/CPU/CI-Budget |
| Repro | `timecapsule` | 🟡 | Versions-Pinning |
| Repro | `checkpoint` | 🟡 | Ad-hoc-Snapshot |
| Teleport | `wormhole` | 🟡 | Gleichverhalten über Geräte |
| Teleport | `spin` | 🟡 | Ephemere Dev-Env |
| Sichtb. | `shadowmap` | 🟡 | Beziehungen sichtbar |
| Sichtb. | `lighthouse` | 🟡 | Policy-Diff + Fix |
| Sichtb. | `patchbay` | 🟡 | signierte Mini-PRs |
| Offline | `phone` | 🟡 | Offline-Bundles |
| Offline | `bundle` | 🟡 | Export/Import WGX-Setup |
| Explain | `explain` | 🟡 | Kontexte/Fehler erklären |
| Simul. | `simulate run` | 🔬 | Kosten/Fehler-Vorschau |
| Diff | `diff` | 🟡 | Env/Artefakt/TC-Diff |
| Opt. | `optimize` | 🟡 | Laufzeit-/Ressourcen-Tipps |
| Forecast | `preview` | 🟡 | Pre-PR Wirkung |
| Forecast | `forecast` | 🟡 | Flake/Dauer-Prognose |
| Budget | `fuel` | 🟡 | Kosten sichtbar/Limit |
| Audit | `audit` | 🟡 | Sec/Compliance Report |
| Policy | `policy simulate` | 🔬 | Regeldry-run |
| Policy | `compliance diff` | 🔬 | Team-Vergleich |
| Trail | `audit trail` | 🔬 | Forensik |
| Team | `sync` | 🟡 | Team-Gedächtnis |
| Knowl. | `knowledge` | 🟡 | Vektor-Q&A (Docs/Logs) |
| UX | `undo` | 🟡 | „Oops“-Taste |
| UX | `shell` | 🟡 | Interaktiver Modus |
| UX | `aliases learn` | 🟡 | Komfort-Aliase |
| UX | `replay` | 🟡 | Session → Runbook |
| Auto | `autopilot` | 🔬 | supervised Automation |
| Auto | `scheduler cron` | 🟡 | Zeitpläne |
| Resil. | `emergency` | 🔬 | Incident-Protokoll |
| Viz | `topology` | 🔬 | 2D/3D-Graph |
| Viz | `heatmap realtime` | 🔬 | Live-Status |
| Viz | `story` | 🟡 | Release Notes |
| Exp. | `ai pair` | 🔬 | Code-Assistent |
| Exp. | `quantum test` | 🔬 | Prob. Readiness |
| Exp. | `blockchain evidence` | 🔬 | Unveränderliche Beweise |

---

## 6. Profile v1 / v1.1 (Minimal → Reich)

### Minimal v1

```yaml
# .wgx/profile.yml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0"
  repoKind: "generic"
  tasks:
    dev:   "just dev || npm run dev || cargo run"
    test:  "just test || npm test || cargo test --workspace"
    lint:  "just lint || npm run lint || cargo clippy -- -D warnings"
    fmt:   "just fmt  || npm run fmt  || cargo fmt"
alias:
  "docs prüfen": ["vale", "cspell", "linkcheck"]
```

#### Erweitert v1.1

```yaml
wgx:
  apiVersion: v1.1
  requiredWgx: { semver: "^2.0", mode: "strict" }
  repoKind: "rust-app"
  tasks:
    test:
      cmd: ["cargo", "nextest", "run", "--workspace"]
      desc: "Schneller Testlauf"
      group: "ci"
      safe: true
  envDefaults:
    prefer: [devcontainer, devbox, mise]
  contracts:
    style: true
    format: true
  ci:
    template: "github-actions-basic"
```

---

## 7. Reproduzierbarkeit & Seeds

**Timecapsule:** speichert Toolversions/Env-Hash/Seeds/Artefakt-Fingerprints → `wgx timecapsule run --at=2025-06-12`.  
**Seeds:** kleine, anonymisierte Datensätze → `wgx seeds snapshot|apply`.  
**Checkpoint:** *ad hoc* Snapshots für Refactor/Debug → `save "pre-refactor"` → `restore`.

---

## 8. Sichtbarkeit & Evidenz

- **Shadowmap:** gerichteter Graph (Repos↔Workflows↔Secrets↔Dienste) als TUI/Web-UI.  
- **Lighthouse:** erklärt Policy-Diffs, **One-Click-Fix**, Moduswahl (`strict|balanced|fast`).  
- **Evidence-Packs:** Zip mit Logs/Smoke/Guard/Coverage an PRs anhängen (`wgx evidence attach #123`).  
- **Audit/Audit-Trail:** Reports + forensische Kette für Compliance-Teams.

---

## 9. Fleet-Operationen

- **Status/Fix:** Health Überblick; Standard-Heilungen parallel.  
- **Smoke-Orchard:** `--budget` & adaptive `--concurrency`.  
- **Benchmark:** Dauer/Flake/CI-Minuten pro Repo; Optimierungsvorschläge.  
- **Ripple/Convoy/Quarantine:** Kaskaden erkennen; koordinierte Releases; Isolation kranker Repos.

---

## 10. Offline, Teleport & Mobile

- **Wormhole:** identische Semantik der Knöpfe über Geräte.  
- **Phone:** Offline-Bundles (Docs/Lints/Seeds), später Sync.  
- **Mirror/Bundle:** Delta-Updates; komplette WGX-Export/Import.

---

## 11. Developer Experience (Begreifbarkeit & Sicherheit)

- **Explain:** konkrete Ursachen, letzte Vorkommen, Fix-Knopf.  
- **Undo:** Transaktion für schreibende Aktionen.  
- **Shell:** kontextbewusste REPL mit `suggest`/Runbook-Schritten.  
- **Tour/Playground:** geführter Start; gefahrloses Ausprobieren.  
- **Stats/Gamification:** Einsparungen sichtbar machen.

---

## 12. Onboarding-Fahrplan (MVP → Next → Extended)

**MVP (Woche 1):**
`up · list · run · guard · smoke · doctor|validate` + `.wgx/profile.yml v1`.

**Next Ring:**
`fleet status|fix · rituals ship-it · runbook · suggest · checkpoint · optimize`.

**Extended:**
`chrono · timecapsule · chaos · spin · lighthouse · shadowmap · patchbay · phone · audit · fuel · forecast · preview`.

```text
MVP Woche 1 → up · list · run · guard · smoke · doctor|validate + .wgx/profile.yml (v1)
Next Ring  → fleet status|fix · rituals ship-it · runbook · suggest · checkpoint · optimize
Extended   → chrono · timecapsule · chaos · spin · lighthouse · shadowmap · patchbay · phone · audit ·
             fuel · forecast · preview
```

**Done-Kriterien (Kern):**  

- `wgx run` mappt Just/Task/npm/cargo und propagiert Exit-Codes korrekt.  
- `guard` mit ≥3 Auto-Fix-Typen (fmt/lint/docs) + Explain-Links.  
- `smoke` ≤90 s, klarer Ampel-Status.  
- `.wgx/profile.yml` enthält `topTasks`, `env.prefer`, `contracts`, optional `ci.template`.

---

## 13. Sicherheitsmodell (Kurz)

- Secrets nur als **Referenzen** (sops/age/Provider).  
- `lighthouse` kann Rotation vorschlagen + Regelerfüllung prüfen.  
- `audit trail` für Prüfbarkeit; **Evidence-Packs** ohne personenbezogene Daten.  
- **Least Privilege** Defaults in CI-Vorlagen (Templates).

---

## 14. Canvas-Appendix (optionale Visualisierung)

- **Farben:** Blau=Zentrum/Meta, Grau=Grundlagen, Gelb=Prozesse, Rot=Hindernisse, Grün=Ziele, Violett=Ebenen.  
- **Logik:** Links Grundlagen, Mitte Prozesse, Rechts Ziele (optional). Vertikal: unten konkret, oben abstrakt.  
- **Knoten:** Root enthält Quelle; Essenz-Knoten prägnant; Meta-Knoten ohne Allverbindungen.  
- **Verbindungen:** nur sachdienlich, sparsam; Labels nutzen.  
- **Legende-Knoten (verpflichtend):** Farbzuordnung, Achsen-Logik, Freiheiten.

---

## 15. Für Dummies (ein Absatz)

**WGX ist deine Universalfernbedienung fürs Coden.** Du merkst dir drei Knöpfe: `wgx up` (Bühne
hinstellen), `wgx list` (Knöpfe anzeigen), `wgx run <…>` (richtig ausführen). `guard` räumt automatisch
Kleinkram weg, `smoke` prüft fix, ob alles gesund ist. WGX merkt sich, was bei **dir** funktioniert,
erklärt Fehler und liefert Belege für PRs. Läuft am Laptop, im Browser (Codespaces) und auf dem Handy
(Termux).

---

## 16. Verdichtete Essenz

**WGX = Bedienkanon + Policies + Sichtbarkeit + Gedächtnis.**  
Einheitliche Knöpfe → sichere Abläufe → sichtbare Beweise → reproduzierbare Ergebnisse – vom Einzelrepo zur Fleet.

---

## 17. Ironische Auslassung

Andere schreiben Playbooks, die niemand liest.  
WGX **spielt** sie – mit Applaus-Knopf: `ritual ship-it`. 🎬

---

## 18. ∆-Radar (Regel-Evolution)

- **Verstärkung:** Ein-Knopf-Rituale, Fleet-Skalierung, Policy-Transparenz, Evidence als erste Klasse.  
- **Seitwärtsmutation:** Studio/Registry/Marketplace, Seeds, Smoke-Orchard, Explain/Optimize/Forecast.  
- **Straffung:** Kern auf 6–7 Kommandos verdichtet; alles weitere dockt an und bleibt optional.

---

## 19. ∴fores Ungewissheit

**Grad:** ▮▮▮▯▯ ≈ 35–40 %  
**Ursachen:** Adapter-Feinheiten (npm/just/task/cargo), sauberes Versions-Pinning, Seed-Governance,
sops/age-Schlüssel, Offline-Sync-Konflikte, Fleet-Semantik in Edge-Fällen.  
**Charakter:** **produktive** Unschärfe → optimal für MVP-Spikes mit echten Repos/PRs; modular ausbaubar.

---

## 20. Anhang: Kommandokarte als Einzeiler (Merkliste)

`up` Bühne · `list` Knöpfe · `run` drücken · `guard` aufräumen · `smoke` gesund? ·  
`doctor|validate` vertrauen · `runbook` klickbar · `rituals` choreografiert · `fleet` Überblick ·  
`chrono` günstig · `timecapsule` reproduzierbar · `checkpoint` sichern · `chaos` stressen · `spin` ephemer ·  
`wormhole` überall gleich · `lighthouse` erklärt · `shadowmap` sichtbar · `patchbay` heilt ·  
`explain` versteht · `diff` vergleicht · `simulate` prognostiziert · `optimize` spart · `preview/forecast` warnt ·  
`fuel` deckelt · `audit` prüft · `policy simulate` testet · `compliance diff` vergleicht ·  
`undo` beruhigt · `shell` begleitet · `replay` lehrt · `phone/bundle` nimmt offline mit.
