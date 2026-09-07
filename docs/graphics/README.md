# Lush resort graphics implementation plans

Status: proposed work, written 2026-09-06. These documents expand the [fidelity assessment](../../design/lush-resort/fidelity-roadmap.md); they do not indicate that the improvements have shipped. The visual target is [the resort reference](../../design/lush-resort/reference.png): rich vegetation, readable manicured turf, warm buildings, integrated shorelines and calm water. Preserve the game's editable, readable management view.

## Agent starting instructions

1. Read the selected plan and [shared validation and handoff requirements](VALIDATION.md).
2. Inspect current source and repository instructions. Function names below are verified entry points at writing time; proposed filenames, schemas and thresholds are design suggestions. Reconcile intervening changes before editing. Preserve unrelated working-tree changes.
3. Establish the relevant baseline, implement a bounded vertical slice, capture it, then expand. Do the asset generation, visual review and iteration autonomously. Do not depend on user modeling, painting, paid accounts or selecting asset packs.
4. Complete the package acceptance checks and leave an implementation record. If an experiment fails its gate, document the result and retain the working fallback. A failed experiment is not a reason to ship a regression.

## Packages and dependencies

Difficulty: **1** small isolated edit; **2** bounded implementation; **3** moderate asset/shader pipeline; **4** difficult cross-system work; **5** experimental/high risk. Difficulty includes validation, not a promise of artistic quality. All packages are suitable for autonomous agent work; renderer migration and planar reflections have conditional adoption gates.

| # | Plan | Difficulty | Required predecessor(s) | Recommended coordination |
|---|---|---|---|---|
| 01 | [Benchmarks and quality settings](01-benchmarks-quality.md) | 2/5 | None | All packages consume these budgets |
| 02 | [Renderer comparison](02-renderer-comparison.md) | 2/5 trial; 4/5 migration | 01 | Record a decision before renderer-specific work |
| 03 | [Color and lighting](03-color-lighting.md) | 2/5 | 01, 02 decision | Establish material reference images |
| 04 | [Material library](04-material-library.md) | 3/5 | 03 | Shared texture conventions for 07–11 |
| 05 | [Hole-aware mowing](05-hole-aware-mowing.md) | 2/5 | 03 | 06 subsequently adapts ownership sampling |
| 06 | [Course contours and banks](06-course-contours.md) | 4/5 | 01 | Preserve 05; publish boundary/depth contracts |
| 07 | [Trees](07-trees.md) | 4/5 | 04 | Coordinate shadow silhouettes with 10 |
| 08 | [Ground cover](08-ground-cover.md) | 3/5 | 04, 06 | Consume boundaries; avoid simulation obstacles |
| 09 | [Architecture and asset pipeline](09-architecture.md) | 3/5 | 04 | Start clubhouse, cart and bridge |
| 10 | [Contact shading and shadows](10-contact-shadows.md) | 3/5 | 03 | Revalidate when 07/09 land |
| 11 | [Water and shoreline materials](11-water-shorelines.md) | 3/5 | 03, 06 | Supplies water-body data to 12/13/16 |
| 12 | [Reflection probes](12-reflection-probes.md) | 2/5 | 11 | Establish baseline before 13 |
| 13 | [Planar reflections](13-planar-reflections.md) | 4/5 | 12 | Optional premium tier only |
| 14 | [Atmospheric depth](14-atmosphere.md) | 2/5 | 03 | Recheck 12/13 lighting refresh |
| 15 | [Character and vehicle motion](15-animation.md) | 3/5 | 01 | Preserve rig contracts during 09 |
| 16 | [Event-driven effects](16-event-effects.md) | 2/5 | 01, 11, 15 | Share event timing and water-body IDs |

Dependencies express the preferred integrated rollout, not a requirement to finish every predecessor before an isolated prototype. Do not merge a prototype that relies on an absent contract. There are no circular prerequisites.

## Delivery sequence

**Foundation:** 01 → 02 → 03. Record measured budgets and renderer choice. Compatibility remains the baseline until a comparison justifies changing it.

**One polished hole:** 04, 05, 07, 09 and 10. Use the same Cedar House hole and camera positions for all comparisons. Ship a coherent asset/material family before replacing the entire catalogue.

**Editable landscape:** 06 → 08 and 11. This is the highest gameplay-integration risk. Validate save migration, transactional undo, surface queries and routing before decorative expansion.

**Finish and motion:** 12, 14, 15 → 16. Attempt 13 only with measured rendering headroom. Revisit the full-resort benchmark after integration.

## Shared technical direction

Retain catalogue IDs, footprints, seasonal behavior and simulation semantics unless a plan explicitly defines a tested migration. Cosmetic systems use separate deterministic seeds and cannot advance simulation RNG. Runtime uses checked-in generated assets; authoring tools are developer dependencies only. Spatial batching, LOD and quality fallbacks are required for dense additions.

Performance targets are proposed: a stable 30-fps low tier on the reference M2 and an aspirational 60-fps standard tier after profiling. Neither is established by the old short benchmark. Do not claim Windows runtime support from export success alone. Detailed evidence and exceptions belong in the package handoff, not in this index as invented completion claims.
