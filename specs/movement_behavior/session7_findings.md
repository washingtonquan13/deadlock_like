# Session 7: ramp1 slides, the "teleporting" question, mantle height, strafe mult

This session recorded 9 scenarios on ramp1, the sandbox spawn ramp (Haze, sandbox, 3 trials each).
- Recordings: `tools/movement_capture/rec_auto/s7_ramp`.
- Scenarios and analysis scripts: `tools/movement_capture/scenarios/s7_*`.
- Method: as in session 6. One analyst fitted each topic, and an independent verifier re-derived it with its own
  scripts. Only verified results are listed. Topics the verifier did not confirm are under Still open.

## "Why are we still teleporting?" Nothing on ramp1 teleports (verified, high)

- **ramp1 is one smooth plane.** It looks like stairs but has no treads. The fit gives 26.2-26.4 deg, a 260 u
  horizontal run, a 127.7 u drop and 0.29 u rms. On the slope, camera |dz|/dh has a median of 0.491-0.495
  (tan 26.2 = 0.492).
- **The game does not snap during a trial.** Every flagged frame in all 9 clips x 3 trials is one of these:
  - frame timestamp jitter (dt 0.3-8 ms at normal travel);
  - an OCR digit flip that corrects itself on the next frame. Examples: RWALK t3 at 2.43-2.50 s, RBOT t1 at
    4.67-5.14 s, RSWtop t1 at about 4.0 s;
  - the crouch camera change (about -29 u on press, about +28 u over 0.2 s on release);
  - the dash camera lag. The camera barely moves for about 10 ticks, then catches up at 1000-1200 u/s. The same thing
    happens on flat ground, so it is game camera behavior and is not modelled.
- **The only real jumps are the capture driver's setpos calls.** `driver.py` `run_trial` does one setpos per trial
  (3 per scenario at 3 trials), and `driver.py mark` does two more when a mark is made. The mark setpos goes to the
  camera point, about 93 u from the hero, so on a ramp it can drop the hero onto the slope.
- **The sim does not snap either.** Three independent replays built ramp1 with `ArenaBuilder.add_ramp` (26.2-26.3
  deg). The results:
  - no position snaps;
  - the largest unexplained per-tick move is 3-5 u, which is the vertical part of ground-following motion;
  - edge kinks of 1.7-3.3 u where the capsule crosses the top or bottom edge mid-tick;
  - a 3.8-4.9 u step_down on the RJ landing.
- **The step-up code does not run on a walkable ramp.** `KinematicMover.move` only steps up after a steep
  (non-walkable) hit. `MoveEvents.TELEPORTED` is only emitted by the F4/F8 debug hop, so render interpolation is never
  skipped on a ramp.
- **Control:** the same check on `add_stairs` with 16 u risers does flag real snaps on every riser.
- **Rule for sim geometry:** model ramp1 and other stair-looking ramps with `add_ramp`, never `add_stairs`. No ramp1
  copy exists in `src/arena` today.
- **Minor edge-feel difference, not a bug:** at the top edge the sim drops down at once, while the game camera eases
  over about 5 ticks.

## HUD speed on slopes (verified)

- **Walking or running on a slope:** the HUD shows horizontal speed, and ground velocity has no vertical part. For
  RWALK the HUD reads 386 while the 3D speed is about 428. The sim does the same (vy = 0 on the ground).
- **Air:** the HUD is 3D |v|. For RJ in the air, the HUD reads 452 -> 542 while vh = 348 -> 331 and
  vz = -293 -> -401.
- **Sliding on a slope:** the HUD matches horizontal speed (median HUD - vh = 0 to +2 u/s), not 3D speed (HUD - 3D =
  -42 to -51). The game keeps slide velocity horizontal on the ground too.
- **In the game, entering a slope never costs speed in one tick.** RBOT HUD at the crouch: 385.8, 387.5, 389.2,
  392.6, rising. The current sim projects slide velocity onto the plane at slide entry and loses about cos^2(theta)
  in one tick: RBOT 385.8 -> 313, RDASH 635 -> 520, RUP 635 -> 510. The bottom "drop" is only a 3D-magnitude effect;
  horizontal speed is kept there. This is not applied yet (see Still open).

## Mantle max height (E, verified; lower bound only)

- **The game mantles a 162.0 u ledge from a ground press.** Recordings: rec_auto/mantle2, the truck cargo top. The
  mantling trials are TJ040 t1, TJ046 t2 and TJ050 t1/t2.
  - The camera rests at 162.2 on top and 0.2 at the start, with pitch constant.
  - The 164-166 u camera peaks overshoot at the climb exit; they are not ledge height.
  - A plain jump peaks at 54 u, so the 162 u rise is a mantle.
- **The old sim refused it.** The top band was 160 u, and `mantle_band_for_height` rejects roundi(h) > 160.
- **Change:** `mantle_band_tops_u` [64, 96, 128, 160] -> [64, 96, 128, 162]. 162 is a lower bound. The true maximum
  is unmeasured.
- About half the truck presses fail (a plain jump that slides up the face). That failure is still unexplained, as in
  session 4.

## Strafe run speed (F, verified; no change)

- **D-only or A-only ground running (s6_diag DRD/DRA)** rises at the Source rate: friction v/16 per tick plus
  25 u/s per tick. It reaches 330-336 u/s at the key release (tick ~174), with no plateau.
- **Recording lag:** the recordings lag the script by a constant ~3.5 ticks (jump 40 -> 43.5, air jump 66 -> 69.3,
  D release 170 -> ~174). Align on that before comparing.
- **Result:** strafe_mult is at least about 0.87 (336/386). 0.85 would cap at 328, below the game, so it is ruled out.
  `strafe_mult` stays 1.0.
- **Correction to the analyst:** the "sim lands 4 ticks early" in s6_diag is this recording lag, not physics.

## Topics with no data (verified)

- There are no LT440/LT460, SHH12/20/30/6F, NK1/NK2 or WJD/WJA recordings, and there is no `s7_open` set.
- `landing_slide_friction_speed` 11.43 (450 u/s), the G09 values (0.5 / 1.3 / 0.3125), the no-key air jump and the
  wall-jump tangential kick are unchanged.

## Still open

- **Slides on ramps (s7_ramp), not confirmed as proposed:**
  - Agreed by the analyst and the verifier: on the ground, slide velocity stays horizontal (v.y = 0, no plane
    projection, SLIDE motion ground-projected like GROUND/CROUCH), with a horizontal downhill accel g*tan(theta).
  - Disputed: the friction on the slope. The analyst proposed 0.1875/s for every kind. The verifier measured a
    normal-slide net accel of +405 u/s^2 at ~435 u/s against g*tan = 399, so friction is about 0, and a dash-slide net
    of +232 at ~690, so k_dash is about 0.24. The "1-4 %" replay matches came from runs that cannot tell these apart.
  - A second ramp angle is needed to separate the accel scale from the friction.
  - Uphill: RUP only shows that a crouch pressed while already moving uphill on the slope gets crouch/ground friction
    (about 5/s, then about 400 u/s^2 below 100, stops about 169-176 u up, no slide-back). A slide that reaches an
    upslope from the flat is unmeasured. The sim currently dash-slides up and over the ramp (ends 507 u out).
- **slide_entry_speed:** a crouch at HUD 333-335 on the flat top of ramp1 slides in the game, while the sim needs 350.
  A crouch-walk at 187 does not slide. A flat bracket at 300/320/340 is needed before this changes.
- **Crest dip and penalty timing on the slope:** a HUD dip of 390 -> 356 near the crest in RRUN/RJ. The slide
  penalty lands about 1.28 s after the crouch in RRUN, 0.76 s in RBOT and 1.06 s in RDASH. Unexplained.
- **Recording post-filter:** OCR digit flips pass the hampel filter (k = 4, window 3) while the HUD is steady, so raw
  plots show fake teleports. The filter should reject a position jump that the HUD speed does not support.
- **Sim camera:** CameraRig does not reset its boom on the F4/F8 hops, and it pulls the boom in at once on a hit. A
  crouched eye looking downhill could hit the slope behind and jump the camera. This is the likeliest visible snap in
  the sim, and it is untested.
- **E and F caps:** E needs ground-press mantles at 166, 170 and 174 u. F needs a D-only run of 150 ticks or more.
- **Diagonal landings:** DRWA/DRSA land 35-40 u/s faster than the game. This needs re-comparing with the 3.5-tick lag
  removed.
- **Still unrecorded:** LT440/LT460, SHH12/20/30/6F, NK1/NK2 and WJD/WJA.

# Session 7b (s7_open fits, verified)

Recordings: rec_auto/s7_open (SE*, LT*, SHH*, NK*, WJ*, FS*). Fit scripts: scenarios/s7b_fit_*; independent
verifier scripts: scenarios/s7b_verify_*. Sim replays: tools_fit/_out/s7b_*. The HUD lags the sim by ~4 ticks
(3.5-4.5 per trial; ~4.2 using tick = t*64 + 1); every comparison below is lag-aligned.

## Flat slide entry speed (G, verified; no change)

- A crouch press on flat ground slides only above 347.5-350.2 u/s at the last W tick (sim time). SE300-SE336 do
  not slide (up to 347.3-347.5), SE340/SE360 slide (350.2-350.7, 366.5-366.8). `slide_entry_speed` 350 u/s matches
  all 7 scenarios; W from rest only gives 344.0 / 347.5 / 350.8 per tick, so the value cannot be narrowed further.
- The "333-335 on the ramp1 top" from session 7 was the HUD read without the lag. Lag-corrected, RRUN/RJ press at
  346.9-349.0. The game speed keeps rising after the press (356-363 at +1 tick, ~378 at +3), so the crouch lands
  on the slope. The fix belongs to the ramp geometry (the ramp1 top edge is probably ~20 u closer than 141 u), not
  the threshold.

## Standing-slide penalty onset (G, verified; changed)

- A slide started by a crouch press on the ground hits the penalty 38.0-39.3 ticks after the press (SE340 x3,
  SE360 x3; slide friction slope 63-66 u/s^2 matches). The sim with the landing table (0.69 s) gave +44.3-44.5 and
  stopped ~0.085 s late.
- Change: new `slide_onset_table_ground` [0.60, 0.85, 1.10, 1.35] for slides entered from GROUND/CROUCH. Only the
  first entry is measured. Landing slides keep `slide_onset_table`.
- Verifier note: measured HUD-to-HUD, the landing onset looks like ~0.73 s (touchdown to knee 47.5-48.1 ticks, sim
  45.3). Not applied (see Still open).

## Landing-into-slide loss threshold (A, verified; changed)

- LT440-LT465: a landing into a normal slide loses one ground-friction tick (x0.936-0.945) at 439-461 u/s and none
  at 471-476. The verifier's longer descent fit brackets the threshold at 461-471.
- The old 450 threshold mismatched LT450 (sim lands at 457, no loss; the game loses at 449-458).
- Change: `landing_slide_friction_speed` 450 -> 466 u/s (bracket midpoint, about +-5).

## Chained slide-hop penalty (B, G09; verified with an adjusted size)

- Penalized at hop delays of 6, 12, 20 and 30 ticks after the first landing; not at 40 (window 0.47-0.63 s, so
  `slide_hop_min_time` 0.5 stays). Not after a dash-jump first jump (SHH6F), though that hop was at ~562 u/s, so it
  does not separate the flag rule from a speed limit.
- Size: after the extra drag fades (~26 ticks after takeoff), h is x0.652-0.655 of the drag-only value for delays
  6-20 and x0.659-0.661 for 30 (verifier, reference = HUD trend at the takeoff midpoint). The current box 1.3 x 20
  ticks gives 0.662; the analyst's 1.375 gives 0.646 (its game reference was taken a few ticks before takeoff and
  read 1-2.7 u/s high).
- Change: `slide_hop_penalty_drag` 1.3 -> 1.34 (integral ~0.419, plateau ~0.658). `slide_hop_penalty_time` stays
  0.3125.
- Shape: the extra drag decays (~1.4/s at ticks 2-8 to 0 by ~26); a box matches apex and landing within ~1%.

## No-key air jump (C, verified; no change)

- NK1: no horizontal movement at all. NK2: horizontal speed through the air jump is unchanged (position fit step
  -0.1 / +0.1 / +0.1 u/s; HUD apexes 339 -> 296 match the sim's 338.8 -> 295.8 with drag only). The sim rule (air
  jump adds along the previous tick's wish, nothing with no key) stands.

## Wall-jump tangential kick (D, verified; changed)

- The A/D kick is added on top of the tangent the held key already built in the air before the press (~45-55 u/s
  after ~4 ticks, kept x0.95). post - 0.95 * pre = 107 (analyst, sd 4) / 111 (verifier, sd 5) over 10 trials
  (s7 and s3 WJD/WJA); post rises with pre (corr 0.86).
- Session 3's 147 was the total launch tangent, so the sim counted the pre-strafe twice (launch ~190 vs the game's
  139-161). Change: `wall_jump_kick_tangent` 147 -> 107 u/s; the sim then launches at ~149-152 (game 149.5 pooled).
- Normal kick already matches (-262 to -272 vs sim -267.6).

## Strafe run speed (F, verified; no change)

- FSD/FSA (sideways only) and FSWA (diagonal) reach the same 385.8 u/s plateau as FSW along the same ramp-up
  (crossing 300 at 0.38-0.41 s, 380 at 0.78-0.80 s in every set). Position-derived plateaus 384.3-386.6 agree.
  `strafe_mult` 1.0 is measured; any value <= 0.87 would plateau at ~336. Session 7's "at least 0.87" came from
  runs that ended before the plateau.

## Mantle max height (E, no data)

- The recorder found no 170-190 u ledge, so nothing was recorded. The 162 u top band stays a lower bound.

## Still open (7b)

- Landing slide onset: HUD-to-HUD it looks like ~0.73 s, not 0.69 (session 4 took touchdown from camera z, ~1.5-2
  ticks late). Re-check with the full lslide set and a curb-aware replay before changing it.
- Slide onset bonus steps (0.85/1.10/1.35 standing) are unmeasured.
- Ramp1: re-fit the top edge from the HUD rise (probably ~120 u, not 141), then decide whether a crouch on the crest
  is a slope slide. Record RRUN from 20-40 u further back.
- slide_entry_speed can only be narrowed with a different ramp-up (walk key, diagonal or delayed W).
- G09: penalty at takeoff speeds above ~380 u/s is unmeasured; SHH30 is ~1% weaker than 6-20 (geometry or window
  edge); the takeoff-tick ratio (0.95 game vs 0.975 sim) is unresolved; a decaying drag would fit the in-flight shape
  better than the box.
- Wall-jump diagonals: the game gives ~0.88 of the single-key kick for W+A/S+A, the sim scales linearly (0.707).
  Record diagonals with the key pressed only on the jump tick, and at a non-world-aligned wall. BWJS/BWJ0 (45 deg)
  not replayed.
- NK2 air-jump apex comes 1-2 ticks later than the sim (vz ~531-542 vs 522); within the lag uncertainty.
- LSD12: sim touchdown is only ~1.3 ticks ahead of the HUD drop while the knee lags ~3.7 ticks; jump airtime may be
  ~2 ticks short there, or the lag is not a pure display delay.
- backpedal_mult (S only) unmeasured; needs an FSS run. Mantle max height needs ledges of 170-200 u, several trials
  per height.
