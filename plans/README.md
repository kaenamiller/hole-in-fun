# Implementation plans

Each document is a self-contained plan for one post-MVP feature. Plans reference the current code (`scripts/*.gd`) by function name so an implementer can start without re-deriving the architecture. Shared conventions:

- `ResortSimulation` stays a data-only `RefCounted`: no nodes, no signals. UI polls fields on its 0.5 s refresh in `main.gd::_process`.
- New simulation fields are added to `snapshot()` / `restore()` with `.get(key, default)` fallbacks so existing `.hif` saves keep loading. Bump `SaveStore.VERSION` only when the terrain array layout changes.
- Catalog IDs are stable save keys. New content is added to `Catalog` as dictionaries first; typed `ContentDefinition` resources are optional.
- Every plan lists the tests it adds. `./tools/test.sh` must stay green after each phase.
- Costs and balance numbers in plans are starting points, not final tuning.

## Suggested build order

Dependencies flow downward. Items on the same line are independent.

1. [Notifications and event log](03-notifications-event-log.md) — every later system reports through it.
2. [Statistics and history](13-statistics-history.md), [Guest feedback aggregation](02-guest-feedback-aggregation.md) — read-only over existing data, unlock the "why" behind numbers.
3. [Analytics overlays](01-analytics-overlays.md) — needs the traffic and wait samplers introduced with statistics.
4. [Per-hole maintenance](04-per-hole-maintenance.md) — replaces the aggregate `terrain.wear`; the wear overlay depends on it.
5. [Staff depth](07-staff-depth.md) — builds on per-hole assignments.
6. [Facilities and upgrades](10-facilities-and-upgrades.md), [Unlock progression](09-unlock-progression.md) — catalog expansion and gating.
7. [Pricing depth](08-pricing-depth.md), [Marketing and reputation](06-marketing-reputation.md), [Memberships and returning guests](05-memberships-returning-guests.md) — the demand model rewrite; do pricing first because reputation and memberships both read the new demand pipeline.
8. [Green shapes and hazards](11-green-shapes-hazards.md), [Hole design metrics](12-hole-design-metrics.md) — course-design layer; metrics read the new hazard data.
9. [Multiple maps](14-multiple-maps.md) — last, because it needs the final `TerrainModel` field set to define presets against.
10. [Calendar, seasons, and monthly settlement](15-calendar-seasons.md) — implemented; records the continuous-play day model the plans above were re-based onto, plus open balance items.

Deferred items (goals and scenarios, guided onboarding, spline paths, settings menu, camera modes, blueprints, music) are tracked in the top-level `README.md` under "Planned features". Weather and seasons are covered by plan 15.
