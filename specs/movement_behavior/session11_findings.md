# Session 11: heavy melee, the wall-jump press interval, and the dead dash slide

- Setup: Haze, Sandbox map, recorded by the driver with no one at the keyboard (3 trials each, mark `street_y058b`
  for melee, `wallAd` for wall jumps).
- Recordings: `tools/movement_capture/rec_auto/s11_conf/`.
- Scenarios and fit scripts: `tools/movement_capture/scenarios/s11_conf/` (`gen.py`, `hm_an.py`, `hm_sim.py`,
  `hm_sim2.py`, `wi_sim.py`, `se_sim.py`, `se_hop1.py`, `dc_sim.py`, `run_fit.py`).
- The game's melee bind is AbilityMelee (the driver key `melee` = q). Held, it is the heavy. The heavy commits after
  ~13-14 ticks of hold (the sim's `heavy_hold_time` 0.2 s).
- Scripted tick = game tick (t·64 + 1) − 2.7 (the session-10 recording lag).

## Heavy lunge (G10)

- **Windup:** 23 ticks (0.36 s). With W held, speed decays by the normal friction with no wish (403 → 99), which
  matches the sim.
- **Ground lunge:**
  - Speed ramps linearly from ~0.59 × 750 u/s to 750 over ~13 ticks (0.2 s) and holds.
  - It stops hard ~22 ticks (0.34 s) after the start.
  - Settled distance 227 u (sim 229).
- **Air lunge:**
  - Ramps from ~0.43 × 797 over ~10 ticks.
  - Follows the aim pitch (14.7° down in HM_J), with no gravity.
  - Landing switches it to the ground 750.
  - Distance 223 vs sim 231.
- **Open:** HM_W (running in at ~400 u/s) goes ~13 u further than the sim (246 vs 232), cause unknown.

## Recovery and cooldown (G12)

- **HM_R** (W held from tick 1, heavy at 20):
  - The lunge ends at 0.
  - Normal accel then resumes, but speed is capped at ~115 u/s for ~19-21 ticks (the 0.2833 s recovery).
  - After that the run-up follows the from-rest curve.
  - There is no visible self-slow; the spec's 30% / 0.5 s is not seen. With no keys, speed stays 0 through the
    recovery.
- **Model:**
  - `heavy_recovery_max_speed` 2.921 m/s: ground walk physics under a horizontal clamp.
  - `heavy_self_slow` 0.
  - The air recovery keeps the zero lock (unmeasured).
- **HM_C** (heavy held again from 70) and **HM_C2** (fresh hold from 115):
  - The second lunge starts at scripted tick 162 in both, 120 ticks after the first (42), whether the key was held
    through the cooldown or freshly pressed.
  - So the cooldown ends at a fixed tick, and a held key fires as soon as it does.
  - Counting back the 1.3 s miss cooldown (83 ticks) and the 23-tick windup puts the cooldown start 0.2 s into the
    lunge.
  - Rejected: a cooldown counted from the lunge start (onset 151), and one counted from the lunge or recovery end
    (they need a non-round constant).
- **Model:**
  - `heavy_cooldown_start` 0.2 s: the cooldown is set to 1.5 s at the lunge start.
  - `try_heavy` accepts a held heavy bit.
  - Replay onsets: 162 / 162.

## Wall-jump press interval (G33)

- **Scenarios WI4, WI8, WI12, WI20** (mark `wallAd`): W into the wall, a ground jump at 60, a wall jump at 88, then a
  second jump press at 88 + k. **WN_E** (session 10) is the same without the second press.
- **Result** (`wi_sim.py`, lag-aligned):

  | Case | Game | Sim |
  |---|---|---|
  | Every case | The second press is an air jump (vz back to ~500 u/s, no new kick off the wall). It is never eaten and never a second wall jump. | |
  | WI4, WI8 | Identical: the jump fires at ~+10 ticks, with 235 u of rise over 48 ticks | |
  | WI12 | Fires at once, 244 u | 241 u |
  | WI20 | Fires at once, 267 u | 265 u |

- **Model:**
  - A jump pressed within `wall_jump_min_interval` of a wall jump is held (`MoveState.jump_deferred`) and fires when
    the interval ends.
  - The interval is 0.156 s (10 ticks). The sim gives 231 u for WI4/8, with the 2-3 u low bias seen in
    WI12/WI20/WN_E.
  - This replaces the 0.125 s placeholder that ate the press next to the wall.
- PROVISIONAL: whether a press held into the wall's reach at the interval end gives a second wall jump. The WI runs
  are already off the wall by then.

## Dead dash slide (G21)

- **Scenarios DC12/20/24 W and R** (mark `street_y058b`): W from tick 1, dash at 4, crouch held from tick c for 40
  ticks, W held through (W) or released at c − 1 (R), then an S brake.
- **Result** (`dc_sim.py`, HUD speed):
  - A crouch 8 or 16 dash ticks in (DC12, DC20): HUD drops 635 → ~442 within 2 ticks, then follows the normal
    dash-slide decay (437 → 292 over 37 ticks).
  - A crouch 20 dash ticks in (DC24): keeps ~640 and decays by the same ratio (0.67 over 37 ticks).
  - W held or released makes no difference.
  - So the dead window ends between 0.25 and 0.3125 s into the dash, matching Leif's 0.3 s.
- **Model:** `dash_slide_dead_before` 0.3 s, `dash_slide_dead_speed` 11.405 m/s (449 u/s). A dash slide entered
  earlier starts at the dead speed, otherwise at `dash_slide_speed` 650. DC12/DC20 replay within ~5 u/s, with the
  sim ~1.5 ticks early.
- **SE (slide hop out of an early dash slide):** the hop-1 mismatch was this dead slide. After the model change the
  SE2 hop-1 apex is 292 (game HUD 293).

## G09 clear time (SC, SE): not measured

- SC6/14/24/36 are invalid: hop 1 lands near the runway end, where the hero hits scenery.
- SE2/8/12/16/24/40 can't measure it either: out of the dead slide, hop 1 lands at ~280 u/s, below the 350 slide
  entry, so there is no second slide to hop out of.
- A redesign needs a live dash slide (crouch at dash tick 20 or later, scripted tick 24+).

## G09 clear time (SL): at most 0.5 s, not narrowed

- SL4..SL48 (live dash slide: crouch 24..32, slide hop 30; hop 1 lands at ~77 near 393 u/s; W held, crouch 77+k,
  hop 6 ticks later).
- For k <= 24 the HUD is below 350 at the crouch (the landing coast below), so hop 2 is a crouch jump, not a
  slide hop. k 32 and 48 slide and hop clean.
- So the flag clears within ~0.5 s of ground time. That is consistent with the sim's 0.25 s but does not narrow it.

## Slide jump keeps the crouch (SE, SL, SC)

- After a slide jump (dash slide or normal slide), landing with crouch released and W held, the HUD coasts on ground
  friction alone for a while. Then the normal run ramp resumes, with sprint kept (it climbs back to ~399, not the
  crouch-walk 187).
- The coast ends ~55 ticks after the slide jump in all three families: SE (hop 26) ~80, SL (hop 30) ~85,
  SC (hop 103) ~158. That is 5, 7 and 9 ticks after landing for SE40, SL48 and SC, so it is keyed to the jump,
  not the landing.
- Model: `slide_jump_crouch_time` 0.86 s. A slide jump holds crouch until then, even with crouch released in the air.
  Landing inside that window enters CROUCH (friction only, no sprint reset); the hero stands at its end.
- HUD-vs-sim rms over all SE/SL/SC trials: 54.0 (off) -> 28.1. A 50/53/55/57-tick scan gives 48.4/36.7/28.1/28.2.
  The remaining worst points are the SC dash-jump tick and the SE landing tick, where the HUD reads 3D speed.

## Contaminated hero from ~15:47 (RUN)

- By the end of the session the sandbox Haze was level 19 with 6 items (~$25,600,
  `citadel_hero_testing_infinite_money true`). `selecthero` to another hero and back does not reset level or items.
- **RUN** (plain W run from rest): the HUD reaches ~414 u/s by 1.5 s, where the clean run (sessions 5-7) plateaus at
  386.

  | t (s) | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 | 0.8 | 1.0 | 1.5 | 2.0 |
  |---|---|---|---|---|---|---|---|---|---|
  | Game (mean of 3) | 221 | 287 | 330 | 359 | 378 | 399 | 408 | 414 | 405 |
  | Sim | 230 | 288 | 326 | 351 | 367 | 386 | 386 | 386 | 386 |
  | Sim, base 8.916 m/s | 230 | 288 | 326 | 351 | 367 | 386 | 394 | 399 | 400 |

- The early ramp matches the constant 1600 u/s² accel, yet the game ends above the 400 u/s ceiling that constant
  accel (with friction 4) imposes. No single override fits (`run_fit.py`: raising the accel reference fits the
  plateau but overshoots the ramp). This is a buffed hero, so the model was not changed on it. It does show 400 u/s
  is not a hard ground ceiling once move speed is raised.
- Dash and slide values in DC/SE are unaffected (they match the clean session-9 numbers).
- The heavy-melee runs (from 15:47) are also on this hero. HM_W's lunge profile does not change with the base speed
  override, so its extra ~13 u is not explained by the run speed.

## Still open

- HM_W's extra ~13 u when the heavy starts from a run.
- The G09 clear time below 0.5 s (SL k <= 24 never reach a slide; needs a faster hop-1 landing).
- The ground accel above 400 u/s on a buffed hero (RUN; needs a clean hero).
- The heavy's air recovery (and whether gravity applies).
- The light melee.
