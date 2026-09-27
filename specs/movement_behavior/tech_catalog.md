# Tech catalog — behavioral model

> Clean-room record. Built only from public sources (official patch notes via forums.playdeadlock.com and wiki Update: mirrors, deadlock.wiki incl. its Movement Portal — the former dlmovement.wiki now redirects there — official forum threads, community guide sites, YouTube titles/authors). No game files or client inspection. Researched 2026-09-27; latest patch checked 2026-09-16.
>
> Important caveat on source quality: most numeric values below come from the **community Movement wiki** (deadlock.wiki Universal Tech subpages, written by movement players and last edited Jan–Sep 2026). They are community measurements or community-datamined values, not official. Official patch notes give *changes* (old → new), which are the most trustworthy anchors.

## How it works (plain language, as a movement player would explain it)

- Deadlock movement is a stamina economy layered on a Source-like controller. Stamina buys *bursts* (dash, air dash, air jump, dash-jump); everything else (jump, slide, first wall jump, mantle, zipline drops) is free. Good movement = getting as much distance as possible out of each stamina bar and never letting friction/drag eat your speed.
- **Ground dash** overwrites your velocity with a fixed dash speed, then slows back to walk speed at the end. It is the "start" of a chain, not a way to add to existing speed.
- **Dash-jump** (jump in the blue-flash window of a ground dash) also *sets* a fixed launch (≈611 u/s horizontal, 425 vertical impulse, ~19 m of travel). It ignores whatever speed you had — great to start a chain, pointless in the middle of one.
- **Air dash** is an *impulse* (adds to velocity) but the speed along the dash direction is capped (~700 u/s; ~900 with Stamina Mastery). So once you are fast, dashing straight forward adds little; dash at an angle (**strafe dash**) to add speed sideways that the cap does not see.
- At the end of an air dash, drag/gravity come back ("dash slowdown"). If you are touching the ground right as that happens and you are crouching, you convert the dash into an **air slide** that keeps the speed. That is **IAD** (jump + instant air dash), and why landing slides are the core of every chain.
- **Slides** have very low friction for ~0.75 s and then friction ramps up hard (late slide penalty). The trick is to jump out before the penalty (**slide hop / slide bunnyhop**) and land into a fresh slide. Slides that come from the air (landing, dash-jump, mantle glide, zipline drop) are "good" slides you can hop out of; slides that come from a *ground* dash are "bad": before 2026-03-06 you couldn't jump out; since then you can (one player reports heavy air drag afterwards — unconfirmed).
- **Air drag** is the hidden enemy: normal air drag coefficient is ~0.2; wall jumps and ground-dash-slide jumps apply extra drag; a crouch-drop from a zipline gives ~2 s of zero drag (ZMC), which is why zipline tech is the fastest movement in the game.
- **Wall jumps** set velocity to a fixed magnitude, with direction from the contact normal on your rounded capsule plus your WASD relative to the wall. At corners/edges the normal tilts, giving **corner boosts** (more vertical) and **edge boosts** (more horizontal). First one per airtime is free, then 0.5 stamina with vertical fatigue.
- **Mantle glide** (hold crouch through a mantle) spits you out at ~550 u/s for free; jumping as soon as you're actionable (**superglide**) carries it into the air, giving dash-jump-like travel for 0 stamina.
- **Heavy melee** lunges fast (750 u/s ground / 797 air) but its recovery zeroes your momentum; cancelling the recovery with an item/ability used to keep the speed (nerfed 2025-04-17).

## Rules (numbered, precise, implementable)

Units: u = hammer unit (1 in = 0.0254 m). Tick assumed 64 Hz (0.14 s = 9 ticks on the Small Zip Jump page is consistent with 64 Hz).

1. **Ground dash sets velocity.** On dash start, horizontal velocity := dash_speed(bucket) × input direction; any prior momentum is discarded. At dash end the hero decelerates to walk speed ("dash slowdown"). Buckets: 635 / 579 / 562 u/s peak; 0.62 / 0.68 / 0.72 s (bucket 3 was 0.70 s before 2026-07-28). [E5, E10, E52] High for "sets velocity" and times (official); medium for peak speeds (community). *Verified 2026-09-27:* the 2026-07-28 notes changed bucket-3 dash **time** only; they say nothing about speed. The earlier "~547 u/s now" figure was our own inference (assumed constant distance) and is removed — whether bucket-3 peak speed or distance changed is unknown. The Dashing wiki page (edited 2026-09-20) still lists 562 u/s / 0.70 s, i.e. it is stale on time.
2. **Air dash is additive but directionally capped.** On air dash, add impulse along dash direction d; then the component v·d is capped at ~700 u/s (~900 with Stamina Mastery). Perpendicular components are not capped. During the dash gravity and air drag are off; after a short delay they re-enable. [E3, E13, E5] Medium for ~700 base (community-derived cap; form of the clamp is inferred from "dot product" wording). Low–medium for ~900 with Stamina Mastery: Stamina Mastery's air-dash bonus was cut 30% → 23% on 2026-01-30 [E51]; the Strafe Dashing page (edited 2026-09-11) still says ~900 but gives no measurement date, so it may predate the nerf.
3. **Dash-jump window.** Jump pressed between t = 0.30 s and 0.55 s after ground-dash start (0.25 s window since 2026-06-30; was 0.20 s). UI: stamina quarter-circle flashes blue. Costs +1 stamina. [E20, E4] High.
4. **Dash-jump sets velocity.** Horizontal := ~611 u/s (prior momentum ignored); vertical impulse 425 (since 2026-06-30, was 400); total travel ~19 m (was 18 m). Grants +30% air control for 0.25 s (since 2026-03-06). [E4, E20, E21] High for 425/19 m/0.25 s (official); medium for 611 u/s (community, may predate 2026-06-30).
5. **Coyote dash-jump.** A dash-jump performed after running off a ledge during the window counts as a dash-jump, not an air action: air jump and wall jump availability are preserved. [E4] Medium.
6. **Dash-jump cancel.** Casting an ability during the dash-jump window cancels the dash-jump; a normal (free) jump can follow. Only fast-cast abilities with no self-slow give benefit. [E1] Medium.
7. **Dash slide.** Holding crouch during/after a ground dash cancels the dash into a slide at any time. Optimal release around when the blue window opens; sliding the full duration drops below walk speed. [E6] Medium.
8. **Short dash crouch cancel (SDCC).** A brief crouch tap during the ground dash ends the dash early (shortens it). [E7] Medium.
9. **Slide entry.** Crouch while grounded with horizontal speed > 350 u/s (8.9 m/s), or on any slope. Several technique pages instead quote 376 u/s ("10 m/s") as "the speed needed to slide". [E11, E14, E15] Conflict — see Uncertainties.
10. **Slide friction.** 0.1875 for the first 0.75 s; then ~3.1875 (dash slides) or 0.6875 (dash-jump slides; onset 1.0 s). Slide-distance items push onset later. [E11] Medium.
11. **Air slide vs ground slide.** Slides entered from the air (landing, dash-jump, air dash, down dash, mantle, wall jump, zipline) keep landing momentum and can be jumped/dashed out of. Slides entered from a ground dash cap momentum and (pre-2026-03-06, and still reported 2026-01-24) could not be jumped out of. After 2026-03-06 (official: "Can now jump during slide") you *can* jump out; one forum user (single post, 2026-04-12) reports very heavy air drag when you do. [E3, E16, E17, E21] Medium for the jump-out change (official); **Low** for the "heavy air drag" part (single report, no wiki page or patch note corroborates it).
12. **Slide bunnyhop flag.** A per-character flag enables slide hopping; set by Slide Conservation (slide storage) or Dash Jumping; Dash Sliding prevents it. Each slide after the first must last ≥ 0.5 s, otherwise a heavy speed penalty applies. Requires ≥ 376 u/s to keep sliding. [E14] Medium.
13. **Raw bunnyhop.** Jumping on the landing tick (jump held/buffered) keeps momentum; beats slide hopping only below ~900 u/s. Risk: a late press becomes an air jump. [E15] Medium. (Our inference, not a source claim:) implies ground friction applies on at least one grounded tick when you slide-hop and that some speed-dependent loss exists above ~900 u/s.
14. **Slide storage / crouch storage.** Holding crouch in the air → instant slide on landing even on normally unslideable geometry. Holding crouch before a launch → prevents sliding regardless of speed. [E11] Medium.
15. **Crouch.** Crouching below slide speed decelerates to crouch speed (4.75–4.8 m/s) almost instantly — used for sharp direction changes. [E22, E23] Medium.
16. **Crouch glide.** Rhythmic crouch presses above 376 u/s keep re-entering slides; spamming too fast is slower. [E15b] Low–medium.
17. **Instant Air Dash (IAD).** Jump then air dash as early as possible (near frame-perfect; too early = ground dash, too late = normal jump-dash). The dash ends while almost touching the ground, so the landing slide captures the dash speed before drag/end-slowdown. The "~20% faster than a normal air-dash-slide chain" figure is one forum author's estimate (E3). The IAD wiki page (edited 2026-09-11) is more qualified: **without items IAD is slower** than a regular dash, air dash or dash jump; it becomes much faster only with Stamina Mastery / vitality items plus slide bunnyhopping (double dash ~900 u/s peak, ≈ two dash jumps of distance). Do not hard-code a flat 20% gain. Community consensus leans "tech, not bug"; no dev response; not patched as of 2026-09-27. [E3, E8] Medium.
18. **Normal air drag.** Coefficient ~0.2 (form unknown, likely Source-style friction). Slows add 35% of their value as extra air drag (since 2026-09-16). [E12, E24] Medium (0.2 community) / High (35% official).
19. **Zipline Momentum Conservation (ZMC).** Crouch-dismount from a zipline → air drag coefficient 0 for 2 s, then 0.25 (i.e., slightly worse than normal 0.2). Momentum along the line is kept. [E12] Medium. Official: dismount momentum "reduced slightly" 2025-05-08 [E25].
20. **Small Zip Jump.** After crouch-dismount, a ground-style jump is available for 0.14 s (9 ticks) at no stamina, without losing the ZMC state. [E26] Medium.
21. **Zip Dash.** ZMC then (strafe) air dash — no drag and no end-of-dash slowdown penalty; wall jumps right after dismount also avoid their extra drag. [E27] Medium.
22. **Zip Launch.** On the tick before the riding state begins, the game applies a very large velocity to snap you onto the line; crouching on exactly that tick keeps it as free velocity (~1300–5900 u/s depending on attach angle; best perpendicular at bends/ends). One tick, cannot be buffered. A 2026 video claims it "got way easier" (candidates: 2026-01-22 "improved how heroes attach to ziplines", or 2026-05-22 "smoothed grabbing"/removed alt-bind delay [E56]). [E9, E28, E29] Medium (numbers community; wiki page edited 2026-06-19), date of easing Low.
23. **Wall jump velocity.** Wall jump *sets* velocity to a fixed magnitude; direction = contact normal of the nearest capsule point on the wall, modified by WASD relative to the wall: into wall → steep/high vertical, low horizontal; away → high horizontal, low vertical; neutral → middle (kick-away speed differs by input since 2025-05-08). Detection uses all walls in a small radius (2025-05-08). Wall jump does not consume the air jump. [E1, E30, E31, E25] High (official qualitative) / numbers unknown.
24. **Wall jump costs/fatigue.** First per airtime free (was 0.25 from 2025-11-21 to 2025-12-16; 0 before 2025-11-21 for the first; 0.5 for subsequent since 2025-10-02). Fatigue: 1.25 s window, reduces vertical launch only, resets on landing; air melee also causes fatigue. Wall jumps also apply "significant" extra air drag (not in ZMC). Fatigued (weakened) wall jumps also cost 0.5 and re-start the 1.25 s fatigue timer. **Since 2026-05-22 (official): using a wall jump reduces stamina regeneration by 25% for 5 s** (does not trigger out of combat or when mantling soon after). [E30, E31, E32, E33, E34, E56] High (costs/fatigue/regen official); extra-drag magnitude unknown.
25. **Wall slide.** While wall sliding, vertical speed has a terminal velocity; at −600 u/s gravity is cancelled out (2025-05-08). [E25] High (official).
26. **Corner boost.** Wall jump where the nearest contact is a horizontal edge/corner: the rounded capsule gives an upward-tilted normal → steeper, higher launch. Velocity reduced 20% on 2025-10-02; also "reduced a bit" 2025-05-08. Setups: regular, dropdown (walk off a thin ledge then wall jump), light-melee-mantle, dash-jump (~14–15 m approach), downdash. [E35, E32, E25] High.
27. **Edge boost.** Wall jump off a *vertical* edge as late as possible (1–2 tick window) so the normal rotates toward travel direction and the jump stacks with existing momentum. Convar `citadel_wall_detection_style 2` changes the behaviour. [E36] Medium.
28. **Fast climb.** Hold forward into a wall, press jump twice: wall jump then buffered mantle at the top. 0 stamina. [E37] Medium.
29. **Mantle glide.** Holding crouch as the mantle ends gives a small boost (official 2025-05-08), ~550 u/s outgoing, then slides. Blocked if you were melee'd while mantling (2025-11-21). [E38, E25, E34] High qualitative, medium number.
30. **Superglide.** Jump the instant you are actionable after a mantle glide: the glide impulse is carried into the air (air friction < ground friction). Sideways variant with A/D. ≈ dash-jump distance at 0 stamina. **Glide wall jump**: superglide next to a wall = wall jump with the glide speed. [E39, E40] Medium.
31. **Heavy melee.** Windup 0.36 s (ground: movement stops; air: keep velocity, lose control), lunge up to 0.6 s at peak 750 u/s ground / 797 u/s air (Melee Charge 1125/1195, Crushing Fists 1200/1275), turn limited, ±5° pitch in air; recovery 0.2833 s cancels **all** momentum. [E41] Medium.
32. **Heavy melee cancel.** Using an active item during the lunge ends it without the recovery, keeping velocity (true cancel: Fleetfoot, Restorative Locket, Fury Trance, Colossus, Unstoppable, Vampiric Burst). Ability cancels are "false" (still locked out). Momentum "significantly reduced" 2025-04-17. **Punch extension**: hold melee through the cancel to chain a second heavy. [E42, E43, E44] High (nerf official).
33. **Strafe dash.** See rule 2; optimal angle ~50° at low speed, ~45° from a dash-jump, approaching 90° at high speed. [E13] Medium.
34. **Air strafing.** Stronger below 450 u/s, weaker above; governed by convars `citadel_aircontrol_speed_slow` / `_fast`. Hero air-control stats exist (Celeste 38% → 44% on 2026-03-06). [E45, E21] Medium.
35. **Parry / dash.** Parry allowed during ground dash (2026-04-10); parry during a regular dash cancels the dash *and momentum* (2026-09-16). [E46, E24] High.
36. **Input buffering** for shooting, dashing, melee and parry since 2025-10-02; jump is buffered by holding (raw bhop, mantle) — the Raw Bunnyhopping page states hold-to-buffer specifically for when you have no stamina (otherwise a held/early press risks becoming an air jump). [E32, E15] High (official buffering) / Medium (jump hold behavior).
37. **Slide and sprint.** Since 2026-05-22 (official) sliding no longer resets sprint speed. Movespeed diminishing-returns point raised 11 → 12 the same patch (units not stated; described as slightly less aggressive diminishing). [E56] High.

## Momentum: what conserves, adds, sets, caps, or decays speed

| Action / state | Effect on horizontal speed | Effect on vertical | Notes / source |
|---|---|---|---|
| Ground dash | **Sets** to bucket speed; ends with slowdown to walk | — | E5, E8 |
| Air dash | **Adds** impulse; component along dash dir **capped** ~700 (900 SM) u/s | gravity off during dash | E3, E13 |
| Dash-jump | **Sets** ~611 u/s | **Sets/adds** 425 impulse (was 400) | E4, E20 |
| Ground jump | Conserves | Sets ~295 u/s | spec, E47 |
| Air jump | Unknown (likely conserves) | Likely sets | open |
| Wall jump | **Sets** fixed magnitude along normal+input; then extra air drag | sets (fatigue scales vertical only) | E30, E25 |
| Corner / edge boost | Normal rotation redirects the fixed-magnitude set | corner: more vertical | E35, E36 |
| Normal air | Decays via air drag ~0.2 | gravity | E12 |
| After slows (2026-09-16+) | Extra air drag = 35% of slow | — | E24 |
| After ZMC crouch-dismount | **No decay** for 2 s, then drag 0.25 | gravity | E12 |
| Air slide (landing) | **Conserves** landing speed; friction 0.1875 | — | E3, E11 |
| Ground (dash) slide | **Caps** momentum (community); can't jump out (pre-2026-03-06) / can jump out since (official); heavy air drag after that jump = single report, low | — | E3, E16, E17, E21 |
| Slide (2026-05-22+) | No longer resets sprint speed | — | E56 |
| Slide > 0.75 s (1.0 s dash-jump) | Friction jumps to ~3.19 / 0.69 | — | E11 |
| Slide hop, slide < 0.5 s (not first) | Heavy speed penalty | — | E14 |
| Raw bhop | Conserves (better than slide hop below ~900 u/s) | — | E15 |
| Crouch below slide speed | Snaps to ~4.8 m/s | — | E22 |
| Mantle glide | **Sets/adds** ~550 u/s forward | — | E38 |
| Superglide | Conserves glide speed into air | jump | E39 |
| Heavy melee lunge | Sets up to 750/797 u/s | air: keeps | E41 |
| Heavy melee recovery | **Zeroes** all momentum | zero | E41 |
| Heavy melee cancel | Keeps lunge speed (reduced 2025-04-17) | — | E42 |
| Zip launch | **Adds** attach snap velocity 1300–5900 u/s | — | E9 |
| Wall slide | — | terminal −600 u/s | E25 |
| Parry during dash | **Zeroes** dash momentum | — | E24 |

## Known tech that depends on these rules

| Tech (aliases) | Inputs | Cost | Why it works (rule #) | Patched? | Best source |
|---|---|---|---|---|---|
| Dash jump | Dash → jump on blue flash | 2 | 3, 4 | Window 0.2→0.25 s, 18→19 m, 400→425 (2026-06-30); +30% air control 0.25 s (2026-03-06) | E4, E20 |
| Coyote dash jump | Dash off ledge, jump in window | 2 | 5 | — | E4 |
| Dash jump cancel | Dash → ability in window → jump | 1 | 6 | — | E1 |
| Dash jump slide bunnyhop | Dash jump, hold crouch, hop each landing | 2 | 4, 11, 12 | slide jump officially 2026-03-06 | E4, E14 |
| Dash jump strafe jumping | Dash jump + air strafe + slide | 2 | 4, 34 | — | E4 |
| Dash slide | Dash, hold crouch | 1 | 7, 11 | — | E6 |
| Short dash crouch cancel (SDCC, dash cancelling) | Dash, tap crouch | 1 | 8 | — | E7 |
| Dash hop | Jump at end of dash (mini dash-jump) | 1 | 1, 3 (just after window?) | — | E2 |
| Short hop | Dash, quick crouch, jump | 1 | 7, 11 | — | E2 |
| Instant Air Dash (IAD) | Jump + air dash ASAP, land in slide | 1 | 2, 11, 17 | Not patched (as of 2026-09-27) | E3, E8 |
| IAD on falling / on stairs | IAD timed to ground contact | 1 | 17 | — | E2 |
| Strafe dash (diagonal dash) | Air dash at an angle to velocity | 1 | 2, 33 | — | E13 |
| Slide / sprint slide | Crouch above slide speed | 0 | 9 | — | E11, E2 |
| Slide storage (slide conservation) | Hold crouch in air | 0 | 14 | — | E11 |
| Crouch storage | Hold crouch before launch | 0 | 14 | — | E11 |
| Slide bunnyhop (slide hop) | Slide ≥0.5 s → jump → land sliding | 0 | 11, 12 | Enabled broadly 2026-03-06 | E14 |
| Raw bunnyhop | Jump on landing tick | 0 | 13 | — | E15 |
| Crouch glide | Rhythmic crouch taps above 376 u/s | 0 | 16 | — | E15b |
| Down dash (fast-fall) | Double-tap crouch in air within 28 ticks | 0.5 or 1 | spec | — | spec |
| Wall jump | Jump near wall (+WASD) | 0 / 0.5 | 23, 24 | Reworked 2025-04-04, 2025-05-08; costs 2025-10-02, 2025-11-21, 2025-12-16; regen penalty 2026-05-22 | E30, E56 |
| Corner boost (+ dropdown, melee-mantle, dash-jump, downdash variants) | Wall jump at horizontal edge | 0 | 26 | −20% 2025-10-02 | E35 |
| Edge boost | Late wall jump off vertical edge | 0 | 27 | — | E36 |
| Wall boost | Dash at angle into wall | 1 | 2 + wall slide (inferred) | — | E2 |
| Fast climb | Forward + jump ×2 on wall | 0 | 28 | — | E37 |
| Melee jump | Heavy melee + wall jump to climb without air jump | 0 | 24, 31 | — | E1 |
| Vent boost / mantle vent boost | Wall jump combined with air vent | 0 | — | — | E2 |
| Mantle glide (mantle slide) | Hold crouch through mantle | 0 | 29 | Added 2025-05-08; blocked after melee 2025-11-21 | E38 |
| Superglide | Mantle glide → jump when actionable | 0 | 30 | — | E39 |
| Glide wall jump / mantle wall jump / mantle corner jump / mantle edge boost | Superglide/mantle next to wall/edge | 0 | 23–30 | — | E40, E2 |
| ZMC | Crouch off zipline | 0 | 19 | Dismount momentum reduced slightly 2025-05-08 | E12 |
| Small zip jump ("cake jump") | Crouch off zipline, jump within 0.14 s | 0 | 20 | — | E26 |
| Zip dash | ZMC → (strafe) air dash | 1 | 21 | — | E27 |
| Zip launch | Attach, crouch on exact snap tick | 0 | 22 | Easier after attach changes (2026, date unconfirmed) | E9, E28 |
| Heavy melee cancel | Heavy → active item in lunge | 0 | 31, 32 | Momentum cut 2025-04-17 | E42 |
| Heavy melee cancel extension (punch extension) | Hold melee through cancel | 0 | 32 | — | E43 |
| Hidden melee | Buffer heavy under ability anim | 0 | anim priority | — | E44 |
| Crouch turn | Tap crouch while changing direction | 0 | 15 | — | E22 |

Hero/item-specific tech (not universal; listed for completeness, see E48/E49): Abrams Charge Cancel/Launch; Doorman Doorway/Self Cart; Drifter mark-teleport momentum; Dynamo/Ivy/Lash/Pocket/Vindicta/Yamato ZMC variants; Haze Bullet Dance Slide; Holliday Bounce Pad / insta jump-pad crash; Infernus Flame Dash Slide (+bhop); Lash Grapple/Slam Slide, grapple wall jump, ult momentum; Mo & Krill burrow family; Paradox Time Jump / carbine momentum cancel; Seven Sky Lift; Shiv M2 sliding/slide hop/infinite slide/force jump/super jump; Sinclair momentum tech; Viscous puddle punch, frogpunch, cube tech; Wraith Telezip; Yamato Dash Slash; items: Majestic Leap Cancel, Rescue Beam Slingshot, Warp Dashing / Warp Dash Jump.

## Patch history affecting this (dated)

| Date | Change | Source |
|---|---|---|
| 2025-04-04 | Wall jump lateral velocity modified by WASD into/away from wall; mantle requires WASD toward ledge; zipline attach direction from input; hold jump to climb ropes | E31 |
| 2025-04-17 | Heavy melee cancel momentum "significantly reduced" | E50 |
| 2025-05-08 | Low-speed air accel increased; kick-away speed by input; fatigue vertical-only, 2 s → 1.25 s; wall detection radius; corner boosting reduced "a bit"; wall slide terminal −600 u/s; Mantle Glide added; zipline dismount momentum reduced slightly; zipline boost 130% → 80% | E25 |
| 2025-10-24 | Jump pads: taking damage in first 0.6 s of launch stuns you (continue to destination, 30% slow 2 s after landing) | E57 |
| 2025-10-02 | Wall jumps after first cost 0.5; corner boost velocity −20%; jump shooting lockout 0.15 → 0; input buffering for shoot/dash/melee/parry | E32 |
| 2025-11-21 | Initial wall jump costs 0.25; stamina regen 5 → 5.25 s; jump pad stun window 0.6 → 0.9 s; sprint timer vs neutrals 0.5 → 2.5 s; mantle slide blocked after mantle-melee slow | E34 |
| 2025-12-16 | Initial wall jump free again; stamina 4.5 s; sprint delay 4 → 3 s; sprint ramp changes; jump pad hit 15% HP | E33 |
| 2026-01-22 | "Improved how heroes attach to ziplines" (possible link to easier zip launch) | E28 |
| 2026-01-30 | Stamina Mastery air dash distance 30% → 23%; dash-distance slows changed | E51 |
| 2026-03-06 | Can jump during slide; dash jump +30% air control for 0.25 s; Celeste air control 38 → 44% | E21 |
| 2026-04-10 | Parry allowed during ground dash | E46 |
| 2026-05-22 | Sliding no longer resets sprint speed; stamina regen −25% for 5 s after a wall jump (not out of combat / mantling soon after); movespeed diminish point 11 → 12; zipline grab smoothed, alt-bind delay removed; two mid-map jump pads removed; knockup durations affected by debuff reduction | E56 |
| 2026-06-30 | Dash jump window 0.2 → 0.25 s (0.30–0.55 s); distance 18 → 19 m; vertical impulse 400 → 425 | E20 |
| 2026-07-28 | Bucket 3 dash times 0.70 → 0.72 (ground), 0.49 → 0.51 (air) | E52 |
| 2026-09-16 | Parry during dash cancels dash and momentum; slows add 35% air drag; slows −20% / dash slows −10% | E24 |

Checked with no *universal* movement changes found (hero-specific only): 2025-12-29, 2026-03-21. Checked with no movement changes found: 2026-02-10, 02-17, 03-10 (zipline capture only), 03-25, 04-30 (bounce-pad knock-off now drops you), 05-19, 06-11, 07-09 (Urn Runner only), 08-12, 08-22, 09-09.

## Contradictions / uncertainties (and what recording would settle them)

1. **Dash-jump window** — Dashing page says 0.2 s; Dash Jumping page and official 2026-06-30 notes say 0.25 s (0.30–0.55). Official wins: 0.25 s. Recording: frame-step jump presses at 0.50–0.56 s after dash.
2. **Dash-jump velocity** — Community 611 u/s horizontal "fixed, ignores momentum" may predate the 18 → 19 m change. Record `cl_showpos` speed at takeoff (and with an incoming dash-slide speed to confirm "ignores prior momentum").
3. **Slide threshold 350 vs 376 u/s** — Slide/Crouching pages say 350; Slide Bunnyhopping and Crouch Gliding say 376. Hypothesis: 350 to enter from crouch, 376 to keep sliding / re-enter while hopping (or one is stale). Record: accelerate slowly (sprint items) and crouch at logged speeds; also measure the speed at which a slide ends.
4. **Jumping out of ground-dash slides** — Nov 2025–Jan 2026 reports: impossible. 2026-03-06: "can now jump during slide". Apr 2026 forum: possible but "insane" air drag. Record horizontal speed for 1 s after jumping from (a) dash slide, (b) air slide, same entry speed.
5. **Air dash cap form** — "dot product capped at ~700/900" is community wording. Is it a clamp of the along-direction component, or is the impulse reduced as v·d approaches the cap? Record air dashes at several incoming speeds/angles.
6. **Air drag model** — coefficient 0.2 (normal), 0 → 0.25 (ZMC), wall-jump extra drag, ground-dash-slide-jump drag: form (linear vs Source friction) and magnitudes unknown. Record coast-down curves with no input.
7. **Dash "slowdown" at end** — how fast/when a ground or air dash returns to base speed; IAD depends on it.
8. **Slide hop 0.5 s penalty** — magnitude and whether it's a friction spike or a multiplier.
9. **Down dash cost** 0.5 (Movement page) vs 1 (Stamina page) — unchanged conflict.
10. **Zip launch speeds** (1300–5900 u/s) and whether 2026-01-22 changed the snap — record several attaches at bends.
11. **Wall jump magnitudes** — no public numbers for kick speed per input; only qualitative official notes.
12. **Mantle glide ~550 u/s** — community number; verify.
13. **Heavy melee numbers** (0.36 / 0.6 / 0.2833 s; 750/797 u/s) — community; verify, and measure what a true cancel keeps post-2025-04-17.
14. **Raw bhop 900 u/s crossover** implies a speed-dependent loss on landing; unknown mechanism.

## Evidence (numbered)

1. https://deadlock.wiki/Movement — wiki, accessed 2026-09-27 — tech list: corner/dropdown boost, melee jump, dash jump cancel, heavy melee cancel (patched 2025-04-17); wall jump sets fixed velocity along capsule normal.
2. https://deadlockmoves.com/fundamentals/ — community site (2026) — 22 universal moves with stamina costs and difficulty tiers (dash hop, short hop, zip launch, small zip jump, mantle corner jump, etc.).
3. https://forums.playdeadlock.com/threads/instant-air-dash-iad-what-it-is-how-it-works-and-why-its-probably-a-bug.105874/ — official forum, 2026-02-06 (+replies to 2026-04-13) — IAD mechanism, ~20% gain, air slide vs ground slide, ground-dash-slide jump air drag.
4. https://deadlock.wiki/Dashing/Dash_Jumping — community movement wiki (edited 2026-09-11) — 0.25 s window from 0.3 s, 611 u/s fixed, coyote dash jump, variations.
5. https://deadlock.wiki/Dashing — wiki — ground dash sets velocity, air dash impulse, buckets, 0.2 s window (stale), down dash 28 ticks.
6. https://deadlock.wiki/Dashing/Dash_Sliding — community wiki (2026-09-11) — dash slide mechanics.
7. https://deadlock.wiki/Dashing/Short_Dash_Crouch_Cancelling — community wiki — SDCC.
8. https://deadlock.wiki/Dashing/Instant_Air_Dash — community wiki — IAD removes end-of-dash slowdown; ~900 u/s with double dash.
9. https://deadlock.wiki/Ziplines/Zip_Launch — community wiki — one-tick snap velocity, 1300–5900 u/s.
10. Spec ground dash values (deadlock.wiki/Dashing, Stamina) — see movement.md.
11. https://deadlock.wiki/Sliding — wiki — 350 u/s, frictions, penalty onsets, slide/crouch storage, infinite ammo.
12. https://deadlock.wiki/Ziplines/Zipline_Momentum_Conservation — community wiki — air drag 0.2 normal, 0 for 2 s, then 0.25.
13. https://deadlock.wiki/Dashing/Strafe_Dashing — community wiki (2026-09-11) — directional (dot-product) cap ~700 / ~900 u/s, optimal angles.
14. https://deadlock.wiki/Bunnyhopping/Slide_Bunnyhopping — community wiki (2026-06-22) — flag, 0.5 s penalty, 376 u/s.
15. https://deadlock.wiki/Bunnyhopping/Raw_Bunnyhopping — community wiki (2026-02-08) — <900 u/s crossover, hold-to-buffer.
15b. https://deadlock.wiki/Crouch_Gliding — community wiki (2026-02-08) — 376 u/s, rhythm.
16. https://forums.playdeadlock.com/threads/cant-jump-while-sliding-after-dash-slide.90956/ — official forum bug report, 2025-11-23 (+2026-01-24) — can't jump out of dash slide.
17. Same as E3 (reply 2026-04-12) — jump out of dash slide now allowed but heavy air drag.
18. https://deadlock.io/en/articles/mechanics/dash-jump — community guide — aliases; jump cooldown 0.15 s, dash cooldown 0.85 s, dash duration 0.6 s (unclear provenance, low).
19. https://boostroom.com/blog/deadlock-movement-guide-slide-dash-wall-jump-and-zipline-tech — guide, 2026-02-28 — names "cake jump", fast-fall, jump-cancel.
20. https://deadlock.wiki/Update:June_30,_2026 (and blitz.gg/articles/deadlock-patch-notes-6-30-2026) — official notes mirror — dash jump window/distance/vertical impulse.
21. https://forums.playdeadlock.com/threads/03-06-2026-update.114328/ — official — slide jump, dash jump air control, Celeste air control.
22. https://deadlock.wiki/Crouching — wiki — crouch decel to 4.8 m/s, crouch turning.
23. https://deadlock.wiki/Walking — wiki — crouch 4.75 m/s, gradual accel/decel (no numbers).
24. https://deadlock.wiki/Update:September_16,_2026 — official mirror — parry cancels dash momentum, slow air drag.
25. https://deadlock.wiki/Update:May_8,_2025 — official mirror — wall jump/mantle glide/wall slide terminal/zipline dismount changes.
26. https://deadlock.wiki/Ziplines/Small_Zip_Jump — community wiki — 0.14 s (9 ticks).
27. https://deadlock.wiki/Ziplines/Zip_Dash — community wiki.
28. https://deadlock.wiki/Update:January_22,_2026 — official mirror — zipline attach improved.
29. https://www.youtube.com/watch?v=6DHgDHgpGoA — YouTube, "Deadlock's HARDEST Movement Tech just got WAY EASIER (zip launch tech)" by Idkhi (date not retrieved).
30. https://deadlock.wiki/Wall_Jumping — community wiki — input directions, fatigue, extra air drag.
31. https://deadlock.wiki/Update:April_4,_2025 — official mirror — wall jump WASD rework.
32. https://deadlock.wiki/Update:October_2,_2025 — official mirror — wall jump 0.5, corner boost −20%, buffering.
33. https://forums.playdeadlock.com/threads/12-16-2025-update.93983/ — official — initial wall jump free, 4.5 s stamina, 3 s sprint delay.
34. https://deadlock.wiki/Update:November_21,_2025 — official mirror — initial wall jump 0.25, jump pad window 0.9 s, neutral sprint timer 2.5 s.
35. https://deadlock.wiki/Wall_Jumping/Corner_Boost — community wiki — mechanism, 5 setups.
36. https://deadlock.wiki/Wall_Jumping/Edge_Boost — community wiki — late wall jump, wall detection style convar.
37. https://deadlock.wiki/Wall_Jumping/Fast_Climb — community wiki.
38. https://deadlock.wiki/Mantling/Mantle_Glide — community wiki (2026-06-19) — ~550 u/s.
39. https://deadlock.wiki/Mantling/Superglide — community wiki (2026-01-25).
40. https://deadlock.wiki/Mantling/Glide_Wall_Jump — community wiki (2026-01-25).
41. https://deadlock.wiki/Heavy_Melee — wiki — windup/lunge/recovery timings and speeds.
42. https://deadlock.wiki/Heavy_Melee/Heavy_Melee_Cancel — community wiki — true/false cancels, items.
43. https://deadlock.wiki/Heavy_Melee/Heavy_Melee_Cancel_Extension — community wiki.
44. https://deadlock.wiki/Heavy_Melee/Hidden_Melee — community wiki.
45. https://deadlock.wiki/Air_Strafing — wiki — 450 u/s, convar names.
46. https://deadlock.wiki/Update:April_10,_2026 — official mirror — parry during ground dash.
47. https://deadlock.wiki/Jumping — wiki — 295 u/s, +45 u.
48. https://deadlock.wiki/Character_Tech — community wiki — hero tech index.
49. https://deadlock.wiki/Item_Tech — community wiki — item tech index.
50. https://deadlock.wiki/Update:April_17,_2025 — official mirror — heavy melee cancel nerf.
51. https://deadlock.wiki/Update:January_30,_2026 — official mirror — Stamina Mastery 30 → 23%.
52. https://deadlock.wiki/Update:July_28,_2026 — official mirror — bucket 3 dash times.
53. https://forums.playdeadlock.com/threads/wall-jump-bug.60655/ — official forum, 2025-04-08 — wall jump direction relative to wall, not model.
54. https://forums.playdeadlock.com/threads/wall-jump-boost-bug.22586/ — official forum, 2024-08-29 / 2024-12-18 — early corner-boost-on-extrusion reports.
56. https://www.deadlockpatchnotes.com/patches/05-22-2026-update (and https://deadlock.wiki/Update:May_22,_2026) — official notes mirror — slide/sprint, wall-jump stamina regen penalty, movespeed diminish, zipline grab.
57. https://deadlock.wiki/Update:October_24,_2025 — official mirror — jump pad launch stun.
55. https://deadlock.wiki/Portal:Movement — community movement portal (dlmovement.wiki redirects here); Movement Discord https://discord.gg/q6TwMv3eEF.

### Reading list (top guides / creators)

- **deadlock.wiki Portal:Movement + Universal Tech** (E55) — the most technical source; written by the movement community, has numbers.
- **deadlockmoves.com** (E2) — tech directory with difficulty tiers and a map of route-specific moves.
- **Deadlock Movement Discord** (linked from the portal) and the "【MOVEMENT】 MOVE" Steam group (steamcommunity.com/groups/dlmovement).
- YouTube: "Deadlock 2026 Movement Guide (Featuring Leif)" — Deathy, ~2026-03-05 (https://www.youtube.com/watch?v=EtHEtvBfC2M); "The Ultimate Deadlock Movement Guide! - Beginner to Expert" — Eskay, ~2026-03-12 (https://www.youtube.com/watch?v=uCBrlTAPti4); "How to MOVE Like a DEADLOCK PRO" — Eido, ~2026-02-27 (https://www.youtube.com/watch?v=kmhFPIMmXzc); "The ULTIMATE Deadlock Movement Guide" — Piggy (https://www.youtube.com/watch?v=LT_NIHF_25A); "Deadlock Advanced Movement Tech" playlist — Noct Gaming (https://www.youtube.com/playlist?list=PLpmhP4COCOJnDQYISIU8Dx04_kueJLait); Idkhi zip launch video (E29). LȊGHTBRINGER is credited with naming SDCC.
- Official forum threads: IAD analysis (E3), dash-slide jump report (E16).
- Movement practice map mod: https://gamebanana.com/mods/631714 (not inspected; mods are out of scope for clean-room).

## Verification log (2026-09-27)

Adversarial pass: re-fetched cited pages and official patch mirrors, looked for newer patches and contradicting reports. Clean-room sources only (wiki, official forum/changelog, patch-note mirrors).

**Confirmed against source (unchanged):**
- Ground dash sets velocity / air dash is impulse (Dashing page, edited 2026-09-20).
- Dash jump: 0.25 s window starting 0.3 s, 611 u/s, "prior momentum disregarded", coyote dash jump (Dash Jumping page, edited 2026-09-11); 0.2→0.25 s, 18→19 m, 400→425 (official 2026-06-30).
- 2026-03-06: "Can now jump during slide"; dash jump +30% air control for 0.25 s; Celeste air control 38→44% (official forum).
- Slide: 350 u/s entry, friction 0.1875, late 3.1875 (grounded dash) / 0.6875 (dash jump), onsets 0.75 / 1.0 s, +0.25 s per slide-distance item level (Sliding page, edited 2026-06-19). Crouching page also says 350; Slide Bunnyhopping (2026-06-22) and Crouch Gliding (2026-02-08) say 376 — conflict stands.
- Slide bunnyhop flag, <0.5 s penalty (not on first slide) — Slide Bunnyhopping page.
- Raw bhop <900 u/s crossover — Raw Bunnyhopping page (2026-02-08).
- ZMC drag 0.2 / 0 for ~2 s / 0.25 — ZMC page footnote (no patch date).
- Wall jump: WASD in/away behaviour, 0.5 after first, 1.25 s fatigue, landing resets, air melee triggers fatigue, doesn't use air jump, significant extra drag (Wall Jumping page, edited 2026-01-31); fixed-magnitude set along capsule normal (Movement page).
- Official wall-jump/corner-boost/mantle-glide/wall-slide/zipline items of 2025-04-04, 2025-05-08, 2025-10-02, 2025-11-21, 2025-12-16.
- Heavy melee numbers (Heavy Melee page, edited 2026-01-31; also ~300° max turn); cancel nerf 2025-04-17 (official).
- Mantle glide ~550 u/s "can vary by surface" (edited 2026-06-19). Zip launch 1300–5900 u/s, one tick, no buffer (edited 2026-06-19).
- Air strafing 450 u/s split and convar names (edited 2026-02-08).
- 2026-01-30 Stamina Mastery 30→23%; 2026-04-10 parry during ground dash; 2026-07-28 bucket-3 times; 2026-09-16 parry cancels dash+momentum, slows −20%, dash slows −10%, slows add 35% air drag.
- Down dash 0.5 stamina, one per jump (two with Stamina Mastery) per Movement page; 28-tick window per Dashing page.
- IAD not patched; no dev response in the forum thread (latest reply 2026-04-13).
- No movement patch after 2026-09-16 on the official changelog as of today.

**Corrected / removed:**
- Rule 1: removed invented "~547 u/s now" bucket-3 speed. Official 2026-07-28 changed dash *time* only; speed/distance effect unknown.
- Rule 11 / table / plain-language: "heavy air drag when jumping out of a ground dash slide" downgraded to Low — it rests on one forum reply; the official note only says you can now jump during slide.
- Rule 17: "~20% faster" is a single author's estimate; IAD wiki says IAD is *slower* without items and only much faster with Stamina Mastery/vitality + slide bhop. Rewritten.
- Rule 2: ~900 u/s Stamina Mastery cap downgraded (may predate 2026-01-30 nerf 30→23%).
- Rule 13: marked the friction/speed-loss implication as our inference.
- Rule 24: added fatigued-jump cost detail and the **missed official 2026-05-22 change** (stamina regen −25% for 5 s after a wall jump).
- Added rule 37 and patch rows for the **missed 2026-05-22 update** (sliding no longer resets sprint speed; movespeed diminish point 11→12; zipline grab smoothed) and 2025-10-24 (jump pad launch stun). The previous "checked" list omitted 2025-10-24, 2025-12-29, 2026-03-21 and 2026-05-22.
- Rule 36: raw-bhop hold-to-buffer is stated for the no-stamina case.

**Still uncertain (need in-game recording or more sources):** 350 vs 376 u/s slide threshold; whether 611 u/s was re-measured after 2026-06-30 (page doesn't say); bucket-3 speed after 2026-07-28; Stamina Mastery air-dash cap after 2026-01-30; air-drag model form and wall-jump/dash-slide-jump extra drag magnitudes; wall-jump kick magnitudes (no public numbers); "ground dash slide caps momentum" (community only); down dash 0.5 vs 1 conflict (Movement page says 0.5); Dec 16 2025 notes describe regen as "5 s → 4.5 s" although Nov 21 had set 5.25 s (mirror wording or baseline confusion); what exactly "dash slowdown" does over time; Reddit/YouTube transcripts were not retrievable, so creator-level exploits beyond the wiki are not independently checked.
