# Canon: every name in the world

The register of every proper name a player can read: places, people, creatures,
items, skills, quests, ideas. **A name exists in the world only once it is here.**
`npm run canon` (first step of `npm run verify`) fails when the game data shows a
name this page doesn't list, when a name from [Not ours](#not-ours) turns up
anywhere, or when a link in the docs points nowhere.

How to read and keep it:

- A name counts as registered when it appears here in **bold** or in `code`. Write the
  main name in bold; put the exact on-screen form in `code` when it differs.
- **Status**: *canon* (in the game), *planned* (agreed in [WORLD.md](WORLD.md), not built
  yet), *retired* (taken out; never reuse it for something else).
- **Source** says where the name comes from: *myth* (real Greek myth or history),
  *coined* (ours, with its roots), *word* (an ordinary Greek or English word).
- Adding a name: pick it by the [naming rules](#naming-rules), add its row here, then use
  it. Renaming: retire the old row, add the new one, record it in
  [DECISIONS.md](DECISIONS.md).

## Naming rules

1. Greek myth, history and language are ours to use: gods, heroes, monsters, real
   places, real words (*aspis*, *pithos*, *tholos*).
2. Coined names are built from Greek roots and say what they mean: *Elaion* (olive
   grove), *Khalkotauros* (bronze bull). Write the roots in the row.
3. Never a name from Titan Quest, Grim Dawn or Diablo, even one that happens to be a
   real word (Helos is a real ancient town; we still don't use it). See [Not ours](#not-ours).
4. One thing, one name. A disguise or a title is listed in the same row (*Klotho*, as
   `Old Klothia`).
5. Player-facing English stays plain and archaic-neutral: no modern idiom, no fantasy
   filler (*Shadowbane*, *Doomblade*). Item names are things a potter or smith of the
   Aegean would say.
6. "Sanctuary" is only ever a common noun (*a sanctuary of the Moirai*), never the name
   of the world.

## Places

| Name | Status | Source | What |
|---|---|---|---|
| **Elaion** | canon | coined: *elaiōn*, olive grove | The fishing and olive village above the sea; Act I's first zone |
| **The Olive Terraces** | canon | word | Five terraces of olives climbing east of Elaion |
| **The Cypress Road** | canon | word | The climb north between cypress rows |
| **Necropolis of the Forgotten Siege** | canon | word | The war dead's burial ground; the tholos of Lykos |
| **Sanctuary of the Moirai** | canon | myth | The hilltop sanctuary of the three Fates; the bull's arena |
| **Hades** | canon | myth | The underworld, starving for souls |
| **Styx** | canon | myth | The underworld river, seeping up as teal light where death is denied |
| **Hellas** | planned | myth | Act I's land (see [WORLD.md](WORLD.md)) |

## People and powers

| Name | Status | Source | What |
|---|---|---|---|
| **The Threadless** | canon | coined | The hero, unnamed; died halfway and got up |
| **Klotho**, as **Old Klothia** | canon | myth | The Spinner, disguised as a weaver in Elaion; quest giver |
| **Lachesis** | canon | myth | The Measurer; a statue in the sanctuary |
| **Atropos** | canon | myth | The Cutter, whose shears were stolen; her statue's hands are empty |
| **Moirai** | canon | myth | The three Fates together |
| **Dion the fisherman** | canon | myth (a common Greek name) | Villager by the well; lost his brother to the sea twice |
| **Captain Lykos**, shown as `Captain Lykos the Unthreaded` | canon | coined: *lykos*, wolf | Hoplite captain of the forgotten siege; carries the Seal |
| **Hephaestus** | canon | myth | Smith of the gods; built the bronze bull and the forge under the sanctuary |
| **Hestia** | canon | myth | Goddess of the hearth; her hearths call the fallen back |
| **The thief** | canon (unnamed) | — | Stole the shears; hinted at by a black thread. Name and nature open ([WORLD.md](WORLD.md)) |

## Creatures

| Name | Status | Source | What |
|---|---|---|---|
| **Unthreaded** | canon | coined | The dead who cannot die: teal-eyed shades in rusted bronze |
| **Unthreaded Hoplite** | canon | word | Spear or sword and shield; the common shade (both `shade_hoplite` and `shade_swordsman`) |
| **Unthreaded Archer** | canon | word | Keeps its distance, looses arrows |
| **Styx-touched Boar** | canon | word | A boar that mends overnight; charges |
| **Khalkotauros**, shown as `Khalkotauros, the Bronze Bull` | canon | coined: *khalkos* bronze + *tauros* bull | Hephaestus' bull, guardian of the first blade; the slice's boss |
| **Bound Shade** | canon | coined | An Unthreaded bound in gold to fight for the hero (skill) |

Champion titles (a pack's champion takes one): **Restless**, **Bronze-bound**,
**Hateful**, **Ever-hungry**, **Oathbreaker**, **Grave-cold** (canon, word).

## Things and ideas

| Name | Status | Source | What |
|---|---|---|---|
| **Blade of Atropos**, the first shown as `First Blade of Atropos` | canon | myth + coined | A third of the broken shears; one per act |
| **Seal of the Sanctuary** | canon | word | Bronze disc stamped with a spindle; opens the sanctuary gate |
| **Hearth of Hestia** | canon | myth | Respawn shrine: a round altar with an eternal flame |
| **Ichor** | canon | myth | The gods' golden blood; the hero's skill energy |
| **The Loom** | canon | word | The skill panel; a thread per skill, knots for ranks |
| **Drachmae** | canon | myth | Coins |
| **Healing Draught**, **Ichor Draught** | canon | word | The two belt potions |

## Gear

Bases (canon, word: real Greek arms and dress): **Dory Spear**, **Xiphos**, **Kopis**,
**Olivewood Club**, **Pelte**, **Aspis**, **Pilos Helm**, **Attic Helm**, **Crested Attic
Helm**, **Corinthian Helm**, **Chiton**, **Linothorax**, **Muscle Cuirass**, **Leather
Wraps**, **Bronze Greaves**, **Bronze Ring**, **Silver Ring**, **Owl Pendant**.

Mythic uniques (canon):

| Name | Source | What |
|---|---|---|
| **Ember of Hephaestus** | myth | Kopis still warm from the bull's forge; the boss's drop |
| **Gorgoneion of Elaion** | myth + coined | The village's old Medusa ward |
| **Thread-Woven Chiton** | coined | Klotho's gift, gold woven into linen |
| **Spear of the Unbroken Line** | coined | Lykos' spear; the phalanx that would not break |

Affixes (canon; prefixes name a people, beast or metal, suffixes a god or hero):
**Spartan**, **Nemean**, **Keen**, **Swift**, **Brazen**, **Olympian**, **Hephaestan**,
**Gilded**, **Ichorous**; **of Ares**, **of Hermes**, **of the Owl**, **of Heracles**,
**of Odysseus**, **of the Olive**, **of Ichor**, **of the Hydra**, **of Orpheus**, **of the
Tortoise**, **of Tyche**, **of Achilles**, **of the Phalanx**.

## Skills

| Name | Status | What |
|---|---|---|
| **Lunge** | canon | Dash through foes |
| **Aspis Bash** | canon | Shield cone, stuns |
| **Fate's Lash** | canon | The golden thread whips round, pulls foes in |
| **War Cry of Ares** | canon | Fury for the hero, dread for foes |
| **Bound Shades** | canon | Golden shades fight beside the hero |
| **Atropos' Mercy** | canon | Passive: the weakened are severed outright |

## Quests

| Name | Status | What |
|---|---|---|
| **The Weaver of Elaion** | canon | Klotho's errand: sever ten Unthreaded |
| **Where the Dead Walk** | canon | Take the Seal from Lykos, open the sanctuary |
| **The Bronze Heart** | canon | Destroy Khalkotauros, take the first blade |

## Retired

| Name | Was | Why |
|---|---|---|
| **Helos** | The village, first draft | A Titan Quest place name (see Not ours); now Elaion |

## Not ours

Names from the games UNTHREADED is inspired by. They must not appear in the game,
its data, code or docs, except on this page, in [DECISIONS.md](DECISIONS.md), in
the roadmap's history and in CLAUDE.md's rule. The list is not complete: when in doubt
about a name, look it up before using it, and add it here if it belongs.

- Titan Quest: `Helos`, `Telkine`, `Telkines`
- Grim Dawn: `Cairn`, `Devil's Crossing`, `Burrwitch`, `Ugdenbog`, `Malmouth`, `Arkovia`,
  `Rovia`, `Aetherial`, `Aetherials`, `Chthonians`, `Ch'thon`, `Dreeg`, `Solael`,
  `Bysmiel`, `Empyrion`, `Kymon`, `Korvaak`
- Diablo: `Tristram`, `Horadrim`, `Nephalem`, `Deckard`, `Tyrael`, `Lut Gholein`, `Kurast`,
  `Westmarch`, `Caldeum`, `Mephisto`, `Azmodan`, `Inarius`

The games' own titles may be named in docs, as references (that's where we come from);
never in the game. Real myth that these games made famous (Typhon, Hades, Baal, Belial, Lilith...) is not
banned, but think twice: use it only in its own myth's sense, never in theirs.
