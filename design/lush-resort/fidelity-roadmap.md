# Graphical fidelity roadmap

Assessment based on the current Godot project, asset factory, terrain renderer, shaders, saved overview/close-up captures, and the last recorded benchmark. No new benchmark was run for this assessment.

## Current position

The visual direction is established; geometry, material response and environmental integration still need production work. Trees are visibly assembled from rounded lobes. Buildings have framing and roof detail but retain simple volumes and shallow windows. Most surfaces use color plus procedural grain; wood, plaster and roofing share a small noise texture rather than distinct material maps. Turf and water derive their boundaries from 256×256 masks covering a 1,024-metre property. Shader smoothing softens those boundaries but cannot recover an independently authored curve. Mowing stripes use one world-space direction. Water has animated shading and sky response, with no scene reflections or genuine depth-driven coloration. Canopy shadows use simplified proxy volumes; terrain receives shadows but does not cast them.

The project already has reusable asset IDs, batching, foliage LODs, seasonal colors, shader-based surfaces, capture scripts and build validation. Those provide a useful foundation for autonomous work.

Last recorded measurement: Apple M2, Compatibility renderer, 1440×900, 4× MSAA, 35.9 average fps, 20 ms p95 frame time, 20 active golfers. The short sample is insufficient to establish CPU/GPU bottlenecks or performance on a full 18-hole resort. Its average/p95 difference warrants investigation of occasional long frames.

## Difficulty scale

1 = small isolated change; 2 = straightforward bounded implementation; 3 = moderate asset/shader pipeline work; 4 = difficult cross-system work requiring substantial iteration; 5 = experimental or especially high-risk. Ratings concern implementation and validation, not a guarantee of artistic quality. Every proposed item can be attempted and validated without manual modeling or painting by the user.

## Ranked work packages

| Package | Difficulty | Visual value | Autonomous implementation and main constraint |
|---|---|---|---|
| Reproducible graphics benchmarks and quality settings | 2 | Enables all subsequent work | Fixed camera paths, seeds, seasons and loads; distinguish simulation, rendering and asset-loading stalls; collect CPU/GPU timing where supported, p50/p95/p99 and memory. Add foliage, shadows, water and effects quality levels. |
| Renderer comparison | 2 for trial; 4 for migration | Potentially high | Compare Compatibility, Mobile and Forward+ using the same representative scenes and supported drivers. Keep a tested fallback and compare exported builds. Select based on measured results before committing to renderer-specific effects. |
| Consistent color and lighting pipeline | 2 | High | Audit color-space conversion and material-specific power adjustments; calibrate sun, ambient fill, tone mapping and exposure on a fixed material test scene. Preserve palette contrast and readable overlays. |
| Distinct material library | 3 | Very high | Generate seamless turf, rough, sand, gravel, stone, plaster, bark, wood and roofing maps. Produce base color, roughness and normal maps from explicit procedural height/material definitions. Use shared atlases or trim sheets, correct physical scale, mipmaps and distance filtering. |
| Hole-aware mowing | 2 | High | Store per-hole mowing orientation or a flow field derived from the routing. Support straight, alternating and gently curved patterns. Reduce contrast with distance; keep stripes aligned across chunks and edits. |
| Continuous course contours and shaped banks | 4 | Very high | Introduce persistent vector outlines or higher-resolution surface authoring for new paint, with a compatibility path for existing raster saves. Generate bunker lips, green collars and shore profiles from shared definitions. Rendering, ball lies, costs, undo and navigation must remain consistent. Merely upscaling the old masks does not add information. |
| Second-generation trees | 4 | Very high | Script branching trunks, asymmetrical crowns and smaller leaf clusters; compare geometry leaves with alpha-cutout foliage cards. Generate multiple deterministic species/age variants and screen-size LODs. Budget transparency overdraw as well as triangle count; use suitable shadow meshes for each distance. |
| Ground cover and planting composition | 3 | High | Seeded grass tufts, shrubs, reeds, flowers, leaf litter and stones concentrated at natural boundaries. Use spatial batches and distance-based density. Clear or regenerate cosmetic cover after edits; retain simulation objects for substantial obstacles. |
| Architectural asset pipeline | 3 | High near buildings | Use scripted Blender or equivalent mesh generation for beveled edges, recessed windows, roof thickness, gutters, stone foundations, porches and refined carts/bridges. Bake geometry detail and occlusion into textures, generate LODs, export GLB scenes and preserve catalogue IDs/footprints. Begin with the clubhouse, cart and bridge. |
| Better contact shading and shadows | 3 | High | Improve canopy shadow silhouettes, bias and transitions at several zoom levels. Bake self-occlusion into static props; test supported screen-space ambient occlusion for live contacts. Avoid a whole-course baked-lighting dependency because the land and buildings are editable. |
| Water depth and shoreline materials | 3 | High | Derive shallow/deep tint from the actual basin or a maintained depth field, add wet bank materials and irregular shore transitions, filter repeating wave patterns, and trigger local ripples from events. Maintain compatibility with painted water at different elevations. |
| Reflection probes | 2 | Medium to high | Add a small number of appropriately placed probes and refresh after relevant construction or lighting changes. Use reduced-detail reflection captures. They improve environmental response but are approximate on a broad flat lake. |
| Planar lake reflections | 4 | High in close views | Prototype a reflected-camera viewport for one dominant water plane. Clip geometry correctly, exclude the water itself, use lower resolution and selective updates. Multiple independent water elevations and the extra rendering pass make this a later optional quality tier. |
| Atmosphere and distant landscape | 2 | Medium to high | Gentle distance/height haze, horizon color separation, layered distant vegetation and restrained moving cloud shading. Ensure the UI and playable surfaces retain contrast. Volumetric fog is a separate renderer-dependent experiment. |
| Character and vehicle motion | 3 | Medium; high close up | Procedural animation blending, planted feet, improved swing timing, head/torso follow-through, steering/wheel rotation and suspension. Keep animation cosmetic and synchronized with existing shot/navigation events. |
| Small event-driven effects | 2 | Medium | Sand puffs, turf divots, pond ripples, flag flutter, fountain spray and occasional ambient movement. Pool effects and cap their count; validate scene motion in video as well as still captures. |

## Execution order

1. Establish longer, reproducible benchmarks and quality levels. Run the renderer comparison and fix color management before material authoring.
2. Build one polished asset family and a representative hole: material library, clubhouse/cart/bridge, tree variants, mowing and contact shading. Keep camera views identical for before/after evaluation.
3. Implement continuous authoring and shared surface definitions, then generate collars, banks and clustered ground cover. Test legacy saves, surface boundaries, costs, edits, undo and routing.
4. Add depth-aware water, limited reflection probes and atmospheric depth. Try planar reflections only if performance permits. Finish with animation and restrained event effects.

## Autonomous production workflow

Scripts should generate source meshes and maps, export game-ready assets, bake static detail, build LODs and capture deterministic turntables and in-game views. Ship generated assets so normal game startup does not need Blender or expensive generation. Procedural textures provide a repeatable baseline without requiring downloaded art packs or paid asset services. Optional generated artwork requires automated inspection and iteration rather than assumptions about seamlessness or usable normal maps.

Each work package should include fixed overview, hole and close views; a short motion capture; shader/asset checks; an exported Mac launch; and a comparison against the same performance scenario. Windows runtime validation requires an available Windows runner; producing a Windows executable alone does not validate its renderer.

Proposed performance goals are a stable 30-fps minimum tier on the M2 and a 60-fps target for standard gameplay after profiling. These are goals, not measured capabilities. Judge regressions using frame-time tails and editing responsiveness, not just average fps. Expensive effects should degrade gracefully by quality level.

## Lower-priority approaches

Blanket subdivision of all models, 4K textures on every prop, grass blades across the entire property, heavy bloom/depth of field during management, and full dynamic global illumination should not lead the next pass. Their cost can greatly exceed their visible benefit at the normal camera. More polygons are useful where they improve silhouettes, bevels or important terrain profiles.

## Engine references

- [Godot 4.7 renderer comparison](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html): feature availability differs by renderer. The table lists reflection probes, SSAO, glow and basic fog for Compatibility; screen-space reflections, volumetric fog and advanced GI require Forward+.
- [Reflection probes](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/reflection_probes.html): limited probe overlap in Compatibility, controlled update modes and reflection LOD options.
- [MultiMesh optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html): spatial grouping matters because instances within one MultiMesh are culled together.
- [Blender command-line scripting](https://docs.blender.org/manual/en/3.0/advanced/command_line/arguments.html): background execution and Python scripts support automated asset production.

## Detailed implementation plans

See [the graphics implementation index](../../docs/graphics/README.md) for all 16 package plans, difficulty ratings, dependencies, acceptance criteria and shared agent handoff requirements.
