# 15 — Character and vehicle motion

**Difficulty:** 3/5. **Dependencies:** 01; coordinate asset contracts with 09. **Outcome:** golfers and carts feel connected to the ground and to shot/navigation events.

## Baseline and entry points

`AssetFactory::golfer`, `staff_golfer`, `animate_golfer` and `cart` create procedural actors. Golfer nodes such as Head, Torso, ArmL/ArmR, LegL/LegR and Club are animation contracts. `main.gd::_update_people`, `_update_balls` and `_visual_shots` synchronize display with simulation. Inspect the current simulation event schema before introducing adapters.

## Implementation sequence

1. Record current idle/walk/swing/cart motion and identify event IDs, shot timing, route interpolation and actor lifetime. Define a cosmetic pose state separate from authoritative simulation position and RNG. Preserve the existing rig naming until every consumer is migrated.
2. Implement blended idle, walk, address, backswing, contact and follow-through states. Drive walking cadence from actual traveled distance, not just elapsed wall time, to reduce skating. Bound transitions for teleports, route changes and spawned actors.
3. Sample terrain under feet and root. Add lightweight procedural foot placement and body height/lean with bounded correction. Respect steep slopes and avoid expensive physics queries for every limb every frame; reduce update rate/distance detail for far actors.
4. Align club contact and ball launch to the existing shot event's visual timeline. Swing animation must never calculate a second outcome or delay the simulation's actual shot result. Handle fast simulation speeds by compressing/skipping cosmetic phases coherently.
5. Add head/torso aiming and follow-through toward the intended shot direction. Blend locomotion and swing orientation without instantaneous full-body spins. Verify left/right transforms and attached club placement.
6. Improve carts using named wheel/steering pivots: wheel rotation from traveled distance, steering from route curvature, bounded pitch/roll from ground sampling and mild suspension smoothing. Keep cosmetic offsets separate from navigation/collision positions.
7. Handle pause, photo mode, save/load, despawn and world recreation. Use stable IDs and reset interpolators on discontinuities. Publish a visual-contact/event timing contract for package 16 without making effects responsible for simulation state.
8. Add animation quality tiers through update rates or simplified distant rigs. Keep nearby motion continuous; benchmark many active golfers/carts to avoid turning procedural posing into the new CPU bottleneck.

## Acceptance and tests

Capture complete approach/walk/address/swing/ball-flight sequences and carts turning on slopes/bridges. Feet do not visibly skate or penetrate routinely; wheels move in the correct direction; actors do not snap after pause or loading. Compare identical seeded simulation outputs with animation enabled/disabled to prove cosmetic isolation.

Run relevant asset hierarchy and gameplay tests, a full lush round and [shared validation](VALIDATION.md). Deliver rig/state contracts, event timing rules and clips. If full foot planting is unstable, ship bounded root/stride correction first and mark detailed planting partial rather than distorting navigation.
