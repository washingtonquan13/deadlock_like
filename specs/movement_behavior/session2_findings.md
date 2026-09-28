# Session 2 findings: automated ground dash (2026-09-27)

Source: observation only. Synthetic keyboard/mouse input in a private Sandbox Mode lobby, and the
`cl_showpos` readout read from screen captures (grid-template OCR). No game code, memory, files or
network traffic. Recordings: `tools/movement_capture/rec_auto/D1*`. Fits: `*_fitnoclamp/`, `*_fitclamp/`.

Hero: Haze (dash bucket 1 per the roster in `hero_movement_stats.gd`, from the wiki Stamina page). Flat street, cheats and fast stamina on.

## Measurement notes

- **The `cl_showpos` pos line is the third-person camera, not the hero.** It sits ~96.6 u from the hero (~90 u behind,
  ~35 u right at pitch 14.7) and moves with yaw and pitch. `setpos` places the hero. At the dash start
  it trails the hero and then overshoots: speed derived from it reached 991 u/s while the readout said 635.
  Use the readout's own speed (`vel_scalar`, fit channel `speed_3d`), not derived position, for fast changes.
  Session 1 positions are contaminated wherever the mouse moved.
- **The readout speed is smoothed between ticks.** It changes every rendered frame instead of stepping once per 1/64 s.
  The fitter's linear interpolation of the sim trace matches this.
- **The game repeats itself exactly.** Six D1 trials, three at `host_timescale` 1 and three at 0.25, all travelled
  526.2 u. `host_timescale 0.25` changes nothing but the sampling density.

## Behaviour

1. **A dash with no movement input does nothing.** This held standing still (4/4) and coasting at 200–300 u/s after
   releasing W (3/3; a 4th try gave no usable reading). The sim instead dashes toward facing
   (`dash_state.gd` `_dash_dir`, movement.md §8), so this contradicts it. It settles gap G23 for ground dashes.
   Air dashes are untested.
2. **A dash pressed in the same tick as the first W from standstill does nothing** (2/2). 16 ms later it fired 1/2 times;
   50 ms and 100 ms later it fired 4/4. Possibly the dash direction comes from the previous tick's input. Untested.
3. **Plateau:** 635.01 u/s (16.13 m/s), constant to the display's precision.
4. **The plateau length does not depend on W.** It lasted 0.576 s as displayed in all three probes: W released at
   0.31 s, 0.67 s and 1.88 s.
5. **There is no speed clamp at the dash end.** After the plateau, speed decays by ordinary ground friction:
   ×0.879 per 1/32 s, then −12.5 u/s per 1/32 s below ~100 u/s. That equals the sim's current
   `ground_friction` 4.0 and `stop_speed` 100 u/s exactly. With W held, the decay stops at 385.8 u/s. This
   settles Open Q6: `ground_dash_exit_clamp` should be false.
6. **With W held, speed settles at 385.8 u/s (9.80 m/s). The sim settles at 283.5 u/s with `suppress_sprint`.**
   This is probably the out-of-combat sprint, and it is a separate gap from the dash.

## Fit (exit clamp off, `speed_3d` only)

| trials | duration (s) | distance (m) | RMSE (u/s) |
|---|---|---|---|
| ts 0.25 ×3 | 0.6037 / 0.5988 / 0.6027 | 9.740 / 9.647 / 9.718 | 6.6 / 6.4 / 10.8 |
| ts 1 ×3 | 0.6100 / 0.6029 / 0.6025 | 9.782 / 9.723 / 9.703 | 20.1 / 7.3 / 6.5 |
| W released at 0.31 s | 0.6039 | 9.737 | 5.3 |

- **Result:** the median is 0.603 s and 9.72 m, i.e. 16.12 m/s, which matches the 635.01 u/s readout.
- **Clamp on:** the best fit is ~60 u/s RMSE, with structured residuals.
- **What's left:** the remaining residual is at the dash start (one tick where the readout dips toward 0 before the jump).
- **The ts1_t1 outlier:** RMSE 20.1. Its dash distance also read short (381 u against ~411 u for the other trials).

Applied 2026-09-27 (reviewed): `ground_dash_exit_clamp = false` in `movement_params.gd`. All 76 tests pass.

## B2 and B3 (Infernus, Abrams), same probe: W released at tick 20, ts 0.25, 3 trials each

Hero switched with the console command `selecthero hero_inferno` / `selecthero hero_atlas` (sandbox, cheats on).
The camera offset differs per hero, so each has its own mark (`street_inf`, `street_abr`). Recordings: `rec_auto/B2_infernus`,
`rec_auto/B3_abrams`; fits in `*_fitnc/`, with the exit clamp off and `speed_3d` only.

| bucket | plateau (u/s) | 10 m / spec duration | displayed plateau (s) | fit duration (s) | fit distance (m) | RMSE (u/s) |
|---|---|---|---|---|---|---|
| B1 Haze | 635.01 | 635.0 (0.62) | 0.576 | 0.603 (0.599–0.610) | 9.72 | 5–11 |
| B2 Infernus | 578.98 | 579.0 (0.68) | 0.637 | 0.667 (0.666–0.668) | 9.81 | 6.4–7.3 |
| B3 Abrams | 546.81 | 546.8 (0.72) | 0.684–0.689 | 0.712 (0.705–0.713) | 9.87 | 6.2–8.4 |

- **Dash speed is exactly 10 m ÷ the spec duration in all three buckets.** So `ground_dash_distance = 10` and the
  spec durations are right as a speed rule.
- **Only the length is off.** The fitted "distance" differs per bucket (9.72 / 9.81 / 9.87), so changing the shared
  `ground_dash_distance` would be wrong.
- **In ticks (×64):**
  - Spec: 39.68 / 43.52 / 46.08. The sim runs ceil() ticks with a fractional last tick (`_setup_ticks`, design §7.10).
  - Fits: 38.6 / 42.7 / 45.5. That is floor(spec) − 0.4 / − 0.3 / − 0.5, a near-constant offset.
  - Compared with the exact value, the offsets are −1.1 / −0.8 / −0.5, which is not constant.
- **Hypothesis (not applied):** the game runs the dash for floor(duration × 64) whole ticks at 10 m / duration,
  with no fractional last tick. The remaining ~0.4 tick is common to all buckets and is probably alignment or display
  smoothing in the fit.

Applied 2026-09-27 (reviewed): `ground_dash_whole_ticks = true`. The ground dash now lasts floor(duration × 64) full
ticks (39 / 43 / 46). Durations and distance stay at the spec values.
- Re-fitting with the change puts the optimum at the spec values: 0.621 / 0.678 / 0.720 s and 10.0 m, with RMSE
  5.3 / 7.3 / 6.2 u/s. The ~0.4-tick residual is gone.
- `test_t05_ground_dash_buckets` and `test_fp1_dash_slow_scales_speed` now expect 39/43/46 ticks and
  displacement = speed × ticks / 64. All 76 tests pass.
- `air_dash_whole_ticks` exists but stays false (see below).

## Air dash (Haze B1, Infernus B2, Abrams B3)

Probe: W from tick 1, jump at tick 4, air dash at tick 16 (still rising), W released at tick 18, then no input, ts 0.25.
- Runs: 2 per bucket, 3 more for B3, and 2 for B3 with a slower entry (jump from standstill, W only on ticks 12–18).
- Trials repeat to within 0.2 u/s. Recordings: `rec_auto/A_air_b{1,2,3}`.

| bucket | entry (u/s) | ramp | peak (u/s) | decay in dash | gravity off (ticks) | spec (ticks) | distance |
|---|---|---|---|---|---|---|---|
| B1 | ~130 | 0.116 s at ~3900 u/s² | 573.3 | −111 u/s² | 28.6–28.7 | 27.52 | ~5.5–5.9 m |
| B2 | ~130 | 0.116 s at ~3610 u/s² | 535.8 | −103 u/s² | 31.5–31.7 | 30.08 | ~5.5–5.9 m |
| B3 | ~129 | 0.116 s at ~3350 u/s² | 503.4 | −97 u/s² | 33.5–33.8 | 32.64 | ~5.5–5.9 m |
| B3, slow entry | ~96 | | 496.4 | | | 32.64 | |

1. **The dash zeroes vertical speed at its start.** The readout drops to the horizontal speed in one tick. This matches
   `air_dash_zero_vertical`.
2. **Speed ramps up instead of being set.** It rises linearly for ~7.5 ticks to the peak.
   - The ramp is real, not display smoothing: the same readout shows a ground dash rising in ~1 tick.
   - The rate scales as 1/duration: rate × duration ≈ 1690 u/s in every bucket.
3. **The peak is below the spec speed, and it is not a fixed target.**
   - 8 m / spec duration gives 732.5 / 670.2 / 617.6 u/s. The measured peaks are 78 / 80 / 82 % of that.
   - Entering 33 u/s slower lowers the peak by only 7 u/s. So the dash neither adds a fixed amount nor sets a fixed speed.
4. **After the peak, speed decays linearly at ≈ 0.19 × peak per second.** This is close to the sim's `air_drag` 0.2
   (G08, provisional), so air drag may stay active during the air dash.
5. **Gravity is off for ~0.6–0.7 tick longer than ceil(spec).** This is the vertex of a parabola fitted to the fall
   after the dash.
   - floor(spec) is further off (+1.7). So the ground dash's whole-tick (floor) rule does not carry over, and
     `air_dash_whole_ticks` stays false.
   - The camera's vertical lag is unmeasured and could explain part of the extra ~0.6 tick.
6. **Distance while gravity is off is ~5.5–5.9 m, not the spec's 8 m.**
7. **The fall after the dash curves at ~800 u/s².** The sim's `gravity` is 967 u/s² (24.562 m/s², spec §10).
   This comes from the camera z, so check it with a plain jump before acting on it.
8. **No 20% end drag is visible at the end of the dash.** This probe can't test the drag, because horizontal speed
   there (~463 u/s) is already below the sim's 480 u/s floor (G02).

The sim's air dash (cap mode 1) sets horizontal speed to the bucket speed at once and holds it. That disagrees with
2, 3, 4 and 6. Fixing it is a structural model change, not a parameter change, so nothing has been changed.

Probes that would pin down the model:
- a dash from a straight vertical jump (entry speed 0);
- a dash sideways or backwards relative to the motion (does the ramp add along the dash direction?);
- a dash while falling;
- a dash with W held throughout.

## Session 2b probes (Infernus B2, ts 0.25, `rec_auto/A_probe_b2`)

Walk, jump and air-dash probes, 1–2 trials each. Speeds are the readout's `vel_scalar`.

**Walk and sprint**
- W held from standstill reaches 326.78 u/s = 8.30 m/s in ~0.45 s, then holds exactly. That is Infernus base 6.7 + sprint 1.6
  (`data/reference/heroes.csv`). Haze's 385.8 u/s above is 8.2 + 1.6. So the "walk/sprint gap" is per-hero base speed
  with sprint on, not a missing mechanic.
- The acceleration is ~1200 u/s² at the start, falling to ~290 near the top. It hasn't been compared with the sim's
  ground-accel curve yet.
- Stop and go (walk 1 s, stop ~1 s, walk): speed returns to 326.78 at once. Stopping does not reset sprint
  (sandbox, out of combat).

**Plain jump**
- Gravity is 798–801 u/s² on both the rise and the fall (~20.3 m/s²). The sim uses 967 u/s² (24.562 m/s², spec §10).
  This is the readout speed, not camera z, so it confirms point 7 above.
- Launch speed is ~299–307 u/s (sim `jump_speed` 295). Apex ~0.39–0.40 s, airtime ~0.77 s.

**Air dash**
- With no move input the trace is identical to a plain jump, so a neutral air dash does nothing (as on the ground).

| probe | entry along dash (u/s) | peak (u/s) | decay (u/s²) |
|---|---|---|---|
| W held | +132 | 535.8 | −103 |
| vertical jump | ~40–77 | 527.6 | −102 |
| sideways | 0 (130 perpendicular) | 533.4 | −103 |
| backwards | −130 | 498.6 | −97 |
| while falling | ~75 | 527.6 | −102 |

- Gravity is off for ~0.505–0.514 s in every probe. Landing is at ~1.06 s (1.38 s for the falling probe).
- **The ramp is close to linear:** ~56 u/s per tick (~3580 u/s²). It runs for ~7 ticks (W held), ~8 (vertical) and ~9–10
  (backwards), so the ramp stops at a target rather than after a fixed time.
- **Candidate peak rule (fits all five within 0.5 u/s):** along the dash, peak = 0.858 × 602.6 + 0.142 × entry
  = 517 + 0.142 × entry. The perpendicular part is kept: the sideways prediction is sqrt(517² + 130²) = 533.1,
  against 533.4 measured.
- After the peak, speed decays at ≈ 0.19 × speed per second, which is consistent with `air_drag` 0.2 staying active.
- **Candidate model (not applied, needs review):**
  1. Zero vertical speed.
  2. Accelerate at ~3580 u/s² along the dash direction until that component reaches 517 + 0.142 × entry (B2).
  3. Keep the perpendicular part.
  4. Apply normal air drag.
  5. Suspend gravity for ~0.51 s.
- The per-bucket constants (the rate × duration ≈ 1690 u/s relation and the 602.6 / 0.858 split) are from B2 only.
  B1 and B3 need the same probes before they can be generalised.

Applied 2026-09-27 (user: "match the game"):
- `neutral_dash_does_nothing = true`: a ground or air dash with no move input does nothing.
- `sprint_reset_on_stop = false`: stopping keeps sprint.
- Both flags keep the spec path for tests (the harness defaults `measured_neutral_dash = false` for legacy cases).
- All 77 tests pass.

Not applied at the time (value changes, need review). All three were applied later; see Session 2c:
- gravity 800;
- the air-dash model;
- per-hero `.tres` files (Haze 8.2, Infernus 6.7, Abrams 6.4 m/s; sprint 1.6).

## Session 2c: B1/B3 air-dash probes and the applied model (2026-09-27)

Same six probes on Haze (B1, `rec_auto/A_probe_b1`) and Abrams (B3, `rec_auto/A_probe_b3`), 2 trials each.

**Ramp.** Each tick adds A − K·v along the dash. A × duration is about the same in every bucket, so the ramp rate is
~48 m/s divided by the dash duration. K includes the 0.2 air drag, which leaves ~1.6/s of extra damping.

| bucket | A (u/s²) | A × dur (u/s) | K (/s) | peak intercept c (u/s) | c / dash speed | slope m |
|---|---|---|---|---|---|---|
| B1 | 4337 | 1865 | 1.75 | 546.7 | 0.746 | 0.151 |
| B2 | 4080 | 1918 | 2.04 | 508.2 | 0.758 | 0.183 |
| B3 | 3700 | 1887 | 1.59 | 476.4 | 0.771 | 0.193 |

- Peak along the dash = c + m × entry along-dash speed. Perpendicular speed is kept.
- After the peak, speed decays at ~0.19 × v per second, so air drag stays on during the dash.
- Gravity-off time is ≈ the spec duration. The extra ~0.035 s seen earlier came from the 0.3 u z-drop detection threshold.
- **End drag:** horizontal speed above ~480 u/s eases down to ~482 over ~7 ticks, not an instant 20%.
  - B1: 537 → 482, about −8 u/s per tick.
  - B2: 497 → 482.
  - B3 ends below 480, so there is no drop.
  - This confirms the 480 floor.

Applied (user: "Yup go ahead"):
- `gravity` 20.32 (800 u/s²) and `jump_speed` 7.62 (300 u/s).
- Per-hero files `data/movement/heroes/hero_{haze,infernus,abrams}.tres`: base 8.2 / 6.7 / 6.4 m/s, sprint 1.6, buckets 1 / 2 / 3.
- `air_dash_cap_mode = 3` (ramp):
  - no impulse at dash start;
  - v_par gains (48 / duration − 1.6 × v_par) × dt per tick;
  - the ramp stops once v_par reaches frac[bucket] × dash speed + 0.176 × entry v_par, with fracs 0.746 / 0.758 / 0.771;
  - air drag stays on (`air_dash_keeps_air_drag`).
- `air_dash_end_drag_mode = 4`:
  - on an airborne dash end, the excess over 480 u/s is removed in 7 equal steps on top of air drag;
  - landing cancels the remaining steps;
  - a dash that ends grounded is not measured and gets no stepped drag.
- The old G01/G02 tests are pinned to the old modes via `legacy_air_dash()`. One loose shape test covers the new model
  (minimal tests until the feel matches).

**Sim vs recordings** (`tools_fit/fit_runner.gd`, evaluation only, per-hero `.tres`, sprint on):
- `side` and `back` match the peak within ~3–8 u/s. The `back` offset is the entry-speed term.
- **W held through the dash (`whold`):** the game peaks 10–15 u/s above the sim in all buckets (B1 573 vs 559) from
  the same entry state. The gain per tick stays higher late in the ramp.
  - Probes that release the key 2 ticks into the dash don't show this.
  - Not modelled: one probe type isn't enough to separate "input held" from other causes.
  - Next probe: two runs that are identical except W held vs released right after the dash press.
- `vert` and `fall`: the recorded dash starts ~5 ticks later than in the probe scenario timeline. Re-align those
  scenarios before using them for fitting.
- After landing with W held the game sits at 385.8 u/s (sprint on), but the sim stays at 322.8. The sim isn't
  activating sprint in this scenario; check the sprint trigger.

Superseded (kept for the record): Held: duration and distance are coupled, because the sim's dash speed is distance / duration. The measured B1 speed,
16.13 m/s, already equals the spec's 10 m / 0.62 s. So the data says the dash lasts ~1 tick less at the same speed:
B1 is 0.603 s and 9.72 m. Changing only the duration would raise B1 to 16.58 m/s (the tests caught this).
`ground_dash_distance` is shared by all buckets, so it waits for the B2 and B3 recordings. The fix may instead be a
per-bucket speed.

```
ground_dash_durations[0] = 0.603      # bucket 1 (Haze), together with:
ground_dash_distance = 9.72           # 0.603 s x 16.13 m/s; changes B2/B3 speeds too
```
