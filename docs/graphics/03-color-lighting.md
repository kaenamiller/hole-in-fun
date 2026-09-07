# 03 — Consistent color and lighting

**Difficulty:** 2/5. **Dependencies:** 01 and the 02 renderer decision. **Outcome:** warm resort lighting with consistent material response and readable gameplay.

## Current implementation and entry points

`main.gd::_setup_light` uses a warm directional sun, colored ambient fill, procedural sky and linear tone mapping. `_apply_season` changes the palette. Ground, water, foliage, paths and horizon shaders use different `pow` adjustments to their colors. These may be artistic curves rather than accidental transfer conversions; audit before removing them. `AssetFactory::_material` and `apply_season` govern shared prop materials.

## Implementation sequence

1. Create a deterministic lighting test scene containing neutral gray/white swatches, rough and glossy spheres, turf, water, foliage, stone, plaster and timber. Include the existing assets beside swatches so calibration remains relevant to the game.
2. Trace every color source from script/image/vertex color through shader to final output. Document which textures are color versus data and how the selected renderer interprets them. Identify duplicated conversions, clipped highlights and inconsistent exposure responses using actual captures.
3. Define a small central environment palette/configuration: sun color/energy, ambient color/energy, sky colors, exposure and tone mapper. Define separate surface palette values. Avoid one broad color multiplier that compensates for errors differently across materials.
4. Replace shader-specific corrections only when comparisons establish the intended alternative. Centralize any deliberate art curve and document its purpose. Preserve turf type contrast, warm buildings and cooler lake/horizon values from the reference.
5. Calibrate the neutral scene first, then the overview and close views. Keep bloom restrained if used; avoid relying on it to conceal flat materials. Verify shadowed foliage retains shape without excessive emissive fill.
6. Apply seasonal variants through the same contract. Preserve shared material caching; avoid accidental mutation of a material used by unrelated species. Ensure seasonal transitions do not reset roughness, normal strength or quality settings.
7. Verify analysis overlays, selection markers, ball and flag under the brightest and darkest intended lighting. Keep UI colors outside world grading unless the current UI pipeline explicitly requires otherwise.

## Acceptance and tests

Neutral materials behave consistently across shader and standard-material paths. Snow/white paint do not clip uncontrollably; shadows retain useful detail; sand, green and fairway remain distinguishable. Capture all supported seasons, two zoom levels and overlay/photo modes. Compare the unchanged backend/settings before and after, then follow [shared validation](VALIDATION.md).

## Delivery and fallback

Store the calibration scene, palette definitions and a short color-space contract for material authors. Record intentionally retained shader curves. Keep previous environment values available in the implementation diff or comparison fixture. Avoid changing sun direction late in downstream shadow/material work without rerunning those captures.
