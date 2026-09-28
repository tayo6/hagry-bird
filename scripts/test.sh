#!/usr/bin/env bash
# SHAPESHOT - all automated checks: Go tests, level generation+validation,
# file-presence validation, and a headless Godot smoke test.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"

echo "[GO DATA] go test ./tools/levelgen"
(cd tools/levelgen && go vet ./... && go test ./...)

echo "[GO DATA] building levelgen"
(cd tools/levelgen && go build -o bin/levelgen .)

echo "[GO DATA] generating generated/levels.json from data/levels.json"
./tools/levelgen/bin/levelgen generate -in data/levels.json -out generated/levels.json
./tools/levelgen/bin/levelgen validate -in generated/levels.json

echo "[EXPORT] static project validation"
./scripts/validate.sh

if command -v "$GODOT" >/dev/null 2>&1 || [ -x "$GODOT" ]; then
  echo "[BOOT] headless Godot import + smoke test"
  "$GODOT" --headless --path . --import
  "$GODOT" --headless --path . --script tests/smoke.gd
else
  echo "[BOOT] godot binary not found (set GODOT=...) - skipping engine checks"
fi

echo "[BOOT] all tests passed"
