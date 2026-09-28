# Session 6: diagonal air jump, slide-jump losses, high-entry air dash

This session made 27 new recordings (Haze, sandbox, 3 trials each, trials agree within a few u/s).
- Recordings: `tools/movement_capture/rec_auto/s6_{diag,diagverify,slidejump,airdash}`.
- Scenarios and analysis scripts: `tools/movement_capture/scenarios/s6_*`.
- Method: each gap was fitted by one analyst, then re-derived by an independent verifier with its own scripts. Only
  verified results are listed.
- All air fits pin vz0 or read h where vz = 0, such as the apex HUD minimum or an air dash with flat z. Air drag is
  fixed at 0.2/s.

## Air jump: diagonal add uses the unnormalized, world-axis-clamped key vector (verified, high)

- **The rule:**
  1. c = the previous tick's key vector in world space, unnormalized (length √2 on a diagonal), with each world
     horizontal axis clamped to [−1, 1].
  2. The add goes along c/|c|.
  3. It tops up toward run speed along that direction.
  4. The cap is 200·|c|.
- **Single keys are unaffected:** DRD, DRA, DBL and DBX match within 0.6 u/s and 0.1°.
- **Diagonals** are pulled toward the nearest world 45° line. The size of the pull depends on view yaw, which is why
  the rotation sign flips between yaws (+4° at 147.7, −4.5° at 102.7 and 12.8).
- **Air control and the ground wish stay normalized.** DGRWD/DGRSD before the jump sit exactly on the diagonal, and
  DGGSD reads −135.02°.
- **Out-of-sample check.** The verifier recorded W+D from rest at view yaws 135, 180 and 162 (new marks). Apex HUD in
  u/s, then heading:

  | Yaw | Game | Clamp rule | Normalized |
  |---|---|---|---|
  | 135 | 245.0, −45.00 | 244.5, −45.00 | 244.5 |
  | 180 | 317.2, −45.00 | 316.9, −45.00 | 244.5 |
  | 162 | 277.6, −40.73 | 277.2, −40.73 | 244.5, −45 |

- **Existing cases** (apex HUD, game vs rule):
  - DRWDY 289.1 vs 288.7
  - DRSA 288.8 vs 288.4
  - DRWA 253.1 vs 252.6
  - DBSA 333.0 vs 333.5
  - The DWA/DGWD mirror asymmetry (402 vs 382) is reproduced as 405 vs 388.
- **R1 route:** the ~28 u sideways gap at tick 220 closes to ~3 u.
- **Previous-tick wish confirmed:** in DRWDR the keys are released one tick before the air jump, and there is no add.
- **Replay consequence:** diagonal air-jump scenarios need `start.yaw_deg` equal to the game view yaw.

## Slides (verified)

- **Takeoff cuts are right as modelled.**
  - A dash-slide jump gives ×0.74–0.76 (SHJ3/10/19/40/60).
  - A normal-slide or landing-slide jump gives ×1.000 (NSJ48, NSJ52, SHH40 hop 2).
  - The session-4 "0.92" and "0.69" were fit artifacts.
- **Landing into a normal slide loses one ground-friction tick (×0.9375) below a speed threshold.**
  - Landings at 376–428 u/s give 0.944 on 8 landings of three jump kinds (SHJ3, SHJ10, NSJ48, SHH hop 1, LSD12,
    LSX16).
  - Landings at 466–572 give no loss (DJS1/3/7/7L, SLDJ, dj148 DJC).
  - LSD12 vs DJS7 differ only in S hold time, so the threshold is in speed, not jump kind. It is bracketed at 428–466
    and set to 450 (provisional).
  - Crouch timing does not matter (DJS7L).
  - The old 0.877 was a fit artifact.
- **G09 chained slide-hop penalty.**
  - It is real on a hop about 6 ticks after landing (SHH6): h drops to ~229 at the apex and ~214 at landing. There is
    no takeoff cut.
  - The extra drag decays: +1.5/s over ticks 4–12, +0.9 over 12–22, then about 0.
  - Its integral is ~0.42.
  - A box of +1.3/s for 20 ticks matches the apex and the landing.
  - It is absent at 0.63 s (SHH40).
  - Evidence is one speed and one timing, so this is provisional.
- **Unexplained, outside scope:** LSD26/LSB landing on the curb slope at 261 u/s slide and lose only ~3%.

## Air dash at high entry speed (verified, the end drag adjusted by the verifier)

- **Forward and angled entries are already right.** Game peaks for entries +189 to +673 are 604 / 646 / 688 / 732,
  and the sim is within +0.2 to +2.9. The 45° W+D cases confirm that v_perp is kept (E700WD 822 vs 824.5).
- **Back dashes against momentum:** the peak falls with slope 0.35–0.36 of |v_par0|, not 0.26.
  - E386S (−348) gives 434, where the old sim gave 464.
  - E700S (−641) gives 327, where the old sim gave 388.
  - The target stays continuous at 0.
- **End drag is not a fixed 480 floor.**
  - The drop over the end drag is min(0.75·(v − 480), 0.175·v).
  - Measured v_end → h: 565 → 490, 601 → 500, 627 → 512, 637 → 517, 672 → 545, 765 → 618, with vz pinned from g.
  - Settle rms over 10 cases goes from ~49 to ~3.
- **Unmeasured:** high entries for B2/B3 (Infernus, Abrams). Only their −60 back probes test the 0.35.

## Still open

- The landing-loss threshold between 428 and 466: dash-jump landings at ~440 and ~460 would narrow it.
- G09 penalty size at other hop speeds and timings.
- The first air-jump tick of an air dash after a dash jump, and the rest of the session-5 list: NK1/NK2, WJD/WJA,
  mantle max height, strafe mult.
