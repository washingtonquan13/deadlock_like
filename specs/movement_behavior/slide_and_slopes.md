# Slide & Slopes — behavioral model

Research date: 2026-09-27. Scope: entering a slide, slide friction phases, the late-slide penalty, slopes, slide-jump / slide-hop chaining, landing into a slide, bunnyhopping, ground speed caps, and how slides interact with sprint and dashes.
Sources are public only: patch notes, deadlock.wiki (including the migrated Deadlock Movement Wiki pages), official forum threads, and YouTube descriptions and auto-captions. I paraphrased everything.
Some numbers have the note "community-datamine": the wiki gives them, citing contributors such as Altimor, or code-variable names. I did not verify them myself. I only record them here.

Patch baseline: the "current" behavior below is as of the 2026-09-16 update. The biggest slide-related changes were **2026-03-06** (you can now jump during any slide), **2026-05-22** (sliding no longer resets sprint) and **2026-06-30** (dash-jump window and impulse changed).

---

## How it works (plain language, as a movement player would explain it)

- A slide is a **low-friction, speed-carrying state**. It does **not** add speed on flat ground. It keeps speed you already have (from a dash, dash-jump, mantle glide, zip dash, air dash or a downhill). On a downhill, gravity feeds the slide, so it gains speed.
- To slide you need to be fast (about 350 u/s ≈ 8.9 m/s) or on a slope. Normal running is below that for most heroes. So on flat ground you nearly always need a dash, a dash-jump, a mantle glide, a zipline drop or sprint and items first.
- The slide has **two friction phases**. For roughly the first 0.75 s, friction is very low (lower than air drag, according to the best-known movement creator). After that it becomes about 17× worse, and the slide dies quickly. So you never "ride a slide out". You **jump out of it before 0.75 s** and land into a new slide. Each new slide gets a fresh low-friction phase. This is the **slide hop**, which is Deadlock's version of bhopping and the basis of most routing.
- When you chain slide hops there is a second timing rule. If you jump out of a slide **earlier than 0.5 s**, you get a heavy speed penalty that players call "slide drag". So the target window for chained hops is about **0.5–0.75 s into each slide** (a 0.25 s window). The first slide of a chain is exempt, so you can hop out of it instantly.
- Holding W does nothing while sliding at speed or while in the air. The slide's speed stays the same whether you press keys or not. You steer a slide or a hop with the mouse and A/D (air strafing between slides). Strafing well can keep a slide-hop chain going almost indefinitely.
- Hold crouch **in the air** and you slide the moment you land ("slide storage"). You do not need to meet the speed threshold when landing on ramps, curbs or edges. Hold crouch **before** you leave the ground and you land crouched instead of sliding ("crouch storage").
- A ground dash cancelled into crouch becomes a "dash slide", which starts at about 650 u/s. If you crouch too early in the dash (before the dash-jump window), you get a "dead slide" that loses speed.
- An air dash normally loses about 20% of total velocity when it ends. If you air-dash right at the ground and hold crouch, you land into a slide before that penalty applies. This is the Instant Air Dash (IAD). It is not extra speed. It **avoids a loss**.
- A raw bunnyhop (jumping on the landing tick without sliding) exists and costs no stamina. It is hard to do and rarely better than slide hopping, except for Celeste, whose air control is high.
- Sliding does not stop sprint (since 2026-05-22). While sliding you have infinite ammo, and you can shoot.

---

## Rules (numbered, precise, implementable)

**Units:** 1 u = 1 inch = 0.0254 m. Speeds are horizontal unless stated otherwise. Tick = 1/64 s (the wiki uses "28 ticks = 0.44 s").

### Entry
1. **Speed entry.** When crouch is pressed while grounded and horizontal speed is above **350 u/s (8.9 m/s)**, the character enters Slide. Below that speed it enters Crouch, and speed quickly falls to crouch-walk speed (4.8 m/s). *High confidence (wiki Sliding, Crouching, Movement, Move Speed; Leif 2026-05).*
   - Some wiki pages give **376 u/s (10 m/s)** instead: the Crouch Gliding page, and the Slide Bunnyhopping page for "speed to keep sliding". I treat 350 as the entry threshold and 376 as unverified (see Contradictions).
   - Verification 2026-09-27: the 376 figure is internally inconsistent. The wiki's own 350 u/s = 8.9 m/s implies about 39.3 u per m, so 10 m/s would be about 394 u/s, not 376. One 2026 guide (BoostRoom) says "10 m/s according to what players have tested", with no method. Keep 350 as the rule; 376/10 m/s is a rounded or practical figure, **low confidence**.
2. **Slope entry.** On an inclined surface (ramps, stairs) the slide can start **at any speed** when crouch is pressed. *High confidence (wiki).* The minimum slope angle is not documented.
3. **Buffered entry ("slide storage").** If crouch is pressed while airborne and held, a slide input is stored with no time limit. When you land, the slide starts if the speed rule or the slope rule is met. Very small geometry such as curbs and ledge lips counts as sloped enough. *High confidence (wiki Sliding; Leif; Eskay).*
4. **Crouch storage.** If crouch is already held **before** you leave the ground or start a dash, you land crouched and **never slide**, whatever the surface or speed. The exception is a down dash. *Medium-high confidence (wiki Sliding).*
5. **Dash slide.** Pressing crouch at any time during a **ground** dash cancels the dash into a slide. Details (Leif, 2026-04):
   - The dash slide **starts at about 650 u/s regardless of dash bucket**.
   - If crouch is pressed **before the dash-jump window opens** (earlier than 0.3 s), it becomes a "dead slide". It loses speed and ends at about 270 u/s.
   - If crouch is pressed too late, after the dash has already decayed, the slide starts below 500 u/s.
   - Cost: the dash's 1 stamina. The slide itself is free.
   *Medium-low confidence (single expert creator, measured with cl_showpos). The wiki Dash Sliding page confirms "cancel at any time", the 1-stamina cost, and "cancel roughly when the DJ circle turns blue", but gives no 650 or 270 figure. Note that 650 is above the wiki's listed peak ground-dash speeds (635 / 579 / 562 u/s for buckets 1/2/3), so the 650 set-speed is unusual and must be checked in a recording before you build on it.*
6. **Mantle glide.** If crouch is held as a mantle ends, you get a small speed boost and a slide. Outgoing speed is about 550 u/s and can be lower on curved lips. Holding A or D while mantle-gliding sends the slide out at 90° ("mantle strafe"). *High confidence (patch 2025-05-08; wiki Mantle Glide; Eskay).*
7. **Crouch-spam penalty.** Pressing crouch aggressively within a very narrow window briefly makes you move progressively slower. *High confidence that it exists (patch 2024-09-26). No numbers.*

### Friction phases
8. **Early phase.** Slide friction coefficient is **0.1875**. Friction is applied Source-style against current speed. Leif describes it as lower than air drag. *Medium confidence (the number is community-datamine on the wiki; the qualitative claim is an expert statement).*
9. **Late-slide penalty.** After **0.75 s** of continuous sliding, friction rises sharply. The wiki gives **about 3.1875** when the slide came from a grounded dash (17× base, which matches Leif's "~1,500% worse") and **about 0.6875** when it came from a dash-jump. For a slide that follows a dash-jump, the penalty starts at **1.00 s** instead. *Medium confidence (community-datamine plus independent expert corroboration).*
   - The wiki does **not** give the penalty friction for a plain slide (sprint entry, landing slide, slope slide). Leif's general statement implies that ordinary slides also get about 17×. Treat 3.1875 as the default penalty friction and 0.6875 as the dash-jump exception.
10. **Slide Distance items.** These delay the penalty onset in steps of **+0.25 s**:
    - Fleetfoot (+35%): 1.00 s / 1.25 s (dash-jump)
    - Burst Fire (+50%): 1.25 s / 1.50 s
    - Electric Slippers (+80% Slide Distance per the wiki item table): penalty onset not measured. Do not extrapolate a step count from the percentage.
    They **do not add speed**. Implement this as a lookup table, not a multiplier. *Medium confidence (wiki).*
    - Hidden friction reductions from items (+27% / +56%) appear in a commented-out wiki table as "unconfirmed". Do not implement them.
11. **End.** The slide ends when:
    - crouch is released (you go to stand or run, and ground friction applies)
    - you jump
    - speed decays to a stop (you become crouched, which also breaks sprint)
    - you slide into a wall, which transitions to crouch and can break sprint

### Slide-hop (jump out of slide)
12. **Jumping from a slide is allowed from any slide (since 2026-03-06).**
    - Before that patch, only slides that started from an airborne state could be jumped out of: landing slides, slide storage, dash-jump landings, ramps. Grounded dash slides on flat ground could not. That restriction was the "slide bunnyhop flag" described on the wiki. The official line reads "Can now jump during slide".
    - The jump is a normal free ground jump: 295 u/s vertical and +45 u apex per the wiki. **Horizontal slide velocity carries into the air.** No evidence says it is reduced, apart from rule 13.
    - *High confidence on existence. Medium confidence on "fully conserved".*
13. **Slide drag (early-jump penalty in a chain).** Jumping out of a slide sets a flag. While the flag is set, jumping out of the **next** slide less than **0.5 s** after it started applies a large air-drag penalty ("decreasing speed dramatically").
    - The flag clears after a short period on the ground doing something other than sliding. It also clears when you slide down a slope and jump.
    - The first slide in a chain is exempt.
    - A dash-cancel short hop done with a scroll-wheel crouch does not set the flag.
    - Resulting optimal window: land, slide 0.5 s to 0.75 s (or 1.0 s after a dash-jump), then jump.
    - *Medium confidence (wiki Slide Bunnyhopping, 2026-02; Leif, 2026-05; Eskay, 2026-03 "jumping too early is much worse than too late"). Magnitude not measured publicly.*
14. **Movement input during a slide does not change slide speed.** Pressing W, A or D neither accelerates nor slows a slide. Leif states this for both the slide and the air phase of a hop.
    - **Steering exists.** Players describe turning a slide by holding forward and slowly moving the mouse. A 2026-02 bug report says heroes can change direction during a slide on flat ground, downhill and (except Vyper) uphill.
    - Vyper's Slither gives "can turn faster while sliding", so a base **turn-rate limit** exists. The value is unknown.
    - *Medium confidence (qualitative).*
15. **Speed floor for continuing.** A new slide on landing still needs the entry speed (rule 1) unless the ground slopes. Leif: once hop speed nears your run speed, there is no point hopping further.

### Slopes
16. **Downhill.** Gravity accelerates a slide down a slope, and you can pass run speed "for free". No documented speed cap for downhill sliding. *High confidence (qualitative; wiki, guides).*
17. **Uphill.** A slide carrying momentum can go up a ramp and loses speed to gravity plus friction. Slither's description ("can slide up hills") suggests that normal heroes cannot *start* or *sustain* a slide uphill without momentum. That is inferred.
    - Vyper's lack of lateral control uphill was fixed on 2026-04-10, which implies other heroes have lateral control uphill.
    - *Low-medium confidence.*
18. **Bottom of a ramp.** Since 2024-06-06, heroes slide farther when they reach the bottom of a ramp. This is an official, deliberate tuning, with no number given. *High confidence that it exists.*

### Landing, air dash and bunnyhop
19. **Landing into a slide keeps horizontal speed.** You need crouch held (slide storage) and speed of 350 or more, or a slope. This is what makes dash-jump → slide → hop work. *High confidence.*
20. **End-of-air-dash penalty.** When an air dash ends, about **20% of total velocity** is removed as extra drag, unless:
    - (a) you land into a slide first (IAD), or
    - (b) you are within 2 s of crouch-dropping off a zipline, or
    - (c) you chain straight into another air dash (IAD → IAD).
    Bhopping out of an IAD still applies the drag. With a good IAD, height rises by only about 1 u during the dash (ground-hugging). A curb or drop that makes you fall afterwards applies the penalty.
    - *Existence of the end-of-air-dash drag: high confidence* (forum 11916 from 2024-07, forum 105874 from 2026-02, and the wiki IAD page all describe it).
    - *The 20% size: medium-low confidence, single source (Leif).* The wiki and forum threads give no percentage. The "~20%" in forum thread 105874 is a different number: the **speed gain of chained IADs over normal air-dash sliding**, not the drag size. Do not conflate them.
21. **Raw bunnyhop.** Jumping on the landing tick with no slide keeps horizontal speed. The wiki implies ground friction is not applied if you jump immediately.
    - Costs 0 stamina.
    - You cannot bind jump to scroll: extra jump inputs in the air trigger the air jump or double jump and spend stamina.
    - Holding jump buffers the next jump only when you are out of stamina.
    - The wiki says perfect raw bhops beat slide hops only below about 900 u/s, and only with good strafing. Eskay says Celeste is the only hero for whom bhopping is effective.
    - *Medium confidence.*
22. **Crouch-jump.** No public source describes a crouch-jump height bonus or a distinct crouch-jump state. Crouching in the air is used only for slide storage and down dash (double-tap within 28 ticks). *No evidence either way. Do not invent it.*

### Caps and interactions
23. **No hard ground speed cap for momentum.**
    - The "movespeed diminish point" (10 → 11 m on 2026-03-06, 11 → 12 on 2026-05-22) is a **stat-stacking** rule. Move Speed *bonuses* stack diminishingly above that point, like resistances. It is not a velocity clamp.
    - Sprint speed stacks additively with no diminishing.
    - I found no source for a clamp on slide or hop speed. Friction and drag are the only limiters.
    - *Medium-high confidence.*
24. **Air strafing between hops.** This belongs to the air-control cluster; it is summarized here because it limits hops.
    - Leif: air acceleration limit ("air control") is 80. Above **700 u/s** horizontal speed it drops to 50 for most heroes.
    - The wiki names two convars, `citadel_aircontrol_speed_slow` and `_fast`, with a **450 u/s** threshold.
    - Turning too fast loses speed. Turning too slowly just gains less.
    - A double jump adds some horizontal acceleration based on the keys you hold.
25. **Sprint.**
    - Since **2026-05-22**, sliding no longer resets sprint speed. Before that it did.
    - A slide that decays into crouch, or that hits a wall and becomes crouch, still resets sprint, because crouching resets sprint.
    - Sprint only adds to walk speed and does not accelerate a slide. For heroes with high sprint (plus items), running speed can pass 350, so they can slide from a run and "crouch glide". *High confidence.*
26. **Shooting.** Infinite ammo while sliding (wiki). Firing does not end a slide. Several active items and abilities were patched so they no longer interrupt sliding, which implies that casting some abilities *does* end a slide unless flagged otherwise (2024-11-21, 2025-02-25, 2026-03-21, 2026-04-10). *High confidence.*
    - Forum thread 128840 (2026-04-24) confirms the slide shows an infinite-ammo icon. It also reports that if you were firing before a dash, the dash's fire lockout carries into the resulting slide (shooting is delayed), while not firing before the dash lets you fire at once. No dev reply; treat as observed behavior, medium confidence.

---

## Momentum: what conserves, adds, sets, caps, or decays speed

| Event | Effect on horizontal speed | Effect on vertical | Numbers | Confidence | Patch |
|---|---|---|---|---|---|
| Enter slide from run/sprint (above 350) | **Conserves** | — | threshold 350 u/s | high | current |
| Enter slide on slope | Conserves, then **gravity adds** downhill | — | none | high | current |
| Dash slide (crouch during ground dash, in or after DJ window) | **Sets** about 650 u/s regardless of bucket | — | 650 | medium-low (single source; above wiki peak dash speeds) | 2026-04 video |
| Dead slide (crouch before 0.3 s of dash) | Sets low, decays to about 270 | — | 270 | medium-low (single source) | 2026-04 |
| Mantle glide | **Adds/sets** about 550 u/s out of mantle | — | ~550 | high | 2025-05-08+ |
| Slide 0 to 0.75 s (1.0 s after DJ) | **Decays** slowly (friction 0.1875) | — | 0.1875 | medium | current |
| Slide after penalty onset | **Decays** fast (about 3.1875; about 0.6875 for DJ slide) | — | see rule 9 | medium | current |
| +Slide Distance item | Delays penalty by +0.25 s steps; no speed added | — | table | medium | current |
| W/A/D input during slide | **No change** to speed; steering by mouse and strafe, rate-limited | — | none | medium | 2026-05 |
| Jump out of slide (not flagged, or slide ≥ 0.5 s) | **Conserves** | sets 295 u/s up | 295 | medium-high | since 2026-03-06 for all slides |
| Jump out of flagged slide before 0.5 s | **Decays** heavily (air-drag penalty) | normal | unknown size | medium | observed 2026 |
| Land with crouch held (slide storage) | **Conserves** into new slide | — | — | high | current |
| Land without crouch, no jump | Ground friction → decays to run speed | — | not documented | high (qual.) | — |
| Raw bhop (jump on landing tick) | **Conserves** (no ground friction) | 295 up | — | medium | current |
| Air strafing | **Adds** a little speed when done well; loses speed if you turn too fast | — | accel limit 80 → 50 above 700 u/s (Leif) or 450 threshold (wiki) | medium | current |
| End of air dash (not into slide) | **Decays** (extra drag at dash end) | also | 20% (Leif only) | high (exists) / medium-low (20%) | since 2024 at least |
| IAD into slide | **Avoids** the end-of-dash drag (forum: chained IADs about 20% faster than normal air-dash sliding; a separate figure from the drag size) | — | ~20% net gain | medium | 2026 |
| Dash-jump | **Sets** 611 u/s (wiki) and ignores prior momentum; vertical impulse 425 | sets | 611 / 425 / 19 m | medium / high | vertical and distance 2026-06-30 |
| Downhill slide | **Adds** (gravity) | — | no cap known | high (qual.) | — |
| Bottom of ramp | Extra slide distance (tuned up 2024) | — | none | high (exists) | 2024-06-06 |
| Move Speed stat bonuses | **Diminishing stack** beyond 12 m/s | — | diminish point 12 | high | 2026-05-22 |
| Crouch spam | Brief progressive slowdown | — | none | high (exists) | 2024-09-26 |
| Slows (any) | Also raise air drag by 35% of slow value | — | 35% | high | 2026-09-16 |

---

## Known tech that depends on these rules

1. **Slide hop / Slide bunnyhop.** Hold crouch, then jump 0.5–0.75 s into each slide and land with crouch held.
   - Why it works: the low-friction phase resets with each new slide, and the jump keeps horizontal speed.
   - The first hop can be instant.
   - Costs 0 stamina.
   - Leif calls it the most fundamental skill in the game.
2. **Dash-jump slide bunnyhop.** Dash-jump (2 stamina), hold crouch in the air, slide on landing, then hop. The dash-jump slide's late penalty comes later (1.0 s) and is milder.
3. **Dash slide / Short Dash Crouch Cancel (SDCC) / short hop.**
   - Crouch during a ground dash, in or after the DJ window, to keep about 650 u/s in a slide.
   - A single scroll-wheel crouch plus an immediate jump gives a "short hop" that avoids a dead slide and does not set the slide-drag flag.
4. **Instant Air Dash (IAD).**
   - Press jump and dash on the same tick while moving. The game buffers the air dash. Then hold crouch.
   - The ground-hugging air dash lands into a slide before the 20% end drag applies.
   - Out of a slide, the dash is not buffered. You must release crouch and jump as the slide ends.
   - It can replace a bhop on landing. Chaining IADs also avoids the drag.
   - With Stamina Mastery (two air dashes), peak speed reaches about 900 u/s (wiki).
5. **Slide storage / Crouch storage.** Hold crouch in the air to slide instantly on any lip or ramp. Hold it before takeoff to never slide.
6. **Mantle glide / Mantle strafe.** Hold crouch through a mantle for about 550 u/s. Hold A or D for a 90° exit.
7. **Crouch glide.** At run speed of 376 u/s or more (from sprint items), tap crouch repeatedly to make short slides for evasion and infinite ammo.
   - You must re-press M1 each slide ("M1 lockout").
   - Crouch spam past a narrow window slows you (rule 7).
8. **Slope launch.** Downhill slides build speed, and jumping at the bottom carries it. Downhill jumping also clears the slide-drag flag.
9. **Hero and ability variants.**
   - Infernus Flame Dash Slide: cancel Flame Dash and slide. It is not bhop-eligible without re-pressing crouch in the air (slide storage).
   - Kelvin's Ice Path is slideable (2024-05-30).
   - Viscous Splatter gives +60% slide distance (2026-03-06).
   - Vyper Slither: +15% slide distance, can slide uphill, turns faster (2026-04-10).
   - Shiv M2 while sliding gives a small boost (deadlockmoves).

---

## Patch history affecting this (dated, official unless noted)

- **2024-05-30** Kelvin can slide down Ice Path.
- **2024-06-06** Crouch move speed 4 → 4.75. **Heroes slide farther when they reach the bottom of a ramp.**
- **2024-06-20 / 06-27 / 07-04 / 07-18** Slide Distance added to and tuned on Burst Fire (25 → 35 → 50%) and Fleetfoot (+25%, later +35%).
- **2024-08/09 (community)** Jumping out of a grounded dash slide on flat ground did not work. Jumping out of air-originated or ramp slides worked (forum threads 21810 and 30939).
- **2024-09-26** "Aggressive crouch spamming" causes brief progressive slowdown.
- **2024-11-21** Several actives no longer interrupt sliding. Zipline exit air drag 20 → 25%.
- **2025-02-25** Crouch toggle ends on a failed dash. Crouch locomotion was re-authored for faster speeds.
- **2025-05-08** Mantle Glide added officially: crouch while exiting a mantle gives a speed boost and a slide.
- **2026-02 (community)** Toggle-crouch users could not jump-cancel dash slides (thread 105871). A brief fix was reverted around 2026-02-24.
- **2026-03-06** **"Can now jump during slide."** Dash-jump gives +30% air control for 0.25 s. Move speed diminishing starts around 11 m (was 10).
- **2026-04-10** Vyper can move laterally sliding uphill. Casting abilities while sliding improved.
- **2026-05-22** **Sliding no longer resets sprint speed.** Movespeed diminish point 11 → 12.
- **2026-06-30** Dash-jump window 0.2 → 0.25 s (0.30 → 0.55 s). DJ distance 18 → 19 m. DJ vertical impulse 400 → 425.
- **2026-07-28** Bucket 3 ground dash 0.70 → 0.72 s, air dash 0.49 → 0.51 s.
- **2026-09-16** Slows also raise air drag (35% of slow value). A parry during a dash cancels the dash's momentum.

---

## Contradictions / uncertainties (and what recording would settle them)

1. **Entry threshold 350 vs 376 u/s.** Sliding, Crouching, Movement and Leif give 350. Crouch Gliding and Slide Bunnyhopping give 376. Possibly 376 is the practical speed needed to still be above 350 after a landing tick or a crouch-friction tick.
   - *Record:* with cl_showpos 1, sprint on flat ground with items giving run speeds of 355, 365 and 380, press crouch, and note which ones slide.
2. **Is slide-jump horizontal speed fully conserved?** No source gives a numeric loss for an unflagged hop.
   - *Record:* dash-jump, land into a slide, hop at about 0.6 s, and log speed on the last slide frame and the first air frame (cl_showpos).
3. **Slide-drag size, flag clear time, and whether the 0.5 s is measured from slide start.**
   - *Record:* chain hops at 0.3, 0.4, 0.5 and 0.6 s and log speed after each. Separately, stand or run on the ground for 0.1, 0.2 and 0.3 s between hops to find the clear time.
4. **Penalty friction for ordinary (non-dash) slides.** The wiki gives values only for dash and dash-jump slides.
   - *Record:* sprint-slide on flat ground with a high-sprint hero and log the speed curve across 0.75 s.
5. **Friction model form** (Source `speed -= max(speed, stopspeed)*friction*dt`, or exponential). Only coefficients are known. Also, is the dash-jump slide's 0.6875 an *onset* friction or a replacement? The same log from item 4 settles this.
6. **Slope behavior.** Minimum angle for a zero-speed slide start, downhill acceleration (should be g·sinθ minus friction), any terminal speed, and whether an uphill slide ends at zero speed or keeps sliding back.
   - *Record:* slide down two ramps of known angle from standstill and log speed vs time. Slide up a ramp and see what happens at zero.
7. **Slide steering rate.** Qualitatively limited (Slither "turns faster"). The value is unknown.
   - *Record:* a steady-speed slide with a fixed mouse sweep; measure the heading change per second vs camera change.
8. **Spec claim "ground slides cap forward momentum; air slides preserve it".** This comes from a Feb-2026 forum post written **before** the 2026-03-06 change. Leif's later framing explains the same observations as (a) the dash-slide set-speed (about 650) and dead slide, (b) the slide-drag flag, and (c) the 20% air-dash end drag. No source shows an explicit cap value.
   - Treat "cap" as unverified. Model it with rules 5, 13 and 20 instead.
9. **Dash-jump sets 611 u/s (wiki) vs "preserves dash momentum" (spec).** This belongs to the dash cluster. The wiki is explicit that the dash-jump ignores prior momentum.
10. **Air control threshold 450 (wiki) vs 700 (Leif).** This belongs to the air cluster. They may be two different quantities (strafing strength vs accel cap).
11. **Infinite ammo while sliding.** The wiki still states it. Electric Slippers has "Slide Fire Rate" (2026-03-21), which fits shooting while sliding. No patch removes infinite ammo.
    - *Record:* slide-shoot with an automatic weapon and watch the ammo counter.
12. **Raw bhop ground-friction window.** Is it exactly one tick, or is there a grace period?
    - *Record:* at about 600 u/s, jump on landing with delays of 0, 1, 2 and 4 ticks (using exec_async, as wiki editors do) and log speed.
13. **Crouch-jump.** Nothing found. Default to no special crouch-jump. A single recording of jump height with crouch held vs standing would confirm it.

---

## Evidence

1. https://deadlock.wiki/Sliding (wikitext via API). Wiki, revised 2026-06-19. Entry 350 u/s or ramp; friction 0.1875; penalty 0.75 / 1.00 s; penalty friction ~3.1875 / ~0.6875 (Altimor); item table; slide and crouch storage; infinite ammo; items add no speed.
2. https://deadlock.wiki/Bunnyhopping/Slide_Bunnyhopping. Wiki, created 2026-02-08, edited 2026-06-22. The pre-patch "flag" rule (dash slides not jumpable); under 0.5 s speed penalty; first slide exempt; 376 u/s needed.
3. https://deadlock.wiki/Bunnyhopping/Raw_Bunnyhopping. Wiki, 2026-02-08. Raw bhop is free; jump buffering when out of stamina; beats slide hop only below 900 u/s with strafing.
4. https://deadlock.wiki/Dashing/Instant_Air_Dash. Wiki, 2026-09-11. IAD removes the end-of-dash slowdown; with Stamina Mastery, about 900 u/s.
5. https://deadlock.wiki/Dashing/Dash_Sliding and https://deadlock.wiki/Dashing/Short_Dash_Crouch_Cancelling. Wiki. A ground dash can be cancelled into a slide at any time; cancel around the DJ-circle-blue timing; SDCC.
6. https://deadlock.wiki/Dashing/Dash_Jumping. Wiki. DJ sets 611 u/s and ignores momentum; DJ slide bunnyhop; coyote DJ.
7. https://deadlock.wiki/Crouching and https://deadlock.wiki/Crouch_Gliding. Wiki, 2026-02. Crouch 4.8 m/s; slide above 8.9 m/s; crouch glide at 376 u/s or more; crouch-spam slowdown; M1 lockout.
8. https://deadlock.wiki/Mantling/Mantle_Glide. Wiki. About 550 u/s out; crouch timing lenient.
9. https://deadlock.wiki/Move_Speed. Wiki. Diminishing stacking of move speed; sprint additive; sliding does not interrupt sprint, but slide into crouch does.
10. https://deadlock.wiki/Air_Strafing. Wiki. 450 u/s threshold; convar names.
11. https://deadlock.wiki/Movement. Wiki. Slide threshold 350 or incline; Slither "slide up hills, turn faster"; Friction section under construction.
12. https://deadlock.wiki/Update:March_6,_2026 and https://store.steampowered.com/news/app/1422450/view/519740319207522795. Official, 2026-03-06. "Can now jump during slide"; DJ air control +30% for 0.25 s; diminish ramp 11 m.
13. https://deadlock.wiki/Update:May_22,_2026 (source: Steam news 670617878982034052). Official, 2026-05-22. Sliding no longer resets sprint; diminish point 12.
14. https://deadlock.wiki/Update:June_30,_2026. Official, 2026-06-30. DJ window 0.25 s (0.3–0.55); distance 19 m; vertical impulse 425.
15. https://deadlock.wiki/Update:June_6,_2024 (forums 06-06-2024-update). Official. Slide farther at the bottom of ramps; crouch speed 4.75.
16. https://deadlock.wiki/Update:September_26,_2024. Official. Crouch-spam slowdown.
17. https://deadlock.wiki/Update:May_8,_2025. Official. Mantle Glide.
18. https://deadlock.wiki/Update:April_10,_2026. Official. Vyper lateral movement sliding uphill; casting while sliding improved.
19. https://deadlock.wiki/Update:September_16,_2026. Official. Slows affect air drag by 35%.
20. https://deadlock.wiki/Update:November_21,_2024. Official. Actives no longer interrupt sliding; zipline exit air drag 25%.
21. https://www.youtube.com/watch?v=5N_c34iRn74. "Movement Breakdown: Slidehopping", Leif, 2026-05-13 (auto-captions). Slide friction below air drag for 0.75 s, then about 1,500% worse; chained slides must last at least 0.5 s; "slide drag" flag set on any slide jump and cleared by ground time or a downhill jump; W does nothing; 0.25 s window.
22. https://www.youtube.com/watch?v=4pfFUdO31FU. "Movement Breakdown: Dash Cancels (aka shorthop)", Leif, 2026-04-13. Dash slide starts at 650 u/s for all buckets; dead slide if crouch before the DJ window (ends about 270); too late gives below 500; scroll short hop avoids the flag; on a downhill, crouching out of a dash gives a regular slide.
23. https://www.youtube.com/watch?v=MzXdg4OvzAw. "Movement Breakdown: Instant Airdash", Leif, 2026-05-06. IAD only avoids the air-dash drag by sliding; curb drop still applies 20%; about 1 u height change; IAD chaining.
24. https://www.youtube.com/watch?v=85EwLJT0xPo. "Movement Breakdown: Airdashing", Leif, 2026-04-29. Air dash removes 20% of total velocity at its end; removed for 2 s after a zipline crouch-drop; per-bucket accel limits; strafe-dash angles.
25. https://www.youtube.com/watch?v=lGrzMLOqjzE. "Movement Breakdown: Strafing", Leif, 2026-05-21. Slide speed unaffected by turning or inputs; air control 80, 50 above 700 u/s; strafe-hop technique; double jump adds horizontal accel.
26. https://www.youtube.com/watch?v=uCBrlTAPti4. "The Ultimate Deadlock Movement Guide", Eskay, 2026-03-12. Slide-hop timing 0.5 s, and early is worse than late; turn slides with forward held plus mouse; IAD; Celeste the only effective bhopper; mantle strafe 90°.
27. https://forums.playdeadlock.com/threads/jumping-out-of-slide.21810/. Official forum, 2024-08-28. Early slide-jump inconsistency (worked downhill, with speed items, or on a missed DJ timing).
28. https://forums.playdeadlock.com/threads/cannot-jump-out-of-a-slide-after-dashing-into-a-slide-otherwise-jumping-out-of-a-slide-works-fine.30939/. Official forum, 2024-09/10. Grounded dash slides could not be jumped out of; airborne-origin slides could.
29. https://forums.playdeadlock.com/threads/inconsistent-behaviour-for-jump-cancelling-a-slide.105871/. Official forum, 2026-02-06 to 03-06. Toggle-crouch dash slide jump bug, resolved in the 03-06-2026 patch.
30. https://forums.playdeadlock.com/threads/instant-air-dash-iad-what-it-is-how-it-works-and-why-its-probably-a-bug.105874/. Official forum, 2026-02 to 04. The ground-slide vs air-slide "cap" framing; about 20% IAD gain; reports of added drag on jumping out of ground-dash slides.
31. https://forums.playdeadlock.com/threads/gameplay-reproduction-steps-in-thread-vyper-cannot-change-direction-while-sliding-up-a-ramp.105944/. Official forum, 2026-02-06. Heroes can change slide direction on flat ground, downhill and uphill (Vyper excepted, fixed 2026-04-10).
32. https://deadlockmoves.com/fundamentals/. Community site, undated. Slide after DJ or mantle; 8.9 m/s threshold; Shiv M2 slide boost; short hop via scroll crouch.
33. https://beebom.com/deadlock-advanced-movement-guide/. Guide, 2024-10-10. Slope slides are easy; slide-jump extension (pre-2026, historical).

---

## Verification log (2026-09-27)

Adversarial pass. I re-fetched the cited evidence and searched for newer patches and contradicting reports. Public sources only.

**Newer patches.** deadlock.wiki/Updates lists nothing after 2026-09-16 (2026-09-09 was a crash-exploit fix and chat/ping cooldowns). I checked 2026-07-28, 08-12 and 08-22 for slide, crouch, jump, sprint, friction or air-drag lines. The only movement line was the bucket-3 dash timing (already recorded). The 2026-09-16 baseline stands.

**Confirmed by re-fetch (official patch text):**
- 2026-03-06 "Can now jump during slide"; DJ +30% air control for 0.25 s; diminish ramp 10 → 11 m.
- 2026-05-22 "Sliding no longer resets sprint speed"; diminish point 11 → 12.
- 2026-06-30 DJ window 0.2 → 0.25 s (0.3–0.55 s), distance 18 → 19 m, vertical impulse 400 → 425.
- 2026-04-10 Vyper lateral movement uphill; Slither +10 → +15%; casting while sliding improved; Haze could no longer slide during Bullet Dance (a fix).
- 2026-09-16 slows affect air drag by 35% of slow value; a parry during a regular dash cancels the dash and its momentum.
- 2024-06-06 crouch speed 4 → 4.75; slide farther at the bottom of a ramp.

**Confirmed by re-fetch (wiki, community-datamine):**
- Sliding: 350 u/s (8.9 m/s) or a ramp; friction 0.1875; penalty 0.75 s / 1.00 s (DJ); ~3.1875 / ~0.6875; +0.25 s per item step; infinite ammo; slide and crouch storage.
- Movement: 350 hu/s or an incline; Slither text; Friction section still "under construction".
- Move Speed: formula `12 × (1 − Π(1 − Bi/12))`; sprint additive; a slide into crouch or a wall resets sprint; no absolute speed cap.
- Air Strafing: 450 u/s threshold and the two convar names.
- Dash Jumping: 611 u/s, prior momentum discarded; window 0.3 s + 0.25 s.
- Mantle Glide ~550 u/s. IAD ~900 u/s with Stamina Mastery.

**Corrected or downgraded:**
1. **376 u/s / 10 m/s** (rule 1). It is internally inconsistent with the wiki's own 350 = 8.9 m/s conversion: 10 m/s would be about 394 u/s. Downgraded to low; 350 stays the rule.
2. **Air-dash end drag of 20%** (rule 20, table). The drag exists (high confidence: forum 11916 from 2024-07, forum 105874, wiki IAD). The **20% size is single-source (Leif)**. The forum's "~20%" is the IAD chain *speed gain*, not the drag size; the earlier table row mixed the two. Downgraded to medium-low and split apart.
3. **Dash slide 650 u/s / dead slide 270** (rule 5, table). Single source. The wiki Dash Sliding page has neither number, and 650 is above the wiki's listed peak ground-dash speeds (635/579/562). Downgraded to medium-low; put this near the top of the recording list.
4. **Electric Slippers.** The wiki item table lists it as +80% Slide Distance. Its penalty onset is still unmeasured; do not extrapolate.
5. **Slide Bunnyhopping wiki page is stale.** It still describes the pre-2026-03-06 "only certain slides are jumpable" flag and does not mention the patch. Rule 12 already treats this as historical, which is correct. Its 0.5 s penalty and first-slide exemption agree with Leif (2026-05) and Eskay (2026-03), so those are post-patch-corroborated.

**Added:** forum 128840 (2026-04-24). The slide shows an infinite-ammo icon (corroborates rule 26). If you were firing before a dash, the dash's fire lockout carries into the resulting slide. No dev reply.

**Not refuted but still unverifiable from public sources:** slide-drag magnitude and clear time; penalty friction for ordinary (non-dash) slides; the form of the friction equation; slope acceleration, minimum angle and terminal speed; slide turn rate; the raw-bhop friction window. No public source gives numbers for any of these. The Leif videos were confirmed to exist with the recorded titles and dates via search, but their transcripts could not be re-fetched in this pass.

**No invented caps found.** The file correctly states there is no known hard speed cap for slides or hops. The forum phrase "ground slides cap forward momentum" (2026-02) remains unverified and is pre-patch (see Contradictions 8).

**Is recording still the best next step?** Yes, for the numeric gaps above. Public research is close to exhausted: the wiki, the official forum and Leif's series are the deepest public sources, and none of them publishes those numbers. Recording your own gameplay with `cl_showpos 1` (observing the running game, not extracting files) is the right way to settle Contradictions 1–7 and 12, plus the 650 u/s and 20% figures above. Until then, implement the qualitative rules and mark those numbers as tunables, not limits.
