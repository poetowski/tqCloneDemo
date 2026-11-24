# Asset pipeline: Blender scripts → Godot

Every asset is the output of a script. The script is the source; the `.glb`, `.png`,
`.wav` and `.ogg` files are build products (committed so the game runs without Blender).

```
data/palette.json ──► textures/palette.py ──► assets/textures/palette_{albedo,params}.png
                                                         │ (sampled by every model)
tools/blender/lib/kit.py  (Mesh builder, palette UVs, rigs, export)
   ├─ characters/*.py  (humanoid.py / quadruped.py rigs + actions) ─► assets/models/characters/<slug>/<slug>.glb
   ├─ props/*.py                                                    ─► assets/models/props/<slug>/<slug>.glb
   ├─ items/*.py                                                    ─► assets/models/items/<slug>/<slug>.glb
   ├─ level/elaion.py  (terrain + sea + layout + the map)          ─► assets/models/level/elaion_terrain + data/level/elaion_layout.json
   │                                                                   + assets/ui/minimap/elaion.png
   ├─ render/icons.py  (portraits of the item models, skill emblems, logo) ─► assets/icons/, assets/ui/
   └─ audio/sounds.py  (numpy DSP + aud)                            ─► assets/audio/*.wav|*.ogg
                         │
Godot import ── tools/import/post_import.gd swaps materials by name:
   "Palette" → assets/materials/palette.tres (src/shaders/palette.gdshader)
   "Foliage" → foliage.tres (the palette shader with wind: everything alive)
   "Terrain" → terrain.tres (vertex colours)     "Water" → water.tres
   (After changing post_import.gd: `npm run import -- --force`; it also clears Godot's
   stored checksums, without which unchanged models would not import again.)
tools/build_level.gd ── data/level/elaion_layout.json ─► src/world/elaion/elaion.tscn (+ baked navmesh)
```

## Making a model

1. Pick the folder: `characters/`, `props/`, `items/`. One script may build several
   assets (`props/village.py` builds houses, a well, the loom...).
2. Start every asset with `kit.clear_scene()`, build with `kit.Mesh`, `finish()`,
   then `kit.export_glb(kit.model_path(category, slug))` and `kit.report(...)`.
3. Colours are palette swatch names. `Mesh` parts: `box` (optional `bevel`),
   `cylinder` (`ring_step` adds rings so it can bend), `cone`, `sphere`, `ico`,
   `lathe` (profile of (radius, height); `pattern(band, segment)` paints bands),
   `loft` (rings of points), `extrude` (2D outline), `polygon`, `torus`, `tube`,
   `rock`, `leaf`. Place parts with `with m.at(location, rotation, scale):`.
4. Colliders: `kit.collision_box/collision_cylinder(name, ...)` make
   `<name>-convcolonly` objects that Godot turns into static colliders.
5. Build and look: `npm run models -- <script>` then `npm run render -- <slug>`.

Conventions: metres, Z up, bottom centre at the origin, front toward -Y (Godot +Z).
Items: weapons with the grip at the origin and the blade up +Z (flat facing ±Y);
shields centred, facing -Y; helmets with the origin at the head bone's base.
Where items sit on a skeleton is data: `data/attachments.json` (used by the Blender
preview and by `ActorBody.attach` in Godot).

## Characters and animation

- Humanoids share one skeleton (`lib/humanoid.py`, SkeletonProfileHumanoid bone
  names) and one action library (idle, combat_idle, walk, run, attack_thrust,
  attack_slash, bash, lash, war_cry, lunge, cast, hit, die, rise, stunned, shoot, talk,
  weave). A `style` (hero, shade, archer, villager, weaver) changes the stance.
- Poses are `{bone: (pitch, twist, spread)}` in degrees plus `loc:Hips` / `loc:Root`
  offsets; right-side bones mirror automatically. See the module docstring for the sign
  conventions (a knee bends with a negative lower-leg pitch, an elbow with a positive one).
- Quadrupeds (`lib/quadruped.py`): boar and bronze bull, gaits, gore, charge, breath,
  stomp, bellow, die.
- Equipment variants are extra skinned meshes in the same .glb (`Cuirass_Linen`,
  `Greaves_Bronze`...); `ActorBody.set_variant` shows or hides them.
- One-shot actions have an impact fraction (`ActorBody.IMPACT`, mirrored from
  `humanoid.IMPACT`) where the blow lands.
- Check animations visually: `npm run render -- hero --anim=attack_thrust --frames=0,5,8,12 --attach=dory:weapon,aspis_hero:shield`.

## The level

`level/elaion.py` holds the design as data: zones (plateaus with a height and a
kind), paths (ramps between zone edges), terraces, coast. It writes the terrain (flat
faces, palette colours as linear float vertex colours; alpha < 1 glows), the sea, a
top-down map (`.shots/elaion_map.png`) and the layout JSON: props, spawners, NPCs,
hearths, chests, pots, the gate, zones (each with its mood), birds, hearth smoke, the
boss mark, the ground cover scatter (grass, flowers, thyme, broom, reeds, pebbles,
acanthus) and the test route. Last it renders the **minimap**: every prop model
imported once and stamped at its placements on the terrain, lit by the low western
sun, the ground you can't walk on darkened so paths and places read, photographed
straight down onto exactly the level's bounds (`assets/ui/minimap/elaion.png`; Godot
gets the bounds from the layout). `npm run level` turns that into the Godot scene and bakes navigation (runtime
objects get proxy colliders during the bake so paths go around them). The bake marks
everything below the waterline unwalkable (the seabed slopes on to -4 m), drops
isolated islands under 16 m², then keeps only the polygons connected to the start
(the surrounding hills bake as walkable slopes cut off by steep banks; an actor
knocked or snapped onto them would be stranded). `npm run tour -- --scenario=paths`
checks the result: every route link walks, no polygon is cut off, none is under the sea.

## Icons, logo, audio

- `render/icons.py` photographs each item model (64 px per inventory cell), draws the
  skill emblems as black-figure medallions, and builds the UNTHREADED logo from
  straight-stroke archaic capitals (no font files).
- `audio/sounds.py`: effects are additive/filtered synthesis (bronze partials, plucked
  lyre strings, filtered noise); music is lyre, aulos and frame drum over drones in
  Dorian (the living) and Phrygian (the dead, the bull). Loops are written as Ogg
  Vorbis by Blender's `aud`; `Sfx` loads `<name>.wav` or `<name>.ogg`.

## MCP

The Blender MCP add-on (`blender_mcp.py`, port 9876) and the Godot MCP plugin are for
live inspection and experiments. Results that matter go back into scripts; never
hand-edit a .glb or keep a .blend as a source.
