# Stats Spec

> Clean-room observation record. Describes observed behavior of Deadlock (Valve) for the purpose of independent reimplementation. No game code or assets were used.

Scope: the hero **stat model**. This covers every numeric stat that items, boons, investment bonuses and abilities modify, including what channel each one uses, how multiple sources combine, floors and caps, whether the stat shows on the stat panel, and the order of computation. This spec is the contract for a Godot `StatSheet`. Damage math, crowd control, movement physics and the economy are specified elsewhere and are **cross-referenced, not repeated**:
- [combat.md](combat.md): damage pipeline, resists, crit, falloff, heal reduction, lifesteal, fire rate, boons.
- [abilities.md](abilities.md): spirit power, CDR, duration, range, charges.
- [movement.md](movement.md): move speed, sprint, stamina, dash.
- [economy.md](economy.md): investment bonuses and the item table.

Data currency:
- The public community API (deadlock-api.com `/v1/assets/items`, `/v1/assets/heroes`, `/v1/assets/generic-data`) is from build 6701, fetched 2026-09-27, and cached in `tools/deadlock_data/cache/`.
- deadlock.wiki pages were fetched 2026-09-29; all 21 requested pages resolved, with no Cloudflare challenge this time.
- The latest official general patch notes are dated 2026-09-16.

Units: 1 m = 39.37 engine units. The API expresses move and sprint bonuses in m/s, percentages as whole numbers (`25` means 25%), and time in seconds.

Source tags: **official** (patch notes), **wiki** (deadlock.wiki), **community-datamine** (deadlock-api.com, which is built from that site's own extraction; cite "Data: deadlock-api.com"), and **inferred** (reasoning from the data's structure, with no documentation). Each row carries a date and a high, medium or low confidence.

---

## Summary

- **The stat channel is the unit of the model.** Every item property that changes a stat carries a `provided_property_type` (a `MODIFIER_VALUE_*` enum), and **95 distinct channels** exist across all 726 API entries (items, abilities and weapons). Shopable upgrades use **119 distinct (property key, channel) pairs**. Many keys map to one channel. For example, `BonusFireRate`, `ActiveBonusFireRate`, `FireRatePerKill`, `FireRateWhileSliding` and `ActivatedFireRate` all feed `FIRE_RATE`. So a `StatSheet` should be keyed by **channel**, not by property name.
- **Four combine rules cover almost everything** (evidence in §2):
  1. *flat sum*: HP, SP, clip, stamina, charges, regen, barrier, move and sprint m/s.
  2. *additive percent pool*: weapon damage %, fire-rate bonus, clip %, bullet velocity, falloff range, melee damage %, healing amp.
  3. *diminishing stack* `1 − Π(1 − x)`: CDR, ability duration, range and radius, bullet, spirit and melee resist, resist shred, heal reduction, slows.
  4. *product* `Π(1 + x)`: spirit power %.
- Four stats have special rules:
  - Move speed has diminishing returns with K = 12 m/s.
  - Fire rate combines bonuses and slows asymmetrically, with a −50% floor.
  - Final resist equals resist minus shred, and it can go negative.
  - Debuff resist stacking is disputed.
- **Investment and boons feed the same channels as items.** The API's per-hero `purchase_bonuses` put weapon investment in `WEAPON_DAMAGE_INCREASE`, vitality investment in `BASE_HEALTH_PERCENT` and spirit investment in `TECH_POWER`. Those are the same channels shop items use, so investment bonuses stack exactly like an item of that channel. Boons (level-ups) add to *base* values (bullet damage, base HP, melee, SP, and a few per-hero resists) **before** the percentage pools.
- **Order of computation** (§4): base, then + boons, then + pre-% flat, then × (1 + additive pool), then + post-scale flat, then × product/multiplicative, then clamp and round.
  - Max HP: `(base + boons×per_boon) × (1 + vit%) + flat`, rounded up for display (wiki).
  - Clip: `(base + flat) × (1 + Σ%)`, rounded **up** (wiki). This contradicts the order this spec had drafted from the data; the wiki wins.
  - Reload: a "Reload Time %" channel with negative values meaning faster reload. Only one shop item still uses it (Spellslinger −10%), so its stacking rule is untestable in normal play.
- **Tooltips can hide stats.** Properties with no `tooltip_section` are applied but not shown. Examples: the ability **radius** multiplier that ships alongside nearly every range bonus; heal-reduction halves; Improved Spirit's (`upgrade_soaring_spirit`) +75 HP. The stat panel shows a fixed per-category list (§8), and several stats never appear on it.

---

## Mechanics

### 1. Data model: channels, keys, and flags (community-datamine, 2026-09-27, high)

Each item and ability property in the items API has these fields:

| Field | Meaning for the StatSheet |
|---|---|
| `value` | The number, as a string. Percentages are whole numbers, and move and sprint are in m/s. A negative value means a reduction, for example `ReloadSpeedMultipler −10`, `TechPowerReduction −25`, `MaxHealthLossPercent −13`. |
| `provided_property_type` | The **channel** (`MODIFIER_VALUE_*`). If it is absent, the property is mechanic data (proc chance, radius, duration, cooldown) and not a stat. |
| `tooltip_section` | `innate` (a permanent stat line), `passive` (a proc or conditional effect) or `active` (while an active is running). If it is **absent**, the property is hidden from the tooltip but may still apply (§8). |
| `usage_flags` | `ConditionallyApplied` (498 uses): applies only while a condition, buff or active holds. `IntrinsicallyProvidedInAbility` (33): baked into the ability. `ConditionallyEnemyApplied` (6): a debuff placed on the enemy. |
| `conditional` | A free-text qualifier: "after proc" (6), "against NPCs" (6), "within Range" (4), "beyond Range" (2). |
| `scale_function` | Scaling by another stat (§5): `specific_stat_scale_type` is `ETechPower`, `ELevelUpBoons`, `EHealingOutput`, `ETechDuration` and so on, with `stat_scale` per unit. |
| `label`, `postfix`, `prefix`, `display_units`, `css_class`, `negative_attribute`, `tooltip_is_elevated` | Display only (§8). |

- **Rule (inferred, high).** A property is an always-on stat when all of these hold: it has a channel, its section is `innate` or absent, it has no `ConditionallyApplied` flag, and its value is non-zero.
  - Everything else is a *conditional modifier*. A conditional modifier is added to or removed from the sheet by the item or ability's own state machine, for example "+40% fire rate for 6 s after proc".
- **Every item carries boilerplate zero or sentinel properties.** The sentinels are `WeaponPower 0`, `BaseBonusWeaponPower 0`, `ChannelMoveSpeed −1` (`MODIFIER_VALUE_INVALID`), `AbilityCooldownBetweenCharge −1` and `AbilityUnitTargetLimit 1`. The importer must ignore zeros and the `INVALID` channel.

### 2. Combine rules (the four channel kinds)

| Kind | Formula | Used by | Evidence |
|---|---|---|---|
| `flat` | `Σ v` | Health, regen, OOC regen, barrier, SP flat, clip flat, stamina, charges, move and sprint m/s (move goes through DR afterwards), melee travel | Data units (absolute numbers), and the wiki formulas on the Health, Ammo and Spirit Power pages. |
| `additive_pct` | `1 + Σ p/100` | Weapon damage %, fire-rate bonus, clip %, bullet velocity %, falloff range %, melee damage %, healing effectiveness, vitality % | Wiki pages for Weapon Damage ("DMG Multiplier" is a single pool), Fire Rate ("simply added together") and Ammo ("added together into a single multiplier"); combat §1 and §12. Velocity and falloff: inferred. |
| `mult_stack` | `1 − Π(1 − p/100)` | CDR (ability, item, ultimate, charged), ability duration, range, radius, bullet/spirit/melee resist, resist shred, heal reduction, move slows, fire-rate slows | Wiki pages for Ability Cooldown, Ability Duration, Ability Range, Damage Resistance, Spirit Resist and Healing. |
| `product` | `Π(1 + p/100)` | Spirit power %, multiplicative damage amps, `ALL_DAMAGE_MULTIPLIER` | Wiki Spirit Power ("stack multiplicatively with other bonus % sources"); wiki Damage Amplification (multiplicative amps). |

Special compositions, which are not a fifth channel kind but functions over the kinds above:
- **Move speed diminishing returns:** `bonus_eff = 12 × (1 − Π(1 − Bi/12))` (wiki Move Speed; movement.md §4).
- **Fire rate:** `M = max(Σbonus − mult_stack(slows), −0.5)`. Then `rate × (1 + M)` if M ≥ 0, else `rate / (1 + |M|)` (wiki Fire Rate; combat §12).
- **Resist:** `final = mult_stack(resists) − mult_stack(shreds)`, with no floor, so it can go negative (wiki Damage Resistance and Spirit Resist; combat §5).
- **Move slow with slow resist:** see combat §10. Slow resist is additive and slows are `mult_stack`.

### 3. Boons and investment bonuses

**Boons** (`standard_level_up_upgrades`, per hero, per boon; community-datamine 2026-09-27, high). Boons add to **base** values, which the percentage pools then scale.

| Level-up key | Range across the 38 heroes | Feeds |
|---|---|---|
| `MODIFIER_VALUE_BASE_BULLET_DAMAGE_FROM_LEVEL` | 0.043 – 1.25 per boon | base bullet damage |
| `…_ALT_FIRE` | 0 – 1.44 | alt-fire base |
| `MODIFIER_VALUE_BASE_HEALTH_FROM_LEVEL` | 27 – 65 | base HP (inside the vitality %) |
| `MODIFIER_VALUE_BASE_MELEE_DAMAGE_FROM_LEVEL` | 1.2 – 1.738 (mode 1.58) | base light and heavy melee (inferred to be a scale on both) |
| `MODIFIER_VALUE_TECH_POWER` | 0.5 – 1.6 (mode 1.1) | base SP |
| `MODIFIER_VALUE_BULLET_ARMOR_DAMAGE_RESIST` | Dynamo 0.625, Bebop 0.3 | bullet resist (one more `mult_stack` term, inferred) |
| `MODIFIER_VALUE_TECH_RESIST` | McGinnis 0.35, Kelvin 0.625 | spirit resist |
| `MODIFIER_VALUE_BONUS_ATTACK_RANGE` | Bebop 59 | per-hero special case |
| `MODIFIER_VALUE_BOON_COUNT` | 1 | the counter read by `ELevelUpBoons` scale functions |

**Investment bonuses.** Combat §14 and economy §14–15 cover the tables in detail. The API holds two structures, both identical for all 38 heroes:

- **`cost_bonuses`** (a step function on souls spent per category):
  - Thresholds: 800 / 1600 / 2400 / 3200 / 4800 / 6400 / 8000 / 11200 / 16000 / 22400 / 28800.
  - Weapon (% weapon damage): 9/12/15/18/46/54/62/74/86/100/115.
  - Vitality (% base HP): 9/12/15/20/38/42/46/50/54/60/66.
  - Spirit (flat SP): 7/11/15/19/38/45/52/59/66/75/100.
  - The wiki Items page (2026-09-29) confirms the per-type accumulation, the 28,800 cap and the "4.8k spike". The bonus is lost when the item is sold.
- **`purchase_bonuses`** (per item tier 1–5):
  - Weapon `WEAPON_DAMAGE_INCREASE` 4/8/13/18/23.
  - Vitality `BASE_HEALTH_PERCENT` 7/8/9/10/11.
  - Spirit `TECH_POWER` 4/7/10/13/16.
  - This structure is **unexplained**. It may be a newer per-item model or an unused one (the open question is already in combat.md). The wiki Health page says the vitality multiplier starts at **8%**. That matches neither `cost_bonuses` (9%) nor tier-1 `purchase_bonuses` (7%), so it is flagged in the open questions.
- **Channel mapping (inferred, medium).** The `purchase_bonuses` rows name channels explicitly, and they are the same channels items use. So investment bonuses are treated as one more contributor to:
  - `WEAPON_DAMAGE_INCREASE`, in the additive pool with item weapon damage;
  - `BASE_HEALTH_PERCENT`, the vitality % pool that multiplies base plus boons;
  - `TECH_POWER`, which is flat SP and is then multiplied by SP %.

  The wiki formulas agree: the Health page's "Vitality Bonuses" multiplies base plus boons, and the Weapon Damage page says items *and* investment add bonus weapon damage.

### 4. Order of computation (pseudocode)

```
# inputs: hero starting_stats S, per-boon table L, boons B, channel sums C[...] (items + investment + buffs)

# --- Health ---
base_hp   = S.max_health + B * L.BASE_HEALTH_FROM_LEVEL
vit_pct   = C.additive[BASE_HEALTH_PERCENT]          # investment % + Colossus 25 + …
max_hp    = base_hp * (1 + vit_pct) + C.flat[HEALTH_MAX]
max_hp   *= (1 + C.additive[HEALTH_MAX_PERCENT])      # Glass Cannon −13 (inferred: applied last)
max_hp    = ceil(max_hp)                              # wiki: rounded up
# On max-HP change, keep the current-HP *fraction*? UNKNOWN — see Open question 6.

# --- Bullet damage ---
base_bullet = W.bullet_damage + B * L.BASE_BULLET_DAMAGE_FROM_LEVEL (+ hero SP scaling, e.g. Vindicta 0.022/SP)
bullet      = base_bullet * (1 + C.additive[WEAPON_DAMAGE_INCREASE] + conditional pools)
bullet     += C.flat[FLAT_BULLET_DAMAGE_POST_SCALE]   # abilities only; wiki: not scaled by weapon %
# then falloff × crit × additive/multiplicative amps × (1 − resist) … → combat.md §1

# --- Melee ---
light = (S.light_melee_damage + B*L.BASE_MELEE…) * (1 + 0.5*C.additive[WEAPON_DAMAGE_INCREASE]
                                                     + C.additive[MELEE_DAMAGE_INCREASE])   # same pool: inferred
heavy = (S.heavy_melee_damage + …) * same * (1 + BonusHeavyMeleeDamage%) * Π MELEE_DAMAGE_MULTIPLIER

# --- Fire rate ---
M = max(C.additive[FIRE_RATE] - C.mult_stack[FIRE_RATE_SLOW], -0.5)
cycle_time = W.cycle_time / (1 + M) if M >= 0 else W.cycle_time * (1 + abs(M))

# --- Clip ---
clip = ceil((W.clip_size + C.flat[AMMO_CLIP_SIZE] + hero_SP_clip) * (1 + C.additive[AMMO_CLIP_SIZE_PERCENT]))
# wiki Ammo: flat first, then %, round UP.  Example: (20+10)*1.19 = 35.7 → 36

# --- Reload ---
reload_time_pct = C.sum[RELOAD_SPEED]                 # negative = faster ("Reload Time −10%")
reload_time     = W.reload_duration * max(0.0, 1 + reload_time_pct)   # additive, inferred (low)
# single-shell weapons: apply to initial_delay and per-shell time alike (inferred, low)

# --- Spirit ---
sp  = (B * L.TECH_POWER + C.flat[TECH_POWER]) * Π(1 + C.each[TECH_POWER_PERCENT])     # abilities M9
cd  = base_cd * (1 - mult_stack(CDR [+ ULTIMATE_CDR if ult] [+ CHARGED_CDR if charged]))
dur = base_dur * (1 + mult_stack(BONUS_ABILITY_DURATION_PERCENTAGE))
rng = base_rng * (1 + mult_stack(TECH_RANGE_PERCENT));  rad = base_rad * (1 + mult_stack(TECH_RADIUS_PERCENT))
charges = base_charges + C.flat[BONUS_ABILITY_CHARGES] (only if ability is charged or ENABLE_CHARGES)

# --- Movement ---
move   = S.max_move_speed + 12*(1 - Π(1 - Bi/12))     # Bi = each MOVEMENT_SPEED_MAX source, m/s
sprint = S.sprint_speed + Σ SPRINT_SPEED_BONUS          # additive, no DR
stamina_rate = S.stamina_regen_per_second * (1 + Σ STAMINA_REGEN_PER_SECOND_PERCENTAGE)   # inferred
# → per-bar cooldown = 1 / stamina_rate  (= 4.5 s / (1+Σr) for the modal hero)
```

- Clamp every percentage pool at the floor that makes the result non-negative. **No other caps are documented** for CDR, duration, range, lifesteal or resists (wiki, 2026-09-29).
- Round only for display, except where the wiki documents gameplay rounding: clip (integer ammo) and max HP.

### 5. Stat-to-stat scaling (`scale_function`)

Item and ability values that scale with another stat declare it in `scale_function.specific_stat_scale_type`. Counts across all API entries (community-datamine 2026-09-27, high):

- ETechDuration 906, ETechRange 841, ETechCooldown 475, EItemCooldown 272, ETechPower 190, EHealingOutput 90, ETechRadius 71, EMaxChargesIncrease 66, ETechCooldownBetweenChargeUses 66, EMeleeRange 58, ELevelUpBoons 24, ELightMeleeDamage 11, EBuildUpRate 10, EBaseWeaponDamageIncrease 6, EReloadSpeed 4, EProcBuildUpRateScale 4, EHeavyMeleeDamage 3, EWeaponPower 2, EWeaponDamageScale 2, EStatsCount 2, EAirMoveDistanceScale 1, EParryCooldown 1, EBulletDamage 1, EWeaponFalloffMaxRange 1.

What these counts imply:
- **The derived stats are the StatSheet's public read API.** Abilities and items never read raw channels; they read *derived stats* such as `ETechDuration` (the duration multiplier) and `ETechCooldown` (the cooldown multiplier).
- **Durations, ranges, cooldowns and radii scale implicitly.** The item's `ETechDuration` or `ETechRange` scale marks a value as affected by duration and range bonuses. This is how "ability range affects active items" works (wiki Ability Range). Item cooldowns use `EItemCooldown` rather than `ETechCooldown`, which is why ability CDR does not reduce item cooldowns (wiki Ability Cooldown).
- **Healing and lifesteal values** carry `EHealingOutput` scaling, so healing amp multiplies them.
- **Boon-scaled item values** (`ELevelUpBoons`):
  - Cultist Sacrifice: +50 HP (+4 per boon) and +10% weapon damage (+0.8 per boon).
  - Headhunter: 75 (+4 per boon).
  - Weapon Shielding and Spirit Shielding: barrier 300 (+5 per boon).
  - Majestic Leap: barrier 200 (+12 per boon).
  - Express Shot: proc 125% (+2 per boon).
- **SP-scaled values** (`ETechPower`), per SP:
  - Vex barrier 325: +1.8 to 2.0.
  - Bullet shred: −0.055.
  - Item damage: 0.16 to 0.7.
  - Mercurial Magnum's 20% base-bullet bonus: +0.38.
- **Odd couplings to reproduce, not "fix":**
  - `EReloadSpeed` scales weapon wind-up and charge times (Humble Pie wind-up, Sister's Lament charge).
  - `EWeaponFalloffMaxRange` scales The Teacher's cast range.
  - Parry cooldown uses `EParryCooldown`.
- **Multi-stat scaling:** `ETechDuration + EChannelDuration` (731), `ETechPower + ETechRange`, and `ELevelUpBoons + EWeaponDamageScale + EDamageScale`.
- **Hero SP scaling** (`starting_stats … scaling_stats`), per SP:
  - Vindicta: EBulletDamage 0.022.
  - Wraith: ESprintSpeed 0.05.
  - Haze: EClipSize 0.5.
  - Grey Talon: EMaxMoveSpeed 0.0084 and EBulletDamage 0.08.
  - Warden: ERoundsPerSecond 0.008 and EFireRate 0.21.
  - Yamato: EClipSize 0.15.
  - Vyper and Sinclair: EMaxMoveSpeed 0.0138.
  - Venator: bullet and spirit resist 0.12178.
  - Victor: EBaseHealthRegen 0.08.
  - Paige: EHeavyMeleeDamage 0.45.

  These are **flat** additions into the named derived stat (inferred, medium). For example, Haze's clip adds to the flat term before the clip %.

### 6. Conditional variants

Many channels have conditional keys that feed the **same channel** only while the condition holds (`usage_flags: ConditionallyApplied`):
- **On active:** `ActiveBonusFireRate`, `ActiveBonusMoveSpeed`, `ActiveBonusLifesteal 70`.
- **Per stack or per kill:** `WeaponPowerPerStack`, `FireRatePerKill 7`, `BonusClipPerKill 2`, `WeaponDamageBonusPerKill`, `StackingGoldPerMinute`.
- **Range-gated:**
  - `CloseRangeBonusWeaponPower 20/50` applies within 15 m (`BONUS_WEAPON_DAMAGE_CLOSE_RANGE_MAX_RANGE`).
  - Long-range 40/60 applies beyond 15 m (`…_MIN_RANGE`).
- **Target-gated:** `NonPlayerBonusWeaponPower −15/25/30` ("against NPCs") and `BULLET_RESIST_NON_HERO 25/30`.
- **HP-gated:** `BulletResistBelowThreshold` and `TechResistBelowThreshold` 15 below 50% HP.
- **State-gated:**
  - `FireRateWhileSliding 60`.
  - Charged-ability-only: `BonusSpiritForChargedAbilities 7/14/50`, `CooldownReductionOnChargedAbilities 14/30`.
  - Imbued-ability-only: `ImbuedTechPower 28/70`, `ImbuedCooldownReduction 50`, `ImbuedBonusDuration`.
  - Ultimate-only: `ULTIMATE_COOLDOWN_REDUCTION_PERCENTAGE 10`.
- **Debuffs placed on enemies** (`ConditionallyEnemyApplied` plus the shred and slow channels):
  - `BulletArmorReduction` / `BulletResistReduction −5…−16`.
  - `TechArmorDamageReduction −6…−16`.
  - `FireRateSlow 15–40`.
  - `HealAmpReceivePenaltyPercent −35…−70`.
  - `TechPowerReduction −25/−30`.
  - `OutgoingDamagePenaltyPercent −40`.

**StatSheet implication:** a modifier needs a `scope` tag (`all`, `charged_only`, `imbued_only`, `ultimate_only`, `vs_npc`, `vs_hero`, `range_lt:15m`, `range_gt:15m`). Consumers then query with a context, for example `sheet.get(TECH_POWER, {ability=x})`.

### 7. Stamina, sprint and movement notes (cross-reference movement.md)

- **Stamina regen is a rate.** Hero `stamina_regen_per_second` ranges 0.1667 – 0.2381 (mode 0.2222 = 1/4.5 s). The channel is `STAMINA_REGEN_PER_SECOND_PERCENTAGE`, even though the key is named `StaminaCooldownReduction` and labelled "Stamina Recovery".
  - So the natural model is **rate × (1 + Σr)**, which equals movement.md's `cooldown / (1 + Σr)` (inferred, medium).
  - The wiki says Seraphim's +120% "nearly doubles" regen speed, which fits the rate model qualitatively.
  - Weighted Shots −14% → rate × 0.86.
  - A separate `STAMINA_REGEN_PER_SECOND_ADDITIVE` channel exists (abilities only).
- **Sprint delay:** the wiki Sprint Speed page (2026-09-29) still says 5 s. Movement.md §3 records the official change to 3 s (2025-12-16) and treats the wiki as stale. **The official value is kept.**
- **Stamina cooldown:** the wiki Stamina page still says about 5 s per bar. The data mode is 4.5 s, matching movement.md.
- **Dash distance:**
  - Items reduce enemy dash distance through `MOVEMENT_GROUND_DASH_REDUCTION_PERCENT` (−10 … −36).
  - `GROUND_DASH_INCREASE_PERCENT` exists, but no shop item uses it.
  - `AIR_MOVE_DISTANCE_INCREASE_PERCENT 23` (Stamina Mastery) scales air dash and jump distance.
  - The base values are the hero's `ground_dash_distance_in_meters` (10) and `air_dash_distance_in_meters` (8).
  - The panel shows `EDashSpeedInMeters`.

### 8. Display: stat panel and tooltips

**Stat panel** (`shop_stat_display` and `stats_display`, identical for all heroes; community-datamine 2026-09-27, high):

- **Weapon tab:** EBulletDamage, EBaseWeaponDamageIncrease, ERoundsPerSecond, EFireRate, EClipSize, EClipSizeIncrease, EReloadTime, EReloadSpeed, EBulletSpeed, EBulletSpeedIncrease, EBulletLifesteal, ECritDamageBonusScale. Other: ELightMeleeDamage, EHeavyMeleeDamage.
- **Vitality tab:** EMaxHealth, EBaseHealthRegen, EHealingOutput, EOOCHealthRegen, EBulletArmorDamageReduction, ETechArmorDamageReduction, EMeleeResist, EDebuffResist, ECritDamageReceivedScale. Other: EMaxMoveSpeed, ESprintSpeed, EStaminaCooldown, EStaminaRegenIncrease, EStamina, EDashSpeedInMeters.
- **Spirit tab:** ETechCooldown, ETechDuration, ETechRange, ETechLifesteal, EMaxChargesIncrease, ETechCooldownBetweenChargeUses. The header is ETechPower.
- **In-game HUD stat block** (`stats_display`): the health header (EMaxHealth, EBaseHealthRegen), the weapon header (EWeaponDPS, EBulletDamage), the magic header (ETechPower plus cooldown, range, duration), and lines for resists, lifesteal, move, sprint, stamina, healing, melee, fire rate and clip.
- **Never on the panel:** spirit power % (only the resulting SP), item CDR, ultimate CDR, ability **radius**, slow resist, falloff range, raw bullet-velocity m/s beyond `EBulletSpeed`, heal reduction received, fire-rate slows, damage amps, and souls/min.

**Panel conventions** (inferred from the paired names, medium):
- Paired names show a result and its bonus side by side: EClipSize and EClipSizeIncrease, EBulletSpeed and EBulletSpeedIncrease, EReloadTime and EReloadSpeed, ERoundsPerSecond and EFireRate.
- Percentage stats display the *combined* value. For example, CDR shows `1 − Π`, not the sum; the wiki's worked examples use combined values.

**Tooltips** (item properties):
- `label` plus `postfix` (`%`, `m`, `s`) plus `prefix` (`+`), and `display_units` is the unit string.
- `tooltip_is_elevated` puts the line in the big stat block at the top of the card.
- `negative_attribute` renders the line as a downside, for example Glass Cannon's max-HP loss and Weighted Shots' stamina penalty.
- `css_class` colours the line by category.
- Items show **raw item values**, not the post-stacking contribution.
- **Hidden (no `tooltip_section`) but applied** (inferred, medium):
  - `TechRadiusMultiplier` on at least 13 shop items (Mystic Expansion 20, Greater Expansion 30, Mystic Conduit 40, and others).
  - `HealAmpRegenPenaltyPercent` on anti-heal items (Toxic Bullets, Healbane, Decay, Spirit Burn, Cheat Death, Inhibitor).
  - Improved Spirit (`upgrade_soaring_spirit`): +75 HP.
  - Refresher: bullet and spirit resist 15/14.
  - Witchmail: CDR 7.
  - Mystic Conduit: SP 40.

  Some hidden entries are probably active-only values that the tooltip describes in prose; which ones are always-on is Open question 9. economy.md already flags Improved Spirit's missing HP as a wiki omission.

---

## Stat catalog

"Channel" means `MODIFIER_VALUE_<name>`. The n= values are shopable-item counts with a non-zero value. Stacking kinds are those in §2. "Panel" is Y (shown), N (not shown) or result-only. Unless marked otherwise, the data evidence is **community-datamine 2026-09-27** and wiki evidence is **wiki 2026-09-29**.

### Weapon

| Stat | API key(s) → channel | Units | Applies to | Stacking | Floor/cap | Evidence | Conf |
|---|---|---|---|---|---|---|---|
| Weapon damage % | `BaseAttackDamagePercent` (n=26, 5–18), `BaseAttackDamagePercentBonus`, `AtMaxDuration`, `ProcBaseAttackDamagePercent`, `WeaponPowerPerStack(NonHero)`, `BuffBaseWeaponPct`, `WeaponDamageBonusPerKill`, `WeaponPowerDebuff` → `WEAPON_DAMAGE_INCREASE`; investment (weapon cost_bonuses 9–115%) | % | base bullet damage (starting + boons); melee at 50% | additive_pct | none documented; floor at 0 total | wiki Weapon Damage (single multiplier); combat §1, §16; purchase_bonuses channel | high |
| Weapon power (legacy) | `WeaponPower`, `BaseBonusWeaponPower` → `WEAPON_POWER`; hero `weapon_power` 0, `weapon_power_scale` 1 | — | — | ignore (always 0 on items) | — | data | high |
| Flat bullet damage | `WeaponDamageBonus` → `FLAT_BULLET_DAMAGE_POST_SCALE` (abilities only, 6) | dmg/bullet | added after the % pool | flat | — | channel name plus wiki "added after multiplier" | high |
| Bullet damage (per kill, etc.) | `WeaponPowerPerKill` → `BULLET_DAMAGE_INCREASE` | % | as weapon % (inferred) | additive_pct | — | data | low |
| Close / long-range weapon damage | `CloseRangeBonusWeaponPower` 20/50 → `CLOSE_RANGE_WEAPON_DAMAGE_INCREASE` (+ max range 15 m); long 40/60 → `LONG_RANGE_BULLET_DAMAGE_INCREASE` (+ `BONUS_BULLET_DAMAGE_LONG_RANGE_MIN_RANGE` 15 m) | % | bullet damage when the range condition holds | additive_pct (conditional) | range gate | data "within/beyond Range" | medium |
| Damage vs NPC | `NonPlayerBonusWeaponPower` −15/25/30 → `WEAPON_DAMAGE_TO_NPC_INCREASE` | % | vs non-heroes | additive_pct (inferred) | — | data "against NPCs" | medium |
| Fire rate | `BonusFireRate` (n=19, 5–20+), `ActiveBonusFireRate`, `ActivatedFireRate` 32, `FireRatePerKill` 7, `FireRateWhileSliding` 60, `FervorFireRate` → `FIRE_RATE` | % | 1 / cycle_time | additive; combined with slows | total M ≥ −50% | wiki Fire Rate; combat §12 | high |
| Fire-rate slow | `FireRateSlow` 15/28/32/40, `MaxFireRateSlowPercent` → `FIRE_RATE_SLOW` | % | enemy fire rate | mult_stack, then subtracted | −50% floor on the total | wiki Fire Rate | high |
| Clip size % | `BonusClipSizePercent` 20/30/35/100, `ClipSizeBonus` → `AMMO_CLIP_SIZE_PERCENT` | % | base clip + flat | additive_pct | round up | wiki Ammo | high |
| Clip size flat | `BonusClipSize` (Kinetic Dash, temporary 6), `BonusBullets`, `BonusClipPerKill` 2; Haze/Yamato SP scaling → `AMMO_CLIP_SIZE` | bullets | base clip, **before** the % | flat | — | wiki Ammo formula | high (order), medium (hero SP) |
| Reload time | `ReloadSpeedMultipler` ("Reload Time", postfix %) → `RELOAD_SPEED`; Spellslinger −10 (shop); disabled items −25/−35 | % of reload duration (negative = faster) | `reload_duration` (and single-shell delays, inferred); also wind-up/charge via `EReloadSpeed` | additive (inferred) | floor 0 | data; combat §2 "multiplier on time"; wiki Reload gives no formula | low |
| Ammo refill effects | `AmmoReloadPercent`, `ActiveReloadPercent` 75, `LightMeleeAmmo` 15 | % of clip | — | mechanic, not a stat | — | data; combat §2 | medium |
| Bullet velocity | `BonusBulletSpeedPercent` 60/200, `ProcBulletVelocity` 100 → `BONUS_BULLET_SPEED_PERCENT` | % | weapon `bullet_speed` | additive_pct (inferred) | — | wiki Bullet Velocity (values only) | medium |
| Falloff range | `BonusAttackRangePercent` ("Weapon Fall-off Range") 8/20 → `BONUS_ATTACK_RANGE_PERCENT` | % | falloff start and end ranges | additive_pct (inferred) | — | data label; combat §4 | medium |
| Headshot bonus | `BonusCritDamagePercent`, `BonusHeadshotDamage` → `BONUS_CRIT_DAMAGE_PERCENT`; `HeadShotBonusDamage` (Headshot Booster 45, Headhunter 75 +4/boon) and `CritDamagePercent` (Lucky Shot 100) are **proc/mechanic keys** with no channel | % | crit multiplier 1.65 (`crit_mult = 1 + 0.65×(1+bonus)`) / flat proc damage | additive (inferred) | — | combat §3 | medium |
| Crit damage received | `HeadshotResist` → `CRIT_DAMAGE_RECEIVED_SCALE`; hero `crit_damage_received_scale` 0.45–1 | scale | incoming crit bonus | product (inferred) | ≥ 0 | combat §3 | medium |
| Zoom | → `ZOOM_INCREASE_PERCENT` 25 | % | ADS FOV | additive | — | data | medium |
| Spread / accuracy | `AccuracyPercentage`, `DebuffAccuracy` → `FIREARM_ACCURACY_PERCENTAGE`; → `WEAPON_RECOIL_REDUCTION_PERCENT` (abilities only) | % | spread / recoil | additive (inferred) | — | data; see the gun-system approximation in combat §2 | low |
| Bullet lifesteal | `BulletLifestealPercent` 10/13/14/16/28, `ActiveBonusLifesteal` 70 → `BULLET_LIFESTEAL`; scaled by `EHealingOutput` | % of damage dealt | post-resist bullet damage | see combat §9 (multiplicative there); non-hero 60% | — | combat §9 | medium |
| Bullet resist shred | `BulletArmorReduction`, `BulletResistReduction` −5…−16 (SP-scaled −0.055/SP) → `BULLET_AND_MELEE_RESIST_REDUCTION` | % | target bullet **and melee** resist | mult_stack, then subtracted | final resist may be < 0 | wiki Damage Resistance; channel name | high |

### Vitality

| Stat | API key(s) → channel | Units | Applies to | Stacking | Floor/cap | Evidence | Conf |
|---|---|---|---|---|---|---|---|
| Max HP flat | `BonusHealth` (n=51, 30–375; Cultist +4/boon), `BonusMaxHealth` → `HEALTH_MAX` | HP | added after vitality % | flat | ceil | wiki Health formula | high |
| Vitality % (base HP %) | `BonusBaseHealth` (Colossus 25) → `BASE_HEALTH_PERCENT`; vitality investment 9–66% | % | base + boon HP | additive_pct | — | wiki Health ("Vitality Bonuses"); purchase_bonuses channel | high (formula), medium (Colossus in the same pool) |
| Max HP % | `MaxHealthLossPercent` (Glass Cannon −13) → `HEALTH_MAX_PERCENT` | % | total max HP | applied last (inferred) | — | data only | low |
| Base regen | `BonusHealthRegen` 2.5/3/6/8 → `HEALTH_REGEN_PER_SECOND`; hero `base_health_regen` 1–3.5 (Victor +0.08/SP) | HP/s | always on | flat | — | wiki Health Regen ("additively"); combat §7 | high |
| Out-of-combat regen | `OutOfCombatHealthRegen` (n=27, 1–4) → `OUT_OF_COMBAT_HEALTH_REGEN` | HP/s | after the combat timer (4 s hero, 0.5 s NPC) | flat | — | wiki Health Regen | high |
| Max-HP % regen | `HealLifePercentOutOfCombat` 2.25 + `RestoreDelay` 10 (Fortitude): **no channel**, item mechanic | %maxHP/s | — | item-scripted | — | data; combat §7 | medium |
| External regen | → `EXTERNAL_HEALTH_REGEN_PER_SECOND` (abilities) | HP/s | — | flat | — | data | low |
| Bullet resist | `BulletResist` (n=20) → `BULLET_ARMOR_DAMAGE_RESIST`; boon (Dynamo/Bebop); `BulletResistBelowThreshold`; `BULLET_RESIST_NON_HERO` 25/30 (vs NPC) | % | bullet **and melee** damage | mult_stack | none; can go negative after shred | wiki Damage Resistance; combat §5 | high |
| Spirit resist | `TechResist` (n=22), `TechResistBelowThreshold` → `TECH_RESIST`; hero `tech_armor_damage_reduction` (3 heroes) | % | spirit damage | mult_stack | same | wiki Spirit Resist | high |
| Melee resist | `MeleeResistPercent` 18–50 → `MELEE_RESIST` | % | melee damage | mult_stack; stacks with bullet resist (inferred multiplicative) | — | wiki Damage Resistance (bullet resist also reduces melee) | medium |
| Spirit shred | `TechArmorDamageReduction` −6…−16 → `TECH_RESIST_REDUCTION`; → `MELEE_RESIST_REDUCTION` (abilities) | % | target resist | mult_stack, then subtracted | < 0 allowed | wiki Spirit Resist | high |
| Debuff resist | `StatusResistancePercent` 20–40, `InnateStatusResistancePercent` (Mina −8) → `STATUS_RESISTANCE` | % | incoming CC and debuff duration (not parry stun or knockdown) | **disputed**: combat §10 chose multiplicative; the wiki implies additive | none documented | wiki Debuff Resist; combat §10 | low |
| Healing effectiveness (outgoing) | `HealAmpCastPercent` 20/25 ("Healing Effectiveness") → `HEAL_AMP_CAST_PERCENT`; shown as `EHealingOutput` | % | heals the hero *casts* (self and allies), lifesteal via `EHealingOutput` scale | additive_pct (inferred) | — | wiki Healing ("25% makes 100 into 125") | medium |
| Regen amp / regen penalty | `HealAmpRegenPercent` (+20 Healing Booster, +25 Healing Tempo) / `HealAmpRegenPenaltyPercent` (−35…−70) → `HEAL_AMP_REGEN_PERCENT` | % | the hero's own regen | penalties mult_stack; same source does not stack (combat §8) | ≥ −100% | combat §8; data (mostly hidden) | medium |
| Heal received penalty | `HealAmpReceivePenaltyPercent` −35…−70 → `HEAL_AMP_RECEIVE_PERCENT` | % | all healing received | mult_stack; applied **before** amp | ≥ −100% | wiki Healing (reduction then amp) | high |
| Heal-reduction resist | `DegenResistance` ("Healing Reduction Resist") → `HEAL_DEGEN_RESISTANCE` (currently 0 on Healing Booster) | % | incoming heal reduction | unknown | — | data | low |
| Barrier | `CombatBarrier` 200–1000 (boon- and SP-scaled), `VexBarrierCombatBarrier` 325 → `BARRIER_HEALTH`; `BARRIER_AMP_CAST_PERCENT` | HP | temporary pool | flat, additive; decays | — | combat §6 | high |
| Legacy bullet shield | → `BULLET_SHIELD_HEALTH`; panel `EBulletShieldHealth` | HP | — | flat | — | merged into barrier in 2025-05 (combat §6) | medium |
| Damage amps | `BonusDamagePercent` 30, `OutgoingDamagePenaltyPercent` −40, `DeathImmunityDamageReduction` → `ALL_DAMAGE_MULTIPLIER`; `ALL_DAMAGE_TAKEN_INCREASE`, `INCOMING_DAMAGE_PERCENTAGE`, `BULLET_DAMAGE_TAKEN_INCREASE`, `TECH_DAMAGE_MULTIPLIER` | % | final damage | additive vs multiplicative per the wiki Damage Amplification categories; see combat §1 | — | wiki Damage Amplification | medium |
| Bullet evasion | → `BULLET_EVASION` (abilities) | % chance | — | unknown | — | data | low |

### Movement

| Stat | API key(s) → channel | Units | Applies to | Stacking | Floor/cap | Evidence | Conf |
|---|---|---|---|---|---|---|---|
| Move speed | `BonusMoveSpeed` (n=21, −0.7 and 0.75–10), `ActiveBonusMoveSpeed` → `MOVEMENT_SPEED_MAX`; hero `max_move_speed` 6.2–8.2 | m/s | added to base | DR `12(1−Π(1−Bi/12))` | effective bonus < 12 m/s | wiki Move Speed; movement §4 | high |
| Move speed % | → `MOVEMENT_SPEED_MAX_PERCENT` (abilities) | % | — | unknown (DR presumably after conversion) | — | data | low |
| Sprint speed | `BonusSprintSpeed` 0.5–2 (n=18); Wraith 0.05/SP → `SPRINT_SPEED_BONUS`; hero `sprint_speed` 1–4 (mode 1.6) | m/s | while sprinting | flat, no DR | ramp above +2.5 at 0.6 m/s² | wiki Sprint Speed; movement §3 | high |
| Sprint acceleration | → `SPRINT_ACCELERATION` | — | sprint ramp | unknown | — | data | low |
| Slow | `SlowPercent`, `MovementSpeedSlow` → `MOVEMENT_SPEED_SLOW_PERCENT`; hard limits → `MOVE_SPEED_LIMIT` | % | enemy speed | mult_stack | floor formula (combat §10) | combat §10 | high |
| Slow resist | → `MOVEMENT_SLOW_RESISTANCE` 25/40/50 | % | incoming slows | additive | — | combat §10 | medium |
| Stamina | `Stamina` 1/2/3 → `STAMINA`; hero 2–4 | bars | — | flat | HUD shows ≤ 8 | wiki Stamina | high |
| Stamina recovery | `StaminaCooldownReduction` (label "Stamina Recovery") −14/12/18/100/120 → `STAMINA_REGEN_PER_SECOND_PERCENTAGE`; `STAMINA_REGEN_PER_SECOND_ADDITIVE` | % of regen rate | hero `stamina_regen_per_second` | additive_pct on rate (inferred) | rate > 0 | channel name + rate base; movement §7 | medium |
| Dash distance | → `MOVEMENT_GROUND_DASH_REDUCTION_PERCENT` −10…−36 (enemy debuff); `MOVEMENT_GROUND_DASH_INCREASE_PERCENT` | % | ground dash 10 m / air 8 m | reductions mult_stack (inferred) | — | data | low |
| Air move distance | `AirMoveIncreasePercent` 23 → `AIR_MOVE_DISTANCE_INCREASE_PERCENT` | % | air dash and air jump distance | additive_pct | — | movement §7 | medium |
| Air control | `AirControlPercent` 25/50/100 → `AIR_CONTROL_PERCENT`; → `AIR_CONTROL_ACCEL_PERCENT` 50 | % | air accel/steer | additive_pct (inferred) | — | data | low |
| Slide | → `MOVEMENT_SLIDE_DISTANCE_SCALE` 35/50/80; `SlideTurnScale` 100 → `MOVEMENT_SLIDE_TURN_SCALE` | % | slide | additive (inferred) | — | data | low |
| Shoot / zoom move penalty | `MoveWhileShootingSpeedPenaltyReductionPercent`, `MoveWhileZoomedSpeedPenaltyReductionPercent` 100 → `MOVEMENT_SPEED_WHILE_SHOOTING_PENALTY_REDUCTION_PERCENT` / `MOVEMENT_SPEED_WHILE_ZOOMED_PENALTY_REDUCTION_PERCENT` | % of the penalty removed | ×0.75 shooting penalty | additive, cap 100 | ≤ 100 | data; movement | medium |
| Jump / gravity / friction | → `BONUS_JUMP_VERTICAL_SPEED_PERCENT`, `GRAVITY_SCALE` (`GravityScale` −15/−70), `FRICTION_PERCENTAGE` | % | — | additive (inferred) | — | data | low |

### Spirit

| Stat | API key(s) → channel | Units | Applies to | Stacking | Floor/cap | Evidence | Conf |
|---|---|---|---|---|---|---|---|
| Spirit power flat | `TechPower` (n=19, 6–40), `SpiritPower`, `BonusSpirit`, `BonusSpiritForChargedAbilities` 7/14/50, `ImbuedTechPower` 28/70, `TechPowerGain` 25, `SpiritPowerPerSoul`, `TechPowerReduction` −25/−30 → `TECH_POWER`; boons 0.5–1.6; spirit investment 7–100 | SP | — | flat, then × SP% | ≥ 0 (inferred) | wiki Spirit Power; abilities M9 | high |
| Spirit power % | → `TECH_POWER_PERCENT` (Boundless Spirit 15) | % | current SP | product | — | wiki Spirit Power | high |
| Ability CDR | `CooldownReduction` 5/7/18/20/25/40, `CooldownReductionOnChargedAbilities` 14/30, `ImbuedCooldownReduction` 50 → `COOLDOWN_REDUCTION_PERCENTAGE` | % | ability cooldowns (`ETechCooldown`) | mult_stack | no cap | wiki Ability Cooldown; abilities M10 | high |
| Item CDR | `ItemCooldownReduction` 25 → `ITEM_COOLDOWN_REDUCTION_PERCENTAGE` | % | item cooldowns (`EItemCooldown`), not charge-up items | mult_stack | — | wiki Ability Cooldown | high |
| Ultimate CDR | → `ULTIMATE_COOLDOWN_REDUCTION_PERCENTAGE` 10 | % | ultimate only | mult_stack with ability CDR (inferred) | — | data; abilities M10 | medium |
| Charge cooldown | → `COOLDOWN_BETWEEN_CHARGE_REDUCTION_PERCENTAGE` 30/70 | % | time between charge uses (`ETechCooldownBetweenChargeUses`) | mult_stack (inferred) | — | abilities M11 | medium |
| Bonus charges | → `BONUS_ABILITY_CHARGES` 1/2 (Omnicharge 4/2); → `ENABLE_CHARGES` | charges | charged abilities / all | flat | — | data; abilities | high |
| Ability duration | `BonusAbilityDurationPercentage` 13/15/22/28, `ImbuedBonusDuration` → `BONUS_ABILITY_DURATION_PERCENTAGE` | % | ability and item durations (`ETechDuration`) | mult_stack | — | wiki Ability Duration | high |
| Ability range | `TechRangeMultiplier` 5–40 → `TECH_RANGE_PERCENT` | % | cast range incl. active items (`ETechRange`) | mult_stack | — | wiki Ability Range | high |
| Ability radius | `TechRadiusMultiplier` 5–40 (usually hidden) → `TECH_RADIUS_PERCENT` | % | AoE radius (`ETechRadius`) | mult_stack (inferred, same as range) | — | data | medium |
| Spirit damage % | `TechDamagePercent`, `TechDamageReduction` −25 → `TECH_DAMAGE_MULTIPLIER`; `IMBUED_BONUS_DAMAGE` | % | spirit damage | see combat §1 amps | — | data | medium |
| Spirit lifesteal | `AbilityLifestealPercentHero` 8/13/28/70 → `TECH_LIFESTEAL`; `NonHeroAbilityLifestealTooltipOnly` 3; `TECH_DAMAGE_TAKEN_HEALS_ATTACKER` (Spirit Rend 10, on the enemy) | % | post-resist spirit damage | combat §9 | non-hero effectiveness (combat §9: 40% vs data 3/13) | combat §9 | medium |
| Spirit shred | see Vitality: `TECH_RESIST_REDUCTION` | | | | | | |

### Melee

| Stat | API key(s) → channel | Units | Applies to | Stacking | Floor/cap | Evidence | Conf |
|---|---|---|---|---|---|---|---|
| Melee damage % | `BonusMeleeDamagePercent` 7–30 → `MELEE_DAMAGE_INCREASE` | % | light and heavy base (starting 42–63 / 116–128 + boons) | additive_pct with 50% of weapon % (inferred same pool) | — | combat §1, §11 | medium |
| Melee multiplier | → `MELEE_DAMAGE_MULTIPLIER`; `HeavyMeleeMultiplier` 2× (proc) | × | final melee | product | — | data | medium |
| Heavy-only bonus | `BonusHeavyMeleeDamage` 25 (no channel) | % | heavy melee | item-scripted | — | data | medium |
| Melee speed / reach | → `MELEEATTACK_SPEED`; → `MELEE_TRAVEL_DISTANCE_PERCENTAGE` 50/60/150; `LightMeleeCooldownMult` 1.5/2 | % | swing rate / lunge distance | additive (inferred) | — | data | low |
| Parry cooldown | → `PARRY_COOLDOWN_REDUCTION_FIXED` 1.75 s | s | parry cooldown | flat subtraction | ≥ 0 | data | medium |

### Misc

| Stat | API key(s) → channel | Units | Applies to | Stacking | Floor/cap | Evidence | Conf |
|---|---|---|---|---|---|---|---|
| Souls/min | `StackingGoldPerMinute` 16, `BonusGoldPerMinute` 80, `BonusSoulsPct` 170: **no channel**, item-scripted | souls/min, % | income | flat | — | data; economy.md | medium |
| Respawn time | → `RESPAWN_TIME_PERCENTAGE` −70, `RESPAWN_TIME_ADDITIVE` | %, s | respawn timer (combat §15) | unknown | — | data | low |
| Build-up rate | hero `proc_build_up_rate_scale` 1; `EBuildUpRate`/`EProcBuildUpRateScale` scale types | × | proc build-up items | product (inferred) | — | data | low |
| Non-stats | `ANIMATION_FRAME_SKIP_RATE` (Cursed Relic), `MATERIAL_OVERRIDE`, `INVALID` | — | cosmetic / sentinel | ignore | — | data | high |

**Catalogue totals.**
- All 95 channels are named in the tables above (checked by script against the API).
- Also catalogued: 119 shop key/channel pairs and 23 hero `starting_stats` keys.
- About 218 channel-less mechanic keys on shop items are *not* stats. Examples: proc chances, radii, durations, and `HeadShotBonusDamage`.

---

## Values

### Hero `starting_stats` (community-datamine, 2026-09-27, high; per-hero values are in combat.md's hero table)

| Key | Range (38 heroes) | Panel stat | Note |
|---|---|---|---|
| `max_health` | 660 – 930 | EMaxHealth | before boons and vitality % |
| `base_health_regen` | 1.0 – 3.5 | EBaseHealthRegen | |
| `max_move_speed` | 6.2 – 8.2 m/s | EMaxMoveSpeed | |
| `sprint_speed` | 1.0 – 4.0 (mode 1.6) | ESprintSpeed | |
| `crouch_speed` / `move_acceleration` | 4.75 / 4 | — | |
| `light_melee_damage` / `heavy_melee_damage` | 42–63 / 116–128 | ELight/EHeavyMeleeDamage | |
| `stamina` | 2 – 4 | EStamina | |
| `stamina_regen_per_second` | 0.1667 – 0.2381 (mode 0.2222) | EStaminaCooldown = 1/rate | |
| `ground_dash_distance_in_meters` / `_duration` | 10 / 0.62–0.72 | EDashSpeedInMeters | |
| `air_dash_distance_in_meters` / `_duration` | 8 / 0.43–0.51 | | |
| `reload_speed` | 1 | EReloadSpeed | a speed multiplier base (see Open question 1) |
| `tech_duration`, `tech_range` | 1 | — | multiplier bases |
| `weapon_power`, `weapon_power_scale` | 0, 1 | — | legacy |
| `proc_build_up_rate_scale` | 1 | — | |
| `crit_damage_received_scale` | 0.45 – 1 | ECritDamageReceivedScale | |
| `ability_resource_max` / `_regen_per_second` | 0 | — | unused |

Weapon base stats (`bullet_damage`, `cycle_time`, `clip_size`, `reload_duration`, `bullet_speed`, falloff ranges, `crit_bonus_start/end` 1.65) live on the hero's weapon entry in the items API (86 weapon entries). They are catalogued in combat.md §2 and are the bases for the weapon rows above.

### Global

- `item_price_per_tier`: 0 / 800 / 1600 / 3200 / 6400 / 9999 (generic-data, community-datamine 2026-09-27, high).
- `max_purchases_for_tier`: [6, 6, 6] per category (heroes API; meaning unverified).
- The shop groups in generic-data (`weapon_groups`, `armor_groups`, `spirit_groups`: EMagazines, ERateOfFire, EBulletVelocity, EMoreHealth, EHealing, EDebuffs, EMoreSpirit, ECooldown, and others) are shop UI categories, **not** stacking groups. There is no evidence of "unique"-group non-stacking between different items. The one documented exception is heal reduction, where the same source does not stack (combat §8).

---

## Open questions (measurable in a private lobby with the public console only)

1. **Reload stacking and direction.** The key `ReloadSpeedMultipler` and the panel stats EReloadTime/EReloadSpeed suggest a speed multiplier. The label and the negative values suggest a time %.
   - *Measure:* time a full reload with and without Spellslinger (−10%) on a slow-reload hero.
   - Additive and multiplicative stacking cannot be distinguished with one shop source.
2. **Clip formula order and rounding.** The wiki gives `(base + flat) × (1 + %)`, rounded up.
   - *Measure:* Haze (SP-flat clip) with Extended Magazine +30%. Compare the HUD clip to `ceil((base + 0.5·SP) × 1.3)` against `ceil(base × 1.3) + 0.5·SP`.
3. **Vitality % starting value.** The wiki says 8%, `cost_bonuses` says 9%, and tier-1 `purchase_bonuses` says 7%.
   - *Measure:* buy one 800 vitality item with no HP line (e.g. an 800-cost vitality item without BonusHealth) and read EMaxHealth.
   - This also settles whether `purchase_bonuses` is live.
4. **Debuff resist stacking.** Stack two sources (e.g. 20% + 40%) against a timed slow. Expect 0.52 duration if additive, 0.48 if multiplicative.
5. **Stamina recovery formula.** With Extra Stamina (+12%), time bar regen. Expect 4.5/1.12 = 4.02 s for the rate model, 3.96 s for time × (1 − r) (movement.md Open question 18).
6. **Max-HP change and current HP.** Buy a +HP item at partial HP and check whether current HP rises by the same amount or keeps the same fraction.
7. **Glass Cannon's −13% max HP.** Is it applied after the flat HP or inside the vitality % pool? Compare EMaxHealth before and after with known flat HP.
8. **Melee % pool.** Is `MELEE_DAMAGE_INCREASE` in the same additive pool as 50% of weapon %, or a separate multiplier? *Measure:* heavy melee a bot with 0, one, and both kinds.
9. **Hidden properties.**
   - Does Improved Spirit (`upgrade_soaring_spirit`) actually give +75 HP? Read EMaxHealth.
   - Do range items silently enlarge AoE radius? Measure an AoE edge against a bot.
10. **Move-speed %** (`MOVEMENT_SPEED_MAX_PERCENT`): is it converted to m/s before the K = 12 diminishing returns? This is ability-only, so measure it with a hero buff.

---

## Implementation notes for Godot 4

**`StatSheet` (Resource or RefCounted, one per unit).**

```gdscript
enum Kind { FLAT, ADD_PCT, MULT_STACK, PRODUCT }
# channel -> Kind table generated from this spec (StringName keys = API channel names without the prefix)
var _mods := {}          # channel -> Array[Modifier]  (Modifier: value, source_id, scope, stack_key)
var _cache := {}         # derived stat -> float
var _dirty := true
signal stat_changed(stat: StringName, old: float, new: float)

func add_mod(channel, value, source_id, scope := &"all", stack_key := &""): ...; _dirty = true
func remove_source(source_id): ...; _dirty = true     # item sold / buff expired
func channel_total(channel, ctx := {}) -> float:     # applies Kind: sum | sum | 1-Π(1-x) | Π(1+x)
func get_stat(stat: StringName, ctx := {}) -> float  # derived stats (§4 pseudocode), recompute if dirty
```

- **Channels.**
  - `flat`: sum.
  - `additive_pct`: `1 + Σ`.
  - `mult_stack`: `1 − Π(1 − x)`.
  - `product`: `Π(1 + x)`.

  The special compositions are functions in `get_stat`, not channel kinds: move speed diminishing returns, fire-rate bonus minus slow, and resist minus shred.
- **Recompute on change.** Mark the sheet dirty on add or remove. Recompute derived stats lazily on the next read, or eagerly at the end of the frame, and emit `stat_changed` only for values that changed.
  - When max HP changes, apply the policy chosen in Open question 6.
  - When clip size changes mid-magazine, clamp the current ammo.
- **Stack keys.** Modifiers with the same `stack_key` from the same source kind take the max rather than stacking. Heal reduction needs this (combat §8). Everything else stacks, including duplicate effects from different items.
- **Scopes.** Contextual reads, such as a charged ability, imbued ability, ultimate, vs-NPC target or a 15 m distance gate, pass `ctx`. Unscoped modifiers always count.
- **Importer.** `tools/deadlock_data` should emit `data/reference/stat_channels.csv` (key, channel, kind, section, flags). Rules:
  - Skip zeros and `INVALID`.
  - Treat `innate` or no-section non-conditional properties as always-on.
  - Leave `ConditionallyApplied` properties to the item script.
  - Resolve `scale_function` at read time. Never bake SP into item values.

**Who reads what.**

| Subsystem | Reads |
|---|---|
| Weapon (combat §2) | bullet damage, cycle time (fire rate), clip, reload time, bullet speed, falloff ranges, crit bonus, lifesteal; `EReloadSpeed` for wind-ups |
| Damage resolver (combat §1) | attacker amps and shred; target resists, crit-received, barrier; healing effectiveness and heal penalties |
| Health component | max HP, base regen, OOC regen, heal amp regen/receive |
| Ability system (abilities.md) | SP, `ETechCooldown` (plus ult/charged), `ETechDuration`, `ETechRange`, `ETechRadius`, charges, charge cooldown, spirit lifesteal |
| Item actives | `EItemCooldown`, duration, range (active items use ability range and duration) |
| Movement controller (movement.md) | move speed (diminishing returns), sprint, stamina count/rate, dash and air distance, air control, slide, shoot/zoom penalty, slows and slow resist, gravity |
| CC system (combat §10) | debuff resist (duration), slow resist |
| HUD / shop panel | the display lists in §8, reading derived values only |

Keep tests minimal and loose, per the project convention. A small set of formula checks is enough: clip `(20 + 10) × 1.19 → 36`; CDR 20% + 5% → 24%; duration 15% + 15% → 27.75%; move bonuses 2 + 3 → 4.5 m/s; fire rate +38%, −25%, −28% → −8%.

---

## Sources

1. deadlock-api.com assets API, `/v1/assets/items` (726 entries; cached `tools/deadlock_data/cache/items__1bf2796963.json`). Community-datamine, fetched 2026-09-27. Data: deadlock-api.com.
2. deadlock-api.com `/v1/assets/heroes` (38 heroes; `heroes__6110121f2b.json`): starting_stats, standard_level_up_upgrades, scaling_stats, cost_bonuses, purchase_bonuses, shop_stat_display, stats_display. Fetched 2026-09-27.
3. deadlock-api.com `/v1/assets/generic-data` (`generic_data__54d9824aed.json`): item_price_per_tier, shop groups. Fetched 2026-09-27.
4. deadlock.wiki pages fetched 2026-09-29. All resolved:
   - Stats (overview only, no formulas), Items, Weapon_Damage, Fire_Rate, Ammo, Reload (no formula), Spirit_Power.
   - Cooldown_Reduction (served the Ability Cooldown content), Health, Health_Regen, Bullet_Resist (served the Damage Resistance content), Spirit_Resist.
   - Move_Speed, Sprint_Speed, Stamina, Bullet_Velocity, Damage_Amplification, Debuff_Resist, Healing, Ability_Range, Ability_Duration.
   - CC BY-NC-SA; facts paraphrased.
5. Official patch notes as already cited in combat.md, abilities.md and movement.md: sprint delay 3 s (2025-12-16), stamina cooldown 4.5 s (2025-12-16), item CDR separated (2025-07-04), barrier merge (2025-05-08), and the latest general notes of 2026-09-16.
6. Cross-referenced specs: combat.md, abilities.md, movement.md, economy.md, _data_sources.md.

---

## Verification log (2026-09-29)

Each claim was checked against a second, independent source.

| # | Claim | Source A | Source B | Result |
|---|---|---|---|---|
| 1 | MaxHP = (base + boons·per) × (1 + vit%) + flat | wiki Health | combat §7; API channel split `BASE_HEALTH_PERCENT` vs `HEALTH_MAX` | Confirmed. The wiki adds display round-up. |
| 2 | Clip = (base + flat) × (1 + Σ%), rounded up | wiki Ammo | API: separate `AMMO_CLIP_SIZE` / `_PERCENT` channels (order not in data) | Partly confirmed. **The draft order (flat after %) was corrected to the wiki's order.** |
| 3 | Fire rate: bonuses additive, slows `mult_stack`, −50% floor, asymmetric | wiki Fire Rate | combat §12 | Confirmed. |
| 4 | CDR = 1 − Π(1 − r), no cap; item CDR separate | wiki Ability Cooldown | abilities M10; API separate `ITEM_COOLDOWN_REDUCTION_PERCENTAGE` and `EItemCooldown` scale | Confirmed. |
| 5 | Duration and range use `1 − Π` | wiki Ability Duration / Ability Range | abilities M11 (examples 27.8%, 37%) | Confirmed. Radius as `1 − Π` is inferred only. |
| 6 | SP = flat sum × Π(1 + %) | wiki Spirit Power | abilities M9; API `TECH_POWER` vs `TECH_POWER_PERCENT` | Confirmed. |
| 7 | Flat weapon damage is added after the weapon % | wiki Weapon Damage | API channel name `FLAT_BULLET_DAMAGE_POST_SCALE`; combat §16 | Confirmed. |
| 8 | Move bonus DR with K = 12 m/s; sprint additive | wiki Move Speed, Sprint Speed | movement §3–4 | Confirmed. The wiki's 5 s sprint delay contradicts the official 3 s; the official value is kept. |
| 9 | Resists `1 − Π`; shred `1 − Π` then subtracted; may be negative; bullet resist also covers melee | wiki Damage Resistance, Spirit Resist | combat §5; API `BULLET_AND_MELEE_RESIST_REDUCTION` | Confirmed. |
| 10 | Investment bonuses: per-category spend thresholds to 28,800, feeding the item channels | wiki Items (28.8k cap, 4.8k spike) | API `cost_bonuses`; `purchase_bonuses` channel names | Confirmed for thresholds. **Contradiction:** wiki Health says the vitality bonus starts at 8% vs API 9% (Open question 3). |

Additional contradictions noted, and **not** resolved here:
- **Debuff resist stacking.** combat §10 chose multiplicative, while the wiki page reads as additive (Open question 4).
- **Stamina cooldown.** The wiki says about 5 s, the API mode is 4.5 s; movement.md already marks the wiki as stale.
- **Improved Spirit's hidden +75 HP.** The API has it and the wiki omits it (economy.md flag; Open question 9).
- **Spirit lifesteal vs non-heroes.** combat §9 gives 40%, while the API tooltip key gives 3 vs 13 hero (≈23%).
