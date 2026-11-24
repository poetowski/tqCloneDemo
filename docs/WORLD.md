# The world of UNTHREADED

What holds for the whole game, beyond the slice. Every new zone, creature, item or
line of text must agree with this page. Related pages:

- [LORE.md](LORE.md): the premise, Elaion's story, characters and the writing voice
- [CANON.md](CANON.md): every name, checked by `npm run canon`
- [EXPANSION.md](EXPANSION.md): how to add things, step by step
- [DECISIONS.md](DECISIONS.md): why things are the way they are
- [ART_BIBLE.md](ART_BIBLE.md): the look; the palette is law

## The laws

Changing one of these is a decision: record it in [DECISIONS.md](DECISIONS.md) first.

1. **The thread.** Every life is a thread: Klotho spins it, Lachesis measures it,
   Atropos cuts it. A cut thread is a death, and the soul goes down to Hades.
2. **The theft.** Atropos' shears were stolen and broken into three blades. Each is
   hidden in a different land and guarded by something the thief set there or turned.
   One blade per act. Until the shears are whole, nothing in the world can die.
3. **What "nothing dies" looks like.** The slain rise as Unthreaded where they fell, in
   what they wore. Beasts mend overnight. The Styx seeps up where death is refused,
   glowing teal. Hades starves. Each land shows this its own way (its *symptom*, see
   below); none may show a true death that the hero didn't cause.
4. **Only the Threadless severs.** What the hero kills stays dead; what anyone else
   kills gets up again. So wars don't end, nobody else can clear a road, and the hero's
   allies are bound shades, not soldiers.
5. **The gods are near but hidden.** They act through disguises (Klotho as old
   Klothia), works (Hephaestus' bull) and bargains. People speak of them with caution
   and some grievance. No Olympian fights the hero face to face before the last act.
6. **The thief stays unknown.** Each act adds one clue (Act I: a black thread in the
   bull's furnace). The reveal belongs to the last act.
7. **The age is bronze.** The Greece of myth, late Bronze Age to archaic: bronze, linen,
   leather, olive wood, clay, stone. No steel plate, crossbows, glass or gunpowder;
   iron is rare and fallen from the sky. Writing is scarce: stelae, seals, curses on lead.
8. **Colour means something.** Gold is fate, the hero and loot; teal is death and the
   Styx; red-orange is an enemy's warning; fire is Hephaestus. A land may add an accent
   from the palette; it never gives these colours another meaning.
9. **Myth is the source, names are ours.** Real myth, history and Greek words are free to
   use; coined names follow [CANON.md](CANON.md#naming-rules); nothing from the games
   we come from.

## The shape of the game

Three acts, one blade each. Only Elaion exists; everything else here is *planned*:
described, not named, until it is built (names are chosen then and registered in
[CANON.md](CANON.md)).

| Act | Land | The blade's guardian | Status |
|---|---|---|---|
| I | **Hellas**, the mainland: olive coasts, hill country, rivers, cities | Elaion: Khalkotauros, Hephaestus' bronze bull | Elaion built (the slice) |
| II | The wine-dark sea: islands, sea caves, a drowned harbour | A sea-thing the thief turned | planned |
| III | The edge of the world: where the Styx runs above ground | The thief | planned |

**Act I after Elaion** (planned). The hero has the first blade and follows the black
thread inland, toward the thief's first ally. Candidate zones, each with its symptom:

- High pastures where shepherds starve among flocks that cannot be slaughtered.
- A river ford where the drowned walk the riverbed and grab at travellers.
- A city whose funerals never end: the dead sit up at their own rites.
- The act's last zone holds the ally, whose defeat points across the sea.

**Act II** (planned). The sea gives back its drowned. Dion's brother, lost to the sea
"twice", is the thread that leads there (already said in Elaion).

## A new land, a new zone

Before building, write the zone down (in a `docs/LEVEL_<ZONE>.md`, like
[LEVEL_ELAION.md](LEVEL_ELAION.md)) answering each of these:

| Question | Elaion's answer |
|---|---|
| Myth anchor: which story is under it? | Hephaestus' forge-beasts; the Moirai's sanctuary |
| Symptom: how does "nothing dies" show here? | A forgotten siege's dead rise from the terraces and the necropolis |
| Level band | 1–7 (the bull is 7) |
| Its Unthreaded and its beasts | Hoplites, archers, a captain; Styx-touched boars |
| Landmarks (3–5, each visible from afar) | Village and well, olive terraces, the tholos, the sanctuary on the hill |
| Guardian or boss, and its trick | Khalkotauros; bait its charge into a column |
| Hearths (start, middle, before the boss) | Beach, necropolis, sanctuary court |
| Quest beats (who asks, what, what changes) | Klotho's errand → the Seal → the bull |
| Palette accent (existing swatches only) | Olive greens, whitewash, bronze, the teal of the Styx |
| Sound bed: ambience and music | Shore, cicadas, forge; village, field, necropolis, boss |
| Navigation targets (`--scenario=paths`) | Detour mean ≤ 1.10, worst ≤ 2.2 (around a hill is fine), no islands, no stalls |

## Progression across the world

- Levels rise with the journey: Elaion 1–7; each later zone adds about 3–5 levels.
  The XP curve is in `data/progression.json`, enemy scaling in
  [GAME_DESIGN.md](GAME_DESIGN.md#enemies).
- Item bases unlock by level (`level` in `data/items/bases.json`); each zone adds one or
  two mythic uniques tied to its own myth.
- Every zone ends in a boss with one learnable trick and telegraphed moves; nothing
  kills without a warning in red-orange.

## Open questions

Decide these before the work that depends on them, then record the answer in
[DECISIONS.md](DECISIONS.md).

- Who is the thief, and why? (Needed by the end of Act I.)
- How does the hero travel between zones and acts: on foot through edge exits, by ship,
  through hearths? (Needed before the second zone.)
- One hero or more? A second class would need its own reason to hold no thread.
