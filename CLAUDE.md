# UNTHREADED (tqCloneDemo)

An isometric action RPG vertical slice in the Titan Quest / Grim Dawn / Diablo lineage,
set in mythic Greece: the Fates' shears are stolen, nothing can die, and the hero, the
Threadless, cuts the threads of the dead. Godot 4.7.2 (GDScript, Forward+, Jolt), every
asset made by Blender 5.2.3 scripts.

Read before working:
- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): what the slice is (combat, skills, loot, quests)
- [docs/ART_BIBLE.md](docs/ART_BIBLE.md): the one look, the palette rules, VFX and UI language
- [docs/LORE.md](docs/LORE.md): story, characters, voice for any text
- [docs/LEVEL_ELAION.md](docs/LEVEL_ELAION.md): the zone's layout, encounters, flow
- [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md): how Blender scripts become game assets
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): code structure, systems, data files
- [docs/ROADMAP.md](docs/ROADMAP.md): what's done, what's next, known issues

## Rules

- **Every asset is made by our own scripts in Blender**: models, animations, textures,
  icons, the logo, sounds and music (`tools/blender/`). No asset packs, downloads,
  marketplace or AI-service assets, whatever their license. Inspiration only.
- **Original names only.** Never reuse place, character or item names from Titan Quest,
  Grim Dawn or Diablo (the village is *Elaion*, not Helos). Greek myth itself is fine.
- **The palette is the law** (`data/palette.json`, 64 swatches): models map faces onto
  swatches; no free colours. Add a swatch only for a genuinely new material, at the end.
- Gold = fate/hero/loot, teal = death/Styx, red-orange = enemy telegraphs, fire = Hephaestus.
- Typed GDScript (untyped declarations are errors). Signals in the past tense.
  Tunables in data (`data/*.json`) or `@export`, not buried literals.

## Commands

| Command | What it does |
|---|---|
| `npm run models [-- <script>...]` | Runs Blender asset scripts headless (palette, characters, props, items, level) → `assets/models/**.glb`, then imports. Name scripts to build only those (`npm run models -- hero pottery`). |
| `npm run icons` | Renders item/skill icons, the title logo and the window icon in Blender. |
| `npm run audio` | Synthesizes every sound and music loop in Blender (`aud` + numpy). |
| `npm run assets` | All of the above, in order. |
| `npm run level` | Rebuilds `src/world/elaion/elaion.tscn` from `data/level/elaion_layout.json` (run `npm run models -- elaion` first if the layout changed). Bakes the navmesh. |
| `npm run render -- <slug> [--anim=run --frames=0,4,8] [--attach=dory:weapon] [--hide=Mesh]` | Blender preview of a model into `.shots/models/`. Read the PNG. |
| `npm run check` | Import, then load every script/scene/resource; fails on errors. |
| `npm test` | GUT tests headless (`tests/`). |
| `npm run verify` | check + test. |
| `npm run shot -- [scene] [--scenario=fight\|brawl\|panels\|loom\|hero] [--camera=x,y,z --look=x,y,z] [--frames=90]` | Plays a scene in a window, saves `.shots/<name>.png`, quits, and prints every actor's state. |
| `npm run tour [-- --minutes=12 --speed=3 --scenario=tour\|playthrough\|paths]` | Headless automated play-through of the whole zone; prints quests, kills, deaths, stuck spots; fails unless the demo is completed. `tour`: a strong hero (does it work?); `playthrough`: a level-1 hero who levels and equips like a player (is it fair?); `paths`: navmesh check (route links, islands, nothing under the sea). |
| `npm run game [-- scene]` | Plays (title screen by default). Blocks: run it in the background. |
| `npm run editor` | Opens the Godot editor (needed for the godot MCP tools). |
| `npm run blender` | Opens Blender with the MCP add-on listening on localhost:9876. |
| `npm run api` | Dumps the Godot 4.7.2 class reference into `.godot-api/` (grep it when unsure of an API). |

Binaries are pinned in `tools/dev.mjs` (`%LOCALAPPDATA%\Programs\Godot\4.7.2\`,
`%LOCALAPPDATA%\Programs\Blender\5.2.3\`); `GODOT` / `BLENDER` env vars override.

## Definition of done

1. `npm run verify` passes.
2. Visible changes are looked at: `npm run shot` (or `npm run render` for a model) and
   Read the PNG. Iterate until it matches the art bible.
3. Gameplay changes keep `npm run tour` completing the demo.
4. New logic gets a GUT test in `tests/unit/`.
5. `docs/ROADMAP.md` is updated: what changed, what's next.

## MCP servers (`.mcp.json`)

- **godot** (`godot-mcp-server@0.6.1`) talks to the editor plugin `addons/godot_mcp` on
  `ws://127.0.0.1:6505`; it works only while the editor has this project open
  (`npm run editor`). Live loop: `run_scene`, `send_input`, `take_screenshot {save_to:
  "res://.shots/x.png"}`, `get_errors`, `stop_scene`. `MCPRuntime` (autoload) is the
  in-game half; it only runs under the editor binary (patched, see `addons/README.md`).
- **blender** (`mcp-for-blender==2.2.4`) talks to the `blender_mcp.py` add-on on
  `localhost:9876` while Blender is open (`npm run blender`). Use it to inspect and try
  things in a live scene; anything worth keeping goes into a script in `tools/blender/`.
  Its asset-download services stay off: we never use third-party assets.
- MCP servers start with a Claude Code session; after editing `.mcp.json`, restart the
  session and approve them.
- Outside a session (or to script them), `node tools/mcp_probe.mjs` starts a server from
  `.mcp.json` and lists its tools; `... blender execute_blender_code '{"code": "..."}'`
  calls one tool; `... godot --session calls.json` keeps one godot server up, waits for
  the editor plugin to connect, and runs a list of calls (`read_scene`, `run_scene
  {wait_for_runtime: true}`, `take_screenshot`, `get_errors`, `stop_scene`). The plugin
  backs off exponentially after a server goes away, so use one session, not many calls.
- The editor and Blender are GUI windows on the author's desktop: open them only when
  needed and close them after. Long automated runs are headless (`npm run tour`).

## Gotchas

- A `--script` tool (`tools/*.gd`) is compiled before the autoloads exist: never name
  game classes that use `Game`, `DB`, `Events`... at the top level of a tool; `load()`
  their scripts inside `_initialize` (see `tools/build_level.gd`). Nodes needing the
  scene tree must wait for `process_frame` first.
- A runtime error in a `--script` tool leaves Godot running: `dev.mjs` kills it on a timeout.
- New `class_name` scripts need an import pass before shots/tests see them; `dev.mjs`
  re-imports automatically when scripts are newer than the class cache.
- Headless runs can't render: `shot` opens a window for a few seconds; `tour` is headless.
- Blender: bmesh `float_color` layers hold linear colours; set the mesh's active colour
  attribute or the glTF exporter writes none. Faces built by hand must wind
  anticlockwise (from outside) or back-face culling hides them.
- Blender `-colonly` / `-convcolonly` object names become Godot colliders on import;
  everything collides on layer 1 (world) except the terrain (layer 6).
- Models face -Y in Blender = +Z in Godot = `MODEL_FRONT`: turn actors with
  `look_at(point, Vector3.UP, true)`.
- Imported meshes get the project materials by name in `tools/import/post_import.gd`
  (`Palette`, `Terrain`, `Water`). Per-instance shader parameters (`flash`, `tint`,
  `fade`, `dissolve`, `highlight`) need no material copies.
- Godot re-imports a source only when its modified time changes; a byte-identical
  re-export or a post-import script change re-imports nothing. Run
  `npm run import -- --force` after changing `post_import.gd`.
- The navigation map syncs asynchronously: paths are empty for the first ~30 physics
  frames after a level loads (actors steer straight until then). Wait before querying.
  In a `--script` tool the map never syncs: work on the NavigationMesh's polygons.
- The navmesh floats 0–0.5 m above the ground (0.25 m cells plus detail error): judge
  path points on the ground plane, as `Player._path_direction` does, not in 3D. A
  `NavigationAgent3D` with a small `path_desired_distance` can stand on a point and
  never "reach" it; a large one skips the corner points round a wall's end.
- The navmesh climbs ledges up to `agent_max_climb` (0.25 m); a capsule only rides
  over ~0.14 m, so `Actor` lifts walks over ledges up to `STEP_HEIGHT` (0.3 m). Keep
  the two in step.
- With avoidance on, `velocity_computed` fires every physics frame with the last
  wanted velocity, not only when you set one: `Enemy` moves in it only on frames its
  AI steered, or a foe that stops to strike drifts on (the bull walked out of its arena).
- A `-col` mesh's generated body is a child named `StaticBody3D`: identify it by its
  parent's name.
- Ground placement at runtime: spawners raycast the terrain; set a node's `position`
  before `add_child` when `_ready` needs it (enemy home, boss arena centre).

## Layout

```
src/autoload/   Events (signal bus), DB (data), Game (state), Quests, Sfx, DevTools
src/core/       Stats, DamageInfo, Combat (targeting helpers)
src/actors/     Actor, ActorBody (model + animation + attachments), Projectile
  player/       Player (input, progress, items)    enemies/  Enemy (AI), BronzeBull (boss)
src/skills/     SkillBook (ranks), SkillCaster (the five skills)
src/items/      Item, Loot (rolls), Inventory, Equipment, GroundItem, LootDrop
src/world/      Level, GameCamera, Spawner, NPC, Shrine, Chest, Breakable, SanctuaryGate,
                Zone, Fire, GrassField; elaion/ (the zone scene + its story script)
src/ui/         hud/ (HUD, bars, skill slots, damage numbers), panels/ (bag, hero,
                Loom, dialogue, pause, tooltip), title/, end/, ui_style.gd
src/vfx/        Vfx (sparks, motes, rings, arcs, beams, threads, telegraphs)
src/shaders/    palette, terrain, water, vfx_additive, telegraph, orb
src/dev/        Autopilot, arena and pipeline test scenes
data/           palette, enemies, skills, items/, quests, dialogue, attachments, level/
assets/         models/ textures/ icons/ ui/ audio/ materials/ (generated; commit them)
tools/          dev.mjs, build_level.gd, check_project.gd, import/post_import.gd,
                blender/ (lib/ kit, humanoid, quadruped; textures/ characters/ props/
                items/ level/ render/ audio/)
docs/           design, art, lore, level, pipeline, architecture, roadmap
```
