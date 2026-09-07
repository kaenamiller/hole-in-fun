#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
engine="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$engine" ]]; then engine="$(command -v godot || command -v godot4 || true)"; fi
if [[ -z "$engine" || ! -x "$engine" ]]; then echo 'Set GODOT_BIN to the Godot 4.7.2 executable.' >&2; exit 1; fi
"$engine" --headless --editor --path . --quit
"$engine" --headless --path . --script tools/assets/generate_architecture.gd
