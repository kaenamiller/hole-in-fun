# 16 — Small event-driven effects

**Difficulty:** 2/5. **Dependencies:** 01, 11 and 15. **Outcome:** restrained feedback gives shots and the resort subtle life without clutter.

## Baseline and entry points

Shot/ball presentation is managed by `main.gd::_update_balls` and `_visual_shots`; actors are updated separately. Water shading is in `resort_water.gdshader`. AssetFactory creates flags and fountains. Inspect actual simulation events and the visual timing contract from 15; do not infer an effect by repeatedly sampling an actor's current state.

## Implementation sequence

1. Define a cosmetic effect event adapter with stable event ID, type, world position, surface/body ID and visual timestamp. Consume each event once, retain a bounded deduplication history and reset appropriately on world recreation. Loading a save should not replay every historical shot.
2. Build a pooled effect manager with per-family and total caps. Configure lifetimes, distance culling and priority; drop insignificant distant events when full. Use a separate deterministic cosmetic RNG. Release particles, meshes and material references on teardown.
3. Add sand puffs at bunker contact, a small turf fragment/divot response for relevant shots and pond ripples at actual water impacts. Use authoritative lie/impact data so sand does not puff from a green. Synchronize with the visible contact/ball timeline from 15.
4. Render temporary marks through supported shader masks or draped meshes. The assessment's Compatibility path does not support built-in Decal nodes; verify the installed renderer before choosing that API. Offset/conform marks carefully to avoid z-fighting and remove them with bounded lifetime or affected terrain edits.
5. Feed bounded ripple events into package 11's water-body contract. Reject dry positions or removed bodies, and prevent a ripple from appearing on a nearby lake at another elevation. Do not spawn new persistent gameplay objects for each effect.
6. Add gentle flag flutter and fountain spray with stable phase and quality caps. Ambient birds/insects or other movement are optional finishing work; keep frequency low and avoid resembling shot/selection feedback.
7. Define pause and simulation-speed behavior explicitly. Persistent ambient motion may use cosmetic time, while contact effects follow the shot presentation clock. Test fast-forward so events do not accumulate into a burst when returning to normal speed.
8. Expose effects density through package 01. Low/off modes preserve essential gameplay feedback; if an effect becomes the sole indicator of a gameplay event, provide a non-particle cue.

## Acceptance and tests

One shot produces one appropriate contact effect; replay/load does not duplicate it. Pool counts remain bounded during long fast-forward sessions and memory returns after scene teardown. Edits remove or reproject stale marks. Verify sand, turf and separate-height water fixtures, pause/resume and offscreen events.

Capture short clips rather than relying on stills. Effects should be visible at useful camera distances but not obscure the ball or fill the management view. Follow [shared validation](VALIDATION.md), including simulation determinism and worst-case simultaneous effects.

## Delivery and fallback

Document event IDs/timing, pool caps, lifetime rules and surface mappings. Include debug counters or a reproducible stress fixture. If particle rendering is unsupported or costly, use simpler pooled meshes/shader ripples and retain the same event API. No effect may alter shot outcomes, maintenance costs or simulation RNG.
