# Walls and ledges — behavioral model

Scope: wall jump (launch composition, input and camera effects, momentum), wall jump fatigue, wall-jump stamina and refunds, wall sliding, corner boost, edge boost, wall detection, mantle (activation, bands, glide, superglide, interactions), and ledge tech.
Current as of the 2026-09-16 patch. Research date: 2026-09-27. Clean-room: every claim comes from public sources (patch notes, deadlock.wiki, official forums, community guides). I read no game files. Where deadlock.wiki cites `abilities.vdata`, the source is tagged "wiki (community datamine)".

---

## How it works (plain language, as a movement player would explain it)

- **Wall jump.** Press jump while airborne and close to a wall. It does not use an air jump. You get one free wall jump per airtime. Each wall jump after that costs 0.5 stamina, and you can keep chaining them as long as you have walls and stamina. The launch is built from three parts: a fixed "up" part, a fixed "sideways" part, and a push along the wall's surface normal at the point on your capsule closest to the wall. WASD relative to the wall changes the shape of the launch:
  - Holding **into** the wall gives a steep, mostly vertical hop. The angle is always the same.
  - Holding **away** from the wall gives a long, flat, lateral leap.
  - **Neutral** falls between the two.
  - Players therefore use "into the wall" to climb and "away" to cross gaps.
- **Fatigue.** Wall jumping again within about 1.25 s of the last wall jump gives a weak vertical launch, and that fatigued jump restarts the 1.25 s timer. Landing clears fatigue. Fatigue only reduces the vertical part, so long lateral wall-to-wall chains still work, but "chimneying" straight up a shaft does not. Light or heavy melee used in the air also puts you into fatigue.
- **Air drag.** A wall jump puts you into the normal air-drag state, which the community describes as "significant". The zipline-dismount buff, which removes air drag, bypasses it.
- **Wall sliding.** When you fall while touching a wall, vertical fall speed is capped at 600 u/s ("terminal velocity"). Players use the slide to time a late wall jump.
- **Corner boost.** The wall-push direction comes from the closest point between your capsule and the geometry. Your capsule's lower hemisphere can touch the top edge of a ledge, a fence top, a signpost edge, or a curved surface. At that contact the normal points up and out, so the "push" is aimed upward and adds to the fixed up component. The result is a much taller, nearly vertical launch with no stamina cost. Valve treats it as accepted tech: they nerfed it (−20% velocity, 2025-10-02) rather than removing it. Common setups:
  - **Dropdown:** step or mantle onto a thin ledge, walk off, then wall jump as you pass the edge.
  - **Light-melee mantle:** light melee lets you approach closer before the mantle.
  - **Dash-jump:** start the dash-jump roughly 14–15 m out and arrive at the edge.
  - **Downdash:** jump off an edge, down dash back toward it, then wall jump.
- **Edge boost.** On a vertical edge, such as the side corner of a building, a wall jump as late as possible uses a normal that has swung toward your direction of travel. The wall jump then adds to your existing forward speed instead of killing it. The good window is 1–2 ticks.
- **Mantle.** Hold forward (WASD toward the ledge, required since 2025-04-04) and press or hold jump near a ledge. You climb in 0.2–0.5 s depending on ledge height and cannot act during the climb. You finish grounded, which refreshes air resources.
  - **Mantle glide:** hold crouch as the mantle ends and you pop out at about 550 u/s into a slide.
  - **Superglide:** jump as soon as you become actionable after a mantle glide to carry most of that speed into the air, where friction is lower. It costs no stamina. The exact tick window and how much speed you keep are not published. "Close to dash-jump speed" was an unsourced comparison, so don't treat it as a number.
  - **Glide wall jump:** a superglide next to a wall, which combines the glide burst with a wall jump.
  - **Fast climb:** wall jump while holding forward and holding jump. The held jump buffers a mantle that fires once the ledge is in reach, so you scale roughly air-jump-height walls for 0 stamina.
- **Stamina side effects** (combat only, since 2026-05-22):
  - A wall jump cuts stamina regeneration by 25% for 5 s. The penalty does not apply out of combat or if you mantle soon after the wall jump.
  - Paid wall jumps are refunded if a mantle or zipline attach happens within the stamina refund window (2025-10-03).

---

## Rules (numbered, precise, implementable)

**Wall jump — trigger and detection**
1. **Wall jump trigger:** the jump input is pressed while airborne and a wall is within the detection radius. It is available only in the air. [E1, E3] (high)
2. **Detection:** since 2025-05-08, the check considers all walls in a small radius around the player, not only the last wall touched. Radius: **unknown number** ("small radius"). [E6] (high qualitative / no number)
3. **Jump direction source:** the closest point on the world geometry to the player's collision capsule. The surface normal at that point (as seen from the rounded capsule) is the push direction. [E2, E4] (medium; community explanation, consistent with Valve calling it "corner boosting")
   - A console variable `citadel_wall_detection_style 2` exists as an alternate detection style, per the wiki's Edge Boost page. The default style is not stated. [E4] (low-medium)
4. **Same-surface rule:** since 2024-12-06 you cannot wall jump off the *same surface* multiple times in a row ("Fixed being able to wall jump off of the same surface multiple times").
   - Today the wiki says infinite wall jumps are possible, limited by stamina and fatigue.
   - Whether a same-surface lockout still exists alongside fatigue is **unverified**. Fatigue may have replaced it (2025-04 rework). [E12, E1] (low)
5. **Air-jump counter:** a wall jump does not consume the air-jump charge. [E1] (high)

**Wall jump — launch composition**

6. **Launch vector:** fixed upward component + fixed sideways component + wall-push along the contact normal ("set vectors" in the wiki diagrams). [E2] (medium; illustrative diagram, no numbers)
7. **Effect on existing velocity** (reset vs additive): **conflicting sources**.
   - The wiki Movement page says a wall jump "first sets the character's velocity to a fixed absolute value". [E3]
   - The Edge Boost page says you "stack" the wall-jump velocity with pre-existing velocity, and lose less forward speed than a regular wall jump. [E4]
   - Glide wall jumps and superglides "carry" the glide speed into the wall jump. [E17]
   - The 2025-04 forum report says you lose a lot of speed moving toward the wall but gain little moving away. [E14]
   - Best-fit model:
     - Velocity is **mostly set** on the wall-normal axis and the vertical axis.
     - The **tangential (along-wall) component of prior velocity is at least partly kept**. That is why edge boosts work: they rotate the normal so that more of your momentum counts as tangential.
     - Recording required. (low-medium)
8. **Input direction:**
   - Since 2025-04-04, lateral (kick-away) velocity is modified by WASD into or away from the wall. [E8]
   - Since 2025-05-08 there are **three distinct kick-away speeds: toward / away / neutral**. [E6] (high, qualitative)
   - **Toward** the wall: upward-angled jump, high vertical and low horizontal, and the angle never varies. [E1] (medium)
   - **Away**: outward jump, high horizontal and low vertical. Analog sticks give slight angle variation, which suggests the result is interpolated by input angle. [E1] (medium)
   - Original 2024-08-29 rule: an away input was *required*. The requirement was later relaxed; the 2024-09-12 patch says "activation more lenient", "angle can be steered a bit more". [E9, E10] (high)
   - Since the 2025-04-04 rework, a wall jump needs **no directional input at all**; neutral works. Several players reported this on 2025-04-07 and pointed to the patch notes. [E33] (medium-high)
   - On 2025-05-08 some players reported that "away" input had stopped working. The report was withdrawn a day later: both toward and away inputs work. [E30] (medium)
9. **Camera:** one community site (deadlockmoves.com) says camera direction determines wall-jump direction and recommends aiming 45° away from the wall while holding the opposite key for distance. [E15]
   - The wiki attributes the angle to movement keys relative to the wall. WASD is camera-relative, so both statements can be true. [E1]
   - A 2025-04 forum report, from before the 2025-05-08 rework, says fatigued jumps behave differently depending on whether the *character model faces the wall*. The same poster says the perpendicular push depends on whether the input vector, taken from the viewing angle, points into the wall. [E14] (low: one player, old patch)
   - Treat the camera as influencing only through the WASD vector, unless a recording shows the yaw acting independently of WASD. (low)
10. **Air drag after a wall jump:** the jump places you in "a significant amount of air drag". The zipline-momentum-conservation buff removes the same drag.
    - The wiki gives normal air drag as a friction coefficient of 0.2 (patch notes: "default in general is 20%").
    - Zipline dismount sets it to 0, then 0.25 after 2 s.
    - Whether a wall jump uses a *higher* drag than normal (> 0.2), or just re-enables normal drag, is unclear. [E1, E18, E19] (medium qualitative)
11. **Air control:** on 2025-05-08, air acceleration was raised "only while moving at lower speeds" to improve wall-jump control. Control over air dashes right after a wall jump was also fixed or improved. [E6] (high, no numbers)
12. **Mantle after a wall jump:** you can mantle ledges to the left or right of the wall-jump direction right after a wall jump (bug fix, 2025-05-08). [E6] (high)

**Fatigue**

13. **Fatigue** changes **vertical launch only** (since 2025-05-08; before that it presumably affected the whole launch). [E6] (high)
14. **Fatigue timing:**
    - Fatigue window: **1.25 s** after a wall jump (was 2 s before 2025-05-08). [E6] (high)
    - Wiki Wall Jumping page: a wall jump inside the window is weakened, and **the window is set back to 1.25 s**. [E1] (medium)
    - Wiki Movement page: "recovers non-linearly over 1.25 s", marked *citation needed*. [E3] (low)
    - Implementation choice: a timer reset to 1.25 on every wall jump. Launch strength when the timer is above 0 = f(remaining), with the curve unknown. The patch-note word "recovers" suggests a ramp rather than a hard step, which is a recording target.
15. **Fatigue reset:** landing fully clears fatigue. [E1, E3] (high)
16. **Fatigue from melee:** light and heavy melee used **airborne** both trigger fatigue. Ground melee triggering it was a bug fixed 2025-05-08. [E1, E6] (high)
    - The Fast Climb page says heavy melee "debuffs subsequent Wall Jumps for two seconds". This likely predates the 2 s → 1.25 s change, so use 1.25. [E16] (low)

**Stamina**

17. **Wall-jump cost:**

    | Period | First wall jump in the airtime | Each later wall jump |
    |---|---|---|
    | 2024-08-29 → 2025-10-02 | free | free |
    | 2025-10-02 → 2025-11-21 | free | 0.5 |
    | 2025-11-21 → 2025-12-17 | 0.25 | 0.5 |
    | 2025-12-17 → now | free | 0.5 |

    - The first wall jump is free "per sequence", i.e. per airtime. [E5, E11, E13] (high)
    - Fatigued wall jumps are not free. The wiki says they also cost 0.5 each. [E1] (medium)
18. **Stamina refund:** if a mantle or zipline attach happens within the stamina refund window, the wall jump's stamina is refunded (fix, 2025-10-03). Window length is not given; see the ground-dash research for the general refund window. [E20] (high qualitative)
19. **Regen penalty:** since 2026-05-22, stamina regen is −25% for 5 s after a wall jump. It does **not** trigger when out of combat or when mantling soon after. How the "combat" flag and "soon after" are defined is not public. [E7] (high)
20. **Superior Stamina / Stamina Mastery:** from 2024-11-21 the item gave +1 wall-jump count. Because wall jumps have been unlimited since 2025-04, this is probably obsolete. [E21] (medium)

**Wall slide**

21. **Wall slide:** while wall sliding, vertical terminal velocity applies. At **−600 u/s** gravity is cancelled, so fall speed stops growing. Horizontal speed is unaffected by this rule. The trigger conditions for "wall sliding" are not documented; presumably airborne, touching a wall, and falling. [E6] (high for the number, low for the trigger)

**Corner boost**

22. **Corner boost:** same code path as the wall jump. The normal is taken at the capsule-to-geometry closest point, so on an edge or a curve it tilts upward and produces a steep, high-vertical launch with near-zero horizontal speed. Behavior changes by patch:
    - 2025-05-08: "reduced effectiveness a bit". Some setups broke; for example, fences now result in a mantle onto the fence.
    - 2025-10-02: "Reduced corner boosting velocity by 20%". The mechanism is not stated. It may be a scale on the normal-push when the normal has an upward component, or a cap.
    - [E2, E6, E5, E22] (high that it exists; unknown magnitude)
23. **Best corner-boost surfaces:** edges between a horizontal and a vertical plane give the most height. Curved surfaces (roof domes, statues, hotdog stand) are near-optimal. [E2] (medium)
24. **Setting interaction:** the "cancel abilities with ability key" setting shortens a wall-bounce grace period and prevented corner boosts right after a jump. One player reported this on 2026-03-12, and another said it also affects ground and air jumps. No staff replied. It suggests **a short grace or buffer window exists for wall-jump input**, but the only evidence is players' own diagnosis. Its length is unknown, so do not implement a specific window length from this. [E23] (low)

**Edge boost**

25. **Edge boost:** a wall jump on a *vertical* edge, as late as possible. The normal swings toward your velocity direction, so the push adds speed along your travel direction instead of opposing it. There is no vertical-for-horizontal trade. The good window is about 1–2 ticks. [E4] (medium)

**Mantle — trigger and duration**

26. **Mantle trigger:** holding forward, meaning WASD toward the ledge (required since 2025-04-04), plus jump near a ledge. [E8, E24] (high)
    - Holding jump buffers the mantle, so it fires automatically once in range. The Fast Climb and Corner Boosting technique pages say this; the main Mantling page does not. [E16, E2] (medium)
27. **Mantle geometry** (wiki, community datamine):
    - The ledge must be at least **6 u** long (depth of the top surface).
    - Maximum distance from the ledge to start: **212 u**. This seems very large and is probably a horizontal+vertical reach or trace length; treat it as low confidence.
    - [E24] (medium / low)
28. **Mantle duration by ledge height:**

    | Ledge height | Duration |
    |---|---|
    | 32–64 u | about 0.2 s |
    | 64–96 u | 0.3 s |
    | 96–128 u | 0.4 s |
    | 128–160 u | 0.5 s |

    - The player is not actionable during the climb and ends in a grounded state. [E24] (medium)
    - The ground mantle costs 0 stamina. Whether an airborne mantle refunds a wall jump is covered by rule 18.

**Mantle — after the climb**

29. **Speed after a plain mantle:** a plain mantle "kills" momentum (qualitative). [E17] (medium)
30. **Mantle glide:** holding crouch (or crouch-toggle) when the mantle ends gives a small speed boost of about **550 u/s** outgoing, lower on steep curved tops. The timing is lenient: crouch only has to be held at mantle end. Keep holding crouch to continue into a slide.
    - Intentional; added 2025-05-08. [E6, E17] (high qualitative, medium number)
31. **Superglide:** after a mantle glide, jump as soon as you become actionable to carry "most of" the glide speed into the air, where there is less friction than on the ground. The wiki gives no tick window and no retention percentage, so do not invent one. Holding A or D makes a sideways variant. [E25] (medium qualitative, no numbers)
32. **Glide wall jump:** a superglide next to a wall combines the glide burst with a wall jump; sideways variants work. [E17b] (medium)
    - On 2026-08-23 a forum user asked Valve to remove wall jumping while sliding (the mantle-slide wall-jump boost). That shows the tech works on current builds. The only reply ("Not a bug") came from a regular forum member, **not** Valve staff or a moderator, so it is not an official ruling. [E26] (medium that the tech exists; low for Valve intent)

**Mantle — hit interactions**

33. **Mantle under melee:**
    - Since 2025-07-29, being meleed while mantling does not cancel the mantle. Instead it applies an 80% movement slow that tapers to 20% over 2 s.
    - Since 2025-11-21, if that slow is applied, mantle sliding right afterwards is not allowed.
    - Since 2026-09-16, slows also add air drag equal to 35% of the slow value. A toggle convar exists, so this is a deliberate, tunable rule.
    - The same 2026-09-16 patch says "All move slow values reduced by ~20% globally". It does **not** say whether that lowers the 80%→20% mantle slow, so treat the 80/20 numbers as possibly stale. [E28] (low)
    - 2025-11-21 also says "Slow debuff now prevents stamina usage and silences movement abilities". It is **unclear** whether this covers every move slow or only one specific debuff. If it covers every slow, paid wall jumps are blocked while slowed. [E11] (low)
    - [E27, E11, E28] (high for the quoted lines)
34. **Heavy melee and ledges:** heavy melee can mantle ledges (from the main spec; not re-verified here, low). During heavy melee recovery in the air, all momentum on both axes is cancelled "for a moment". [E29] (medium)

---

## Momentum: what conserves, adds, sets, caps, or decays speed

| Event | Horizontal (along-wall / tangential) | Horizontal (wall-normal) | Vertical | Source / confidence |
|---|---|---|---|---|
| Wall jump (fresh) | **Unclear**: probably mostly kept (edge boost "stacks") vs a full reset (wiki Movement) | **SET** to kick-away speed, which depends on input (toward / neutral / away) | **SET** to fixed up speed, plus the normal's vertical component | E1–E4, E6 — medium/low |
| Wall jump (fatigued) | same as fresh | same as fresh (fatigue does not affect lateral) | **SET, reduced** (curve unknown) | E6 — high qualitative |
| Wall jump input into the wall | — | low kick-away | high vertical, fixed angle | E1 — medium |
| Wall jump input away | — | high kick-away | low vertical | E1 — medium |
| Corner boost | small | small (the normal tilts up) | **large**; −20% since 2025-10-02 | E2, E5 — high qualitative |
| Edge boost | **ADDS** in the travel direction | — | normal wall-jump vertical | E4 — medium |
| After a wall jump (air) | **DECAYS** by air drag (normal drag, friction 0.2; ZMC can bypass it) | same | gravity | E1, E18 — medium |
| Wall slide | unchanged | — | **CAPPED** at −600 u/s (fall) | E6 — high |
| Mantle (plain) | **killed** / low at exit | — | ends grounded | E17 — medium |
| Mantle glide | **SET** to about 550 u/s at exit (forward) | — | 0 (grounded) → slide | E17 — medium |
| Superglide | keeps most of the glide speed into the air (lower air friction) | — | jump impulse | E25 — medium |
| Heavy melee recovery (air) | **ZEROED** | ZEROED | ZEROED | E29 — medium |
| Melee hit while mantling | not cancelled; 80%→20% slow over 2 s (may be about 20% weaker since 2026-09-16); no mantle slide; the slow adds air drag | — | — | E27, E11, E28 — high (slow magnitude now low) |
| Low-speed air accel (post-2025-05-08) | higher air accel below some speed threshold | — | — | E6 — high qualitative |

---

## Known tech that depends on these rules

| Tech | Inputs | Why it works | Patch notes |
|---|---|---|---|
| Wall-jump climb / "chimney" | alternate wall jumps up a narrow shaft | infinite wall jumps; fatigue limits vertical gain | Fatigue exists to "keep chimneying in check" (2025-05-08) |
| Long lateral leaps | wall jump holding away; aim about 45° off the wall | fatigue affects vertical only, so lateral chains keep working | 2025-05-08 |
| Fast climb | face the wall, hold W and jump, wall jump | the wall jump gains height and the held jump buffers a mantle; 0 stamina | Stamina penalty avoided if mantling soon after (2026-05-22) |
| Corner boost (regular, dropdown, light-melee mantle, dash-jump, downdash) | wall jump with the capsule touching an edge or curve | upward-tilted closest-point normal | −20% velocity (2025-10-02) |
| Edge boost | late wall jump at a vertical edge | the normal swings toward your velocity, so the push adds to your momentum | 1–2 tick window |
| Melee jump | heavy melee timed with a wall jump | gains height without spending an air jump | airborne melee causes fatigue |
| Mantle glide | hold crouch at mantle end | intentional exit boost of about 550 u/s | 2025-05-08 |
| Superglide | mantle glide, then jump as soon as actionable | air friction is lower than ground friction | — |
| Glide wall jump | superglide next to a wall | glide burst plus wall jump | still works per a 2026-08 forum post (the reply was from a non-staff member) |
| Mantle wall jump / mantle edge boost / mantle vent boost | chains after a mantle slide | same principles | deadlockmoves.com |
| Zipline momentum conservation into a wall jump | crouch-dismount the zipline, then wall jump | the ZMC buff removes the drag a wall jump applies | wiki |

---

## Patch history affecting this (dated)

**2024**
- **2024-05-16:** clips added to overpass ledges so players do not hit their heads while climbing (geometry only).
- **2024-08-29:** wall jump added. It costs no stamina, requires input *away* from the wall, and works once per airtime. Ropes added.
- **2024-09-12:** wall-jump activation made more lenient; launch angle can be steered more; McGinnis can no longer wall jump off Spectral Wall.
- **2024-09-26:** better wall-jump animations to show direction.
- **2024-11-21:** Superior Stamina gives +1 wall-jump count. Zipline-dismount air drag raised from 20% to 25% ("default in general is 20%").
- **2024-12-06:** fixed wall jumping off the same surface multiple times.

**2025**
- **2025-02-09 (forum):** extreme-height corner wall jumps reported as a glitch (the early form of the corner boost).
- **2025-04-04:**
  - Wall jump reworked: lateral velocity is modified by WASD into or away from the wall.
  - Mantle requires WASD toward the ledge.
  - Wall jumps no longer need a direction key (player reports, 2025-04-07).
  - Holding jump on a rope keeps you climbing.
  - Forum reports from 2025-04-04/05 describe multiple wall jumps without the item and strange second jumps. This is when multi-wall-jump with fatigue (2 s) appears to begin; the exact patch line is not found.
- **2025-05-08:**
  - Air acceleration raised at low speeds.
  - Kick-away speed varies for toward / away / neutral input.
  - Fatigue affects vertical only; window 2 s → 1.25 s.
  - Fixed ground melee triggering fatigue.
  - Wall detection considers all walls in a radius.
  - Corner boosting reduced "a bit".
  - Fixed mantling left or right after a wall jump.
  - Air dashes after a wall jump improved.
  - Mantle glide added.
  - Wall slide terminal velocity set at −600 u/s.
- **2025-07-29:** meleeing a mantling enemy applies an 80%→20% slow over 2 s instead of cancelling the mantle.
- **2025-10-02:** wall jumps after the first cost 0.5 stamina; corner boosting velocity −20%.
- **2025-10-03:** wall jumps are refunded if a mantle or zipline attach happens within the refund window.
- **2025-11-21:** the initial wall jump costs 0.25 stamina. Mantle slide is blocked after the melee mantle slow. A "Slow debuff" now prevents stamina use and silences movement abilities (scope unclear).
- **2025-12-03:** Billy's Chain Gang can no longer be broken by mantling.
- **2025-12-16/17:** the initial wall jump is free again.

**2026**
- **2026-03 (forum):** the "cancel abilities with ability key" setting shortens the wall-bounce grace period and breaks corner boosts.
- **2026-05-22:** stamina regen −25% for 5 s after a wall jump, only in combat and not if you mantle soon after. Entangling Bola no longer prevents jumping or mantling.
- **2026-09-16:** slows add air drag equal to 35% of the slow value, which matters after a melee on a mantling player. All move slows are reduced by about 20% globally.
- **No wall, mantle, or corner changes found** from 2026-06 to 2026-09-16. I scanned all 166 wiki Update pages.

---

## Contradictions / uncertainties (and what recording would settle them)

1. **Reset vs additive wall-jump velocity.**
   - Conflict: the wiki Movement page says velocity is "set to a fixed absolute value"; the Edge Boost page says the wall jump "stacks" with existing velocity.
   - Recording: wall jump off a flat wall at three approach speeds (walk, sprint, dash-jump), running parallel to the wall, with the same input (neutral). Log velocity per tick with `cl_showpos`.
   - If post-jump tangential speed scales with approach speed, the tangential part is kept. If it is constant, it is reset.
2. **Kick-away magnitudes** for toward / neutral / away, and the vertical speed for each.
   - Recording: standing wall jumps (zero approach speed) for each input, to read the peak horizontal and vertical velocity.
3. **Camera vs WASD.**
   - Recording: hold W with the camera at 0°, 45° and 90° to the wall; then hold S or A or D with the camera fixed.
   - This shows whether the launch depends on the WASD world vector alone or on camera yaw independently.
4. **Fatigue curve.**
   - Conflict: a binary 1.25 s window that resets on each attempt (Wall Jumping page) vs "non-linear recovery" (Movement page, citation needed; the patch-note verb is "recovers").
   - Recording: a second wall jump at 0.2 / 0.5 / 0.8 / 1.1 / 1.3 s after the first, with peak vertical speed measured each time.
5. **Wall detection radius, and whether the same-surface lockout (2024-12) still exists.**
   - Recording: approach the wall at increasing distances; try two wall jumps off a single flat wall.
6. **Corner boost magnitude and how the −20% is applied.**
   - Recording: peak height of a corner boost vs a normal wall jump on the same fence type.
7. **Wall-jump air drag.**
   - Recording: horizontal speed decay per second after a lateral wall jump vs after a normal jump at the same speed.
8. **Mantle reach "212 u" and the 160 u maximum height;** also what happens above 160 u (no mantle?).
   - Recording: ledges of known height, `cl_showpos` z before and after.
9. **Mantle glide exit speed (about 550 u/s):** fixed set, or a function of approach speed?
   - Recording: mantle glides from standing vs from a sprint.
10. **Wall slide trigger** (touching the wall, holding into it?) and whether horizontal friction applies.
11. **Wall-jump input grace window** implied by the ability-cancel setting report: how many ms after the jump press, or before wall contact, still triggers the wall jump.
12. **"Combat" definition and the "mantling soon after" window** for the regen penalty, and the refund window length.

---

## Evidence

- **E1** https://deadlock.wiki/Wall_Jumping (raw wikitext) — community wiki, last edited 2026-01-31. Supports:
  - Air-only; does not use an air jump; infinite wall jumps.
  - Cost 0 then 0.5.
  - Toward = high vertical, fixed angle; away = high horizontal, analog variation.
  - "Significant amount of air drag", bypassed by ZMC.
  - Fatigue window 1.25 s, reset on each fatigued attempt, cleared on landing; light and heavy melee in the air trigger it.
- **E2** https://deadlock.wiki/Wall_Jumping/Corner_Boosting — community wiki, edited 2026-08-02. Supports:
  - Closest point on the capsule determines the launch vector.
  - Fixed sideways and up vectors plus the wall push (diagram).
  - Five setup methods; dash-jump from about 14–15 m.
  - Best surfaces.
  - Quotes the 2025-10-02 −20%.
- **E3** https://deadlock.wiki/Movement — community wiki, edited 2026-06-12. Supports:
  - "Velocity reset" explanation of the corner boost.
  - Non-linear fatigue recovery (citation needed); heavy melee in the air causes fatigue.
  - Dropdown corner boost; melee jumping.
  - Mantle 80%→20% slow.
- **E4** https://deadlock.wiki/Wall_Jumping/Edge_Boost — community wiki, 2026-02-08. Supports: edge boost stacks with existing velocity; 1–2 tick window; `citadel_wall_detection_style 2`.
- **E5** https://deadlock.wiki/Update:October_2,_2025 (and the Steam discussion https://steamcommunity.com/app/1422450/discussions/0/591784051116992385/) — official patch notes mirror. Supports: 0.5 cost after the first wall jump; corner boost −20%.
- **E6** https://deadlock.wiki/Update:May_8,_2025 — official patch notes mirror. Supports:
  - Air accel at low speed; three kick-away speeds.
  - Fatigue vertical-only, 1.25 s (was 2 s); ground-melee fatigue bug fixed.
  - Multi-wall radius detection; corner boost reduced.
  - Mantle left/right fix; air-dash fix.
  - Mantle glide; wall slide −600 u/s.
- **E7** https://deadlock.wiki/Update:May_22,_2026; https://liquipedia.net/deadlock/Gameplay_Update_2026-05-22 (search snippet); https://deadlock.one/en/news/deadlock-gameplay-update-05-22-2026 — official patch notes mirrors. Supports: −25% regen for 5 s; exceptions for out of combat and mantling soon after.
- **E8** https://deadlock.wiki/Update:April_4,_2025; https://deadlockrank.com/news/deadlock-april-4-2025-patch-notes — official patch notes mirrors. Supports: WASD modifies lateral velocity; mantle requires WASD toward the ledge.
- **E9** https://deadlock.wiki/Update:August_29,_2024; https://steamcommunity.com/app/1422450/discussions/0/4760955347168939024 — official. Supports: original wall jump rules.
- **E10** https://deadlock.wiki/Update:September_12,_2024 — official. Supports: activation more lenient; launch steerable.
- **E11** https://deadlock.wiki/Update:November_21,_2025 — official. Supports: initial wall jump 0.25; no mantle slide after the melee slow.
- **E12** https://deadlock.wiki/Update:December_6,_2024 — official. Supports: same-surface fix.
- **E13** https://deadlock.wiki/Update:December_17,_2025; https://tracklock.gg/articles/deadlock-12-16-25-patch-notes — official/aggregator. Supports: initial wall jump free again.
- **E14** https://forums.playdeadlock.com/threads/wall-jump-bug.60655/ — official forum, player reports, 2025-04-08/09. Supports: momentum loss toward the wall; facing dependence; fatigued input oddities.
- **E15** https://deadlockmoves.com/fundamentals/ — community guide site, 2025–26. Supports: camera determines direction; 45° tip; edge boost, corner jump and mantle chain tech.
- **E16** https://deadlock.wiki/Wall_Jumping/Fast_Climb — community wiki. Supports: fast climb inputs, 0 stamina, heavy-melee "2 s" debuff (stale).
- **E17** https://deadlock.wiki/Mantling/Mantle_Glide — community wiki, 2026-06-19. Supports: about 550 u/s, lenient timing, plain mantle kills momentum.
- **E17b** https://deadlock.wiki/Mantling/Glide_Wall_Jump — community wiki. Supports: glide wall jump.
- **E18** https://deadlock.wiki/Ziplines/Zipline_Momentum_Conservation — community wiki. Supports: normal air-drag friction 0.2; zipline dismount 0, then 0.25 after 2 s.
- **E19** https://deadlock.wiki/Update:November_21,_2024 — official. Supports: zipline drag 20%→25%; "default in general is 20%".
- **E20** https://deadlock.wiki/Update:October_3,_2025 — official. Supports: wall-jump refund on a mantle or zipline within the refund window.
- **E21** https://deadlock.wiki/Update:November_21,_2024 — official. Supports: Superior Stamina +1 wall-jump count.
- **E22** https://forums.playdeadlock.com/threads/corner-boost-set-ups-dont-work-anymore.63509/ — official forum, 2025-05-09. Supports: fence and poster setups now mantle instead of boosting.
- **E23** https://forums.playdeadlock.com/threads/corner-boosting-prevented.117094/ — official forum, 2026-03-12/13. Supports: the ability-cancel setting shortens the wall-bounce grace period.
- **E24** https://deadlock.wiki/Mantling — community wiki (datamine refs), 2026-06-19. Supports: forward + jump, hold-to-buffer, 6 u, 212 u, height bands, not actionable, grounded end.
- **E25** https://deadlock.wiki/Mantling/Superglide — community wiki, 2026-01-25. Supports: superglide mechanics.
- **E26** https://forums.playdeadlock.com/threads/mantle-slide-wall-jump-boost-tech.158459/ — official forum, 2026-08-23. Supports: mantle-slide wall-jump tech is live. The "Not a bug" reply is from a regular member, not staff.
- **E27** https://deadlock.wiki/Update:July_29,_2025 — official. Supports: melee on a mantling player gives an 80%→20% slow instead of a cancel.
- **E28** https://deadlock.wiki/Update:September_16,_2026 — official. Supports: slows add air drag.
- **E29** https://deadlock.wiki/Heavy_Melee — community wiki. Supports: airborne heavy-melee recovery zeroes all velocity; air lunge peak 797 u/s.
- **E30** https://forums.playdeadlock.com/threads/the-new-wall-jump-system.63460/ — official forum, 2025-05-09/10. Supports: the toward/away input requirement changed over time; both inputs work after 05-10.
- **E31** https://forums.playdeadlock.com/threads/wall-jump-chaining.60337/ and https://forums.playdeadlock.com/threads/wall-jump-bugged-infinite-jumps.60298/ — official forum, 2025-04-04/05. Supports: multi-wall-jump appears with the 2025-04-04 rework.
- **E32** https://forums.playdeadlock.com/threads/dash-walljumping-boost-glitches.55560/ — official forum, 2025-02-09. Supports: corner height glitch predates the name.
- **E33** https://forums.playdeadlock.com/threads/walljumps-no-longer-require-a-direction-key-to-perform.60526/ — official forum, 2025-04-07/09, player posts only. Supports: after the 2025-04-04 rework, wall jumps need no directional input.

Not reachable: YouTube pages (no description or transcript returned), Reddit (not indexed by search), Liquipedia patch pages (403).

---

## Verification log (2026-09-27)

I checked this spec adversarially against public sources only.

**Re-fetched and confirmed as quoted**
- Patch notes (wiki Update pages):
  - 2024-08-29, 2024-09-12, 2024-11-21 and 2024-12-06.
  - 2025-04-04, 2025-05-08 (all ten wall, mantle and air lines), 2025-07-29, 2025-10-02 and 2025-10-03.
  - 2025-11-21, 2025-12-17, 2026-05-22 and 2026-09-16.
- Wiki pages:
  - Wall_Jumping: 0 then 0.5 cost; not an air jump; toward and away shapes; "significant" air drag; 1.25 s fatigue that is reset on each attempt and cleared on landing; both melees cause fatigue.
  - Movement: "sets the character's velocity to a fixed absolute value" (in the Corner Boost section); "recovers non-linearly".
  - Edge_Boost: "stack"; 1–2 ticks; `citadel_wall_detection_style 2`.
  - Corner_Boosting: closest point on the capsule; five setup methods; dash-jump from about 14–15 m; best surfaces.
  - Mantling: 6 u; 212 u; four height bands; not actionable; ends grounded; 0 stamina on the ground.
  - Mantle_Glide: about 550 u/s; lenient timing; a plain mantle kills momentum.
  - Superglide and Glide_Wall_Jump.
  - Fast_Climb: its heavy-melee "two seconds" is still on the page (last edited 2026-02-08), so it is stale.
  - Zipline_Momentum_Conservation: friction 0.2, then 0, then 0.25 after 2 s.
  - Heavy_Melee: momentum cancelled in the air; 797 u/s.
- Forum threads E14, E22, E23, E26, E30 and E31 were re-read.

**Newer patches checked:** there are no wall-jump, mantle, corner-boost or wall-slide changes in 2026-07-28, 2026-08-02, 2026-08-12, 2026-08-22, 2026-09-09 or 2026-09-16. The 2026-09-16 patch is the latest on the wiki Updates page as of today.

**Corrections made**
- The glide wall jump "Not a bug" reply came from a regular forum member, not a moderator. It is no longer treated as a Valve ruling.
- Superglide: "first actionable tick" became "as soon as actionable". The source gives no tick window. The "close to dash-jump speed" claim was removed as unsourced.
- Rule 8: added the 2025-04-04 change (no directional input needed) and the retracted 2025-05-08 report that "away" input had broken.
- Rule 17: fatigued wall jumps also cost 0.5.
- Rule 26: the hold-jump mantle buffer is now cited to the technique pages, not the main Mantling page.
- Rule 33: flagged that the 2026-09-16 global ~20% slow reduction may make the 80%→20% mantle slow stale. Also flagged the unclear scope of the 2025-11-21 line saying a slow debuff prevents stamina use.
- Rule 34: heavy melee cancels momentum "for a moment", on both axes. Heavy melee mantling ledges is marked not re-verified.
- Rule 24: lowered to low confidence. The evidence is one player's diagnosis with no staff reply. Do not implement a grace-window length from it.
- Rule 9: added the camera-related claim from the E14 poster, at low confidence.

**Still unresolved (recording or further research needed)**
- Wall jump reset vs additive, and kick-away magnitudes. No public numbers exist.
- The fatigue curve (binary vs ramp).
- Detection radius.
- Whether the 2024-12 same-surface lockout still applies.
- Corner-boost magnitude.
- Wall-jump drag value.
- The 212 u mantle reach.
- The mantle-glide speed source.
- Wall-slide trigger.
- The "combat" definition, the "soon after" window and the refund window.

**Sources I could not use:** YouTube pages returned no description or transcript, and Reddit was not surfaced by search, so no creator video evidence was added. A community page (steamdb.com mechanics, built from game-client data by a third party) had no numbers, and I did not use it.
