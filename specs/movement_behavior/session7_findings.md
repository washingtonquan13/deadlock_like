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
