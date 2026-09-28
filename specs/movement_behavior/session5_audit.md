# Session 5: audit of existing recordings (HUD-based, adversarially verified)

Five analysts re-derived each subsystem from the existing recordings. An independent verifier re-derived every
proposal with its own scripts. Only the verified parts are listed as measured. No new recordings were made.

## Method note: pin vz0 before fitting horizontal speed in the air

In free fall, HUD² = h² + vz². Fitting h and vz0 together over a window cannot tell drag from a larger vz0. Drag d is
absorbed as vz0' ≈ vz0 + d·h²/g, and synthetic d = 0.21 traces reproduce the session-4 "no drag" table.
- Pin vz0 from the airtime on flat ground (vz0 = g·T/2, with T between the HUD takeoff and landing steps).
- A camera-free check: with no drag, the HUD minimum sits at the airtime midpoint. The game's minimum sits +2.5 ticks
  later on plain jumps and +7.5 ticks later on dash jumps.

## Air

- **Air drag ≈ 0.20/s, proportional, in all normal air.**
  - Pinned fits: A0/AW 0.196–0.228, DJ20/22/27 and dj148 DJ27 0.196–0.214.
  - The fall after an air dash is also ≈ 0.2.
  - u' = −A − D·u on DJ27/DJW gives D = 0.2 with A ≈ 0.
  - Sim fits are best at 0.20. This equals the in-dash air-dash drag.
- **Jump takeoff keeps horizontal speed.** h0 equals the pre-jump ground HUD: A0 370.9 against 366–369. The old
  "h 339" came from the unpinned fit.
- **Dash-jump launch:** h0 704–713 (mean ~709), vz0 ~414–419. It does not depend on the jump tick (k 20–35) or on the
  hero (Haze, Abrams). The landing h is ~566, and the landing ground slide matches once drag is on. The "615–625"
  recheck was the same artifact.
- **Gravity:** 795–797 u/s², against 800 in the sim (no change). Plain-jump airtime is 46.0–46.9 ticks against the
  sim's 47.
- **Air-jump horizontal rule.** h is re-measured with d = 0.2 fixed, and vz1 is cross-checked against the landing
  time. The rule:
  1. Along the wish of the previous tick, top up toward run speed, adding at most 200 u/s.
  2. There is no gate at 280 and no |h| cap. DBL, DGWD, DGBSA and DGBSD reach 434–463, above 386.
  3. A key change on the air-jump tick itself is ignored. In DB0, W is released on that tick and the jump still adds
     along W, to 381–385. In DBS, S on that tick is ignored.
  4. The previous-tick clause could be a capture artifact. The key latency check (AS vs A0) rules that out.

  | Case | Game h | Rule |
  |---|---|---|
  | DBW8–36 | 380–389 | 386 |
  | DBL | 434–437 | 433 |
  | DGWD / DGBSA / DGBSD | 437–463 | 454 |
  | DBX / DBRW | 273–284 | 280 |
  | DGRWD / DGRSD | 282–291 | 280 |

- **Air wishspeed cap:** 80 u/s is confirmed. Air jump vertical is 522 (flat-landing airtime gives ~516).
- **Wall-jump kicks and vertical rule:** confirmed once drag is on.
  - WJ0 |h| 269.4 against 268; WJS 362.9 against 361.
  - Apex HUD, game vs sim with drag: WJ0 235 vs 234, WJS 316 vs 314.
- **Air accel:** a 2.03–2.09 fit from AS alone (one scenario). Inconclusive, so it stays at 2.0.

## Air dash (timescale 0.25, B1/B2/B3; gravity off, so HUD = horizontal speed)

- **Peak target:** frac[b] × 8 m/dur + 0.26 × v_par0, with fracs 0.759 / 0.776 / 0.789. The old 0.746 / 0.758 / 0.771
  with an entry fraction of 0.176 was 2–21 u/s low.
  - Least-squares peaks: B1 554.1 + 0.240·v0; B2 516.1 + 0.260·v0; B3 484.7 + 0.266·v0.
  - Entries above ~80 u/s are unmeasured.
- **Ramp damping:** the ramp damps on the speed gained since dash start, not on absolute v_par. At the same tick index,
  per-tick increments are equal across entries from −60 to +80.
  - Fit: gain = (R − c·(v_par − v_par0)) / dur, with R = 49 m/s and c = 0.85 (K = c/dur).
  - Over 36 trials this gives rms 3.91 and matches the peak tick in 34 of 36. The best absolute-v rule gives rms 7.02
    and 26 of 36.
- **Settled:**
  - In-dash drag 0.2.
  - Holding or releasing W during the dash makes no difference.
  - The perpendicular component is kept.
  - Gravity-off length and the 480 end floor over 7 ticks.
- **After the dash:** the horizontal decay continues (~0.2/s, covered by the general air drag). A gravity restart 1
  tick late cannot be separated from the decay rate yet (inconclusive).
- **R1 route:** the 639 vs 667 gap is the S+D air jump, not an air dash.

## Slides

- **Dash-slide peak:** the first slide tick reads 641–643 in the game against 636 in the sim. The sim applies friction
  on the entry tick. `dash_slide_speed` 650 u/s reads 643 on that tick.
- **Dash-slide penalty onset:** knee − t(643) has a median of 62.95 ticks in the game. Once the peak fix is in, the sim
  needs 64 ticks (1.00 s).
- **Settled:** dash-slide friction 0.69, penalty friction ~3.2–3.3, onset independent of input, landing-slide friction
  0.189, and the store-crouch threshold.
- **Not applied:** the slide analyst's "0.92 takeoff loss" and its "0.69 dash-slide jump cut". Both came from the
  unpinned no-drag fit (walk-jump h 338 from 368 is exactly the artifact). They need a refit with drag and pinned vz0.
  The landing-into-slide loss (~0.877, SHJ3/SHJ10) is inconclusive.

## Ground, dash, stamina, mantle

- **Ground accel is a constant ~1600 u/s² for every hero,** not 4 × wishspeed.
  - Haze best k is 4.15 and Infernus 4.9; k × run speed = 1601 for both.
  - Abrams-bucket pre-jump slope is 20.1–20.3 u/s per tick, the same as Haze.
  - Friction 4 and stop speed 100 are confirmed. A run speed above 400 u/s (the steady state) is unmeasured.
- **Settled:**
  - Ground dash profile within ~0.1 tick for all three buckets, with plateaus 635 / 579 / 547.
  - Dash counts and stamina regen.
  - Backpedal mult 1.
  - Run speeds.
  - Mantle exit speed 177.
  - Climb durations within ~2 ticks.
  - Mantle glide 537 and crouch walk 187.
- **Mantle exit lasts 10–14 ticks (median ~11–12) wherever the mantle triggered.**
  - The game closes the gap to the face during the climb (TJ040B stops horizontally ~2 ticks before contact).
  - The sim walks the whole gap in the exit phase (15–20 ticks from a gap).
- **Open:** the game accepts a 1-tick jump press 2.5–6 ticks before the ledge comes in reach, and the sim does not.

## Recordings that would settle the remaining questions

- **Air:**
  - No-key air jump (NK1/NK2).
  - Key change at AJ−1 (latency).
  - Diagonal asymmetry (DGWD/DGWA/DGBSD/DGBSA ×3, plus a 90° yaw).
  - Standing air-jump add size.
  - Air control above 700 u/s (dash jump plus S or A).
  - Post-air-dash long fall from a ledge.
  - WJD/WJA tangential kick.
  - Wall-jump rising gain.
  - AS ×4 and S at the apex (air_accel).
- **Air dash:**
  - Entry-speed sweep (W/S for N ticks before the dash, and a back dash).
  - High-entry air dash after a dash jump.
  - Diagonal air dash.
- **Dash jump:**
  - Jumps at k = 40 and 44 (tail speed at takeoff).
  - Plain jump from sprint.
  - dj148 DJ27 retake on a clear lane.
- **Slides:**
  - Landing-loss split (ledge heights, crouch or not).
  - Chained slide hops (G09).
  - Non-dash slide jump at known speeds.
  - SL0 at timescale 0.25.
- **Ground and mantle:**
  - Strafe mult.
  - Crouch-walk accel.
  - Sprint build-up.
  - Mid-dash wish change at timescale 0.25.
  - Mantle max height (150–174 u).
  - Mantle trigger from a gap at timescale 0.25.
