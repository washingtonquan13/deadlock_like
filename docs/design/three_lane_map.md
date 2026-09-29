# Three-lane map (prototype)

Greybox 5v5 lane map, built in code by `src/arena/lane_map_builder.gd` (`ArenaBuilder.build(root, &"three_lane")`).
It is the first entry of `MapRotation`, so it is the default; F9 cycles to the movement debug map.
You can also pick a map on the command line, e.g. `godot -- --map=full`.

## Goals

- **Dota-scale macro.** Deadlock's map is small enough that everything is a short walk away, so teams deathball.
  This map is a 720 m square, so lanes are far apart and splitting up pays off.
  - Side lanes run along the map edges, about 1030 m from ramp to ramp.
  - Mid runs the diagonal, about 600 m.
  - Crossing the map from one side lane to the other takes about a minute on foot.
  - The travel-time budget is carried by the movement kit rather than by a smaller map.
- **Movement as the answer to distance.**
  - Every lane has two ziplines, one on each side. Side lanes use the outer (21 m/s) speed and mid uses the inner (18 m/s) speed.
    A side lane takes about 50 s end to end on a zipline.
  - Each jungle has a cross-country zipline between two watchtowers, reached by ropes.
  - The base cliffs have mantle shelves and ropes.
  - Scattered cover comes in crouch, mantle (≤ 4 m) and rooftop heights.
  - There are also ridges along the lanes, a wall-jump alley, and a tunnel.
- **A jungle worth playing in.** Each team has two jungle quadrants, each containing:
  - 5 camps (small/medium/large target dummies);
  - hills;
  - a secret shop per side.
- **River and objectives in the middle.**
  - A meandering river runs along the anti-diagonal.
  - Bridges carry the three lanes across it.
  - The mid-boss sits in a 10 m pit under the mid bridge, reached by ramps from the river.
  - The side bridges carry powerup pads.

## Layout (team A = south-west, cyan; team B = north-east, orange)

- The map is point-symmetric: team B's half is team A's half rotated 180°.
- Team A's south jungle is its west jungle reflected across the mid diagonal. All authored content lives in the west-jungle frame.
- Each team has:
  - a 7 m base plateau with three 16° ramps;
  - Patron and 2 Shrines;
  - 2 Base Guardians per lane at the ramp top;
  - a Walker and a Guardian out in each lane;
  - a side shop beside each Guardian;
  - a base shop;
  - a practice range of dummies next to team A's spawn.
- Structure positions are rough placeholders. Nothing is functional yet: no troopers, no structure behaviour, and camps are only target dummies.

## Minimap

- Bottom right; M toggles a large view.
- Draws the map's baked terrain image (lanes, river, pit, hill shading) and every box collider's footprint.
- Also draws zipline routes, icons and the player with a camera view cone.
- Any layout works: the debug arena just gets a default rect.

## Tunables

These are constants at the top of `lane_map_builder.gd`:
- map half size;
- plateau height;
- ramp angle and width;
- lane half width;
- river and pit sizes;
- rail height and offset;
- hills, camps, blocks, ropes and the jungle zipline.

Scatter cover is seeded (`rng.seed`) so the map is identical on every build.
