# Abilities Spec

> Clean-room observation record. Describes observed behavior of Deadlock (Valve) for the purpose of independent reimplementation. No game code or assets were used.

## Summary

- Every hero has **4 ability slots**: 3 regular abilities (slots 1–3) and 1 **ultimate** (slot 4). Some abilities are fully or partly **passive**.
- Progression uses **souls**. Crossing total-soul thresholds grants **boon levels** (max 35, reached at 49,200 souls under the 2026-06-30 curve).
  - Each level grants either an **ability unlock** (levels 0, 2, 4 and 7, where level 7 is the ultimate) or **1 Ability Point (AP)**. All other levels grant 1 AP, for 32 AP in total.
  - Each level also grants fixed per-hero stat growth: base bullet damage, base HP, melee damage and spirit power.
- Each ability has **3 upgrade tiers costing 1, 2 and 5 AP** (8 AP per ability, 32 AP to max all four). This exactly matches the 32 AP available.
- Ability values scale linearly: `value = base + Σ(coef_i × stat_i)`. The stat is usually Spirit Power, but can also be boon count, melee damage, weapon damage, or the global duration, range or cooldown multipliers.
- **Ability Cooldown Reduction** stacks multiplicatively: `1 − Π(1 − r_i)`. Since 2025-07-04 it affects abilities only; items use a separate "Item Cooldown Reduction" stat.
- Ability types (behaviors), which can be combined:
  - instant cast, with optional recast
  - channeled
  - toggle
  - charged (per-charge restore timer plus a "time between charges" lockout)
  - passive
- Current hero base stats come from the community-datamined wiki `Data:HeroData.json` and the Hero Comparison Table (data edited 2026-09-16).
- Heroes use 4 archetype tags (Marksman, Assassin, Brawler, Mystic). The newest heroes are untagged.
- Legal data-analysis route: the public REST API `api.deadlock-api.com` has match analytics (ability upgrade order win-rates, soul curves, hero and item stats) and needs no game files. See the Godot notes, section "Legal data pipeline".

## Mechanics

### M1. Ability slots and unlocks
- Slots 1, 2 and 3 are regular abilities; slot 4 is the ultimate.
- At level 0 (600 souls, the starting amount) the player picks 1 regular ability to unlock.
- Further unlocks come at levels 2 (1,100 souls) and 4 (2,000 souls). The ultimate becomes unlockable only at level 7 (3,800 souls) under the 2026-06-30 curve; it was level 6 before.
- The first three unlocks can go to any regular abilities in any order. The ultimate can only take the level-7 unlock.
- Unlocks cannot be refunded.
- Passive abilities occupy a slot and still need an unlock and upgrades.
- Some abilities mix a passive buildup with an active trigger ("partial passives").

### M2. Boon levels (soul thresholds)
- Level `L` is reached when total earned souls ≥ `threshold[L]` (see the Values table, level rows). Thresholds are cumulative.
- The API stores them relative to the 600 starting souls (`0, 200, 500, 900 … 48600`).
- Each level grants:
  - unlock or AP, as in M1/M3
  - `+Δ` base bullet damage per bullet
  - `+Δ` max HP
  - `+Δ` light melee (and a separate heavy-melee delta)
  - `+Δ` spirit power (usually 1.1)
  - `BOON_COUNT +1`, which is used by boon-scaled abilities
  - Dynamo also gains bullet resist per boon.
- After level 35 the HUD reportedly keeps counting overflow "levels", but no stats, AP or unlocks are granted. Confidence low: the souls per post-max level is not sourced publicly; measure it (Open question 9).
- If unsecured souls are lost (e.g., on death) after a threshold was crossed, the level is kept; only progress toward the next level drops.
- Edge case: one large soul gain can cross several thresholds. Grant every level crossed, in order.

### M3. Ability points and upgrade tiers
- AP comes from every level that is not an unlock level: 32 AP across levels 1–35.
- Upgrade tier costs are T1 = 1 AP, T2 = 2 AP and T3 = 5 AP. Tiers must be bought in order (T1 → T2 → T3), and the ability must be unlocked first.
- AP can be banked. There are no per-level caps on how far an ability can be upgraded.
- Refund: an upgrade can be undone within 10 s of purchase, as long as no ability was cast in that window.
- Each tier is an **additive delta** on one or more ability properties, e.g. `AbilityCooldown −12`, `+1 AbilityCharges`, `Damage +100`, or `StunDuration +0.8`. A tier can also add a new scale term, e.g. `DPS +18 + 0.12×SP`.
- Tier content counts across all 176 abilities in the data. These counts were aggregated by the spec writer from the community-datamined wiki JSON [15]. They were not independently re-verified (confidence low); use them only as rough guidance:
  - T1 reduces cooldown in 56 abilities, T2 in 62 and T3 in 39.
  - T1 adds charges in 10 abilities, T2 in 7 and T3 in 9.
  - Over all tiers, `AbilityCooldown` is the most common upgraded key (291), followed by `Damage` (74), `AbilityDuration` (46) and `AbilityCharges` (34).

### M4. Ability type: instant cast (with optional recast)
- State machine: `READY → (press) → CAST_DELAY (AbilityCastDelay, e.g. 0.1 s) → EFFECT → COOLDOWN → READY`.
- Casting is blocked while stunned, silenced or displaced (knocked up, pulled). Abilities flagged "not silencable" ignore silence.
- Abilities flagged "castable while busy" can be cast during other actions, such as reloading or another channel.
- Recast abilities: the first cast opens a recast window. The cooldown **starts on the first cast**, not on the recast.
- Since 2026-01-22, cancelling a **channeled** ability during its cast delay still puts it on cooldown. The patch named specific heroes (Bebop, Grey Talon, Haze, Mo & Krill); it did not describe a general rule for instant casts. (Corrected 2026-09-27: the claim was previously stated as general for all instant casts.)

### M5. Ability type: channeled
- State machine: `READY → CAST_DELAY → CHANNELING (AbilityChannelTime) → END → COOLDOWN`.
- Interrupts:
  - **Stun** and hard interrupts end the channel.
  - **Silence** and **displacement** do NOT end a channel already in progress.
  - Jump is the default self-cancel input. Some channels cannot be cancelled by the player.
- The cooldown usually starts on press. Abilities flagged "cooldown on channel end" start it when the channel ends instead (observed examples: a sleep-dagger, a charged bolt, a slam).
- Some channels refund cooldown when interrupted: **50%** for some, **100%** for at least one.
- Move speed during a channel is set per ability (from 0 up to full).
- A "holds at max channel" variant stays at the max-power state until released.

### M6. Ability type: toggle
- `OFF ↔ ON`. While ON, the effect runs continuously (e.g., an aura).
- Some toggles start their cooldown on toggle **off** (flag: start cooldown on toggle off). The rest start it on toggle on.
- Being stunned or silenced while ON is a hero-specific question. See Open questions.

### M7. Ability type: charges
- Properties: `max_charges`, `charge_restore_time` (equal to the ability cooldown, so it is reduced by CDR) and `time_between_charges` (a short lockout after each use).
- Algorithm:
  - Using a charge sets `lockout = time_between_charges`.
  - If `charges < max_charges` and no restore timer is running, a restore timer starts with length `cooldown × (1 − CDR)`.
  - When the timer completes: `charges += 1`, and the timer restarts if still below max. Charges restore **one at a time**, never in parallel.
- `time_between_charges` is NOT reduced by ability CDR. Only "faster time between charges" item stats reduce it, as a percentage.
- Bonus charges from items (+1 or +2) apply only to abilities that already have charges.
  - Exception: a **Legendary, Street-Brawl-only** "omni-charge" item grants +2 charges to non-charged abilities, turning them into charged abilities. (Corrected 2026-09-27: it was previously described as a tier-5 item costing 9,999. The wiki lists it as Legendary with no soul cost.)
- Charge-refill effects: "echo" restores one charge (or ends the cooldown of the imbued ability); "refresher" restores all charges and all cooldowns.

### M8. Ability type: passive
- The effect is always on after unlock and cannot be turned off.
- Upgrades still apply.
- Most item imbues cannot target passives. Duration and range/radius imbues are the exceptions.

### M9. Spirit Power (SP) scaling
- `scaled = base + coef_SP × SP_total`. Linear, with no soft cap or diminishing returns observed.
- Tooltip coefficients are shown rounded to 0.1. Data values can be finer, e.g. 0.975 or 0.66.
- `SP_total = (base_SP_from_boons + Σ flat_SP) × Π(1 + pct_i)`. Flat bonuses add; percentage bonuses multiply each other and apply to the current total.
- There is also a **spirit investment bonus** (flat SP by souls spent on spirit items, tiered). It is recorded here only as context; it belongs to the items spec.
- Other scale types appear in ability data. The counts below were aggregated from [15] and not re-verified (confidence low). Counts of scaled properties: cooldown 308, duration 305, spirit 284, range 211, radius 70, max_charges 41, charge_cooldown 41, healing 23, boon/power_increase 14, melee 11, weapon_damage_increase 6, heavy_melee 3, weapon_damage 2, weapon_power 2.
- A property can have several scale terms, e.g. a duration with `base 3.5 + 0.03×SP` that is then multiplied by the ability-duration stat.

### M10. Cooldown and cooldown reduction
- `effective_cd = base_cd_after_upgrades × (1 − CDR_total)`, where `CDR_total = 1 − Π(1 − r_i)`.
  - Example: 20% + 5% gives 24%, not 25%.
- No cap is documented. Multiplicative stacking approaches 100% only asymptotically.
- Ability CDR does not affect items (since 2025-07-04). Item cooldown reduction is a separate stat. One tier-4 item gives both.
- Ultimate-only CDR exists (e.g. 10% from one armor item). Charged-ability-only CDR exists on charge items.
- The powerup "casting" buff grants temporary CDR.
- The HUD shows decimals only when the remaining time is under 2 s. This is a UI detail.
- Some effects shorten current cooldowns directly: one item reduces all ability cooldowns by 20% when it triggers. Implement this as `remaining *= 0.8`.

### M11. Duration and range multipliers
- `tech_duration` and `tech_range` both start at 1.0.
- Items add percentages. The wiki's Ability Duration and Ability Range pages (checked 2026-09-27) both state that the bonuses stack like CDR, `total_bonus = 1 − Π(1 − x_i)`, and apply it as `value × (1 + total_bonus)`. Their worked examples are 15% + 15% = 27.8% (duration) and 30% + 10% = 37% (range).
  - Corrected 2026-09-27: the earlier "12 m × 1.35 = 16.2 m" example could not be found on the current range page and has been removed.
  - Use the wiki formula as the default. It is still worth confirming in game (see Open question 1).
- Only properties whose data carries a `duration` or `range` scale term are affected.

### M12. Imbue
- Some items target one chosen ability (the imbue). The target can only be changed by selling and rebuying the item.
- Imbues cannot target passives, except the duration and range imbues.

### M13. Crowd control that interacts with abilities (summary)
- Stun: blocks casting and ends channels. Since 2026-09-16 it also pauses reload.
- Silence: blocks casting but does not end a running channel.
- Displacement (knockup or pull): blocks casting but does not end a channel. Since 2026-05-22 knockup duration is reduced by debuff reduction.
- Slows: all move slows were reduced by about 20% on 2026-09-16.

## Values

Abbreviations for Source type:
- **dm** = community-datamine (wiki Data:*.json or the deadlock-api assets API, both generated by the community from game data; not produced by this project)
- **wiki**
- **off** = official patch notes
- **inf** = inferred

Numbers in brackets refer to the Sources list.

### Progression

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Ability slots | 3 + 1 ultimate | slots | wiki | 2026-09 | high | [2] |
| Starting souls (level 0) | 600 | souls | dm + wiki | 2026-06-30 | high | [1][30] |
| Max boon level | 35 | level | dm + wiki | 2026-06-30 | high | [1][18] |
| Souls at max level | 49,200 | souls | dm + wiki | 2026-06-30 | high | [1][30] |
| Level thresholds L0–L9 | 600, 800, 1100, 1500, 2000, 2600, 3200, 3800, 4500, 5200 | total souls | dm + wiki | 2026-06-30 | high | [1][30] |
| Level thresholds L10–L19 | 5900, 6600, 7400, 8200, 9000, 9800, 10700, 11600, 12500, 13400 | total souls | dm + wiki | 2026-06-30 | high | [1][30] |
| Level thresholds L20–L29 | 14400, 15500, 16700, 18000, 19500, 21200, 23100, 25200, 27500, 30000 | total souls | dm + wiki | 2026-06-30 | high | [1][30] |
| Level thresholds L30–L35 | 32700, 35600, 38700, 42000, 45500, 49200 | total souls | dm + wiki | 2026-06-30 | high | [1][30] |
| Unlock levels | 0, 2, 4, 7 (7 = ultimate) | level | off + wiki | 2026-06-30 | high | [18][19][1] |
| Ultimate unlock souls | 3,800 | souls | inf (from thresholds) | 2026-06-30 | high | [1] |
| Previous ultimate unlock level | 6 | level | off | before 2026-06-30 | medium | [18] |
| Total AP | 32 | AP | wiki + inf | 2026-06-30 | high | [1] |
| Cumulative AP milestones | 1 @ 800, 2 @ 1500, 3 @ 2600, 4 @ 3200, 5 @ 4500 | AP @ souls | inf | 2026-06-30 | high | [1] |
| Upgrade tier costs | 1 / 2 / 5 | AP | wiki | 2026-09 | high | [2][1] |
| AP to max one ability | 8 | AP | inf | 2026-09 | high | [2] |
| Upgrade refund window | 10 | s | wiki | 2026-09 | medium | [2] |
| Unlock refundable | no | — | wiki | 2026-09 | medium | [1] |
| Total AP earlier (for history) | 29 (reduced from 32) | AP | off | 2025-06-17 | medium | [29] |

### Per-boon stat gains

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Spirit power per boon (default) | 1.1 | SP/level | dm | 2026-09-16 | high | [16][30] |
| SP per boon: Grey Talon | 1.6 | SP/level | dm | 2026-09-16 | high | [16] |
| SP per boon: Haze | 0.5 | SP/level | dm | 2026-09-16 | high | [16] |
| SP per boon: Ivy | 1.2 | SP/level | dm | 2026-09-16 | medium (the wiki Spirit Power page only gives 1.2–1.3 for this group) | [16][3] |
| SP per boon: Kelvin, Sinclair, Viscous | 1.3 | SP/level | dm | 2026-09-16 | medium (the wiki Spirit Power page gives 1.2–1.3, i.e. 42–45.5 SP at max, without a per-hero split) | [16][3] |
| Light melee per boon (default) | 1.58 | dmg/level | dm | 2026-09-16 | high | [16][30] |
| Light melee per boon: Abrams / Venator / Paige | 1.74 / 1.70 / 1.20 | dmg/level | dm | 2026-09-16 | medium | [16] |
| Heavy melee base (most heroes) | 116 | dmg | dm | 2026-09-16 | high | [16] |
| Heavy melee per boon (range) | 2.91–4.25 | dmg/level | dm | 2026-09-16 | medium | [16] |
| Infernus per-boon package | bullet 0.088, HP 39, melee 1.58, SP 1.1 | per level | dm | 2026-09 | high | [30] |
| Health per boon change | −5% | % | off | 2026-06-30 | high | [18][19] |
| Health per boon change | −3 | HP/level | off | 2026-05-22 | high | [22][23] |
| Base HP change | −10 | HP | off | 2026-05-22 | high | [22][23] |
| Health per boon change | −7 | HP/level | off | 2026-04-30 | high | [20][21] |

### Hero base stats (level 0)

Column formats:
- **HP**: `base + per_boon`
- **Bullet**: `base + per_boon` per bullet, with ×N where the shot fires several pellets or a burst
- **Speed**: move speed in m/s
- **Sprint**: sprint bonus in m/s
- **Stamina**: number of stamina bars

All rows: source type dm/wiki, data dated 2026-09-16, confidence high, sources [7][16].

| Hero | Archetype | HP | Regen HP/s | Bullet | Ammo | Speed | Sprint | Stamina | Dash speed m/s |
|---|---|---|---|---|---|---|---|---|---|
| Abrams | Brawler | 800+49 | 1.5 | 3.6+0.1 ×9 | 9 | 6.4 | 1.6 | 3 | 13.9 |
| Bebop | Brawler | 880+52 | 2.5 | 4.98+0.115 | 66 | 6.45 | 4 | 3 | 13.9 |
| Dynamo | Mystic | 880+61 | 1.75 | 12.6+0.5 | 20 | 6.7 | 1.6 | 3 | 13.9 |
| Grey Talon | Marksman | 780+38 | 1.5 | 23.51+0.85 | 17 | 6.3 | 1.6 | 4 | 16.1 |
| Haze | Assassin | 730+33 | 2 | 5.26+0.143 | 25 | 8.2 | 1.6 | 3 | 16.1 |
| Infernus | Marksman | 830+39 | 2 | 5.5+0.088 | 27 | 6.7 | 1.6 | 3 | 14.7 |
| Kelvin | Brawler | 880+60 | 1 | 18.6+0.418 | 14 | 6.7 | 1.1 | 3 | 13.9 |
| Lady Geist | Mystic | 880+51 | 1 | 20.7+1 | 9 | 6.3 | 2.4 | 3 | 13.9 |
| Lash | Assassin | 780+50 | 2 | 8.46+0.31 ×3 burst | 29 | 7.2 | 2.1 | 3 | 14.7 |
| McGinnis | Mystic | 780+52 | 2 | 6.08+0.171 | 66 | 6.7 | 1.6 | 2 | 14.7 |
| Mo & Krill | Brawler | 930+65 | 1 | 2.82+0.0847 ×4 | 20 | 8 | 1.6 | 3 | 13.9 |
| Paradox | Marksman | 730+46 | 1 | 6.8+0.26 ×5 burst | 40 | 6.7 | 1.6 | 3 | 16.1 |
| Pocket | Assassin | 780+36 | 1 | 4.28+0.14 ×7 | 11 | 7.2 | 1.6 | 3 | 14.7 |
| Seven | Mystic | 730+41 | 1 | 10.8+0.24 ×3 | 29 | 6.7 | 1.8 | 3 | 14.7 |
| Shiv | Brawler | 830+46 | 2 | 4.8+0.165 ×6 | 10 | 6.5 | 1.6 | 3 | 13.9 |
| Vindicta | Marksman | 755+28 | 2 | 12.33+0.495 | 19 | 7.9 | 1.6 | 2 | 14.7 |
| Viscous | Mystic | 780+45 | 2 | 10.34+0.36 | 20 | 7.2 | 1.6 | 3 | 14.7 |
| Warden | Brawler | 805+60 | 2 | 17.34+0.25 | 17 | 6.3 | 1.6 | 3 | 14.7 |
| Wraith | Marksman | 730+35 | 2 | 5.64+0.14 | 52 | 7.2 | 1.6 | 3 | 14.7 |
| Yamato | Assassin | 730+45 | 1 | 5.31+0.154 ×5 | 12 | 8.2 | 1.6 | 3 | 14.7 |

The full 38-hero table is available in [7]. Ranges across all heroes:
- HP: 660–930 base, +27 to +65 per boon
- Regen: 1–3.5 HP/s
- Move speed: 6.2–8.2 m/s

### Archetypes and generic hero parameters

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Archetype counts | Marksman 13, Assassin 9, Brawler 8, Mystic 8, untyped 6 | heroes | dm | 2026-09-16 | medium | [16] |
| Brawler profile (inferred) | HP 800–930, +49–65/boon, speed 6.3–8.0, dash 13.9 | mixed | inf | 2026-09 | medium | [7] |
| Marksman profile (inferred) | HP 660–830, +27–46/boon, dash 14.7–16.1, often 4 stamina | mixed | inf | 2026-09 | medium | [7] |
| Assassin profile (inferred) | HP 730–780, speed 6.8–8.2 | mixed | inf | 2026-09 | medium | [7] |
| Mystic profile (inferred) | HP 680–880, high bullet/boon on single-shot guns | mixed | inf | 2026-09 | low | [7] |
| Stamina restore per bar (default) | 4.5 | s | dm | 2026-09-16 | high | [16][6] |
| Stamina restore, wiki prose (stale) | 5 | s | wiki | older | low | [6] |
| Dash distance, ground / air | 10 / 8 | m | wiki | 2026-09 | high (checked on the Stamina page) | [6][24] |
| Dash bucket 1: ground / air speed | 16.1 / 18.6 (0.62 / 0.43 s) | m/s | wiki | 2026-07-28 | low (the cited Movement page does not contain these numbers; the ground speed matches the Hero Comparison Table dash column) | [13][7] |
| Dash bucket 2: ground / air speed | 14.7 / 17.0 (0.68 / 0.47 s) | m/s | wiki | 2026-07-28 | low (as bucket 1) | [13][7] |
| Dash bucket 3: ground / air speed | 13.9 / 15.7 (0.72 / 0.51 s) | m/s | wiki | 2026-07-28 | low (as bucket 1) | [13][7] |
| Crouch speed | 4.75 | m/s | dm | 2026-09-16 | medium | [16] |
| Move acceleration | 4.0 | (engine units) | dm | 2026-09-16 | low | [16] |
| Base tech_duration / tech_range multipliers | 1.0 / 1.0 | multiplier | dm | 2026-09-16 | high | [16] |
| Wall-jump stamina regen penalty | −25% for 5 s | %, s | off | 2026-05-22 | medium | [22] |
| Length unit conversion | 1 unit ≈ 0.0254 | m | wiki | — | high | [13] |

### Ability timing and cooldowns

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Slot 1 cooldown min / median / max (n=38) | 0.6 / 23 / 42 | s | dm (aggregated) | 2026-09-16 | medium | [15] |
| Slot 2 cooldown min / median / max (n=39) | 13 / 34 / 50 | s | dm (aggregated) | 2026-09-16 | medium | [15] |
| Slot 3 cooldown min / median / max (n=31) | 2 / 28 / 50 | s | dm (aggregated) | 2026-09-16 | medium | [15] |
| Ultimate cooldown min / median / max (n=39) | 55 / 150 / 250 | s | dm (aggregated) | 2026-09-16 | medium | [15] |
| Ultimate cooldowns change | +10% | % | off | 2025-07-04 | high | [28] |
| Ultimate cooldowns change (base and upgrades) | +15%, rounded to the nearest 5 s | % | off | 2026-06-30 | high | [18][19] |
| Ability base and AP damage change | −8% | % | off | 2025-07-04 | high | [28] |
| Typical cast delay | 0.1 | s | dm | 2026-09 | medium | [15] |
| Channel interrupt refund (partial) | 50 | % of cd | wiki | 2026-09 | low (not found on the current Abilities page; that page says silence or displacement does not affect the cooldown) | [2] |
| Channel interrupt refund (full, rare) | 100 | % of cd | wiki | 2026-09 | low (not found on the current Abilities page) | [2] |
| Cast-delay cancel avoids cooldown (channeled abilities) | no (removed for named channeled abilities) | — | off | 2026-01-22 | high | [27] |

### Worked example: fire-themed Marksman kit (Infernus-like reference values)

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Slot 1 cooldown / charges / between-charge time | 25 / 1 / 6 | s / count / s | dm | 2026-09-16 | high | [15] |
| Slot 1 damage | 40 + 0.6×SP | dmg | dm | 2026-09-16 | high | [15] |
| Slot 1 upgrades | T1 +1 charge; T2 15% lifesteal; T3 +17% dmg amp, −33% healing | — | dm | 2026-09-16 | high | [15] |
| Slot 2 cooldown / duration | 38 / 3 | s | dm | 2026-09-16 | high | [15] |
| Slot 2 DPS | 30 + 0.7×SP | dmg/s | dm | 2026-09-16 | high | [15] |
| Slot 2 upgrades | T1 −12 s cd; T2 +20 DPS, +1 s; T3 +2 charges, 14 s between charges | — | dm | 2026-09-16 | high | [15] |
| Slot 3 (passive burn) DPS | 14 + 0.66×SP | dmg/s | dm | 2026-09-16 | high | [15] |
| Ultimate cooldown | 190 | s | dm | 2026-09-16 | high | [15] |
| Ultimate damage / stun / radius | 125 + 0.975×SP / 1.25 / 12 | dmg / s / m | dm | 2026-09-16 | high | [15] |
| Ultimate upgrades | T1 +100 dmg; T2 −65 s cd; T3 +0.9 s stun, +10 radius | — | dm | 2026-09-16 | high | [15] |
| Brawler slot 1 (lifedrain-like) | cd 42, dur 4, DPS 22 + 0.6×SP; T1 −20 cd, T2 +2 s, T3 +18 + 0.12×SP DPS and +2 m radius | s, dmg/s | dm + wiki | 2026-09-16 | high | [15][33] |
| Brawler slot 2 (charge-like) | cd 33, dur 1.4, dmg 30 + 1.4×SP; T1 32% slow 3 s, T2 0.8 s stun on wall hit, T3 −18 cd and +1.5 weapon damage for 6 s on hero hit | s, dmg | dm + wiki | 2026-09-16 | high | [15][33] |
| Whip-like ability damage | 65 + 0.8×SP | dmg | wiki | 2026-09 | medium | [3] |

### Spirit power, CDR and multiplier items

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| SP percent stacking | multiplicative, applied to total | — | wiki | 2026-09 | medium | [3] |
| Flat SP item tier 1 | +10 (cost 800) | SP (souls) | dm | 2026-09-16 | high | [17] |
| Flat SP item tier 2 | +18 (1600) | SP (souls) | dm | 2026-09-16 | high | [17] |
| SP item tier 4 | +30 and +15% (6400) | SP (souls) | dm | 2026-09-16 | high | [17] |
| Spirit investment thresholds | 800/1600/2400/3200/4800/6400/8000/11200/16000/22400/28800 | souls spent | wiki | 2026-05-22 | low | [3][22] |
| Spirit investment bonus | 7/11/15/19/38/45/52/59/66/75/100 | SP | wiki | 2026-05-22 | low | [3][22] |
| CDR stacking formula | 1 − Π(1 − r_i) | — | wiki | 2026-09 | high | [4] |
| CDR worked example | 20% + 5% = 24% | % | wiki | 2026-09 | high | [4] |
| CDR cap | none documented | — | wiki | 2026-09 | low | [4] |
| CDR affects items | no (separate stat since 2025-07-04) | — | off | 2025-07-04 | high | [28] |
| CDR item tier 3 | 20% (3200) | % (souls) | dm | 2026-09-16 | high | [17] |
| CDR imbue tier 2 | 18% (1600) | % (souls) | wiki | 2026-09 | high | [4] |
| Vitality CDR item tier 2 | 5% (1600) | % (souls) | wiki | 2026-09 | medium | [4] |
| Legendary CDR items | 40% and 50% (no soul cost listed) | % | wiki | 2026-09 | medium | [4] |
| Tier-4 dual CDR item | 25% ability + 25% item (6400); it was 30% + 30% at launch on 2025-07-04 and reduced to 25% on 2025-11-21. The wiki says its CDR also shortens cooldowns already running when it is bought. | % (souls) | dm + wiki | 2025-11-21 | high | [17][28][34] |
| Tier-4 spell item CDR | 5% (6400) | % (souls) | dm | 2026-09-16 | medium | [17] |
| Ultimate-only CDR (armor item) | 10 | % | dm | 2026-09-16 | medium | [17] |
| Powerup "casting" buff CDR | 12–20% for 160 s | %, s | wiki | 2026-09 | low | [4] |
| On-trigger cooldown cut (tier item) | −20% of all ability cds | % | off | 2026-04-30 | medium | [20] |
| HUD decimal display threshold | < 2 | s | wiki | 2026-09 | low | [4] |
| Duration item tiers | 22% / 28% | % | dm | 2026-09-16 | medium | [9][17] |
| Range/radius item tiers | 20% / 30% | % | dm | 2026-09-16 | medium | [10][17] |
| Range stacking example (replaces the old 12 m × 1.35 row) | 30% + 10% = 37% | % | wiki | 2026-09 | medium | [10] |
| Duration stacking example | 15% + 15% = 27.8% | % | wiki | 2026-09 | medium | [9] |

### Charges

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Charge restore time | = ability cooldown (after CDR) | s | wiki | 2026-09 | high | [5] |
| Charge restore order | one at a time | — | wiki | 2026-09 | high | [5] |
| Time between charges affected by CDR | no | — | wiki | 2026-09 | high | [5] |
| +1 charge item | +1 charge, +7 SP on charged (800) | charges (souls) | dm + wiki | 2025-05-19 | high | [17][37] |
| Charge item tier 3 | +2 charges, 30% faster between-charge, 14% CDR on charged, +14 SP on charged (3200) | mixed | dm + wiki | 2026-05-22 | high | [17][36] |
| Charge item, Legendary (Street Brawl only) | +4 charges, 70% faster between-charge, 30% CDR on charged, +50 SP on charged, +2 charges on uncharged; no soul cost listed | mixed | wiki | 2026-01-22 | medium | [35] |
| Echo-type item | restores 1 charge; cd = 30 s + imbued ability cd; 0.5 s post-cast | s | off + dm | 2026-07-28 | medium | [24][17] |
| Refresher-type item | restores all charges and cooldowns | — | wiki | 2026-09 | medium | [5] |

### Status interactions

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Move slows (global) | about −20% effectiveness | % | off | 2026-09-16 | medium | [26] |
| Stun pauses reload | yes | — | off | 2026-09-16 | medium | [26] |
| Knockup affected by debuff reduction | yes | — | off | 2026-05-22 | medium | [22] |
| Stealth move speed | 4 | m/s | dm | 2026-09-16 | low | [16] |

## Open questions / needs in-game measurement

All measurements are to be done in a **private sandbox or bot lobby** using only the built-in console and cheat commands (e.g. `sv_cheats 1`, the hero-testing sandbox, and commands that grant souls or reset cooldowns) plus a stopwatch or screen-recording frame count. No file or memory inspection.

1. **Stacking of duration and range multipliers.** The wiki says `1 − Π(1 − x)` and its examples (27.8%, 37%) agree with that formula. Confirm it in game.
   - Buy the 22% and 28% duration items together.
   - Time a fixed-duration ability (e.g. a 3 s effect) with 60 fps video.
   - Compare the result against 3×1.50 (additive), 3×1.22×1.28 (product) and 3×(1+0.438) (the wiki formula).
2. **CDR cap.**
   - Stack every available CDR source (tier 3 + tier 4 + imbue + powerup).
   - Record the cooldown shown on the HUD against the formula.
   - Check for clamping, e.g. at 60% or 75%.
3. **Charge restore while at the lockout.**
   - Use a 2-charge ability twice quickly.
   - Verify that the restore timer starts on the first use (not the second) and that the lockout does not pause it.
   - Frame-count the moment each charge returns.
4. **Adding charges while cooling down.**
   - While a 1-charge ability is on cooldown, buy +1 charge.
   - Check whether a charge is granted immediately or only after the timer ends.
5. **CDR bought mid-cooldown.** The wiki's Transcendent Cooldown page says the CDR does apply to cooldowns already running. Confirm this for the other CDR items too: check whether the remaining time is rescaled at purchase or only applies to the next cooldown. Time it with a stopwatch before and after buying the item in the sandbox shop.
6. **Upgrade mid-cooldown.** A T1 `−12 s` cooldown upgrade bought during an active cooldown: does it shorten the running timer? Observe the HUD.
7. **Toggle vs silence and stun.** Toggle an aura on, get silenced or stunned by a bot, and check whether the aura turns off. Use the bot-ability or cheat commands to apply the CC.
8. **Channel vs silence and knockup.** Confirm the wiki claim that silence does not break channels. Have a bot hero silence you mid-channel.
9. **Overflow soul levels.**
   - Grant souls past 49,200 with the cheat command.
   - Confirm that no AP or stats are added.
   - Record the souls per post-max "level" shown on the HUD.
10. **Refund window.**
    - Buy T1 and wait 9 s, then try to refund.
    - Buy again, wait 11 s, and try again.
    - Repeat after casting an ability during the window.
11. **Per-boon heavy melee.** Grant souls level by level on a dummy and read the damage numbers per level for three heroes.
12. **Stamina regen.** The data gives 4.5 s per bar; the wiki prose says 5 s. Time full stamina recovery from empty with video.
13. **Spirit investment bonus.** Buy spirit items adding up to 800, 1600 and 3200 souls, and read the SP stat panel at each step.
14. **Hidden rounding.** Check whether damage numbers use the unrounded coefficient (0.975) or the tooltip value (1.0). Hit a dummy with 100 SP from items and compare the damage number with 125 + 97.5.
15. **Stale wiki "Boon table" soul labels** (0.6K, 0.9K, 1.3K …) differ from the current level table. Grant souls one threshold at a time and note the exact HUD level-up points.

## Implementation notes for Godot 4

- **Data model (Resources):**
  - `ScaleTerm`:
    - `type` (enum SPIRIT, BOON, MELEE, WEAPON_DAMAGE, DURATION_MULT, RANGE_MULT, COOLDOWN_MULT, CHARGE_CD_MULT, MAX_CHARGES, HEALING)
    - `coef: float`
  - `AbilityProperty`: `base: float`, `scales: Array[ScaleTerm]`. The function `evaluate(stats: HeroStats) -> float` returns `base + Σ coef×stat`, then applies the multiplier-type terms.
  - `AbilityUpgrade` (per tier):
    - `cost: int` (1, 2 or 5)
    - `deltas: Dictionary[StringName, float]`
    - `added_scales: Dictionary[StringName, Array[ScaleTerm]]`
  - `AbilityData` (Resource):
    - `slot` (1–4), `is_ultimate`
    - `behavior_flags` (bitmask: INSTANT, RECAST, CHANNELED, TOGGLE, PASSIVE, CD_ON_CHANNEL_END, CD_ON_TOGGLE_OFF, NOT_SILENCABLE, CASTABLE_WHILE_BUSY, HOLD_AT_MAX_CHANNEL, STARTS_ON_COOLDOWN, NO_CANCEL)
    - `properties: Dictionary[StringName, AbilityProperty]`. Keys include cooldown, cast_delay, channel_time, duration, max_charges, time_between_charges, damage and radius.
    - `upgrades: Array[AbilityUpgrade]` (size 3)
    - `interrupt_refund: float` (0, 0.5 or 1)
    - `channel_move_speed_mult: float`
  - `LevelTable` (Resource): `thresholds: PackedInt32Array` (36 entries) and `unlock_levels: PackedInt32Array = [0,2,4,7]`, with `ultimate_level = 7`.
  - `HeroStats` (Resource):
    - `archetype`
    - `base_hp`, `hp_per_boon`, `regen`
    - `bullet_dmg`, `bullet_per_boon`, `pellets`, `ammo`
    - `move_speed`, `sprint_bonus`, `stamina_bars`, `stamina_regen_time`, `dash_bucket`
    - `sp_per_boon`, `melee_per_boon`, `heavy_melee_base`, `heavy_per_boon`
- **Runtime:**
  - An `AbilityComponent` node per slot, with states `LOCKED, READY, CAST_DELAY, CHANNELING, ACTIVE(toggle/duration), COOLDOWN`.
  - Charges are tracked in parallel: `charges`, `restore_timer`, `lockout_timer`.
  - Drive it from `_physics_process` with a fixed tick. Emit signals (`cast_started`, `cast_finished`, `cooldown_started(t)`, `charges_changed`) for the HUD.
  - `StatAggregator` on the hero:
    - Flat stats are summed and percentage stats multiplied.
    - CDR uses `1 − Π(1 − r)`.
    - Keep separate buckets: ability CDR, item CDR, ultimate CDR and charged-only CDR.
    - Recompute when items or levels change and emit `stats_changed`. Abilities re-evaluate their properties lazily.
  - `ProgressionComponent`:
    - `add_souls(n)` loops over the thresholds crossed, granting unlocks or AP plus per-boon stats in order.
    - Losing souls never lowers the level.
    - Keep a 10 s refund stack that is cleared on any cast.
- **CC gating:** a `can_cast()` check tests the stunned/silenced/displaced flags against the behavior flags. On stun, a running channel is interrupted and the refund applied. Silence and displacement do not interrupt.
- **Data import:** author abilities as `.tres` files, or as JSON loaded by an EditorScript. Use original names and numbers for our game. Values here are reference ranges for tuning, not content to copy.
- **Legal data pipeline:** an optional offline Python or GDScript tool in `tools/analytics/`.
  - Query `https://api.deadlock-api.com/v1/analytics/ability-order-stats?hero_id=<id>&min_matches=<n>`. It returns public aggregate upgrade orders with wins, losses and matches.
  - Also query `/v1/analytics/hero-stats`, `/v1/analytics/lane-soul-curve` and `/v1/analytics/item-stats`. The spec is at [31].
  - Use the results for balance targets: souls-per-minute curves to pace the level table, and win rate by upgrade order to check tier cost balance.
  - Cache responses locally and respect the API's rate limits. The OpenAPI spec (checked 2026-09-27) lists shared analytics limits of 200 requests/min per IP, 400/min per key and 2000/min globally. Never touch game files.
  - The endpoints above were confirmed to exist in that spec. `ability-order-stats` requires `hero_id`, and `min_matches` defaults to 20. Other endpoints that may be useful: `hero-build-stats/{hero_id}`, `build-item-stats`, `item-permutation-stats` and `player-performance-curve`.

## Sources

All accessed 2026-09-27.

1. https://deadlock.wiki/Boon
2. https://deadlock.wiki/Abilities
3. https://deadlock.wiki/Spirit_Power
4. https://deadlock.wiki/Ability_Cooldown
5. https://deadlock.wiki/Charges
6. https://deadlock.wiki/Stamina
7. https://deadlock.wiki/Hero_Comparison_Table
8. https://deadlock.wiki/Health_Regen
9. https://deadlock.wiki/Ability_Duration
10. https://deadlock.wiki/Ability_Range
11. https://deadlock.wiki/Imbue
12. https://deadlock.wiki/Scaling
13. https://deadlock.wiki/Movement
14. https://deadlock.wiki/Status_Effects
15. https://deadlock.wiki/Data:AbilityData.json (community-datamine, last edited 2026-09-16)
16. https://deadlock.wiki/Data:HeroData.json (community-datamine, last edited 2026-09-16)
17. https://deadlock.wiki/Data:ItemData.json (community-datamine, last edited 2026-09-16)
18. https://deadlock.wiki/Update:June_30,_2026
19. https://steamcommunity.com/games/1422450/announcements/detail/688635449342692004 (official, 2026-06-30)
20. https://deadlock.wiki/Update:April_30,_2026
21. https://store.steampowered.com/news/app/1422450/view/664986477286916766 (official, 2026-04-30)
22. https://deadlock.wiki/Update:May_22,_2026
23. https://store.steampowered.com/news/app/1422450/view/670617878982034052 (official, 2026-05-22)
24. https://deadlock.wiki/Update:July_28,_2026
25. https://deadlock.wiki/Update:August_12,_2026
26. https://deadlock.wiki/Update:September_16,_2026
27. https://deadlock.wiki/Update:January_22,_2026
28. https://deadlock.wiki/Update:July_4,_2025
29. https://deadlock.wiki/Update:June_17,_2025
30. https://assets.deadlock-api.com/v2/heroes (community-datamine API)
31. https://api.deadlock-api.com/openapi.json
32. https://api.deadlock-api.com/v1/analytics/ability-order-stats
33. https://deadlock.wiki/Abrams
34. https://deadlock.wiki/Transcendent_Cooldown
35. https://deadlock.wiki/Omnicharge_Signet
36. https://deadlock.wiki/Rapid_Recharge
37. https://deadlock.wiki/Extra_Charge
38. https://deadlock.wiki/Infernus
39. https://deadlock.wiki/Echo_Shard
40. https://deadlock.wiki/Boundless_Spirit, https://deadlock.wiki/Extra_Spirit, https://deadlock.wiki/Improved_Spirit

## Verification log (2026-09-27)

Adversarial re-check against public sources only: the deadlock.wiki pages, the wiki's copies of the official patch notes, and the deadlock-api OpenAPI spec. No game files were used. `assets.deadlock-api.com` could not be reached from the checking environment (DNS failure), so values sourced only from [30] were not re-verified against that source.

**Confirmed (no change):**
- Level table L0–L35 (600 … 49,200) and max level 35 [1].
- Unlocks at 600 / 1,100 / 2,000 / 3,800 souls and ultimate at level 7 [2][1][18].
- Ultimate moved from level 6 to 7 on 2026-06-30 [18].
- 32 AP total, and the history of 32 → 29 on 2025-06-17 [1][2][29].
- Tier costs 1/2/5 and the 10 s refund window [2].
- Level is kept when souls are lost [1].
- SP per boon: 1.1 default, Grey Talon 1.6, Haze 0.5 [3].
- CDR formula and the 24% example, no cap documented, 18% / 1,600 imbue, 20% / 3,200, HUD decimals under 2 s, powerup 12–20% for 160 s [4].
- Ability CDR separated from item CDR on 2025-07-04; ultimate cd +10% and ability damage −8% on the same patch [28].
- Charges restore one at a time, restore time equals cooldown, and time-between-charges ignores CDR [5].
- Infernus-like kit: all slot values and upgrades match [38].
- Abrams-like slots 1 and 2 values match; missing T3 parts were added [33].
- Hero table spot check of 7 heroes (Abrams, Haze, Grey Talon, Mo & Krill, Vindicta, Dynamo, Lash): all match [7].
- 38 heroes, with HP range 660–930 and speed 6.2–8.2 [7].
- SP items: 10 / 800, 18 / 1,600, and 30 + 15% / 6,400 (the flat part was reduced from 35 to 30 on 2026-03-21) [40].
- Echo-type item: 30 s + imbued ability cd, restores 1 charge, 0.5 s post-cast (2026-07-28) [39].
- On-trigger −20% cooldown (new T4 vitality item) and −7 HP/boon, both on 2026-04-30 [20].
- −10 base HP, −3 HP/boon, knockup affected by debuff reduction, and the wall-jump −25% stamina regen for 5 s, all on 2026-05-22 [22].
- Slows about −20% and stuns pausing reload on 2026-09-16 [26].
- Duration items 22% / 1,600 and 28% / 3,200; range items 20% and 30% [9][10].
- Wiki stamina prose is still 5 s per bar (page edited 2026-09-09), so the 4.5 s vs 5 s conflict remains.
- Dash distance 10 / 8 m and 1 hu ≈ 0.0254 m [6][13].
- deadlock-api analytics endpoints, parameters and rate limits [31].

**Corrected:**
- M4 / timing table: the 2026-01-22 cast-delay-cancel change applies to named **channeled** abilities, not to all instant casts.
- Omni-charge item: changed from "tier 5, 9999 souls" to **Legendary, Street Brawl only, no listed cost**. Also added +50 SP on charged abilities.
- M11 / range example: the "12 m × 1.35" example was removed because it is not on the current wiki. The wiki formula `1 − Π(1 − x)` is now the default and is backed by the wiki's 27.8% and 37% examples.
- Tier-4 dual CDR: added its history (30% → 25% on 2025-11-21) and the wiki note that it applies to cooldowns already running.
- Added the 2026-06-30 +15% ultimate cooldown nerf (rounded to 5 s).
- Charge item tier 3 and +1 charge item: added their SP-on-charged stats and the dates of their last changes.
- Added the missing CDR sources: a 5% / 1,600 vitality item and legendary 40% / 50% items. These matter for the CDR-cap test.

**Downgraded:**
- Channel-interrupt refund of 50% / 100%: not found on the Abilities page, now low.
- Dash speed buckets: the cited Movement page lacks them, now low. The ground speeds are still consistent with the Hero Comparison Table.
- Ivy and Kelvin/Sinclair/Viscous SP per boon: the wiki only gives a 1.2–1.3 range, now medium.
- Tier and scale-type counts (M3, M9): the spec writer's own aggregation of community JSON, now low.
- Overflow levels "convar" detail: unsourced, now low.

**Unverifiable (left as is, confidence unchanged or low):**
- Ultimate-only 10% CDR armor item.
- Spirit investment thresholds and values (the wiki page returns 404; the 2026-05-22 notes confirm only the 4.8k/6.4k/8k/11.2k/16k breakpoints).
- Heavy melee base and per-boon values.
- Crouch speed, move acceleration and stealth speed.
- Archetype counts.
- API-relative thresholds (0 … 48,600): arithmetically consistent with the wiki table, but the API itself was unreachable.

**Legality pass:**
- No lore, voice lines, art or long verbatim descriptions were found. Ability entries are numbers only, with generic labels ("fire-themed Marksman", "lifedrain-like").
- No claim is derived from the spec writer's own extraction of game files. Data-derived values are tagged `dm` (community datamine: wiki Data:*.json and the deadlock-api assets API).
- In-game measurement steps use only the built-in sandbox and console, with no file or memory inspection.
- Nothing was removed on legal grounds.

