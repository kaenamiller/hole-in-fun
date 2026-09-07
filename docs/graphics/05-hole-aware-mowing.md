# 05 — Hole-aware mowing patterns

**Difficulty:** 2/5. **Dependencies:** 03; coordinate with 06. **Outcome:** fairways and greens read as individually maintained golf features.

## Baseline and entry points

`shaders/resort_ground.gdshader` currently derives stripes from one world-space direction. `TerrainView::_update_surface_maps` builds surface masks. `TerrainModel` stores holes and provides green ownership queries. Hole routing and green ownership are related but do not automatically establish fairway ownership, especially for overlapping or unfinished holes.

## Implementation sequence

1. Define a cosmetic per-hole pattern record: stable hole ID, orientation, width, phase, contrast and pattern type. Supply deterministic defaults from tee-to-cup routing; preserve explicit values when the hole changes. Inspect the existing save schema before adding an optional versioned field.
2. Establish fairway ownership from authored association when available, with a deterministic nearest-routing fallback for legacy courses. Resolve overlap consistently and give unassigned paint a neutral default. Do not change playable surface classification to obtain stripe ownership.
3. Begin with straight alternating bands and subtly different green orientation. Generate a separate ownership/orientation texture or bounded per-hole data representation. Avoid a shader loop over every hole per fragment. Keep stripe phase in world coordinates to prevent chunk seams.
4. Add gently curved patterns only after straight patterns pass. For a direction field, maintain phase continuity rather than integrating independently per pixel and creating breaks. Use bounded curvature and inspect junctions. This is optional refinement, not a blocker for the basic feature.
5. Blend contrast by surface type and viewing distance. Preserve green/fairway palette separation; avoid moiré at overview zoom. Use filtered derivatives where supported and validate the chosen shader path.
6. Update only affected regions when hole geometry or paint changes. Save optional pattern metadata, restore legacy defaults deterministically and include changes in the existing undo transaction when an editor control modifies them.
7. Provide a compact pattern control only if it fits current hole editing; autonomous defaults must work without user setup. Package 06 should consume this ownership contract rather than create a second competing system.

## Acceptance and tests

Capture neighboring differently oriented holes, overlapping/unassigned fairways and chunk boundaries. Paint, remove, move and restore holes; patterns must not jump on unrelated edits or load. Compare shots and green ownership before/after to prove the feature remains cosmetic. Check near/far motion for shimmering and measure mask-update cost on an 18-hole fixture.

Follow [shared validation](VALIDATION.md). Deliver the ownership fallback rules, schema defaults and captures. If curved fields prove unstable, ship straight patterns with the same metadata contract and document the omitted mode.
