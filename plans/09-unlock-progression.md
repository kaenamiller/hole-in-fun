# Unlock progression

## Goal

Separate "how good is my resort" (grade) from "what can I build" (unlocks). Add a research-and-milestone tree so new facilities, scenery collections, staff roles, campaigns, and course tools unlock through play choices rather than only through the three grade thresholds.

## Current state

- `Catalog` entries carry `grade` / `min_grade`; `can_build(kind)` and `unlocks()` compare against `sim.grade`.
- `_update_grade` promotes when cash, buildings, holes, publicity, satisfaction, wear, and a qualifying event are all met.
- Sandbox bypasses grade checks.

## Design

### Unlock nodes

New `Catalog.unlocks()` returning nodes:

```gdscript
{"id": "cart_fleet", "name": "Cart Fleet", "branch": "operations"|"course"|"hospitality"|"prestige",
 "cost": 12000.0, "days": 3, "requires": ["…node ids…"], "grade": 1,
 "milestone": {"kind": "completed_visits"|"rating"|"holes"|"events_won"|"members"|"beauty_peak", "value": 200},
 "grants": ["cart_barn", "marketing:radio_spot", "role:marshal", "tool:bunker_shape"]}
```

A node is **available** when every `requires` node is complete, `grade` is met, and its optional `milestone` is satisfied. The player then **commits** cash and the node completes after `days` days (a "project" the log reports). Milestones give players goals that reflect play, e.g. "Host a successful Charity Scramble" unlocks the club championship.

Starting tree (about 24 nodes, four branches):

- **Operations**: `cart_fleet` → `cart_barn`; `greenkeeping` → `maintenance_shed`, groundskeeper training; `irrigation` → halves overnight decay; `night_crew` → late shift; `fleet_upgrade` → +50 % cart capacity.
- **Course**: `bunker_craft` → sand shaping tool tiers; `green_complex` → non-circular greens (green shapes plan); `water_features` → decorative pond, water hazard tool; `championship_tees` → multiple tee boxes; `signature_hole` → design-metrics badge that adds awareness.
- **Hospitality**: `snack_bar` → kiosk upgrade; `pro_shop`; `restaurant`; `lodge` (multi-day stays, facilities plan); `member_lounge` → memberships tier 2 and 3.
- **Prestige**: `local_press` → campaigns; `regional_circuit` → regional amateur event; `invitational_rights`; `founder_program`.

Grade requirements move to their own node type (`"kind": "grade"`) so the Events panel text and `_update_grade` read from the same data. Each grade node lists the branch nodes it needs (e.g. Club requires `greenkeeping` and `local_press`), which replaces the current hard-coded satisfaction and wear thresholds with visible prerequisites.

### Rules

- `can_build(kind)` becomes: unlocked if `kind` appears in any completed node's `grants`, or if the catalog entry has no gating node (base content: clubhouse, restroom, kiosk, range, basic scenery, paths).
- Sandbox still bypasses everything but shows the tree for reference.
- Only two projects may run at once; committing a project charges the full cost immediately (refundable at 80 % if cancelled the same day).
- Completed nodes are saved as ids in `sim.unlocked: Array[String]`, projects in `sim.projects`.
- Migration: an old save at grade N marks every node with `grade <= N` and no `milestone` as complete so nothing already built becomes illegal.

### UI

New **Progress** tab (icon `✦`, header "THE PLAN"): four branch columns, nodes as cards with state (locked / available / in progress with days left / complete), cost, milestone text and current progress, and a Commit button. Selecting a node highlights its prerequisites. The Build panel greys out locked items with a tooltip naming the unlocking node. The Events panel's grade text links to the grade node.

## Files

- `scripts/catalog.gd`: `unlocks()`, `grants` mapping helper `unlock_for(kind) -> Dictionary`.
- `scripts/resort_simulation.gd`: `unlocked`, `projects`, `commit_project`, `cancel_project`, `_tick_projects` in `_end_day`, `milestone_progress(node)`, revised `can_build`, `unlocks`, `_update_grade`, snapshot/restore with migration.
- `scripts/resort_ui.gd`: Progress tab, Build panel lock states.
- `docs/SIMULATION.md`: tree and rules.

## Tests

- `tests/test_simulation.gd`: `cart_barn` is not buildable at start; committing `cart_fleet` charges cost and after 3 `_end_day` calls `can_build("cart_barn")` is true; a milestone node stays unavailable until `completed_visits` passes the value; a third concurrent commit is rejected; grade promotion requires its listed nodes.
- `tests/test_regressions.gd`: restoring an old grade-2 save marks grade-1 and grade-2 nodes complete and every already-placed object remains `can_build`; sandbox unaffected.
- `tests/test_game.gd`: Progress tab renders; Build buttons disabled for locked kinds.

## Phases

1. Data model, `unlocked`/`projects`, `can_build` rewrite with migration, grade nodes. Behaviour identical for the current catalog.
2. Progress tab and Build panel lock states.
3. New branch content as its dependent plans land (each plan adds its own nodes).

## Dependencies

- Facilities, staff, marketing, memberships, and green-shape plans each contribute `grants` targets; this plan should land first with the base tree, and they append nodes.
