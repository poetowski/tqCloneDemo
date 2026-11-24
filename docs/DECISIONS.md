# Decisions

Why things are the way they are. Before changing one of these, read its reason; if you
still change it, add a new entry that replaces it (don't edit the old one), and update
the docs it touches. New entries go at the bottom, numbered on.

Format: **D-number: the decision** (date). *Why.* What follows from it.

## D1: Every asset is made by our own Blender scripts (2026-11-23)

*Why:* one consistent look and full ownership: no asset packs, downloads, marketplace
or AI-service assets, whatever their license. Models, animations, textures, icons, the
logo, sounds and music all come from `tools/blender/`. Inspiration is fine; copying isn't.

## D2: The palette is law: 64 swatches (2026-11-23)

*Why:* a small fixed set of colours keeps every model, prop and effect in one visual
family. Models map faces onto swatches in `data/palette.json`; no free colours. A swatch
is added only for a genuinely new material, at the end of the list.

## D3: Original names only (2026-11-23)

*Why:* the game draws on Titan Quest, Grim Dawn and Diablo for its genre, never for its
names. The village was first called Helos, a Titan Quest place: renamed **Elaion**. Names
are registered in [CANON.md](CANON.md) and checked by `npm run canon` (D11).

## D4: The hero is the unnamed Threadless, one person (2026-11-23)

*Why:* the premise needs exactly one being outside fate: the only one who can sever.
A second playable class would need its own reason to hold no thread
([WORLD.md](WORLD.md#open-questions)).

## D5: One blade per act; the thief is revealed only in the last act (2026-11-23)

*Why:* gives every act a goal and the whole game a mystery. Each act adds one clue.

## D6: Story items always fit the bag; loot lands on walkable ground (2026-11-24)

*Why:* the Seal and the First Blade gate the story; a full bag must never block them.
When it is full, the plainest gear is set down to make room.

## D7: The bull keeps to its arena and mends slowly while it waits (2026-11-24)

*Why:* it once charged out through the gate and got wedged there, and a fallen hero
found it fully healed every time. Now charges stop at the arena's edge; after a death it
mends 1%/s, so a second try finds it still wounded; it mends 6%/s while the hero lingers
at the edge, so it can't be sniped. Numbers in `data/enemies.json` (`bronze_bull.moves`).

## D8: Hearths heal once, when lit; a hearth before every boss (2026-11-24)

*Why:* a lit hearth that healed on every click was a free well to run back to mid-fight.
A hearth just outside each boss's reach keeps retries short.

## D9: XP brings a thorough hero to the boss's level (2026-11-24)

*Why:* a level-1 playthrough reached the bull at level 4 and lost. The curve
(`45 × L^1.5`, `data/progression.json`) is tuned so clearing Elaion and turning in both
quests gives about level 7, the bull's level.

## D10: Ground is generous: walkable banks, verges, only connected navmesh (2026-11-24)

*Why:* players and the autopilot got stuck or took long detours: near-vertical terrace
banks behind continuous walls, steep edges, the seabed and cut-off hilltops in the
navmesh. Now terrace banks are walkable slopes with wall segments and gaps, every edge
has a 3 m walkable verge, and the level build keeps only ground connected to the start.
Each zone must meet the navigation targets in [WORLD.md](WORLD.md#a-new-land-a-new-zone),
measured by `npm run tour -- --scenario=paths`.

## D11: Consistency is checked, not remembered (2026-11-24)

*Why:* as the world grows, nobody can keep every name and rule in their head.
[CANON.md](CANON.md) registers every name; `npm run canon` (part of `npm run verify`)
fails on unregistered names, names that aren't ours and broken doc links. The laws of the
world live in [WORLD.md](WORLD.md), the recipes in [EXPANSION.md](EXPANSION.md).

## D12: The map is a Blender render of the level, its moods are data (2026-11-24)

*Why:* the minimap must look like the world and stay true to it. The level script
renders it from the same terrain and prop models the game uses, so it is our own asset
(D1) and is rebuilt with the level. The art bible's area moods, wind and cloud shade
live in `data/atmosphere.json`, reached by every shader through shader globals, so a new
area's air is a few lines of data. Plants sway because they are painted with the
`Foliage` material, not because of their colour, so nothing that only shares a leaf's
colour sways.
