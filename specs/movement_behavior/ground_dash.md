# Ground dash — behavioral model

Research date: 2026-09-27. Current live patch context: post 2026-09-16 update. All sources are public (wiki, official patch notes and forums, community guides). Quotes are short; everything else is paraphrased. Where a source's numbers come from a third-party "game data" site, it is flagged, because it may be derived from client files.

## How it works (plain language, as a movement player would explain it)

- Tap Shift with a direction and your hero bursts 10 m along the ground. Every hero goes the same 10 m, but "heavier" heroes take longer to get there (three dash-speed "buckets"). It costs one stamina bar.
- A ground dash does **not** add to your speed. It **replaces** it: whatever speed you had (sprint, slide, etc.) is ignored for the dash. At the end of a plain dash you are back to about walking speed, so a plain dash on its own does not give you any lasting momentum.
- To keep speed you have to leave the dash some other way:
  - **Dash slide**: press or hold crouch during the dash. The dash turns into a slide right away (you can do this at any point in the dash). The slide keeps your speed and slowly loses it to friction. After a while the friction jumps up sharply (the "late slide penalty"), so good players jump out of the slide early. Since 2026-03-06 you can jump out of any slide, including one that started from a ground dash.
  - **Dash jump**: press jump while the stamina ring flashes blue (0.30 s to 0.55 s into the dash since 2026-06-30). You get a long, fast, high leap (set speed, about 19 m of travel) for one more stamina bar. If you press jump before the window opens, you are locked out of the dash jump for the rest of that dash.
  - **Dash cancel / short hop**: tap crouch briefly during the dash (not held). The dash stops early. If you are fast enough you slide briefly; if you tap and then jump you get a short hop (1 bar). Community videos teach the short hop as normal tech (2026-04 onward). One forum player (2026-08-31) says that with crouch on the scroll wheel it matches full dash-jump distance for 1 bar, and calls that a bug. No dev has replied and no fix is listed. Pressing dash and crouch at the same moment gives almost no dash movement at all (one forum report).
  - **Dash hop** (single community guide, undated): a jump timed at the very end of the dash gives a small dash-jump-like hop for 1 bar. It is not the blue-window dash jump. See rule 12b.
- **Crouch storage**: if you are already holding crouch before the dash (or before leaving the ground), you do not slide when the dash ends or when you land. You come to a crouch stop instead. It is the opposite of slide storage.
- **Coyote dash jump**: if a ground dash carries you off a ledge, the dash-jump window stays open in the air. Jumping then is still a dash jump (2 bars total) and does not use your air jump.
- Movement players use dash-jump to start a chain (it sets a high fixed speed), then keep that speed with slides and slide-jumps. Dash-jump in the middle of a chain is a poor choice because it overwrites speed you already had.

## Rules (numbered, precise, implementable)

1. **Trigger**: grounded, dash input, at least 1 stamina bar. Cost: 1 bar. Direction: the current movement input direction, any angle, 8-way or analog on a joystick. *(Neutral-input direction is undocumented. A search-engine summary said "forward", but no primary source (wiki, patch notes or forum) confirms it. Assume forward and mark it as unverified.)*
2. **Velocity during dash**: the horizontal velocity is **set** in the dash direction. Prior horizontal momentum is discarded (not added). Source: wiki Dashing, "always sets your velocity to a fixed amount".
3. **Distance and duration**: 10 m over bucket duration. B1 0.62 s, B2 0.68 s, B3 0.72 s (B3 changed from 0.70 on 2026-07-28). The published u/s figures (635, 579, 562) are exactly 10 m ÷ duration (393.7 u ÷ t), so they are **average** speeds, even though the wiki labels them "peak". If the profile eases out (see rule 4), the true peak is higher than 635.
4. **Speed at dash end**: the dash ends at about **regular walking speed**, not sprint and not dash speed. Source: wiki Dash Sliding, "a regular dash ends at regular walking speed". Whether this is a smooth ease-out or a flat plateau with a sudden drop is **not documented**. Implement it as a curve resource that ends at base move speed, and fit its shape from a recording.
5. **Bucket speed modifiers** (origin 2025-07-29): B1 +5%, B2 −5%, B3 −15% (changed to −10% on 2025-08-08). These match the durations: an implied base duration of about 0.65 s gives 0.62/0.68/0.72. The bucket changes speed only; distance stays the same.
6. **Dash slow** (debuff): lowers dash **speed** while dash **time** stays the same, so the hero travels less distance. Source: wiki Dashing. This settles the "scale duration or speed?" open question in the current spec: **scale speed**. On 2026-09-16 all ground-dash slows were cut by about 10% globally. The same patch cut **move** slows by about 20% and made move slows also affect air drag (35% of the slow value). That air-drag line is about move slows in general. It is not a property of the dash-slow debuff, so do not fold it into this rule. Patch notes and item text call these debuffs "Dash Distance" reductions (for example Slowing Bullets −25% since 2026-01-30). Under this rule a distance reduction comes from reduced speed.
7. **Dash slide**: a ground dash can be cancelled into a slide **at any time** by crouch. The slide keeps the current horizontal speed and then follows slide friction (0.1875), with the late penalty (about 3.1875 for ground-dash slides) after 0.75 s. The late penalty applies to **all** slides after 0.75 s. The wiki footnote gives ≈3.1875 as the value "when sliding from a grounded dash". The friction numbers come from a wiki footnote credited to a contributor (Altimor), and the method is not stated, so treat them as **medium** confidence and as candidates to tune. Slide entry threshold: **350 u/s (8.9 m/s)** on flat ground (wiki Sliding and Crouching), or any speed on a ramp. **Conflict**: the wiki Slide Bunnyhopping page says 376 u/s are needed to keep sliding, and one low-tier guide says about 10 m/s for a dash slide. Use 350 for entry and keep the threshold a tunable export. Below the threshold, crouch drops the hero to crouch speed almost at once (**4.8 m/s**, wiki Crouching), with no slide. Early in a dash the hero is above the threshold. Still unclear: whether the slide timer counts from dash start or from slide start, and whether a late dash slide (near walking speed) fails the threshold and becomes a crouch stop.
8. **Crouch cancel**: a crouch press during the dash ends the dash. If speed ≥ slide threshold, the hero goes into a slide. With a brief tap, the slide ends when crouch is released, which gives a "short dash". Dash and crouch on the same frame: "no momentum is applied" (forum, 2026-04). So a crouch that comes before any dash displacement can zero the dash while still charging stamina. Treat this as an observed side effect, not a design goal.
9. **Crouch storage**: crouch held **before** the dash (or before going airborne) stops the automatic slide. The hero ends in a crouch regardless of speed or surface. Implement it as "crouch that was already held when the state was entered does not count as a slide request. Only a fresh crouch press does."
10. **Other cancels**: the wiki Dash Sliding page (last edited 2026-09-11) says a regular dash "can only be cancelled by a slide". A jump does not cancel it: a jump inside the window is a dash jump (rule 11), and one before the window causes the lockout (rule 12). Known exceptions:
    - **Parry**: allowed during a ground dash since 2026-04-10. Since 2026-09-16 it cancels the dash **and its momentum** and parries on the spot (official notes).
    - **Some ability casts** (Dynamo 3, Warden 1, Geist 1 "and many others") cancel dashes. This comes from one forum bug report (2026-08-09) with no dev reply. Treat it as a per-ability flag, **not** a general rule.
    - **Melee / "almost any action"**: 2024 forum report only. Unconfirmed in 2026, so do not implement it as a rule.
    - Known bug, do not replicate: a ground dash right after a parry plays the animation, does not move, and costs no stamina (forum, 2026-05-02, unanswered).
11. **Dash-jump window**: opens 0.30 s after dash start and lasts **0.25 s** (to 0.55 s) since **2026-06-30**. Before that it lasted 0.2 s. It is **not** bucket-scaled in any source. In B1 (0.62 s) the window closes 0.07 s before the dash ends. UI: the stamina ring flashes light blue.
12. **Early jump lockout**: a jump pressed during the dash but before the window opens locks the hero out of dash-jump for the rest of that dash. Sources: wiki Stamina and wiki Dash Jumping. What the early jump does instead (nothing, or a normal jump) is not documented. A 2024 report of dash and jump pressed together describes an "in-between" state.
12b. **Dash hop** (low–medium confidence, one community guide, deadlockmoves.com, undated): a jump "perfectly" at the end of the dash (after the window closes, so about 0.55–0.62 s for B1) gives a smaller dash-jump-like hop for **1 bar**. The simplest model is a normal ground jump that keeps whatever speed the dash still has in its tail. That suggests the dash is still above walking speed just before it ends, which bears on rule 4's shape. Do not add a special case. Let it emerge from the dash profile plus a normal jump, and check it against a recording.
13. **Dash-jump output**: horizontal speed is **set** to about 611 u/s (≈15.5 m/s). Prior momentum is ignored. Vertical impulse is **425** (since 2026-06-30, was 400; units presumably u/s). Nominal travel is **19 m** (since 2026-06-30, was 18 m). For 0.25 s after takeoff, air control is +30% (since 2026-03-06). The sources do not say whether 611 is per bucket or global, or whether 611 predates the 18→19 m change. The page was edited on 2026-06-18, 2026-07-01 and 2026-09-11. The revision diffs are behind Cloudflare and could not be checked. The official notes give distance (19 m) and vertical (425) but no horizontal speed. Make 611 a tunable value and **fit it so a flat-ground dash jump travels 19 m**. The official 19 m is the stronger constraint.
14. **Dash-jump cost**: 1 more bar (2 total). It needs a bar available at the moment of the jump. Kinetic Dash procs on dash-jump.
15. **Coyote dash jump**: the window stays open after a grounded dash leaves a ledge. A dash jump taken in the air uses no air jump or wall jump.
16. **Dash-jump slide**: holding crouch through a dash-jump landing starts a slide. The late penalty starts at 1.0 s and is milder (0.6875).
17. **Jump out of a dash slide**: blocked before 2026-03-06. The jump seemed to be eaten by the dash-jump window/lockout logic, and the stamina ring flashed blue during the dash slide. Since 2026-03-06, jump is allowed from any slide (official "Can now jump during slide"; the forum thread confirms the fix). Before the fix, jump already worked out of sprint, air-dash and dash-jump slides, and only ground-dash slides were blocked. The wiki Slide Bunnyhopping page still says dash slides block jumping. That text dates from 2026-02 and is **outdated**. The Dash Sliding wiki says to cancel the dash slide around when the blue ring shows (about 0.3 s).
17b. **Consecutive-slide penalty** (medium–low confidence, wiki Slide Bunnyhopping, content from 2026-02): inside a slide-hop chain, a slide that lasts **under 0.5 s** gives a big speed penalty. The **first** slide of a chain is exempt, so jumping at once out of the first (for example dash) slide is fine. Size and exact rule are unknown, and nothing confirms it after 2026-03-06. Implement it behind a flag and verify with a recording.
18. **Sprint**: nothing documents a dash resetting sprint. Only zipline attach is documented to reset sprint. The wiki Sprinting page lists the things that interrupt sprint (damage turns it off for 3 s, firing, alt-fire zoom), and dash is not among them. Sprint model since **2025-12-16** (official notes): the ramp is 0.6/s and it starts accelerating above +2.5 m/s. The dash ends at walking speed, so the sprint ramp resumes from there. Unverified: whether sprint ramp progress carries through a dash.

## Momentum: what conserves, adds, sets, caps, or decays speed

| Event | Effect on horizontal speed | Effect on vertical | Source / confidence |
|---|---|---|---|
| Ground dash start | **SET** to bucket dash speed along the input direction. Prior momentum discarded | none (grounded) | wiki Dashing; high |
| During dash | follows a fixed profile; averages 10 m / duration | — | wiki; shape unknown (low) |
| Dash end (no input) | **SET/decays to ≈ walk speed** | — | wiki Dash Sliding; medium (one source, qualitative) |
| Dash slow debuff | **SCALES** dash speed down; duration unchanged | — | wiki Dashing; high |
| Bucket | scales dash speed (+5 / −5 / −10 %); distance constant | — | 2025-07-29 and 2025-08-08 notes; high |
| Crouch during dash → slide | **CONSERVES** current speed, then **DECAYS** by slide friction 0.1875, penalty ≈3.1875 after 0.75 s | — | wiki Sliding; medium (numbers from a credited wiki footnote, method unstated) |
| Crouch same frame as dash | dash displacement ≈ **zero** | — | forum 2026-04 (one reporter, no dev reply); low |
| Crouch during dash below slide threshold | **SET** to ≈4.8 m/s crouch speed (no slide) | — | wiki Crouching; medium |
| Jump at very end of dash ("dash hop") | **CONSERVES** residual dash-tail speed into a normal jump (inferred model) | normal jump | deadlockmoves.com (undated, single source); low–medium |
| Some ability casts during dash | **CANCEL** the dash (per ability) | — | forum 2026-08-09 bug report; low |
| Dash jump in window | **SET** to ≈611 u/s. Prior discarded | **SET/ADD** 425 up | wiki; 2026-06-30 notes; high (425), medium (611) |
| Dash-jump airtime | +30% air control for 0.25 s | gravity | 2026-03-06; high |
| Dash-jump landing + crouch | **CONSERVES** into slide, penalty 0.6875 after 1.0 s | — | wiki Sliding; medium |
| Parry during ground dash | **KILLS** dash momentum | — | 2026-09-16; high |

## Known tech that depends on these rules

| Tech | Inputs | Why it works |
|---|---|---|
| Dash slide | Dash → hold crouch (any time) | Rule 7: the slide keeps the dash's high speed instead of letting the dash end at walking speed |
| Dash slide jump / slide-hop chain | Dash → crouch → jump out of the first slide early (for example around the blue ring) → land holding crouch → later slides last **≥0.5 s** but under 0.75 s → repeat | The slide jump carries the slide speed. Landing into a slide keeps it. Jumping before the late penalty avoids the friction spike. Slides after the first one that last under 0.5 s are penalized (rule 17b, medium–low) |
| Dash jump | Dash → jump on the blue flash (0.30–0.55 s) | Rule 13: sets a high speed plus 425 vertical, about 19 m |
| Coyote dash jump | Ground dash off a ledge → jump inside the window while airborne | Rule 15: the window is not cancelled by leaving the ground. Air actions are kept |
| Dash-jump strafe | Dash jump → air strafe | +30% air control for 0.25 s. No stamina |
| Dash-jump slide bunnyhop | Dash jump → hold crouch on landing → hop | Rule 16: milder penalty on dash-jump slides |
| Short dash crouch cancel (SDCC) | Dash → brief crouch tap | Rule 8: crouch ends the dash early. It fakes a dash slide |
| Short hop / dash cancel | Dash → quick crouch (mousewheel bind) → jump | Crouch ends the dash, then the jump comes out of the brief slide. Costs 1 bar |
| Dash hop | Dash → jump right at the end of the dash (after the blue window) | Rule 12b: a normal jump that keeps the dash's tail speed. 1 bar. Single undated source |
| Scroll-crouch short hop ("1-bar dash jump") | Dash → mousewheel crouch → jump right away | One player reported it on 2026-08-31 as matching full dash-jump distance for 1 bar and called it a bug. No dev reply, no fix in the 09-16 notes, and community videos teach short hops as normal tech. It **emerges** from rules 7 + 17 (crouch keeps dash speed, jump out of any slide). Do not add special code to allow or block it. Implement 7 and 17 faithfully and compare the distance to a recording |
| Crouch storage | Hold crouch **before** the dash or takeoff | Rule 9: a crouch that was already held does not start a slide |
| Crouch-jump-dash-uncrouch momentum exploit | Jump + crouch → dash → uncrouch → hop/slide | **Hotfixed** around 2026-02. Do not replicate |

## Patch history affecting this (dated)

- 2024-07 to 2024-09: forum reports of a dash+jump "in-between" state, crouch-held dash-jump sliding over curbs, and dash cancel into melee or any action.
- 2025-07-29: hero dash-speed buckets added (same distance, different speed): B1 +5%, B2 −5%, B3 −15%.
- 2025-08-08: B3 changed from −15% to −10%.
- 2025-12-16: Lady Geist moved to bucket 3. Sprint ramp 0.75→0.6/s, sprint accelerates above +2.5, base sprint −0.4.
- 2026-01-30: "Dash Speed" added to the stat screen. Dash-distance values: Slowing Bullets −20→−25%, Mystic Slow and Lightning Scroll −10→−12%.
- ~2026-02-24: crouch/uncrouch dash momentum exploit hotfixed.
- 2026-03-06: jump allowed during slides, which fixed jump being blocked out of dash slides. Dash jump gives +30% air control for 0.25 s.
- 2026-04-10: parry allowed while ground dashing.
- 2026-06-30: dash-jump window 0.2→0.25 s (0.30–0.55 s). Dash-jump distance 18→19 m. Vertical impulse 400→425.
- 2026-07-28: B3 ground dash 0.70→0.72 s. Air dash 0.49→0.51 s.
- 2026-09-16: ground-dash slows reduced about 10%. Move slows reduced about 20% and now add air drag (35% of the slow value; this is move slows, not dash slows). Parry during a regular dash cancels its momentum. Dashes no longer pause the gun cycle.

## Contradictions / uncertainties (and what recording would settle them)

1. **Dash-jump window length**: the wiki Dashing page and the current spec say 0.2 s. The wiki Dash Jumping subpage and the 2026-06-30 notes say 0.25 s. **Resolved: 0.25 s** (official patch notes). The spec is outdated.
2. **Dash velocity profile**: is it constant then drops to walk speed, or eased? The wiki's "peak" speeds equal 10 m ÷ duration, so they carry no information about shape. *Recording*: a frame-by-frame position log of a B1 dash on flat ground (a 60+ fps capture in the sandbox or practice mode, measured against map geometry or an on-screen speedometer if one exists), plus a slide started at t = 0.1 / 0.3 / 0.5 s to sample speed at each point.
3. **Dash end speed**: "walking speed" (one source). Does it depend on held input, and does it keep sprint? *Recording*: dash, then keep holding W, and read the speedometer.
4. **Dash-jump speed 611 u/s**: global or per bucket? Recorded before or after the 18→19 m buff? *Recording*: dash-jump distance for a B1 hero and a B3 hero on flat ground.
5. **Game-data "duration 0.6 s"** (deadlock.io, client-6698) does not match the bucket durations 0.62/0.68/0.72. It may be a base value before bucket scaling, or a different parameter. Low confidence. It is also possibly derived from client files, so do not use it as a spec value.
6. **Early-jump lockout outcome**: does the early jump fire a normal jump, or nothing? *Recording*: jump at 0.1 s into a dash.
7. **Neutral-direction dash**: forward, or no dash? *Recording*: dash with no movement key held.
8. **Crouch-at-dash-start zero-momentum**: is it intended? It interacts with crouch storage (crouch held before the dash). *Recording*: hold crouch, then dash. Does the hero crouch-dash 10 m or not move?
9. **Dash-slide late-penalty clock**: does it start at dash start or at slide start?
10. **Bucket membership**: the wiki Dashing table is garbled (heroes listed twice). The wiki Stamina page lists B1 as Calico, Celeste, Grey Talon, Haze, Holliday, Ivy, Mina, Paradox, The Doorman. B2 as Apollo, Billy, Drifter, Graves, Infernus, Lash, McGinnis, Mirage, Pocket, Seven, Silver, Sinclair, Vindicta, Viscous, Vyper, Warden, Wraith, Yamato. B3 as Abrams, Bebop, Dynamo, Kelvin, Lady Geist, Mo & Krill, Paige, Rem, Shiv, Venator, Victor. Use the Stamina page. The current spec's "most others B1" is wrong: most heroes are B2 or B3.

## Evidence (numbered)

1. https://deadlock.wiki/Dashing: wiki, current. Set-velocity rule, 635/579/562 u/s and 0.62/0.68/0.70 s, 0.2 s window (outdated), dash slow scales speed not time, dash-slow table, any-angle dashing.
2. https://deadlock.wiki/Dashing/Dash_Jumping: wiki, updated after 2026-06-30. 0.25 s window from 0.3 s, speed set to 611 u/s, 2 bars, lockout, coyote dash jump, strafe jump, slide bunnyhop.
3. https://deadlock.wiki/Dashing/Dash_Sliding: wiki. Cancel into slide at any time, dash ends at walking speed, dash only cancellable by slide, cancel the slide around the blue ring.
4. https://deadlock.wiki/Stamina: wiki. Bucket speeds and durations 16.1/14.7/13.9 m/s and 0.62/0.68/0.72 s, full bucket rosters, 10 m / 8 m distances, window about 2/3 through the dash, lockout.
5. https://deadlock.wiki/Sliding: wiki. 350 u/s threshold, friction 0.1875, penalty 3.1875 / 0.6875 at 0.75 / 1.0 s, slide storage, crouch storage.
6. https://deadlock.wiki/Update:June_30,_2026 and https://tracklock.gg/articles/deadlock-update-06-30-26-patch-notes: patch notes. Window 0.2→0.25 s (0.3–0.55), distance 18→19 m, vertical 400→425.
7. https://forums.playdeadlock.com/threads/07-29-2025-update.72760/: official. Buckets introduced (+5/−5/−15%), B3 −10% on 2025-08-08.
8. https://forums.playdeadlock.com/threads/12-16-2025-update.93983/: official. Lady Geist to B3.
9. https://forums.playdeadlock.com/threads/01-30-2026-update.102822/: official. Dash Speed stat, dash-distance item changes.
10. https://deadlock.wiki/Update:March_6,_2026 and https://forums.playdeadlock.com/threads/03-06-2026-update.114328/: official. Jump during slide, dash-jump air control +30% / 0.25 s.
11. https://forums.playdeadlock.com/threads/inconsistent-behaviour-for-jump-cancelling-a-slide.105871/: forum, 2026-02 to 03. Jump blocked only in ground-dash slides, blue flash during them, fixed 03-06-2026.
12. https://forums.playdeadlock.com/threads/cant-jump-while-sliding-after-dash-slide.90956/: forum, 2025-11-23. Same issue.
13. https://forums.playdeadlock.com/threads/slow-dash-maybe-a-terrain-issue.126515/: forum, 2026-04-12. Dash and crouch pressed together give no momentum.
14. https://forums.playdeadlock.com/threads/dash-jump-bug-consuming-only-1-stamina.159771/: forum, 2026-08-31. Dash → scroll-crouch → jump gives a full dash jump for 1 bar (bug).
15. https://forums.playdeadlock.com/threads/jump-crouch-into-dash-uncrouch-makes-you-gain-insane-momentum.112237/: forum, 2026-02-24. Momentum exploit, hotfixed.
16. https://forums.playdeadlock.com/threads/minor-bug-dash-jump-bug-when-staying-crouched-and-crossing-ledges.28341/: forum, 2024-09-12. Crouch held during a dash jump causes curb slides. Crouching before the dash jump prevents it (early evidence of crouch storage).
17. https://forums.playdeadlock.com/threads/dash-cancel-into-light-melee-charged-punch.24481/: forum, 2024-09. Dash cancellable into melee or other actions (old).
18. https://forums.playdeadlock.com/threads/dash-jump-bug.12286/: forum, 2024-07-21. Dash and jump together give an odd state.
19. https://deadlockmoves.com/fundamentals/: community guide, undated. Dash hop (jump at dash end, 1 bar), short hop (dash → quick crouch → jump), sprint slide at 8.9 m/s.
20. https://deadlock.io/en/articles/mechanics/dash-jump and /dashes: third-party "game data", client-6698, 2026-09-20. Dash duration 0.6 s, dash cooldown 0.85 s, jump cooldown 0.15 s. **Low confidence / possibly client-derived. Do not adopt.**
21. https://tracklock.gg/articles/deadlock-update-07-28-26-patch-notes: B3 0.70→0.72 s.
22. https://www.youtube.com/watch?v=4pfFUdO31FU: "Movement Breakdown: Dash Cancels (aka shorthop)" (title only, transcript not retrievable). Also https://www.youtube.com/watch?v=EtHEtvBfC2M ("Deadlock 2026 Movement Guide (Featuring Leif)"). Candidates for watching directly.
23. https://boostroom.com/blog/deadlock-movement-guide-slide-dash-wall-jump-and-zipline-tech: community guide, 2026-02-28. Dash in multiple directions ("forward/back/left/right/diagonals"; the "8" is our paraphrase), dash-jump best at chain start, dash-slide jump inconsistency (pre-03-06).
24. https://deadlock.wiki/Bunnyhopping/Slide_Bunnyhopping: wiki, content 2026-02 (last edit 2026-06-22). A slide under 0.5 s inside a chain is penalized, the first slide is exempt, 376 u/s to keep sliding. Says dash slides block jumping (**outdated**, see rule 17).
25. https://deadlock.wiki/Crouching: wiki. Crouch below 350 u/s drops to 4.8 m/s. Above 350 u/s you slide.
26. https://deadlock.wiki/Dashing/Short_Dash_Crouch_Cancelling: wiki. SDCC = dash, then a brief duck press. 1 bar. Same inputs as a dash slide with a brief duck.
27. https://deadlock.wiki/Walking/Sprinting: wiki. Sprint interrupts (damage 3 s, firing, zoom). Dash is not listed.
28. https://forums.playdeadlock.com/threads/12-16-2025-update.93983/: official. Sprint ramp 0.75→0.6/s, acceleration above +2.5, base sprint −0.4, Lady Geist to B3.
29. https://forums.playdeadlock.com/threads/some-abilities-cancel-dashes.155575/: forum, 2026-08-09. Some abilities cancel dashes. No dev reply.
30. https://forums.playdeadlock.com/threads/ground-dash-after-parry-goes-nowhere-and-costs-no-stamina.130541/: forum, 2026-05-02. Dash right after a parry does not move and costs no stamina (bug).
31. https://forums.playdeadlock.com/threads/04-10-2026-update.125825/ (and wiki Update:April_10,_2026): official. Parry allowed while ground dashing.
32. https://deadlock.wiki/Update:September_16,_2026: official. Ground dash slows −10%, move slows −20%, move slows affect air drag 35%, parry cancels a regular dash and its momentum, dashes no longer pause the gun cycle.
33. https://deadlock.wiki/Kinetic_Dash: wiki. Procs on dash-jump.
34. YouTube titles (videos not watched, transcripts not retrieved): "Movement Breakdown: Dash Cancels (aka shorthop)" (2026-04-13), "How to shorthop in Deadlock" (short, 2026-07-26), "How to MOVE Like a DEADLOCK PRO" (2026-02-27), https://www.youtube.com/watch?v=KFyjh2DAg1Y "Deadlock Dashes (and how to make use of 'em)". They show that the short hop is recognized, taught tech.

## Verification log (2026-09-27)

Adversarial pass. We re-fetched every primary citation and searched for contradicting and newer material.

**Confirmed (re-fetched, still current)**
- Ground dash **sets** velocity (wiki Dashing). The 635/579/562 u/s and 0.62/0.68/0.70 s figures are still on the Dashing page. Arithmetic check: 393.7 u ÷ t gives 635.0 / 579.0 / 562.4, and the Stamina page's 16.1/14.7/13.9 m/s = 10 m ÷ 0.62/0.68/0.72. So the "peak" label really is an average. The Dashing page's B3 value is stale (0.70). Its bucket table is garbled (it lists 35 heroes under B1), so the Stamina page roster stands.
- Bucket math: +5/−5/−10% on a base of about 0.651 s gives 0.620/0.685/0.723 s, which matches 0.62/0.68/0.72.
- 2025-07-29 buckets (+5/−5/−15%), B3 −10% on 2025-08-08, Lady Geist to B3 on 2025-12-16, 2026-01-30 Dash Speed stat and dash-distance items. All verbatim in official notes.
- 2026-06-30: window 0.2→0.25 s (0.3–0.55), 18→19 m, vertical 400→425. Verbatim.
- 2026-07-28: B3 ground 0.70→0.72 s, air 0.49→0.51 s. Verbatim.
- 2026-03-06: "Can now jump during slide" and dash-jump air control 30% for 0.25 s. Verbatim.
- 2026-04-10 parry during ground dash, and 2026-09-16 parry cancels dash and momentum. Verbatim.
- Dash Jumping wiki (last edit 2026-09-11): 0.25 s window from 0.3 s, 611 u/s set, 2 bars, lockout, coyote dash jump keeps air actions.
- Dash Sliding wiki (last edit 2026-09-11): slide cancel at any time, ends at walking speed, only cancellable by slide, cancel around the blue ring.
- Sliding wiki (last edit 2026-06-19): 350 u/s, 0.1875, 3.1875 (grounded dash) / 0.6875 (dash jump), 0.75 / 1.0 s, crouch storage "hold the crouch button before dashing".
- Forum threads 105871, 126515, 159771 and 112237 say what the spec says (dates correct). The 112237 exploit is marked hotfixed by the OP.
- Kinetic Dash procs on dash-jump.

**Corrected**
- Rule 6: the 2026-09-16 "air drag 35%" line is about **move** slows in general. It is not part of the dash-slow debuff, and the spec had merged the two. Move slows were also cut 20%.
- Rule 10: "ability casts" as a general cancel was not supported. The only evidence is one 2026-08 bug report for specific abilities. It is now a per-ability flag. The melee cancel is downgraded to unconfirmed. The parry-then-dash no-move bug is added.
- Tech row "Dash hop / 1-bar dash-jump exploit": it merged two different things. "Dash hop" (deadlockmoves: jump at the end of the dash, 1 bar) is not the forum's scroll-crouch short hop. Calling the latter a confirmed "bug, do not replicate" overstated the evidence: one player, no dev reply, no fix, and it is taught tech. It is now "emergent, do not special-case".
- Slide-hop chain row: added the ≥0.5 s rule for slides after the first one (wiki Slide Bunnyhopping). The old "jump about 0.3 s into every slide" advice would trigger that penalty.
- Rule 7: the slide threshold is contested (350 vs 376 vs about 10 m/s). Added the below-threshold crouch speed of 4.8 m/s. The friction numbers are now labelled as from a credited footnote, not as "datamine".
- Rule 13: the official 19 m is the constraint to fit. 611 stays a tunable value.
- Rule 18: added the official 2025-12-16 sprint ramp numbers. Dash is not on the wiki's list of sprint interrupts.

**Still uncertain (needs a recording or a better source)**
- Dash velocity profile shape and end speed (rule 4). The dash hop suggests the tail is still above walking speed.
- Neutral-input dash direction: no primary source.
- Whether 611 u/s is per bucket and whether it predates 19 m (wiki diffs blocked).
- Early-jump outcome (normal jump or nothing), and what a jump in 0.55–0.62 s does (dash hop).
- Whether the scroll-crouch short hop really equals dash-jump distance.
- Whether the Slide Bunnyhopping 0.5 s penalty and the 376 u/s figure survive 2026-03-06.
- The slide-timer origin for dash slides.
- The YouTube movement guides (Leif 2026, Dash Cancels 2026-04) could not be transcribed. Watching them is the best remaining non-recording source.

**No invented limits found**: every numeric cap in the spec traces to official notes or the wiki. The only new limit is the 0.5 s consecutive-slide penalty, which comes from the wiki and is flagged as low–medium.
