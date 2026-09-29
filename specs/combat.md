# Combat Spec

> Clean-room observation record. Describes observed behavior of Deadlock (Valve) for the purpose of independent reimplementation. No game code or assets were used.

Scope: gunplay and the damage model: weapon stats, falloff, headshots, damage types, resists, barriers, health and regen, healing reduction, lifesteal, crowd control, melee and parry, respawn timers, and how boons grow damage.

Data currency: the most recent sources are the September 2026 patches (latest general notes are 09-16-2026, and the wiki pages were edited 2026-09-10 to 09-17). Per-hero numbers come from the public deadlock-api.com assets API (`/v1/assets/heroes`, `/v1/assets/items`, `/v1/assets/npc-units`, `/v1/assets/generic-data`), fetched 2026-09-27. They are tagged **community-datamine** because that site builds them from its own extraction of game data. Valve changes values almost every patch, so treat every number as a tunable default.

Units: the game engine measures distance in units where **1 m = 39.37 units** (1 unit = 1 inch). This was checked against the data: 787 units matches the wiki's 20 m falloff start, and 30000 units/s matches Haze's 762 m/s. Distances in this spec are in meters unless marked `u`.

---

## Summary

- Every hero carries one **primary gun** plus melee, dash, sprint and parry. Guns fire **projectiles**, not hitscan. Bullets have a real travel speed of 43–1590 m/s, a per-hero gravity scale, a collision radius and a lifetime. Each shot can fire several pellets and some guns fire bursts. Two guns spin up and fire faster the longer the trigger is held. Magazines reload either all at once or one shell at a time (Abrams and Silver).
- **Damage falloff** is linear with distance. Damage is 100% up to a hero-specific start range (usually about 20 m), then drops linearly to a minimum scale at the end range (usually 10% of base at about 46–64 m). A few heroes are exceptions.
- **Headshots** (weakpoint hits) multiply bullet damage by **1.65×** (since 2025-11-21; it was 1.8× before). The weakpoint exists on heroes, troopers, neutrals and Lane Guardians. Base Guardians have no weakpoint. Some attacking heroes have a negative *crit bonus scale*, which makes their headshots weaker. Some defending heroes take reduced crit damage.
- **Damage types:**
  - **Weapon** (bullet and melee): reduced by Bullet Resist.
  - **Spirit** (most abilities and items): reduced by Spirit Resist.
  - **Pure**: ignores resists and barriers, and only invincibility stops it.
  - Melee is a subtype of weapon damage. It gets only 50% of Weapon Damage % bonuses and has its own Melee Resist.
- **Resists stack multiplicatively**: total = 1 − Π(1 − Rᵢ). **Resist reduction (shred)** stacks multiplicatively within itself and is then *subtracted* from total resist. The result can go negative, which amplifies damage. No hard cap is documented.
- **Barriers** have been one generic type since 2025-05-08 (the old separate bullet and spirit shields were merged). A barrier is a temporary health pool that absorbs damage after resists. Barriers stack additively and decay over time. Pure damage and Armor Piercing Rounds skip them.
- **Health**: Max HP = (base + boons × HP per boon) × (1 + vitality %) + flat bonus HP.
  - Base regen is 1–3.5 HP/s depending on the hero.
  - Extra out-of-combat regen from items turns on after a combat timer runs out. The timer is 4 s after hero damage, and a separate, shorter timer applies to NPC damage.
  - Standing in your own base heals +60 HP/s plus 6% of max HP per second.
- **Healing reduction**, **lifesteal**, **movement slow** and **fire-rate slow** all stack multiplicatively. Lifesteal is weaker against non-heroes. Slows cannot push movement below 2 m/s. Fire-rate slows are floored at −50%.
- **Crowd control types:** stun, silence, disarm, immobilize, sleep, displacement, curse and others. **Debuff Resist** shortens debuff durations (not their strength). Stuns and some other hard CC have **diminishing returns**: the 2nd CC within a 9 s window is 15% shorter, and the 3rd or later is 35% shorter (values from 2026-04-10). Silences and slows are reportedly exempt.
- **Melee:**
  - Light melee is instant and deals about 50 damage.
  - Heavy melee is a held input with a 0.36 s windup, a lunge of up to 0.6 s and a 0.283 s recovery (1.25 s total). It deals about 116 damage. Cooldown is 1.0 s on hit and 1.3 s on miss.
  - **Parry** has a 0.75 s active window. A successful parry blocks the hit and stuns the attacker for 2.75 s. That stun cannot be reduced by debuff resist. The attacker also takes +25% damage from all sources. A missed parry puts it on a 4.5 s cooldown.
- **Boons** are 35 levels earned from souls. Each boon adds a per-hero increment to base bullet damage, melee damage, base HP and spirit power.
- **Respawn** time rises linearly with match time: 8 s at 5 min, 38 s at 20 min, 70 s at 30 min, 85 s at 40 min, capped at 90 s. Modifiers apply for dying to NPCs, for "comeback" kills and for Patron events.

---

## Mechanics

### 1. Damage pipeline (order of operations)

Implement one central `apply_damage(source, target, DamageInfo)` function. The order below is assembled from the wiki's Damage Amplification, Weapon Damage and Headshot pages. Parts are inferred where marked.

```
raw      = base_damage                               # bullet: hero base + boons*per_boon (+ spirit scaling for a few heroes)
                                                     # spirit ability: base + coef * SpiritPower
raw      = raw * (1 + sum(weapon_damage_pct))        # additive % pool (weapon dmg items, investment bonus); melee uses 50% of it
raw      = raw * (1 + sum(additive_amps))            # additive amps/reductions pool (negative reductions included)
raw      = raw + flat_bonus                          # flat weapon damage is NOT multiplied by the % above
raw      = raw * falloff_scale(distance)             # weapon damage and "weapon-related" procs only
raw      = raw * crit_mult  (if weakpoint hit)       # bullets only; see §3
raw      = raw * prod(multiplicative_amps)           # e.g. parry vulnerability +25%, "damage taken" debuffs
raw      = raw * (1 - effective_resist(type))        # §5; pure damage skips this
-> absorbed by barrier first (§6), overflow goes to health; pure skips barriers
-> lifesteal is computed from the damage dealt (§9)
```

- The wiki's short form is `Final = [(Base × DmgMult) + Flat] × Falloff × Resistances × Crit`. Falloff, resist and crit are all multiplicative, so their relative order only matters for flat terms and clamps (source 3).
- "Instance amps" are multiplicative amps that are dealt as a separate damage instance. That matters for on-hit procs and damage numbers (source 11).
- Since 2026-01-30, various on-bullet-hit resist-reduction debuffs apply **after** the hit that applies them, so the reducing hit is not amplified by its own shred (source 24). The notes do not say this covers every spirit shred; treat others as unverified.
- Some spirit-damage reductions (for example Silencer, and Infernus Afterburn T2) are additive with each other but multiplicative against the other additive amps (source 11).

### 2. Weapon model

Each hero's gun is a data record. Field names below are descriptive. Values are in the per-hero table.

| Field | Meaning |
|---|---|
| `bullet_damage` | damage per pellet or bullet at 0 boons |
| `bullet_damage_per_boon` | added to `bullet_damage` for each boon |
| `pellets` | projectiles per shot (shotguns 3–9) |
| `cycle_time` | seconds between shots (or between bursts); fire rate = 1 / cycle_time |
| `burst_count`, `intra_burst_time` | shots per trigger pull and the gap between them (Seven, Lash: 3 @ 0.084 s; Paradox 5 @ 0.0735 s; Sinclair 2 @ 0.105 s) |
| `spins_up`, `max_spin_cycle_time`, `spin_increase_rate`, `spin_decay_rate` | McGinnis: 0.21 s → 0.084 s (+0.5/s, −0.25/s); Victor: 0.198 s → 0.171 s (+0.6/s, −1.0/s). The rates are probably the fraction of the spin range gained or lost per second (**inferred**) |
| `clip_size` | magazine size. Some heroes scale it with spirit power (Haze +0.5 per spirit power) |
| `reload_duration` | full reload time. For single-shell heroes it is the time per shell |
| `reload_single`, `reload_single_initial_delay`, `allow_cancel` | Abrams (0.705 s delay, 0.3525 s per shell) and Silver (0.5 s delay, 0.3 s per shell). Firing interrupts the reload. Abrams's full reload is about 3.5 s |
| `bullet_speed` | projectile speed (u/s) |
| `gravity_scale` | projectile drop multiplier (0 means no drop; Haze 1.5; most guns 0.8) |
| `bullet_radius` | collision radius against units (3 u ≈ 7.6 cm, up to 25 u ≈ 63.5 cm for Paige) |
| `bullet_radius_vs_world` | separate, usually smaller, radius against world geometry |
| `bullet_lifetime`, `range` | seconds before the projectile despawns (usually 2 s), and max travel (7000 u ≈ 178 m; Apollo 1000 u, Bebop 1260 u, Rem 3000 u) |
| `falloff_start`, `falloff_end`, `falloff_end_scale` | see §4 |
| `crit_bonus_start/end`, `crit_start/end_range` | headshot multiplier at 500 u and at 1500 u. Both are 1.65 for every hero right now, so there is effectively no range-based crit change |
| `shoot_move_speed_pct` | move-speed multiplier while firing: 0.75 (Rem 0.85) |
| spread and recoil | per-shot spread penalty (Haze 0.4 per shot, decays at 4/s), vertical punch, aim-down-sights spread penalty, standing-shot penalty (Graves, Silver) |

**DPS formulas.** These were checked against the dataset: Haze gives 5.26 / 0.105 = 50.1 DPS and 26.43 sustained.

- `burst DPS = bullet_damage × pellets × burst_count / period`, where `period = cycle_time` for normal guns and `cycle_time + burst_count × intra_burst_time` for burst guns. So for burst guns `cycle_time` is the pause after a burst, not burst start to burst start. This is **inferred** from the table's Base DPS column (Lash 8.46 × 3 / (0.2625 + 0.252) = 49.3; Seven 63.0; Paradox 51.4; Sinclair 48.3). Using `cycle_time` alone would give Lash 96.7.
- `sustained DPS = damage_per_magazine / (clip_size × cycle_time + reload_duration)`

**Firing state machine:**

```
IDLE -> (trigger) -> FIRING: spawn pellets; ammo -= 1 per shot; next shot allowed at t + cycle_time
     (burst: fire burst_count shots, spaced intra_burst_time apart, each costing ammo; then wait cycle_time)
FIRING -> (ammo == 0) -> RELOADING (auto)          | manual reload key -> RELOADING when ammo < clip
RELOADING(full): after reload_duration*reload_mult, ammo = clip
RELOADING(single): wait initial_delay, then +1 shell per reload_duration; firing cancels the reload (keeps loaded shells)
Melee or dash during a reload pauses it until that animation ends (Billy's reload continues during light melee).
Since 2026-09-16, dashes and light melee no longer pause the gun's cycle-time timer (source 38).
```

- **Fire-rate modifiers:** see §12.
- **Reload modifiers:**
  - "Reload Time −x%" is a multiplier on reload time.
  - Active Reload adds a 0.3 s quick-time window. Hitting it skips 50% of the reload.
  - Some items refill ammo on hit or cancel the reload. Vampiric Burst, for example, adds 75% of base ammo.
- **Projectiles:** simulate each bullet as a swept sphere moving at `bullet_speed`, affected by gravity. Shooter velocity is not inherited (`inherit_shooter_velocity_scale = 0`). A bullet hits the first unit hitbox it overlaps; a hit on the head hitbox counts as a crit. Paige's bullets pierce and can hit several enemies, but do not get headshot bonus damage.
- **Graves, Apollo, Silver** have a flat bullet-speed curve of 22500 u/s (571.5 m/s) in the data. The wiki says Apollo and Graves deal no damage beyond their max range.

### 3. Headshots / crits

- Hitting the **head hitbox** (weakpoint) applies `crit_mult`. The base value is **1.65** (from 2025-11-21; 1.8 before).
- **Units with a weakpoint:** heroes, troopers, neutrals, Lane Guardians. **No weakpoint:** Base Guardians. Walkers, Shrines and the Patron are not documented (see Open questions). The npc-units data lists dedicated "weakpoint" neutral entities.
- **Attacker crit bonus scale** (a hero stat that weakens that hero's own headshots): Billy −20%, Celeste −25%, The Doorman −30%, Drifter −45%, Kelvin −25%, Rem −20%, Vyper −30%.
  - Likely formula (**inferred**): `crit_mult = 1 + 0.65 × (1 + crit_bonus_scale)`, which gives Drifter 1.3575×.
- **Target crit reduction** (defender stat `crit_damage_received_scale`): Seven 0.45 (55% reduction), Mo & Krill 0.8, Rem 0.9. Everyone else is 1.0.
  - Likely formula (**inferred**): `crit_mult_final = 1 + (crit_mult − 1) × crit_damage_received_scale`.
- **No crits at all:** Graves; Paige (can still trigger headshot items); Viscous alt-fire; Yamato alt-fire.
- **Headshot items** add flat bonus damage to a headshot, often on an internal cooldown. Examples: Headshot Booster +45 damage with a 9 s cooldown; Headhunter +75 damage with an 8 s cooldown and a 4% heal. These are separate "proc" damage instances.

### 4. Damage falloff

```
d = distance from muzzle to hit point (a hit through a portal uses the portal-traversed distance, fixed 2025-11)
if d <= start: scale = 1.0
elif d >= end: scale = end_scale          # 0.1 for most heroes
else: scale = lerp(1.0, end_scale, (d - start) / (end - start))
```

- **Defaults:**
  - Start 20 m (787 u), end about 57.5 m (2264 u), end scale 0.1 (−90%).
  - Per-hero start ranges run from 7.6 to 25.4 m and end ranges from 17 to 64 m.
  - The 2026-09-16 notes changed Lash's gun falloff from 18–54 m to 16–48 m (confirmed on the wiki's Update:September_16,_2026 page and in the API data). Some third-party summaries misreport this as 20–58 → 18–54.
- **Exceptions:**
  - Sinclair: end scale 0.3 (−70%).
  - Drifter: end scale 0.6 (−40%), 22→27 m.
  - Graves: end scale 0.5, 7.6→17 m. The wiki says Graves has "no falloff", but his falloff range still feeds his Build-Up calculations.
  - Apollo: 25.4 m hard cut-off, with no damage past it.
- **Where falloff applies:** it scales bullet damage and "weapon-related" item and ability effects, notably Build-Up procs. It does **not** scale spirit abilities.
- **Explosive rounds** (explosive alt-fires) deal 50% at the edge of the blast radius, and that is multiplied by the normal falloff.
- **Items:** Long Range gives +8% attack/falloff range and +40% weapon damage beyond 15 m. Sharpshooter gives +20% falloff range. Close Quarters gives +20% weapon damage within 15 m and 20% melee resist.
- The data also has a `damage_falloff_bias = 0.5` field on every weapon. If it bends the curve, 0.5 probably means linear. See Open questions.

### 5. Damage types and resists

| Type | Reduced by | Crits? | Notes |
|---|---|---|---|
| Weapon / Bullet | Bullet Resist | yes (bullets) | Includes bullet-based abilities. Trooper, guardian, neutral and mid-boss attacks also count as weapon damage |
| Melee | Bullet Resist and Melee Resist (**inferred**: stacked multiplicatively) | no documented crit | Counts as weapon damage but gets only 50% of Weapon Damage % bonuses. Trooper "player damage resist" is not applied to melee |
| Spirit | Spirit Resist | no | Most abilities and items; also Walkers, Shrines and the Patron |
| Pure | nothing (only invincibility) | no | Skips resist and barriers and does not trigger Mystic Reverb. Some "damage amp" displays are pure damage calculated after mitigation |

**Resist formulas** (the same for bullet, spirit and melee):

```
total_resist    = 1 - Π(1 - Rᵢ)          # positive sources, multiplicative
total_reduction = 1 - Π(1 - Sⱼ)          # shred sources, multiplicative
effective       = total_resist - total_reduction     # may be negative -> damage × (1 - effective) > 1
damage_taken    = damage × (1 - effective)
```

- Worked example: 40% and 20% resist give 52%. Reductions of 25% and 20% give 40%. Effective resist is 12%. At −30% effective resist, the target takes 130% damage.
- **Per-hero innate resists** (wiki Hero Comparison Table, 2026-09):
  - Bullet resist per boon: Bebop +0.3%, Dynamo +0.625%.
  - Spirit resist per boon: Kelvin +0.625%, McGinnis +0.35%.
  - Flat spirit resist: Lash +10%, Pocket −15%.
  - Melee resist: Rem −5%.
  - Venator gains +0.122% bullet and spirit resist per spirit power.
- **Items (examples):** Bullet Armor 18% bullet resist; Spirit Armor 15% spirit resist; Battle Vest 18% bullet resist; Rebuttal 18% melee resist.

### 6. Barriers (shields)

- A barrier is a temporary extra HP pool that is used before health. **Resist applies** to damage hitting the barrier. Damage beyond what the barrier holds carries over to health.
- **Pure damage** and **Armor Piercing Rounds** procs skip barriers.
- Multiple barriers stack **additively**. Every barrier now has a duration and decays over it (an undocumented change in May 2025).
- Healing amp and healing reduction do **not** change newly created barriers. Only Rem's Tag Along can change a barrier after it is created.
- **History:** before 2025-05-08, bullet shields and spirit shields were separate pools. They are now merged into one generic "Barrier".
- **Reactive barrier items:** Weapon Shielding and Spirit Shielding grant a 300 HP barrier.
  - They trigger when you take 250 or 225 damage within a 4 s or 3.5 s window.
  - The barrier lasts 8 s. Cooldown is 35 s for Weapon Shielding and 45 s for Spirit Shielding (API 2026-09; corrected 2026-09-27 from "7–8 s, 45 s cooldown").
  - Also granted: +18% bullet or spirit resist and +2.5 out-of-combat regen.
  - The 11-21-2025 notes changed both items to 45 s cooldown and 7 s duration; the current API data shows 35/45 s and 8 s, so later patches moved them again. Use the API data.

### 7. Health, regen, combat state

- `MaxHP = (BaseHP + boons × HP_per_boon) × (1 + vitality_pct) + flat_bonus_HP`
  - Base HP ranges from 660 (Mina) to 930 (Mo & Krill), and HP per boon from 27 to 65.
  - Vitality % comes from the vitality investment bonus and items such as Colossus (+25%).
  - Health bar UI: one segment per 100 HP, and one row per 1000 HP.
- **Base regen**: 1–3.5 HP/s per hero, always on. Most heroes have 2; Drifter has 3.5. Victor's regen also scales +0.08 per spirit power. Boons do not raise regen.
- **Out-of-combat (OOC) regen** is an extra flat HP/s (items only) that runs while the hero is out of combat. Examples: Extra Regen +1.5 OOC (plus +2.5 always-on); Battle Vest +3; Enchanter's Emblem +2.
  - **Combat timer vs heroes:** 4 s after dealing damage to, or taking damage from, a hero.
  - **Combat timer vs NPCs:** it is 0.5 s after taking damage from troopers or neutrals according to the wiki. The patch history says it went 0.5 → 2.5 s (2025-11-21) → 4 s (2025-12-03) against neutrals. **Conflict:** use 4 s for neutrals, and treat troopers as uncertain.
  - Dealing damage to NPCs alone does **not** start combat.
  - The sprint timer is a separate 5 s out-of-combat timer. Getting CC'd, zip-lining, crouching or stopping also resets sprint.
- **Max-health regen** is a separate %-of-max-HP-per-second stat (for example Fortitude +2.25%).
- **Base fountain**: +60 HP/s and +6% of max HP per second while standing in your own base's regen zone.
- **Getting shot slow** (added 2025-12-03): taking bullet damage applies a 10% movement slow for 0.7 s. Whether it is still current is unverified.

### 8. Healing reduction

- Healing reduction cuts all healing received: heals, heals over time, lifesteal, and item/ability heals from allies.
- Stacking is **multiplicative across different sources**: `total = 1 − Π(1 − Rᵢ)`. Two 40% sources give 64%.
- The **same source** applied again while active does **not** stack. Only the first instance counts (implement it as a refresh keyed by source).
- **Health Regen:** the wiki says ordinary regen is not reduced, but some items have a separate **regen penalty**. Healbane, for example, has −35% healing received *and* −35% regen, for 8 s. Model two separate stats: `heal_received_mult` and `regen_mult`.
- **Order:** healing reduction applies before Healing Amp is added.
- **Values:**
  - Hero abilities: 30–100%. Pocket's Affliction is 100%.
  - Items: 35–70%. Spirit Burn 70%, Cheat Death 60%, Decay 50% (was 45% after the 12-03-2025 notes; API 2026-09 shows 50%), Inhibitor 40%, Crippling Headshot 35%. Every item heal-reduction in the API data also carries an equal regen penalty.

### 9. Lifesteal

- There are two separate stats: **Bullet Lifesteal** (weapon damage) and **Spirit Lifesteal** (spirit damage). Melee lifesteal is its own item-based heal.
- Sources stack **multiplicatively**: `1 − Π(1 − Lᵢ)`. 22% and 30% give 45.4%.
- `heal = damage_dealt × lifesteal × nonhero_factor`. Healing reduction then applies to that heal.
- **Against non-heroes (creeps and objectives):**
  - Bullet lifesteal works at 60%.
  - Spirit lifesteal works at 40% on the wiki. Item data shows a separate non-hero value: 3% against non-heroes for 13% against heroes, which is about 23%.
  - Melee lifesteal works at 40%.
- Whether lifesteal uses pre- or post-mitigation damage is not documented (see Open questions).
- **Item examples:**
  - Bullet Lifesteal (T2): 13% bullet lifesteal, +6% weapon damage, +90 HP.
  - Spirit Lifesteal (T2): 13% spirit lifesteal against heroes.
  - Melee Lifesteal (T1): heals 100 on a melee hit, 8 s cooldown, +12% melee damage. It also multiplies the light melee cooldown by 1.5, so light melee has a cooldown.

### 10. Crowd control / debuffs

Model each debuff as a status with `type`, `source_id`, `duration`, `magnitude` and `flags`:

| Status | Blocks | Allows |
|---|---|---|
| Stun | movement, gun, melee, abilities, items | nothing |
| Silence | ability casts | gun, melee, active items (Curse also blocks items) |
| Curse | abilities and active items; interrupts channels | movement, gun |
| Disarm | gun fire | abilities, melee |
| Immobilize / root | movement | abilities, gun |
| Movement Silence | movement abilities, stamina (dash) and applies a slow | gun, abilities |
| Sleep | all actions; can crawl very slowly | wakes when damaged |
| Displace (knockup/back/pull) | overrides velocity | — |
| Movement slow | reduces speed (including sprint) | — |
| Fire-rate slow | lengthens cycle time | — |
| Bleed / Burn | damage over time (bleed = % of health; burn = spirit) | — |
| Healing reduction, damage output reduction, time stop, hero-specific marks | — | — |

**Rules:**

- **Debuff Resist** multiplies debuff *duration*: `duration × (1 − debuff_resist)`. 30% resist turns a 10 s debuff into 7 s. It does not change magnitude.
  - Stacking between multiple sources is **disputed**: the wiki suggests additive, a community site says multiplicative. Choose multiplicative `1 − Π(1 − Dᵢ)` as the safer option and flag it.
  - Mina has −8% innate debuff resist.
  - **Not reduced by debuff resist:** the parry stun, the Knockdown stun, and Warden's Binding Word escape time.
- **Diminishing returns on consecutive CC** (2026-04-10 values):
  - Within a **9 s window**, the 2nd CC is reduced by **15%** and the 3rd and later by **35%** (earlier values: 7/21%, 8/24%, 10/30%, window 8 s).
  - Players report it applies to stuns (and presumably other hard CC). **Silence, slow, hex and disarm** are *not* reduced.
  - It only applies if the previous CC had ended (a gap), and some abilities (Abrams's Charge) ignore it. This is reported bug-like behavior, so reproduce the intent: reduce on each new application within the window.
- **Re-applying a stun during a stun** restarts the full stun (it is replaced, not added).
- **Unstoppable** gives immunity to stun, silence, sleep and immobilize, but damage is still taken.
- **Movement slow:**
  - Stacking: `total = 1 − Π(1 − sᵢ)`.
  - Floor: `speed = (base − 2) × (1 − total × (1 − Σ slow_resist)) + 2` m/s. Slow resist is additive. Speed never drops below 2 m/s (80 u/s).
  - Since 2026-09-16, slows also increase air drag by 35% of the slow value. The same patch reduced all movement slow values by about 20% and ground-dash slows by about 10% globally.
- **Fire-rate slow:** see §12.
- **Getting-shot slow:** 10% for 0.7 s (§7).

### 11. Melee

**Light melee** (tap the melee key):
- Instant with no windup. About 50 damage (per-hero values in the table).
- Range about 5 m in a ±30° cone (datamine melee attack length and half-angle; **inferred** to be the light-melee hit test).
- Its own cooldown or interval is not published (see Open questions).

**Heavy melee** (hold the melee key), a 3-phase state machine:

```
WINDUP 0.36 s (parry-able tell; can turn up to ~300° total)
 -> LUNGE up to 0.6 s, forward speed peaks ~750 u/s ground (~19 m/s) / ~797 u/s air; hit test = sphere r=192 u
    plus cone 200 u long, 100 u end radius; ±5° vertical steer in air
 -> RECOVERY 0.2833 s (stop)
 total ≈ 1.25 s; stamina cost 0
 cooldown after: 1.0 s on hit, 1.3 s on miss
```

- Lunge distance is about half a dash. Items raise the lunge speed: Melee Charge 1125/1195 u/s, Crushing Fists 1200/1275 u/s.
- **Damage:** standard heroes deal 50 (+1.58 per boon) light and 116 (+3.67 per boon) heavy. At 35 boons that is 105.3 and 244.5.
  - Exceptions: Abrams 50/116 (+1.74/+4.03); Paige 42/120 (+1.20/+3.43, heavy also ×0.45 spirit power); Pocket 60/116 (+1.58/+3.05); Venator 50/125 (+1.70/+4.25); Yamato 55/128; Drifter 51.5/120; Apollo, Bebop, Calico and Viscous 63/116 (+2.91 heavy); Rem 58.
- Melee gets **50%** of Weapon Damage % bonuses.
- A trooper killed by a melee hit gives 100% of its bounty to the killer (no orb split).
- Hitting a climbing enemy slows them by 80%, decaying to 20% over 2 s.
- **Rejuvenator** revive tokens can only be claimed by heavy melee (1 per punch).

### 12. Fire rate modifiers

```
bonus = Σ fire_rate_bonus               # additive
slow  = 1 - Π(1 - fire_rate_slowᵢ)      # multiplicative
M     = max(bonus - slow, -0.5)         # floored at -50%
if M >= 0: rate = base_rate × (1 + M)
else:      rate = base_rate / (1 + |M|)  # -50% => 66.7% of base
```

- Worked example: +18% and +20% bonuses with −25% and −28% slows give −8%.
- Since 2026-01-30, most ability and item fire-rate effects have been reduced by a small amount globally.

### 13. Parry

**State machine:**

```
READY -(parry input)-> PARRYING (animation 1.0 s; active window first 0.75 s; move speed 50% during)
  on incoming enemy melee during active window:
     block all that melee damage; attacker gets STUN 2.75 s (not reducible by debuff resist)
     + "vulnerable": attacker takes +25% damage from ALL sources for the stun
     parrier: 0.3 s action lockout, then free; no cooldown consumed
  window expires without a parry:
     COOLDOWN 4.5 s  (Rebuttal item: −1.75 s -> 2.75 s)
```

- **Anti-mash:** extra parry inputs are ignored for 0.25 s after the first input (from 2026-04-10).
- A parry can be started during a ground dash (from 2026-04-10) and during an air dash.
- **What can be parried:** hero melee (light and heavy); trooper melee (blocks it and stuns the trooper); Lane Guardian melee (the guardian is stunned for 2 s); Viscous's Puddle Punch. **Cannot be parried:** Walkers, Base Guardian melee, most abilities.
- **Stun duration:** 2.75 s. The Parry wiki page (re-checked 2026-09-27) now also says 2.75 s, matching the Melee Attack page and the API data (`ParriedStunTime 2.75`). The earlier "2 s" conflict no longer exists.
- **Rebuttal item:** after a successful parry, gives +30% damage for 6 s and heals 100% of the blocked damage.

### 14. Boons and level growth

- A **boon** is gained at each soul threshold, up to a maximum of **35**. Each boon adds the hero's per-boon increments:
  - `BaseBulletDamage += per_boon` (0.043 for Calico up to 1.25 for The Doorman)
  - `Melee += 1.58 / 3.67` (standard light / heavy)
  - `BaseHP += 27..65`
  - `SpiritPower += 1.1` (standard; Haze 0.5, Grey Talon 1.6, Kelvin, Sinclair and Viscous 1.3, Ivy 1.2)
- A few heroes' bullet damage also scales with spirit power: Grey Talon ×0.08, Vindicta ×0.022.
- **Soul thresholds for boons** (wiki), 1..35: 800, 1100, 1500, 2000, 2600, 3200, 3800, 4500, 5200, 5900, 6600, 7400, 8200, 9000, 9800, 10700, 11600, 12500, 13400, 14400, 15500, 16700, 18000, 19500, 21200, 23100, 25200, 27500, 30000, 32700, 35600, 38700, 42000, 45500, 49200.
  - Heroes start with 600 souls (raised from 400 on 2025-11-21).
- Ability unlocks and ability points ride on the **same level track** as boons. The API's `level_info` thresholds (0, 200, 500, 900, 1400, 2000, ... 48600) are exactly the wiki boon thresholds minus the 600 starting souls, so each level-up grants one boon plus either an ability unlock or an ability point (**inferred**, medium confidence; corrected 2026-09-27 from "separate level track"). Details belong to the progression spec.
- **Weapon investment bonus** (a % Weapon Damage source in the additive pool). Thresholds are total souls spent on weapon-category items (wiki Items page):

  | Souls spent on weapon items | Weapon Damage bonus |
  |---|---|
  | 800 | +9% |
  | 1600 | +12% |
  | 2400 | +15% |
  | 3200 | +18% |
  | 4800 | +46% (the "4.8k spike") |
  | 6400 | +54% |
  | 8000 | +62% |
  | 11200 | +74% |
  | 16000 | +86% |
  | 22400 | +100% |
  | 28800 | +115% |

  Vitality investment runs from +9% to +66% base HP, and spirit investment from +7 to +100 spirit power. The API also has a different per-item-tier `purchase_bonuses` table (weapon +4/8/13/18/23% per tier). It may be a newer or experimental system; see Open questions.

### 15. Death and respawn

- **Respawn time** is a piecewise-linear function of match time. The four wiki points are 5 min → 8 s, 20 min → 38 s, 30 min → 70 s, 40 min → 85 s. It is capped at 90 s.
  - Before 5 min it is assumed to be 8 s. Past 40 min it is assumed to keep rising toward the 90 s cap (unknown slope).
  - Implement it as a `Curve` resource.
- **Dying to an NPC** with no enemy-hero bounty or assist adds +10 s.
- **Comeback kill** (after 10 min): if the victim's net worth is at least 15% above the killer team's average, their respawn gets +6 s to +22 s. The extra time scales with the net worth gap (15% → 30%) and with match time (10 → 25 min).
- **Last Stand** (the first Patron stage dies): a dead defender with 30 s or more left loses 20 s; with 10–30 s left, the timer is set to 10 s; with 10 s or less, it is unchanged. This applies once.
- **Rejuvenator** tokens (3 per Mid-Boss crystal) make a death respawn instantly and grant no souls to the killer. The data also has `player_respawn_mult` values of [0.5, 0.4, 0.3] per rejuvenator stage. They probably shorten the enemy's or the team's respawn; meaning unclear.
- **On death:** unsecured souls drop in an orb that others can pick up. There is no regen while dead. Dead players can use the shop.
- **Patch history:** 2026-01-20 added the comeback penalty. 2026-06-30 changed the ramp to 8–35 s over 5–20 min. 2026-09-16 changed the 20-minute value from 35 s to 38 s.

### 16. Weapon Damage % and spirit power

- **Weapon Damage %** bonuses (items, investment) add together, then multiply base bullet damage. **Flat** weapon damage is added after the multiplier.
- **Damage amplification debuffs** on the target (for example "increased bullet damage taken") multiply the final total, including flat damage.
- **Spirit damage** = `base + coef × SpiritPower`. Tooltip coefficients are rounded to 0.1. Percentage spirit power bonuses multiply each other.
- **Spirit investment** gives flat spirit power.

---

## Values

### Global values

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Unit conversion | 39.37 | units per m | inferred (787 u = 20 m; 30000 u/s = 762 m/s) | 2026-09 | high | [1][2] |
| Headshot (weakpoint) multiplier | 1.65 | × | wiki / community-datamine | since 2025-11-21 | high | [3][2] |
| Headshot multiplier before 2025-11-21 | 1.8 | × | official | 2025-11-21 | high | [20] |
| Crit bonus at 500 u / 1500 u | 1.65 / 1.65 | × | community-datamine | 2026-09 | high | [2] |
| Crit bonus scale Billy/Celeste/Doorman/Drifter/Kelvin/Rem/Vyper | −20/−25/−30/−45/−25/−20/−30 | % | wiki | 2026-09 | high | [3][14] |
| Crit damage received scale Seven/Mo&Krill/Rem | 0.45/0.8/0.9 | × | community-datamine | 2026-09 | high | [2][14] |
| Default falloff start | 20 (787 u) | m | community-datamine | 2026-09 | high | [2][6] |
| Default falloff end | 57.5 (2264 u) | m | community-datamine | 2026-09 | high | [2][6] |
| Default falloff min damage | 10 | % of base | wiki / datamine | 2026-09 | high | [6][2] |
| Sinclair falloff min | 30 | % | datamine / wiki | 2026-09 | high | [2][6] |
| Drifter falloff min | 60 | % | datamine / wiki | 2026-09 | high | [2][6] |
| Graves falloff min | 50 | % | community-datamine | 2026-09 | medium | [2] |
| Explosive bullet damage at blast edge | 50 | % | wiki | 2026 | medium | [6] |
| Long Range: bonus falloff range / weapon dmg beyond 15 m | +8 / +40 | % | community-datamine | 2026-09 | high | [2][6] |
| Sharpshooter falloff range | +20 | % | wiki | 2026 | medium | [6] |
| Close Quarters: weapon dmg within 15 m / melee resist | +20 / +20 | % | community-datamine | 2026-09 | high | [2] |
| Bullet lifetime (typical) | 2.0 | s | community-datamine | 2026-09 | high | [2] |
| Max bullet range (typical) | 7000 (≈178 m) | u | community-datamine | 2026-09 | high | [2] |
| Move speed while shooting | 75 (Rem 85) | % | datamine / wiki | 2026-09 | high | [2][27] |
| Bullet velocity range across roster | 43.4 – 1587.5 | m/s | wiki / datamine | 2026-09 | high | [5][2] |
| High-Velocity Rounds etc. bullet velocity | +60 | % | wiki | 2026 | medium | [5] |
| Global gun base damage changes | +10% then −5% | % | official | 2025-11-21/22 | high | [20] |
| Resist stacking | 1−Π(1−R) | formula | wiki | 2026-09 | high | [4][8] |
| Resist reduction | subtract after multiplicative stack | formula | wiki | 2026-09 | high | [4] |
| Shred applies after the triggering hit | yes ("various on bullet hit" resist-reduction debuffs) | — | official | 2026-01-30 | high | [24] |
| Resist hard cap | none documented | — | wiki | 2026-09 | low | [4] |
| Bullet Armor bullet resist | 18 | % | community-datamine | 2026-09 | high | [2] |
| Spirit Armor spirit resist | 15 | % | community-datamine | 2026-09 | high | [2] |
| Bebop bullet resist per boon | 0.3 | %/boon | wiki | 2026-09 | medium | [14] |
| Dynamo bullet resist per boon | 0.625 | %/boon | wiki | 2026-09 | medium | [14] |
| Kelvin / McGinnis spirit resist per boon | 0.625 / 0.35 | %/boon | wiki | 2026-09 | medium | [14] |
| Lash / Pocket innate spirit resist | +10 / −15 | % | wiki | 2026-09 | medium | [14] |
| Rem innate melee resist | −5 | % | wiki | 2026-09 | medium | [14] |
| Venator bullet and spirit resist per spirit power | 0.122 | %/SP | wiki | 2026-09 | medium | [8][14] |
| Weapon Damage share for melee | 50 | % | wiki | 2026-09 | high | [9][10] |
| Weapon investment bonus curve | 9,12,15,18,46,54,62,74,86,100,115 at 0.8k..28.8k souls | % | wiki / datamine | 2026-09 | medium | [26][2] |
| Vitality investment bonus range | 9 → 66 | % base HP | wiki | 2026-09 | medium | [26] |
| Spirit investment bonus range | 7 → 100 | spirit power | wiki | 2026-09 | medium | [26] |
| Barrier stacking | additive, temporary | — | wiki | since 2025-05-08 | high | [12] |
| Bullet and spirit shields merged into Barrier | — | — | wiki / official | 2025-05-08 | high | [12] |
| Weapon/Spirit Shielding barrier | 300 | HP | community-datamine | 2026-09 | high | [2] |
| Weapon Shielding trigger | 250 dmg in 4 s | HP / s | community-datamine | 2026-09 | high | [2] |
| Spirit Shielding trigger | 225 dmg in 3.5 s | HP / s | community-datamine | 2026-09 | high | [2] |
| Shielding cooldowns (weapon/spirit) | 35 / 45 (re-checked; 11-21-2025 notes said 45 for both) | s | community-datamine | 2026-09 | high | [2][20] |
| Shielding barrier duration | 8 (patch 2025-11 said 7) | s | community-datamine | 2026-09 | high | [2][20] |
| Base health regen range | 1 – 3.5 | HP/s | wiki / datamine | 2026-09 | high | [13][2] |
| OOC regen delay vs heroes | 4 | s | wiki | 2026-09 | high | [13] |
| OOC regen delay vs NPC damage (wiki) | 0.5 | s | wiki | 2026-09 | low (conflicts with patches) | [13] |
| OOC / sprint timer vs neutrals (patch) | 0.5 → 2.5 → 4 | s | official | 2025-11-21 / 2025-12-03 | medium | [20] |
| Sprint out-of-combat timer | 5 | s | wiki | 2026 | medium | [27] |
| Base regen zone | +60 HP/s and +6% max HP/s | HP/s | wiki | 2026-09 | high | [13] |
| Getting-shot movement slow | 10% for 0.7 s | % / s | official | 2025-12-03 | medium | [20] |
| Extra Regen item (T1) | +2.5 regen, +1.5 OOC regen | HP/s | community-datamine | 2026-09 | high | [2] |
| Healing reduction stacking | 1−Π(1−R); same source doesn't stack | formula | wiki | 2026-09 | high | [15] |
| Healbane: heal received / regen penalty | −35 / −35 for 8 s | % / s | community-datamine | 2026-09 | high | [2] |
| Healing reduction ranges (abilities / items) | 30–100 / 35–70 | % | wiki | 2026-09 | medium | [15] |
| Inhibitor / Decay / Crippling Headshot heal reduction | 40 / 50 / 35 (Decay corrected 45 -> 50) | % | community-datamine (official 12-03-2025 gave 40/45/35) | 2026-09 | high | [2][20] |
| Lifesteal stacking | 1−Π(1−L) | formula | wiki | 2026-09-10 | high | [16] |
| Bullet lifesteal vs non-heroes | 60 | % effectiveness | wiki | 2026-09-10 | medium | [16] |
| Spirit lifesteal vs non-heroes | 40 (item data suggests ~23) | % effectiveness | wiki / datamine | 2026-09 | low | [16][2] |
| Melee lifesteal vs non-heroes | 40 on the wiki; Melee Lifesteal item NonHeroHealPct = 30 | % | wiki / community-datamine | 2026-09 | medium | [16][2] |
| Bullet Lifesteal item | 13 | % | community-datamine | 2026-09 | high | [2] |
| Spirit Lifesteal item (heroes) | 13 | % | community-datamine | 2026-09 | high | [2] |
| Melee Lifesteal item heal / cooldown / light-melee cooldown mult | 100 / 8 / 1.5× | HP / s / × | community-datamine | 2026-09 | high | [2] |
| Debuff resist effect | duration × (1 − DR) | formula | wiki | 2026-09 | high | [18] |
| Debuff Reducer | 25 | % | datamine / official | 2026-01-30 | high | [2][24] |
| Mina innate debuff resist | −8 | % | wiki | 2026-09 | high | [18] |
| Subsequent CC reduction (2nd / 3rd+) | 15 / 35 | % | official (via patch mirror) | 2026-04-10 | medium | [21][22] |
| Subsequent CC reduction window | 9 | s | official (via patch mirror) | 2026-04-10 | medium | [21] |
| Movement slow stacking | 1−Π(1−s) | formula | wiki | 2026 | high | [17] |
| Movement speed floor under slows | 2.0 (80 u/s) | m/s | wiki | 2026 | high | [17] |
| Slow resist stacking | additive | — | wiki | 2026 | medium | [17] |
| Slows increase air drag | 35% of slow value | % | wiki (patch page) | 2026-09-16 | medium | [38] |
| Fire-rate modifier floor | −50 | % | wiki | 2026 | high | [19] |
| Fire-rate slow formula | rate / (1 + abs(M)) | formula | wiki | 2026 | high | [19] |
| Slowing Bullets | 24% slow for 3.5 s (build-up 0.7 per shot) | % / s | community-datamine | 2026-09 | high | [2] |
| Standard light / heavy melee | 50 / 116 | damage | wiki / datamine | 2026-09 | high | [10][2] |
| Standard melee per boon (light / heavy) | 1.58 / 3.67 | damage/boon | wiki | 2026-09 | high | [10] |
| Heavy melee windup | 0.36 | s | wiki | 2026-09 | high | [23] |
| Heavy melee lunge max | 0.6 | s | wiki | 2026-09 | high | [23] |
| Heavy melee recovery | 0.2833 | s | wiki | 2026-09 | high | [23] |
| Heavy melee total | 1.25 | s | wiki | 2026-09 | high | [23] |
| Heavy melee lunge peak speed ground / air | 750 / 797 | u/s | wiki | 2026-09 | high | [23] |
| Heavy melee hit sphere radius | 192 | u | wiki | 2026-09 | medium | [23] |
| Heavy melee hit cone | 200 u long, 100 u end radius | u | wiki | 2026-09 | medium | [23] |
| Heavy melee cooldown hit / miss | 1.0 / 1.3 | s | wiki | 2026-09-17 | high | [9][23] |
| Melee attack length / half angle | 5 / 30 | m / deg | community-datamine | 2026-09 | medium | [2] |
| Climbing target melee slow | 80% decaying to 20% over 2 s | % / s | wiki | 2026-09-17 | medium | [9] |
| Parry animation / active window | 1.0 / 0.75 | s | wiki | 2026-09 | high | [7][9] |
| Parry stun | 2.75 | s | community-datamine / wiki | 2026-09 | high | [2][7][9] |
| Parry vulnerability on attacker | +25 | % damage taken, all sources | datamine / wiki | 2026-09 | high | [2][7] |
| Parry missed cooldown | 4.5 | s | datamine / wiki | 2026-09 | high | [2][7] |
| Parry post-success lockout | 0.3 | s | wiki | 2026-09 | high | [7] |
| Parry anti-mash lockout | 0.25 | s | official (mirror) | 2026-04-10 | medium | [21] |
| Parry move speed | 50 | % (inferred unit) | community-datamine | 2026-09 | low | [2] |
| Rebuttal: parry cooldown reduction / bonus damage / duration | −1.75 s / +30% / 6 s | — | community-datamine | 2026-09 | high | [2] |
| Guardian stun when parried | 2 (then no melee for 5 s) | s | wiki | 2026-09 | medium | [28] |
| Max boons | 35 | boons | wiki | 2026-09 | high | [29] |
| Starting souls | 600 | souls | official / wiki | 2025-11-21 | high | [20][29] |
| Boon soul thresholds | 800 … 49200 (see §14) | souls | wiki | 2026-09 | medium | [29] |
| Standard spirit power per boon | 1.1 | SP/boon | wiki | 2026-09 | medium | [14] |
| Respawn at 5 / 20 / 30 / 40 min | 8 / 38 / 70 / 85 | s | wiki | 2026-09-16 | high | [30] |
| Respawn cap | 90 | s | wiki | 2026-09 | high | [30] |
| Death-to-NPC respawn penalty | +10 | s | wiki | 2026-09 | high | [30] |
| Comeback kill penalty | +6 → +22 (15→30% NW gap, 10→25 min) | s | wiki | since 2026-01-20 | medium | [30] |
| Last Stand respawn reduction | −20 s if ≥30 s; set to 10 s if 10–30 s | s | wiki | 2026 | high | [30] |
| Rejuvenator respawn mult table | 0.5 / 0.4 / 0.3 | × | community-datamine | 2026-09 | low | [31] |
| Active Reload QTE window / skip | 0.3 s / 50% | s / % | wiki | 2026 | medium | [32] |
| Reload times range | 1.6 (Vyper) – 3.29 (McGinnis) | s | wiki / datamine | 2026-09 | high | [32][2] |
| Pure damage blocked only by | invincibility | — | wiki | 2026 | high | [33] |

### Per-hero weapon and vitality table (community-datamine, deadlock-api.com `/v1/assets/heroes` + `/v1/assets/items`, fetched 2026-09-27, game state as of about the 2026-09-16 patch; confidence high for the snapshot)

- Velocity and falloff are converted to meters at 1 m = 39.37 u. Bullet radius is converted to cm at 1 u = 2.54 cm.
- For single-shell reloaders, "Reload" shows the initial delay plus the time per shell.
- "Min dmg scale" is the damage multiplier at or beyond the falloff end.
- Crit damage received scale is the defender-side headshot modifier.

| Hero | Bullet dmg | +dmg/boon | Pellets | Cycle time (s) | Burst | Clip | Reload (s) | Velocity (m/s) | Falloff (m) | Min dmg scale | Gravity scale | Bullet radius (cm) | Lifetime (s) | Base DPS | HP (+/boon) | Base regen (HP/s) | Crit dmg received scale |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Abrams | 3.6 | 0.1 | 9 | 0.63 | - | 9 | single 0.705s+0.352s/shell | 609.6 | 17.0-40.0 | 0.1 | 0.8 | 7.62 | 2 | 51.4 | 800 (+49) | 1.5 | 1 |
| Apollo | 18.5 | 0.825 | 1 | 0.38 | - | 15 | 2.5 | 127.0 | 25.4-25.4 | 1 | 0 | 25.40 | 1 | 48.7 | 770 (+45) | 1 | 1 |
| Bebop | 4.98 | 0.115 | 1 | 0.084 | - | 66 | 2.35 | 508.0 | 20.0-50.8 | 0.1 | 0.8 | 7.62 | 2 | 59.3 | 880 (+52) | 2.5 | 1 |
| Billy | 6.3 | 0.127 | 1 | 0.085 | - | 30 | 2.9 | 513.1 | 14.0-31.8 | 0.1 | 0 | 10.16 | 2 | 74.1 | 820 (+53) | 2 | 1 |
| Calico | 1.84 | 0.043 | 9 | 0.21 | - | 12 | 2.6 | 317.5 | 20.0-57.5 | 0.1 | 0 | 7.62 | 2 | 78.9 | 730 (+37) | 2 | 1 |
| Celeste | 18 | 0.82 | 1 | 0.58 | - | 8 | 2 | 50.0 | 22.0-60.0 | 0.1 | 0.2 | 45.72 | 5 | 31 | 690 (+33) | 1 | 1 |
| Drifter | 19.5 | 0.49 | 3 | 0.441 | - | 12 | 2.44 | 508.0 | 22.0-27.0 | 0.6 | 0 | 15.24 | 0.054 | 132.7 | 755 (+41) | 3.5 | 1 |
| Dynamo | 12.6 | 0.5 | 1 | 0.2625 | - | 20 | 2.35 | 320.0 | 20.0-57.5 | 0.1 | 0.8 | 15.24 | 2 | 48 | 880 (+61) | 1.75 | 1 |
| Graves | 3.6 | 0.054 | 1 | 0.102 | - | 40 | 2.8 | 635.0 | 7.6-17.0 | 0.5 | 0 | 7.62 | 2 | 35.3 | 730 (+35) | 1 | 1 |
| Grey Talon | 23.51 | 0.85 | 1 | 0.6 | - | 17 | 2.35 | 495.3 | 18.0-54.0 | 0.1 | 0.8 | 12.70 | 2 | 39.2 | 780 (+38) | 1.5 | 1 |
| Haze | 5.26 | 0.143 | 1 | 0.105 | - | 25 | 2.35 | 762.0 | 20.0-46.0 | 0.1 | 1.5 | 7.62 | 3 | 50.1 | 730 (+33) | 2 | 1 |
| Holliday | 19.7 | 1.144 | 1 | 0.4725 | - | 10 | 2.75 | 1155.7 | 20.0-57.5 | 0.1 | 0 | 12.70 | 2 | 41.7 | 780 (+43) | 2 | 1 |
| Infernus | 5.5 | 0.088 | 1 | 0.105 | - | 27 | 2.25 | 660.4 | 18.0-55.0 | 0.1 | 0.8 | 10.16 | 2 | 52.4 | 830 (+39) | 2 | 1 |
| Ivy | 4.45 | 0.08 | 1 | 0.0735 | - | 33 | 2.44 | 571.5 | 20.0-57.5 | 0.1 | 0.8 | 7.62 | 2 | 60.5 | 755 (+45) | 2 | 1 |
| Kelvin | 18.6 | 0.418 | 1 | 0.2625 | - | 14 | 2.58 | 160.0 | 20.0-57.5 | 0.1 | 0.3 | 15.24 | 2 | 70.9 | 880 (+60) | 1 | 1 |
| Lady Geist | 20.7 | 1 | 1 | 0.4725 | - | 9 | 2.58 | 828.0 | 17.0-48.0 | 0.1 | 0.8 | 10.16 | 2 | 43.8 | 880 (+51) | 1 | 1 |
| Lash | 8.46 | 0.31 | 1 | 0.2625 | 3x @0.084s | 29 | 2.35 | 635.0 | 16.0-48.0 | 0.1 | 0.8 | 7.62 | 2 | 49.3 | 780 (+50) | 2 | 1 |
| McGinnis | 6.08 | 0.171 | 1 | 0.21 spin->0.084 | - | 66 | 3.29 | 650.0 | 20.0-57.5 | 0.1 | 0.8 | 10.16 | 2 | 29 | 780 (+52) | 2 | 1 |
| Mina | 7.31 | 0.275 | 1 | 0.252 | - | 12 | 1.7 | 762.0 | 20.0-46.0 | 0.1 | 0 | 12.70 | 2 | 29 | 660 (+27) | 2 | 1 |
| Mirage | 14.8 | 0.3 | 1 | 0.3675 | - | 16 | 2.6 | 828.0 | 20.0-57.5 | 0.1 | 0.8 | 12.70 | 2 | 40.3 | 730 (+45) | 1.5 | 1 |
| Mo & Krill | 2.82 | 0.0847 | 4 | 0.189 | - | 20 | 2.82 | 320.0 | 20.0-57.5 | 0.1 | 0.8 | 7.62 | 2 | 59.7 | 930 (+65) | 1 | 0.8 |
| Paige | 35 | 0.52 | 1 | 0.5 | - | 14 | 2.5 | 43.4 | 20.0-57.5 | 0.1 | 0 | 63.50 | 1.5 | 58.3 | 680 (+31) | 2 | 1 |
| Paradox | 6.8 | 0.26 | 1 | 0.294 | 5x @0.0735s | 40 | 2.58 | 525.0 | 20.0-57.5 | 0.1 | 0.1 | 10.16 | 2 | 51.4 | 730 (+46) | 1 | 1 |
| Pocket | 4.28 | 0.14 | 7 | 0.525 | - | 11 | 2.82 | 558.8 | 16.0-45.7 | 0.1 | 0.8 | 7.62 | 2 | 57.1 | 780 (+36) | 1 | 1 |
| Rem | 16 | 0.34 | 1 | 0.26 | - | 13 | 2 | 160.0 | 20.0-57.5 | 0.1 | 0.8 | 25.40 | 2 | 61.5 | 680 (+28) | 2 | 0.9 |
| Seven | 10.8 | 0.24 | 1 | 0.2625 | 3x @0.084s | 29 | 2.35 | 635.0 | 20.0-57.5 | 0.1 | 0.8 | 7.62 | 2 | 63 | 730 (+41) | 1 | 0.45 |
| Shiv | 4.8 | 0.165 | 6 | 0.55125 | - | 10 | 2.8 | 609.6 | 19.8-41.1 | 0.1 | 0.8 | 7.62 | 2 | 52.2 | 830 (+46) | 2 | 1 |
| Silver | 5.1 | 0.117 | 7 | 0.85 | - | 7 | single 0.5s+0.3s/shell | 812.8 | 17.0-42.0 | 0.1 | 0 | 10.16 | 2 | 42 | 830 (+31) | 2.5 | 1 |
| Sinclair | 17.76 | 0.55 | 1 | 0.525 | 2x @0.105s | 16 | 2.5 | 300.0 | 25.4-61.0 | 0.3 | 0 | 12.70 | 2 | 48.3 | 730 (+38) | 2 | 1 |
| The Doorman | 24 | 1.25 | 1 | 0.63 | - | 8 | 2.4 | 203.2 | 20.0-57.5 | 0.1 | 0 | 25.40 | 2 | 35.3 | 755 (+42) | 1 | 1 |
| Venator | 8 | 0.27 | 1 | 0.126 | - | 33 | 2.8 | 1587.5 | 18.0-47.0 | 0.1 | 0 | 7.62 | 2 | 63.5 | 820 (+43) | 2 | 1 |
| Victor | 12 | 0.26 | 1 | 0.198 spin->0.171 | - | 24 | 2.4 | 203.2 | 20.0-57.5 | 0.1 | 0 | 12.70 | 2 | 60.6 | 800 (+34) | 1.5 | 1 |
| Vindicta | 12.33 | 0.495 | 1 | 0.231 | - | 19 | 2.91 | 660.0 | 20.0-64.0 | 0.1 | 0.8 | 7.62 | 2 | 53.4 | 755 (+28) | 2 | 1 |
| Viscous | 10.34 | 0.36 | 1 | 0.21 | - | 20 | 2.5 | 254.0 | 20.0-57.5 | 0.1 | 0 | 20.32 | 2 | 49.2 | 780 (+45) | 2 | 1 |
| Vyper | 6.58 | 0.178 | 1 | 0.07 | - | 24 | 1.6 | 411.5 | 15.0-33.0 | 0.1 | 0 | 12.70 | 0.5 | 94 | 780 (+35) | 2 | 1 |
| Warden | 17.34 | 0.25 | 1 | 0.2625 | - | 17 | 2.91 | 290.0 | 18.0-47.0 | 0.1 | 0.25 | 12.70 | 2 | 66.1 | 805 (+60) | 2 | 1 |
| Wraith | 5.64 | 0.14 | 1 | 0.0945 | - | 52 | 2.82 | 571.5 | 18.0-52.0 | 0.1 | 0 | 7.62 | 2 | 59.7 | 730 (+35) | 2 | 1 |
| Yamato | 5.31 | 0.154 | 5 | 0.42 | - | 12 | 2.44 | 254.0 | 20.0-45.7 | 0.1 | 0 | 7.62 | 2 | 63.2 | 730 (+45) | 1 | 1 |

Crit bonus scale (attacker) and innate resists are in the global table above. Light and heavy melee per hero are in §11.

---

## Open questions / needs in-game measurement

All measurements go in a **private custom lobby** with `sv_cheats true`, using only built-in commands (source 34): `citadel_create_unit <hero>` (spawn a dummy), `citadel_spawn_practice_bots`, `healthpct`, `citadel_enable_no_hero_death`, `kingme`, `citadel_hero_testing_infinite_money`, `hud_damagemeter true`, `selecthero`, `citadel_enable_fast_cooldowns`. Read values from floating damage numbers, the HUD health bar and tooltips, and record video at 60+ fps so timings can be counted frame by frame.

1. **Is falloff linear?** The data has `damage_falloff_bias = 0.5`. *Method:* spawn a dummy and shoot it with a single-bullet hero (Haze) at 20, 26.5, 33, 39.5 and 46 m, measuring distance with the Long Range tooltip / map scale or by counting 1 m floor tiles. Plot damage against distance. If the midpoint (33 m) reads 55% of base, falloff is linear.
2. **Crit bonus scale and crit reduction formula.** *Method:* as Drifter (−45%), headshot and bodyshot a dummy Haze at point-blank range and compare the ratio (1.3575 if additive-on-bonus). Then headshot a dummy Seven (0.45 received scale) with Haze and check whether the ratio is 1.2925.
3. **Which NPCs have a weakpoint:** Walkers, Shrines, Patron, Mid-Boss, Super Troopers. *Method:* shoot each target's head-like area and watch for yellow crit numbers or the crit hit sound.
4. **Melee resist interaction:** does melee damage go through Bullet Resist and Melee Resist multiplicatively? *Method:* buy Bullet Armor (18%) on a dummy, then Rebuttal (18% melee resist). Light-melee it and compare 50 → 41 → 33.6 (multiplicative) against 32.0 (additive).
5. **Light melee cooldown and attack interval.** *Method:* spam light melee on a dummy and count hits per 10 s. Also measure the light melee range with a measured distance.
6. **Lifesteal: pre- or post-mitigation damage.** *Method:* give the target 50% bullet resist, give the attacker Bullet Lifesteal, and compare the heal numbers against the damage numbers.
7. **Non-hero lifesteal factor for spirit** (wiki 40% vs item data about 23%). *Method:* use Spirit Lifesteal on troopers and measure heal per damage.
8. **OOC regen timer against troopers and neutrals** (wiki 0.5 s vs patch 4 s). *Method:* take a single hit from a neutral, then time how long until OOC regen ticks, using an OOC regen item such as Extra Regen and watching the HP bar's regen rate change.
9. **Getting-shot slow** (10% for 0.7 s): does it still exist, and does it stack? *Method:* have a bot shoot you while you walk a known distance; compare to walking unhit.
10. **Debuff resist stacking** (additive vs multiplicative). *Method:* hold Debuff Reducer (25%) plus another DR source. Get stunned by a known-duration stun and time it (10 s stun: 5.0 s if additive 50%, 5.625 s if multiplicative).
11. **Diminishing-returns details:** which CC types count, whether it stacks per source, and whether the window restarts. *Method:* chain the same stun on a bot at 1 s, 4 s and 10 s gaps and time each stun.
12. **Spin-up rate units** for McGinnis and Victor. *Method:* hold fire and log shot timestamps from audio; fit the cycle time against time held.
13. **Respawn curve before 5 min and after 40 min.** *Method:* die at 2 min and at 45–50 min in a bot match (use `healthpct 1`) and record the timer.
14. **Barrier decay rate:** linear or step, and over what time? *Method:* activate Weapon Shielding and watch the barrier bar every second.
15. **Headshot vs falloff order with flat headshot items.** Does Headshot Booster's +45 get falloff and crit? *Method:* test at 50 m versus 5 m.
16. **Investment bonus system.** Is the current system `cost_bonuses` (soul thresholds) or `purchase_bonuses` (per item tier)? *Method:* buy one T1 weapon item and read the weapon damage stat panel. It reads +9% under the threshold system and +4% under the tier system.
17. **Stun during parry vulnerability:** does the +25% last the whole 2.75 s, or longer? *Method:* parry a bot, then shoot it and track damage numbers over time.
18. **Heavy melee headshots:** can heavy melee crit on the head? *Method:* heavy-melee a dummy's head and check the number color.

---

## Implementation notes for Godot 4

- **Data-driven resources:**
  - `WeaponData` (Resource): every field of the §2 table, stored in engine units (u, u/s) with a global `UNITS_PER_METER = 39.37`.
  - `HeroStats` (Resource): base HP, HP per boon, base regen, melee values, per-boon increments, crit bonus scale, crit received scale, innate resists.
  - `StatusEffectDef` (Resource): type, flags, `dr_category`, `affected_by_debuff_resist`.
  - Import the per-hero table as a CSV or JSON (regenerate it from deadlock-api.com after each patch; see "Data tooling" below).
- **Stat system:** use an `AttributeSet` node on each unit that holds modifier lists by channel: `additive_pct`, `mult_stack` (1−Π(1−x)), `flat`. Resist, lifesteal, slow and healing reduction use `mult_stack`. Weapon damage % and fire-rate bonus use `additive_pct`. Recompute values on change, not every frame.
- **DamageInfo** (a RefCounted class): `amount`, `type` (BULLET, MELEE, SPIRIT, PURE), `is_crit`, `distance`, `source_unit`, `ability_id`, `proc_flags`, `is_instance_amp`. Put all of §1 in one `DamageSystem.apply()` autoload so the math stays in one place.
- **Projectiles:** avoid one `RigidBody3D` per bullet. Use a pooled manager that steps positions each physics tick with `PhysicsDirectSpaceState3D.cast_motion`/`intersect_shape`, using a `SphereShape3D` of `bullet_radius` against a hitbox layer, and a separate `bullet_radius_vs_world` against the world. Put head hitboxes on their own collision layer (`Area3D` with a `weakpoint` meta) so crit detection is just a layer check.
- **Falloff and crit:** use `Curve` resources or a lerp. Store `falloff_start`, `falloff_end` and `end_scale` per weapon.
- **Weapon FSM:** a `WeaponController` node with states IDLE, FIRING, BURSTING, RELOADING and RELOADING_SINGLE. Use a `Timer` or accumulated delta for `cycle_time` and support fractional fire-rate modifiers. Server-authoritative if networked.
- **Melee and parry:** an `AnimationTree` state machine for windup, lunge and recovery, with hit tests done using `ShapeCast3D` (sphere plus cone check). Parry is a state on the defender that is checked in `DamageSystem` before melee damage applies.
- **Status effects:** a `StatusController` node with a dictionary keyed by `(effect_type, source_id)`. Refresh rules, the DR window tracker (a list of recent CC timestamps kept 9 s) and debuff-resist scaling of durations all live there.
- **Combat state:** track `last_hero_combat_time` and `last_npc_damage_time` separately. OOC regen and sprint check different thresholds (4 s, NPC timer, 5 s).
- **Respawn:** `RespawnRules` Resource with a `Curve` (x = minutes, y = seconds) plus modifier functions.
- **Tunables:** keep every number in this spec in `.tres` files, not in code. Valve changes them nearly every two weeks.

### Data tooling (legal public API)

- **What it is:** deadlock-api.com runs a free public REST API with OpenAPI docs at `https://api.deadlock-api.com/docs`.
- **Static game data:** `GET /v1/assets/heroes`, `/v1/assets/items` (each hero's weapon is an item with `type: "weapon"` and a `weapon_info` block), `/v1/assets/npc-units`, `/v1/assets/generic-data`, `/v1/patches`.
- **Aggregated match analytics:** for balancing your own game against real play data, use `/v1/analytics/hero-stats`, `/v1/analytics/item-stats` and `/v1/analytics/kill-death-stats`. `/v1/sql` also exists.
- **How to use it:** a small script (Python or GDScript `HTTPRequest`) can pull these after each patch and write `WeaponData`/`HeroStats` `.tres`/JSON.
- **Clean-room rules:** these are the third party's published data, so tag them community-datamine. Do not use or ship Valve assets (images, sounds) that the API also links.
- **Note:** the older host `assets.deadlock-api.com` no longer resolves. Use `api.deadlock-api.com/v1/assets/...`.

---

## Sources

All accessed 2026-09-27.

1. https://api.deadlock-api.com/docs (Deadlock API OpenAPI docs)
2. https://api.deadlock-api.com/v1/assets/heroes and https://api.deadlock-api.com/v1/assets/items (community-datamine hero/weapon/item data)
3. https://deadlock.wiki/Headshot
4. https://deadlock.wiki/Bullet_Resist
5. https://deadlock.wiki/Bullet_Velocity
6. https://deadlock.wiki/Damage_Falloff
7. https://deadlock.wiki/Parry
8. https://deadlock.wiki/Spirit_Resist
9. https://deadlock.wiki/Melee (redirects to Melee Attack; last edited 2026-09-17), and https://deadlock.wiki/Melee_Attack
10. https://deadlock.wiki/Melee_Damage
11. https://deadlock.wiki/Damage_Amplification
12. https://deadlock.wiki/Barrier
13. https://deadlock.wiki/Health_Regen and https://deadlock.wiki/Health
14. https://deadlock.wiki/Hero_Comparison_Table
15. https://deadlock.wiki/Healing_Reduction
16. https://deadlock.wiki/Lifesteal
17. https://deadlock.wiki/Movement_Slow
18. https://deadlock.wiki/Debuff_Resist and https://deadlock.wiki/Debuffs
19. https://deadlock.wiki/Fire_Rate
20. https://forums.playdeadlock.com/threads/11-21-2025-update.90383/ (official patch notes, including the 11-22 and 12-03 follow-ups)
21. https://tracklock.gg/articles/deadlock-update-04-10-26-patch-notes (mirror of the official 04-10-2026 notes)
22. https://forums.playdeadlock.com/threads/chain-cc-reduction-issues.126476/ and https://forums.playdeadlock.com/threads/silences-not-affected-by-diminishing-crowd-control-cc-debuffs.127010/
23. https://deadlock.wiki/Heavy_Melee
24. https://forums.playdeadlock.com/threads/01-30-2026-update.102822/
25. https://deadlock.one/en/news/deadlock-patch-notes-09162026-minor-update (patch summary; air-drag line seen in search snippet only)
26. https://deadlock.wiki/Items
27. https://deadlock.wiki/Move_Speed
28. https://deadlock.wiki/Lane_Guardian and https://deadlock.wiki/Base_Guardian
29. https://deadlock.wiki/Boons
30. https://deadlock.wiki/Respawn (redirects to Death)
31. https://api.deadlock-api.com/v1/assets/generic-data and https://api.deadlock-api.com/v1/assets/npc-units
32. https://deadlock.wiki/Reload
33. https://deadlock.wiki/Pure_Damage
34. https://deadlock.wiki/Console_commands
35. https://deadlock.wiki/Spirit_Damage and https://deadlock.wiki/Weapon_Damage
36. https://forums.playdeadlock.com/threads/09-16-2026-update.162572/ and https://forums.playdeadlock.com/threads/06-30-2026-update.146261/
37. https://steamdb.com/en/deadlock/mechanics/status-effects (build client-6698, 2026-09-23)
38. https://deadlock.wiki/Update:September_16,_2026 (wiki copy of the official 09-16-2026 notes)

---

## Verification log (2026-09-27)

Adversarial re-check of the most implementation-critical numbers. Sources re-fetched on 2026-09-27: the deadlock-api.com public assets API (`/v1/assets/heroes`, `/v1/assets/items`, `/v1/assets/generic-data`; community-datamine), deadlock.wiki pages (read through the normal page view only; the raw-source endpoint is behind a bot check and was not bypassed), the official forum 11-21-2025 and 01-30-2026 notes, the wiki copy of the 09-16-2026 notes, and the tracklock.gg mirror of the 04-10-2026 notes. No game files were opened.

| # | Claim | Checked against | Outcome |
|---|---|---|---|
| 1 | Headshot multiplier 1.65× (1.8× before 2025-11-21) | API `crit_bonus_start/end` = 1.65 on all weapons; wiki Headshot; official 11-21-2025 notes | Confirmed |
| 2 | Attacker crit bonus scales (Billy −20 … Drifter −45 …) | wiki Headshot | Confirmed |
| 3 | Crit damage received scale Seven 0.45 / Mo & Krill 0.8 / Rem 0.9 | API `crit_damage_received_scale` | Confirmed |
| 4 | Default falloff 787–2264 u (20–57.5 m), end scale 0.1; Haze 20–46 m; Drifter 22–27 m @0.6; Abrams 17–40 m | API weapon data | Confirmed |
| 5 | Lash falloff 18–54 → 16–48 m on 2026-09-16 | wiki Update:September_16,_2026; API (629.9–1889.8 u) | Confirmed. A search-engine summary said 20–58 → 18–54; that is wrong |
| 6 | 1 m = 39.37 u; Haze 30000 u/s = 762 m/s; Mo & Krill 12600 u/s = 320 m/s | API | Confirmed |
| 7 | Haze DPS 50.1 burst / 26.43 sustained; Drifter 132.7 | Recomputed from API values | Confirmed |
| 8 | Parry: 0.75 s window, 1.0 s animation, 2.75 s stun, +25% damage taken, 4.5 s miss cooldown, 0.3 s lockout | wiki Parry (now says 2.75 s); API `ParriedStunTime 2.75`, `VictimDamageTakenScale 25`, `AbilityCooldown 4.5` | Confirmed; the "Parry page says 2 s" conflict was removed as stale |
| 9 | Parry anti-mash 0.25 s; parry during ground dash (04-10-2026) | tracklock.gg mirror | Confirmed (mirror only, medium) |
| 10 | CC diminishing returns 15%/35%, 9 s window (was 10/30, 8 s) | tracklock.gg mirror of 04-10-2026 | Confirmed for 10/30 → 15/35. The older 7/21 and 8/24 steps were not re-verified |
| 11 | Heavy melee 0.36 / 0.6 / 0.2833 s, 1.25 s total, 750/797 u/s, 192 u sphere, 200×100 u cone, 1.0/1.3 s cooldown | wiki Heavy Melee | Confirmed |
| 12 | Light/heavy melee 50/116, per-boon 1.58; Drifter 51.5/120; Venator 125 heavy; Bebop 63 light; Rem 58 light; melee cone 5 m / 30° | API | Confirmed |
| 13 | Respawn 8/38/70/85 s at 5/20/30/40 min, cap 90 s, +10 s NPC death, comeback +6…+22 s, Last Stand rules | wiki Death; wiki 09-16-2026 notes (35 → 38 s) | Confirmed |
| 14 | Boon thresholds 800 … 49200, max 35, 600 starting souls | wiki Boons; official 11-21-2025 (400 → 600); API `level_info` | Confirmed. **Corrected** the claim that `level_info` is a separate ability track: its thresholds equal boon thresholds minus 600 (inferred same track) |
| 15 | Weapon investment curve 9…115% at 0.8k…28.8k; vitality 9→66%; spirit 7→100 | API `cost_bonuses` | Confirmed |
| 16 | Weapon/Spirit Shielding: 300 barrier, 250 dmg/4 s and 225 dmg/3.5 s, 8 s, cooldowns | API; official 11-21-2025 | **Corrected** §6 text: "7–8 s, 45 s cooldown" → 8 s; 35 s (weapon) / 45 s (spirit) |
| 17 | Decay heal reduction 45% | API (`HealAmpReceivePenaltyPercent −50`); official 12-03-2025 said 45% | **Corrected** 45 → 50 (newer data wins) |
| 18 | Inhibitor 40%, Crippling Headshot 35%, Healbane 35%/35% for 8 s, Spirit Burn 70% | API | Confirmed |
| 19 | Lifesteal stacking 1−Π(1−L); non-hero effectiveness 60/40/40% | wiki Lifesteal | Confirmed. Melee Lifesteal item's own non-hero value is 30% (text tightened from "30–40") |
| 20 | Health regen range 1–3.5 HP/s, OOC delay 4 s vs heroes / 0.5 s vs NPCs (wiki), fountain +60 HP/s + 6%/s | wiki Health Regen (last edited 2026-08-12); official 11-21 / 12-03-2025 (neutral timer 0.5 → 2.5 → 4 s) | Confirmed as written; the wiki vs patch conflict for NPC timers remains open |
| 21 | Movement slow stacking, 2 m/s floor, additive slow resist | wiki Movement Slow | Confirmed |
| 22 | Slows add air drag at 35% of slow value | wiki 09-16-2026 notes | Confirmed; confidence low → medium, date set to 2026-09-16. Also added the same patch's ~20% global move-slow reduction and the change that dashes and light melee no longer pause gun cycle time |
| 23 | Fire-rate formula, −50% floor, worked example −8% | wiki Fire Rate | Confirmed |
| 24 | Shred applies after the triggering hit (01-30-2026) | official 01-30-2026 notes | Confirmed, but the notes say "various on bullet hit" debuffs; wording narrowed and confidence raised to high |
| 25 | Debuff Reducer 25% | official 01-30-2026 (20 → 25%); API | Confirmed |
| 26 | Items: Bullet Armor 18%, Spirit Armor 15%, Long Range +8%/+40% beyond 15 m, Sharpshooter +20% range, Close Quarters +20%/20% melee resist, Headshot Booster +45/9 s, Headhunter +75/8 s/4%, Rebuttal −1.75 s/+30%/6 s, Slowing Bullets 24%/3.5 s, Extra Regen 2.5 + 1.5 OOC | API | Confirmed |
| 27 | Innate resists: Lash +10 spirit, Pocket −15 spirit, Bebop 0.3 and Dynamo 0.625 bullet/boon, Kelvin 0.625 and McGinnis 0.35 spirit/boon, Venator 0.122/SP | API | Confirmed. Rem −5% melee resist was not visible in the API fields checked; it stays at medium (wiki only) |
| 28 | Lane Guardian parried stun 2 s | wiki Lane Guardian (also: no melee for 5 s after) | Confirmed; detail added |

**Not re-verified (confidence left as stated):** getting-shot slow still being live (only the 12-03-2025 notes); the spirit-lifesteal non-hero factor (wiki 40% vs item tooltip data); the debuff-resist stacking rule (the wiki does not specify); the Active Reload QTE numbers; Rejuvenator `player_respawn_mult` meaning; and the melee resist interaction.

**Legality pass:** No lore, voice lines, art or long verbatim descriptions were found. Quotes are short and paraphrased. Numbers come from public wiki pages, official patch notes and the third-party public API (tagged community-datamine). Nothing in the spec comes from the writer extracting game files. API field names such as `ParriedStunTime` and `damage_falloff_bias` are quoted as the third-party API publishes them. The in-game measurement plan uses only built-in console commands in a private lobby. Nothing was removed.

