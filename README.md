# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS).  
Lizenz: MIT (projektintern).

## Nutzung
```bash
./wgx --help
git clone git@github.com:alexdermohr/wgx.git ~/.local/opt/wgx
ln -sf ~/.local/opt/wgx/wgx ~/.local/bin/wgx
# === Termux: Struktur + Basisdateien ins bereits geklonte Repo schreiben ===
# Voraussetzung: Dein privates Repo liegt unter ~/.local/opt/wgx (per git clone)

set -Eeuo pipefail
IFS=$'\n\t'

cd "$HOME/.local/opt/wgx"

# Ordnerstruktur
mkdir -p .github/workflows scripts docs tests

# README.md (ohne Markdown-Codeblöcke, damit dieser Gesamtblock copy-paste-sicher bleibt)
cat > README.md <<'EOF'
# wgx – Weltgewebe CLI

Eigenständiges CLI für Git-/Repo-Workflows (Termux, WSL, Linux, macOS).
Lizenz: MIT (projektintern).

Nutzung:
- ./wgx --help
- ./wgx version
- ./wgx selftest

Installation (Termux, privat):
1) Repo per SSH oder HTTPS (Token) nach ~/.local/opt/wgx klonen
2) Symlink setzen: ln -sf ~/.local/opt/wgx/wgx ~/.local/bin/wgx
3) PATH prüfen: export PATH="$HOME/.local/bin:$PATH"
