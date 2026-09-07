# Package 09 — Architectural models and asset pipeline

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 09 adds a native Godot architecture pipeline for **clubhouse** (3 tiers), **cart**, and **bridge** with enhanced procedural geometry (bevels, recessed windows, roof eaves, foundations, bridge arches/rails, rounded cart body), MaterialLibrary PBR families, static self-occlusion baked into vertex colors, embedded mesh LODs, committed runtime scenes under `assets/architecture/`, and `AssetFactory` loading with procedural fallback when a shipped variant is missing. Cart wheels remain on named pivots for package 15 animation.

## Catalogue inventory (manifest contract)

| Asset key | Catalogue IDs | Tiers | Footprint (m) | Catalog radius | Pivot | Dynamic nodes |
|---|---|---:|---|---:|---|---|
| `clubhouse` | `clubhouse` | 3 | 12.0 × 5.35 × 8.6 | 9.0 | center origin, feet y=0 | — |
| `cart` | runtime actor (not catalog placable) | 1 | 1.62 × 1.94 × 2.35 | 1.4 | center origin, feet y=0 | `Wheels/WheelFL`, `WheelFR`, `WheelRL`, `WheelRR` |
| `bridge` | `bridge`, `bridge_walk`, `bridge_cart` | 1 | 4.8 × 1.55 × 3.0 | 3.2 | center origin, feet y=0 | — |

**Rotation convention:** models face −Z (front porch / cart dash forward). Placement preview and save object IDs are unchanged (`Catalog` kind strings and tier indices map to variant `level - 1`).

**Static vs dynamic:** clubhouse and bridge are static-baked meshes. Cart body is static; wheel pivots are excluded from bake and preserved in exported scenes.

## Source changes

| File | Role |
|---|---|
| `scripts/architecture_manifest.gd` | Stable contracts, scene paths, manifest read/write |
| `scripts/architecture_mesh.gd` | Enhanced native builders, static bake, embedded LOD pass |
| `scripts/asset_factory.gd` | Shipped scene load + cache; architecture builders; cart wheel hierarchy |
| `tools/assets/generate_architecture.gd` | Headless exporter (no Blender) |
| `tools/assets/generate_architecture.sh` | Regeneration wrapper |
| `assets/architecture/**` | Committed `.tscn` scenes + `manifest.json` |
| `tests/test_assets.gd` | Cart wheel pivot checks (+4 assertions) |

### Deviations from plan

- **Blender path deferred:** Assessment confirmed Blender not required; native Godot `ArchitectureMesh` is the sole generator.
- **LOD storage:** LODs are embedded per `ArrayMesh` surface (via `ImporterMesh.generate_lods`) rather than separate `.glb` sidecars; manifest records `lod_count` per variant.
- **Remaining facilities:** Other catalogue buildings still use legacy procedural `_dress_facility` builders; only clubhouse/bridge/cart are in the shipped architecture set for this pass.

## Generator commands

```bash
cd /Users/kaenamiller/Documents/ChatGPT/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Regenerate architecture scenes + manifest (no Blender)
bash tools/assets/generate_architecture.sh

# Direct script (after editor scan)
"$GODOT_BIN" --headless --editor --path . --quit
"$GODOT_BIN" --headless --path . --script tools/assets/generate_architecture.gd
```

**Tool versions:** Godot 4.7.2; generator version `1.0.0`; seed `0x092026` (598054 decimal).

**Manifest:** `assets/architecture/manifest.json` sha256 `0adc52a1a61cfac67d11da4d0caee07bb4e82b9f479b21ff43a4d5552e2d89af`.

**Shipped scenes:**

| Scene | LOD surfaces |
|---|---:|
| `assets/architecture/clubhouse/v0.tscn` | 3 |
| `assets/architecture/clubhouse/v1.tscn` | 3 |
| `assets/architecture/clubhouse/v2.tscn` | 3 |
| `assets/architecture/bridge/v0.tscn` | 3 |
| `assets/architecture/cart/v0.tscn` | 0 (wheels dynamic) |

## Runtime loading and fallback

```gdscript
# AssetFactory.build("clubhouse", variant) → loads assets/architecture/clubhouse/v{variant}.tscn when present
# Missing scene → ArchitectureMesh.build_* + static bake (same geometry path as export)
# AssetFactory.cart() → loads assets/architecture/cart/v0.tscn or procedural cart with wheel pivots
```

`_dress_facility` is skipped for architecture catalogue kinds to avoid duplicate facades on shipped clubhouse meshes.

## Checks run

| Check | Result |
|---|---|
| `tests/test_assets.gd` | **64 passed** (clubhouse tiers, bridge kinds, cart wheel pivots) |
| `tests/test_graphics.gd` | **Not run** — pre-existing parse error (`HoleMowingClass` undeclared in test file) |
| `bash tools/assets/generate_architecture.sh` | **OK** — 3 assets exported |
| Windowed resort/clubhouse captures | **Not run** (headless pass) |

**Pre-existing:** tree GLTF load errors (`assets/trees/*_near.gltf` missing) during scenery builds in `test_assets.gd`; unrelated to package 09.

## Quality-tier behavior

Shipped architecture loads at all graphics presets. Embedded LODs activate at the mesh level; no runtime generator or Blender invocation. Material instances remain shared via `MaterialLibrary`.

## Known limitations / follow-up

1. **Facility bulk conversion** — Extend architecture pipeline to cart_barn, lodge, etc.
2. **Trim sheet UVs** — Architecture uses per-family triplanar maps; `architecture_trim` atlas reserved for future UV-authored modules.
3. **Cart animation** — Wheel pivots are in place; rotation/steering driven in package 15.
4. **Windowed validation** — Run `tests/capture_lush.gd` clubhouse + bridge views after merge.

## Next step

Package 15: wire cart wheel rotation to traveled distance using `Wheels/Wheel*` pivots; windowed before/after captures at overview and close-up for clubhouse openings and bridge arches.
