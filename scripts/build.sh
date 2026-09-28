#!/usr/bin/env bash
# SHAPESHOT - full local build: Go data pipeline + headless Godot web export.
# Usage: scripts/build.sh            (from repo root or anywhere)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"   # override: GODOT=/path/to/godot-4.7.2 scripts/build.sh

echo "[EXPORT] build starting in $ROOT"
"$ROOT/scripts/test.sh"
"$ROOT/scripts/build_web.sh"
echo "[EXPORT] build complete -> build/web/index.html"
