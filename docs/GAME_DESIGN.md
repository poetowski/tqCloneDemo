# UNTHREADED: game design (vertical slice)

> *The Fates' shears are stolen. Nothing can die. You already did.*

Working title **UNTHREADED**. An isometric action RPG in the lineage of Titan Quest,
Grim Dawn and Diablo, set in mythic Greece. This file is the design of the
**vertical slice**: one zone, one hero, a full loop from the first click to the first boss.
Lore and names live in [LORE.md](LORE.md), the look in [ART_BIBLE.md](ART_BIBLE.md),
the map in [LEVEL_ELAION.md](LEVEL_ELAION.md).

## Pillars

1. **Every kill is a cut thread.** Hits are crisp, deaths are final and golden: the
   thread snaps, the shade unravels. Combat reads at a glance: telegraphs, clear hit
   feedback, numbers that matter.
2. **Myth you can walk through.** A sun-baked Aegean shore gone uncanny: whitewash,
   olive silver and terracotta, with Styx-teal seeping up through the cracks.
3. **Loot with a story.** Every drop is a Greek object with a Greek name. Mythic items
   carry a line of lore.
4. **Pottery come alive.** The art direction is black- and red-figure vase painting:
   bold silhouettes, terracotta, black, gold.

## Slice scope

| | |
|---|---|
| Length | 15–25 minutes, level 1 → about 7 |
| Zone | Elaion: village, olive terraces, cypress road, necropolis, Sanctuary of the Moirai |
| Hero | One class: the Threadless hoplite (spear/sword + shield) |
| Enemies | Unthreaded Hoplite, Unthreaded Archer, Styx Boar, Captain (champion), boss **Khalkotauros** |
| Skills | 5 actives + 1 passive on the Loom (skill panel) |
| Loot | 4 rarities, ~16 bases, ~20 affixes, 4 mythic uniques, potions, drachmae |
| Quests | 3 linked steps from Klotho the weaver to the bronze bull |
| End | The first blade of Atropos' shears, then a "to be continued" card |

## Core loop

explore → meet a pack → fight (attack, skills, potions) → loot → equip / spend points →
reach the next landmark (shrine, quest step) → boss.

## Controls

| Input | Action |
|---|---|
| LMB (click or hold) | Move; on an enemy, attack; on an item, pick up; on an NPC or object, interact |
| Shift + LMB | Attack in place (don't move) |
| RMB | Skill slot 1 (Lunge by default) |
| Q W E R | Skill slots 2–5 |
| 1 / 2 | Healing Draught / Ichor Draught |
| I / C / K | Inventory / Character / The Loom (skills) |
| Alt (hold) | Show every item label on the ground |
| Mouse wheel | Zoom |
| Esc | Close panels, otherwise pause menu |
| F12 / F3 | Screenshot to `.shots/` / debug overlay (dev) |

## Hero stats

- **Attributes**: Might, Cunning, Spirit, 10 each at level 1, **+3 points per level**.
  - Might: +2 max health and +1.5% physical damage per point.
  - Cunning: +1% attack speed and +0.25% critical chance per point.
  - Spirit: +2 max ichor, +2% skill damage and +0.05 ichor/s per point.
- **Health** 80 + 12/level, regenerates 0.6/s. **Ichor** (the gods' golden blood; skill
  energy) 40 + 4/level, regenerates 2/s.
- **Damage** = weapon roll × (1 + Might bonus + % bonuses) × skill multiplier.
  Critical hits (base 5%) deal ×1.75 and show in gold.
- **Armor** mitigates physical damage: `taken = dmg × 100 / (100 + armor)`.
- **Move speed** 6 m/s. **Attack speed** comes from the weapon (attacks per second).
- **Levels**: XP to next level = `round(45 × L^1.5)` (`data/progression.json`): about
  1 900 XP to level 7, which a hero who clears Elaion and turns in both quests earns by
  the bull. Each level: +1 skill point and +3 attribute points, a full heal, and a golden
  "thread spun" flourish.

## Skills: the Loom

The skill panel is a loom: each skill is a thread with up to 5 knots (ranks). The hero
starts knowing **Lunge** (rank 1) with **1 unspent point**, and gets +1 point per level.

| Skill | Type | Unlock | Effect (rank 1 → per rank) | Ichor | Cooldown |
|---|---|---|---|---|---|
| **Lunge** | active | 1 | Dash 6 m toward the cursor, hitting all in the path for 130% weapon damage (+15%) | 8 | 3.0 s (−0.2) |
| **Aspis Bash** | active | 1 | 100° cone, 3 m: 90% weapon damage (+12%), stun 1.0 s (+0.2) | 12 | 6 s |
| **Fate's Lash** | active | 2 | The golden thread whips 360°, 4.5 m: 100% weapon damage (+15%), pulls enemies 2 m inward | 18 | 7 s |
| **War Cry of Ares** | active | 3 | 8 s: +25% damage (+5%), +15% attack speed; enemies within 7 m slowed 40% for 3 s | 25 | 18 s |
| **Bound Shades** | active | 5 | Bind 2 golden shades (3 at rank 4) to fight beside you for 15 s (+2 s) | 35 | 30 s |
| **Atropos' Mercy** | passive | 1 | Non-boss enemies under 8% health (+2%) are severed outright when you hit them | — | — |

## Enemies

Numbers are level-1 values; data/enemies.json is the source of truth. All undead are **Unthreaded**: the slain who could not die. They rise out of the earth
in a column of teal mist when the hero comes near. Stats scale with level:
health × (1 + 0.28 × (level − 1)), damage × (1 + 0.18 × (level − 1)).

| Enemy | Role | HP | Damage | Speed | Notes |
|---|---|---|---|---|---|
| Unthreaded Hoplite | melee grunt | 34 | 5–8 | 3.6 | Rises from the ground; readable thrust wind-up |
| Unthreaded Archer | ranged | 24 | 4–7 | 3.4 | Keeps its distance, ghost arrows (projectiles) |
| Styx Boar | charger | 46 | 7–11 | 5.2 | Paws the ground (telegraph), then charges in a line; knockback |
| Captain Lykos | unique | 240 | 9–14 | 3.9 | Bigger, black crest, a cleaving spin every third swing, carries the Seal |
| **Khalkotauros** | boss | 700 | 8–13 | 4.2 | Armour 20. See below (≈1900 health at level 7) |

**Champions**: any pack may roll a champion (12%): ×2.2 HP, ×1.4 damage, a gold name and
a guaranteed Blessed+ drop.

### Boss: Khalkotauros, the Bronze Bull of Hephaestus

A fire-breathing bronze bull from the god's forge. A stolen thread is wound into its
furnace heart, so it cannot be unmade, until the hero cuts it.

- **Gore**: front cone, 2.8 m, heavy damage.
- **Trample**: paws twice (a lane appears on the ground), then charges 18 m. If it
  hits a column it is **stunned for 2.5 s** and takes +50% damage. Dodging so that it
  hits a column is the key move.
- **Forge Breath**: lowers its head, the chest grille glows, then a 70°, 9 m fire cone
  for 2.4 s (a ground cone shows first). Burning ticks. The cone sweeps after the hero
  slowly (0.6 rad/s), so a sidestep gets out of it.
- **Hoof Quake**: rears up and slams down; a ring expands from 2 m to 7 m and must be
  outrun or taken.
- **Phase 2 (under 50%)**: the furnace cracks open (gold-teal), it attacks 25%
  faster, and every 20 s three Unthreaded Hoplites claw out of the arena floor.
- **Defeat**: it collapses, the furnace door bursts and the **First Blade of Atropos**
  falls out, with a loot fountain (a guaranteed Mythic).
- **The arena** is the ring of columns (15 m). The bull never leaves it: charges stop
  at the edge, and against a hero beyond it, it waits on the hero's side. Struck by a
  hero at the edge, it engages. If the hero dies, leaves, or stays more than 3 m beyond
  the edge for 6 s, it walks home and mends: 1%/s once the hero fell or left (a second
  try finds it still wounded), 6%/s while they linger within 4 m of the edge (no
  sniping it). Under half health its summons are Unthreaded two levels below it.
  Move numbers: `data/enemies.json` → `bronze_bull.moves`.
- Story items (the Seal, the Blade) always fit in the bag: if it is full, the plainest
  gear is set down on the ground to make room. All loot lands on walkable ground.

## Loot

**Rarities** (label colour, affixes):

| Rarity | Colour | Affixes | Base drop share |
|---|---|---|---|
| Mortal | bone white `#D8D2C4` | 0 | 70% |
| Blessed | Aegean blue `#5AA6E8` | 1–2 | 24% |
| Heroic | laurel green `#7CCF6A` | 2–3, better rolls | 5.5% |
| Mythic | ichor gold `#F2C14E` | fixed unique stats and a lore line | 0.5% (boss: guaranteed) |

**Bases** (16): Dory Spear, Xiphos, Kopis, Bronze Club · Pelte, Aspis · Pilos,
Attic Helm, Corinthian Helm · Chiton, Linothorax, Muscle Cuirass · Leather Wraps,
Bronze Greaves · Bronze Ring, Silver Ring, Owl Pendant.
Plus Healing Draught, Ichor Draught, drachmae and the quest items.

**Equipment slots**: weapon, shield, head, chest, legs, ring ×2, amulet.
Weapon, shield and helm change the hero's look; armour retints the body.

**Inventory**: a 10 × 6 grid with item sizes (weapons 1×3, shields 2×2, helms 2×2,
chests 2×3, greaves 2×2, rings and pendants 1×1). Potions go to the belt (stacks up to 9).

**Affixes**: prefixes (Spartan, Nemean, Keen, Swift, Brazen, Olympian…) and suffixes
(of Ares, of Hermes, of the Owl, of the Olive, of Ichor, of Heracles, of Odysseus,
of Orpheus, of the Hydra…). The full list is in `data/items/affixes.json`.

**Mythic uniques**: Ember of Hephaestus (kopis, the boss's), Gorgoneion of Elaion
(pendant), Thread-Woven Chiton (Klotho's gift), Spear of the Unbroken Line (rare drop).

**Breakables**: amphorae and pithoi shatter when clicked and drop potions, coins and
small loot. Chests hold more.

## Quests

1. **The Weaver of Elaion.** Old Klotho, sitting at her loom in the village, sends you to
   sever 10 Unthreaded in the olive terraces. Reward: the Thread-Woven Chiton, XP.
2. **Where the Dead Walk.** Cross the cypress road to the necropolis and destroy
   **Captain Lykos**, who carries the Seal of the Sanctuary. Reward: XP; the
   sanctuary gate opens.
3. **The Bronze Heart.** Climb to the Sanctuary of the Moirai and destroy Khalkotauros.
   Reward: the First Blade of Atropos. *End of the slice.*

## Death and shrines

Death costs nothing but the walk: you wake at the last **Hearth of Hestia** you lit (the
village, the necropolis, and the sanctuary court before the bull), with full health.
Lighting a hearth mends body and ichor once; a lit hearth is no well to run back to.
Enemies keep their wounds; the bull mends slowly while you are gone.

## Feel targets

- Click-to-move answers within a frame. Hold LMB to keep moving toward the cursor.
- Attacks commit: the hero turns, winds up and hits on the strike frame. Each weapon has
  its own speed.
- Hits get a 40 ms hit-stop on crits and kills, a white flash, a spark, a number and a sound.
- Deaths: the shade's thread snaps (a golden line flicks up), the body unravels into teal motes.
- Every enemy wind-up is readable (pose plus a ground marker on bigger moves).
