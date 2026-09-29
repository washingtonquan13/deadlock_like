# The Burrows (city map prototype)

Greybox 5v5 lane map, built in code by `src/arena/city_map_builder.gd` (`ArenaBuilder.build(root, &"city")`).
It is the first entry of `MapRotation`, so it is the default; F9 cycles to the movement debug map
(`godot -- --map=full` picks one on the command line).

## Goals

- **Dota, not League.** The lanes are not mirrored copies of each other:
  - **Top lane is a subway.** Outside each base it drops 10 m below the street and runs underground under a roof.
    - Light wells and two open-cut stations break up the roof.
    - Five stairwells lead up into the jungle.
    - Fights are tight, and the ceiling kills vertical play.
  - **Bot lane is topside.** It is a street-level avenue between tower rows.
    - An elevated rail deck (7 m, ramps at both ends, newsstand steps to mantle up) runs along the map edge.
  - **Mid is a diagonal boulevard** that cuts the street grid. Flatiron-style buildings line it, and a bridge carries it over the canal.
- **The jungles are asymmetric too.** Each team gets:
  - a **main jungle** between mid and its safe lane (A: bot, B: top), with 5 camps;
  - a **triangle** on its offlane side, with 3 camps.
  Buildings come from a seeded lot generator, so the two halves read differently.
- **The river is a sunken canal** (bed at −3.5 m) along the other diagonal.
  - It drains into the subway at the north-west corner and rises to the street at the south-east corner.
  - Boat ramps and three footbridges cross it, and there are two powerup pads in the bed.
- **The boss lair** is an underground chamber (−10 m) off the canal's upper reach, on team A's side.
  - It has a skylight.
  - An entrance ramp runs from the canal bed.
  - A sewer connects it west to the subway.
- **Sewers** give each main jungle a hidden underground route: A's to the canal, B's to the subway.
- **Movement answers distance.** The map is a 720 m square with the same lane lengths as before.
  - Every lane has a zipline on each side, including the subway.
  - Each jungle has a rooftop zipline between two towers, reached by ropes.
  - 3.5 m podiums, docks and lowrises give mantle routes onto the city.
  - Arcades can be walked under or mantled onto.

## Layout (team A = south-west, cyan; team B = north-east, orange)

- Bases are point-symmetric. Each has a 7 m plateau with three 16° ramps, and contains:
  - Patron;
  - 2 Shrines;
  - Base Guardians;
  - a shop;
  - a spawn;
  - team A's practice range.
- Each lane has a Walker and a Guardian per team.
  - A side shop sits beside each Guardian, tucked against the wall in the subway.
  - Underground structures are clipped to fit under the roof.
- Nothing is functional yet: no troopers, and camps are target dummies.

## Minimap

- Draws the terrain image: street grid, lanes, canal, park plazas, and darkened underground floors.
- Draws building footprints, shaded darker the taller they are.
  - Roofs over tunnels are translucent (meta `minimap = &"roof"`), so the subway shows through.
  - Pieces tagged `&"skip"` and anything below −2 m are left out.
- Static layers redraw only on resize.

## Tunables

Constants at the top of `city_map_builder.gd`:
- avenue and street grid;
- lane and channel widths and depths;
- subway wells and stations;
- stair and canal ramp positions;
- camps and towers;
- elevated deck.

The lot generator uses `rng.seed = 90210`.
