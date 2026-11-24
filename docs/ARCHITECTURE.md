# Architecture

How the code is put together. Design intent lives in [GAME_DESIGN.md](GAME_DESIGN.md);
asset production in [ASSET_PIPELINE.md](ASSET_PIPELINE.md).

## Autoloads (`src/autoload/`)

| Autoload | Job |
|---|---|
| `Events` | Signal bus: damage dealt, deaths, XP, level-ups, pickups, quests, areas, boss, player death/respawn, notifications, demo completed. Systems that don't know each other talk here. |
| `DB` | Loads `data/*.json` once: palette, enemies, skills, item bases, affixes, uniques, loot tables, quests, dialogue. Read-only. |
| `Game` | The player, level, camera, HUD references; shared RNG; hit-stop and shake; XP curve; respawn point; world flags (opened chests, lit hearths, the gate); scene changes. |
| `Quests` | Quest stages and counters from `data/quests.json`; listens to deaths and pickups; gives rewards; starts the next quest. |
| `Sfx` | Pooled 2D/3D sound players, music and ambience cross-fades; a missing sound is silent. |
| `DevTools` | `--shot` screenshots, scenarios, actor state logging, F12 screenshot, F3 overlay. |
| `MCPRuntime` | Godot MCP's in-game half (editor binary only). |

## Actors

```
Actor (CharacterBody3D)       health, faction, Stats, statuses (stun, slow, burn,
 │                            knockback), timed actions with an impact moment,
 │                            grounded movement (lifts over ledges ≤ 0.3 m), stays
 │                            on the navmesh after blows
 ├─ Player                    input → commands (MOVE, ATTACK, INTERACT), hover picking,
 │                            paths from NavigationServer3D followed on the ground
 │                            plane (renewed every 1.5 s; unsticks itself),
 │                            weapon attacks, potions, XP/levels/attributes,
 │                            Inventory + Equipment + SkillBook, gear visuals
 └─ Enemy                     data-driven (data/enemies.json): dormant → rising →
     │                        idle/wander → chase → attack (melee / ranged / charge),
     │                        pack alert, leash, champions, Bound Shade allies;
     │                        NavigationAgent3D with avoidance (moves only on frames
     │                        its AI steered)
     └─ BronzeBull            boss: arena trigger, gore, trample (column crash →
                              vulnerable), forge breath, hoof quake, phase two;
                              keeps to its arena, mends while it waits
                              (bronze_bull.moves in data/enemies.json)
ActorBody (Node3D)            the imported model: AnimationPlayer (loops, one-shots
                              timed to a duration), BoneAttachment slots from
                              data/attachments.json, mesh variants, shader effects
Projectile                    straight flight, hits the first hostile, stops on walls
```

Combat flow: an attack calls `start_action(anim, duration, on_impact)`; at the impact
fraction the attacker queries targets with `Combat.in_cone/in_radius/along`, rolls a
`DamageInfo` (Player: weapon roll × Might, %, skill bonuses, crits; Atropos' Mercy
marks severs) and calls `take_damage`. The victim applies armour, flashes, emits
`Events.damage_dealt` (floating numbers, sounds) and dies at zero health
(`Events.actor_died` → XP, loot, quest counters, dissolve).

## Stats

`Stats` = base values + modifier sources (`eq_weapon`, `buff_war_cry`...) of
`{stat, flat, pct}`; `value(stat) = (base + flat + derive(stat)) × (1 + pct/100)`.
The Player's `derive` turns level and attributes into health, ichor, regen and crit.
Percent-only stats (attack speed, magic find) have a base of 100.

## Items

`Item` (rolled instance: base, rarity, item level, affixes or a unique id) → `mods()`
and `describe()` (tooltip lines). `Loot` rolls bases, rarities (magic find shifts
weight from Mortal), affixes (one prefix + one suffix name the item) and whole loot
tables. `Inventory` is a grid with item sizes; `Equipment` has eight slots.
`GroundItem` shows a dropped item (model, rarity-coloured label, beam for Heroic+) and
auto-collects coins and draughts. `LootDrop` spills a table's roll around a point.

## Skills

`SkillBook` keeps ranks and points; parameters come from `data/skills.json` as
`[value at rank 1, change per rank]`. `SkillCaster` (child of the Player) checks rank,
ichor and cooldown, then runs the skill: Lunge (dash, hits along the path), Aspis Bash
(cone stun), Fate's Lash (360° hit + pull), War Cry (buff source + slow), Bound Shades
(golden ally Enemies). The passive Atropos' Mercy is applied in `Player.deal`.

## World

- `Level` (base): spawns the Player, GameCamera and HUD, adds the panels, bakes
  navigation if the scene has none, respawns the hero at the last hearth.
  `ElaionLevel` adds the story: intro, the first quest, the boss, the end card, and the
  automated `tour` scenario.
- `GameCamera`: fixed-pitch isometric follow, zoom, shake, mouse rays, dithers away
  props (group `fadeable`) that block the view of the hero.
- `Spawner`: a pack; Unthreaded lie dormant until the hero is within range, then rise.
- `NPC` (dialogue by quest state), `Shrine` (Hearth of Hestia: respawn point),
  `Chest`, `Breakable` (pots), `SanctuaryGate` (needs the seal), `Zone` (banner +
  music by distance), `Fire`, `GrassField` (MultiMesh chunks).

## UI

`HUD` (CanvasLayer, keeps running while paused): orbs (shader), skill bar
(`SkillSlot`), XP thread, target frame, boss bar, messages, area banners, quest
tracker, point buttons, death veil, `FloatingNumbers`. Panels extend `GamePanel`:
`InventoryPanel` (paper doll + grid, lift/place/swap/drop, tooltips via
`ItemTooltip` with comparison), `CharacterPanel`, `LoomPanel`, `DialoguePanel`,
`PausePanel`. `UIStyle` holds the black-figure look. Title (`src/ui/title/`) and end
card (`src/ui/end/`).

## Data files

| File | Holds |
|---|---|
| `data/palette.json` | the 64 swatches (colour, roughness, metal, emission) |
| `data/enemies.json` | stats, AI kind, attacks, models and attachments per enemy |
| `data/skills.json` | the Loom |
| `data/items/bases.json`, `affixes.json`, `uniques.json`, `loot_tables.json` | loot |
| `data/quests.json`, `data/dialogue.json` | the story |
| `data/attachments.json` | where items sit on bones |
| `data/level/elaion_layout.json` | generated by the level script |

## Physics layers

1 world (props, walls) · 2 player team · 3 enemy team · 4 interact (click areas) ·
5 projectile · 6 terrain. Mouse picking casts against 3|4 (with areas) and 1|6 for the
ground point; navigation is baked from static colliders on 1|6.

## Testing

- `npm run check` loads everything; `npm test` runs GUT (`tests/unit/`: stats, items,
  inventory, loot, skills, quests).
- `npm run shot -- ... --scenario=` drives visual checks; `DevTools` prints actor states.
- `npm run tour`: headless end-to-end play-through with `Autopilot`.
