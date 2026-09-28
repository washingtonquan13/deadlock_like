# Session 10: low-speed ramp slide, held-key wall kicks, fast air strafe

- Setup: Haze, Sandbox map, recorded by the driver with no one at the keyboard (3 trials each).
- Recordings: `tools/movement_capture/rec_auto/s10_gains/`.
- Scenarios and fit scripts: `tools/movement_capture/scenarios/s10_gains/` (`gen.py`, `rampfit.py`, `rampjoint.py`,
  `wkfit2.py`, `wall_sim.py`, `fa_sim.py`).

## Recording lag: align game windows by a kink, not by the scripted tick

- The game's recorded time lags the scripted input by ~2.7 ticks. The launch kink in z of a wall jump sits at game
  tick 91.2 (t·64 + 1) for a press scripted at 88. FA_L's ground jump agrees.
- In an approach from rest the sim is also ~2 ticks (~11 u) ahead. The matched wall replay is
  `wall_sim.py --lag=2.7 --face=411`.
- Any fit that compares game and sim in windows after a scripted tick must shift the game windows by this lag. The
  session-10 256 u/s wall kick (below) was an artifact of skipping it.
- The HUD `vel_scalar2` column is a max-speed readout, not live speed.

## Low-speed ramp slide accel (S10-SL, closes the S8-SL open item)

- **Scenarios RL5, RL8 and RL12** (mark `ramp1_slope`, the smooth 26.5° ramp): W for 5, 8 or 12 ticks, then crouch
  held for 200 ticks. The slide starts at ~150 u/s.
- **Result:** the HUD accel falls linearly from ~600 u/s² at 150 u/s to ~400 at 450: a ≈ 696 − 0.66·v. Plain
  g·tan(θ) − friction gives ~300 at low speed.
- **Model:** below `slide_slope_boost_speed` (500 u/s) a downhill slide on a slide slope gets an extra accel of
  `slide_slope_boost_rate` (1.733/s) · tan(θ) · (500 u/s − v). Above 500 the session-8 fit stands.
- **Replay peaks:** RL sim 482/481/484 vs game 471–482.
- **Side effect:** RBOT is now 474 vs game 457 (was 460), and RRUN 547 vs 514 (was 532). The on-ramp bins match; the
  excess is in the entry (see the ramp-entry section).
- PROVISIONAL: one angle. The tan(θ) scaling is assumed; the ~30° city ramps are too noisy to check it.

## Wall jump: approach independence, the W-held kick, diagonals (S10-WJ, S10-WD)

- **Approach (WN_E, WN_F; mark `wallAd`):** the neutral kick is ~262 whether the pawn reaches the wall at 365 u/s into
  it or at rest (WN_F waits 20 ticks against the wall). There is no dependence on the incoming normal speed. The
  session-9 "245 vs 268" open item is resolved: 268 stands, and 245 was from the key-on-press-tick timing.
  WN_R was invalid (an air jump before contact).
- **Held keys (WH_W/WA/SA/S/A):** the keys are held from tick 84 through the press at 88. Game vs sim replay, lag- and
  contact-aligned (`wall_sim.py --lag=2.7 --face=411`), kick off the wall in u/s at 0.05/0.10/0.15/0.20/0.30 s:

  | Case | Game | Sim, toward 232 | Sim, toward 215 |
  |---|---|---|---|
  | WH_W | 150/106/68/24/−54 | 150/113/76/39/−45 | 133/96/59/23/−61 |

  Diagonals, early kick/along:

  | Case | Game | Sim (224, full tangent) |
  |---|---|---|
  | WH_WA | 169/183 | ~177/191 |
  | WH_SA | 339/133 | 327/136 |

- **Change (S10-WJ):** `wall_jump_kick_toward` 215 → 224 u/s (5.7 m/s). WH_W wants ~232 early, WH_WA ~215.
- **Change (S10-WD):** a held diagonal gets the full single-key tangent kick (~107), not 0.707 of it. Its off-wall kick
  still follows the normalized d. The tangent uses the unnormalized key vector clamped per world axis, like the air
  jump (session 6). This closes the session-7/9 held-diagonal question and the S+A along gap.
- PROVISIONAL (S10-WD): one yaw, facing the wall straight on, so view-space raw keys and the world-clamped vector are
  not separated.

## Air strafe above 450 u/s (G26 / K26)

- **Scenarios FA_A, FA_D, FA_N** (mark `street_y058b`): a dash, a dash jump, a crouch-landing slide and a slide hop at
  ~560 u/s, then A, D or no key for ticks 106–160. **FA_L:** a W jump at ~350 u/s, then A.
- **Result (`fa_sim.py`, 0.08 s windows):**
  - The sideways speed rises from 0 to ~78 u/s in ~0.12 s at both speeds.
  - It plateaus at 80 u/s at both speeds.
  - The sim (accel mult 1.0, cap 80) matches both. The game onset reads ~3–4 ticks later than the sim, which is the
    recording lag.
- **Conclusion:** `air_accel_high_speed_mult` 1.0 and `air_wishspeed_cap` 80 are measured up to ~560 u/s. The 450 u/s
  split has no measured effect. The 700 u/s fast cap is still unmeasured.
- **Side notes:**
  - Forward speed through the hop flight is within ~10–20 u/s of the sim.
  - FA_L's apparent landing loss (1.40 s: game 290 vs sim 235) is the time offset: shifted by the lag, the sim
    matches the whole run. No model change.
  - FA_D's landing stops much faster, probably something on the street edge.

## Ramp entry (RBOT/RRUN/RJ)

- s7 replay tag `s10` (`scenarios/s7_fit_ramp/run.sh s10`, `compare.py s10`): peaks RBOT 474 vs game 457, RRUN 547 vs
  514, RJ 480 vs 558, RDASH 718 vs 716.
- **RJ is not a gap.** In the air the game HUD reads 3D speed: it falls while the pawn rises and climbs while it falls,
  and at the apex (vz = 0) it equals the position-derived horizontal speed (~374). Its 558 peak is the fall, compared
  against the sim's horizontal speed. The air decay from the jump to the apex (~404 → ~374 horizontal in 0.35 s) is
  the 0.2/s air drag. RJ inherits RRUN's entry deficit (below) and nothing else.
- **RBOT: replay geometry, not the slide model.** The slide accel matches (game 445 vs sim 447 at 1.15 s). The game's
  speed stops rising at d ≈ 372–381 (455–457), while the replay ramp runs on to d 406. The camera-z slope also fades
  from d ~380. The foot of the stair-ramp looks rounded or shorter than the straight replay plane, and that is worth
  ~17 u/s at the peak.
- **RRUN: an edge transient in the slide, open.** Crouch is pressed at 348 u/s at the top edge. The game slides and
  gains to ~390 by 0.65 s (game time) like the sim. It then loses speed at a steady ~−225 u/s² for ~0.15 s (to 356),
  then gains again at the normal slope rate. The shape is the same in all 5 trials and in RJ. Running over the same
  edge (RWALK, RBOT) shows nothing, and a slide started on the slope (RBOT) has no dip. The sim has no dip, so it runs
  ~70–90 u/s ahead until the bottom and peaks 33 high. Not modelled: the cause is unknown (possibly the edge or a lip
  in the stair-ramp collision), and the edge is one geometry.

## Air strafe above 700 u/s after a 90 deg air dash (FF_*; G26 still open)

- **Scenarios FF_N, FF_SA, FF_WD, FF_SAE** (mark `street_y058b`, `DL_SETTLE=10` so both dashes have stamina):
  1. Dash 4, dash jump 26, A held 38..42 with an air dash at 40 (90 deg left of the view).
  2. Then no keys (N), S+A or W+D from 76 (after the dash), or S+A from 44 through the dash (SAE).
- **Analysis:** `ff_sim.py` gives the pos-derived velocity, lag-shifted, and each keyed run's velocity minus FF_N's
  (the "strafe index").
- **The dash itself matches.**
  - The windowed speeds read ~975 u/s in the game vs ~850 in the sim during the dash, but that is the camera catching
    up (it lags in dashes).
  - Displacement from 0.55 to 1.15 s: game (377 fwd, 245 left) vs sim (371, 263). That is 450 vs 453 u.
  - The heading after the dash is 37 deg left of the view in the game and ~40 deg in the sim.
- **After the dash the game keeps ~50 u/s more.**
  - 1.15 to 1.40 s: game ~690 u/s vs sim ~640, in the same direction.
  - The landing time matches (~1.5 s).
  - The end drag for a sideways dash looks smaller than the session-6 fit (sim: 815 to 672). Not modelled: one
    geometry, and the dash-end speed is not separable from the drag with this camera.
- **No strafe accel during the air dash.** FF_SAE's index stays at noise (7 to 20) until the dash ends, like the sim.
- **Strafe index, after the dash:**

  | Run | Game plateau | Sim, cap 80 | Sim, cap 50 throughout |
  |---|---|---|---|
  | FF_SA, FF_SAE | 128 to 130 | 127 | 98 |

  - FF_SAE rises 42, 65, 97 at 845, 745 and 714 u/s. The rate is normal above 700, so there is no high-speed accel
    factor up to ~850.
- **The cap is not settled.** The game's flight drops through 700 u/s at ~1.15 to 1.20 s, just as the index reaches
  the ~98 where a 50 cap would bind. A sim with the threshold moved to match the game's timing is identical to cap 80.
  A clean test needs >700 u/s flight lasting >0.3 s with a key exactly square to the motion. This dash chain can't
  give that: the heading is ~37 deg, and keys come in 45 deg steps.

## Capture tooling

- `gameio.focus_game` minimizes the ESET popup (egui.exe) and any Godot window covering the game before a recording.
  It never closes or answers the popup.
- `DL_SETTLE=S` (driver) waits S seconds before each trial. Scenarios with two dashes need ~10 s for stamina
  (4.5 s per charge). Without it trials 2 and 3 of FF_* had no air dash.

## Still open

- The RRUN slide edge transient (one edge; needs a second ramp top to tell geometry from physics).
- The air strafe cap above 700 u/s (the reachable flight is too short; see FF_*).
- The end drag after a 90 deg air dash (game keeps ~50 u/s more than the sim).
