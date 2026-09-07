# Lush resort implementation

The supplied `reference.png` guides the palette, layered planting, water, winding course layout and timber architecture. This is a real-time Godot implementation using procedural meshes and shaders, rather than the generated concept images.

## In the game

- Continuous surface masks draw softer fairway, green, bunker and shoreline contours over the existing editable terrain grid. Turf has subtle mowing bands and fine grain; greens and sand have edge treatments.
- A shared animated water shader provides calmer ripples, sky lighting and shallow-bank color. Shoreline stones and reeds regenerate with terrain edits.
- Oak and pine canopies use overlapping, smooth leaf clusters, restrained wind motion and seasonal colors. Shared baked meshes, instancing, generated mesh LODs and simplified canopy shadow volumes reduce repeated geometry work.
- Buildings have timber framing, framed windows on the rear and sides, foundations, pitched roofs with shingle courses and seams. The clubhouse includes a chimney and a rear terrace with tables and parasols. Palms and flower beds have new geometry; golfers have rounded bodies and limbs.
- Gravel and paved paths have material grain, darker shoulders, rounded joins and ground-conforming surfaces. Camera lighting uses warm sunlight, cool ambient fill, a sky and a surrounding landscape. Four-sample MSAA smooths silhouettes.
- Starting a new Cedar House creates three playable holes around a lake, a connected cart loop, a small footbridge and woodland. The existing 18-hole stress layout is retained. Existing saved layouts are not replaced.
- **F9** toggles photo mode; **Escape** exits it. Camera movement, rotation, zoom and elevation controls still work. **F12** saves a PNG to the game's user-data `screenshots` folder, including in exported applications.

## Validation commands

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_assets.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/test_lush.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_lush_round.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/capture_lush.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/benchmark_lush.gd
```

`test_lush.gd` checks playable holes, cart access, restored terrain and objects, water-mask paint/undo, overlays and mesh reuse. Run it with the real renderer to include GPU texture readback assertions: Godot's headless dummy renderer does not update texture readbacks.

Captured images and validation logs are in `builds/lush-*`. `capture_lush.gd` includes an overview with UI, a clean resort view, a hole, the clubhouse and trees. The benchmark measures a live starter resort with three manually admitted groups after five seconds of warmup.

## Scope and remaining limits

The reference remains an art target. The game uses procedural 3D assets, not the reference's hand-painted detail. Water uses the environment sky and animated shading, not planar reflections of buildings and trees. Land and shot rules still use the existing four-metre grid: rendered contour smoothing is cosmetic, and enabling the grid shows exact surface cells. The path tool still places straight segments; the starter's curved route is composed from multiple connected segments. Shore reeds and small rocks are cosmetic details, while the larger planted trees remain selectable simulation objects.

The initial broader test run found nine shot-suite failures before the shot/terrain systems changed in this pass. A terrain-suite run also reported four failures in independent surface-validity, penalty-zone, bunker-depth and map-crossing checks. Those simulation issues are outside this graphics pass; their logs are retained in `builds/lush-baseline-tests.log` and `builds/lush-terrain.log`.

## Final verification

- Asset/catalogue suite: 60 checks passed.
- Rendered lush suite: zero failures, including texture paint and undo readbacks.
- Real round: one admitted golfer completed the three-hole course with zero refunds.
- Captures: generated from the running game and visually inspected at overview and close camera distances.
- macOS universal app/ZIP and Windows x64 executable exported successfully.
- Exported Mac application launched with the real OpenGL renderer and reported `MAIN_SMOKE_OK guests=8 holes=3` with no script or shader errors. Windows runtime remains untested on this Mac.
- Final live benchmark on Apple M2, OpenGL Compatibility, 1440×900 with 4× MSAA: 35.9 average fps, 20.0 ms p95 frame time, 719 sampled frames and 20 active golfers. This is a short local run, not a guarantee for every map or load; occasional simulation stalls lower the average. Reported frame work was 1,763 draw calls and 895,398 primitives including shadow passes.
