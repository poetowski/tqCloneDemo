# Elaion: the slice's zone

Elaion (Greek *elaiōn*, "olive grove") is a fishing and olive village above the
wine-dark sea, under a hill crowned by the forgotten Sanctuary of the Moirai. The
whole design lives in [`tools/blender/level/elaion.py`](../tools/blender/level/elaion.py)
(zones, paths, placements); this page explains it. The map: `.shots/elaion_map.png`
(written by `npm run models -- elaion`).

Coordinates are Godot's: x east, z south (north is -z), y up. The terrain spans
x -135..110, z -135..100; the sea fills the west.

## Flow

```
            Sanctuary of the Moirai (20 m)          arena + Khalkotauros (4, -107)
                     ▲ gate (11, -76)  ── court (6, -88), the three Moirai, temple ruin
                     │ processional way
   stairs foot (16, -64) ◄── Necropolis (30, -42), 13 m ──► tholos (55, -56): Captain Lykos
                                   ▲
                       Cypress Road (53, 6 → 52, -17), 11–12 m
                                   ▲
   beach (start, -66, 55) ──► Elaion village (-42, 38) ──► Olive Terraces (12, 42), 2.6–9.3 m
          Hearth of Hestia      Klotho's loom (-49, 17)        terrace top (42, 26), 9.6 m
                                Dion by the well
```

## Areas

| Area | What happens | Encounters |
|---|---|---|
| **The beach** | The hero wakes; first Hearth of Hestia; the beached boat with its painted eye. | — |
| **Elaion** | Whitewashed houses, the well, Dion (two draughts), Klotho at her loom (quest). Pots to smash. | none (safe) |
| **The Olive Terraces** | Five terraces climbing east, dry-stone retaining walls, olive rows, a ruined farmhouse, a chest. Quest: sever 10 Unthreaded. | 4 shade packs, 2 boar packs, levels 1–3 |
| **The Cypress Road** | A climb north between cypress rows. | archers on the road, level 3 |
| **Necropolis of the Forgotten Siege** | Stelae, sarcophagi, asphodel, Styx cracks glowing in the ground, second Hearth of Hestia, a chest; the tholos tomb. | 4 packs, levels 3–4; **Captain Lykos** + escort at the tholos (level 5) |
| **Sanctuary of the Moirai** | The sealed gate (opens with the seal), a processional way of columns, the court with the three Fates (Atropos' hands empty), a painted temple ruin and the third Hearth of Hestia (0, -86), the checkpoint before the bull. | — |
| **The arena** | A paved circle ringed by columns at 13.5 m around (4, -107) (bait the bull into them), braziers, the forge pit. The bull keeps inside 15 m of its middle. | **Khalkotauros**, level 7 |

## Rules the layout follows

- Walkable land is the union of zone discs and path corridors; outside it the land
  rises into hills and cliffs (or slopes into the sea in the west). Paths ramp from
  zone edge to zone edge; inside the terraces a path is a smooth ramp cut through the
  steps.
- Terrace risers are steep (unwalkable); dry-stone walls retain them, with gaps where
  paths cross.
- Nothing blocking stands on a path (`on_path` checks); trees keep 2+ m apart.
- Enemy level rises with the climb: 1–2 by the village, 5 at the captain, 7 for the boss.

## Changing it

Edit the data in `elaion.py` (ZONES, PATHS, `plan()`), then `npm run models -- elaion`
and `npm run level`, look at `.shots/elaion_map.png`, then `npm run shot` with a camera
on the changed spot, then `npm run tour`.
