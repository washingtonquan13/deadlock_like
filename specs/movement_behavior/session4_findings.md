# Session 4 findings: air steering (Haze, sandbox)

Clean-room measurements: private sandbox, `cl_showpos` HUD OCR via `tools/movement_capture/driver`.
Units: u and u/s (1 u = 0.0254 m).

## Setup

Mark `street`, long open run. Walk W for ticks 1–40, jump at tick 40, hold the key under test from tick 41 to 130.
Takeoff speed is ~345–365 u/s (the jump comes before full walk speed). Airtime is ~0.72 s.
The generator is `tools/movement_capture/scenarios/air/gen.py`.
The fits are `scenarios/air/fitair.py` (v0 + constant accel) and `scenarios/air/velser.py` (velocity series).

| Scenario | Held in air | Result |
|---|---|---|
| AW | W (already faster than the cap) | Only drag: −71 to −87 u/s² at ~365 u/s (0.2/s × 365 = −73) |
| A0 | nothing | Drag only, −37 to −56 u/s² (noisy) |
| AS | S | A straight line from +344 to −80 u/s in ~0.5 s, ~800 u/s² (drag included). It then holds at −80 |
| AD | D | Lateral goes 0 → ~−75 u/s and holds. Forward keeps drag only |
| RW | W after a standing jump | 0 → ~75 u/s in ~0.1 s, then holds ~76–82 |
| RD | D after a standing jump | Same as RW, sideways, ~−75 to −80 |

## Conclusions (applied)

- **Air accel:** ~780 u/s², the same for every key direction and any current speed. This matches the ~740 u/s²
  pull after a wall jump (session 3).
  - In the Source-style formula `accel = air_accel × walk speed`, that is `air_accel` 2.0 for Haze (386 u/s), down from 10.
  - Scaling with the hero's walk speed is assumed, not measured. A different-speed hero would tell.
- **Wish cap:** 80 u/s along the wish, confirmed (`air_wishspeed_cap` 2.032 unchanged). Holding a key only adds
  speed until the velocity's component along the wish reaches 80.
- **Drag:** 0.2/s is consistent with AW.

## Open

- The 50 u/s cap above 700 u/s (`air_wishspeed_cap_fast`) is untested here.
- Mouse-turn air strafing (turning while holding A/D) is untested. It should follow from the cap and accel.

# Dash jumps (Haze B1, mark street)

Scenarios are in `tools/movement_capture/scenarios/dashjump/gen.py`: W held, ground dash on tick 4, jump press k ticks later.
Fits: `fitdj.py` (window, takeoff), `launchh.py` (launch speeds), `hudh.py` (speed series).
**Camera-derived horizontal positions are unreliable during a ground dash:** they read ~950 u/s while the HUD shows 635.
Horizontal speeds below come from the HUD speed (3D) with vz from the height track.

## Launch (applied)

- **Horizontal:** 703 u/s in all 12 trials (DJ20/22/27, DJC, DJW; fit residual ~4 u/s). The dash plateau is 635, so this is ×1.107.
  - `dash_jump_set_speed` goes from 15.519 to 17.856 m/s.
  - It is **set, the same for every bucket**: Abrams (B3, dash plateau 547) launches at 703.3–703.7 (DJ22/DJ27 on `street_abr`, `scenarios/djabr`).
- **Vertical:** ~412 u/s at the first airborne frame. That is consistent with 425 set minus one tick of gravity, so it is unchanged.
- **In the air:** drag 0.2/s alone fits the horizontal decay (703 → ~570 at landing, airtime 1.03 s).

## Window

| Jump press after the dash (ticks) | Result |
|---|---|
| 12, 18, 19 | No jump at all |
| 20, 22, 27, 33, 34, 35 | Dash jump |
| 36, 40 | No jump at all (the press is dropped, not buffered into a plain jump) |
| 12 then 27 (DJL) | No jump: the early press locks the dash jump out |

The edges are exact: the window is k = 20–35, the same as the model's 0.30–0.55 s (open tick 20, close tick 35). The early-press lock matches too. The sim buffered a late press into
a plain jump when the dash ends (tick 39); the game does not (fixed in 38bc2ed).

## Landing: no dash-jump landing cut (retracted)

The apparent cut (~570 → ~85 u/s at touchdown) is **an obstacle on the street line, not a mechanic**:

- **Landing spot decides it.** DJ27, DJW and DJC land at camera-f ≈ −200 and collapse at once. DJ20 and DJ22 land ~15 u shorter and keep 466 → 392 for ~0.1 s before collapsing. DJ33–35 hit it mid-air (h = 0 before landing).
- **DJW settles at ~70 u/s with W held.** That is the tangential remainder of walking into an angled wall.
- **Short landings just take ground friction:**
  - DJSb (a dash jump slowed by S to ~300 before touchdown): 264 → 223 → 149.
  - DJ44–52 (plain jumps).
- **Walking check (runway RW):** walking along the street yaw also stops. At yaws 58 and 148 from the same spot, walk speed holds to ~32 m. So the landing and slide scenarios are re-recorded on mark `street_y148` (`scenarios/dj148`).

## Jumping after the dash

- Presses at k = 36 and 40 give nothing.
- Presses at k = 44, 48 and 52 give a plain jump: vz ~283 (the measured plain jump is ~300), peak 54 u. Speed is kept (DJ44 takes off at ~600 3D).
- k = 41, 42 and 43 (on `street_y148`) give plain jumps too. So jumping works again from k = 41; the sim allows it from k = 40.
  - That difference is within the ~1 tick input-phase uncertainty, so there is no change.

## Dash-jump landing on a clear runway (`street_y148`, sim already matches)

| Case | Game | Sim |
|---|---|---|
| No key (DJ27) | Lands at ~565, then ground friction: 435 → 141 over 0.28 s | 0.31 ratio |
| Crouch held from mid-air or just before touchdown (DJC, DJC2) | Slide at the landing speed (no boost): 567 → 506 over 0.61 s, ~100 u/s² | DASH_JUMP landing slide, 568 → 502 over 0.70 s, ~94 u/s² |
| Crouch pressed after touchdown (DJC3, DJCP100/106/110) | Ground friction until the press, then a slide at the speed left (see below) | Same, within ~1 tick |

- **Late part of DJC and DJC2:** the drop after ~0.65 s of slide is the landing-slide penalty onset (~0.69 s, see "Landing-slide onset" below), not the end of the runway.
- **Crouch after touchdown (DJC3 resolved; `cslide.py`):**
  - The sim lands on input tick 98. The recorder adds ~2.5–3.5 ticks of latency, and that latency is the same for jump and crouch presses within a run.
  - A crouch 2 ticks after landing (DJCP100) slides ~3 ticks after touchdown, at 471 (sim: 2 ticks, 531).
  - A crouch 5 ticks after (DJC3) slides ~5.5 ticks after touchdown, at 390 (sim: 5 ticks, 438).
  - A crouch 8 or 12 ticks after (DJCP106/110) gives no slide: the speed is already ≤ ~350, below slide entry, and it just crouches (the sim slides at 362 for DJCP106).
  - So there is no crouch-to-slide delay. The residual is ≤ ~1 tick of phase (the game's rise→land is ~66 ticks against the sim's 67), and there is no model change.
  - The old "sim slides from ~530" figure came from before the landing-slide fix (7f4b266).

## Mantles (Haze, crate top 66 u above the sidewalk, mark crateA)

Scenarios are in `scenarios/mantle/gen.py` (the face is ~250 u ahead, contact at ~tick 57); the summary helper is `sumry.py`.

- **No jump, W into the face (MW):** no mantle. The hero slides along the angled face at ~105 u/s.
- **Climb** (jump pressed at contact, or shortly before it, with W held; MJ050/MJ056/MJ070):
  - Horizontal motion stops, and the hero rises straight up at a constant ~206–216 u/s (the HUD reads 215.6 steady).
  - From the ground, 64 u takes ~0.32 s. MJ050 made contact mid-air with 34 u left and climbed it in 0.164 s.
  - So the duration scales with the remaining height; it is **not** a fixed band.
- **Exit:** a constant ~176–177 u/s forward for ~0.16–0.18 s (~11 ticks, ~30 u).
  - That speed is then **kept**, and W accelerates normally from it. The sim ended at 0.
  - The whole mantle takes ~0.5 s from the ground; the sim took 0.3 s.
- **Crouch held (MJ056C):** same climb and exit phase, then a slide at ~535–540 u/s, held roughly constant for ~0.2 s until the next wall. The sim applied 550 at mantle end.
- **W released at the jump (MJ056R):** plain jump with no climb; the hero falls back. The climb needs W.
- **Early jumps** that reach the face with feet ~12–24 u below the top (MJ030/038/044):
  - The hero pops onto the top and keeps its horizontal speed (~330–350).
  - This happens with W released too (MJ044R, 2 trials), so it behaves like a step-up or pop, not the climb.
  - With crouch held (MJ044C): pop, then crouch-walk at 187 u/s.
- **Not repeatable at the same inputs (MJ056 t1, MJ070 t1):** a plain jump (apex ~62 u camera) followed by a pop onto the top without input. The cause may be the crate seam or the lateral slide position.
- **Airborne trigger (MJ012–022, MS68/72/76):**
  - MJ050's contact is actually ~3 ticks after the press (the speed drops at ~53), not 12.
  - In MS72 and MS76 the hero jumps at 40, brakes with S in the air, then holds W and stays against the face (horizontal distance flat at ~241) from ~tick 72 until landing at ~88. Its feet go from ~7 to ~54 u below the top, with no recent press. There is **no mantle and no pop**: it slides down the face.
  - So an airborne contact needs a jump press near contact. This matches the sim's "jump pressed or held" rule, so there is no change.
  - MJ012–022 land before reaching the face, so they don't test this.
- **Open:**
  - How long before contact a press still counts (≤ ~3 ticks is confirmed).
  - The pop threshold.
  - Taller ledges and the maximum mantle height (only a 66 u ledge was tested).

## Double (air) jump (Haze, mark street)

Scenarios are in `scenarios/double/gen.py`: walk W, ground jump at tick 40, then an air jump k ticks later. Two trials each. The fit helpers are `vzfit.py` and `dsum.py`.

- **vz is set, not added.** The rise from the press to the apex is 164.7–175.9 u for every k:

  | k | vz before the press | Rise to apex |
  |---|---|---|
  | 8 | +188 | 174 |
  | 16 | | 169 |
  | 24 | ~0 | 168 |
  | 36 | −135 | 166 |

  - The standing case (DBR, no horizontal speed) fits vz0 = 516–527 at g = 790–797.
  - So the air jump sets **vz ≈ 522 u/s** (13.26 m/s). The sim had 295.
- **Horizontal velocity is untouched.** There is no impulse and no redirect:
  - W held and no key (DBW24, DB0) give the same forward speed afterwards.
  - D from rest (DBR) traces the same lateral path as a plain air strafe (RD): −12 u at 0.2 s and −28 u at 0.4 s in both.
  - S from the air jump (DBS) decelerates at the same ~800 u/s² as plain air S (AS).
- **Not measured:** stamina cost, and air jumps after a dash jump or a wall jump.

## Slide hops and bunny hops (Haze, mark street_y148)

Scenarios are in `scenarios/hop/gen.py`. The dash slide is W 1..23, dash at 4, crouch from 24 (S0), running at ~635 u/s. The jump in SHJk is pressed at S0+k. Two trials each. The helpers are `ser.py` (series) and `hsp.py` (horizontal speed after a jump).

- **No vertical boost.** The apex is ~54 u above standing, the same as a plain jump. The session-1 "82 u" was the crouched camera, which sits 29 u lower in a slide.
- **Jumping out of a dash slide cuts horizontal speed to ×~0.75.** The cut lands within ~2 ticks of the press. After it, the air decay is normal (not an extra drag). Held, released or re-pressed crouch makes no difference.

  | Jump | Slide speed | After | Ratio |
  |---|---|---|---|
  | SHJ3 | 637 | 477–482 | 0.75–0.76 |
  | SHJ10 | 602–606 | 446–448 | 0.74 |
  | SHJ19 / 19R / 19P | 545–552 | 403–410 | 0.74–0.75 |
  | SHJ40 | 435 | 331–332 | 0.76 |
  | SHJ60 | 351–354 | 267–276 | 0.76–0.79 |

- **No cut from a landing slide (SLDJ).** This is a dash jump, landing into a slide, then a jump 20 ticks later: 538 → 541 at takeoff.
  - The later drop to ~420 at the apex is the street geometry: the camera's lateral motion goes to exactly 0, so it is a wall clip.
- **Walking jumps:** no cut (~355 at takeoff).
- **A held jump does not re-hop (BHH):** one jump only.
- **Bhop (BHP2, BHP8, walk jump then jump again 2 or 8 ticks after landing):** horizontal speed is kept through the re-jump (~340 → ~340). Ground ticks only apply normal walk friction and accel.
- **Landing with crouch held after a slide jump:**
  - **Jumped at slide tick 19, 40 or 60:** no slide. The hero lands crouched and brakes to 0 (~430 → 0 in ~40 ticks), the same as with crouch released (SHJ19R).
  - **SHJ19P (crouch released at the jump, pressed again in the air):** landed at ~270, under the slide entry speed, and braked as well.
  - **Jumped at slide tick 3 or 10:** the hero lands into a slide at ~380 / 353 that decays slowly (~0.15–0.19/s, landing-slide friction). The slide ends near tick 145 in both, then it brakes. That is ~43 ticks after the slide steps up the curb at ~680 u (see "Landing-slide onset"), not a landing-based timer.
  - So a late slide jump stores crouch like a ground jump does (G40), and an early one does not. The threshold lies between slide ticks 11 and 18.
- **Open:**
  - A non-dash (normal) slide jump.
  - Chained slide hops (the G09 second-hop penalty).
  - Whether the early/late threshold counts slide ticks or time since the dash.

## Landing-slide onset (Haze, mark street_y148)

Scenarios are in `scenarios/lslide` (`gen.py`). Helpers:
- `land.py`: landing tick, and decay over ~21 ticks.
- `onset.py`: first tick where the HUD speed falls faster than 1.5/s.
- `atd.py` and `dist.py`: camera distance along the runway.

The runs are:
- LSD k: a dash jump (dash 4, jump 31), S held in the air for k ticks to set the landing speed, crouch from 61.
- LSA, LSB, LSW, LSWS: S and crouch order variants, and walk jumps.
- LSX16: LSD12 shifted 16 ticks later.
- LSJ20 and SLC: ground dash slides with the crouch at 50 or 34. LSJ20's jump at 20 did nothing; the dash seems to ignore a jump that early.

**The runway has a curb.** About 680 u out on `street_y148`, the ground steps up ~8 u, then falls ~3 u over the next ~100 u. A slide that crosses it acts like a fresh landing:
- The friction switches from the dash slide's ~0.69/s to ~0.2–0.25/s.
- The penalty clock restarts.

Earlier landing-speed and onset readings near the curb must allow for this.

**Entry on a flat landing: speed, not the dash jump.**
- A dash-jump landing with crouch held slides only above ~350 u/s (the normal entry speed; bracketed between ~300 and ~390 on flat).
- At 260–305 (LSD20, LSA) it brakes with ground friction, the same as a walk jump at ~298 (LSW).
- The slides that did start from 200–250 (LSD26, LSB, one LSD30) all landed on the curb's down slope, so the slope triggered them.
- Holding S at the crouch press makes no difference.

**The friction and penalty are the same as a normal slide.**
- Before the onset, every landing slide decays at 0.18–0.19/s.
- After the onset, a dash-jump landing slide brakes as hard as a ground slide: ~350 → 0 in ~40 ticks (LSD12, LSX16). There is no gentler dash-jump penalty.

**Onset: ~44 ticks (0.69 s) after the landing.** A later landing moves it by the same amount:

| Run | Land | Onset | Gap |
|---|---|---|---|
| LSD12 | 101.2–101.6 | 145.3–145.4 | 44 |
| LSD26 | 101.0–102.5 | 146.2–146.6 | 44–45 |
| LSB | 102.0–102.7 | 145.8–146.1 | 43–44 |
| LSX16 | 117.4–117.9 | ~162–163 | 45 |

Curb crossings behave the same way. SLC, LSJ20 and SHJ3/10 reach 680 u at 86–100 and hit the onset ~40–44 ticks later.

**Ground dash slides that stay before the curb** keep the ~1.0 s onset (SL0: crouch 24, onset ~88).

This agrees with the shot list's "a slope resets the window to 0.6 s" (V15). The landing reset is ~0.69 s.


## S during a slide (Haze, mark street_y148, sim already matches)

Scenarios are in `scenarios/sback`: a dash slide with crouch from 24, plus:
- SB0: no input.
- SBS: S from 32.
- SBSD: S+D from 32.
- SBS60: S from 60.

The helper `fl.py` prints forward and lateral velocity from camera differences.

- **S does not brake.** The HUD speed matches SB0 tick for tick until the penalty onset (~90).
- **It steers instead,** at the normal slide turn rate: the heading reaches ~−90° about 1 s after the press (~90°/s).
- **Plain S always turns to the camera's right,** in both trials of SBS and SBS60. S+D turns the same way at the same rate.
- **After the slide ends,** velocity snaps to the wish at crouch-walk speed (~187 u/s): straight back for S, back-right for S+D.
- **The sim already turns under S,** but which side it picks came from float noise. It now breaks the tie to the right.

## Wall-jump fatigue (Haze, mark wallA, head-on)

Scenarios are in `scenarios/wallfat`. The setup is the same as WJW: W held throughout, ground jump at 60, first wall jump at 88. W pulls the hero back to the wall, so re-contact comes at ~133.
- WF2_P: a second wall jump at P = 138, 141 or 144.
- WF3_P: presses at 88, 141 and P = 186 or 192.

`fitj.py` fits camera z with a fixed 800 u/s² gravity (and forward position linearly) over 8-tick windows before and after each press.

| Jump | Ticks since the previous press | vz before | vz after |
|---|---|---|---|
| 1st | – | −31 to −44 | 518–543 (the session-3 rule gives ~507) |
| 2nd | 50 / 53 / 56 | −99 / −128 to −142 / −170 to −181 | 165–180 / 169–186 / 183–191 |
| 3rd | 45 / 51 | −363 to −382 / −404 to −425 | 71 / 95–96 |

- **The kick off the wall is not fatigued.** The forward speed after every jump is −150 to −171 over the same window.
- **Only the vertical is fatigued, and it recovers with time since the last wall jump.** A press 6 ticks later gains ~37 u/s in both the 2nd and the 3rd jump. The 3rd jump is not worse than the 2nd once you allow for its timing and its faster fall.
- **Model that fits all 14 samples (rms ~8 u/s):**
  - vz = 519·(1 − f) + 0.30·vz_before (falling), where f is the fatigue left at the press.
  - Each wall jump sets f = 1.
  - f recovers linearly to 0 over ~125 ticks (1.95 s).
  - The fall-speed term is not scaled.
- **Other fits:**
  - Scaling the whole launch, fall-speed term included, cannot fit the 2nd and 3rd jumps together.
  - A free linear fit reaches zero recovery at ~8 ticks after the press, which is close to the 0.125 s wall-jump lockout.
- **Open:**
  - Rising-contact repeats.
  - Whether a landing clears the fatigue (the sim assumes it does).
  - Whether an airborne melee adds fatigue.

## Air jump: stamina and horizontal (Haze, marks street_y148 and wallA)

Scenarios are in `scenarios/stam/gen.py`, `scenarios/double/gen.py` (DBX, DBL, DBRW, DBB) and `scenarios/wallfat` (WJAJ).
Two trials each. `stam/dashes.py` counts dashes (HUD ≥ 600 within 12 ticks of a press). `double/hser.py` prints forward and lateral velocity from camera-position slopes.

- **The air jump is free.** SAJ spends two charges on ground dashes, then does an air jump and an air dash before any regen. The air dash still fires (to ~570, z flat) in both trials, and the SAJ0 control matches. The sim charged 1.
- **A dash jump costs 2 in total.** In SCDJ, a dash followed by a dash jump leaves one charge. This matches `cost_dash_jump_extra` 1.
- **Regen is ~140 ticks after each use.** A 4th dash at +142 failed, while dashes at +148 and +196 fired. Fast stamina may still have been on, since the spec says 4.5 s, so the regen time is not applied. **Superseded:** see "Stamina regen (fast stamina off)" below: 4.5 s per charge.
- **Air jump after a dash jump (DJAJ at +10 and +30):** allowed, and the ~620 horizontal speed is kept.
- **Air jump after a wall jump (WJAJ):** vz is set to ~520–545, as in the plain air jump. The camera next to the wall is too unreliable to judge the horizontal.
- **The air jump accelerates along the held direction.** Other components are kept:

  | Case | v·wish before | v·wish after | Other component |
  |---|---|---|---|
  | DBX: S-brake, then W | ~100 | ~275–290 | – |
  | DBRW: standing jump, W | ~80 | ~275–285 | – |
  | DBL: W walk, then D | ~82 (lateral) | ~270–280 | forward ~330 kept |
  | DBB: W walk, then S | ~−210 | ~0 (then air accel to −80) | – |
  | DBW24: W walk | ~340 | unchanged | – |
  | DB0: no key | – | unchanged | – |

  - One Source-style accelerate step fits all the cases. It raises v·wish toward **~280 u/s**, adding at most **~205 u/s**.
  - Only DBB pins the ~205 limit; every other case reaches 280.
  - The earlier "no redirect" result (DBD, DBS, DBR) came from the key being pressed on the same tick as the air jump, so it was not registered.
- **The air strafe caps at ~82 u/s.** The lateral speed from D before the air jump (DBL, DBL0) flattens at 80–87 u/s. This supports the provisional 80 u/s air wishspeed cap (G26).

## Taller mantles (Haze, box truck: cargo top ~162 u, cab roof ~94 u; marks truckA, truckB)

The scenarios are in `scenarios/mantle2/gen.py`. `B` names are the same inputs at the cab (truckB).
The helpers are `climb.py`, `ser.py` and `vz.py`; `driver/goto.py` teleports and faces a direction for scouting.
Heights are the camera rise, which matches the ledge height within a few u.

- **The climb is not one constant speed.** There are two phases, then the usual exit.
  - Phase A: 66 u, vz rises ~185 → 216. 94 u, ~225–229 flat after a one-tick spike. 162 u, ~430–450 decaying at about gravity to ~305.
  - Phase B is a flat HUD plateau: **215.6** (66 u), **236.3** (94 u), **256.0** (162 u).
  - Exit: ~176–177 u/s forward for ~9–11 ticks at all three heights. The speed is kept afterwards.
- **Climb-up time from a ground press at the face:** 66 u ~20 ticks, 94 u ~24 ticks (TJ050B/TJ060B, 2 trials each), 162 u ~32 ticks.
  - So the average climb speed rises with the height: ~211, ~249 and ~328 u/s.
  - A straight line fits all three within ~5 u/s: **v_avg ≈ 132 + 1.2·H u/s**.
  - Airborne presses at the cab (TJ040B) climb the remaining height with the same two plateaus and the same exit.
- **Reach:** 162 u mantles from a ground press, which is at the spec's 160 u top within measurement error. The true maximum is not measured.
- **Not repeatable at the truck** (TJ040 t2, TJ046 t1, TJ060): some presses at 162 u give a plain jump that slides up the face with no mantle.
  - One case had feet ~10 u up at contact (the ledge ~152 u above the feet). A successful one had them ~30 u up.
  - A ground press 2 ticks after contact also failed while 7 ticks after succeeded, so the cause is unclear. It is not modeled.
- **TJ030B:** a jump too early to reach the cab face lands short (apex ~54): no mantle, as expected.
- **Walking into the truck face (TW):** it slides along the face at ~104 u/s with no mantle, same as the crate.

## Stamina regen (fast stamina off; Haze, mark street_y148)

- **The setup was wrong.** `driver.py setup` sent `citadel_enable_fast_stamina`, a command that turns fast stamina on, and `citadel_rapid_stamina_regen` was also true at one point (every dash fired). `find stamina` in the console lists `citadel_disable_fast_stamina`. The setup now sends that and `citadel_rapid_stamina_regen false`. The earlier ~140-tick regen came from fast stamina.
- **A ground dash holds 635 u/s for ~40 ticks.** A press during that plateau reads as a dash to a "speed ≥ 600 soon after the press" check, so only presses made below dash speed count.
- **Scenarios** (`scenarios/stam0/gen.py`): SWnnn and SXnnn spend all 3 charges with dashes at 5/52/100, wait until tick nnn, then press dash 3 more times (24 or 47 ticks apart). SCR2_0 repeats SCR2 with fast stamina off. Each was recorded after ~10 s of rest.
- **Result: one charge every ~288 ticks (4.5 s), one at a time, timed from the first spend.** The first charge is back between 284 and 308 (5 + 288 = 293). The second is back between 567 and 614 (5 + 576 = 581).
  - SX380 and SW380–520: one charge by T, and none back by 474 or 568 after using it.
  - SX520: the press at 567 fails and 614 fires.
  - Later spends did not delay the timer.
- This matches the spec (4.5 s) and the sim (sequential progress from the first spend), so there is no model change.

## Mixed route R1 and the diagonal air jump (Haze, mark street_y148)

Route R1 (`scenarios/route/gen.py`) is 580 ticks of mixed input: walk, dash, S reversal, jump, S+D air jump, crouch, S dash.
Two trials, very consistent. `route/simrun.sh` replays it in the sim (`tools_fit/route_export.gd`), and `route/compare.py` prints
sim against game. The replay must start with sprint on (`start.sprint_on`), since the game has sprint from standstill.

- With the Haze hero and sprint on at the start, the sim matches these within ~15 u/s at every 10-tick sample:
  walk, dash, dash end, S reversal, ground jump, slide hop, crouch walk and S dash.
- **The one large gap is the S+D air jump:** 381 u/s horizontal in the game (HUD) against ~300 in the sim.
- The obstacle at ~(fwd −146, left −196) stopped the planned slide, and the ground behind the mark is uneven, so those parts are not compared.

**Camera slopes overstate air speed.** After an air jump, horizontal speed from camera-position slopes reads 4–13% above the HUD
(e.g. DGRWD 278 vs 246). On the ground they agree (DGGSD 386 vs 386). Air speeds below come from the HUD alone:
`double/hudfit.py` fits HUD² = h² + (vz0 − g·τ)² with g = 795 over the rise (rms 1–2 u/s).

Diagonal probes (`double/gen.py`: DGBSD/DGBSD0, DGBSA, DGWD, DGRWD, DGRSD, DGGSD). Two trials each, with the key held from 56 and the air jump at 66.
The table also refits the older 1-D cases.

| Case | Before: h, direction | Wish | After h (HUD) |
|---|---|---|---|
| DBRW | ~44, fwd | W | 239 |
| DGRWD | ~20–80, along the wish | W+D | 246 |
| DGRSD | ~50–90, along the wish | S+D | 236 |
| DBL | 341, fwd | D | 374 |
| DGWD | 338, fwd | W+D | 378 |
| DGBSA | ~335, back | S+A | 371 |
| DGBSD | 338, back | S+D | 396 |
| R1 | 310, back | S+D | 381 |
| DBW24 | 339, fwd | W | 328 (= DB0 no key, 329) |

- Ground S+D (DGGSD) is exactly 45° and reaches 386 u/s: the ground diagonal is normal.
- **Rule that fits:** when v·wish is below ~280, the air jump adds ~200 u/s along the wish. The horizontal speed is then capped
  at max(old speed, run speed ≈ 386). Otherwise nothing changes (DBW24).
  - From rest, this gives ~240. The old "raise v·wish to 280" came from camera slopes.
  - With speed, the result is at the run-speed cap (371–396).
- The camera directions after the jump are about 11–19° off the old velocity toward the wish. The rule predicts 17°.
- **Open:** S+D lands ~20 u/s above its mirror S+A (396 vs 371, two trials each). The cause is unknown.
- **Open:** earlier air accel values (~780 u/s²) came from camera slopes and may be a few % high.

## Air drag (HUD refit): none outside the air dash

HUD-only fits (`scenarios/double/hudfit.py`, g = 795 fixed) over consecutive windows of one airtime:

| Case | Windows (ticks) | Horizontal h |
|---|---|---|
| A0 (plain jump, no key) | 43–84 | 338.6 / 339.3 / 338.9 / 337.7 |
| DJ22 (dash jump) | 32–90 | 615 / 620 / 625 / 625 / 624.5 |
| A_air_b1 fast (fall after an air dash) | 54–60 / 60–66 | 489.2 / 488.5 |
| A_air_b2 fast (fall after an air dash) | 54–60 / 60–66 | 482.8 / 481.0 |

- Horizontal speed in the air does not decay. The earlier 0.2/s (G08) and the camera-slope readings of decay were wrong:
  camera slopes overstate air speed and drift.
- During the air dash itself (gravity off, HUD = horizontal speed) the speed does fall ~0.19 × speed per second
  (A_air_b1: 572 → 538 over 0.31 s). This is a property of the dash, not of air movement.
- DJ22's HUD-only h after launch is 615–625, below the 703 read earlier from HUD plus the camera height track. Recheck the
  dash-jump launch.
