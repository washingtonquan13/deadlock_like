# Movement Spec

> Clean-room observation record. Describes observed behavior of Deadlock (Valve) for the purpose of independent reimplementation. No game code or assets were used.

Units: Deadlock uses Source 2 "hammer units" (u, hu). **1 u = 0.0254 m (1 inch)**. The game's UI shows speeds in m/s; the wiki's physics articles use u/s. Server tick implied by the wiki's "28 ticks = 0.44 s" is **64 Hz** (inferred).

All values are for the live game as of the most recent patch found (2026-09-16) unless stated otherwise. Deadlock is in active development; re-verify everything against the latest patch before locking numbers.

---

## Summary

Deadlock movement is a Source-style kinematic character controller (capsule, ground/air states, friction, air acceleration) with a MOBA stat layer on top.

- **Ground locomotion**: each hero has a base **Move Speed** (6.2–8.2 m/s). After ~3 s without hero/neutral combat interaction, a per-hero **Sprint Speed** bonus (usually +1.6 m/s) is added, ramping in gradually above +2.5 m/s. Firing a weapon multiplies speed by 0.75. Crouch-walk is a fixed ~4.8 m/s.
- **Stamina** is a pool of discrete charges ("bars", base 2–4 per hero) that regenerate one at a time (4.2–6 s per bar; 4.5 s for most). Stamina pays for **dashes** (ground/air, 1 bar), **air jumps** (1 bar), **dash-jumps** (1 extra bar), and **wall jumps after the first** (0.5 bar).
- **Ground dash** sets velocity to a fixed value for a fixed time (covers 10 m); speed depends on a hero's "dash bucket". **Air dash** is an additive impulse (covers ~8 m), usable once per airtime (twice with Stamina Mastery).
- **Dash-jump**: jumping in a short window (0.3–0.5 s after a ground dash starts) converts dash momentum into a long, fast leap for 1 extra stamina.
- **Slide**: pressing crouch while moving faster than 350 u/s (8.9 m/s) enters a low-friction slide. After ~0.75 s the slide's friction jumps sharply (the "late slide penalty"). You can jump out of a slide (since 2026-03-06). Sliding does not cost stamina.
- **Air**: 1 air jump + 1 air dash per airtime by default (refreshed on landing or zipline attach). Air strafing exists but is deliberately weak, especially above 450 u/s.
- **Wall jump**: first wall jump per airtime is free, then 0.5 stamina each with "fatigue" that shrinks vertical launch; fatigue recovers over 1.25 s and resets on landing.
- **Mantle**: automatic ledge climb (hold forward + jump) for ledges 32–160 u above, 0.2–0.5 s, player is not actionable during it.
- **Ziplines**: lane ropes that carry you at a fixed 18 m/s (inner) / 21 m/s (outer) regardless of hero, with a team-wide boost (+80%). Enemy damage in the first 3 s knocks you off (15% max HP damage + 2.5 s stun on landing).
- **No fall damage.**
- **Slows** stack multiplicatively, are resisted additively, and cannot push speed below 2 m/s.
- **Melee**: light melee is instant; heavy melee has a wind-up and a lunge (~half a dash) with a 1 s cooldown (1.3 s on miss); both apply a brief self-slow afterward. Parry is a 1 s animation with a 0.75 s active window; a successful parry stuns the attacker 2.75 s.

---

## Mechanics

### 1. Units, tick and frame of reference
- Distances/speeds internally in hammer units; 1 u = 0.0254 m. 350 u/s ≈ 8.9 m/s, 80 u/s ≈ 2.0 m/s.
- Simulation appears to run at 64 ticks/s (28 ticks = 0.44 s per wiki). Use a fixed physics step of 1/64 s for parity (Godot `physics_ticks_per_second = 64`).
- Wiki physics numbers are Source-convention "peak speeds" and "+N units" heights.

### 2. Base locomotion (walk)
- Ground speed target = `MoveSpeed_effective` (see §4). Movement input is 8-directional (WASD). (Correction 2026-09-27: the earlier claim that an "8-way sprint" note in the 2025-02-25 update implies sprint works in all directions was a misread; that note was one hero's animation polish and says nothing about sprint rules. Whether sprint applies while strafing/backpedalling is unverified; the wiki lists holding opposing directional inputs as a sprint reset.)
- **No documented backpedal/strafe penalty** in Deadlock sources (unlike TF2). Treat all directions as equal speed until measured (see Open questions).
- **Firing penalty**: while the weapon is firing, speed × 0.75 (was 0.70 before 2025-07-29). Exceptions: Rem and Silver (transformed) keep 100%. Fleetfoot item removes the penalty.
- Ground acceleration/friction values are not published. Source-default feel (sv_accelerate ≈ 5–10, sv_friction ≈ 4–5) is a reasonable starting point but must be measured.

### 3. Sprint
- Sprint is not a button. After **3 s** without hero/neutral interaction (official history: 5 s -> 4 s on 2025-02-25 -> 3 s on 2025-12-16; the wiki Move Speed/Movement pages still say 5 s and appear stale), the hero's **Sprint Speed** is added to move speed. The 2025-02-25 notes also set a 0.5 s sprint disable for non-hero damage; whether that still applies after the 2025-12-16 "hero/neutral" wording is unverified.
- Ramp rule (since 2025-12-16): the first **+2.5 m/s** of sprint is applied immediately; any sprint beyond +2.5 m/s is added gradually at **0.6 m/s per second** while moving (previously 0.75/s above +3).
- Sprint Speed bonuses stack **additively** with no diminishing returns.
- Sprint is **cancelled/reset** by: taking damage, shooting enemies, being CC'd, using a zipline, crouching, stopping, holding opposing directional inputs. Sprint **persists** through: melee attacks, fighting neutrals without taking damage, hitting breakables, sliding, teleporters, magic carpet.
- Sprint is **not** affected by vent boosts.
- State machine: `COMBAT -> (timer >= sprint_delay) -> SPRINT_ACTIVE; any reset event -> COMBAT (timer=0)`.

### 4. Move speed stacking and caps
- `MoveSpeed_effective = BaseMove + EffectiveMoveBonus + BaseSprint + ΣSprintBonus` (sprint terms only while sprinting).
- **Diminishing returns on Move Speed bonuses** (since 2025-12-16): wiki formula
  `EffectiveMoveBonus = K × (1 − Π(1 − Bi/K))` with K = 12 as published on the wiki. The 2026-03-06 notes say the "diminishing ramp now occurs around 11m rather than 10m", so the true curve likely has a soft-knee near 11 m/s total rather than a pure asymptote at K. Implement the curve as a data-driven function (K configurable) and tune.
- Heroes with spirit-scaled move speed exist (Grey Talon, Sinclair, Vindicta, Vyper, Venator, Warden, Wraith sprint): speed += SpiritPower × coefficient (coefficients per hero; see hero specs).
- Vents: +70% Move Speed while traversing (sprint excluded).

### 5. Slows
- Multiple slows: `TotalSlow = 1 − Π(1 − Si)`.
- Slow resist (additive between sources): `ActualSlow = TotalSlow × (1 − ΣResist)`.
- Floor: `SlowedSpeed = (Speed − 2.0) × (1 − ActualSlow) + 2.0` (m/s). Speed never drops below 2.0 m/s from slows.
- 2026-09-16: all move-slow values reduced ~20%, ground-dash slows reduced ~10%, and slows now also increase **air drag** by 35% of the slow value (i.e., a 50% slow adds 17.5% extra air drag).
- **Damage slow** (since 2025-12-16): taking damage applies a 20% slow only to the portion of speed above the hero's base move speed (i.e., it eats sprint/item bonuses, never base speed). Duration not published.
- The old "on bullet hit" move slow was removed 2025-12-16 (previously a flat 10% slow on taking damage).
- Rope climb debuff: after taking player damage, rope climbing is 40% slower for 4 s (2025-07-29).
- **Dash slows** are a separate stat (reduce dash distance/speed), e.g. Slowing Bullets −20%, Haunting Shot −36% (see Values).

### 6. Crouch
- Hold crouch (default Ctrl). Crouch-walk speed is fixed **4.8 m/s** (4.4 m/s Grey Talon/Warden) and not affected by the firing penalty.
- Crouch while horizontal speed > 350 u/s → slide (§8); a slope alone does not start one (session 7).
- "Crouch storage": holding crouch before a ground dash prevents the dash from turning into a slide on any surface.
- Crouch cancels sprint.

### 7. Stamina
- Pool of integer "bars" (fractional costs allowed: 0.5 for wall jumps). Base per hero: 2, 3 or 4. UI caps display at 8.
- **Regen**: one bar at a time, each taking `StaminaCooldown` seconds (4.5 s default since 2025-12-16, was 5 s; the wiki Stamina page still says 5 s and is stale; per hero 4.2–6 s). Stamina Recovery % items shorten this; assumed formula `cooldown / (1 + ΣRecovery)` (unverified).
- **Wall jump in combat** reduces stamina regen by 25% for 5 s.
- **Stamina disable** effects exist (e.g. Fury Trance 6.5 s, Entangling Bola 1.5–2.25 s, Capacitor 3 s) that prevent spending stamina.
- Costs: ground dash 1, air dash 1, dash-jump +1 (2 total), air jump 1, first wall jump 0, subsequent wall jumps 0.5, down dash (conflict: 0.5 per Movement article vs 1 per Stamina article), slide 0, mantle 0 (grounded).
- Items: Extra Stamina (+1, +12%), Kinetic Dash (+1, +12%), Stamina Mastery (+2, +18%, +1 air action, +23% air jump/dash distance; values since 2026-01-30, were +20%/+30%), Celestial/Seraphim legendary (+100%/+120% recovery).
- Powerup rune: temporary +2 to +4 stamina for 160 s.

### 8. Ground dash
- Input: dash key (Shift) + movement direction (neutral = forward, assumed). Cost 1 stamina.
- **Sets velocity** to a fixed horizontal speed in the input direction for a fixed duration (not additive). All heroes' ground dashes cover **10 m**; speed differs by bucket:
  - Bucket 1: 0.62 s (≈16.1 m/s, 635 u/s)
  - Bucket 2: 0.68 s (≈14.7 m/s, 579 u/s)
  - Bucket 3: 0.72 s (≈13.9 m/s, ≈547 u/s inferred) since 2026-07-28 (was 0.70 s / 562 u/s peak; the wiki Dashing page still shows the pre-patch 562 u/s / 0.70 s)
- After the dash ends, if crouch is held or the hero is above slide threshold with crouch pressed, the hero goes into a slide ("dash slide"); momentum then decays via slide friction.
- Dash-distance modifiers (items/abilities) scale distance; implement as scaling duration or speed (unknown which — measure).
- Parry during a regular dash cancels the dash and its momentum (2026-09-16). Parry is allowed while ground-dashing (2026-04-10).
- Dashes no longer pause the gun's cycle time (2026-09-16).

### 9. Dash-jump
- Pressing jump during the **dash-jump window** of a ground dash: window opens 0.3 s after the dash starts and lasts 0.2 s (UI cue: stamina bars flash light blue on the crosshair).
- Costs 1 additional stamina (2 total including the dash). Requires ≥1 stamina remaining.
- Result: a long, fast jump that preserves dash momentum. Since 2026-03-06, grants +30% air control for 0.25 s after takeoff.
- **Dash-jump cancel**: casting an ability during the window cancels the dash-jump, allowing a normal (free) jump afterward.
- Kinetic Dash item triggers on dash-jump (+25% fire rate, +6 temp ammo until reload, up to 7 s).
- Dash-jumped slides get a later late-slide penalty (1.0 s instead of 0.75 s) and a milder penalty friction (0.6875 instead of 3.1875).

### 10. Jump and air jump
- Ground jump: free. Peak vertical speed **295 u/s** (7.5 m/s), max height **+45 u** (~1.14 m) per wiki. These imply gravity ≈ 295²/(2·45) ≈ 967 u/s² (24.6 m/s²) — inferred, verify.
- Hero gravity modifiers: Celeste −25% gravity, Ivy −10%.
- Air jump (double jump): 1 per airtime by default (2 with Stamina Mastery), 1 stamina each. Likely sets vertical velocity (Source convention) rather than adds — unverified.
- Air jump / air dash counters refresh on landing and on zipline attach.
- Shooting during a jump: no lockout since 2025-10-02; a −10% accuracy penalty for 0.15 s after jumping.
- Coyote time / jump buffering not documented. Input buffering exists for shooting, dashing, melee, parry (2025-10-02). Holding jump near a ledge auto-buffers a mantle.

### 11. Air dash and down dash
- Air dash: 1 stamina, 1 per airtime (2 with Stamina Mastery). It is an **impulse added to current velocity** (can stack or conflict with existing momentum). During the dash, gravity and air friction are disabled; after a short delay they re-enable (community forum analysis). Covers ~8 m:
  - Bucket 1: 0.43 s (≈18.6 m/s); Bucket 2: 0.47 s (≈17.0 m/s); Bucket 3: 0.51 s (≈15.7 m/s, since 2026-07-28, was 0.49 s).
- Landing during/after an air dash with crouch held → "air slide", which preserves forward momentum and can be cancelled into jump/dash; ground slides cap forward momentum.
- "Instant Air Dash" (jump + near-instant air dash + slide) yields ~20% more speed than a standard air-dash slide; community suspects it is a bug. Do not replicate unless desired.
- **Down dash**: double-tap crouch in the air within 28 ticks (0.44 s); drives the hero downward. 1 per airtime (2 with Stamina Mastery). Cost conflict (0.5 vs 1).

### 12. Air control / air strafing
- Air strafing exists (steer with A/D + mouse) but is much weaker than in TF2/CS. It is considerably stronger below **450 u/s** and weaker above.
- 2025-05-08: air acceleration increased (only at lower speeds) to help wall-jump control.
- 2026-09-16: slows increase air drag (35% of slow value), implying there is a non-zero air drag term in the air model.
- Implementation: Source-style `air_accelerate` with a wishspeed cap, plus a speed-dependent multiplier that drops above 450 u/s, plus a small linear air drag.

### 13. Slide
- **Entry**: crouch pressed while grounded and horizontal speed > **350 u/s (8.9 m/s)**, NOT at any speed on a slope: measured session 7 (s7_ramp RS0/RSW), a fresh crouch press on a ~20-26° ramp at rest or at crouch-walk speed does not slide. A slope may still lower the threshold on landing (a 261 u/s curb-slope landing slid, session 6); untested between 187 and 350 u/s mid-slope. Also triggered after a ground dash if crouch is pressed/held (dash slide). "Slide storage": buffer crouch while airborne to slide instantly on landing on ramps/edges.
- **Cost**: none. Visual trail.
- **Friction**: base slide friction coefficient **0.1875** (vs normal ground). After **0.75 s** of sliding a "late slide penalty" raises friction to **~3.1875** (dash slide) or **0.6875** (dash-jump slide, penalty begins at 1.0 s).
- Slide-distance items delay the penalty: +35% (Fleetfoot) → 1.00 s (1.25 s dash-jump), +50% (Burst Fire) → 1.25 s (1.50 s), legendary +80% (Electric Slippers) further.
  - Inferred rule: `penalty_time = base_time + 0.25 s × floor-ish(bonus/35%)`. Better: `penalty_time = base × (1 + bonus)`? 0.75 × 1.35 = 1.01, 0.75 × 1.5 = 1.125 (doesn't match 1.25). Treat as a lookup table.
- **Slide jump**: jumping during a slide is allowed (since 2026-03-06). Normal jump rules apply (free).
- Sliding does not break sprint. Weapons have infinite ammo while sliding (per wiki; may be outdated — verify).
- Exit: release crouch (→ crouch-walk or stand), speed falls below crouch-walk speed, or jump.

### 14. Wall jump and corner boost
- Airborne and near a wall: press jump to wall jump. Wall detection considers all walls in a small radius around the player (2025-05-08).
- First wall jump per airtime is free; each subsequent costs 0.5 stamina (2025-10-02).
- **Fatigue**: each successive wall jump has reduced **vertical** launch only; fatigue recovers non-linearly over **1.25 s** and fully resets on landing. Airborne melee also incurs wall jump fatigue.
- Lateral kick-off speed depends on WASD input: toward the wall, away from it, or neutral give different kick-away speeds (2025-04-04 / 2025-05-08).
- Wall jump in combat: −25% stamina regen for 5 s.
- **Corner boost**: jumping off a convex corner uses the capsule's rounded contact normal (angled upward), giving a steeper, faster launch. Reduced by 20% on 2025-10-02. "Dropdown corner boost" = wall jump right after walking off a ledge.

### 15. Mantle
- Trigger: holding forward toward a ledge + jump (or hold jump to buffer). Requires WASD toward the ledge (2025-04-04).
- Ledge height bands and durations: 32–64 u → ~0.2 s; 64–96 u → 0.3 s; 96–128 u → 0.4 s; 128–160 u → 0.5 s. Ledges below 32 u are stepped/jumped, not mantled. Minimum ledge depth 6 u. Max activation distance 212 u (from wiki; interpret as reach check).
- Player is not actionable during the mantle; ends in grounded state (refreshing air actions). No stamina cost on the ground.
- **Mantle glide**: holding crouch while mantling transitions into a slide on completion.
- Taking melee damage while mantling: 80% slow tapering to 20% over 2 s.
- Heavy melee can be used to mantle at ledges.

### 16. Ziplines
- Lane-following rails. Attach by jumping/pressing into the line (attach radius not published). On attach: sprint is reset; air jump and air dash are refreshed.
- Speed is fixed, not hero-based: **inner lane 18 m/s, outer lanes 21 m/s** (outer +15% on 2025-02-25).
- **Zipline Boost** (F key): +80% speed for 32 s; 360 s cooldown; available from 360 s match time. Destroying a base Guardian permanently makes that lane's line an **express line** (+80%). Movement powerup: +40–80% zipline speed (scales with game time).
- Direction: on attach, movement input can override travel direction (2025-04-04).
- **Lockout**: taking damage from enemy heroes or objectives prevents attaching for 3 s (neutral damage does not).
- **Knock-off**: enemy hero damage during the first 3 s of riding knocks the rider off: falls straight down, takes 15% max HP (reduced by spirit resist), then stunned 2.5 s starting on landing (2025-07-29). DoT does not trigger knockoff.
- After 3 continuous seconds, rider becomes immune to knockoff (blue particles); instead damage taken adds +53.6% as extra damage.
- **Exit**: press crouch to drop; momentum along the line is preserved for 2 s. Jump off likewise (assumed). Victor's Aura of Suffering can be activated on zipline (2026-03-10), implying most abilities are otherwise restricted — per-ability flag.
- Jump pads have an analogous 0.6 s vulnerable window: damage → stun until 0.2 s after landing, then 30% slow for 2 s (2025-10-24); 15% max HP damage if hit during window (2025-12-16).

### 17. Ropes
- Vertical ropes; holding jump after attaching continues climbing. Climb speed not published. After taking player damage, climbing is 40% slower for 4 s.

### 18. Fall damage
- None. Heroes take no damage from any fall height.

### 19. Melee movement interactions
- **Light melee**: instant; brief self-slow afterward (hero-specific amount). No longer pauses the gun cycle (2026-09-16).
- **Heavy melee**: wind-up then lunge ≈ half a dash (~5 m assumed; wiki only says "approximately half a dash") in facing direction; reduced turn rate during animation; cooldown 1.0 s on hit, 1.3 s on miss (2025-07-29); can be charged in the air; can mantle ledges. Self-slow after.
- **Heavy melee cancel**: cancel the heavy with an item/ability. Momentum preservation from this was heavily reduced on 2025-04-17 (now negligible for movement).
- Airborne melee incurs wall-jump fatigue.
- **Parry**: 1 s animation; active window the first 0.75 s; on success attacker is stunned 2.75 s (not reduced by debuff resist) and takes +25% damage from all sources (current wiki; history: 35% melee-only -> 30% all damage on 2025-07-29 -> 25% at a later patch not located); failed parry cooldown 4.5 s (2.75 s with Rebuttal); 0.3 s lockout after a successful parry. Anti-mash: 0.25 s after the initial parry input (2026-04-10; previously 0.25 s after parry success). Parry cancels a ground dash and its momentum (2026-09-16); parrying pauses reload.

### 20. Hitbox / hero size
- No public capsule dimensions. Community reports: hitboxes follow model silhouettes closely but vary widely per hero (some larger than the model, e.g. backpack areas; some smaller, e.g. Silver's hair/tail). Movement collision is a capsule (evidenced by corner-boost behavior from "rounded collision capsules").
- Suggested default until measured: capsule radius ~16 u (0.41 m), standing height ~72 u (1.83 m), crouch height ~48 u (1.2 m) — Source conventions, **inferred**, low confidence.

---

## Values

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Hammer unit | 0.0254 | m/u | wiki | n/a | high | [1] |
| Sim tick rate (28 ticks = 0.44 s) | 64 | Hz | inferred | 2025–26 | medium | [5] |
| Base move speed range | 6.2–8.2 | m/s | wiki | 2026 | high | [4],[2] |
| Move speed Abrams / Haze / Holliday / Yamato | 6.4 / 8.2 / 8.2 / 8.2 | m/s | wiki (community-datamine) | 2026 | high | [4] |
| Move speed Bebop / Celeste / Doorman / Mo&Krill / Vindicta | 6.45 / 6.2 / 7.9 / 8.0 / 7.9 | m/s | wiki (community-datamine) | 2026 | high | [4] |
| Typical base sprint speed | 1.6 | m/s | wiki | 2026 | high | [4] |
| Sprint speed outliers: Bebop, Rem 4.0; Paige 3.5; Silver 2.5; Lady Geist 2.4; Graves 2.2; Lash 2.1; Seven 1.8; Kelvin, Victor 1.1; Venator 1.0 | see cell | m/s | wiki / official | 2026-09-16 (Silver) | high | [4],[14] |
| Base sprint change | −0.4 | m/s | official | 2025-12-16 | high | [12] |
| Sprint instant portion | 2.5 | m/s | official | 2025-12-16 | high | [12],[3] |
| Sprint ramp rate above instant portion | 0.6 | m/s per s | official | 2025-12-16 | high | [12] |
| Sprint out-of-combat delay (hero/neutral interaction) | 3 (old -> new: "5 or 3, conflict" -> 3; wiki's 5 is stale) | s | official | 2025-12-16 | medium | [12],[35] |
| Firing move-speed multiplier | 0.75 | × | official | 2025-07-29 | high | [11],[3] |
| Crouch-walk speed | 4.8 (4.4 Grey Talon, Warden) | m/s | wiki | 2025–26 | medium | [3] |
| Move bonus DR constant K | 12 | m/s | wiki | post 2025-12-16 | medium | [3] |
| Move speed DR ramp knee | ~11 (was ~10) | m/s | official | 2026-03-06 | medium | [13] |
| Vent move-speed boost | +70 | % | wiki | 2025–26 | medium | [3] |
| Slow floor | 2.0 (80 u/s) | m/s | wiki | 2025–26 | high | [15] |
| Global move slow reduction | ~20 | % | official | 2026-09-16 | high | [14] |
| Global ground-dash slow reduction | ~10 | % | official | 2026-09-16 | high | [14] |
| Slow → extra air drag | 35 | % of slow value | official | 2026-09-16 | high | [14] |
| Damage slow (portion above base speed) | 20 | % | official | 2025-12-16 | high | [12] |
| Rope climb slow after player damage | 40 for 4 s | %, s | official | 2025-07-29 | high | [11] |
| Base stamina | 2–4 (most 3) | bars | wiki | 2026 | high | [4] |
| Stamina display cap | 8 | bars | wiki | 2026 | medium | [2] |
| Stamina cooldown per bar (default) | 4.5 (was 5; wiki Stamina page still 5) | s | official / wiki | 2025-12-16 | high | [12],[4] |
| Stamina cooldown range | 4.2 (Mina) – 6.0 (Shiv); Bebop, Kelvin 5.5; Celeste 5.3 | s | wiki / official | 2026-09-16 | high | [4],[14] |
| Ground dash cost | 1 | bar | wiki | 2026 | high | [2] |
| Air dash cost | 1 | bar | wiki | 2026 | high | [2] |
| Dash-jump extra cost | 1 (2 total) | bar | wiki | 2026 | high | [1],[2] |
| Air jump cost | 1 | bar | wiki | 2026 | high | [2],[6] |
| Down dash cost | 0.5 (Movement page) or 1 (Stamina page); still conflicting 2026-09-27 | bar | wiki | 2025–26 | low | [1],[2] |
| First wall jump cost | 0 | bar | official | 2025-10-02 / 2025-12-16 | high | [10],[12] |
| Subsequent wall jump cost | 0.5 | bar | official | 2025-10-02 | high | [10] |
| Wall-jump combat regen penalty | −25 for 5 s | %, s | wiki | 2025–26 | medium | [2] |
| Wall-jump fatigue recovery | 1.25 (was 2) | s | official | 2025-05-08 | high | [37],[1] |
| Corner boost velocity change | −20 | % | official | 2025-10-02 | high | [10] |
| Ground dash distance (all heroes) | 10 | m | wiki | 2026 | high | [2] |
| Air dash distance (all heroes) | 8 | m | wiki | 2026 | medium | [2] |
| Ground dash duration B1 / B2 / B3 | 0.62 / 0.68 / 0.72 | s | wiki / official | 2026-07-28 | high | [2],[5],[16] |
| Ground dash speed B1 / B2 / B3 | 635 / 579 / ~547 (16.1 / 14.7 / 13.9 m/s) | u/s | wiki (community-datamine) / inferred | 2026-07-28 | high B1/B2; medium B3 (547 inferred from 10 m / 0.72 s; wiki still lists pre-patch 562) | [5],[2],[16] |
| Air dash duration B1 / B2 / B3 | 0.43 / 0.47 / 0.51 | s | wiki / official | 2026-07-28 | high | [2],[16] |
| Air dash speed B1 / B2 / B3 | 18.6 / 17.0 / 15.7 | m/s | wiki | 2026-07-28 | high | [2] |
| Dash bucket membership | B1: Calico, Celeste, Grey Talon, Haze, Holliday, Ivy, Mina, Paradox, The Doorman. B2: Apollo, Billy, Drifter, Graves, Infernus, Lash, McGinnis, Mirage, Pocket, Seven, Silver, Sinclair, Vindicta, Viscous, Vyper, Warden, Wraith, Yamato. B3: Abrams, Bebop, Dynamo, Kelvin, Lady Geist, Mo & Krill, Paige, Rem, Shiv, Venator, Victor (corrected in fidelity pass 1 from "most others B1"; movement_behavior/ground_dash.md Q10) | — | wiki Stamina page | 2026 | high | [2] |
| Dash-jump window open | 0.3 after dash start | s | wiki | 2025–26 | high | [5] |
| Dash-jump window length | 0.25 (0.30-0.55 s; corrected in fidelity pass 1 from 0.2, movement_behavior/ground_dash.md rule 11) | s | wiki | 2025–26 | high | [5] |
| Dash-jump air-control bonus | +30 for 0.25 s | %, s | official | 2026-03-06 | high | [13] |
| Down-dash double-tap window | 28 ticks (0.44) | s | wiki | 2025–26 | high | [5] |
| Air jumps per airtime (base / Stamina Mastery) | 1 / 2 | count | wiki | 2026 | high | [6] |
| Air dashes per airtime (base / Stamina Mastery) | 1 / 2 | count | wiki | 2026 | high | [5] |
| Ground jump peak vertical speed | 295 | u/s | wiki | 2025–26 | medium | [6] |
| Ground jump max height | 45 | u | wiki | 2025–26 | medium | [6] |
| Gravity (derived) | ~967 (24.6 m/s²) | u/s² | inferred | 2025–26 | low | [6] |
| Hero gravity: Celeste / Ivy | −25 / −10 | % | wiki | 2026 | medium | [4] |
| Post-jump inaccuracy | −10% for 0.15 s | %, s | official | 2025-10-02 | high | [10] |
| Air-strafe strong/weak threshold | 450 | u/s | wiki | 2025–26 | medium | [7] |
| Slide entry speed | 350 (8.9 m/s) | u/s | wiki | 2025–26 | high | [8],[3] |
| Slide base friction | 0.1875 | coefficient | wiki (community-datamine) | 2025–26 | medium | [8] |
| Late slide penalty friction (dash slide / dash-jump slide) | ~3.1875 / 0.6875 | coefficient | wiki (community-datamine) | 2025–26 | medium | [8] |
| Late slide penalty onset (normal / dash-jump) | 0.75 / 1.00 | s | wiki | 2025–26 | medium | [8] |
| Penalty onset with +35% slide (Fleetfoot) | 1.00 / 1.25 | s | wiki | 2025–26 | medium | [8] |
| Penalty onset with +50% slide (Burst Fire) | 1.25 / 1.50 | s | wiki | 2025–26 | medium | [8] |
| Slide stamina cost | 0 | bar | wiki | 2025–26 | high | [8] |
| Mantle 32–64 / 64–96 / 96–128 / 128–160 u | 0.2 / 0.3 / 0.4 / 0.5 | s | wiki (community-datamine) | 2025–26 | medium | [17] |
| Mantle min ledge height | 32 | u | wiki | 2025–26 | medium | [17] |
| Mantle min ledge depth | 6 | u | wiki | 2025–26 | medium | [17] |
| Mantle max activation distance | 212 | u | wiki | 2025–26 | low | [17] |
| Melee-hit-while-mantling slow | 80 → 20 over 2 s | % | wiki | 2025–26 | medium | [1] |
| Zipline speed inner / outer | 18 / 21 | m/s | wiki | 2025-02-25+ | high | [18] |
| Zipline boost | +80 for 32 s, CD 360 s, unlock 360 s | %, s | wiki | 2025–26 | high | [18] |
| Express line (guardian destroyed) | +80 | % | wiki | 2025–26 | high | [18] |
| Movement powerup zipline bonus | +40–80 (scales w/ time) | % | wiki | 2025–26 | medium | [18] |
| Zipline attach lockout after enemy dmg | 3 | s | wiki | 2025–26 | high | [18] |
| Zipline knockoff vulnerable window | first 3 | s | wiki | 2025–26 | high | [18] |
| Zipline knockoff damage | 15 | % max HP | wiki | 2025–26 | high | [18] |
| Zipline knockoff stun (starts on landing) | 2.5 (was 3) | s | official | 2025-07-29 | high | [11] |
| Zipline immune extra damage | +53.6 | % | wiki | 2025–26 | medium | [18] |
| Zipline drop momentum retention | 2 | s | wiki | 2025–26 | medium | [18] |
| Jump pad vulnerable window | 0.6 | s | official | 2025-10-24 | high | [19] |
| Jump pad stun end after landing / slow | 0.2 s; 30% for 2 s | s, % | official | 2025-10-24 | high | [19] |
| Jump pad hit damage | 15 | % max HP | official | 2025-12-16 | high | [12] |
| Fall damage | none | — | wiki | 2025–26 | high | [1] |
| Heavy melee cooldown (hit / miss) | 1.0 / 1.3 | s | official | 2025-07-29 | high | [11],[20] |
| Heavy melee lunge | ~half a dash (~5 m) | m | wiki / inferred | 2025–26 | low | [20] |
| Parry animation / active window | 1.0 / 0.75 | s | wiki | 2025–26 | medium | [20] |
| Parry stun on attacker | 2.75 | s | wiki | 2025–26 | medium | [20] |
| Parry damage amp on attacker | +25 (current wiki; was 30 after 2025-07-29, 35 before) | % | wiki / official | 2026 | medium | [20],[11] |
| Failed parry cooldown (Rebuttal) | 4.5 (2.75) | s | wiki | 2025–26 | medium | [20] |
| Post-parry lockout | 0.3 | s | wiki | 2025–26 | medium | [20] |
| Parry anti-mash | 0.25 after input | s | official | 2026-04-10 | high | [21],[36] |
| Extra Stamina (T1, 800) | +1 bar, +12% recovery | — | wiki | 2025-05-08+ | high | [22] |
| Kinetic Dash (T2, 1600) | +1 bar, +12% rec.; dash-jump: +25% fire rate, +6 ammo, ≤7 s | — | wiki | 2026-01-30 | high | [23] |
| Stamina Mastery (T3, 3200) | +2 bars, +18% rec., +23% air jump/dash dist., +1 air action | — | wiki | 2026-01-30 | high | [24] |
| Sprint Boots (T1, 800) | +2.0 sprint (old -> new: "2 / 2.25" -> 2.0; 2.25 from 2025-10-02 was cut to 2.0 on 2025-12-16), +2 OOC regen | m/s | wiki / official | 2025-12-16 | high | [25],[12] |
| Enduring Speed (T2, 1600) | +2 move, +25% slow resist | m/s, % | wiki / official | 2025-12-16 | high | [26],[12] |
| Fleetfoot (T2, 1600) | +35% slide dist., no firing penalty; active +3 m/s, +40% slow resist, 5 s, CD 16 s | — | wiki | 2025–26 | high | [27] |
| Dash-distance modifiers | Slowing Bullets −20, Weighted Shots −20, Haunting Shot −36, Metal Skin −20, Colossus −22, Slowing Hex −26, Vortex Web −36, Mystic Slow −10, Lightning Scroll −10 | % | wiki | pre 2026-09-16 (−10% since) | medium | [5] |
| Powerup rune | +2–4 stamina, +1.5–4 sprint, 160 s | bars, m/s, s | wiki | 2025–26 | medium | [2],[3] |

---

## Open questions / needs in-game measurement

All measurements in a private custom lobby / Hideout / Sandbox with `sv_cheats true`, `citadel_hero_testing_enabled 1`, using `cl_showpos 1` (shows velocity), `host_timescale 0.25` for slow-mo recording, `citadel_enable_fast_stamina` to isolate costs, `noclip` to position, and screen recording at 120+ fps for frame counting. Only built-in commands; no memory reading, no file inspection.

1. **Ground acceleration & friction** — From standstill, hold W; record `cl_showpos` velocity per frame at timescale 0.25 until max. Release W at max; record decay to 0. Fit `accel` (Source: Δv = accel × wishspeed × dt) and `friction`.
2. **Backpedal/strafe speed** — Hold S, then A, then W+A; read steady-state velocity. Confirm whether any direction penalty exists.
3. **Sprint delay** — Take a bot hit, start a stopwatch (frame count) until velocity steps up by sprint amount. Distinguish damage vs. "interaction with neutrals".
4. **Gravity, jump height, air jump height** — Jump next to a wall with measured texture grid or use `cl_showpos` z-coordinate peak; do a double jump at apex and at takeoff. Verify 45 u height / 295 u/s and whether air jump sets or adds vertical velocity.
5. **Air acceleration model** — While airborne at various speeds (standing jump, dash-jump), strafe with A + mouse turn; log speed gain per second above/below 450 u/s. Measure passive air drag (horizontal speed decay with no input).
6. **Dash velocity profile** — At timescale 0.1, log velocity every frame during ground and air dashes: is it constant then abrupt stop, or eased? What speed remains at dash end? Does neutral-input dash go forward? Measure dash distance under a known dash-slow item to see whether duration or speed is scaled.
7. **Down dash cost and speed** — Use normal stamina; double-tap crouch in air; watch bar consumption (0.5 vs 1) and vertical velocity.
8. **Dash-jump output velocity** — Horizontal and vertical velocity at takeoff for each bucket hero (e.g. Haze B1, Abrams slow bucket).
9. **Dash bucket membership** — For each hero, time ground dash over 10 m (frame count). Resolves the garbled wiki table.
10. **Slide speed curve** — After ground dash + crouch, log velocity per frame; confirm friction 0.1875 then penalty at 0.75 s. Test slope sliding speed gain vs slope angle. Verify "infinite ammo while sliding".
11. **Slide jump** — Velocity at slide-jump takeoff: is slide speed fully preserved?
12. **Wall jump** — Launch velocity components for input toward/away/neutral; fatigue curve over 1–4 successive jumps; wall-detection radius (approach wall at increasing distances).
13. **Mantle** — Max reachable ledge height (build with ledge-height references on map geometry; use z from `cl_showpos` before/after); mantle glide exit speed.
14. **Zipline** — Attach radius (approach distances), attach behavior while dashing, exit velocity on jump vs crouch, momentum 2 s retention curve.
15. **Melee** — Heavy melee wind-up duration, lunge distance/speed (frame-log position), post-melee self-slow amount/duration for light vs heavy; turn-rate cap during heavy.
16. **Damage slow duration** — Get hit by a bot while sprinting; log velocity recovery time.
17. **Move speed DR curve** — Buy combinations of move-speed items (`citadel_give_gold`) and read stat panel / measured speed to fit K and the ~11 m/s knee.
18. **Stamina recovery formula** — Buy Extra Stamina (+12%) and time regen; confirm `cd/(1+r)` vs `cd×(1−r)`.
19. **Hero capsule size** — Walk into narrow gaps / crouch under overhangs of measured height; for hitboxes, use `citadel_spawn_all_heroes_in_a_line` and compare shots at silhouette edges (qualitative).
20. **Coyote time / jump buffer** — Walk off ledges and press jump N frames late (timescale 0.1).

---

## Implementation notes for Godot 4

- **Physics**: `CharacterBody3D` with `CapsuleShape3D`; set `physics_ticks_per_second = 64`. Write a custom Source-style move loop (friction → accelerate → gravity → `move_and_slide`) instead of relying on default velocity smoothing. Convert all wiki u-values with a `HU = 0.0254` constant.
- **State machine** (node-based or enum): `Grounded, Crouching, Sliding, Airborne, GroundDash, AirDash, DownDash, Mantling, WallJumpRecovery, Ziplining, RopeClimb, Stunned, MeleeWindup, HeavyLunge, Parrying`. Keep per-airtime counters (`air_jumps_left`, `air_dashes_left`, `down_dashes_left`, `wall_jumps_done`, `wall_fatigue`) reset on landing/zipline attach.
- **Data-driven resources**:
  - `HeroMovementStats` (Resource): base_move_speed, base_sprint_speed, stamina_max, stamina_cooldown, dash_bucket, gravity_scale, crouch_speed, capsule radius/height, spirit scaling coefficients.
  - `DashBucket` (Resource): ground_duration, air_duration, ground_distance=10 m, air_distance=8 m.
  - `MovementGlobals` (Resource): sprint delay, sprint ramp, instant sprint cap, firing multiplier, slide threshold, slide frictions & penalty times, dash-jump window, down-dash window, wall-jump costs/fatigue, mantle bands, slow floor, DR constant, air-strafe threshold, zipline speeds/timers.
  - `StatModifier` system (stack rules: move bonus = DR curve; sprint = additive; slows = multiplicative with additive resist and 2 m/s floor; dash distance = multiplicative %).
- **Stamina**: component node with float charges and a single regen timer; expose `can_spend(cost)`, `spend(cost)`, `disable(duration)`, `regen_multiplier` stack (wall-jump penalty).
- **Ziplines**: `Path3D` + `PathFollow3D`; rider snaps to follower; speed from lane resource × boost multipliers; `Area3D` for attach; knockoff logic listens to damage events with source filter.
- **Mantle / wall jump**: `ShapeCast3D` forward for walls (small radius sphere to satisfy "all walls in radius"), plus downward `RayCast3D` from above the ledge to find top height; pick mantle band by height.
- **Input buffering**: small ring buffer (e.g., 0.1–0.2 s) for jump/dash/melee/parry.
- **Data analysis**: public stats (hero pick/win rates, match metadata) are available from deadlock-api.com's public REST API; hero base stats are republished on the wiki's Hero Comparison Table. These are community-datamined; treat as reference, not ground truth, and never import game files.

---

## Sources

(All accessed 2026-09-27.)

1. https://deadlock.wiki/Movement
2. https://deadlock.wiki/Stamina
3. https://deadlock.wiki/Move_Speed (also /Movement_Speed)
4. https://deadlock.wiki/Hero_Attributes_Table
5. https://deadlock.wiki/Dashing
6. https://deadlock.wiki/Jumping
7. https://deadlock.wiki/Air_Strafing
8. https://deadlock.wiki/Slide
9. https://liquipedia.net/deadlock/Patch/Playtest/2025-05-08 (official patch notes mirror, 2025-05-08)
10. https://deadlock.wiki/Update:October_2,_2025
11. https://deadlock.wiki/Update:July_29,_2025
12. https://forums.playdeadlock.com/threads/12-16-2025-update.93983/ and https://deadlock.wiki/Update:December_16,_2025
13. https://deadlock.wiki/Update:March_6,_2026 and https://tracklock.gg/articles/deadlock-march-2026-patch-notes-nearly-900-changes-across-heroes-items-bases
14. https://deadlock.wiki/Update:September_16,_2026 and https://deadlock.one/en/news/deadlock-patch-notes-09162026-minor-update
15. https://deadlock.wiki/Movement_Slow
16. https://deadlock.wiki/Update:July_28,_2026
17. https://deadlock.wiki/Mantling
18. https://deadlock.wiki/Ziplines
19. https://deadlock.wiki/Update:October_24,_2025
20. https://deadlock.wiki/Melee_Attack
21. https://deadlock.wiki/Update:April_10,_2026
22. https://deadlock.wiki/Extra_Stamina
23. https://deadlock.wiki/Kinetic_Dash
24. https://deadlock.wiki/Stamina_Mastery
25. https://deadlock.wiki/Sprint_Boots
26. https://deadlock.wiki/Enduring_Speed
27. https://deadlock.wiki/Fleetfoot
28. https://deadlock.wiki/Update:April_4,_2025
29. https://deadlock.wiki/Update:March_10,_2026
30. https://deadlock.wiki/Updates
31. https://deadlock.io/en/mechanics/movement-and-stamina
32. https://forums.playdeadlock.com/threads/instant-air-dash-iad-what-it-is-how-it-works-and-why-its-probably-a-bug.105874/
33. https://deadlock.wiki/Console_commands
34. https://forums.playdeadlock.com/threads/incorrect-hero-hitboxes-provide-a-significant-advantage-in-the-game-detailed-comparison.137294/
35. https://deadlock.wiki/Update:February_25,_2025
36. https://forums.playdeadlock.com/threads/04-10-2026-update.125825/
37. https://deadlock.wiki/Update:May_8,_2025 (liquipedia mirror [9] returned HTTP 403 on 2026-09-27)

---

## Verification log (2026-09-27)

Adversarial re-check of ~25 implementation-critical claims against public sources only (deadlock.wiki pages, official forum patch notes, wiki mirrors of official notes). No game files, memory, or network traffic were inspected. Values marked "community-datamine" are published by the wiki from its own data extraction and are cited, not reproduced from files by us.

| # | Claim | Checked against | Outcome |
|---|---|---|---|
| 1 | Sprint out-of-combat delay | Wiki Move Speed / Movement (5 s); official 2025-12-16 forum notes (4 s -> 3 s); wiki Update:Feb 25, 2025 (5 s -> 4 s) | **Corrected**: 5-or-3 conflict resolved to **3 s** (medium). Wiki 5 s is stale. |
| 2 | "8-way sprint" implies omni-directional sprint | Wiki Update:Feb 25, 2025 | **Corrected/removed**: that note was one hero's animation polish, not a sprint rule. |
| 3 | Default stamina cooldown 4.5 s | Official 2025-12-16 notes ("5s to 4.5s"); Hero Attributes Table (4.5 most heroes); wiki Stamina page (still 5 s) | **Confirmed** 4.5 s; noted stale 5 s on Stamina page. |
| 4 | Per-hero stamina CD outliers (Mina 4.2, Shiv 6, Bebop/Kelvin 5.5, Celeste 5.3) | Hero Attributes Table; Update:Sep 16, 2026 (Celeste 5 -> 5.3) | Confirmed. |
| 5 | Base move speeds (Abrams 6.4, Haze/Holliday/Yamato 8.2, Bebop 6.45, Celeste 6.2, Doorman 7.9, Mo&Krill 8.0, Vindicta 7.9) | Hero Attributes Table | Confirmed; re-tagged community-datamine. |
| 6 | Sprint outliers (Bebop/Rem 4, Paige 3.5, Silver 2.5, Geist 2.4, Graves 2.2, Lash 2.1, Seven 1.8, Kelvin/Victor 1.1, Venator 1.0) | Hero Attributes Table; Sep 16, 2026 (Silver 1.5 -> 2.5); Jul 28, 2026 (Venator 1.5 -> 1) | Confirmed. |
| 7 | Sprint ramp: instant +2.5, then 0.6 m/s per s; base sprint -0.4 | Official 2025-12-16 notes; wiki Move Speed | Confirmed. |
| 8 | Firing multiplier 0.75 | Update:Jul 29, 2025 (-30% -> -25%); wiki Move Speed | Confirmed. |
| 9 | Move bonus DR K = 12; knee ~11 m/s | Wiki Move Speed formula; Update:Mar 6, 2026 | Confirmed (both as stated; exact curve remains unverified). |
| 10 | Slow stacking, resist, 2.0 m/s floor | Wiki Movement Slow | Confirmed. |
| 11 | 2026-09-16 slow changes (~20% move slow, ~10% dash slow, air drag 35%) | Wiki Update:Sep 16, 2026 | Confirmed. |
| 12 | Damage slow 20% of above-base portion; on-hit slow removed | Official 2025-12-16 notes | Confirmed; added that the old slow was 10%. |
| 13 | Ground dash B1/B2/B3 durations and speeds | Wiki Dashing (635/579/562 u/s, 0.62/0.68/0.70 s); wiki Stamina (0.72 s, 13.9 m/s); Update:Jul 28, 2026 (0.70 -> 0.72) | Durations confirmed. **Downgraded** B3 u/s to medium: 547 u/s is inferred; wiki Dashing still shows pre-patch 562. |
| 14 | Air dash durations 0.43/0.47/0.51 s, 8 m | Wiki Stamina; Update:Jul 28, 2026 (0.49 -> 0.51) | Confirmed. |
| 15 | Dash-jump window 0.3 s + 0.2 s; down-dash 28 ticks / 0.44 s | Wiki Dashing | Confirmed (64 Hz tick remains inferred). |
| 16 | Down dash cost | Wiki Movement (0.5) vs wiki Stamina (1) | Still conflicting; kept low. Measure in-game. |
| 17 | Wall jump costs (first free, then 0.5) | Update:Oct 2, 2025; official 2025-12-16 notes; wiki Movement | Confirmed. |
| 18 | Wall-jump fatigue recovery 1.25 s (was 2 s) | Wiki Update:May 8, 2025 (Liquipedia mirror returned 403) | Confirmed; source swapped to wiki mirror. |
| 19 | Jump peak 295 u/s, height +45 u | Wiki Jumping | Confirmed as published; derived gravity still inferred/low. |
| 20 | Slide threshold 350 u/s, frictions 0.1875 / ~3.1875 / ~0.6875, penalty onset 0.75/1.00 s, item delays | Wiki Slide; wiki Move Speed | Confirmed; re-tagged community-datamine. Infinite-ammo-while-sliding still stated on wiki. |
| 21 | Mantle bands, 6 u depth, 212 u activation | Wiki Mantling | Confirmed; re-tagged community-datamine. |
| 22 | Zipline speeds 18/21 m/s, boost +80%/32 s/360 s, lockout 3 s, knockoff 15% HP, stun 2.5 s, +53.6%, 2 s momentum | Wiki Ziplines; Update:Feb 25, 2025 (+15% outer); Update:Jul 29, 2025 (3 -> 2.5 s) | Confirmed. |
| 23 | Jump pad 0.6 s window, stun ends 0.2 s after landing, 30% slow 2 s | Wiki Update:Oct 24, 2025 | Confirmed. |
| 24 | Heavy melee CD 1.0 / 1.3 s | Update:Jul 29, 2025; wiki Melee Attack | Confirmed. Lunge ~5 m remains inferred/low. |
| 25 | Parry 1.0 s anim / 0.75 s window / 2.75 s stun / 4.5 s fail CD / 0.3 s lockout / +25% amp | Wiki Melee Attack; Update:Jul 29, 2025 (35 -> 30%) | Confirmed per wiki; the 30 -> 25% change date was not located (medium). |
| 26 | Parry anti-mash 0.25 s from input; parry during ground dash | Wiki Update:Apr 10, 2026; official forum 04-10-2026 | Confirmed. |
| 27 | Sprint Boots sprint value | Wiki Sprint Boots; Oct 2, 2025 (2 -> 2.25); Dec 16, 2025 (reduced to 2.0) | **Corrected**: "+2 (+2.25)" -> **+2.0** current, confidence raised to high. |
| 28 | Enduring Speed +2 m/s, 25% slow resist | Wiki Enduring Speed; Dec 16, 2025 notes | Confirmed. |
| 29 | Extra Stamina / Kinetic Dash / Stamina Mastery / Fleetfoot values | Respective wiki item pages (Kinetic Dash and Stamina Mastery last changed 2026-01-30) | Confirmed; patch dates updated to 2026-01-30. |

**Legality pass:** no lore, voice lines, art, or long verbatim ability text found. Quotes kept to short phrases. No claim is derived from the spec writer extracting game files; wiki-published numbers that appear to come from the wiki's own data extraction (hero stat table, dash u/s, slide frictions, mantle bands) are now tagged "community-datamine". The Open-questions test plan uses only built-in console commands; the exact command names are unverified and should be checked in-game before use. Nothing was removed.

**Still unverified / needs measurement:** down dash cost, B3 ground dash peak u/s, gravity, air accel/drag values, ground accel/friction, heavy melee lunge distance, non-hero-damage sprint delay (0.5 s in 2025-02-25 notes), date of parry amp 30 -> 25%.
