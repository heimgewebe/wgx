# Readiness Matrix

`scripts/gen-readiness.sh` analysiert die Verzeichnisse `modules/`, `cmd/`,
`tests/` und `docs/` und erzeugt daraus `artifacts/readiness.json`, eine
Markdown-Tabelle sowie ein SVG-Badge. Die JSON-Datei enthält für jedes Modul
den Status (`ready`, `progress`, `partial`, `seed`), die Anzahl vorhandener
Tests/Dokumente sowie einen 0–100 % Score. Wird die Matrix nicht erzeugt
(z. B. in Repos ohne Shell-Module), meldet das Skript nur eine Warnung und
liefert Exit-Code 0, damit CI-Läufe nicht brechen. Die Artefakte werden nicht
eingecheckt, sondern landen als CI-Artefakt bzw. lokal im gitignored
`artifacts/`-Verzeichnis.
