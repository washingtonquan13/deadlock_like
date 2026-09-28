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
