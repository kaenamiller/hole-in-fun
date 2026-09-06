#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$engine" ]]; then engine="$(command -v godot || command -v godot4 || true)"; fi
if [[ -z "$engine" || ! -x "$engine" ]]; then echo 'Set GODOT_BIN to the Godot 4.7.2 executable.' >&2; exit 1; fi
mkdir -p builds/macos builds/windows
touch builds/.gdignore
"$engine" --headless --editor --path . --quit
"$engine" --headless --path . --export-release macOS "builds/macos/Hole in Fun.zip"
"$engine" --headless --path . --export-release 'Windows Desktop' "builds/windows/Hole in Fun.exe"
if command -v unzip >/dev/null; then unzip -o -q 'builds/macos/Hole in Fun.zip' -d builds/macos; fi
printf '%s\n' 'Built macOS universal ZIP/application and Windows x64 executable in builds/.'
