# Movement video guides: rules and numbers mined from public videos

Status: research only. No code was changed. Compiled 2026-09-27. The newest patch covered is 2026-06-30 (Leif's 6-30 patch video). The newest video is 2026-07-06.

Method: public auto-generated captions were read as text (YouTube timedtext, the same track that "Show transcript" displays), along with the video titles, dates and descriptions. No video was downloaded, no account was used and nothing was accepted. Clean-room: every rule below is paraphrased from what the creators say or show. No game files were read. Quotes are kept under 15 words. Timestamps are `m:ss` from the caption track. Auto-captions sometimes mangle words (for example "IED" for IAD, "Leaf" for Leif), and those are corrected silently.

Units: u/s = Source units per second. 1 m/s = 39.37 u/s. Gap IDs refer to `docs/design/movement_fidelity_gaps.md`.

Confidence tags follow the other specs. A tag of **V** means one expert creator states the rule on camera, usually while showing `cl_showpos` or a zero-gravity test. That is stronger than a wiki footnote and weaker than a recording of our own.

---

## 1. Source list

| # | Title | Creator | Date | ID / URL | Patch it reflects |
|---|---|---|---|---|---|
| V1 | Movement Breakdown: Airdashing | Leif | 2026-04-29 | [85EwLJT0xPo](https://www.youtube.com/watch?v=85EwLJT0xPo) | after 2026-03-06, before 2026-05-22 |
| V2 | Movement Breakdown: Instant Airdash | Leif | 2026-05-06 | [MzXdg4OvzAw](https://www.youtube.com/watch?v=MzXdg4OvzAw) | after 2026-03-06 |
| V3 | Movement Breakdown: Strafing | Leif | 2026-05-21 | [lGrzMLOqjzE](https://www.youtube.com/watch?v=lGrzMLOqjzE) | before 2026-05-22 |
| V4 | Movement Breakdown: Slidehopping | Leif | 2026-05-13 | [5N_c34iRn74](https://www.youtube.com/watch?v=5N_c34iRn74) | after 2026-03-06 |
| V5 | Movement Breakdown: Dash Cancels (aka shorthop) | Leif | 2026-04-13 | [4pfFUdO31FU](https://www.youtube.com/watch?v=4pfFUdO31FU) | after 2026-03-06 |
| V6 | Deadlock 2026 Movement Guide (Featuring Leif) | Deathy + Leif | 2026-03-04 | [EtHEtvBfC2M](https://www.youtube.com/watch?v=EtHEtvBfC2M) | **before** 2026-03-06 (recorded pre-patch) |
| V7 | The Ultimate Deadlock Movement Guide! - Beginner to Expert | Eskay | 2026-03-12 | [uCBrlTAPti4](https://www.youtube.com/watch?v=uCBrlTAPti4) | around 2026-03-06 (probably recorded before it) |
| **Additional (found in search and in Leif's channel and playlists)** | | | | | |
| V8 | A Guide to More Optimal Dash Strafing | Leif | 2025-10-20 | [yOouXhhSuRg](https://www.youtube.com/watch?v=yOouXhhSuRg) | after 2025-10-02. Stamina Mastery was then +30%. |
| V9 | Deadlock Dashes (and how to make use of 'em) | Leif | 2026-02-27 | [KFyjh2DAg1Y](https://www.youtube.com/watch?v=KFyjh2DAg1Y) | before 2026-03-06 |
| V10 | Movement Breakdown: Wall Strafing/Wall Boosts | Leif | 2026-07-06 | [3w1DAeZhP1E](https://www.youtube.com/watch?v=3w1DAeZhP1E) | after 2026-06-30 (newest) |
| V11 | Movement Breakdown: Cornerboosting | Leif | 2026-04-20 | [zdm7rwi5USs](https://www.youtube.com/watch?v=zdm7rwi5USs) | after 2025-10-02 nerf |
| V12 | Movement Breakdown: Edgeboosting | Leif | 2026-04-08 | [D8PiCCqQo5g](https://www.youtube.com/watch?v=D8PiCCqQo5g) | current |
| V13 | Deadlock Movement Guide - Edgeboosting | Leif | 2025-09-22 | [qeg7ZTR-EJk](https://www.youtube.com/watch?v=qeg7ZTR-EJk) | 2025-09 |
| V14 | Deadlock Movement Guide - Cornerboosting | Leif | 2025-10-04 | [DWLQUCbRheY](https://www.youtube.com/watch?v=DWLQUCbRheY) | right after the 2025-10-02 corner boost nerf |
| V15 | Everything to Know About Slides in Deadlock | Leif | 2025-11-11 | [nDRB492X0QA](https://www.youtube.com/watch?v=nDRB492X0QA) | 2025-11 |
| V16 | Deadlock Strafing 201: Key Concepts | Leif | 2026-02-14 | [9FaGYoXCGos](https://www.youtube.com/watch?v=9FaGYoXCGos) | 2026-02 |
| V17 | Patch videos: 11-21 / 3-6 / 5-22 / 6-30 | Leif | 2025-11-23 / 2026-03-07 / 2026-05-23 / 2026-06-30 | [cVWMolz2rOA](https://www.youtube.com/watch?v=cVWMolz2rOA), [NIVW_RBcHas](https://www.youtube.com/watch?v=NIVW_RBcHas), [sMACf70eIX4](https://www.youtube.com/watch?v=sMACf70eIX4), [vW3R_IBT7wk](https://www.youtube.com/watch?v=vW3R_IBT7wk) | each patch |
| V18 | Bunnyhopping / Strafing 208 / Stairs / Mantlestrafing | Leif | 2026-02-02 / 2026-02-18 / 2026-03-18 / 2025-10-06 | [XWrhjaPDol4](https://www.youtube.com/watch?v=XWrhjaPDol4), [2XpDnVfimH0](https://www.youtube.com/watch?v=2XpDnVfimH0), [GijpmKbGlTw](https://www.youtube.com/watch?v=GijpmKbGlTw), [UGopPhIB4ws](https://www.youtube.com/watch?v=UGopPhIB4ws) | as dated |

Skipped:
- Piggy, "The ULTIMATE Deadlock Movement Guide" (2025-09-22, LT_NIHF_25A). It uses swapped and nonstandard names ("wall bounce", "corner boost" for edge boost) and gives no numbers.
- Mobalytics (2024-10). Too old.
- Mxrphy and illarya route videos (EWErN67gPQ0, jczQ05XrGvA, -400qncgPLI). These are route showcases with no captions and no rules.

**Leif is the source for almost everything numeric.** He is a single expert, though a careful one: he uses `cl_showpos`, `sv_gravity 0` and `drawline` tests on camera. Treat his numbers as V (strong single source), not as H.

---

## 2. Per-video summaries

### V1. Movement Breakdown: Airdashing (Leif, 2026-04-29)
- 0:05. One air dash per jump, or two with Stamina Mastery (SM). Air dashes use the same three buckets as ground dashes.
- 0:17. The air dash **does not reset velocity**. It stacks with existing velocity, which also makes it weak for changing direction.
- 0:31. It accelerates in one direction **only up to a limit that differs per bucket**. The limit is bypassed by dashing at an angle away from the current motion ("strafe dashing").
- 0:49. At the **end** of the dash, a penalty removes **20% of total velocity**. This is a simplified wording; see V8/V9 for the exact rule. The penalty is skipped for **2 s after dropping off a zipline with crouch**, and by an IAD.
- 1:22. Angle guide (the angle is measured between the dash input and the current velocity):
  - No benefit from angling below about **300 u/s**.
  - About **350 u/s** (the minimum slide speed): 45–50°.
  - Just under **600 u/s** (a typical zipline drop): about **70°**.
  - Zipline dash with only A or D: turn 15–20° away. With W+A/D: turn about 30° toward.
- 2:25. With SM the best angles are slightly wider: 50–55° from a run, 75° off a zipline.
- 3:11. A wall boost needs wider angles, because the wall supplies more acceleration.
- 3:28. **B1 wants slightly wider angles than B2/B3 because its dash is faster.**
- 4:20. Drill: strafe for about 1 s after a zipline drop, then dash at 75–80°.

### V2. Movement Breakdown: Instant Airdash (Leif, 2026-05-06)
- 0:11. The only thing special about an IAD: across **flat ground**, holding crouch to start a slide avoids the end-of-dash drag penalty. It gives **no extra speed or distance** otherwise.
- 0:33. Any drop that makes you fall further after the dash, **even a curb**, brings the 20% penalty back.
- 0:58. Input: be moving, press dash and jump on the same tick, then hold crouch. The game buffers the air dash. If dash comes too early you get a ground dash. If it comes too late, the height changes too much.
- 1:36. In a good IAD the height rises by **about 1 unit** over the whole dash. A rise above **2–3 units** means the drag was not avoided.
- 1:52. An IAD out of a slide is not buffered the same way. You must release crouch and jump as soon as the slide ends, before walking friction slows you.
- 2:41. An IAD can replace a bhop: pressing jump and dash together on landing.
- 3:03. **Starting another air dash prevents the pending drag.** Hopping from one IAD straight into another IAD avoids it. A plain bhop out of an IAD still gets the drag.

### V3. Movement Breakdown: Strafing (Leif, 2026-05-21)
- 0:40. Air acceleration has a limit. Pressing a key in the direction of motion is capped at **80**, which is the character's **air control**. Angling the input away from the velocity bypasses the limit (Source-style).
- 1:20. A diagram shows a "lockout line": full acceleration is only gained when the input vector clears the current velocity. This is described as an estimate.
- 2:01. Strafing during a slide does nothing. Slide speed is the same with or without input.
- 2:45. **Above 700 u/s, air control drops from 80 to 50** for most characters. Only horizontal speed counts.
- 3:00. Turning with the keyboard is about the right strafe rate at about **500 u/s**. Turn faster below that and much slower above 700. Turning too fast can slow you, while turning too slowly just gains less.
- 4:07. Good strafing plus slide-hop timing can keep a slide-hop chain going "basically forever".
- 4:39. **You cannot strafe during an air dash. Velocity is locked in the dash direction until the dash ends.**
- 5:20. **A double jump adds some horizontal acceleration from the held movement keys.**
- 7:12. Overstrafing (input angle above 90°) is a controlled way to slow down or turn tighter.

### V4. Movement Breakdown: Slidehopping (Leif, 2026-05-13)
- 0:17. Slide friction is lower than air drag for the first **0.75 s**, then gets about 1500% worse.
- 0:34. When chaining, each slide must last **at least 0.5 s**. Jumping earlier applies an **air-drag penalty** ("slide drag").
- 0:47. **Any jump out of a slide sets a flag.** The flag stays until you spend a short time on the ground doing something other than sliding.
- 1:01. Recipe: land, slide 0.5 s, jump before 0.75 s. This is a 0.25 s window.
- 1:11. A slide needs at least **350 u/s** to start. Some characters run faster than that.
- 1:37. Movement keys do nothing in the air or during the slide.
- 2:13. **Jumping out of a slide while going down a slope removes the flag.**
- 2:35. The first slide of a chain does not need 0.5 s.

### V5. Movement Breakdown: Dash Cancels (Leif, 2026-04-13)
- 0:03. Crouch cancels a ground dash early into a special **dash slide** that has a friction penalty.
- 0:17. **A dash slide always starts at 650 u/s, even for slower buckets.**
- 0:24. A crouch **before the dash-jump window opens** gives a "dead slide" that loses speed. Jumping right after the dash slide starts keeps more than continuing it.
- 0:38. Crouch bound to the scroll wheel gives a crouch that is not held, so the bad slide cannot slow you.
- 1:21. Check: if the slide input is **too late**, speed is **below 500** at slide start. If it is **too early**, speed ends at **270** when the slide ends.
- 1:49. **A scroll-wheel short hop does not set the slide-hop flag**, so the first slide it lands into can be short without slide drag.
- 2:03. Crouching out of a dash down a slope gives a regular slide.

### V6. Deadlock 2026 Movement Guide (Deathy + Leif, 2026-03-04)
Deathy part (0:00–13:45):
- Stamina regen per hero: Mina 3.9 s, Infernus 4.5 s, Kelvin 5.5 s.
- **The first wall jump costs no stamina** and later ones cost a little. This was already outdated: from 2025-11-21 the first wall jump costs 1/4 bar (V17).
- IAD keeps you "actionable": you can shoot and parry during it. With SM, IAD is always better than regular dashes, and more so for B1.
- Vents: holding W goes straight, while A with mouse turning strafes a lot even on non-air-control heroes.

Leif part:
- 14:09. **The minimum air drag value is 0.2 in the console.** It is a fraction of velocity removed "each tick" (see the form discussion under G08).
- 14:16. At the end of an air dash you lose about 20% of total velocity. This is treated as air drag.
- 14:24. After leaving a transit line with crouch you are **immune to air drag for 2 s**. This is why zip dashes are strong.
- 14:41. A true IAD leaves you grounded, so sliding immediately avoids the penalty.
- 14:57. **Slide friction 0.1875, and 0.175 for dash slides.** This is pre-2026-03-06; V17 says dash slide went to about 0.6 on 03-06.
- 15:06. Jumping before 0.5 s after landing into a slide from a slide hop gives a large air-drag penalty. After a long slide, friction goes above 3.0.
- 15:34. Holding W with zero gravity accelerates you to **80 u/s**, the default air control limit. The best strafe angle is typically **85–90°**.
- 16:07. An air dash in the direction you are already moving can give **no speed at all**, only the 20% drag. From a run, angle about **50°**. Faster speeds approach 90°.
- 16:45. Strafing or strafe-dashing into walls at an angle generates velocity (the wall boost).
- 17:01. **Wall jumps can be done for a brief time after losing wall contact.** An edge boost is a wall jump done after sliding off the end of a wall: **"the wall jump's impulse to be added to their existing velocity"**, like an angled wall jump. It can be triggered by a walk-off with one jump input. It is harder at high speed but still useful.
- 17:45. A mantle-jump input can also trigger a wall jump if you are airborne at the end of the mantle.
- 18:27. Dash cancel by double-crouch or scroll. A short hop is useful to space edge boosts, because dash distance cannot be shortened any other way.
- 19:05. **Corner boost: a wall jump on the upward-facing edge of a floor, giving greatly increased height.** It only works while in contact. Too early or too late fails, usually as a wasted double jump, sometimes as a normal wall jump.
- 20:26. **Mantle slide can go anywhere within a 180° cone** centred on your facing when the mantle starts.
- 21:07. Map collision often differs from the visuals. Slanted ledges keep contact longer and can even be surfed.

### V7. The Ultimate Deadlock Movement Guide (Eskay, 2026-03-12)
- 6:42. You can turn in a slide by holding forward and moving the mouse slowly.
- 7:05. The slide-jump timing is 0.5 s. Jumping too early is much worse than jumping too late.
- 7:44. Wall jump timing is lenient: you can slide down a wall and still wall jump as long as you have not touched the floor. Early presses become a double jump.
- 8:03. **The wall jump direction depends on the key held and where you look.** Facing the wall with W, you land much closer to it than with S.
- 8:19. **"Wall jumps carry momentum."** A dash jump perpendicular to a wall then a wall jump keeps your speed and adds a bit of height plus a nudge in the held key's direction.
- 8:51. Zipline crouch-drop: for about the first half of the fall you barely lose height, then after about 1 s you drop fast. A double jump then carries the speed further. This is an observation, not a number.
- 11:21. An air dash done diagonally or sideways is faster than one done straight forward.
- 12:07. **IAD = jump and dash on the same tick.** Because you are so close to the ground, no air friction is applied. Slide entry is faster than normal.
- 13:08. Crouching off a zipline on the same tick you attach gives a huge burst. This is rarely reproducible.
- 13:32. Heavy melee: you keep momentum while charging, so use it on the way up.
- 14:02. Mantling within a very short window after a double jump refunds that stamina.
- 14:14. **No limit on the number of wall jumps before landing. Each one after the first costs half a bar.** A wall jump done too soon after the previous one gives **no height and no distance**. The required delay is slightly longer than a double jump or a dash.
- 14:47. **Edge boost** gives more speed and distance than a normal wall jump. It works at any corner, and best when you are already sliding or dashing, because it keeps more momentum.
- 15:07. **Corner boost** gives a huge extra height from the right spot on an edge.
- 16:17. "Wall sliding" here means **air-dashing diagonally into a wall**, which gives more speed than a plain air dash. This is the same thing as V10's wall boost.
- 17:23. A 1-stamina slow dash jump: dash, slide, jump out of the slide.
- 17:46. A mantle slide can go in any direction if you face forward at the start. Left or right gives a 90° slide.
- 18:47. Majestic Leap gives 100% air control until landing.
- 19:28. SM increases the double jump and air dash distance, so every dash tech gets stronger.

### V8. A Guide to More Optimal Dash Strafing (Leif, 2025-10-20). The most numeric source.
- 0:28. **Air control acceleration is 80 by default and drops to 50 above 700 u/s. The highest speed air control can reach in one direction is 80 u/s**, shown with gravity off. Holliday's bounce pad (+100% air control) gives 160.
- 0:59. Air control cannot exceed the move speed. The minimum move speed equals the best air control speed, so **slows do not weaken strafing**.
- 1:11. **Lockout cone:** air-dash with gravity and drag off, hold W and turn the camera. Velocity does not change until the input is **about 80°** from the velocity. The cone grows with speed.
- 1:40. The keyboard turn rate is about optimal at **480–500 u/s**.
- 2:00. Strafing off a Holliday pad tops out at about **760 u/s**, because air control drops to 50 at 700.
- 2:10. **Air dash acceleration is not instant. It happens over about 0.13 s.**
- 2:16. **Dashing in the same direction as your velocity cannot go above 732 u/s for B1, 670 for B2 and 642 for B3.** These values are the dash's acceleration. **SM raised them by 30%** at the time; the current bonus is +23%.
- 2:38. **End penalty: up to 20% of the speed above 80 u/s is removed, but not below 480 u/s (about 12 m/s).** So when your speed is more than about 80% of the dash acceleration, a same-direction dash slows you. A zip dash has no penalty.
- 3:01. When you are faster than the dash acceleration, the dash must be **more than 60°** from the velocity to add speed.
  - The best angle is about **75°** when speed equals the dash acceleration.
  - The best angle approaches **90°** as speed nears 2× the acceleration, and **60°** as speed nears 0.5×.
- 3:34. **B1 above 800 u/s cannot gain speed from an air dash** (with the drag), and only breaks even at about **78°**. The only way around this is a drag-free dash (a zip dash).
- 3:47. Zipline drop speed is between **250 and about 590 u/s**, depending on how closely your facing matches the line direction. With a zipline speed boost it is sometimes closer to 700.
- 3:56. Between 400 and 600 u/s with no drag, **every bucket gets the best acceleration at about 65°**.

### V9. Deadlock Dashes (Leif, 2026-02-27)
- 0:19. **Dash jumps and slide cancels set velocity to the same value for every bucket.**
- 0:42. A ground dash resets existing velocity and always gives the same velocity.
- 0:48. **During an air dash you neither gain nor lose altitude.** The character accelerates quickly over a short time.
- 1:09. **At the end of an air dash, 20% of the speed above 480 is removed.** This is an air-drag penalty, so the zipline crouch window prevents it. Compare V8's "above 80, floor 480".
- 1:41. Only an IAD directly into a slide **on a level surface** avoids the penalty. Even tiny elevation changes break it.
- 1:58. Hopping after an IAD does not avoid the penalty, except by doing another IAD immediately.
- 2:26. Dash cancel: scrolling crouch once cancels the dash with no animation.
  - **A dash cancel can never exceed the character's ground dash velocity.** This makes it better for B1 than B3.
  - Note: this is before 03-06. It conflicts with V5's 650 u/s for every bucket, unless the 650 is the slide velocity and the cancel-jump carries the dash speed.
- 3:03. **A dash hop is a frame-perfect jump at the end of a dash. It beats a short hop for distance** and can chain into a true IAD.
- 3:20. Without items, a ground dash beats an IAD from a standstill. This changes with SM. When reversing direction, IAD is much worse. Going uphill, an IAD is impossible.

### V10. Movement Breakdown: Wall Strafing/Wall Boosts (Leif, 2026-07-06)
- 0:17. Against a wall, the same strafe angles apply, but **the velocity vector is held parallel to the wall**. Holding input into the wall avoids the air-accel lockout, and the acceleration is **redirected along the wall**.
- 0:51. Normal strafing has a sweet spot between the lockout and 90°. Wall strafing needs the forward edge of that range, because **near 90° you get no acceleration** (the input is all into the wall).
- 1:11. **Being pressed against a wall caps your falling speed at a much lower value.**
- 1:47. A wall boost is a strafe dash into a wall. The dash accelerates over a short time, and normally the velocity rotates toward the dash direction. Against a wall it cannot rotate, so the angle stays good and you gain more.
- 2:30. The wall boost angle is measured from the wall's parallel: about **55°** from a run, **75°** off a zipline.
- 2:56. Chained wall boosts: IAD, land, IAD again timed like a bhop. **Your feet must touch the ground. A wall jump in between still takes the air-dash penalty.**

### V11. Movement Breakdown: Cornerboosting (Leif, 2026-04-20)
- 0:03. **A corner boost is not a normal wall jump. It is a unique mechanic.**
- 0:13. You must jump while touching a ledge but not standing on it. On such ledges the character **surfs**: it slides without ground friction.
- 0:26. **There is no window for error.** Unlike the wall-jump coyote time, it fails once contact with that surface ends.
- 1:18. Only jump is needed. Strafing into the ledge keeps contact longer, because the ledge is effectively angled or curved.
- 2:18. Success gives more height and a different sound. **A weak corner boost is possible**, and it can sound like a normal wall jump, which suggests a graded result.
- 3:23. Velocity carries you up or down the ledge surface. Surfing up ends with you standing on it.
- 3:45. **A corner boost also gives the normal wall jump's toward or away impulse if you hold movement that way when you jump.**

### V12/V13. Edgeboosting (Leif, 2026-04-08 and 2025-09-22)
- V12 0:04. **An edge boost is just a normal wall jump. Location and timing make it special.**
  - A wall jump while moving parallel to a wall sends you straight away from it.
  - Waiting until you slide off the end of the wall **angles** the jump.
- V12 0:26. Only jump is needed. Holding input into the wall keeps contact longer.
- V12 1:41. At higher speed the timing is tighter, because you leave the wall sooner.
- V12 1:57. Walk-off edge boost: where the wall and the floor end at the same place, one jump input is enough.
- V13 0:04. **A wall jump accelerates you toward or away from the wall surface, not parallel to it. At a corner the direction lies between the two walls.**
- V13 0:18. **An edge boost stacks your speed parallel to the wall with new acceleration from the angled wall jump.**
- V13 0:26. **A wall jump still works for a very short time after leaving contact.** An edge boost uses that window.
- V13 1:18. After a wall jump, a **lateral air-acceleration bonus lasts about 1/3 s**. Leif's rough footage fit: holding D through it seemed to cut the effective air drag **from 20% to about 16%**. He says he is not confident in this.
- V13 1:54. Wall collision often does not match the visuals, especially at corners.

### V14. Cornerboosting (Leif, 2025-10-04, just after the 2025-10-02 nerf)
- 0:04. A corner boost is a wall jump **at an upward angle** on **slanted geometry** where the top of a wall meets the floor. It has a different sound and goes much higher.
- 0:16. No leeway: too early gives a double jump, too late gives a normal wall jump.
- 0:30. **The launch angle varies.** The same strafe angle gave different VFX and trajectories.
- 0:49. Some slanted surfaces are **too shallow** to corner boost. Some are flat enough to jump on but can be neither stood on nor boosted.
- 1:00. **Chaining corner boosts does not reset the wall-jump count or air actions**, because you are not landing.
- 1:08. The patch nerfed **vertical velocity**. Post-patch horizontal velocity was **equal or slightly higher** (checked at jump apex with Shiv).
- 1:41. `drawline` tests show the ledges have **slanted collision**, not a 90° corner.

### V15. Everything to Know About Slides (Leif, 2025-11-11)
- 0:05. Entering a slide keeps all horizontal velocity. Inputs give no acceleration during a slide.
- 0:16. **A slope accelerates the slide up to about 830 u/s.** The stairs video (2026-03-18) confirms sliding down at 830.
- 0:22. **A slide removes about 18% of velocity per second, about 2% less than air drag** (which implies about 20%/s air drag).
- 0:27. **Slide decay** is friction above 300% after a window that depends on how the slide started:
  - from a dash: **1.0 s**
  - from the air: **0.75 s**
  - from the ground: **0.6 s**
  - Fleetfoot raises ground slides to 0.8 s and air slides to 1.0 s.
  - **Hitting a slope that accelerates the slide resets the window to 0.6 s**, for slopes of any size.
- 1:14. Slide drag: jumping out of a slide-hop slide before **0.5 s**. Slopes do not change this window.
  - The penalty **persists through wall jumps, double jumps and air dashes**. The transit-line drag immunity prevents it.
  - **Only jumping out of a slide sets it.** Sliding off a ledge or onto a vent does not, and a **superglide** does not.
- 1:56. Slide friction is less than air drag. Any strafing makes the air better.

### V16. Strafing 201 (Leif, 2026-02-14)
- 0:34. **Air control is locked out in a cone around the velocity vector, and the cone grows with speed.** Inputs inside it neither speed you up nor slow you.
- 0:49. From the cone edge up to 90° is the sweet spot, where nothing slows you. Exactly 90° always accelerates.
- 1:01. Beyond 90° can slow you when fast. When slow, a little past 90° can still accelerate.

### V17. Patch videos (Leif)
- 11-21-2025:
  - **The first wall jump costs 1/4 stamina.**
  - Jump-pad stun window 0.6 → 0.9 s.
  - Meleeing a mantling enemy blocks their mantle slide.
- 03-06-2026:
  - **Dash-jump gives an air control buff.** Turn faster for the first 1/4 s. You can land above 600 u/s.
  - **Dash slides can now be jumped out of, but their friction went from about 0.18 to 0.6**, and jumping out gives an air-drag penalty. Jump as early in the dash slide as possible. A dash cancel avoids both.
  - Celeste air control 120 → 110. Graves-type bucket change: B2 ground dash is **579**, B3 is **562**.
- 05-22-2026:
  - Sliding no longer resets sprint.
  - Stamina regen is reduced for 5 s after a wall jump (in combat, and not when the press also mantles).
  - Graves run speed is 362 u/s.
- 06-30-2026:
  - **The dash-jump window moved 0.05 s later with the same length.**
  - **Dash-jump distance 18 → 19 m. Vertical impulse 400 → 425.**

### V18. Misc (Leif)
- Bunnyhopping, 0:27. After a zip dash, about **0.2 s of ground contact drops you below 400 u/s**.
  - The bhop input window opens **before** touching the ground, based on the predicted landing.
  - A perfect hop makes no footstep sound.
- Strafing 208, 0:39. A perfectly timed hop leaves the velocity vector unchanged. **One frame late starts skewing it with ground movement.**
  - 2:10. Moving parallel to a wall, **a wall jump always redirects your velocity away from the wall's face**. Holding input into the wall at an angle does not slow you and can accelerate you.
- Stairs, 1:21. **Rapid jump presses next to a wall give a jump then a wall jump. Extra presses are eaten, not spent as a double jump.**
  - A dash hop buffered into a wall jump is easy to input.
  - The stairs' collision is a flat slope.
- Mantlestrafing, 0:14. A mantle slide can be redirected up to about **90° to either side** of the initial mantle angle. A superglide always goes forward first.
  - On certain railings, looking straight into the face leaves you airborne after the mantle, so a corner boost needs only the jump. Looking even 10° off makes you stand.

---

## 3. Findings by gap ID

Verdict key:
- **CONFIRMS** means the videos agree with the current research.
- **REFINES** means they add a number, a formula or an exception.
- **CONTRADICTS** means they disagree with the current research or the current proposed change.

Code comparisons use `src/movement/data/movement_params.gd` as of today.

### G01 Air dash velocity rule: REFINES, and partly CONTRADICTS the proposed Hypothesis A
- **The cap is per bucket and equals the dash acceleration:** B1 **732**, B2 **670**, B3 **642** u/s (V8 2:16). The SM bonus scales the cap (+30% then, +23% now).
  - This confirms the inference in `air_movement.md` that the cap equals the dash speed. It replaces the single 700 u/s (17.78 m/s) in the proposed `air_dash_cap`.
  - The cap should be `air_dash_speed_for(state)`, not a separate constant. That avoids inventing a number.
  - Our derived speeds are 8 m / {0.43, 0.47, 0.51} s = 732.5 / 670.2 / **617.6** u/s. B1 and B2 match. V8's B3 figure of 642 u/s is 8 m / 0.49 s, from before the 2026-07-28 change of the B3 duration from 0.49 s to 0.51 s. **617.6 u/s is the current value, not an error.**
- **The acceleration is spread over about 0.13 s, not a single impulse** (V8 2:10, V9 0:48, V10 1:47). Our air dash runs for 0.43–0.51 s at a constant speed. The 0.13 s figure is only the acceleration phase. How long altitude hold and input lock last is not stated, and a recording is needed (A1).
- **Velocity is locked in the dash direction during the dash:** you cannot strafe, and the velocity "rotates toward" the dash direction (V3 4:39, V10 1:53). Against a wall it cannot rotate, which is why wall boosts gain more.
- **Angle data that any formula must reproduce** (V8, V1, V6). These are fit targets for A1–A3:
  - A same-direction dash gives nothing once speed is at or above the cap.
  - When faster than the cap, it gains only above **60°**.
  - The best angle is about 75° at v = cap, tends to 90° at 2× cap and 60° at 0.5× cap.
  - Drag-free, 400–600 u/s: the best angle is about 65° for all buckets.
  - B1 at 800 u/s breaks even at about 78° with the end drag.
  - No benefit from angling below about 300 u/s.
  - Practical angles: 45–50° at 350 u/s, about 70° at 590 u/s.
- **Hypothesis A contradicts these data.** A is `v_par' = max(min(v_par+J, C), min(v_par, C))` with v_perp kept.
  - Under A the best angle is always 90° (speed² = C² + v²), not 75°.
  - Under A, B1 at 800 u/s and 78° ends at about 1071 u/s, or about 873 u/s after the V8 drag. Leif shows break-even.
  - So the real dash also takes away part of the perpendicular component: it rotates the velocity toward the dash direction.
  - **Recommendation:** keep the `air_dash_cap_mode` switch, but do not treat mode 1 (Hyp A) as the final answer. Leif's angle data (60°, 75°, 78° at 800) are the acceptance tests for fitting mode selection from A1–A3. Mark the interim values `# PROVISIONAL (G01)`.
- Diagonal or sideways dashes beat forward ones (V7 11:21, V6 16:18). This is qualitative and consistent with the above.
- Confidence: cap values V (single expert, measured on camera). Formula still L.

### G02 Air dash end drag: REFINES (formula, floor, exceptions)
- There are two wordings, both from Leif:
  - (a) V8, 2025-10: "up to 20% of the speed above 80 u/s is removed, minimum 480". Read as `v' = max(min(v, 480), v − 0.2·(v − 80))`.
  - (b) V9, 2026-02: "20% of the velocity above 480 is removed". Read as `v' = v − 0.2·max(0, v − 480)`.
  - V1 and V6 simplify this to "20% of total".
  - **V8's own consistency check favours (a).** A same-direction dash slows you when v > about 80% of the cap. Under (a), B1 gives 0.8·732 + 16 = 601.6, which is 82% of 732 ✓. Under (b) the result is 681.6, which is 93%.
  - Both agree the penalty **does not act below 480 u/s (12.19 m/s)**. So a flat `air_dash_end_speed_mult 0.8` (the current proposal) over-penalises slow dashes.
  - Proposed: `air_dash_end_drag_frac` 0.2, `air_dash_end_drag_offset` 80 u/s (2.03 m/s) and `air_dash_end_drag_floor` 480 u/s (12.19 m/s), all `# PROVISIONAL (G02)` until A2 decides (a) or (b).
- Exceptions, all confirmed:
  - (1) The zipline crouch window, 2 s of drag immunity. It is an air-drag effect, so the same window also blocks slide drag (G09).
  - (2) IAD: the dash must end already grounded into a slide on **level** ground. A 2–3 u height rise or a curb-size drop is enough to break it.
  - (3) **Starting another air dash cancels the pending penalty.** IAD → bhop → IAD works.
- New negative exception: **a wall jump does not cancel it** (V10 3:18).
- Confidence: M → V for the floor and exceptions. Exact formula L-M.

### G08 Air drag value and form: CONFIRMS the value, REFINES the form
- "Minimum air drag 0.2 in console, a fraction of velocity removed each tick" (V6 14:09).
- Slide 0.1875 is described as "18%/s, about 2% less than air drag" (V15 0:22). So 0.2 behaves as **about 20% per second**, meaning the coefficient is per second and applied per tick as `v *= 1 − 0.2·dt`. That is our current linear-per-tick form, and a switch to exponential is not needed.
- Set 0.2 (R). The form is still to be confirmed by A4, but the evidence favours the current form.

### G03 Wall jump tangential momentum: CONFIRMS "kept"
- "A wall jump accelerates you toward or away from the surface, not parallel to it" (V13 0:04).
- "An edge boost stacks speed parallel to the wall" (V13 0:18).
- "The impulse is added to existing velocity" (V6 17:09).
- "Wall jumps carry momentum": a perpendicular dash-jump keeps its speed through the wall jump (V7 8:19).
- This supports `wall_jump_tangent_keep = 1.0` as the interim value, with the normal axis set or added from a fixed kick.
- Ambiguity: Strafing 208 says a parallel wall jump "redirects your velocity away from the wall's face". That fits a kept tangential plus a normal kick, which gives a velocity angled away. It does not imply the tangential part is discarded.
- Whether the normal component is set or added is still open (W1).

### G04 Corner boost: CONFIRMS the tilted-normal direction, REFINES the rules
- It is a wall jump **at an upward angle** off **slanted collision** at a ledge top. `drawline` shows the slant (V14).
- The character **surfs** the ledge with no ground friction (V11).
- The rules:
  - Jump **only while in contact and not standing**. There is **no coyote window**, unlike normal wall jumps.
  - The result is **graded**: weak corner boosts exist, and the launch angle varies with the contact point.
  - Surfaces that are too shallow do not qualify.
  - A corner boost **does not reset** wall-jump count or air actions.
  - Held toward or away input adds the normal wall-jump in/out impulse.
- The 2025-10-02 nerf cut the **vertical** part. Horizontal after the nerf is equal or slightly higher (V14 1:08).
- This matches a "push along the contact normal, which has an upward component" model: `n' = normalize(n + up·tilt)` with the tilt coming from the geometry's contact normal, not from a constant. It fits G13 (closest-point normal).
- **This contradicts any corner boost that redirects approach speed (the current K24).**
- `corner_tilt` should stay `# PROVISIONAL (G04)` until W3. Better still, derive it from the actual contact normal of slanted collision.

### G13 Wall normal selection: CONFIRMS the closest-point normal
- "At a corner, the wall jump direction lies between the two walls" (V13 0:12). This is what a closest-point capsule normal on a convex edge produces.
- The edge boost's "angled" jump after sliding past the wall end (V12 0:08) comes from the same normal rotating around the edge.

### G14 Edge boost: REFINES. Likely emergent, needs no special code
- It is "just a normal wall jump" (V12 0:04).
- It works because of: (1) a **wall-jump coyote window** after losing contact (V13 0:26, V6 17:01, V7 7:44), (2) the closest-point normal rotating around the edge, which angles the jump, and (3) tangential velocity being kept (G03).
- The window is small and gets effectively tighter at high speed (V12 1:41). A walk-off with one press works where the wall and floor end together.
- Proposal: add `wall_jump_coyote_time` (`# PROVISIONAL (G14)`, value from W4) and a contact memory for the last wall contact, instead of a dedicated edge-boost impulse.
- There is no public number for the window. V13's visual shows a gap of a few ticks.

### G15 Post-wall-jump drag: CONTRADICTS the "significant extra drag" wording (low confidence)
- The only measured statement is the opposite. After a wall jump there is a **lateral air-acceleration bonus of about 1/3 s**, and holding a strafe through it seemed to cut the effective drag from 20% to about 16% (V13 1:18, and Leif says he is not confident).
- No video mentions extra drag after a wall jump.
- Recommendation: do not add `wall_jump_drag` until W1 shows it. Consider `wall_jump_air_accel_bonus_time` of about 0.33 s instead (`# PROVISIONAL (G15)`).

### G16 Wall jump input shaping: CONFIRMS a normal-axis-only input
- Input only shapes the jump toward or away from the wall, never parallel to it (V13 0:04, V11 3:45).
- Facing the wall with W lands much closer than with S (V7 8:03).
- The current `wish·n` selection is the right structure. Kick values are still unknown (W2).

### G33 Wall fatigue: REFINES
- Eskay (V7 14:14): **there is no cap on the number of wall jumps.** A wall jump too soon after the last gives **no height and no distance**, not just weak vertical. The needed gap is slightly longer than a double jump or a dash.
- This contradicts "weak vertically only" in the current research. Horizontal may also collapse. Settle with W5.
- Stamina: the first wall jump costs 1/4 (11-21-2025) and later ones cost 1/2 (Eskay, 2026-03). The Deathy "first is free" claim is outdated.
- Regen is reduced for 5 s after a wall jump in combat (05-22-2026).

### G36 Wall slide fall cap: CONFIRMS
- "Pressed against a wall, max fall speed is much lower" (V10 1:11).
- No number is given. −600 u/s stays from the wiki and the 2025-05-08 notes.

### New (no gap ID yet, propose G49): wall strafe / wall boost
- When touching a wall, air-control and air-dash acceleration that points into the wall is redirected along it, because velocity is held parallel to the wall. Near-90° input gives nothing, and the forward edge of the sweet spot is best (V10).
- The wall boost angle is about 55° from a run and about 75° off a zipline, measured from the wall's parallel.
- In our code this should mostly emerge if air accel is applied before the kinematic clip, and if K49 (backtrack kill) does not zero the velocity at shallow angles. **Check K49 in W1.**

### G05 / G06 Dash-jump vertical and window: CONFIRMS
- 06-30-2026: vertical **400 → 425**, distance **18 → 19 m**, and the window moved **0.05 s later with the same length** (V17).
- This matches the G05 target of 425 u/s. The window's length is still 0.25 s from the other sources.

### G17 Dash-jump horizontal: CONFIRMS a global value
- "Dash jumps and slide cancels set velocity to the same value no matter the bucket" (V9 0:19).
- This supports `dash_jump_sets_horizontal` with one global `dash_jump_horizontal_speed` rather than per-bucket values. The value is still fitted from 19 m (about 611 u/s is research-derived, `# PROVISIONAL (G17)`).

### G20 / G21 Dash slide: CONFIRMS and REFINES
- A crouch **at any time** during the dash cancels it (V5, V9) → G20 confirmed.
- The dash slide starts at **650 u/s for every bucket** (V5 0:17) → G21 confirmed.
- A "dead slide" happens when the crouch comes **before the dash-jump window opens**, and it ends around **270 u/s**. A too-late crouch gives a start below **500** (V5 1:21).
  - The dead threshold is therefore tied to the dash-jump window's open time, which is 0.30 s before 06-30 and 0.35 s after.
  - Proposal: `dash_slide_dead_before = dash_jump_window_open`, not a separate 0.3.
- Dash slide friction was about 0.18 before 03-06 (Deathy/Leif said 0.175) and **about 0.6 after**. Jumping out of a dash slide applies an air-drag penalty (V17 3-6). This fits the wiki's 0.6875.
- Conflict: V9 (before 03-06) says a dash cancel can never exceed the ground dash speed, which is at odds with 650 for all buckets. It may refer to the short-hop jump speed rather than the slide speed. Settle with D2.

### G22 Dash hop clamp: CONFIRMS removing the clamp
- "A dash hop is a frame-perfect jump at the end of the dash that keeps the dash's momentum. It beats a short hop for distance" (V9 3:03, Stairs 1:41).
- The walk-speed clamp on the buffered end-of-dash jump (K14) is contradicted in spirit. The tail speed is still unknown (D1).

### G25 Air dash vertical: CONFIRMS zero-and-hold
- "Air dashing prevents gaining or losing altitude for the duration" (V9 0:48).
- IAD height changes about 1 u (V2 1:36).
- Keep the vy-zero hold. How long it lasts versus the 0.13 s acceleration phase is still open (A1).

### G26 Air strafe: REFINES (numbers now available). The current code CONTRADICTS them.
- Model shown on camera (V8, V3, V6, V16):
  - The Source-style air accelerate **wishspeed cap is 80 u/s (2.03 m/s)**, and it becomes **50 u/s (1.27 m/s) above 700 u/s** horizontal.
  - Air-control stat bonuses scale the cap: +100% gives 160, and Celeste has 110 since 03-06.
  - The cap is also limited by move speed. Slows do not reduce it, because the slow floor equals the air control.
- Lockout cone: no change while the input is within about 80° of velocity at dash speeds. This matches `acos(80/|v|)`, which is about 80° at 460 u/s. That is exactly Source's `addspeed = wishspeed − v·wishdir`.
- Current code:
  - Cap 30 u/s, accel 10, ×0.5 above **450** u/s.
  - Per Leif the threshold is **700**, and the cap at speed is 50, not 15.
  - The 2025-05-08 "stronger at low speed" note may be why Leif's number is 80 and not 30.
- Proposal:
  - `air_wishspeed_cap` 2.032 m/s, `air_wishspeed_cap_fast` 1.27 m/s, `air_fast_threshold` 17.78 m/s.
  - Leave the accel rate `# PROVISIONAL (G26)`. Leif does not give it separately; "80" may be both.
  - Fit the rate from A5: with keyboard turning, the best strafe is at about 480–500 u/s, and a Holliday-pad strafe tops out at about 760 u/s.

### G27 Air jump horizontal: CONFIRMS "adds some"
- "A double jump applies some horizontal acceleration based on movement keys" (V3 5:20). No number is given, so it still needs A6.

### G09 Slide-hop penalty: CONFIRMS and REFINES the rules. The penalty size is still unknown.
Rules:
- **Any jump out of a slide sets the flag** (V4 0:47, V15 1:39).
- Jumping out of a later slide before **0.5 s** gives an **air-drag-type** penalty.
- The flag clears after a short time on the ground doing something other than sliding, or by jumping out of a slide on a **downhill slope** (V4 2:13).
- Slopes do **not** change the 0.5 s window (V15).

Things that do not set the flag:
- A scroll-wheel short hop (V5 1:49).
- A superglide.
- Sliding off a ledge or onto a vent.

Other interactions:
- The penalty **persists through** wall jumps, double jumps and air dashes.
- It is **prevented** by the zipline 2 s drag immunity.
- Eskay: too early is much worse than too late.

- Size: "large" air-drag penalty. There are no numbers (S2 is still needed).
- Proposed params `slide_hop_flag`, `slide_hop_min_time` 0.5 and `slide_hop_penalty` (`# PROVISIONAL (G09)`).

### G41 Slide steering: CONFIRMS
- You can steer a slide by holding W and moving the mouse slowly (V7 6:47). The slide's turn rate differs from a strafe rate (Strafing 208).
- Inputs never change slide speed (V15, V3, V4).

### G43 Slide friction and decay (new detail, propose G50 for decay windows): REFINES
- Friction 0.1875 is about 18%/s (V15).
- The decay window depends on how the slide started:
  - **dash slide 1.0 s**
  - **air-entry slide 0.75 s**
  - **ground slide 0.6 s**
  - slope acceleration **resets it to 0.6 s**
  - Fleetfoot raises these to 0.8 s and 1.0 s
  - After the window, friction is above 3.0.
- The research files currently use 0.75 generally and 1.0 after a dash-jump. **The 0.6 ground-slide window and the slope reset are new.**

### G44 Slope slide: REFINES
- Slope slides accelerate up to about **830 u/s** (V15 0:16, Stairs 0:20). Here is where a speed cap truly exists, so a cap is justified by evidence. The angle threshold is still unknown.

### G11 Mantle glide / G39 superglide / mantle slide: REFINES the direction rules only
- The mantle slide can be redirected within ±90° of the facing when the mantle starts (a 180° cone) (V6 20:26, V18 Mantlestrafing 0:14).
- A superglide always goes forward first and does not set the slide-hop flag.
- A mantle jump can also trigger a wall jump if you are airborne at the end of the mantle.
- No speed number is given for the 550 u/s glide.

### G46 / zipline exit: CONFIRMS 2 s immunity, REFINES exit speed
- 2 s of air-drag immunity after crouch-dropping from a transit line (V1, V6, V15).
- Drop speed is **250–590 u/s depending on facing versus line direction**, up to about 700 with a zipline speed boost (V8 3:47).
- A same-tick attach and crouch gives a "huge burst" (V7 13:08). This is related to G47 but is a crouch, not a jump. L.

### G12 Heavy melee: no conflict
- Eskay: you keep momentum while **charging** a heavy melee (V7 13:32). This is about the windup, not the recovery, so G12's "recovery zeroes velocity" is untouched.

### G07, G10, G18, G19, G23, G28, G29, G30, G35, G40, G45, G47: no new video evidence
- Not covered by the videos, or covered only qualitatively. No change.

### Other rules relevant to the code
- **Bhop:** the input window opens before touching the ground (predicted landing), and a late hop skews velocity with ground accel. About 0.2 s of ground contact after a zip dash drops you below 400 u/s (V18). This supports our ground friction being strong at high speed (K32).
- **Jump buffering next to walls:** rapid presses give a jump, then a wall jump, and extra presses are eaten, not spent as a double jump (V18 Stairs 1:21).
- **Dash-jump air control:** +30% for 0.25 s lets you land above 600 u/s (V17 3-6). This confirms the existing spec.

---

## 4. Suggested additions to the recording shot list

These are fit targets from the videos. They make each clip pass or fail against a stated expert number.

| Clip | Check against |
|---|---|
| A1 | Air-dash acceleration phase about 0.13 s. vy held. Per-bucket same-direction cap 732 / 670 / 642. |
| A2 | End drag at pre-drag speeds 400, 600, 900, 1200: decides formula (a) (offset 80, floor 480) vs (b) (above 480). Also: a wall jump in between does not cancel it, and a second air dash does. |
| A3 | Angle sweep at v ≈ cap: optimum about 75°. At 800 u/s B1: break-even about 78°. Drag-free at 400–600 u/s: optimum about 65°. |
| A5 | Zero-gravity W hold tops out at 80 u/s. Lockout about 80° at about 460 u/s. Cap 50 above 700. Holliday pad strafe tops out at about 760. |
| W1 / W4 | Wall-jump coyote window (ticks after contact loss). Tangential kept. Wall-strafe acceleration along the wall. |
| W3 | Corner boost has zero coyote. Vertical vs horizontal after the nerf. Graded strength vs contact point. |
| S1 | Ground-slide decay at 0.6 s vs air-entry 0.75 s vs dash 1.0 s. Slope reset to 0.6. |
| S2 | Slide-drag magnitude. Flag not set by a scroll short hop or a superglide. Flag cleared by a downhill jump. |
