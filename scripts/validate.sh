#!/usr/bin/env bash
# SHAPESHOT - static pre-export validation. Fails fast with clear messages.
# Checks: required config files, required scripts, every res:// reference.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
need() {
  if [ -e "$1" ]; then
    echo "[EXPORT] ok: $1"
  else
    echo "[EXPORT] MISSING: $1" >&2
    fail=1
  fi
}

for f in project.godot export_presets.cfg main.tscn \
         data/levels.json generated/levels.json \
         game/bootstrap.gd game/game.gd game/game_world.gd game/launcher.gd \
         game/projectile.gd game/structure.gd game/target.gd game/level.gd \
         game/level_data.gd game/level_loader.gd game/camera_controller.gd \
         game/game_state.gd game/game_settings.gd game/audio_manager.gd \
         game/api_client.gd game/trajectory_preview.gd game/theme3d.gd game/log.gd \
         ui/hud.gd tests/smoke.gd \
         tools/levelgen/go.mod tools/levelgen/main.go tools/levelgen/levelgen.go \
         tools/levelgen/levelgen_test.go \
         .github/workflows/build-web.yml; do
  need "$f"
done

echo "[EXPORT] checking res:// references inside scenes and scripts"
refs=$(grep -rhoE 'res://[A-Za-z0-9_./-]+' main.tscn game/*.gd ui/*.gd tests/*.gd project.godot 2>/dev/null | sort -u || true)
for r in $refs; do
  path=".${r#res:}"
  # skip res:// URLs that are runtime-only user paths (none expected here)
  if [ -e "$path" ]; then
    echo "[EXPORT] ok ref: $r"
  else
    echo "[EXPORT] BROKEN REF: $r" >&2
    fail=1
  fi
done

echo "[EXPORT] checking GDScript indentation hygiene (no leading spaces)"
bad=$(grep -rlP '^ +\S' game/*.gd ui/*.gd tests/*.gd 2>/dev/null || true)
if [ -n "$bad" ]; then
  echo "[EXPORT] files use space indentation (project convention is tabs): $bad" >&2
  fail=1
else
  echo "[EXPORT] ok: tab-indented GDScript"
fi

exit $fail
