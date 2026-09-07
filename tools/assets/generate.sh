#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 tools/assets/generate_materials.py
python3 tools/assets/generate_trees.py
python3 tools/assets/generate_ground_cover.py
python3 tools/assets/configure_imports.py
engine="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [[ -x "$engine" ]]; then
  "$engine" --headless --editor --path . --quit
fi
