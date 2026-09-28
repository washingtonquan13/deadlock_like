# Session 3 findings: slides, walls, wall jumps (Haze, sandbox)

Clean-room measurements: private sandbox, `cl_showpos` HUD OCR via `tools/movement_capture/driver`.
Units: u and u/s (1 u = 0.0254 m). Fits use fixed gravity 800 u/s² and air drag 0.2/s.

## Slides (applied to params and model)

- Dash slide: peaks near 643 u/s, then decays with friction about 0.694/s. The penalty onset is about 0.96 s.
- Steering: a held move key turns the slide velocity toward the wish at about 92°/s without losing speed. The mouse alone does not steer.
- Landing slide: friction 0.189 is kept.

## Wall collision (sim already matches; no change)

- **Walking into a wall:** plain velocity clip. The hero then slides along the wall at the tangential remainder, rebuilt by ground accel. That is ~168 u/s at 25° and ~282 u/s at 45°.
- **In the air:** head-on, horizontal velocity goes to 0. Gravity stays normal (~794 u/s²), with no stick or slow fall. At an angle, the tangential speed is kept.
- **Dash into a wall:**
  - Head-on: full stop, no bounce.
  - At 25°: plain clip, 635 → 268 (635·sin 25° = 268). Normal friction follows.
- **Slide into a wall:**
  - Head-on: full stop, then it turns into a crouch.
  - At 25°: plain clip, ~500 → 207 (211 predicted). It decays and ends into a crouch near 175–187.

Scenarios: WW/WWA/WWD, DW, SW, ADW, ASW, BWW. Marks: wallA, wallA25, wallA45 (`driver/marks.json`).
The generator is `scenarios/wall/gen.py`.

## Wall jump (first jump, fresh)

d = wish · wall normal (away from the wall is +).

| Held | Normal kick | Tangent |
|---|---|---|
| none | 265–268 | 0 |
| W (d = −1) | ~215 | 0 |
| S (d = +1) | 350–361 | 0 |
| A or D | ~265 | ~147 in the key direction |
| S+A | ~338 | 128–135 |
| W+A | 210–220 | ~150 |

- **After the kick:** W also gives about 720–760 u/s² of air pull back toward the wall (normal air accel). W+A gives about 350 u/s² tangentially early on.
- **Incoming tangent speed:** kept at ×0.9–1.0 (165 → 147 at 25°; ~250 → 245 at 45°). The key's tangential kick is added on top. BWJS measured −137 to −150 against −146 predicted.
- **Vertical depends on vz just before the press** (not a flat set):

  | vz before | vz after |
  |---|---|
  | +215 | 542 |
  | −15 | 515 |
  | ~−123 | ~485 |
  | −221 | 453 |

  The slope is ~0.30 while falling and ~0.12 while rising, around ~519 at vz = 0.

Scenarios: WJX/WJ0/WJW/WJS/WJA/WJD, WJWA/WJSA/WJ0L/WJ0E, AWJ0/AWJX/AWW, BWJ0/BWJS.
The fit helpers are `analyze.py`, `fitwj.py`, `prepress.py` and `fitacc.py`.

### Model (applied; the vertical rule, kicks, tangent kick and tangent keep are now in params)

- **Normal:** 268 + 93·d for d > 0, and 268 + 53·d for d < 0 (continuous, no thresholds).
- **Tangent:** incoming × keep (~0.95), plus 147 × the wish's tangential component.
  - Diagonals measure ~130 against ~104 predicted, so the tangential part may not scale with the plain component.
- **Vertical:** ~519 + k·vz_before, with k ≈ 0.30 when falling and ≈ 0.12 when rising.

### Air accel (not applied)

- With W held, the pull back toward the wall after a wall jump is ~740 u/s².
- The sim's provisional `air_accel` 10 gives ~3860 u/s² there (10 × walk speed).
- A Source-style fit suggests `air_accel` ≈ 1.9. Check this against plain air-strafe recordings before changing it.

## Open

- More rising-contact samples for the vertical rule.
- Second and later wall jumps (fatigue, stamina).
- Landing-slide onset, dash-jump slide, S steering.
