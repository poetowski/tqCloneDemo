# Roadmap and progress

The vertical slice's plan and state. Update this at the end of every working session.

## Milestones

| # | Milestone | State |
|---|---|---|
| 0 | Harness: docs, `CLAUDE.md`, `tools/dev.mjs`, `.mcp.json` (godot + blender MCP), GUT, check | done |
| 1 | Asset pipeline: palette → kit → glb → import swap → palette shader; preview renders | done |
| 2 | Characters: hero (armour variants), shades (hoplite/archer/captain), boar, bronze bull, Klotho, Dion; humanoid + quadruped rigs with ~20 actions | done |
| 3 | Items: 11 weapons, 4 shields, 6 helmets, armour, trinkets, quest items; icons from the models | done |
| 4 | Props: nature (14), village (13), ruins (14), shrines (5), pottery (3), VFX kit | done |
| 5 | Core gameplay: click-to-move on navmesh, attacks with impact timing, stats, damage, statuses, enemies (melee/ranged/charger), packs that rise, loot, XP and levels | done |
| 6 | Skills: Lunge, Aspis Bash, Fate's Lash, War Cry, Bound Shades, Atropos' Mercy; the Loom panel | done |
| 7 | UI: orbs, skill bar, XP thread, target/boss frames, damage numbers, banners, quest tracker; bag with sized items + paper doll + tooltips with comparison; hero panel; dialogue; pause; title; end card | done |
| 8 | The zone, Elaion: terrain, sea, 590+ props, grass, 12 packs, 3 hearths, 2 chests, 12 pots, the gate, 6 zones, the boss arena | done |
| 9 | Story: three quests, Klotho and Dion's dialogue, intro, the seal and the gate, the boss and the First Blade, end card | done |
| 10 | Audio: 43 effects, 5 ambience loops, 6 music tracks, all synthesized in Blender | done |
| 11 | Verification: 44 unit/smoke tests; `npm run tour` end to end with a strong hero and a level-1 playthrough (both complete the demo); `--scenario=paths` navmesh check | done |
| 12 | Polish pass (see below) | next |

## Next (polish, in priority order)

1. **Boss with real players**: the bull is balanced against the autopilot, which dodges
   telegraphs but never baits a charge into a column (the key move). Watch people play;
   tune telegraph timings, phase-two summons, the number of draughts on hand at the bull
   (2–5 in runs: a guaranteed pair before the sanctuary would steady it).
2. **Feel**: hit-stop/shake tuning, swing trails per weapon, enemy hit reactions, a short
   camera push on the boss intro, footstep sounds.
3. **Enemy pathing**: enemies still follow `NavigationAgent3D` (3D point reach, corner
   skipping at 1.0 m); move them to the Player's ground-plane path following if they
   snag on terrace walls.
4. **Readability**: loot label stacking; fog of war on the maps (explored ground only).
   (Hover highlight, the minimap with goal markers and the full map are in.)
5. **More life**: butterflies and lizards in the sun, fish jumping in the bay, sounds for
   the gulls and crows. (Moods per area, wind, cloud shade, motes, birds and smoke are in.)
6. **Merchant** in Elaion (sell junk, buy draughts) — the gold sink the loot loop wants.
7. **Save/continue** (JSON): hero, bag, gear, Loom, quests, world flags.
8. **Settings**: volume sliders, key rebinding, resolution.
9. More armour visuals (helmet crests by rarity, cloaks), Klotho's weaving animation polish.
10. Performance pass on battery (the laptop throttles): LODs for props, grass distance.

## Known issues

- The automated tour needs the navigation map's first async sync (~0.5 s); actors move
  straight toward goals before it.
- When walking makes no progress for 0.75 s the Player hops back onto the navmesh and
  asks for a new path: a safety net. The walk tests in `--scenario=paths` cover the
  spots that once caught it; add new ones there when one turns up.
- Tours report times in real seconds; the machine can't keep `--speed=3`, so they run
  close to real time.
- Text uses Godot's default font (no font files are made yet; a lapidary bitmap font from
  Blender is a possible follow-up).

## Log

- **2026-11-23** — Project started. Pipeline, all assets, gameplay systems, UI, the zone,
  story, audio, tests and docs built. Renamed the zone from Helos (a Titan Quest place)
  to **Elaion**.
- **2026-11-24** — Navigation fixes (async map sync, agent height offset, gate ramp,
  tholos), knockback keeps actors on the navmesh, headless `npm run tour`. Terrain
  collider on its own layer (post-import matched the wrong node). Boss resets when the
  hero dies or flees, boss damage rebalanced; quests skip goals the world already met;
  the First Blade always ends the demo. Hover highlight, necropolis mist, title camera
  over the bay, brighter logo. Audio stops at exit (no leaks). Both MCP servers proven
  live (Blender: code execution + render; Godot: editor connected) via `tools/mcp_probe.mjs`.
- **2026-11-24 (later)** — Verification pass: the automated runs now both finish the demo.
  Fixed on the way: unrisen Unthreaded could be targeted; enemies drifted on in their
  last direction whenever they stopped (the avoidance callback fires every frame; the
  bull walked out of its arena that way); the bull keeps to its arena (charges stop at
  its edge, it turns on a hero striking from the edge, mends while it waits: slowly
  after a death, fast against a sniper); story items always fit the bag; loot lands on
  walkable ground. Navmesh: the seabed is cut, islands under 16 m² dropped, and only the
  ground connected to the start is kept (the hills baked as cut-off walkable slopes);
  ledges climb 0.25 m and walks lift over 0.3 m. The hero follows its path on the
  ground plane (corner points round wall ends were skipped; points over the floating
  mesh never counted as reached). Balance: XP curve in `data/progression.json`
  (45 × L^1.5), more draughts from trash and beasts, the bull at 700 health / armour 20
  / 8–13 damage with a slow-sweeping breath (`bronze_bull.moves`), a third hearth in the
  sanctuary court, hearths heal only when lit. `npm run tour -- --scenario=paths` checks
  route links, islands, the sea and walks from old trouble spots. Results: strong hero
  completes in ~3 min, bull down in 53 s; level-1 playthrough reaches the bull at level
  7 with no deaths (after Klotho's chiton), beats it in 1–4 tries, ends at level 9.
- **2026-11-24 (terrain)** — Easier to walk: terrace banks became walkable slopes with
  broken wall segments, a 3 m walkable verge along every edge, paths 2 m wider. The
  path check now measures detours: mean 1.17 → 1.05, worst 3.9 → 1.7, walkable area
  +32%. Navmesh flood fill compares heights (a temple top no longer counts as reached
  ground); actors set back on the ground land on its surface, not the navmesh's height.
  Fixed: a hovered item or foe freed under the cursor threw errors on every click.
- **2026-11-24 (environment)** — Richer land: olive trees with roots, two-tone crowns and
  silver sprigs; fuller cypresses; Aleppo pines, fig trees, broom, thyme, acanthus, reeds,
  tall grass, clover, wildflowers, pebbles, driftwood; herms on the road, battle debris in
  the necropolis, offerings at the Fates, nets on the shore. Plants sway on the new
  `Foliage` material; cloud shade drifts over everything; each area blends its mood
  (`data/atmosphere.json`: haze, grading, sun, wind, clouds, motes); gulls and crows
  wheel; hearth smoke rises. Minimap (top right, goal marker pinned to its rim when far)
  and full map (Tab / M), both drawn from a Blender render of the level. Props 560 → 644,
  ground cover ~3 300 → ~5 900. `npm run import -- --force` now really reimports.
- **2026-11-24 (fix)** — The hero sometimes froze: once the foe or item under the cursor
  was freed, every click and frame errored on it before the move was given (the guard
  `hovered != null` is false for a freed object). The hover is now tracked by instance id.
- **2026-11-24 (world)** — A mechanism for growing the world consistently:
  [WORLD.md](WORLD.md) (the laws, the three acts, the zone template),
  [CANON.md](CANON.md) (every name, plus names that aren't ours),
  [EXPANSION.md](EXPANSION.md) (recipes and a review list), [DECISIONS.md](DECISIONS.md)
  (D1–D11). `npm run canon` checks names and doc links and runs first in `npm run verify`.
