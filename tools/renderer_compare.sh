#!/bin/bash
# Package 02 renderer comparison. Does not mutate project.godot.
set -euo pipefail
cd "$(dirname "$0")/.."
engine="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$engine" ]]; then engine="$(command -v godot || command -v godot4 || true)"; fi
if [[ -z "$engine" || ! -x "$engine" ]]; then echo 'Set GODOT_BIN to the Godot 4.7.2 executable.' >&2; exit 1; fi
mkdir -p builds/renderer_compare builds/renderer_captures
touch builds/.gdignore
godot_version="$("$engine" --version 2>/dev/null || true)"
printf 'Godot %s\n' "$godot_version"
duration="${BENCHMARK_DURATION:-25}"
warmup="${BENCHMARK_WARMUP:-5}"
samples="${BENCHMARK_SAMPLES:-3}"
preset="${BENCHMARK_PRESET:-standard}"
scenarios=(starter_lake dense_forest resort_18 active_golfers)
methods=(gl_compatibility mobile forward_plus)
for method in "${methods[@]}"; do
  probe_log="builds/renderer_compare/${method}_probe.log"
  if ! "$engine" --headless --path . --rendering-method "$method" --script tests/renderer_probe.gd >"$probe_log" 2>&1; then
    printf 'UNTESTED %s (probe exit failed)\n' "$method" | tee -a builds/renderer_compare/summary.txt
    continue
  fi
  if ! grep -q "RENDERER_PROBE" "$probe_log"; then
    printf 'UNTESTED %s (probe missing marker)\n' "$method" | tee -a builds/renderer_compare/summary.txt
    continue
  fi
  for scenario in "${scenarios[@]}"; do
    out="builds/renderer_compare/${scenario}_${method}"
    if ! "$engine" --headless --path . --rendering-method "$method" --script tests/renderer_compare.gd -- \
      --benchmark-scenario="$scenario" \
      --benchmark-duration="$duration" \
      --benchmark-warmup="$warmup" \
      --benchmark-samples="$samples" \
      --benchmark-preset="$preset" \
      --comparison-mode=feature_matched \
      --benchmark-output="$out" 2>&1 | tee "${out}.log"; then
      printf 'FAILED %s %s\n' "$method" "$scenario" | tee -a builds/renderer_compare/summary.txt
    fi
  done
done
if [[ "${CAPTURE_WINDOWED:-0}" == "1" ]]; then
  for method in gl_compatibility mobile forward_plus; do
    cap_out="builds/renderer_captures/${method}"
    mkdir -p "$cap_out"
    if "$engine" --path . --rendering-method "$method" --display-driver macos --script tests/capture_lush.gd 2>&1 | tee "${cap_out}/capture.log"; then
      for png in builds/lush-*.png; do
        [[ -f "$png" ]] && mv -f "$png" "${cap_out}/$(basename "$png")"
      done
    else
      printf 'CAPTURE_UNTESTED %s\n' "$method" | tee -a builds/renderer_compare/summary.txt
    fi
  done
fi
printf 'Renderer comparison outputs under builds/renderer_compare/\n'
