# Leitlinie: Shell-Quoting

Diese Leitlinie definiert einen verpflichtenden Grundstock für sicheres
Quoting in allen Bash-Skripten des Repositories. Sie ergänzt ShellCheck und
shfmt, ersetzt sie aber nicht.

## Zielsetzung

- **Vermeidung von Word-Splitting und Globbing:** Unkontrollierte
  Parameter-Expansion darf keine zusätzlichen Argumente erzeugen.
- **Stabile Übergabe von Daten:** Ausgaben von Subkommandos werden immer als
  ganze Zeichenketten übergeben.
- **Reproduzierbare Linter-Ergebnisse:** ShellCheck bleibt Referenz für neue
  Regeln; diese Leitlinie legt das Minimum fest, bevor ShellCheck greift.

## Baseline-Regeln

1. **Alle Variablen-Expansions quoten** – selbst bei offensichtlichen Fällen.
   ```bash
   printf '%s\n' "${repo_root}"
   mapfile -t lines < <(git status --short)
   ```
2. **Arrays immer mit `[@]` und Quotes verwenden.**
   ```bash
   for path in "${files[@]}"; do
     printf '→ %s\n' "$path"
   done
   ```
3. **Command-Substitutions sofort quoten.**
   ```bash
   latest_tag="$(git describe --tags --abbrev=0)"
   ```
4. **`printf` statt `echo` für kontrollierte Ausgaben nutzen.** So bleiben
   Backslashes, führende Bindestriche oder `-n` wörtlich erhalten.
5. **`read` nur mit `-r` verwenden.** Damit werden Backslashes nicht
   interpretiert:
   ```bash
   while IFS= read -r line; do
     printf '%s\n' "$line"
   done <"$file"
   ```
6. **Pfadangaben vor Globbing schützen.** Vor dem Gebrauch `set -f` bzw.
   `noglob` oder frühzeitig quoten:
   ```bash
   cp -- "$src" "$dst"
   ```
7. **Keine nackten `eval`-Aufrufe.** Falls unvermeidbar: dokumentieren,
   Eingabe vorher streng validieren.

## Überprüfung

- ShellCheck muss ohne Ignorieren von Quoting-Warnungen (`SC2086`, `SC2046`,
  `SC2016`, …) bestehen.
- shfmt darf keine Änderungen an bereits formatierten Quoting-Blöcken vornehmen.
- Neue Shell-Komponenten liefern einen kurzen Selfcheck (`wgx lint`) vor dem
  Commit.

## Quick-Check

Vor jedem Commit folgende Fragen beantworten:

- Sind alle Expansions (Variablen, Command-Substitutions, Pfade) gequotet?
- Wird beim Iterieren über Arrays `"${array[@]}"` benutzt?
- Besteht `wgx lint` ohne neue ShellCheck-Ausnahmen?

Wenn eine dieser Fragen mit „nein“ beantwortet wird, muss der Code nachgebessert
werden.
