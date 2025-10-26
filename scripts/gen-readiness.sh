#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "::notice::python3 not found - skipping readiness generation"
  exit 0
fi

ARTIFACT_DIR="$REPO_DIR/artifacts"
mkdir -p "$ARTIFACT_DIR"

read -r summary_count average < <(python3 - "$REPO_DIR" "$ARTIFACT_DIR" <<'PY'
import json
import time
import sys
from pathlib import Path

repo = Path(sys.argv[1])
artifact_dir = Path(sys.argv[2])
modules_dir = repo / "modules"
cmd_dir = repo / "cmd"
docs_dir = repo / "docs"
tests_dir = repo / "tests"

names = set()
if modules_dir.is_dir():
    names.update(path.stem for path in modules_dir.glob("*.bash"))
if cmd_dir.is_dir():
    names.update(path.stem for path in cmd_dir.glob("*.bash"))

modules = sorted(names)

def iter_files(root: Path):
    if not root.exists():
        return
    for path in root.rglob("*"):
        if path.is_file():
            yield path

def count_matches(root: Path, token: str, *, docs=False):
    token_lower = token.lower()
    total = 0
    for path in iter_files(root):
        stem = path.stem.lower()
        name = path.name.lower()
        if docs and path.suffix.lower() not in {".md", ".rst", ".txt"}:
            continue
        if token_lower in stem or token_lower in name:
            total += 1
    return total

rows = []
summary_score = 0
for name in modules:
    tests = count_matches(tests_dir, name)
    docs = count_matches(docs_dir, name, docs=True)
    cli = (cmd_dir / f"{name}.bash").is_file()
    score = (1 if tests > 0 else 0) + (1 if cli else 0) + (1 if docs > 0 else 0)
    if score == 3:
        status = "ready"
    elif score == 2:
        status = "progress"
    elif score == 1:
        status = "partial"
    else:
        status = "seed"
    coverage = int(round(score * 100 / 3))
    summary_score += score
    rows.append({
        "module": name,
        "status": status,
        "tests": tests,
        "cli": cli,
        "docs": docs,
        "coverage": coverage,
    })

summary_count = len(rows)
average = int(round((summary_score * 100 / (summary_count * 3)) if summary_count else 0))

data = {
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "modules": rows,
    "summary": {"count": summary_count, "average_completion": average},
}

(artifact_dir / "readiness.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

lines = [
    "| Module | Status | Tests | CLI | Docs | Coverage |",
    "| --- | --- | --- | --- | --- | --- |",
]
if rows:
    for row in rows:
        lines.append(f"| {row['module']} | {row['status']} | {row['tests']} | {'✅' if row['cli'] else '—'} | {row['docs']} | {row['coverage']}% |")
else:
    lines.append("| _none_ | — | 0 | — | 0 | 0% |")
(artifact_dir / "readiness-table.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

color = "#4c1"
if average < 40:
    color = "#e05d44"
elif average < 70:
    color = "#dfb317"

badge = f"""<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"190\" height=\"20\" role=\"img\" aria-label=\"WGX Readiness: {average}%\">
  <linearGradient id=\"smooth\" x2=\"0\" y2=\"100%\">
    <stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"/>
    <stop offset=\"1\" stop-opacity=\".1\"/>
  </linearGradient>
  <mask id=\"round\">
    <rect width=\"190\" height=\"20\" rx=\"3\" fill=\"#fff\"/>
  </mask>
  <g mask=\"url(#round)\">
    <rect width=\"120\" height=\"20\" fill=\"#555\"/>
    <rect x=\"120\" width=\"70\" height=\"20\" fill=\"{color}\"/>
    <rect width=\"190\" height=\"20\" fill=\"url(#smooth)\"/>
  </g>
  <g aria-hidden=\"true\" fill=\"#fff\" text-anchor=\"middle\" font-family=\"Verdana,DejaVu Sans,sans-serif\" text-rendering=\"geometricPrecision\" font-size=\"110\">
    <text x=\"600\" y=\"140\" transform=\"scale(.1)\" fill=\"#fff\">WGX Readiness</text>
    <text x=\"1530\" y=\"140\" transform=\"scale(.1)\" fill=\"#fff\">{average}%</text>
  </g>
</svg>
"""
(artifact_dir / "readiness-badge.svg").write_text(badge, encoding="utf-8")

print(summary_count, average)
PY
)

if [[ -s "$ARTIFACT_DIR/readiness.json" ]]; then
  echo "Readiness matrix generated at artifacts/readiness.json (modules: $summary_count, avg: ${average}%)."
else
  echo "[readiness] ::warning:: Failed to produce readiness.json" >&2
fi
