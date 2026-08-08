# Leitlinie: Shell-Quoting

Diese Leitlinie beschreibt den verbindlichen Umgang mit Shell-Quoting im WGX-Repository.

## Grundsätze

1. **Variablenexpansion standardmäßig quoten.**

   ```bash
   printf '%s\n' "$value"
   ```

2. **Arrays elementweise expandieren.**

   ```bash
   command "${args[@]}"
   ```

3. **Command-Substitution quoten, wenn das Ergebnis ein einzelnes Argument ist.**

   ```bash
   root="$(git rev-parse --show-toplevel)"
   ```

4. **Explizite Wortaufspaltung nur dokumentiert verwenden.** Wenn ein Wert als
   Argumentliste interpretiert werden soll, ist ein Array gegenüber absichtlichem
   unquotiertem Expandieren zu bevorzugen.

5. **Dateinamen mit `--` von Optionen trennen.**

   ```bash
   rm -- "$path"
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
- Neue Shell-Komponenten werden vor dem Commit mit den repository-eigenen
  Shell-CI-Befehlen geprüft (`bash -n`, `shfmt -d`, `shellcheck -x -S style`).

## Quick-Check

Vor jedem Commit folgende Fragen beantworten:

- Sind alle Expansions (Variablen, Command-Substitutions, Pfade) gequotet?
- Wird beim Iterieren über Arrays `"${array[@]}"` benutzt?
- Bestehen die repository-eigenen Shell-CI-Befehle ohne neue Ausnahmen?

Wenn eine dieser Fragen mit „nein“ beantwortet wird, muss der Code nachgebessert
werden.
