# Traversal (ziplines, ropes, jump pads, teleporters, heavy melee, parry, knockback, movement items) — behavioral model

Research date: 2026-09-27. Latest patch checked: 2026-09-16. Units: hammer units (u), 1 u = 0.0254 m (per main spec). All sources public (deadlock.wiki incl. its merged movement-wiki "Universal Tech" pages, official forum changelogs and bug threads, community guides). Paraphrased.

Important source note: the community Deadlock Movement Wiki (dlmovement.wiki) now redirects into deadlock.wiki (`Portal:Movement`). Its tech pages (Zipline Momentum Conservation, Zip Dash, Small Zip Jump, Zip Launch, Heavy Melee, Heavy Melee Cancel, etc.) are written by movement players and contain datamined-looking numbers (u/s, ticks, drag coefficients). These are the best non-client source available and should be treated as "community, medium-high" unless an official note confirms.

## How it works (plain language, as a movement player would explain it)

- **Ziplines are a momentum source, not just transport.** Riding speed is fixed (18 m/s inner, 21 m/s outer, +80% boosted). What matters to movement players is *how you leave*. Pressing crouch drops you and gives a buff that turns air drag OFF for ~2 s, so you keep the line's speed as a flat glide. Anything you do inside that 2 s (dash, wall jump, air jump) also benefits from zero drag, which is why "zip dash" goes much further than a normal air dash. Jumping off instead gives height but normal drag, so it bleeds speed. The "cake jump" / "small zip jump" is crouch-then-jump within ~0.14 s: you get the jump's height *and* keep the no-drag buff.
- **Attaching to a zipline refreshes your air jump and air dash**, so you can mount, drop and have a full air kit again.
- **Zip Launch** is a snap-velocity exploit: when you latch on, the game applies a very large velocity for one tick to pull you onto the line; crouching on exactly that tick keeps that velocity (1,300–5,900 u/s reported). Frame-perfect, unbufferable. Current status is UNCONFIRMED: no patch note mentions it, but the 2026-05-22 "smoothed zipline grabbing" change may have touched the snap, and the July 2026 forum bug report of very fast zipline launches describes jump-spam (mouse-wheel bind), not crouch-on-attach, so it cannot be treated as proof zip launch still works.
- **Heavy melee is a lunge with a hard stop.** Wind-up (you keep drifting on your existing velocity if airborne), then a lunge at ~750 u/s ground / ~797 u/s air peak, then a recovery phase that zeroes *all* velocity (horizontal and vertical). So heavy melee is not a momentum tool by itself: it's a short, stamina-free burst that ends dead-stopped. Its movement uses are (a) reaching a ledge to mantle, (b) +distance with Melee Charge, (c) Heavy Melee Cancel — activating certain instant items (Fleetfoot, Restorative Locket, etc.) during the lunge skips the recovery and keeps some lunge speed (heavily nerfed 2025-04-17).
- **Airborne heavy melee also adds wall-jump fatigue**, and there's an open bug (June 2026) where a mid-air heavy into a wall sometimes makes the next wall jump behave as if you never touched ground.
- **Parry roots you** (you parry "on the spot"). Since 2026-09-16 parrying during a regular dash cancels the dash *and its momentum*. Ground-dash parry was allowed 2026-04-10.
- **Jump pads set a launch** toward a marked landing spot; you can air-strafe during flight. Getting hit in the first 0.9 s (current; was 0.6 s) stuns you, you continue on the arc with no control, stun ends 0.2 s after landing, then 30% slow for 2 s, plus 15% max HP damage.
- **Ropes**: grab with the jump/zipline key, climb. Climb is 40% slower for 4 s after hero damage (tapering to 0 over the last second); melee hits while climbing slow 80%→20% over 2 s.
- **Teleporters**: 4 s channel, then +3 m/s move speed for 5 s on arrival (buff value set 2024-10-10).
- **Knockback / pulls / knockups** are all "Displace" effects. Knockup durations respect debuff reduction (since 2026-05-22). Some items explicitly wipe momentum (Knockdown: removes all momentum, straight down). Warp Stone kills all prior velocity. There is no public generic knockback formula.
- **Movement items change mechanics, not just stats**: Stamina Mastery adds a second air jump/air dash per airtime and +23% air jump/dash distance; Majestic Leap is a 1063 u/s launch with 100% air control; Magic Carpet has -15% gravity and +25% air control; Melee Charge +50% heavy melee distance (implemented as faster lunge).

## Rules (numbered, precise, implementable)

### Ziplines
1. **Attach**: hold/press jump (the "zipline" bind, default Space) near the line while airborne; the game snaps you to the line with a very high one-tick velocity. Attach is blocked for 3 s after taking damage from an enemy hero or enemy objective (not neutrals, not troopers). [E1]
2. **On attach**: air jump and air dash counters refresh; sprint resets (main spec). Travel direction can be chosen by movement input on attach (2025-04-04, main spec).
3. **Riding speed** is fixed: 18 m/s inner, 21 m/s outer, independent of hero speed; ×1.8 with Zipline Boost (32 s, 360 s CD, available from 6:00) or express line (after base guardian death); movement powerup +40–80% (scales 5→40 min). [E1][E12]
4. **Knockoff**: enemy hero damage during the first 3 s of riding (or while attaching) → fall straight down (all momentum removed), 15% max HP damage (spirit-resistable), stun 2.5 s starting on landing. DoT sources excluded. After 3 continuous seconds: immune to knockoff but take +53.6% extra damage. [E1][E14]
5. **Crouch dismount** (duck key): leave the line keeping full line velocity as your air velocity. Apply buff: air drag coefficient 0 for 2 s, then 0.25 (vs normal 0.2) — the wiki words this as "5% extra air drag" afterward. Duration of the elevated 0.25 not published. Costs 0 stamina. Fully actionable in air (abilities, dash, air jump, wall jump). [E2][E3]
   - ZMC can also be triggered by pressing crouch at any point during the *ascent to* the line while holding jump to latch (you never actually ride). [E2]
6. **Jump dismount** (press jump while riding): regular jump off the line; per community guides it gives height but normal air drag, so it bleeds speed faster than a crouch drop. Exact vertical impulse and whether line velocity is fully kept: not published. [E4][E6]
7. **Small Zip Jump / Cake Jump**: after a crouch dismount, a jump input within 0.14 s (9 ticks at 64 Hz) performs a regular jump while keeping the crouch-dismount no-drag buff and your air jump/air dash. It's a ground-style jump "from thin air" (it does not consume the air jump). [E4][E5] Sourcing note: the 0.14 s / 9-tick window and "keeps no-drag" come from the wiki page [E4]; the "air jump/dash retained" part comes only from the single Cake Jump forum post (with video, 0 replies) [E5] — the wiki page does not state it. Confidence medium-low on the retention part.
8. **Zip Dash**: an air dash / strafe dash during the no-drag window goes farther and faster because (a) air drag is off and (b) the usual end-of-dash slowdown is removed. With Stamina Mastery you can chain two. Wall jumps in the window also benefit. [E3]
9. **Zip Launch**: on the exact tick of attachment (before the riding animation), a crouch dismount keeps the snap velocity; 1,300–5,900 u/s depending on approach angle (best perpendicular to bends, near line ends). One tick, cannot be buffered. [E7] Current-patch status: unconfirmed (medium-low). The 2026-07-10 forum report [E8] is about jump-bind spam producing fast launches, not the crouch-on-attach tick; treat it as a *related* snap-velocity bug, not confirmation. The 2026-05-22 grab smoothing [E16] may have changed the snap.
10. **Early-ride dismount lockout: do NOT implement for standard mode.** The only source is the 2026-06-30 note, which sits under the *Street Brawl* heading ("No longer locks you out of getting off the zipline in the first few seconds"). Street Brawl has its own zipline rules (20 s zipline cooldown at round start per wiki Street_Brawl), so the lockout was most likely a Street-Brawl-specific artifact. No wiki page, guide or patch note describes such a lockout in standard mode, and ZMC-during-ascent tech (rule 5) implies you can drop immediately. [E15][E41] (Previously this spec inferred a standard-mode lockout; that inference is withdrawn.)
11. Rope and zipline share a key bind since 2026-05-22; grab smoothed to fix jitter. [E16]

### Ropes
12. Grab with jump (zipline bind). Climb speed not published. [E9][E16]
13. Hero damage in last 4 s → climb 40% slower, tapering to 0% during the final second. [E9][E13]
14. Melee hit while climbing → 80% slow ramping to 20% over 2 s. [E9]
15. Dismount/exit momentum, whether rope refreshes air jump/dash: not documented.

### Jump pads
16. Launch in a fixed direction toward a marked landing point; air strafe allowed during flight (look + move). Launch velocity for map pads not published. Holliday's Bounce Pad (reference for a pad): 900 u/s vertical, 750 u/s horizontal if any horizontal input; air drag stays 0.2. [E10][E11]
17. Vulnerable window after launch: **0.9 s** (2025-11-21; was 0.6 s from 2025-10-24). Hit → stunned, keep ballistic arc to destination with no control; stun ends 0.2 s after landing; then 30% slow for 2 s; 15% max HP damage (2025-12-16). DoT excluded. [E10][E17][E18][E19]

### Teleporters
18. 4 s channel; on arrival +3 m/s move speed for 5 s (since 2024-10-10; 2025-05-08 only made teleporters available from match start). Available from match start. Urn carrier cannot use. Exit velocity otherwise: not documented. Sprint persists through teleporters (main spec). [E20]

### Heavy melee
19. **Phases**: wind-up 0.36 s → lunge up to 0.6 s → recovery 0.2833 s (total ≈1.25 s). Cooldown 1.0 s on hit, 1.3 s on miss (2025-07-29). Stamina cost 0. [E21][E13]
20. **Wind-up**: if airborne, keep current velocity (gravity presumably applies). Turn rate reduced (further reduced 2025-07-29).
21. **Lunge**: peak speed 750 u/s grounded, 797 u/s airborne *from a standstill* (the wiki labels the air figures "stationary air"; how pre-existing air velocity combines with the lunge is not stated). Direction: facing, vertical steering limited to about ±5°; total turn limited (~300° reported). Melee Charge (+50% distance; enhanced +80%) → 1,125 / 1,195 u/s; Crushing Fists → 1,200 / 1,275 u/s. The 1.5× ratio *suggests* the distance bonus is applied as a lunge speed multiplier with the same duration (our inference, not stated by any source). [E21][E22]
22. **Recovery**: sets velocity to zero on all axes (ground and air). [E21][E24]
23. Lunge into a ledge → mantle. [E23]
24. Airborne heavy melee adds wall-jump fatigue. [E24] Confidence low-medium: only the wiki movement-sandbox page says this; the 2026-06-02 forum bug report only says the wall bounce after landing sometimes acts as if ground was never touched (about half the time, no dev reply). Do not build a fatigue rule from the bug report.
25. **Heavy Melee Cancel (HMC)**: activating Fleetfoot, Restorative Locket, Fury Trance, Colossus, Unstoppable, or Vampiric Burst during the lunge cancels recovery and keeps the velocity from the moment of activation ("True HMC", fully actionable). Some hero abilities cancel but lock actions ("False HMC": Dynamo Singularity, Ivy Stone Form, Kelvin Ice Path); Kelvin Frozen Shelter is the only listed true ability cancel (corrected 2026-09-27: Ice Path is listed as False on the wiki). Best at the end of the lunge. Momentum kept was "significantly reduced" on 2025-04-17 (amount not published). Abilities stopped cancelling in Nov 2024; Kinetic Carbine no longer cancels. [E25][E26][E27]
26. **HMC Extension**: keep holding melee through the cancel → a second heavy starts immediately (≈ double lunge distance). [E28]

### Light melee / parry
27. Light melee: instant; applies a short self-slow. Since 2026-09-16 it no longer pauses the gun cycle. [E29][E31]
28. Parry: 1 s animation, parries during first 0.75 s; movement generally locked (you parry in place). 0.3 s lockout after success. Parry during a regular dash cancels the dash and its momentum (2026-09-16). Ground-dash parry permitted (2026-04-10, worded as bringing it "in-line with air dashing", so air-dash parry was already allowed before). Air-dash parry is described by community (2025-09) as propelling you while parrying at the cost of 1 stamina. Unclear whether the 09-16 change covers air dashes (note says "regular dash", which most likely means the base dash as opposed to ability dashes, and would then include air dash — unverified). Secondary press coverage of 09-16 mentions parry-dashing on an air vent now sends you straight up; this line was not found in the official-notes mirror (low confidence). [E29][E30][E31][E42]
29. Melee hit on a mantling enemy → 80%→20% slow over 2 s; mantle-slide right after that is blocked (2025-11-21). [E29][E17]

### Knockback / displacement
30. Displace = pull / knockup / knockback; changes the target's movement direction and acceleration. No generic formula published. Knockup duration is reduced by debuff reduction (2026-05-22). [E32][E16]
31. Knockdown (item): removes all momentum and brings the target straight down (2025-04-17). Zipline knockoff also straight down. [E26][E14]
32. Slows (since 2026-09-16) add air drag equal to 35% of the slow value; Slowing Hex disables some knockback movement (Shiv alt fire, 2026-06-30). [E31][E15]

### Movement items (mechanic-changing)
33. **Stamina Mastery**: +1 air jump or air dash use per airtime (i.e. two air actions), +2 stamina, +18% stamina recovery, +23% air jump/dash distance (was 30%/20% before 2026-01-30). [E33]
34. **Majestic Leap**: launch up/out peak 1,063 u/s, min angle 30°, 100% air control; after ~1 s you can steer descent at any angle under 45°; landing clamps speed to ~500 u/s unless you jump or dash before landing (Majestic Leap Cancel: an air jump during descent keeps momentum and does not remove leap state). +50% air control for barrier duration (2026-05-22). CD 45 s; 5 s lockout after enemy hero damage. [E34][E35]
35. **Warp Stone**: teleport zeroes all prior velocity; you're actionable after, so an air dash gets its full distance; a dash-jump input in the dash-jump window after warping jumps in the *original* dash direction. [E36]
36. **Magic Carpet**: -15% gravity, +25% air control (2026-05-22). [E16]
37. **Rescue Beam**: pull is fastest at start and decelerates; faster the farther the target; cancelling right after the pull starts "slingshots" the ally. [E37]
38. Fleetfoot: move speed (3.25→3 in-game, 2025-12-16), +6% weapon damage, 40% active slow resist (2026-05-22); also a True HMC item. [E18][E16]

## Momentum: what conserves, adds, sets, caps, or decays speed

| Event | Horizontal | Vertical | Drag / other | Source conf. |
|---|---|---|---|---|
| Zipline attach | SET to snap velocity (1 tick, very high), then SET to rail speed | SET (rail) | Air jump/dash refreshed | high (refresh), medium (snap) |
| Riding | SET = 18/21 m/s × boosts | follows rail | — | high |
| Crouch dismount | CONSERVE rail velocity | CONSERVE | Air drag 0 for 2 s, then 0.25 (normal 0.2) | medium-high (community wiki) |
| Jump dismount | conserve (assumed) | ADD jump impulse (value unknown) | normal drag | low-medium |
| Cake / small zip jump (jump ≤0.14 s after crouch drop) | CONSERVE | ADD regular jump | keeps 0-drag buff; air jump not consumed | medium |
| Zip dash | ADD dash; no end-of-dash slowdown | — | 0 drag | medium |
| Zip launch (crouch on attach tick) | CONSERVE snap velocity (1.3k–5.9k u/s) | — | 0 drag buff presumably (inference) | medium (mechanism); low-medium (still in current patch) |
| Zipline knockoff | SET 0 | fall straight down | stun 2.5 s on landing | high (official) |
| Jump pad | SET launch vector | SET | strafe allowed; stunned = no control, arc continues | high qualitative, no numbers for map pads |
| Holliday pad | SET 750 (if input) | SET 900 u/s | drag 0.2; 100% air control on first use (Holliday + allies) | medium |
| Teleporter exit | unknown | — | +3 m/s move speed 5 s | high |
| Heavy melee wind-up (air) | CONSERVE | CONSERVE (+gravity presumably) | reduced turn | medium |
| Heavy melee lunge | SET toward aim, peak 750 ground / 797 air (air figure measured from standstill) | ±5° steer | 0 stamina; ×1.5 speed with Melee Charge (inferred mechanism) | medium-high (numbers), low (moving-air interaction) |
| Heavy melee recovery | SET 0 | SET 0 | 0.2833 s | medium-high |
| HMC (item during lunge) | CONSERVE current lunge velocity (reduced 2025-04-17 — exact rule unknown) | — | recovery skipped | medium qualitative |
| Parry during dash | SET 0 (cancels dash momentum) | — | since 2026-09-16 | high (official, ground dash); medium (air dash coverage) |
| Knockdown item | SET 0 | straight down | — | high (official) |
| Warp Stone | SET 0 | SET 0 | then actionable | medium |
| Majestic Leap | SET 1,063 u/s up/out | — | 100% air control; landing CAP ~500 u/s unless jump/dash | medium |
| Slows | cap move speed | — | +35% of slow value to air drag | high |

## Known tech that depends on these rules

| Tech | Inputs | Why it works |
|---|---|---|
| Zipline Momentum Conservation (ZMC) | Ride (or hold jump to latch) → crouch | Crouch dismount keeps rail velocity and zeroes air drag for 2 s |
| Zip Dash | ZMC → (strafe) air dash | 0 drag + no end-of-dash decel; air dash refreshed by attach |
| Small Zip Jump / Cake Jump | ZMC → jump within 0.14 s | Grounded-style jump that keeps the no-drag buff and the air jump |
| Zip Launch | Jump → attach → crouch on the attach tick | Keeps the one-tick snap velocity |
| Rollout chain | ZMC → dash → wall jump → air jump | Everything inside the no-drag window; wall jumps also benefit |
| Heavy Melee Cancel | Heavy → item (Fleetfoot etc.) at end of lunge | Skips the zero-velocity recovery |
| HMC Extension | HMC while holding melee | Immediately starts a second lunge |
| Heavy-melee mantle | Heavy toward ledge in air | Lunge reaches mantle range; costs no stamina |
| Hidden Melee | Ability → buffered heavy | Ability animation hides wind-up (parry bait, not movement) |
| Majestic Leap Cancel | Leap → descend → air jump | Jump before landing avoids the ~500 u/s landing clamp |
| Warp Dash / Warp Dash Jump | (Dash →) Warp Stone → air dash / jump in DJ window | Warp zeroes velocity so dash is full; DJ direction from original dash |
| Rescue Beam Slingshot | Beam pull → cancel immediately | Pull speed highest at start |
| Holliday pad wall tech | Pad on wall, no input, wall jump + pad | Stacks wall jump with pad impulse |

## Patch history affecting this (dated)

- 2024-11 (approx): Heavy melee can no longer be cancelled by (most) abilities, only items. [E27]
- 2025-02-25: 3-lane map; outer ziplines +15% speed. Movement powerup placement moved.
- 2025-04-04: outer-lane teleporters removed; zipline travel direction selectable on attach.
- 2025-04-17: Heavy Melee Cancel momentum significantly reduced; Knockdown removes all momentum; parry no longer works on troopers. [E26]
- 2024-10-10: teleporter exit buff set to +3 m/s for 5 s. [E20]
- 2025-05-08: teleporters available from start (previously 8:00); movement powerup scales from 5 min, min sprint 2→1.5 m.
- 2025-07-29: zipline knockoff straight down, stun starts on landing, 3→2.5 s; rope climb 40% slower for 4 s after player damage; heavy melee CD 0.9→1.0 s (miss 1.3 s); reduced turn during heavy; parry stun ignores debuff resist; parry amp 35% melee → 30% all; some jump pads and Walker teleporters removed. [E13]
- 2025-09-16: Cake Jump posted (community). [E5]
- 2025-10-24: jump pad 0.6 s vulnerable window with stun/slow. [E19]
- 2025-11-21: jump pad window 0.6→0.9 s; mantle-slide blocked after mantle-melee slow; movement powerup stamina min 1→2. [E17]
- 2025-12-16: jump pad hit deals 15% max HP; Fleetfoot, Majestic Leap (CD 34→45 s) etc. nerfed. [E18]
- 2026-01-30: Stamina Mastery air jump/dash distance 30→23%. [E33]
- 2026-03-06: dash jump +30% air control 0.25 s; can jump from slide. [E38]
- 2026-04-10: parry allowed during ground dash; anti-mash change (main spec).
- 2026-05-22: ropes share zipline bind; zipline grab smoothed; knockup affected by debuff reduction; Magic Carpet -15% gravity/+25% air control; Majestic Leap +50% air control; sliding no longer resets sprint; wall jump reduces stamina regen 25% for 5 s; Melee Charge CD 7→5 s. [E16]
- 2026-06-02: bug report — wall jump inconsistent after mid-air heavy melee. [E24]
- 2026-06-30: **Dash jump window 0.2→0.25 s (0.30–0.55 s), distance 18→19 m, vertical impulse 400→425**; Street Brawl: no early zipline dismount lockout; more jump pads removed. [E15]
- 2026-07-10: "launching very fast" zipline bug report via jump-bind (mouse wheel) spam; not the same inputs as Zip Launch; no dev reply visible. [E8]
- 2026-09-16: parry during regular dash cancels dash and momentum; slows add air drag; light melee/dash no longer pause gun cycle. [E31]

## Contradictions / uncertainties (and what recording would settle them)

1. **Jump pad vulnerable window 0.6 vs 0.9 s.** Main spec says 0.6 s; official 2025-11-21 notes raised it to 0.9 s, and the wiki page body says 0.9 s. Treat 0.9 s as current (high). Record: jump pad, have a bot/ally hit you at timed offsets.
2. **Standard-mode zipline dismount lockout — RESOLVED as "no evidence; do not implement".** The 2026-06-30 line is under the Street Brawl heading and Street Brawl has its own zipline start rules. No standard-mode source mentions a lockout; ZMC-on-ascent contradicts one. Optional recording check: attach and crouch immediately in a normal match.
3. **Air drag after ZMC.** Wiki: 0 for 2 s then 0.25 "after". Whether 0.25 persists until landing, or decays back to 0.2, is unstated. Record `cl_showpos` speed after a crouch drop for 5+ s from a high line.
4. **Jump dismount**: vertical impulse, whether it keeps full line speed, whether it consumes the air jump. Record side-by-side crouch vs jump vs cake jump from the same point.
5. **Heavy melee lunge distance.** Wiki gives only peak speeds and "about half a dash". 750 u/s × 0.6 s = 450 u (11.4 m) if constant, which contradicts "half a dash"; so the lunge must have a speed curve (ramp/decay) or end early. The main spec's "~5 m" is still unverified. Record position per frame through a heavy on flat ground, grounded and airborne.
6. **What HMC keeps after the 2025-04-17 nerf** (a scale factor? a cap? a decay?). Record lunge-end speed vs speed 0.2 s after Fleetfoot cancel.
7. **Parry during air dash** after 2026-09-16 (note says "regular dash"). Record air dash → parry.
8. **Zip Launch** is still reproducible (July 2026) but many consider it a bug. Decide as a design choice whether to reproduce the snap-velocity exploit; if you do, implement the attach as a 1-tick snap velocity rather than a teleport.
9. **Jump pad refresh**: whether pads refresh air jump/dash, and map-pad launch velocities. Record.
10. **Unit inconsistency**: wiki Crouch Gliding says 10 m/s = 376 u/s (implies 1 u ≈ 0.0266 m), others use 350 u/s = 8.9 m/s (1 u = 0.0254 m). Likely a wiki typo; low impact.
11. **Wall jump stamina regen penalty — RESOLVED.** 2026-05-22 official notes: stamina regen −25% for 5 s after a wall jump; it "does not trigger when out of combat or when mantling soon after". So both readings are right: in-combat only, and mantling shortly after suppresses it.
12. **Jump pad update-history artifact.** The wiki Jump_pad history row for 2025-10-24 says the window was "reduced from 0.9s to 0.6s", but the official 2025-10-24 notes only *introduce* a 0.6 s window, and 2025-11-21 raised it 0.6→0.9. Current 0.9 s stands (high); ignore the wiki row.
13. **Zip Launch current status** (see rule 9). Record: attempt crouch-on-attach tick on current build equivalent footage (YouTube clips dated after 2026-05-22) or skip the exploit.

## Evidence (numbered)

- E1. https://deadlock.wiki/Ziplines — wiki, 2025–26. Speeds 18/21 m/s; boost; express; powerup; 3 s attach lockout; knockoff 15% HP/2.5 s/straight down; immunity after 3 s + 53.6%; crouch drop keeps momentum 2 s; refresh air dash/double jump.
- E2. https://deadlock.wiki/Ziplines/Zipline_Momentum_Conservation (ex dlmovement.wiki) — community movement wiki. Crouch dismount disables air drag; drag 0.2 → 0 → 0.25 after 2 s; can crouch during ascent to line; 0 stamina.
- E3. https://deadlock.wiki/Ziplines/Zip_Dash — community wiki. No drag, no end-of-dash slowdown; 2 dashes with Stamina Mastery; wall jumps benefit.
- E4. https://deadlock.wiki/Ziplines/Small_Zip_Jump — community wiki. Jump within 0.14 s (9 ticks) of crouch dismount.
- E5. https://forums.playdeadlock.com/threads/cake-jump-a-zipline-tech.82472/ — official forum, 2025-09-16. Crouch then immediately jump keeps low-resistance state and air dash/jump.
- E6. https://boostroom.com/blog/advanced-deadlock-zipline-travel-faster-rotations-and-safer-routes and https://games.gg/deadlock/guides/deadlock-movement-guide/ — community guides, 2026. Jump dismount gives height but bleeds speed vs crouch.
- E7. https://deadlock.wiki/Ziplines/Zip_Launch — community wiki. One-tick crouch on attach; 1,300–5,900 u/s.
- E8. https://forums.playdeadlock.com/threads/zipline-movement-bug-launching-people-very-fast.148968/ — official forum bug, 2026-07-10. Fast launches via jump spam still happen.
- E9. https://deadlock.wiki/Ropes — wiki, updated 2025-07-30. Grab with jump; 80→20% melee slow; 40% climb slow tapering.
- E10. https://deadlock.wiki/Jump_pad — wiki. Direction by wind, air strafe allowed, 0.9 s window, stun/slow/damage.
- E11. https://deadlock.wiki/Holliday/Movement — community wiki. Bounce pad 900 up / 750 horizontal u/s, drag 0.2, 100% air control first use.
- E12. https://deadlock.wiki/Runes — wiki, 2025-11-21 values. Movement powerup +40–80% zipline speed etc.
- E13. https://deadlock.wiki/Update:July_29,_2025 — official notes mirror. Zipline knockoff, rope debuff, heavy melee CD, parry changes.
- E14. (same as E1 + E13) knockoff straight down.
- E15. https://www.deadlockpatchnotes.com/patches/06-30-2026-update and https://deadlock.wiki/Update:June_30,_2026 — official notes mirror, 2026-06-30. Dash jump window 0.2→0.25 s (0.3–0.55), 18→19 m, vertical 400→425; Street Brawl zipline dismount lockout removed; Slowing Hex disables Shiv knockback movement.
- E16. https://deadlock.wiki/Update:May_22,_2026 — official notes mirror, 2026-05-22. Rope bind, zipline grab smoothing, knockup vs debuff reduction, Magic Carpet, Majestic Leap air control, slide no longer resets sprint, wall jump regen penalty.
- E17. https://forums.playdeadlock.com/threads/11-21-2025-update.90383/ — official, 2025-11-21. Jump pad 0.6→0.9 s; mantle-slide after mantle-melee slow blocked.
- E18. https://deadlock.wiki/Update:December_16,_2025 — official mirror. Jump pad 15% HP; Fleetfoot, Majestic Leap nerfs.
- E19. https://deadlock.wiki/Jump_Pad/Update_history — wiki, 2025-10-24 entry. Stun mechanics, continue toward destination.
- E20. https://deadlock.wiki/Teleporter — wiki. 4 s channel, +3 m/s 5 s, history.
- E21. https://deadlock.wiki/Heavy_Melee — community wiki. 0.36/0.6/0.2833 s phases; 750/797 u/s; Melee Charge/Crushing Fists speeds; recovery zeroes momentum; ±5° vertical.
- E22. https://deadlock.wiki/Melee_Charge — wiki. +50% (+80% enhanced) heavy melee distance; traversal use.
- E23. https://deadlock.wiki/Melee_Attack — wiki. Half-a-dash lunge, air heavy, mantle, parry timings, cooldowns.
- E24. https://forums.playdeadlock.com/threads/wall-jumping-is-inconsistent-after-mid-air-heavy-melee.139772/ — official forum bug, 2026-06-02; plus wiki Mechanics/Movement sandbox (airborne heavy incurs fatigue, momentum cancelled in air).
- E25. https://deadlock.wiki/Heavy_Melee/Heavy_Melee_Cancel — community wiki. Cancel items/abilities, keeps momentum at activation, nerfed 2025-04-17.
- E26. https://deadlock.wiki/Update:April_17,_2025 — official mirror. HMC momentum reduced; Knockdown removes momentum.
- E27. https://forums.playdeadlock.com/threads/consistent-heavy-melee-cancelling-with-fleetfoot.92010/ — official forum, 2025-11-30. Fleetfoot cancel still works; Carbine no longer cancels.
- E28. https://deadlock.wiki/Heavy_Melee/Heavy_Melee_Cancel_Extension — community wiki.
- E29. https://deadlock.wiki/Melee_Attack — (as E23) light melee slow; parry 1 s / 0.75 s / 0.3 s lockout.
- E30. https://danielhaynes.co.uk/deadlock-the-parry-mechanic — community analysis. Movement locked during parry; air-dash parry propels.
- E31. https://deadlock.wiki/Update:September_16,_2026 — official mirror, 2026-09-16. Parry cancels dash momentum; slows add air drag; light melee no gun-cycle pause.
- E32. https://deadlock.wiki/Displace — wiki. Displace subtypes; no formula.
- E33. https://deadlock.wiki/Stamina_Mastery — wiki. Extra air jump/dash; +23% distance (2026-01-30).
- E34. https://deadlock.wiki/Majestic_Leap — wiki. 1,063 u/s, 100% air control, ~500 u/s landing clamp, 2026-05-22 +50% air control.
- E35. https://deadlock.wiki/Majestic_Leap_Cancel — community wiki.
- E36. https://deadlock.wiki/Warp_Dashing (and Warp_Dash_Jump) — community wiki. Warp kills all velocity.
- E37. https://deadlock.wiki/Rescue_Beam_Slingshot — community wiki.
- E38. https://deadlock.wiki/Update:March_6,_2026 — official mirror.
- E39. https://forums.playdeadlock.com/threads/instant-air-dash-iad-what-it-is-how-it-works-and-why-its-probably-a-bug.105874/ — official forum (community). Air dash disables gravity and air friction for a short time; jumping out of a grounded dash-slide applies heavy air drag.
- E40. https://deadlock.wiki/Portal:Movement and https://deadlock.wiki/Universal_Tech — index of community movement tech pages (dlmovement.wiki merged here).
- E41. https://deadlock.wiki/Street_Brawl — wiki. Ziplines have a modified 20 s cooldown on round start in Street Brawl; lists the 2026-06-30 dismount-lockout removal under Street Brawl.
- E42. https://www.pcgamesn.com/deadlock/update-comeback-mechanic-nerfs-september-2026 (via search summary) — press coverage of 2026-09-16; mentions air-vent parry-dash change. Not in the wiki mirror or tracklock.gg copy. Low.

## Verification log (2026-09-27)

Adversarial re-check of every rule/table row against re-fetched sources (deadlock.wiki pages and Update: mirrors, official forum threads, tracklock.gg patch copy, community guides).

**Confirmed (re-fetched, wording matches):**
- Zipline speeds 18/21 m/s, +80% boost (32 s / 360 s CD / from 6:00), express line 80%, powerup 40–80%; 3 s attach lockout (enemy heroes/objectives only); knockoff 15% max HP, 2.5 s stun starting on landing, straight down; immunity after 3 continuous s with 53.6% extra ("Hyperline") damage; air jump/dash refresh. (E1, E13)
- ZMC drag 0.2 → 0 → 0.25 after 2 s; 0 stamina; crouch during ascent works. (E2) Still community-only; persistence of 0.25 still unknown.
- Zip Dash (no drag, no end-of-dash slowdown, 2 dashes with Stamina Mastery, wall jumps benefit); Small Zip Jump 0.14 s / 9 ticks. (E3, E4; pages last edited 2026-06-19)
- Heavy melee 0.36 / ≤0.6 / 0.2833 s, 750/797 u/s, ±5°, ~300°, recovery zeroes all axes, CD 1.0/1.3 s, 0 stamina. (E21, page edited 2026-01-31; E13)
- Heavy Melee Cancel item list; momentum kept from activation; 2025-04-17 "significantly reduced"; Knockdown removes all momentum. (E25, E26)
- Parry 1 s / 0.75 s / 0.3 s lockout; 2026-09-16 dash parry cancels dash and momentum, parries on the spot; slows add air drag = 35% of slow value; move slows −20%, ground dash slows −10%. (E29, E31)
- Jump pad 0.6 s (2025-10-24) → 0.9 s (2025-11-21); stun until 0.2 s after landing, 30% slow 2 s, 15% max HP. (E17, E19)
- Ropes 40%/4 s tapering; melee on rope 80→20% over 2 s. 2026-05-22 rope/zipline shared bind and grab smoothing; knockup vs debuff reduction; Magic Carpet −15% gravity/+25% air control; Majestic Leap +50% air control. (E9, E16)
- Stamina Mastery +1 air jump/dash, +2 stamina, +18% regen, +23% distance (2026-01-30). Majestic Leap 1,063 u/s, 30°, <45° descent, ~500 u/s landing, 45 s CD, 5 s damage lockout. Warp Stone zeroes velocity; warp dash-jump goes in pre-warp dash direction. Holliday pad 900/750 u/s. Melee Charge +50% (+80% enhanced), CD 5 s.
- 2026-06-30 dash jump 0.2→0.25 s, 18→19 m, 400→425.

**Refuted / corrected:**
1. Standard-mode early zipline dismount lockout (rule 10): the only source is a Street-Brawl-section line; inference withdrawn, do not implement.
2. "Zip Launch still reproducible July 2026": the cited forum report is a jump-spam launch bug, not crouch-on-attach. Status downgraded to unconfirmed; 2026-05-22 grab smoothing may have changed it.
3. Kelvin Ice Path is a *False* HMC per the wiki, not true.
4. Teleporter +3 m/s / 5 s dates from 2024-10-10, not 2025-05.
5. Heavy-melee air speed 797 u/s is a from-standstill figure; "distance bonus = speed multiplier" relabelled as our inference.
6. Wall-jump regen penalty contradiction resolved from official text (in-combat only; mantling soon after suppresses it).
7. Air-dash parry predates 2026-04-10 (that note brings ground dash "in-line with air dashing").
8. Wiki Jump_pad history row claiming 0.9→0.6 on 2025-10-24 is a wiki artifact; official notes introduce 0.6.
9. Cake Jump "air jump not consumed" rests on one forum post (0 replies); wiki page does not state it.
10. Air-heavy wall-jump fatigue: not supported by the cited bug report; low-medium.

**Still uncertain (needs recording, public sources exhausted):** lunge speed curve / real distance (750 × 0.6 s ≠ "half a dash"); HMC momentum after the 2025-04-17 nerf; post-ZMC 0.25 drag duration; jump dismount impulse/speed retention; map jump-pad velocities and whether pads refresh air jump/dash; rope exit momentum; whether 2026-09-16 dash-parry cancel covers air dash; zip launch on current build; how a lunge combines with existing air velocity.

**Answer to "is recording still best?"** For the qualitative rules, public research is close to saturated: the community movement wiki (merged into deadlock.wiki) is where movement players publish, and its numbers were re-confirmed. Every remaining gap is a *numeric curve* or an *edge-case interaction* that no public source states, so a recording with `cl_showpos`-style speed readout is now the right next step. One small research step remains worthwhile before recording: search YouTube for movement clips dated after 2026-05-22 showing zip launch and air-dash parry, to decide whether those two are worth recording at all.
