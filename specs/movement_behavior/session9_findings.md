# Session 9: G09 at faster hops, wall-jump key timing, backpedal

- Setup: Haze, Sandbox map, recorded by the driver with no one at the keyboard.
- Recordings: `tools/movement_capture/rec_auto/s9_open/`.
- Scenarios and fit scripts: `tools/movement_capture/scenarios/s9_open/` (`gen.py`, `g09fit.py`, `wkfit.py`).

## G09 chained slide-hop penalty: a pull toward ~215 u/s, not a drag box

- **New data:** SHL6 and SHL12, which are slide hops at ~470 u/s. They are a dash, a dash jump and a crouch-landing
  slide, then a hop 6 or 12 ticks after landing. They were recorded on a new 1500 u runway, mark `street_y058b`.
- **Joint fit** over SHH6/12/20/30 (session 7, ~370 u/s) and SHL6/12:
  - Flight windows only.
  - h0 is the ground HUD reading.
  - vz0 comes from a z fit with G pinned at 796.
- **Model:** during the penalty, each tick h drops by min(excess, excess·5.25·dt), where excess = h − 215 u/s.
  - The penalty lasts until landing.
  - Joint rms by model:

    | Model | Joint rms |
    |---|---|
    | This model | 8.1 |
    | Best drag box | 12.5 |
    | Old sim | 14.7 |

  - Apex h, sim vs game:

    | Hop | Sim | Game |
    |---|---|---|
    | SHH6 | 228 | 229.5 |
    | SHH12 | 227 | 225.5 |
    | SHL6 | 239 | ~245 |
    | SHL12 | 238 | ~243 |

- A drag box can't fit both speeds. At 470 u/s the loss is much larger in u/s than a fixed drag gives, yet the apex
  lands near the same ~240.
- **Unchanged:** there is still no penalty at a 40-tick delay (SHH40), and no speed limit was added.

## Wall jump: the kick reads the previous tick's keys

- **Scenarios WK_N, WK_A, WK_D, WK_WA and WK_SA** (3 trials each, mark `wallAd`: yaw 0, pitch 45):
  1. Hold W into the wall, with a ground jump at tick 60.
  2. Hold no keys on ticks 84–87.
  3. Press the key and the jump on tick 88 only.
- **Result (post-jump horizontal velocity from position):**
  - The kick off the wall is −245 ± 15 u/s in every case: none, A, D, W+A and S+A.
  - Along the wall:

    | Keys | Speed along the wall |
    |---|---|
    | A | +24 |
    | D | −23 |
    | W+A | +17 |
    | S+A | 0 |

  - That is exactly the ordinary air accel of the ticks the key is down. The driver's minimum press is 25 ms, which is
    2 ticks at ~12 u/s each.
  - S+A gets none because its wish already points along the kick, so v·wish is above the 80 u/s cap.
- **Rule:** the kick uses the previous tick's wish, like the air jump (session 5). The session-3 held-key fits are
  unaffected: W 215, S 361, neutral 268, tangent 107.
- **Open:**
  - The neutral kick here (~245) is below session 3's 268. The approach differs: here the pawn ran into the wall and
    released W 4 ticks before the press; session 3 started from a hover. This may be incoming-speed dependence and is
    not fit yet.
  - The session-7 question of how big a held diagonal's kick is (~0.88 of a single key in the game, 0.707 in the sim)
    needs a held-diagonal recording. This data can't answer it.
- **Capture notes:**
  - cl_showpos shows the camera position.
  - At a wall seen at an angle (the `wallA25d` mark), the third-person camera is pushed by the wall. Its x stayed
    clamped after the jump, so that data was discarded.
  - Face the wall straight on.

## Backpedal

- **FSS** (S only from rest, mark `street_y328d`) plateaus at 386 u/s. Its ramp from rest matches W, A and D within
  start-timing noise: 0.2 s ≈ 190–207 and 0.5 s ≈ 334–343.
- `backpedal_mult` = 1.0 (measured). Together with session 7's strafe result, no direction multiplier exists on the
  ground.

## Capture tooling

- **HUD reader** (`mc_grid.py`): a line ends at its last two decimals (or its closing paren). Stray glyphs from a
  bright background after the value no longer void the frame.
- **Camera pitch 45:** it keeps the HUD over the pavement instead of white walls and windows, and it doesn't affect
  movement.
- **`DL_BLIND_TURN=1`** (driver):
  - The HUD read needs only pos.
  - The view is kept when the angle line is unreadable.
  - It waits out an unreadable end position.

## Still open

- The smooth-ramp recording for the low-speed ramp slide accel (S8-SL: game ~460 u/s² vs sim ~300).
- The wall-jump neutral kick vs incoming speed.
- A held-diagonal wall kick.
