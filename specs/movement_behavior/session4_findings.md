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
| Crouch pressed ~2 ticks after touchdown (DJC3) | ~6 ticks of ground friction first, then a slide from ~385 | Slides from ~530 |

- **Late part of DJC and DJC2:** the drop after ~0.65 s of slide is the end of the runway (~33 m), so the penalty onset is not measured here.
- **Open (DJC3):** the gap may be a crouch-to-slide delay on the ground, or the landing tick being off by ~2 ticks. It needs a ground test: run, then a crouch press.

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
- **Open:**
  - The airborne trigger window (MJ050 climbed with the jump pressed 12 ticks before contact).
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
  - **Jumped at slide tick 3 or 10:** the hero lands into a slide at ~380 / 353 that decays slowly (~0.15–0.19/s, landing-slide friction). The slide ends near tick 145 in both, which is ~65–68 ticks after landing and ~121 after S0, then it brakes.
  - So a late slide jump stores crouch like a ground jump does (G40), and an early one does not. The threshold lies between slide ticks 11 and 18.
- **Open:**
  - A non-dash (normal) slide jump.
  - Chained slide hops (the G09 second-hop penalty).
  - Whether the early/late threshold counts slide ticks or time since the dash.
