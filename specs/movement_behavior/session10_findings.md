# Session 10: low-speed ramp slide, held-key wall kicks, fast air strafe

- Setup: Haze, Sandbox map, recorded by the driver with no one at the keyboard (3 trials each).
- Recordings: `tools/movement_capture/rec_auto/s10_gains/`.
- Scenarios and fit scripts: `tools/movement_capture/scenarios/s10_gains/` (`gen.py`, `rampfit.py`, `rampjoint.py`,
  `wkfit2.py`, `wall_sim.py`, `fa_sim.py`).

## Low-speed ramp slide accel (S10-SL, closes the S8-SL open item)

- **Scenarios RL5, RL8 and RL12** (mark `ramp1_slope`, the smooth 26.5° ramp): W for 5, 8 or 12 ticks, then crouch
  held for 200 ticks. The slide starts at ~150 u/s.
- **Result:** the HUD accel falls linearly from ~600 u/s² at 150 u/s to ~400 at 450: a ≈ 696 − 0.66·v. Plain
  g·tan(θ) − friction gives ~300 at low speed.
- **Model:** below `slide_slope_boost_speed` (500 u/s) a downhill slide on a slide slope gets an extra accel of
  `slide_slope_boost_rate` (1.733/s) · tan(θ) · (500 u/s − v). Above 500 the session-8 fit stands.
- **Replay peaks:** RL sim 482/481/484 vs game 471–482.
- **Side effect:** RBOT is now 474 vs game 457 (was 460), and RRUN 547 vs 514 (was 532). The on-ramp bins match; the
  excess is in the entry. Not fixed.
- PROVISIONAL: one angle. The tan(θ) scaling is assumed; the ~30° city ramps are too noisy to check it.

## Wall jump: approach independence and the W-held kick

- **Approach (WN_E, WN_F; mark `wallAd`):** the neutral kick is ~262 whether the pawn reaches the wall at 365 u/s into
  it or at rest (WN_F waits 20 ticks against the wall). There is no dependence on the incoming normal speed. The
  session-9 "245 vs 268" open item is resolved: 268 stands, and 245 was from the key-on-press-tick timing.
  WN_R was invalid (an air jump before contact).
- **Held keys (WH_W/WA/SA/S/A):** the keys are held from tick 84 through the press at 88. The comparison is between
  game and sim replay windows after the press (`wall_sim.py`), with kick and along in u/s:

  | Case | Game | Sim, toward 215 | Sim, toward 256 |
  |---|---|---|---|
  | WH_W | 179 | 133 | 173 |
  | WH_WA | 191/160 | 171/160 | 199/160 |
  | WH_SA | 334/131 | 327/106 | 327/106 |
  | WH_S | 349 | 354 | 354 |
  | WH_A | 267/148 | 263/149 | 263/149 |

- **Change:** `wall_jump_kick_toward` 215 → 256 u/s (6.5 m/s). This splits WH_W and WH_WA. The session-3 value was a
  fit artifact: the game data agree across sessions.
- **Open:** S+A along is 25 u/s higher in the game. A diagonal away from the wall may get a larger tangent kick. W+A's
  kick is ~8 high at 256, so the diagonal rule is not exactly linear in d.

## Air strafe above 450 u/s (G26 / K26)

- **Scenarios FA_A, FA_D, FA_N** (mark `street_y058b`): a dash, a dash jump, a crouch-landing slide and a slide hop at
  ~560 u/s, then A, D or no key for ticks 106–160. **FA_L:** a W jump at ~350 u/s, then A.
- **Result (`fa_sim.py`, 0.08 s windows):**
  - The sideways speed rises from 0 to ~78 u/s in ~0.12 s at both speeds.
  - It plateaus at 80 u/s at both speeds.
  - The sim (accel mult 1.0, cap 80) matches both. The game onset reads ~4 ticks later than the sim at both speeds, so
    it is recording alignment, not physics.
- **Conclusion:** `air_accel_high_speed_mult` 1.0 and `air_wishspeed_cap` 80 are measured up to ~560 u/s. The 450 u/s
  split has no measured effect. The 700 u/s fast cap is still unmeasured.
- **Side notes:**
  - Forward speed through the hop flight is within ~10–20 u/s of the sim.
  - After landing, the game keeps more speed than the sim at ~350 u/s (FA_L 1.40 s: 290 vs 235). The landings are
    not fit.
  - FA_D's landing stops much faster, probably something on the street edge.

## Capture tooling

- `gameio.focus_game` minimizes the ESET popup (egui.exe) and any Godot window covering the game before a recording.
  It never closes or answers the popup.

## Still open

- Diagonal wall kicks (the S+A tangent, and W+A's kick).
- The RBOT/RRUN ramp-entry excess after S10-SL.
- The landing speed loss after a ~350 u/s jump.
- The air strafe above 700 u/s.
