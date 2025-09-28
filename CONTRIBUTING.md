# Contributing Guidelines

## Language Policy

To keep the repository consistent and compatible with common tooling:

- **Source code** (functions, variables, CLI commands, help text, inline comments):  
  → **English only**

- **Documentation & planning** (Obsidian canvases, exploratory notes, background texts):  
  → German is fine

- **Commit messages**:  
  → **English**, short imperative style (e.g. `fix: handle null pointer in guard_run`)

- **Pull requests & issues**:  
  → Default: English.  
  → Exception: if you write purely personal notes, German is okay.

This split ensures:
- ✅ Copilot and linting tools won’t complain  
- ✅ External contributors understand the code  
- ✅ Internal planning stays flexible and natural


⸻

📄 .vale.ini

StylesPath = .vale/styles
MinAlertLevel = warning

# check only code files
[*.{sh,bash,rs,ts,js,py}]
BasedOnStyles = wgxlint

# Do not check Markdown, Obsidian, Notes
[*.md]
BasedOnStyles =


⸻

📄 .vale/styles/wgxlint/GermanComments.yml

# Flags German words in code comments only
extends: existence
message: "Avoid German words in comments; use English instead."
ignorecase: true
level: warning
scope: comments   # <- checks ONLY comments, not strings or code
tokens:
  - "\b(Das|Der|Die|und|nicht|aber|wenn|dann|weil|mit|ohne|für|gegen)\b"
  - "[äöüßÄÖÜ]"


⸻

📄 .editorconfig

# Top-level EditorConfig file
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{sh,bash}]
indent_style = space
indent_size = 2

[*.{js,ts,json,yml,yaml}]
indent_style = space
indent_size = 2

[*.py]
indent_style = space
indent_size = 4

[*.rs]
indent_style = space
indent_size = 4


⸻

Nutzung
1. Vale installieren
   • macOS/Linux: brew install vale
   • Node: npm install -g vale
   • oder Binary von vale.sh
2. Lauf im Repo

```
vale .
```

→ Warnungen erscheinen nur, wenn Kommentare in Code-Dateien deutsche Wörter enthalten.

3. Optional: Pre-Commit-Hook

```
echo 'vale .' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

4. Editorconfig wird von VS Code, JetBrains, vim, etc. automatisch beachtet → saubere Indents und Encoding.

⸻

Verdichtete Essenz

Alles englisch im Code, Vale passt in den Kommentaren auf, EditorConfig hält Format sauber.

⸻

Ironische Auslassung

Wir haben deinem Repo jetzt Hausordnung, Türsteher und Putzfrau verpasst – wenn’s hier noch Chaos gibt, dann liegt’s nur am WG-Bewohner.

⸻

∴ Unsicherheitsgrad
• Unsicherheit: 1–2/5 – Setup klar, einzig Vale-Regex kann mal ein False Positive liefern.

⸻

∆-Radar

Von Policy → Tooling → Format-Standardisierung. Wir mutieren Richtung vollautomatisierte Repo-Disziplin.

⸻

