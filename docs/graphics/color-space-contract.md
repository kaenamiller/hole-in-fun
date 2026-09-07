# Color-space contract (package 03)

Applies to **Compatibility (`gl_compatibility`)** on Godot 4.7.x unless a future renderer trial changes interpretation.

## Authoring rules

1. **Store colors in sRGB** — `Color("#rrggbb")`, `source_color` shader uniforms, and `StandardMaterial3D.albedo_color` are treated as display-referred sRGB albedos, not linear radiance.
2. **Environment palette** — sun, ambient, sky, exposure and tonemap live in `GraphicsPalette.environment_for_season()`. Do not add a global scene multiplier to “fix” materials.
3. **Surface palette** — terrain slot colors (`GraphicsPalette.SURFACE_COLORS` / `TerrainModel.palette`), water tint, and `AssetFactory` named constants are separate from environment lighting. Season changes tint via `season_tint` / foliage uniforms, not by regrading the sun.
4. **Gameplay readability** — ball, flag, selection rings, and analytics overlay gradients use `GraphicsPalette.READABILITY`. UI theme colors in `resort_ui.gd` stay outside world grading.
5. **Textures** — procedural noise in `AssetFactory` is **data** (grayscale variation). Terrain `turf_map` / `detail_map` are **masks** (surface weights, not albedo). Import color maps as sRGB; roughness/normal as linear data when bitmaps arrive in package 04.

## Shader art curves (retained)

Deliberate per-shader `pow()` curves compensate Compatibility’s linear tonemap and keep turf contrast readable. Constants are mirrored in `GraphicsPalette.ART_CURVES`:

| Shader | Curve | Purpose |
|---|---|---|
| `resort_ground` | `pow(col, 1.65) * 0.9` | Fairway/green separation; shadow detail |
| `resort_foliage` | `pow(col, 1.35)` + stipple | Canopy depth without crushing shadows |
| `resort_water` | `pow(col, 1.5)` | Cooler lake vs warm shore; glint `pow(..., 16)` |
| `resort_path` | `pow(path, 1.65)` | Gravel warmth vs fairway |
| `resort_horizon` | `pow(rgb * season_tint, 1.65) * 0.9` | Distant hills cooler than buildings |

Remove or unify a curve only after side-by-side captures in `builds/color_calibration/`.

## Season contract

| Season | Ground `season_tint` | Foliage target | Foliage mix |
|---|---|---|---|
| Spring (0) | `(1.0, 1.03, 0.97)` | `#5d8a52` | 0.41 |
| Summer (1) | `(1.02, 1.0, 0.9)` | `#3f7040` | 0.0 |
| Fall (2) | `(1.08, 0.95, 0.78)` | `#8a6a34` | 0.56 |
| Winter (3) | `(1.15, 1.2, 1.3)` | `#e8edf2` | 0.64 |

`AssetFactory.apply_season` lerps shared green materials’ **albedo only**; roughness, metallic and normal strength are never modified.

## API for packages 04–16

```gdscript
GraphicsPalette.environment_for_season(season_index)  # sun/sky/ambient/exposure
GraphicsPalette.surface_colors_for_terrain(model)   # ground shader uniforms
GraphicsPalette.water_tint(model)
GraphicsPalette.terrain_season_tint(season_index)
GraphicsPalette.foliage_season_target(season_index)
GraphicsPalette.apply_directional_light(light, season)
GraphicsPalette.apply_environment(environment, season)
GraphicsPalette.READABILITY  # ball, flag, overlays
GraphicsPalette.ART_CURVES   # document shader gamma; do not duplicate in new shaders
GraphicsPalette.LEGACY       # pre-03 comparison fixture
```

Calibration scene: `tests/capture_color_calibration.gd` → `builds/color_calibration/`.
