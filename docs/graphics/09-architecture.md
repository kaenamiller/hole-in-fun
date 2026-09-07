# 09 — Architectural models and repeatable asset production

**Difficulty:** 3/5. **Dependencies:** 04. **Outcome:** richer resort buildings, carts and bridges with consistent catalogue integration.

## Baseline and entry points

`AssetFactory` contains clubhouse/facility builders, `cart`, `_window`, `_roof`, `_steps`, `_dress_facility` and `_bake_static`. Models already have detail but rely on simple volumes and shallow openings. `Catalog` defines stable kinds, variants and footprints. `tests/test_assets.gd` checks assets and animation hierarchy.

## Implementation sequence

1. Inventory catalogue IDs, tiers, dimensions, pivot/rotation conventions and dynamic node names. Separate static architecture from interactive attachments and animated wheels. Preserve these contracts in a generated asset manifest.
2. Build an offline generator using scripted Blender or a native mesh-generation equivalent. Detect available tools first; Blender was not established as installed during assessment. Pin the actual tool version and document unattended setup or a native fallback. Do not require manual modeling or player-side tools.
3. Start with clubhouse, bridge and cart. Add geometry where it changes silhouettes or important shading: small bevels, recessed windows, roof thickness/eaves, foundations, porch posts, bridge arches/rails and rounded cart body edges. Use texture detail for tiny roofing/grain at normal zoom.
4. Apply shared material IDs and trim sheets from 04. Bake static self-occlusion and normal detail where appropriate; keep baked light direction out of general-purpose base color. Verify UV density, smoothing, tangent normals and negative-scale transforms.
5. Produce LODs that retain rooflines, porch silhouette and bridge openings. Export GLB scenes with explicit bounds, sockets and named dynamic children. Exclude animated parts from static baking; ensure wheels and character attachments remain addressable.
6. Add a stable AssetFactory loading/cache path with fallback to existing procedural models for missing variants during rollout. Validate imported unit scale and root transforms. Preserve object IDs, upgrade tiers, footprints, placement previews and save compatibility.
7. Test the three assets in the actual resort before expanding. Measure material count and batching; consolidate compatible surfaces without merging nodes needed by animation. Avoid a unique texture/material set for every facility.
8. Extend the family through reusable roof, wall, porch and foundation modules. Keep enough variant differences to avoid identical buildings while retaining a coherent timber-resort style.

## Acceptance and tests

Close views show real depth at openings and edges; overview silhouettes remain readable. Verify all rotations, tiers, bounds, bridge endpoints and cart animation nodes. Old saves instantiate the right kinds. Asset generation is repeatable and runtime startup loads shipped assets without Blender. Run asset checks and exported import/render validation under [shared validation](VALIDATION.md).

## Delivery and fallback

Commit source generator, configuration/seed manifest, runtime exports and regeneration instructions. Record tool licensing/provenance if external inputs are added; the baseline should need no downloaded commercial pack. Keep procedural fallback until each replacement passes and document any remaining catalogue models separately.
