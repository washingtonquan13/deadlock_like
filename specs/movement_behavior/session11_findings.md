# Session 11: heavy melee (lunge, recovery, cooldown) and the wall-jump press interval

- Setup: Haze, Sandbox map, recorded by the driver with no one at the keyboard (3 trials each, mark `street_y058b`
  for melee, `wallAd` for wall jumps).
- Recordings: `tools/movement_capture/rec_auto/s11_conf/`.
- Scenarios and fit scripts: `tools/movement_capture/scenarios/s11_conf/` (`gen.py`, `hm_an.py`, `hm_sim.py`,
  `hm_sim2.py`, `wi_sim.py`).
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

## Still open

- HM_W's extra ~13 u when the heavy starts from a run.
- The heavy's air recovery (and whether gravity applies).
- The light melee.
