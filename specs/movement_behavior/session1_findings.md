# Recording session 1: findings (for review, nothing applied)

Source: 35 clips in `tools/movement_capture/rec/` (A1, A2, A3, D1, D3, S2, W1), extracted with `extract.py`, and
analysed with the scripts in `tools/movement_capture/out/_*.py`. Observation only: HUD (`cl_showpos`) plus screen capture.
Units: u = game units (1 u = 0.0254 m). **No `.tres` values were changed.**

Data quality: the position and S readouts are precise. Velocity taken from position is noisy, because the game ran at
~79 fps and the capture at 120 fps, so every fit below uses S directly or fits curves to position (parabolas for z,
exponentials for horizontal motion). S is **3D** speed, so horizontal speed = sqrt(S² − vz²).

## 1. Confirmed (the sim already matches)

| Mechanic | Measured | Sim |
|---|---|---|
| Ground dash speed | 635.0 u/s Haze (10 m / 0.62 s), 546.8 Abrams (10 / 0.72) | same |
| Ground friction after the dash | f ≈ 3.85–4.0, stop ≈ 95–110 u/s | 4 / 100 u/s |
| Air drag (exponential, horizontal) | k ≈ 0.20–0.22 /s (A2, S2 dash-jump and hop phases) | 0.2 |
| Dash-jump total speed | peak S ≈ 811, the **same for Haze and Abrams** (fixed value, set rather than added) | mode 1 SET ✓ |
| Dash-jump window | the jump lands 0.33–0.42 s into the ground dash | 0.30–0.55 ✓ |
| Air dash, aligned | pre ~630–660 → peak ~710–720 | cap C ≈ 732 (Haze bucket) ✓ |
| Air dash length | Haze ≈ 0.43 s, Abrams ≈ 0.51 s, height flat | 0.43 / 0.51 ✓ |
| Air dash end drag | 654→535, 661→540, 730→599, 786→640; Haze from rest drops to the 480 floor; Abrams at 461 does not drop | frac 0.2, offset 80, floor 480: within ~8 u/s ✓ |
| Slide friction | k ≈ 0.189 | 0.1875 ✓ |
| Wall-jump tangent speed | kept ≈ 1.0 (a trials: 597→577, 553→535, ~600→580 after drag) | 1.0 ✓ |

The "air dash builds immense speed" concern is answered: the cap plus end drag hold aligned air dashes to ~710–720 at
the peak, falling to ~540–640 after. The sim's cap model reproduces this.

## 2. Proposed value changes (please review)

| Param | Sim now | Measured | Proposed |
|---|---|---|---|
| `gravity` | 24.562 m/s² (967 u/s²) | A1 761–822; dash-jump arcs 795–852; D3 8h/T² ≈ 802; W1 762–871 | **~20.1 m/s² (≈790 u/s²)**. Recheck: whole-arc fits on all 6 D3 jumps give 777–799 (rms ≈ 2 u), with no clear difference between rise and fall |
| `dash_jump_set_speed` (horizontal) | 15.52 m/s (611) | vh0 ≈ 700–708 u/s | **~17.9 m/s (≈704)** |
| `dash_jump_vertical_speed` | 10.795 m/s (425) | vz0 ≈ 400–420 | ~10.4 m/s (≈410), a small change. With 704 this gives sqrt(704²+410²) ≈ 815, matching P 811 |
| `wall_jump_kick_neutral` | 4.5 m/s (177) | normal component 265–300 u/s over 5 trials | **~6.9 m/s (≈270)** |
| `wall_jump_up_speed` | 7.0 m/s (276) | vz0 ≈ 415–505 (from apex timing at g ≈ 800) | **~11.7 m/s (≈460)**, the least precise value |
| `slide_hop_penalty_drag` | 0.8 extra | hop phases decay at plain air drag (0.198–0.208) | **0** (no penalty seen), pending the flat-floor check in §4 |

Gravity and the dash-jump split belong together: with the current 967 u/s² gravity, the sim's dash-jump arcs are shorter
and steeper than the game's (takeoff to landing ≈ 1.05 s over 17.3–17.75 m).

## 3. Model gaps (structure, not just numbers)

1. **Ground dash constant phase is ~0.58 s** (0.554–0.600, ≈365–371 u), not 0.62 s, while the speed is exactly 10/0.62.
   The dash seems to hand off to friction ~0.04 s early, or its last ticks are a blend. Proposal: keep the speed formula
   and add a separate constant-phase length. Needs code, not a `.tres` change.
2. **The air dash from rest ramps up over ~0.14 s** (peak ~570 Haze, ~503 Abrams, so J ≈ 570). The sim applies the impulse
   in one tick. There is also a ~0.1 s position freeze at the dash start in the A3 trials.
3. **Air dash end drag is spread over ~0.07–0.1 s**, and gravity resumes ~0.07 s after it begins. The sim applies both
   at once. The end values match, so this only affects the shape. The offset is poorly determined (0–80); frac ≈ 0.19–0.21.
4. **The slide-hop is higher than a standing jump**: 82 u from the slide floor (vz0 ≈ 375–380) against 54 u standing.
   Either a slide-jump vertical boost exists or the S2 geometry interfered. Check on a flat floor before adding anything.
5. **Wall stick**: the b trials hold z ≈ 60 for ~0.2 s before the wall jump, but a_t2 shows none (a normal fall along
   the wall). This is not proven, so no change yet.
6. **Wall-jump tangent in the b trials** is ~0.8–1.0 (b_t2 282→224, b_t3 261→248). The a trials say 1.0. The b trials
   were slow, so they are noisier.

## 4. Re-record requests (session 2)

- **A3 (angled air dash).** The angle was held from the start of the ground dash, so there was no real change of
  direction, and the 75° trials hit geometry. Redo: W only through the ground dash and dash-jump, then W+D or D pressed
  **at** the air dash, in open space. This decides the air-dash angle model (keep-perpendicular vs rotate). Only 75_t1
  was usable: heading ✓ (272.1° predicted, 273.7° measured) but magnitude ✗ (832 predicted, 788 measured).
- **W1 at dash-jump speed.** The b trials were at walk or jump speed (~263–380). Redo them approaching at ~700 u/s.
- **D1 neutral trial** (dash with no movement key): missing.
- **Slide-hop on a flat floor** (for gap 4).

## 5. Other changes made

- `layouts/showpos_default.json`: the comment now records that S is 3D speed.
- `tools_fit/fit_core.gd`: `speed_3d` channel (weight 0 by default). The self-test re-run gives 42 passed, 0 failed.
