# Air — behavioral model

> Clean-room research record (2026-09-27). Built only from public sources: official patch notes (forum / wiki Update mirrors), deadlock.wiki (including its Movement-wiki tech pages, which absorbed the old dlmovement.wiki), official forum threads, and community guides. No game files or client inspection. Quotes are short and paraphrased where possible. Current patch at time of writing: 2026-09-16.
>
> Units: u = hammer unit = 1 inch = 0.0254 m. 100 u/s = 2.54 m/s.

---

## How it works (plain language, as a movement player would explain it)

- **You have a small budget of air actions per airtime**: by default one air jump and one air dash (Stamina Mastery adds one more), plus one down dash (tracked separately from air dash). The first wall jump per airtime is free. Everything resets when you land (and on zipline attach).
- **Air dash is not "set my velocity"**. The ground dash hard-sets your speed. The air dash pushes you in a direction, and how much speed you end up with depends on how that direction lines up with what you already had. The movement wiki describes a directional **speed cap (~700 u/s, ~900 u/s with Stamina Mastery)**. It only applies to movement in the same direction you are already going. The cap is community-measured (the "~" is theirs), not an official number, and the exact formula is our model. So dashing *straight forward* while already fast gains you nothing and can even feel like a slowdown. Dashing *at an angle* to your current velocity stacks the two and pushes you past the cap ("strafe dashing").
- **During an air dash, gravity and air friction are switched off.** You fly flat. When the dash window ends, gravity and air friction come back, and there is an **end-of-dash drag** that bleeds the burst speed off quickly. That end-of-dash slowdown is the thing skilled players try to avoid.
- **The main trick for avoiding it is landing before it hits.** If you air dash right next to the ground (jump and dash on the same tick = Instant Air Dash, IAD) and hold crouch, you touch down and go into an **air slide** while you still have full dash speed. Air slides keep momentum, and you can jump or dash out of them. Ground-dash slides are different: they cap forward momentum, and jumping out of one gets heavy air drag.
- **Air strafing exists but is weak**, much weaker than in CS/TF2. It is noticeably stronger below ~450 u/s and weak above. At high speed it mostly turns you and adds little or no speed. Heroes have separate **Air Control** and **Air Acceleration** stats (Celeste has large bonuses), and a dash-jump gives +30% air control for the first 0.25 s.
- **Air drag is real and tunable.** Normal airborne horizontal drag has a published friction coefficient (0.2). Zipline crouch-dismount turns it off for 2 s. Slows increase it (since 2026-09-16). That is why long flights shed speed, and why the fastest routes chain ground contact (slides) rather than staying airborne.
- **Air jump** costs 1 stamina and is used to extend height and reshape your arc. It has a "distance" stat (Stamina Mastery +23%). Public sources do **not** say whether it sets or adds vertical velocity, or what it does to horizontal speed. This needs measuring.
- **Down dash** (double-tap crouch in air, 0.44 s window) fast-falls you for 0.5 stamina (was 1 before 2025-12-29). Its speed is not published.
- **Landing** does not deal damage and does not wipe your speed if you land into a slide. Without a slide, normal ground friction takes over. Raw bunnyhopping (jump on the landing tick) exists and is viable below ~900 u/s with good strafing. That implies no special landing speed reset beyond ground friction, and a lenient jump buffer (holding jump works).

---

## Rules (numbered, precise, implementable)

Confidence tags: [H] high, [M] medium, [L] low. "Q" = qualitative only, "N" = has numbers.

### Air action budget
1. Per airtime: `air_jumps = 1`, `air_dashes = 1`, `down_dashes = 1` by default. Stamina Mastery: "an additional use of Air Jump or Air Dash before landing" (item text). The wiki Dashing/Jumping/Movement pages each say "two" for each action. **Treat as +1 to each counter** until measured. [M, N] (E3, E4, E5, E14)
2. Down dash uses a **separate counter** from horizontal air dash: a down dash and an air dash can both be done in one airtime (reported 2024-06, not contradicted since). [M, Q] (E18)
3. All counters reset on landing and on zipline attach (existing spec). A dash-jump executed as a coyote dash-jump (after leaving a ledge, inside the window) **does not consume an air action**. You keep your air jump and wall jumps. [M, Q] (E9)
4. Seraphim Wings (legendary, **Street Brawl mode only**) makes extra air dash/jump **unlimited** (2026-03-06 per patch mirrors; the wiki's own 2026-03-06 page excerpt did not show the line). Some abilities grant unlimited air dashes while active (Grey Talon Rain of Arrows). [H, Q] (E22, E25)

### Air dash
5. Input: dash while airborne + movement direction. Cost 1 stamina. [H] (E3)
6. **Duration** (the "burst" phase) by bucket: B1 0.43 s, B2 0.47 s, B3 0.51 s. Only the **B3 value is publicly confirmed**: the 2026-07-28 notes change B3 air dash time 0.49 → 0.51 s (and B3 ground dash 0.70 → 0.72 s). The B1/B2 air values come from the existing spec and were not found in any public source during verification. Note: the wiki Dashing page's 0.62 / 0.68 / 0.70 s figures are **ground** dash times (B3 there is stale; now 0.72). The "~8 m for all buckets" and implied burst speeds (≈732 / 669 / 618 u/s) are derived, not published. [B3: H, N; B1/B2 and speeds: M/L, N] (E21, E3, existing spec)
7. **During the burst: gravity = 0 and air friction = 0.** After the burst, gravity and air friction are re-enabled, and an **end-of-dash drag** is applied. Source is one forum analyst (CDranzer, 2026-02-06) plus a 2024 forum report by Altimor ("drag is applied at the end of an airdash"); no official statement. The wiki Mechanics page (edited 2026-09-12) says an air dash works like a regular dash but with "less slowdown at the end", so ground dashes also have an end slowdown and the air one is milder. [M, Q] (E1, E2, E20)
8. **Velocity application** (best current model, needs recording to lock):
   - The dash is an impulse that "can stack or conflict" with prior momentum (wiki). [H, Q] (E3)
   - The wiki states a speed cap of **~700 u/s (~900 with Stamina Mastery)** that "only applies to movement in the same direction as your current velocity", and that dashing at an angle adds speed beyond it. The "~" values are community measurements, not official. **The projection axis is our interpretation**: the page does not say whether the capped component is measured along the dash direction or along the current velocity. Modelling it as `v_par = dot(v, d)` along the dash direction, with `v_perp` left alone, is the simplest reading that matches the described behaviour. [cap existence and values: M, N; axis and formula: L] (E7)
   - Consequence: dashing forward while already above the cap produces a *slowdown*. Dashing at an angle keeps `v_perp` and adds a capped `v_par`, so total speed can exceed the cap. [M, Q] (E7)
   - Suggested implementation (hypothesis A):
     `v_par_new = max(min(v_par + J, C), min(v_par, C))`, where J is the dash impulse and C scales with air-dash distance bonus. `v_perp` is unchanged. Vertical velocity is zeroed/held for the burst (gravity off). Hypothesis B, "set `v_par = C` exactly", also fits the "slowdown when dashing forwards" note. See Uncertainties U1.
   - Note: ~700 u/s is close to the B1 burst speed (≈732 u/s), and 700 × 1.30 (the old Stamina Mastery +30%) ≈ 910. That suggests **the cap is the dash speed itself, scaled by the air-dash-distance bonus** (current bonus +23%, so ≈860 u/s today). [L, inference]
9. Air-dash-distance modifiers: Stamina Mastery +23% (since 2026-01-30. The official line reads "Air Dash distance reduced from 30% to 23%" and does not mention air jump, but the current item shows one combined "+23% Air Jump/Dash Distance" stat; was +30% 2025-05-19 → 2026-01-30, +25% on 2025-05-08, +30% from 2024-08-29, +40% originally). Dash-slow effects reduce dash distance (−10% global reduction to ground-dash slows on 2026-09-16; air-dash slows not mentioned). [H, N] (E14, E24, E26)
10. Air dash right after a wall jump has improved control (2025-05-08 fix). The exact mechanism is unpublished. [H, Q] (E23)
11. Parry is allowed during an air dash, and was before 2026-04-10 (ground dash was brought "in line with air dashing"). The 2026-09-16 parry-cancels-momentum rule is worded for **regular (ground) dash** only. [H, Q] (E27, E28)

### Instant Air Dash (IAD)
12. Input: jump and dash on the **same tick** (the forum calls it frame-perfect; players bind jump+dash to mousewheel). If you are late you get a normal jump-dash; if you are early you get a ground dash. Possible since a change around 2024-08-21 that allowed jump and air dash on the same tick. [M, Q] (E1, E2)
13. Effect: the dash happens so low that you land (with crouch held → air slide) **before the end-of-dash drag applies**. The slide inherits near-full burst speed. Chained IAD → air slide → IAD gives about **+20%** speed over normal air-dash sliding (forum, 2026-02-06; one author's estimate, not a measured figure). Wiki: **without items, a single IAD is slower** than a regular dash, air dash or dash-jump. Its value comes from chaining. A good IAD plus slide-bhop gives about a dash-jump's distance at half the stamina (1 bar vs 2). Double IAD with Stamina Mastery peaks around **900 u/s** and covers about two dash-jumps of distance. [M, N] (E1, E6)
14. Status: the community calls it "probably a bug". There is no patch note targeting it as of 2026-09-16. Wiki IAD page last edited 2026-09-11 and still lists it as live universal tech. [M] (E1, E6)

### Down dash
15. Input: double-tap crouch while airborne; the second press must come within **28 ticks (0.44 s)**. [H, N] (E3)
16. Cost: **0.5 stamina since 2025-12-29** (was 1). The wiki Stamina page value of 1 is stale. A bug report dated **2026-01-20**, with four other players confirming through 2026-01-25, says down dash still needs at least 1 full bar available even though it only spends 0.5. No fix was posted in that thread, and no later patch note mentions one. Current status is unknown, so do **not** replicate the ≥1 requirement as a design rule. [cost: H, N; bug: M] (E16, E17)
17. Drives the hero downward ("return to the ground quickly"). The speed profile, and whether horizontal velocity is kept, are **unpublished**. [L] (E4)

### Air jump (double jump)
18. Cost 1 stamina; 1 per airtime (see rule 1). [H] (E4, E5)
19. Has a "distance" attribute scaled by Stamina Mastery (+23% air jump/dash distance). This implies either a fixed launch velocity or a horizontal component. [M, Q] (E14)
20. Vertical: **unknown whether it sets or adds**. No public source states it. (An earlier search snippet from steamdb.com said air jumps "reset your trajectory". On re-fetch (2026-09-27) the page no longer contains that text, so it is **withdrawn as evidence**.) [unverified] (E19 withdrawn)
21. Horizontal: **unknown**. No public source says an air jump redirects or kills horizontal speed. [unverified]

### Ground jump and gravity
22. Ground jump: free; peak vertical speed 295 u/s; max height +45 u (wiki). Implied gravity ≈ 295² / (2·45) ≈ **967 u/s²** (24.6 m/s²). Inferred. [M numbers / L derived] (E5)
23. Gravity scale is a per-hero and per-item stat: Celeste −25% (was −20% → −28% → −25% during 2026-02/03), Ivy −10%, Seraphim Wings −70%, Magic Carpet −15%. **Movement Silence forces gravity scale to 120%.** A 2026-09-16 debuff "increases gravity" during its duration. [H, N] (E10, E11, E25)
24. Wall sliding: vertical fall speed is capped at **−600 u/s** ("at −600 u/s gravity is cancelled out", 2025-05-08). **There is no published free-fall terminal velocity.** [H, N] (E23, E20)
25. No fall damage. [H] (existing spec)

### Air strafing / air control
26. Classic Source-style air strafe (release W, hold A/D, turn the mouse the same way). It is much weaker than in other Source games. [H, Q] (E8)
27. Two regimes separated at **450 u/s**. Below it air strafing is "considerably stronger", above it weaker. The wiki names two separate tunables (`citadel_aircontrol_speed_slow` / `_fast`). [M, N] (E8)
28. 2025-05-08: "Air Acceleration has been increased … but only while moving at lower speeds" (for wall-jump control). This is consistent with rule 27. [H, Q] (E23)
29. Air strafing at high speed **redirects without adding speed** (Strafe Dashing page: "The air strafe does not add speed"). Raw bunnyhop can beat slide-hop only below 900 u/s with good strafing, which implies some speed gain at low speed. [M, Q] (E7, E13)
30. Heroes have **two separate air stats**: *Air Control* and *Air Acceleration* (Celeste: Air Control +44%, Air Acceleration +10% to +18%, figures conflict; see U7). These are independent of gravity scale. [H, N] (E10, E11, E12)
31. Dash-jump grants **+30% air control for 0.25 s** after takeoff (2026-03-06). Holliday's Bounce Pad grants allies air control (2026-03-25). [H, N] (E11, E29)

### Air drag / high-speed decay
32. There is a **horizontal air drag** term while airborne. Published friction coefficient: **0.2** (normal). [M, N] (E15)
33. Zipline crouch-dismount: drag coefficient **0 for 2 s**, then **0.25**. The page prose says "5% extra air drag". This most likely means +0.05 absolute on the coefficient (0.20 → 0.25), not a 5% relative increase, so the two statements agree. This is our reading; the page does not say it. Also unstated: whether 0.25 is permanent until landing or decays back to 0.2. [M, N] (E15)
34. Slows add air drag: **+35% of the slow value** (2026-09-16). So a 50% slow gives +17.5% drag, assumed multiplicative on the coefficient. [H, N] (E28)
35. Jumping out of a **ground-dash slide** applies a very large air drag. This rests on a **single forum reply** (van17ino6, 2026-04-12, in the E1 thread, page 2), which speculates it was added in response to IAD. No official line, and no second report found. The Slide page's footnote does show separate *ground* slide frictions: 0.6875 for dash-jump slides vs 3.1875 for grounded dash slides. That supports "dash slides are penalised" generally, but not the airborne drag claim itself. **Do not implement as a hard rule without recording** (U12). [L, Q] (E1, E31)
36. Air dash burst phase: drag = 0 (rule 7). End of burst: extra drag (rule 7). [M]

### Landing
37. On landing all air counters refresh. Stamina regen is per-bar and not tied to grounded state in patch notes. One guide claims regen is faster while grounded. Unverified. [L] (E30)
38. **Crouch held while landing** (slide storage) with speed at or above the slide threshold, or on a slope → an **air slide** that preserves horizontal momentum and can be cancelled by jump or dash. The Slide page also describes a distinct "Crouch Storage" state in which you "will never slide" regardless of speed. The exact input difference from slide storage was not resolved in this pass; see the slide doc. [M, Q] (E1, E31)
39. **Ground-dash slide** caps forward momentum and has stronger momentum cancellation (forum analysis; also consistent with the 3.1875 dash-slide friction on the Slide page). Jumping out of it is allowed since 2026-03-06, but it reportedly carries heavy drag (rule 35, single source). The Slide Bunnyhopping page (edited 2026-06-22) still says dash sliding does not set the slide-bhop flag. [M, Q] (E1, E31, E13)
40. Slide-bunnyhop penalty: slides shorter than **0.5 s** give a large speed penalty, except the first slide in a chain. The "flag" enabling slide-bhop is set by slide conservation or dash-jumping. [M, N] (E13)
41. Landing without crouch: normal ground friction applies. Nothing published indicates a special landing speed clamp. Raw bunnyhop is possible by jumping on ground contact, and holding jump buffers the landing jump. [M, Q] (E13b)
42. Slide threshold for landing slides is **conflicting**: 350 u/s (8.9 m/s) on the Slide page vs **376 u/s (≈9.6 m/s, "10 m/s")** on the Mechanics, Slide Bunnyhopping and Crouch Gliding pages. [M, N] (E31, E13, E20, E32)

---

## Momentum: what conserves, adds, sets, caps, or decays speed

| Action / state | Horizontal | Vertical | Cap / decay | Source | Conf. |
|---|---|---|---|---|---|
| Ground jump | conserves (no documented change) | sets ~295 u/s | gravity ≈967 u/s² (derived) | E5 | M |
| Air jump | **unknown** (likely conserves; "distance" stat suggests a component) | **unknown** (set likely) | — | E4, E14, E19 | L |
| Dash-jump | **sets** 611 u/s, prior momentum discarded | set (value unpublished) | +30% air control 0.25 s; slide penalty later | E9, E11 | M |
| Air dash (burst) | **impulse that stacks with prior momentum; community-reported cap ~700 u/s (~900 SM) applies only to the "same direction" component; angled dashes exceed it** (exact axis/formula = our inference) | held (gravity off) | air drag off during burst | E3, E7, E1 | M (cap) / L (formula) |
| Air dash end | **decays**: end-of-dash drag, then normal air drag | gravity resumes | — | E1, E2, E6 | M |
| IAD | same as air dash, but landing before end-drag carries ≈ full burst speed into air slide | — | +~20% over normal air-dash slide chain; ~900 u/s peak with SM | E1, E6 | M |
| Down dash | unknown | adds/sets downward (unpublished) | — | E4 | L |
| Air strafe <450 u/s | **adds** (stronger) | — | — | E8, E23 | M |
| Air strafe >450 u/s | mostly **redirects**, little/no gain | — | — | E7, E8 | M |
| Airborne, no input | **decays** by air drag (coef 0.2) | gravity | slows add 35% of slow % to drag | E15, E28 | M |
| Zipline crouch-dismount | **conserves** (drag 0 for 2 s, then 0.25 = 0.2 + 0.05) | gravity | — | E15 | M |
| Jump out of ground-dash slide | **decays hard** (heavy air drag), single forum reply only | — | — | E1 (p.2) | L |
| Wall slide | — | **capped** at −600 u/s | — | E23 | H |
| Land with crouch (air slide) | **conserves** into slide; jump/dash-cancellable | — | slide friction 0.1875, late-slide penalty (see slide doc) | E1, E31 | M |
| Land into ground-dash slide | **capped** | — | stronger cancellation | E1 | M |
| Land without crouch | ground friction | 0 | no documented landing clamp | E13b | L |
| Slide-bhop slide <0.5 s | **large penalty** (not on first slide) | — | — | E13 | M |
| Movement Silence | — | gravity scale forced 120% | — | E10 | H |

---

## Known tech that depends on these rules

| Tech | Inputs | Why it works | Rules |
|---|---|---|---|
| **Instant Air Dash (IAD)** | Jump + dash on the same tick (mousewheel bind common), hold crouch | The dash starts at ground height, so you land during the burst (gravity is off only for the burst). The air slide inherits full speed before the end-of-dash drag | 7, 12–14, 38 |
| **IAD chain / slide-bhop** | IAD → air slide ≥0.5 s → jump → IAD… | Air slide keeps momentum and is jump/dash-cancellable; slides ≥0.5 s avoid the bhop penalty | 13, 38, 40 |
| **Strafe Dashing** | Turn ~45–50° (low speed) up to ~90° (high speed) off your velocity, then air dash (sideways, or forward and air-strafe back) | The cap only applies along the dash direction, so the perpendicular component survives and total speed exceeds the cap | 8, 29 |
| **Dash-jump → air dash** | Dash-jump, then air dash immediately | Stacks the 611 u/s set with the air dash; works best when angled (strafe dash) | 8, E9 |
| **Coyote dash-jump** | Ground dash off a ledge, jump inside the window | Counts as a dash-jump, not an air action, so the air jump and wall jumps are preserved | 3 |
| **Zipline Momentum Conservation** | Latch the line, crouch-dismount while rising | Air drag is disabled for 2 s, so you fly far; Stamina Mastery air-dash bonus helps rollouts | 33 |
| **Raw bunnyhop** | Jump on landing (hold jump to buffer), air strafe | Strafe gain below 450 u/s plus ground friction skipped on the landing tick; beats slide-bhop only <900 u/s | 27, 29, 41 |
| **Fast fall** | Double-tap crouch in air | Down dash for 0.5 stamina: land sooner to refresh air actions, break line of sight | 15–17 |
| **Stalker's Mark air-dash carry** (Drifter) | Cast, air dash, ambush during dash | The teleport keeps air-dash momentum (shows momentum is stored as velocity, not as a scripted path) | 8 |
| **Air dash + wall jump** | Wall jump, then air dash | 2025-05-08 improved control of air dashes right after wall jumps | 10 |

---

## Patch history affecting this (dated)

| Date | Change | Source |
|---|---|---|
| 2024-06 (approx.) | Down dash and air dash are separate counters (player report) | E18 |
| 2024-07-04 | Superior Stamina: +30% Air Dash/Air Jump distance | E26 |
| 2024-07-18 | Air-dash end drag bypass by landing documented (curb-height only) | E2 |
| ~2024-08-21 | Jump and air dash possible on the same tick → IAD reproducible anywhere (player-reported change) | E2 |
| 2024-08-29 | Wall jumping added; Superior Stamina air jump/dash distance +40% → +30% | E24 |
| 2025-05-08 | Air Acceleration increased at lower speeds; improved air-dash control after wall jump; wall-slide terminal −600 u/s; Superior Stamina → Stamina Mastery (distance 30 → 25%) | E23, E14 |
| 2025-05-19 | Stamina Mastery air jump/dash distance 25 → 30% | E14 |
| 2025-10-02 | Jump shooting lockout 0.15 → 0 s; −10% accuracy for 0.15 s; wall jumps after first 0.5 stamina; corner boost −20%; input buffering for dash | E33 |
| 2025-12-29 | **Down dash cost 1 → 0.5** | E16 |
| 2026-01-30 | Stamina Mastery air distance 30 → 23% | E14 |
| 2026-02-13 | Celeste Air Acceleration 25 → 18% | E12 |
| 2026-03-06 | Jump during slide; dash-jump +30% air control 0.25 s; Seraphim Wings extra air dash/jump → unlimited; Celeste gravity/air control retune | E11, E22 |
| 2026-03/04 | Community: jumping from a ground-dash slide gets heavy air drag | E2 |
| 2026-03-25 | Holliday Bounce Pad grants allies air control | E29 |
| 2026-04-10 | Parry during ground dash allowed "in line with air dashing" | E27 |
| 2026-07-28 | B3 air dash 0.49 → 0.51 s | E21 |
| 2026-09-16 | Slows add air drag = 35% of slow value; parry cancels regular dash momentum; dashes no longer pause gun cycle | E28 |

---

## Contradictions / uncertainties (and what recording would settle them)

Test setup (from the main spec): private lobby, `cl_showpos 1`, `host_timescale 0.25`, 120+ fps capture, frame-count. Built-in commands only.

- **U1 — Air dash velocity formula (highest priority).** Is `v_par` set to C, or `v_par + J` clamped to C? Does dashing forward above the cap *reduce* speed to C (the wiki implies "slowdown")? Is the vertical velocity zeroed or held?
  *Record:* (a) air dash from a standing jump; (b) forward air dash at ~400 u/s and at ~900 u/s (post-zipline or dash-jump); (c) 90° sideways dash at ~600 u/s. Log velocity per frame. If (b) at 900 drops to ~700, the cap clamps down. If (c) yields about sqrt(600² + C²), the perpendicular component is preserved.
- **U2 — End-of-dash drag.** What is its shape (instant cut to some fraction, or a temporary high drag coefficient), and how long does it last?
  *Record:* horizontal speed for 1 s after the burst ends (no input, high jump so no landing).
- **U3 — Air jump.** Does it set or add vertical velocity? Is its height the same as the ground jump? What does it do to horizontal speed, including redirect toward WASD? What does "+23% air jump distance" scale?
  *Record:* air jump at apex, while rising, and while falling fast (walk off a tall ledge); air jump with W vs S vs neutral at ~600 u/s. Compare peak heights with and without Stamina Mastery.
- **U4 — Down dash.** Speed, duration, whether horizontal is kept or zeroed, and whether there is an end drag.
  *Record:* z-velocity and horizontal speed per frame.
- **U5 — Air drag form.** The coefficient 0.2 is published, but is drag linear (`v -= v·k·dt`), Source-friction-like (with a stop speed), or quadratic? ("5% extra" vs 0.25 is best read as +0.05 absolute. See rule 33.)
  *Record:* free flight after zipline dismount (and >2 s later), and a normal long fall. Fit the decay curve.
- **U6 — Air strafe strength.** Actual accel values in each regime. Is 450 u/s a hard switch or a blend?
  *Record:* constant-turn strafe at 300, 450 and 600 u/s. Measure Δspeed/s and turn rate.
- **U7 — Celeste air stats.** The Celeste page says Air Acceleration +10%. The 2026-02-13 notes say 25 → 18%, and 2026-03-06 (wiki) says +50/18% → +38/12%. Air Control 44% vs 38%. This matters only for hero data; the page is probably out of sync.
- **U8 — Stamina Mastery counters.** Is it +1 shared air action, or +1 air jump AND +1 air dash? Item text is ambiguous; wiki pages imply both.
  *Record:* with SM, try jump-jump-jump and dash-dash-dash in one airtime.
- **U9 — Slide threshold on landing.** 350 vs 376 u/s. *Record:* land with crouch at controlled speeds.
- **U10 — IAD status.** It is a probable bug. Decide design-wise whether to replicate. It falls out of rule 7 naturally if gravity is off during the burst and end-drag is only applied while airborne.
- **U11 — Free-fall terminal velocity.** Only the wall-slide cap (−600 u/s) is published. *Record:* fall from max height and read z-velocity.
- **U12 — Dash-slide-jump heavy drag.** Community-only. *Record:* jump out of a ground-dash slide vs out of an air slide at the same speed; compare decay.
- **U13 — Dash-jump window length.** The Dash_Jumping page says 0.25 s; the Dashing page says 0.2 s (ground cluster, noted here because it feeds air speed).

---

## Evidence

| # | URL | Type | Date | Supports |
|---|---|---|---|---|
| E1 | https://forums.playdeadlock.com/threads/instant-air-dash-iad-what-it-is-how-it-works-and-why-its-probably-a-bug.105874/ | Official forum, community analysis | 2026-02-06 (replies to 2026-04-12) | Gravity + air friction disabled during burst, then re-enabled; IAD same-tick input; ~+20%; air slide conserves, ground slide caps; dash-slide-jump heavy drag (p.2) |
| E2 | https://forums.playdeadlock.com/threads/airdash-slowdown-can-be-circumvented-by-immediately-landing.11916/ | Official forum | 2024-07-18 / 2024-08-21 | Drag applied at end of air dash; landing first bypasses it; same-tick jump+dash change |
| E3 | https://deadlock.wiki/Dashing | Wiki | 2026 | Air dash is an impulse that stacks/conflicts; ground dash sets; down dash 28 ticks |
| E4 | https://deadlock.wiki/Movement | Wiki | 2026 | Air jump 1 stamina; down dash 0.5; one per jump; SM → two |
| E5 | https://deadlock.wiki/Jumping | Wiki | 2026 | Ground jump 295 u/s, +45 u; air jump 1 stamina |
| E6 | https://deadlock.wiki/Dashing/Instant_Air_Dash | Wiki (movement tech) | edited 2026-09-11 | IAD removes end slowdown; ~900 u/s with SM double dash; ≈ dash-jump distance at half cost |
| E7 | https://deadlock.wiki/Dashing/Strafe_Dashing | Wiki (movement tech) | edited 2026-09-11 | Directional cap ~700 (~900 SM) along dash direction only; angled dash exceeds it; air strafe only redirects; optimal angles |
| E8 | https://deadlock.wiki/Air_Strafing | Wiki (movement tech) | edited 2026-02-08 | 450 u/s threshold; weaker than Source; two aircontrol tunables |
| E9 | https://deadlock.wiki/Dash_Jumping | Wiki | 2026 | Dash-jump sets 611 u/s; coyote dash-jump not an air action; window 0.25 s (conflicts) |
| E10 | https://deadlock.wiki/Gravity_Scale | Wiki | edited 2026-07-01 | Gravity scale values; Movement Silence → 120%; Air Control/Acceleration separate stats |
| E11 | https://forums.playdeadlock.com/threads/03-06-2026-update.114328/ ; https://deadlock.wiki/Update:March_6,_2026 | Official patch notes | 2026-03-06 | Jump in slide; dash-jump +30% air control 0.25 s; Celeste gravity/air control |
| E12 | https://deadlock.wiki/Update:February_13,_2026 ; https://deadlock.wiki/Celeste | Official notes mirror / wiki | 2026-02-13 | Celeste air accel 25→18%; current page values |
| E13 | https://deadlock.wiki/Slide_Bunnyhopping | Wiki (movement tech) | edited 2026-06-22 | <0.5 s slide penalty; flag from slide conservation/dash-jump; 376 u/s |
| E13b | https://deadlock.wiki/Raw_Bunnyhopping | Wiki (movement tech) | edited 2026-02-08 | Raw bhop faster than slide bhop only <900 u/s; hold jump to buffer; no stamina |
| E14 | https://deadlock.wiki/Stamina_Mastery | Wiki | 2026 | +23% air jump/dash distance; additional air action; history 25/30/23% |
| E15 | https://deadlock.wiki/Ziplines/Zipline_Momentum_Conservation | Wiki (movement tech) | 2026 | Air drag coef 0.2; dismount 0 for 2 s then 0.25; "5% extra" prose |
| E16 | https://forums.playdeadlock.com/threads/12-29-2025-update.95233/ | Official patch notes | 2025-12-29 | Down dash cost 1 → 0.5 |
| E17 | https://forums.playdeadlock.com/threads/unable-to-down-dash-using-5-stamina-bar-unless-minimum-1-stam-bar.97807/ | Official forum bug report | 2026-01-20 (bumps to 01-25) | ≥1 bar needed to down dash; 4 confirmations; no fix posted |
| E18 | https://forums.playdeadlock.com/threads/downward-air-dash-interaction-intended-superior-stamina-description.5865/ | Official forum | 2024-06-13 | Down dash and air dash separate counters |
| E19 | https://steamdb.com/en/deadlock/mechanics/dashes | Community site | re-fetched 2026-09-27 | **Withdrawn**: page no longer contains the "reset your trajectory" line; overview only |
| E20 | https://deadlock.wiki/Mechanics | Wiki | edited 2026-09-12 | Down dash 0.5; wall slide −600 u/s; slide 9.6 m/s |
| E21 | https://deadlock.wiki/Update:July_28,_2026 | Official notes mirror | 2026-07-28 | B3 air dash 0.49 → 0.51 s |
| E22 | https://deadlock.one/en/news/deadlock-gameplay-update-march-6-2026 (search snippet) | Patch mirror | 2026-03-06 | Seraphim Wings extra air dash/jump → unlimited |
| E23 | https://deadlock.wiki/Update:May_8,_2025 | Official notes mirror | 2025-05-08 | Low-speed air accel increase; air dash after wall jump; wall slide −600 u/s |
| E24 | https://www.shacknews.com/article/141236/deadlock-patch-notes-2024-08-29 | Patch mirror | 2024-08-29 | Wall jump added; Superior Stamina 40 → 30% |
| E25 | https://deadlock.wiki/Update:October_2,_2025 (Rain of Arrows); Grey Talon note in E24 | Official notes | 2024–2025 | Ability-granted unlimited air dashes |
| E26 | https://deadlock.wiki/Update:July_4,_2024 | Official notes mirror | 2024-07-04 | Superior Stamina +30% air dash/jump distance |
| E27 | https://deadlock.wiki/Update:April_10,_2026 | Official notes mirror | 2026-04-10 | Parry in ground dash "in line with air dashing" |
| E28 | https://deadlock.wiki/Update:September_16,_2026 | Official notes mirror | 2026-09-16 | Slow → air drag 35%; parry cancels regular dash momentum |
| E29 | https://deadlock.wiki/Update:March_25,_2026 | Official notes mirror | 2026-03-25 | Holliday Bounce Pad air control |
| E30 | https://metabot.gg/en/deadlock/guides/deadlock-movement-mechanics-guide | Community guide | 2026-07-25 | Dash burst "dies almost immediately" to friction; grounded regen claim (weak) |
| E31 | https://deadlock.wiki/Slide ; https://deadlock.wiki/Sliding | Wiki | edited 2026-06-19 | Slide storage (hold crouch in air); 350 u/s |
| E32 | https://deadlock.wiki/Crouch_Gliding | Wiki (movement tech) | edited 2026-02-08 | Slide threshold 10 m/s / 376 u/s |
| E33 | https://deadlock.wiki/Update:October_2,_2025 | Official notes mirror | 2025-10-02 | Jump lockout / inaccuracy; input buffering |
| E34 | https://deadlock.wiki/Movement/Character_Tech/Drifter/Stalker's_Mark_Air_Dash_Momentum_Conservation | Wiki (movement tech) | edited 2026-08-25 | Air-dash momentum survives teleport |

Not reachable: YouTube pages (metadata not fetchable, e.g. "The Ultimate Deadlock Movement Guide", "SPEED SECRET IAD"), Reddit (blocked), the Steam bunnyhop guide (HTTP 429). A follow-up pass through a browser could mine those.

---

## Verification log (2026-09-27)

Adversarial pass. Every cited page was re-fetched and checked for newer patches. The wiki Updates index and Steam/forum mirrors show **no patch after 2026-09-16**.

**Confirmed on re-fetch (unchanged):**
- Strafe Dashing (edited 2026-09-11): cap ~700 / ~900 SM, "same direction as your current velocity", angled dash exceeds cap, air strafe "does not add speed", angles ~50° / ~45° / near-perpendicular.
- IAD page (edited 2026-09-11): removes the end-of-dash slowdown; ~900 u/s with double air dash; 1 bar of stamina. The page itself does not call IAD a bug; that label comes only from the forum thread title.
- Forum E1 (2026-02-06): gravity and air friction off during the burst; frame-perfect same-tick input; ~20% (estimate); air slide conserves and ground slide caps.
- Forum E2 (2024-07-18 / 2024-08-21): drag at the end of the air dash; landing bypasses it; the same-tick jump+dash change.
- Air Strafing (edited 2026-02-08): 450 u/s regime split, two `citadel_aircontrol_speed_*` names, weaker than other Source games.
- Zipline Momentum Conservation (edited 2026-06-19): 0.2 / 0 / 0.25, "after two seconds".
- 2026-09-16 notes: slows affect air drag by 35% of slow value; parry cancels *regular* dash momentum; Bola increases gravity.
- 2025-12-29: down dash 1 → 0.5. 2025-05-08: low-speed air accel increase, air dash after wall jump, wall slide −600 u/s.
- 2026-03-06: jump during slide; dash-jump +30% air control for 0.25 s; Celeste gravity/air lines. 2026-02-13: Celeste air accel 25 → 18%.
- Dash Jumping: 611 u/s set, prior momentum disregarded, window 0.25 s starting 0.3 s in, coyote variant not an air action. The page also says dash-jump costs **2 bars**.
- Jumping (edited 2026-06-10): 295 u/s, +45 u, air jump 1 bar; nothing on set vs add.
- Gravity_Scale (edited 2026-07-01): values and Movement Silence 120% unchanged.
- Down dash / air dash separate counters (E18, 2024-06-13): still no dev reply and no contrary report found.
- Slide Bunnyhopping (0.5 s penalty, first-slide exception, 376 u/s) and Raw Bunnyhopping (<900 u/s, hold-jump buffer).

**Corrected / downgraded:**
- Rule 6: B1/B2 air dash times (0.43 / 0.47 s) are **not in any public source found**. Only B3 0.49 → 0.51 s is official. The Dashing page's 0.62 / 0.68 / 0.70 s figures are ground-dash times (B3 is stale there; now 0.72 s).
- Rule 7: added the Mechanics page wording that ground dashes also have an end slowdown and the air dash has "less" of it.
- Rule 8: the ~700/900 cap is community-measured, and the wiki's axis wording ("same direction as your current velocity") differs from our "along dash direction" model. The formula was downgraded to L.
- Rule 9: the 2026-01-30 official line names only "Air Dash distance". The combined air jump/dash stat comes from the item page.
- Rule 4: Seraphim Wings is Street Brawl only.
- Rule 13: added the wiki caveat that a single IAD without items is slower than a normal dash or dash-jump; the +20% is labelled an estimate.
- Rule 16: the bug report is dated 2026-01-20 (not 2025), with 4 confirmations and no fix found. Not a design rule.
- Rule 20 / E19: the "reset your trajectory" snippet no longer exists on the page. Withdrawn.
- Rule 33 / U5: "5% extra" is reconciled as +0.05 absolute (0.20 → 0.25). This is our reading.
- Rule 35: heavy post-dash-slide air drag rests on **one forum reply**. Evidence pointer fixed (E1 p.2, not E2). Kept at L and must not be implemented without recording.
- Rule 38: noted the Slide page's separate "Crouch Storage" (never slides) state.

**Could not verify / still open:**
- Air jump velocity behaviour (set vs add, horizontal effect); down dash speed; end-of-dash drag shape; air drag functional form; free-fall terminal velocity; air strafe accel values; Stamina Mastery counter semantics; 350 vs 376 u/s slide threshold (Mechanics page says 9.6 m/s ≈ 378 u/s).
- YouTube guides (e.g. "Deadlock 2026 Movement Guide (Featuring Leif)", 2026-03-05; "Movement Breakdown: Slidehopping", 2026-05-13; "How to MOVE Like a DEADLOCK PRO", 2026-02-27) were found by title, but their pages returned no description or transcript. Reddit returned no indexed threads for these mechanics. The BoostRoom guide (2026-02-28) is qualitative only.
- Unrelated to air physics, but noted: 2026-03-06 "move speed diminishing ramp now occurs around 11m" is a soft cap on move-speed *bonuses*, not on velocity. It must not be read as an air speed cap.

**Bottom line for the research question:** public sources are close to exhausted for the numeric shape of the air rules. The remaining unknowns (U1–U6, U11) are ones no public source states, so **in-game recording remains the best next step**. The one high-value non-recording lead is mining the three YouTube movement guides above with a real browser for transcripts.
