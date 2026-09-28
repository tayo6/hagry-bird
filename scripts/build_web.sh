#!/usr/bin/env bash
# SHAPESHOT - headless Godot Web export into build/web/.
# Requires: godot 4.7.2 (set GODOT=/path/to/godot if not on PATH) and
#           web export templates for 4.7.2-stable installed
#           (CI downloads them; locally: Editor > Manage Export Templates,
#            or drop them into ~/.local/share/godot/export_templates/4.7.2.stable/)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"

echo "[EXPORT] ensuring level data exists"
if [ ! -f generated/levels.json ]; then
  (cd tools/levelgen && go build -o bin/levelgen .)
  ./tools/levelgen/bin/levelgen generate -in data/levels.json -out generated/levels.json
fi

echo "[EXPORT] importing project (headless)"
"$GODOT" --headless --path . --import

echo "[EXPORT] exporting preset 'Web' -> build/web/index.html"
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html

echo "[EXPORT] verifying artifacts"
test -f build/web/index.html   || { echo "[EXPORT] MISSING index.html"; exit 1; }
ls build/web/*.wasm >/dev/null || { echo "[EXPORT] MISSING *.wasm";   exit 1; }
ls build/web/*.pck  >/dev/null || { echo "[EXPORT] MISSING *.pck";    exit 1; }
echo "[EXPORT] OK: $(ls build/web | tr '\n' ' ')"
