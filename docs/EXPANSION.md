# Expanding the world

How to add to UNTHREADED without breaking what's there. Every recipe follows the same
loop:

1. **Write it down first.** Where it sits in the world ([WORLD.md](WORLD.md)), and its
   name in [CANON.md](CANON.md) (status *planned*). Check the name against the
   [naming rules](CANON.md#naming-rules) and the [laws](WORLD.md#the-laws).
2. **Data**, then **assets** (our Blender scripts only, palette swatches only), then
   **placement** in a level.
3. **Check**: `npm run verify` (canon, project check, tests). For levels and movement
   also `npm run tour -- --scenario=paths`; for anything you can meet in play,
   `npm run tour` and `npm run tour -- --scenario=playthrough`.
4. **Look**: `npm run render -- <slug>` for a model, `npm run shot` with a camera on the
   spot for anything in a level. Read the PNG; compare with [ART_BIBLE.md](ART_BIBLE.md).
5. **Record**: the CANON row goes to *canon*; [ROADMAP.md](ROADMAP.md) gets a log line;
   if a rule or a law changed, [DECISIONS.md](DECISIONS.md) gets an entry.

The checks catch what can be checked: unregistered or borrowed names, broken links,
missing models, icons and sounds, quests naming people or enemies that don't exist,
navmesh islands and stalls. The rest is review: read the review list at the end.

## A new enemy

1. **Name and role** in [CANON.md](CANON.md) (Creatures). Decide where it fits:
   which zone, which symptom of "nothing dies" it shows ([WORLD.md](WORLD.md)).
2. **Model**: a function in `tools/blender/characters/` (`shades.py` for Unthreaded
   variants, `beasts.py` for animals; humanoids use `lib/humanoid.py`, four-legged
   things `lib/quadruped.py` so they share the rigs and the ~20 actions). Faces on
   palette swatches; teal glow only for Styx and death. `npm run models -- <script>`,
   then `npm run render -- <slug>`.
3. **Data**: an entry in `data/enemies.json` (copy the closest one: health, damage and
   speed at level 1; `ai` melee / ranged / charger; `attack`; `rises` for the
   Unthreaded; `loot` table; `tags` for quests). Numbers go in
   [GAME_DESIGN.md](GAME_DESIGN.md#enemies)'s table too.
4. **Place it**: in a spawner's `pack` in the zone script (`L.thing("spawner", ...)`).
5. **Check**: `npm run verify` (the data tests confirm its model and gear exist), then
   `npm run shot -- --scenario=fight` near it.

## A new item, unique or affix

- **Base**: `data/items/bases.json` (slot, size in bag cells, `level` it starts dropping
  at, `weight`); its model in `tools/blender/items/` (weapons, shields, helmets, gear);
  `npm run models -- <script>` and `npm run icons`. If it is worn, where it sits is in
  `data/attachments.json`.
- **Unique**: `data/items/uniques.json` (a fixed base, fixed mods, one lore line in the
  voice of [LORE.md](LORE.md#tone)); tie it to a myth of the zone where it drops.
- **Affix**: `data/items/affixes.json`; prefixes name a people, beast or metal, suffixes
  a god or hero.
- Register every new name in [CANON.md](CANON.md) (Gear).

## A new person, dialogue or quest

1. **Who**: a row in [CANON.md](CANON.md) and in [LORE.md](LORE.md#characters) (what
   they are, how they speak). Gods only in disguise or through their works (law 5).
2. **Model**: `tools/blender/characters/npcs.py`.
3. **Dialogue**: `data/dialogue.json`, keyed by the NPC id: `name`, `intro` and topics.
   Short sentences, no modern idiom ([LORE.md](LORE.md#tone)).
4. **Quest**: `data/quests.json`: a `title`, `stages` (each a `text` and a `goal`:
   `talk` to an npc, `kill` an enemy or a `tag` a number of times, a world `flag`, an
   `item` in the bag), a `reward` (xp, a unique) and the `next` quest. Goals the world
   already met settle at once, so the order players do things in can't break a chain.
5. **Place**: `L.thing("npc", ...)` in the zone script.

## A new skill

`data/skills.json` (cost, cooldown and params as `[rank 1, per rank]`, a `desc` with
`{param}` slots), its behaviour in `src/skills/skill_caster.gd`, its icon in
`tools/blender/render/icons.py`, its row in [GAME_DESIGN.md](GAME_DESIGN.md) and
[CANON.md](CANON.md). Keep the Loom's rule: up to 5 ranks, unlocks by hero level.

## A new prop or sound

- **Prop**: a function in `tools/blender/props/` (`nature`, `village`, `ruins`,
  `shrines`, `pottery`); a `-col` or `-colonly` collider if it should block. Anything
  that blocks also shapes the navmesh: run the paths check after placing it.
- **Sound or music**: `tools/blender/audio/sounds.py` (synthesized; no recordings from
  elsewhere), then `npm run audio`. Code asks for sounds by name (`Sfx.play(&"name")`).

## A new zone

The biggest recipe. Elaion is the model: read [LEVEL_ELAION.md](LEVEL_ELAION.md) and
`tools/blender/level/elaion.py` first.

1. **Design on paper**: a `docs/LEVEL_<ZONE>.md` answering every question in
   [WORLD.md](WORLD.md#a-new-land-a-new-zone): myth anchor, symptom, level band,
   enemies, landmarks, boss and its trick, hearths, quest beats, palette accent, sound.
   Names into [CANON.md](CANON.md) as *planned*.
2. **The zone script**: copy `elaion.py` to `tools/blender/level/<zone>.py` and replace
   the design data: `ZONES` (plateaus: position, radius, height, kind), `PATHS`
   (corridors between them, 7–10 m wide), the terrain rules, and `plan()` (props,
   spawners, NPCs, hearths, chests, the boss mark, the test route). Keep the walkable
   banks and verges (D10 in [DECISIONS.md](DECISIONS.md)).
3. **Build**: `npm run models -- <zone>` writes the terrain and
   `data/level/<zone>_layout.json`; look at `.shots/<zone>_map.png`.
   `tools/build_level.gd` turns a layout into a scene with a baked navmesh (today it is
   wired to Elaion's files: give it the zone's paths as a parameter when you add the
   second zone).
4. **Its story script**: like `src/world/elaion/elaion.gd` (intro, quests, the boss's
   spawn and what ends the zone).
5. **Check**: `npm run tour -- --scenario=paths` must be clean and meet the navigation
   targets (detour mean ≤ 1.10, worst ≤ 2.0); then both tours; then shots of every
   landmark.

Before the second zone exists, three things need building once: the level build taking
a zone as a parameter, a way to travel between zones (an [open question](WORLD.md#open-questions)),
and saving the hero between them (roadmap: Save/continue).

## Review list

What no check catches. Read it before calling new content done:

- **Laws**: does anything die for good that the hero didn't kill? Does a god appear
  openly? Is there steel, glass or gunpowder? ([WORLD.md](WORLD.md#the-laws))
- **Colour**: teal only for death and the Styx, gold for fate, the hero and loot,
  red-orange only for enemy warnings.
- **Voice**: short sentences, concrete, a little wry; Greek words only where they stay
  readable; no fantasy filler names.
- **Fairness**: every attack that can hurt badly shows a red-orange warning first; a
  hearth before every boss.
- **Ground**: no spot where the hero can be knocked and stranded (add a walk test in
  `src/world/elaion/elaion.gd` `WALK_TESTS` when one turns up).
