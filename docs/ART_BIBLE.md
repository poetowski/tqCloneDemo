# UNTHREADED: art bible

One look, everywhere: **painted pottery come alive under an Aegean sun.** Every model,
icon, texture, sound and UI image is made by our own scripts in Blender
([ASSET_PIPELINE.md](ASSET_PIPELINE.md)). No third-party asset packs, ever.

## The idea in one paragraph

Low-poly, faceted forms with bold silhouettes, like figures painted on a vase. The
world is mid-value and warm (dry gold grass, silver olive leaves, whitewash,
terracotta) under a long late-afternoon sun. Two "magic" colours cut through it:
**ichor gold** means fate, life, the hero and loot; **Styx teal** means death, the
Unthreaded and corruption. If something glows, it is one of these two (plus fire, for
Hephaestus).

## Palette

The palette is data: [`data/palette.json`](../data/palette.json). Blender turns it into
`assets/textures/palette_albedo.png` and `palette_params.png`, and every model maps its
faces onto those swatches (one material per model). Add a colour by adding a swatch.
Never pick a colour that isn't in the palette.

| Family | Swatches (sRGB) |
|---|---|
| Stone | marble `#E8E1D3`, limestone `#CFC4AE`, whitewash `#EDE6D6`, rubble `#A89A82`, stone_dark `#6E665A`, basalt `#3E3A36` |
| Fired clay | terracotta `#B5562E`, clay `#C8643C`, black_glaze `#1A1412` |
| Cloth | linen `#EFE6D2`, wool_red `#9E2B25`, wool_ochre `#C99A3E`, wool_indigo `#3A3F6B` |
| Metal | bronze `#B07A3A`, bronze_dark `#7A5226`, gold `#E2B04A`, silver `#C9CDD2`, iron `#5C5E62`, verdigris `#4F9C8A` |
| Living | skin `#C98E66`, olive_leaf `#8A9A6A`, cypress `#2F4A2F`, grass_dry `#B8A65A`, grass_green `#7D8A4A`, poppy `#C8322A`, asphodel `#EDE6E0` |
| Dead | bone `#D8CFBA`, shade_body `#2E3A44`, shade_cloth `#262A30` |
| Glow | ichor_glow `#F2C14E`, styx_glow `#5FD3C6`, fire_glow `#FF8A2A`, furnace `#FFB347` |

## Value and colour rules

- **Environment** stays mid-value and warm. **Characters** carry the strongest
  contrast: the hero warm (red cloak, bronze, white linen), enemies cool (teal,
  blue-grey, black).
- **Gold** belongs to the player side: the hero's thread, skills, XP, Mythic loot, quest
  markers. **Teal** belongs to death: shade eyes and hearts, Styx cracks, enemy
  projectiles, spawn mist. Never swap them.
- **Red-orange** marks enemy telegraphs on the ground. **Fire** is reserved for
  Hephaestus' things: braziers, the bronze bull, forges.
- Saturation is highest at gameplay focus points (loot beams, glow, cloaks) and low
  elsewhere.

## Shapes and proportions

- Faceted low-poly, flat-shaded hard surfaces. Skin and cloth may be smooth-shaded.
  Polycount guide: hero ~3–5k triangles, enemies 1.5–4k, boss ~8k, props 50–1500.
- **Heroic exaggeration**: big helmets and crests, broad shoulders, slightly large
  hands, feet and weapons. Readability at 18 m from the camera comes first.
- Heights: hero 1.85 m (2 m with crest), shades 1.8 m and gaunt, Klotho 1.55 m and
  hunched, boar 0.95 m at the shoulder, **Khalkotauros 2.6 m at the shoulder, 4.8 m long**.
- Architecture: Doric order (fluted columns, plain capitals), 1.0 m column diameter,
  6 m column height. Houses: 2.6 m walls, 0.25 m thick, hipped terracotta roofs.

## Materials

- One palette material per model (`Palette`): albedo from the swatch, roughness,
  metalness and emission from `palette_params.png`. In Godot every model uses
  `assets/materials/palette.tres` (shader `src/shaders/palette.gdshader`). It supports
  per-instance hit `flash`, `tint` and occlusion `fade` (dither).
- Everything alive (trees, shrubs, grass, flowers) is painted with `Foliage` instead: the
  same palette with wind (`assets/materials/foliage.tres`). Stone and dead wood stay on
  `Palette`, so a dropped draught never sways.
- Ancient marble was **painted**. Temples carry faded polychrome: red and blue meander
  friezes, gold on the capitals. Use it sparingly and keep it weathered.
- Pottery uses the black-figure scheme: clay body, black glaze bands, a meander band.

## Lighting

- Golden hour: the sun from the west-south-west (over the sea) at about 30°,
  `#FFE0B0`, with long shadows eastward up the hill. Sky ambient is cool blue to
  balance it.
- Tonemap AgX, mild glow (bloom) on emissive only, SSAO on, light warm distance haze.
- Areas shift mood: **village** warm and clean; **terraces** dappled under olive
  shade; **necropolis** desaturated with teal ground mist and asphodel;
  **sanctuary** dusk-lit with a forge glow from below.

## Atmosphere

How the moods above are made (all in data: `data/atmosphere.json`):

- **Moods by area.** Each zone names a mood; `src/world/atmosphere.gd` blends haze colour
  and density, saturation, contrast, ambient light, the sun's colour and strength over
  3.5 s as the hero walks in. Shore and village warm and clean, terraces golden and
  dappled, the road dusty, the necropolis grey-teal and hazy, the sanctuary at dusk, the
  arena forge-lit.
- **Wind.** Leaves, grass and flowers sway (more the higher they reach, trunks stay
  planted); leaves flutter. Strength per mood: a sea breeze on the shore, still air in
  the necropolis.
- **Cloud shade.** Soft shadows drift with the wind over ground and models, cooler as
  well as darker. Heavier over the terraces (the dappling) and the necropolis.
- **Motes.** What floats around the hero: pollen (village, terraces), dust (shore,
  road), Styx wisps (necropolis, teal), embers (sanctuary, arena, fire). Glow only in
  gold, teal or fire.
- **Life.** Gulls wheel over the bay and crows over the graves; smoke rises from three
  village hearths and leans with the wind.

The weather reaches every shader through the project's shader globals (`wind_strength`,
`wind_direction`, `cloud_cover`; `src/shaders/weather.gdshaderinc`).

## VFX language

| Effect | Look |
|---|---|
| Hero skills | Gold ribbons and arcs, thin and bright, with a short trail |
| Thread snap (kill) | A gold line flicks upward from the body and breaks |
| Unthreaded spawn/death | A teal mist column; the body unravels into teal motes |
| Enemy telegraphs | Red-orange ground decals that fill toward the moment of impact |
| Hits | Bronze: white-gold sparks. Bone: pale chips. Flesh: dark red flecks |
| Fire | Orange core, gold edge, dark smoke. Only for Hephaestus' things |
| Loot beams | A vertical beam in the rarity colour (Blessed and up) |

## UI

- **Black-figure panels**: near-black glaze `#1A1412` at 92% opacity with a terracotta
  border and a gold meander (Greek key) band at the top.
- Text: bone white `#EFE6D2`. Headers: gold `#E2B04A`. Muted text: `#A89D86`.
- **Orbs**: health is wine red, ichor is gold, both liquid with a slow surface wave
  in bronze rims. The skill bar sits between them.
- Rarity colours: Mortal `#D8D2C4` · Blessed `#5AA6E8` · Heroic `#7CCF6A` ·
  Mythic `#F2C14E`.
- Icons are rendered in Blender from the actual item models (items) or from emblem
  compositions in the black-figure style (skills): terracotta disc, black figure, gold
  accent.

## Audio direction (made in Blender with `aud` and numpy)

Lyre plucks (Karplus-Strong) for UI, quests and level-ups; bronze clangs and dull
thuds for hits; bone rattles for shades; cicadas and surf in the village; wind and a low
drone in the necropolis; forge roar and metal groans for the bull. The music is a
Dorian lyre line over a drone, with frame drums in combat.

## Don'ts

- No textures from outside, no photo textures, no fonts from outside.
- No glow that isn't gold, teal or fire.
- No modern-Cycladic blue doors or domes: this is the Bronze/Archaic age.
- No realistic gore. Shades unravel and beasts collapse.
