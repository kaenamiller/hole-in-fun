# 04 — Distinct procedural material library

**Difficulty:** 3/5. **Dependencies:** 03. **Outcome:** recognizable timber, stone, plaster, roofing and course surfaces at consistent physical scale.

## Current implementation and entry points

`AssetFactory::_material` shares a small noise texture among wood, plaster and roofing-like materials. Terrain and water use procedural shader grain. Inspect `scripts/asset_factory.gd`, `scripts/terrain_view.gd` and `shaders/resort_*.gdshader`. Existing material caching and batching must survive the richer library.

## Implementation sequence

1. Define material families: fairway/rough, sand, gravel, stone, plaster, bark, timber and roof. Specify intended meters per repeat, palette range, roughness and close-view detail. Separate macro variation from fine grain so the overview does not look noisy.
2. Add an offline deterministic generator under a proposed `tools/assets/` directory. Generate seamless base color, roughness and height from explicit surface definitions; derive tangent-space normals from the authored height. Record seed, resolution, units and generator version in a manifest.
3. Begin with shared 512–1024 maps where useful, smaller maps for simple surfaces, and a trim sheet for architecture. These are starting sizes, not requirements to fill memory. Produce edge-comparison checks for seamlessness and reject maps with lighting baked into base color unintentionally.
4. Configure imports: color maps interpreted as color, roughness/normal/height as data, normal orientation verified on a lit sample, mipmaps and sensible filtering. Inspect distant shimmer and grazing-angle repetition. Do not claim arbitrary image-to-normal conversion produces accurate material structure.
5. Add a material-library lookup keyed by stable family/variant. Preserve shared resource instances across matching meshes. Use UVs for controlled trim placement and existing triplanar mapping where appropriate; check scale on rotated/scaled objects.
6. Convert one representative asset per family and one hole before bulk conversion. Blend terrain detail by existing surface weights without changing simulation surfaces. Use distance fade or filtered frequencies for fine turf/sand detail.
7. Integrate seasonal tint without tinting every material indiscriminately. Measure texture memory, draw calls and import/startup cost. Commit generated runtime assets and generator sources so launching the game requires no authoring tool.

## Acceptance and tests

Materials are distinguishable by surface structure under the same lighting, remain coherent at management zoom and show no obvious seams. Check roof ridge/UV seams, timber grain direction, plaster scale and normal-map handedness. Confirm batching does not fragment into a unique material per object. Regenerate twice and compare manifests/content deterministically where the toolchain allows it.

Follow [shared validation](VALIDATION.md), including real-rendered captures and relevant asset bounds/import tests. Save files and gameplay values should be unchanged.

## Delivery and fallback

Document material IDs, map channel meanings, texture scale and exact generation commands. Retain simple-color low-tier variants only if measurement justifies them; fewer textures alone does not necessarily improve the bottleneck. Optional AI imagery must be inspected and made repeatable, but the baseline pipeline must work without paid services or manual painting.
