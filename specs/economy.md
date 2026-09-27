# Economy Spec

> Clean-room observation record. Describes observed behavior of Deadlock (Valve) for the purpose of independent reimplementation. No game code or assets were used.

Current as of the **09-16-2026** gameplay update (latest patch found; accessed 2026-09-27). Deadlock rebalances its economy nearly every patch, so treat every number as a tunable default and not as a constant.

Source-type legend: `official` = Valve patch notes (forums.playdeadlock.com / Steam news); `wiki` = deadlock.wiki; `community-datamine` = values that community sites (deadlock-api.com) publish from their own data extraction, read here only through their public JSON API; `community-measurement` = player tests; `inferred` = derived by this author from other numbers.

---

## Summary

- **Souls** are both the gold and the XP of the game. Every soul a hero collects adds to **net worth**. Net worth pays for items and also drives hero level ("boons"). Spending souls does not lower net worth or level.
- Heroes start with **600 souls**. Most income comes from lane **troopers**. Each dead trooper releases a **soul orb** that has to be claimed by shooting or meleeing it. Enemies can **deny** the flying part of the orb. Other income: **neutral (jungle) camps**, **hero kills and assists**, **objectives** (Guardians, Walkers, Base Guardians, Shrines, Mid-Boss), the **Unstable Rift** (a periodic capture-point objective), the **Soul Urn** (a periodic carry-and-deliver objective), **crates**, **Sinner's Sacrifice** machines, a **Soul Well** at base, and soul-generating items (Golden Goose Egg, Trophy Collector).
- Souls are either **secured** or **unsecured**. Jungle, crate and Sinner's Sacrifice souls arrive unsecured and slowly turn into secured souls. If the hero dies first, the unsecured amount drops as a container that anyone can pick up with a heavy melee.
- Several **comeback systems** help the team that is behind: bigger bounties for killing richer enemies, up to +26% on non-hero income, "tick gold" (passive souls) for the two poorest players on each team, a longer respawn for a rich hero killed by a poor team, and trailing-team bonuses at the Urn and Rift.
- **Shop:** items come in 3 categories (Weapon / Vitality / Spirit) and 4 tiers (800 / 1600 / 3200 / 6400). Heroes have **9 item slots**, plus up to **3 extra slots** (one per enemy Walker destroyed). A hero can hold at most **4 active items**. Some items are **components** of higher-tier items, and the component's price is credited when upgrading. Selling refunds **50%**, or **100%** if the hero has not left the shop area since buying. Cumulative spending in each category grants **investment bonuses**: Weapon damage %, Health %, or Spirit Power, with a large jump at **4,800** souls.
- Shops: the **Base shop** (own team only), **Side shops** (one per lane; each closes permanently when its lane's Guardian dies), and **2 Secret shops** in tunnels (both teams can use them). All shops sell the same catalog.

---

## Mechanics

### 1. Soul state model (per hero)

State per hero:
- `secured_souls` (spendable)
- `unsecured_souls` (spendable, but spent **after** the secured pool, and lost on death)
- `net_worth`: total souls ever earned (secured + unsecured). Used for comeback math and team averages. Buying does not lower it. Selling does not lower it either (to verify).
- `boon_level`, derived from net worth (cumulative thresholds; see Values).

Spend order: take from `secured_souls` first, then from `unsecured_souls`.

**Unsecured → secured conversion (per tick):**
```
convert_per_sec = 0.005 * unsecured + base_drain(t)
base_drain(t) = 1.6 souls/s * (1.08 ^ minutes)   # "scales 8% per minute"; confirm whether the 8% compounds or adds linearly
```
Move `min(unsecured, convert_per_sec*dt)` from unsecured to secured.

**Death:** if `unsecured >= 50 + 5*minutes`, spawn a **Soul Container** at the death location holding all of the unsecured souls, then set unsecured to 0. The container lasts **3 min**. Either team secures it with a **Heavy Melee** (the heavy-melee requirement dates from Oct 2025). When unsecured is below the threshold, the wiki suggests the souls are simply lost. The container's contents probably go to the claimer as unsecured souls; confirm in game. The wiki says boon progress is reduced by the dropped amount, i.e. the dropped souls leave the hero's net worth.

### 2. Troopers and soul orbs

- Bounty per trooper kill: `100 + 2 * minutes` (June 30 2026 rescale).
- A last hit is **not** required (since Feb 2025). Killing a trooper releases **two orbs**:
  - **Flying orb (deniable), 50% of the bounty.** It spawns dark, becomes active after about **80 ms**, and floats. It is claimed by any bullet, pellet or melee hit from the killing team. If an enemy hero hits it first, it is **denied** (see below). If nobody claims it, it auto-awards after about **1 s**. Claiming an orb **refunds the bullet** that hit it, and claiming orbs restores ammo in general (May 2025).
  - **Ground orb (non-deniable), 50%.** Enemies see it as white. It lasts **18 s**, extended by **2 s per minute after 10 min** up to **40 s**. Allies within range collect it by walking over it or by shooting it (verify).
  - If the trooper is killed by **melee**, only the ground orb spawns, and the flying 50% goes straight to the melee player.
- **Sharing:** the souls are split among allied heroes in range. The range is **45 m** from the orb when it breaks, or **30 m** from the killing hero; being inside either radius counts. With N heroes sharing, each gets `bounty * trooper_share[N]`, where `trooper_share = [1.00, 0.54, 0.36, 0.25, 0.20, 0.16]`. The group total is therefore 100/108/108/100/100/96%.
- **Denies:** since Feb 2025 a denied flying orb is split **50/50** (it was 65/35 before). The current wiki text is inconsistent on who receives what. One section says the denier and nearby allies get the souls. The comeback section says denied souls are split between the victim team's two lowest-net-worth players. See the open questions.
- Troopers receive the comeback multiplier (up to +26% for the trailing team; section 7).

Suggested orb state machine: `SPAWNING (80ms, not hittable) -> ACTIVE (hittable by both teams) -> {CLAIMED | DENIED | AUTO_AWARD after ~1s}`. Ground orb: `ACTIVE(lifetime) -> {COLLECTED | EXPIRED}`. What an expired ground orb does is unknown: it may give nothing or auto-split.

### 3. Hero kills, assists, first blood

- Base kill bounty: `min(200 + 50*minutes, 2200)` (the cap is reached at 40 min). First blood adds **+125**.
- Kill credit goes to every hero who **damaged the victim in the last 10 s**. With N participants, each gets `bounty * hero_share[N]`, where `hero_share = [1.25, 0.575, 0.283, 0.175, 0.11, 0.083]`. A solo kill therefore pays 125% (a Dec 2025 bonus). The shares are **flat**: the killer gets the same as an assister (verify).
- Since June 2025, hero kill souls are **awarded directly**, with no orb.
- **Comeback kill bounty:** killing a hero whose net worth is above the killer team's average gives up to **+126.8%** extra. The exact curve is not public. Sep 16 2026 changes: the fixed "you're behind" bonus was removed, overall values were lowered slightly, and **70% of the extra comeback value earned by a player who is above the enemy team's average net worth is redirected** to their team's two lowest-net-worth players through the tick-gold channel.
- **No separate kill-streak bounty was found in public sources.** "Streak" value is handled only by the net-worth-based comeback bounty. Glass Cannon's per-kill stacks are an item effect, not an economy rule.
- Respawn time is tied to the economy: 8 s at 5 min, 38 s at 20 min, 70 s at 30 min, 85 s at 40 min, capped at 90 s, and +10 s when killed by non-player units. From 10 min on, if the victim's net worth is at least 15% above the killer team's average, the victim's respawn grows by **+6 to +22 s**. This scales with a net-worth gap of 15–30% and with game time from 10 to 25 min (Jan 2026).

### 4. Neutral (jungle) camps

- Tiers (souls per unit): Small `41 + 0.44/min`, Medium `68 + 0.73/min`, Large `181 + 1.95/min`. Cockroaches in vents give 1 soul each and respawn after 30 s.
- First spawn / respawn after the camp is cleared: Small 2:00 / 1:25, Medium 5:00 / 4:50, Large 8:00 / 5:35.
- Souls are **unsecured**. They are split **equally** among the allied heroes who damaged the neutral. Unlike troopers, there is no distance-based sharing.
- They receive the trailing-team comeback multiplier.

### 5. Sinner's Sacrifice (melee-only soul machines)

- 10 sites: 6 solo machines, 2 camps with 1 machine plus 2 Medium neutrals, and 2 camps with 2 machines plus 1 Medium neutral. They spawn at 8:00 and respawn 5 min after being broken (hybrid camps wait until fully cleared).
- 500 HP. A light melee deals 50, a heavy melee deals 100. **Only melee** damages a machine.
- Value `V = 310 + 3.35*minutes`. Each light hit pays `V/20`, each heavy hit pays `V/10`. The breaking hit pays `V/2 + V/10`. The extra +1 soul applies **only on a jackpot** (corrected 2026-09-27; earlier draft applied +1 to every break). Payouts are unsecured.
- Jackpot: when the last bulb is reached a ~3 s timing window starts; hitting in the final ~1.3 s grants 1 permanent statue buff (light melee) or 4 (heavy melee) (wiki, medium).
- The machine deals 80 return damage per melee hit to the attacker (disabled during the jackpot window) (wiki, 2026).

### 6. Breakables

- **Crates:** 518 on the map. Standard crates spawn at 3:00 and respawn after 3 min. Mid-Boss-room crates spawn at 10:00 and respawn after 3 min. Tunnel crates spawn at 5:00 and respawn after 5 min. Each break has a **60%** chance to drop `23 + 2*minutes` unsecured souls. If a dropped container is never collected, the crate's respawn is delayed.
- **Golden Statues:** these give buffs, not souls. Each break has a 50% chance to drop one random **permanent stat buff**. The weights are equal across 7 slots, with Health taking 2 of them. The buff's strength depends on game time (levels at 0 / 10 / 30 min; see Values).

### 7. Comeback and catch-up systems

1. **Trailing-team income multiplier:** up to **+26%** on souls from troopers, neutrals, Sinner's Sacrifice and objectives. The first **3,000** souls of net-worth deficit are ignored, and the bonus peaks at a **20%** team net-worth gap. Assume a linear ramp between those points (unverified).
2. **Tick gold:** after **8:00**, the lowest-net-worth player on each team passively earns **2.5%** of the souls their team gathers, and the second-lowest earns **1.5%**. Implement it as a per-second trickle based on team income over a rolling window (the exact window is unknown).
3. **Comeback-kill redistribution:** 70% of excess comeback souls go to the two lowest players (section 3).
4. **Comeback respawn penalty** (section 3).
5. **Urn / Rift trailing-team bonuses** (sections 9–10). These scale linearly from 0 at a 0% net-worth gap to full at a 15% gap.

Team net-worth deficit (%) = `(enemy_avg - own_avg) / enemy_avg`. This definition is inferred.

### 8. Objectives (lane structures and Mid-Boss)

- Souls are **awarded directly** (no orbs) since June 2025.
- **Split rule** (Sep 16 2026): **25%** of the bounty goes to allied heroes near the objective, and the other **75%** is split between **all 6** team members. This was 40% in early July 2026 and 30% after July 9. The radius for "nearby" is not public. Assume the trooper sharing radius of 45 m.
- Bounties: Guardian (tier-1 lane tower) **1375**; Walker (tier 2) **3675**; Base Guardians **1000**; Shrines **2000**; Patron phase 1 **0**. These are flat, with no time scaling found. The Mid-Boss is `3000 + 50/min` and is split equally among the killing team. It gives up to 3 Rejuvenator credits (see the objectives domain).
- Destroying an enemy **Walker** unlocks **one extra item slot** for every member of the destroying team (max 3).
- The comeback multiplier applies (up to +26%).

### 9. Soul Urn (carry objective; current rules as of Jun–Sep 2026)

- The Urn spawns at 10:00, then every 5 min after that, alternating between the Yellow and Green lanes. It descends for 12.5 s before it can be picked up.
- Pick it up with a **light or heavy melee** (May 2026). The carrier gets +2 m/s sprint (15 m/s max), +1 stamina, +10% dash distance, +25% stamina regen and 100% slow resist. A carrier on the trailing team gets an extra sprint bonus (+4 to +5 m/s; the sources differ).
- Deliver it to the drop-off on the **opposite end of the map** from where it spawned (corrected 2026-09-27: old text said "top of the middle bridge", which was the pre-June-30-2026 rule; June 30 2026 patch notes and the wiki Soul Urn page, last updated 2026-07-13, both say opposite end). If nobody picks it up within 3 min it walks toward the drop-off by itself. The 5 / 10 / 15 s Favored / Neutral / Unfavored deposit channel is from the May 22 2026 version and is **probably stale** (low confidence). The June 2026 KOTH-style deposit capture was also reworked again. An enemy melee or stun makes the carrier drop the urn.
- **Bounty:** `250 + 70*minutes`, fixed at spawn time. The June 30 2026 patch notes say it goes **only to the urn runner**. The wiki (2026-07-13) says instead that the souls come out as orbs that allies can claim and share. This conflict is unresolved (medium-low confidence). The runner also gets **4 random permanent buffs** from the golden-statue buff table. The bounty value starts decaying 45 s after pickup and reaches 0 over the next 45 s.
- **Favored team definition** (May 22 2026 wording, possibly superseded): a team at least 15% behind in soul difference for the first urn (10:00), and at least 10% behind for later urns. The wiki (Jul 2026) instead describes a trailing-team resist bonus that scales with a 0–15% net-worth deficit: bullet/spirit/debuff resist of 10% + 1%/min, up to 40% at 30 min.
- Confidence is medium to low: the Urn was reworked 4+ times between May and July 2026, and sources disagree on details.

### 10. Unstable Rift (capture objective, "KOTH")

- First spawn at 11:00 ±1 min, then every 7 min ±1. A visual effect appears 60 s before the announcement, and the rift opens 20 s after the announcement.
- Captured by standing in a **20 m** radius for **12 s**. At a full 15% net-worth deficit, the trailing team needs 6 s and the leading team needs 18 s. After 60 s of continuous contest, 13 soul orbs are released.
- Bounty: **1482 souls**, growing by **222/min** starting at minute 13. It is split **equally among the capturing team**. The capturing team also gets a wave of 5 Rift Troopers that drop **no** souls, or up to 14 when trailing.
- Trailing-team resist bonus: `10% + 1%/min`, capped at 40% (Sep 16 2026).

### 11. Soul Well (base)

After 2:30, each team's base releases a **10-soul orb every 2 s**. A player who confirms (hits) an orb takes all 10 souls. An orb that expires unclaimed is split equally among nearby living allies (July 28 2026).

### 12. Passive / item income

- There is **no universal passive soul income**, apart from tick gold and the Soul Well.
- **Golden Goose Egg** (T1 Spirit, active and consumed on use): banks 400 souls on purchase, then grows by +80 souls/min while held. Using it (hatching) pays out the banked souls. It also grants one permanent buff (statue table) per 80 souls accrued beyond the starting 400. The stored souls count toward net worth (Sep 2026). While held, it applies a −15% outgoing damage penalty.
- **Trophy Collector** (T2 Vitality, built from Sprint Boots): gains 1 stack per hero kill or assist, up to 16 stacks, and the stacks persist through death. Each stack gives +16 souls/min, +0.15 m/s sprint and +0.75% ability range. The item has −15% weapon damage against NPCs. At 16 stacks the item makes 256 souls/min (inferred).

### 13. Hero level (boons) from souls

The hero's level is set by cumulative net worth. Level 0 is 600 souls. Level 1 is 800 souls and level 7 (ultimate unlock) is 3800 souls. Per the wiki, levels 0, 2, 4 and 7 unlock abilities. The official Apr 30 2026 patch notes (verified on deadlock.wiki/Update:April_30,_2026 and by search against tracklock/liquipedia) changed the thresholds above 13.2k to **13.2k, 14.5k, then +1.5k per boon, ending at 40k** (previously 13.2k/15k/17k/+2k, ending at 49k). The wiki Boons table (ending at 49,200 for level 35) is **stale above 13.2k**. Use 40,000 as the cap. Full detail belongs to the progression spec.

### 14. Shop: categories, tiers, slots, actives

- Categories: **Weapon** (orange), **Vitality** (green), **Spirit** (purple). Tier prices are **800 / 1600 / 3200 / 6400**, and these are the only prices in the game (every item in a tier costs the same). The old prices were 500 / 1250 / 3000 / 6000(–6300), changed on **May 8 2025**.
- Catalog size (standard mode): Weapon 7/16/19/11, Vitality 8/15/14/17, Spirit 8/12/13/16 items for T1/T2/T3/T4. That is 156 items in total, **44** of which are actives (corrected 2026-09-27: was 50. The API `is_active_item` count for T1–T4 is 4/8/16/16 = 44; 50 only if the 6 Street Brawl Legendary actives are included). The wiki Items page gives slightly different per-tier counts (Weapon T3 20, Vitality T2 14, Spirit T2 11), so the per-tier counts are medium confidence. A 5th "Legendary" tier (price 9999 in data) exists only in Street Brawl mode. Street Brawl also shows "Enhanced" item variants with boosted stats. **Ignore both** for the core economy.
- **Slots:** 9 base slots, not restricted by category. There are **+3 Extra Slots**, one granted per enemy **Walker** the team destroys (Nov 21 2025). Before that there were 8 base slots plus 4 flex slots, unlocked by all 3 Guardians, 1 Walker, 3 Walkers and the Base Guardians.
- **Active item cap:** at most **4 active items** in the inventory. A 5th active cannot be bought until one is sold. Actives are bound to separate activation keys.
- **Components:** a higher-tier item may list 1 or more lower-tier items as components. Buying the upgrade **consumes the owned component and credits its full cost**, so upgrading T1→T2 costs 800 more. The upgraded item keeps the component's stats or grows them (the component's stats are generally included). The upgrade reuses the component's slot, so upgrading does not use an extra slot.
- **Imbue:** 9 items (such as Mystic Expansion, Duration Extender, Surge of Power, Echo Shard, Quicksilver Reload and Mercurial Magnum) are bound to one chosen ability at purchase. The only way to rebind is to sell and rebuy.
- **Selling:** refunds 50% of the souls actually spent. If the hero has **not left the shop area** since buying the item, the refund is 100% (undo window). Selling is allowed only inside a shop area (assumption, consistent with every source). No buyback beyond the undo window was found.

### 15. Investment bonuses

For each category, track `spent[cat]`, the cumulative souls spent on that category's items. Rules for implementation:
- The bonus is a **step function**: use the highest threshold that is at or below `spent[cat]`. Do not interpolate (steps confirmed by the wiki's breakpoint table; exact behavior between steps should be checked in game).
- Weapon gives **% weapon damage**, Vitality gives **% max health** (base health), and Spirit gives **flat Spirit Power**. The values are in the Values table. Bonuses stop growing at 28,800 souls per category.
- Selling probably reduces `spent[cat]` by the item's cost, and the bonus steps back down. **Unverified; measure it.** Component credit on an upgrade should count the full upgrade price, not double-count the component: spent grows by the upgrade's cost minus the component's cost (inferred).

### 16. Shops (Curiosity Shop)

- **Base shop:** in spawn. The buy radius covers the whole spawn room. Own team only.
- **Side shops:** one per lane on each team's side. Own team only. Each closes permanently when that lane's (own) Guardian is destroyed.
- **Secret shops:** 2, in the underground tunnels between the middle street and the outer lanes. Both teams can use either one. They stay open even when both teams are nearby (Oct 2025).
- All shops sell the full catalog. There are no secret-shop-exclusive items.

---

## Values

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Starting souls | 600 | souls | wiki / official | 2025-11-21 | high | [1][4] |
| Trooper bounty | 100 + 2/min | souls | official | 2026-06-30 | high | [5] |
| Trooper flying (deniable) orb share | 50 | % of bounty | official | 2026-06-30 | high | [5] |
| Trooper ground orb share | 50 | % of bounty | wiki | 2026-06-30 | high | [1] |
| Flying orb activation delay | ~80 | ms | wiki | 2026 | medium | [1] |
| Flying orb auto-award if unclaimed | ~1 | s | wiki | 2026 | medium | [1] |
| Ground orb lifetime | 18 → 40 (+2 s/min after 10 min) | s | wiki / official | 2025-11-21 | high | [1][4] |
| Trooper share per hero, N=1..6 | 1.00/0.54/0.36/0.25/0.20/0.16 | fraction of bounty each | community-datamine / wiki | 2025-11-21 → 2026-09 | high | [1][13] |
| Trooper sharing radius (from orb) | 45 | m | wiki / official | 2025-11-21 | high | [1][4] |
| Trooper sharing radius (from killer) | 30 | m | wiki | 2026 | medium | [1] |
| Deny split | 50/50 | % | official (via wiki history) | 2025-02-25 | medium | [4] |
| Last hit required for trooper souls | no | — | official (via wiki history) | 2025-02-25 | high | [4] |
| Hero kill base bounty | 200 + 50/min, cap 2200 at 40 min | souls | official | 2026-06-30 | high | [5] |
| First blood bonus | 125 | souls | official | 2026-06-30 | high | [5] |
| Hero kill share per hero, N=1..6 | 1.25/0.575/0.283/0.175/0.11/0.083 | fraction of bounty each | community-datamine | 2026-09 | high | [13] |
| Assist window | 10 | s since last damage | wiki | 2026 | high | [1] |
| Comeback kill bonus max | +126.8 | % | wiki | 2026-09-16 | medium | [1] |
| Comeback redirect to lowest 2 | 70 | % of excess comeback souls | official | 2026-09-16 | high | [3][6] |
| Trailing-team non-hero income bonus max | +26 (was +25 in May 2025) | % | wiki | 2026 | medium | [1][4] |
| Trailing bonus deadzone / peak | 3000 souls / 20% NW gap | souls / % | wiki / official | 2025-05-08 | medium | [1][4] |
| Tick gold (lowest / 2nd-lowest) | 2.5 / 1.5 | % of team soul income | official (via wiki) | 2024-12-21 | high | [1][4] |
| Tick gold start | 8:00 | mm:ss | wiki | 2026 | medium | [1] |
| Unsecured drop threshold | 50 + 5/min | souls | official | 2026-06-30 | high | [5] |
| Unsecured conversion | 0.5%/s + 1.6 souls/s (base grows 8%/min) | rate | wiki / official | 2025-12-16 | medium | [1][4] |
| Soul container lifetime | 3 | min | wiki | 2026 | medium | [1] |
| Soul container claim input | Heavy Melee | — | official (via wiki) | 2025-10-02 | high | [4] |
| Small neutral | 41 + 0.44/min | souls/unit | wiki | 2026 | high | [1][8] |
| Medium neutral | 68 + 0.73/min | souls/unit | wiki | 2026 | high | [1][8] |
| Large neutral | 181 + 1.95/min | souls/unit | wiki | 2026 | high | [1][8] |
| Small camp spawn / respawn | 2:00 / 1:25 | mm:ss | wiki | 2026 | high | [8] |
| Medium camp spawn / respawn | 5:00 / 4:50 | mm:ss | wiki / official | 2026-05-22 | high | [8][7] |
| Large camp spawn / respawn | 8:00 / 5:35 | mm:ss | wiki | 2026 | high | [8] |
| Neutral HP small/med/large | 129 / 322 / 1133 | HP | wiki | 2026 | medium | [8] |
| Cockroach | 1 (30 s respawn) | souls | wiki | 2026 | medium | [8] |
| Sinner's Sacrifice value | 310 + 3.35/min | souls | wiki | 2025-12-16 | high | [9] |
| Sinner's Sacrifice HP / light / heavy dmg | 500 / 50 / 100 | HP | wiki | 2026 | high | [9] |
| Sinner's payout light / heavy / final | V/20, V/10, V/2+V/10 (+1 only on jackpot) | souls | wiki | 2026 | medium | [9] |
| Sinner's spawn / respawn | 8:00 / 5 min | time | wiki | 2026 | high | [9] |
| Sinner's sites | 10 | count | wiki | 2026 | medium | [9] |
| Crate souls | 23 + 2/min, 60% chance | souls | wiki | 2025-07-29 | high | [1][10] |
| Crate count | 518 | count | wiki | 2026 | medium | [10] |
| Crate spawn / respawn (standard) | 3:00 / 3 min | time | official / wiki | 2026-05-22 | high | [10] |
| Crate spawn / respawn (tunnel) | 5:00 / 5 min | time | wiki | 2026-09-16 | high | [10] |
| Golden Statue buff drop chance | 50 | % | wiki | 2025-05-08 | high | [11] |
| Statue buff: fire rate L1/L2/L3 | 1.5 / 2 / 2.5 | % | wiki | 2026 | high | [11] |
| Statue buff: max ammo | 3 / 5 / 7 | % | wiki | 2026 | high | [11] |
| Statue buff: cooldown reduction | 0.5 / 0.75 / 1 | % | wiki | 2026 | high | [11] |
| Statue buff: weapon damage | 3 / 4 / 6 | % | wiki | 2026 | high | [11] |
| Statue buff: max health | 15 / 20 / 30 | HP | official / wiki | 2026-05/06 | high | [7][11] |
| Statue buff: spirit power | 2 / 3 / 4 | SP | wiki | 2026 | high | [11] |
| Statue buff level times | 0 / 10 / 30 | min | wiki | 2026 | high | [11] |
| Objective near-hero share | 25 | % (rest split among all 6) | official / community-datamine | 2026-09-16 | high | [3][13] |
| Guardian bounty | 1375 | souls | official / community-datamine | 2026-09-16 | high | [3][13] |
| Walker bounty | 3675 | souls | official / community-datamine | 2026-09-16 | high | [3][13] |
| Base Guardian bounty | 1000 | souls | community-datamine / wiki | 2026-09 | high | [1][13] |
| Shrine bounty | 2000 | souls | community-datamine / wiki | 2026-09 | high | [1][13] |
| Patron (phase 1) bounty | 0 | souls | community-datamine | 2026-09 | high | [13] |
| Mid-Boss bounty | 3000 + 50/min (killing team, equal split) | souls | wiki | 2026-03-06 | high | [12] |
| Mid-Boss respawn | 7 / 6 / 5 then 5 | min | wiki | 2026 | high | [12] |
| Urn bounty | 250 + 70/min (runner only per 06-30 notes; wiki says shareable orbs) | souls | official (via wiki) | 2026-06-30 | medium (formula) / low (recipient) | [14][15] |
| Urn first spawn / interval | 10:00 / 5 min | time | wiki | 2026-07 | medium | [15] |
| Urn decay | starts 45 s after pickup, over 45 s | s | official (via wiki) | 2026-06-30 | medium | [14] |
| Urn permanent buffs to runner | 4 | buffs | official (via wiki) | 2026-06-30 | medium | [14] |
| Urn favored threshold | 15% (1st urn) / 10% (later); possibly superseded by 0–15% scaling resist | NW gap | official | 2026-05-22 | low | [7][15] |
| Rift bounty | 1482 + 222/min (from min 13), team split | souls | wiki | 2026-06-30+ | medium | [16] |
| Rift spawn | 11 ±1 min, every 7 ±1 min | min | wiki / official | 2026-06-30 | medium | [14][16] |
| Rift capture | 12 s (6–18 with comeback), 20 m radius | s / m | wiki | 2026 | medium | [16] |
| Rift trailing resist | 10% + 1%/min, max 40% | % | official | 2026-09-16 | high | [3][6] |
| Soul Well orb | 10 souls every 2 s after 2:30 | souls | wiki | 2026-07-28 | medium | [1] |
| Respawn curve | 8 s @5 min, 38 @20, 70 @30, 85 @40, max 90 | s | wiki / official | 2026-09-16 | medium | [3][17] |
| Comeback respawn penalty | +6 to +22 | s | wiki | 2026-01-20 | medium | [17] |
| Golden Goose Egg income | 400 start + 80/min | souls | official / community-datamine | 2026-09-16 | high | [3][13][18] |
| Trophy Collector income | 16/min per stack, max 16 stacks | souls/min | official / community-datamine | 2026-09-16 | high | [3][13][19] |
| Item tier prices | 800 / 1600 / 3200 / 6400 | souls | community-datamine / wiki | 2025-05-08 → 2026-09 | high | [2][13] |
| Legacy tier prices (pre 2025-05-08) | 500 / 1250 / 3000 / 6000–6300 | souls | wiki | ≤2025-05 | medium | [20][21] |
| Base item slots | 9 | slots | wiki / official | 2025-11-21 | high | [22] |
| Extra slots | 3 (1 per enemy Walker destroyed) | slots | wiki / official | 2025-11-21 | high | [22] |
| Max active items | 4 | items | wiki | 2026 | high | [2][23] |
| Sell refund | 50 | % of spent | wiki | 2026 | high | [2][23] |
| Undo refund (still in shop area) | 100 | % | wiki | 2026 | high | [2][23] |
| Component upgrade credit | 100 | % of component cost | wiki | 2026 | high | [2] |
| Investment thresholds | 800/1600/2400/3200/4800/6400/8000/11200/16000/22400/28800 | souls spent in category | official / wiki | 2026-05-22 | high | [2][7] |
| Weapon investment bonus | 9/12/15/18/46/54/62/74/86/100/115 | % weapon damage | wiki (04-30-2026 official list 9/12/15/18/46/55/70/85/100/115 was later retuned) | 2026-05-22+ | medium | [2][39] |
| Vitality investment bonus | 9/12/15/20/38/42/46/50/54/60/66 | % health | wiki (last two steps: official says "+4") | 2026-05-22 | medium | [2][7] |
| Spirit investment bonus | 7/11/15/19/38/45/52/59/66/75/100 | spirit power (flat) | official / wiki | 2026-05-22 | medium | [2][7] |
| Standard item count per tier (W / V / S) | 7-16-19-11 / 8-15-14-17 / 8-12-13-16 (API; wiki differs: W T3 20, V T2 14, S T2 11) | items | community-datamine | 2026-09 | medium | [2][13] |
| Active items in catalog (T1–T4) | 44 (was 50; 50 counts Street Brawl Legendaries) | items | community-datamine | 2026-09 | high | [13] |
| Boon level 0 / first unlock / ult unlock | 600 / 800 / 3800 | souls | wiki | 2026 | medium | [24] |
| Boon cap | 40,000 (official 04-30-2026; wiki table's 49,200 is pre-patch) | souls | official | 2026-04-30 | medium | [39][24] |

### Representative item table (current values; generic stat names)

All values are taken from the default (non-Street-Brawl) version. Stats marked **API** come from the community-datamine JSON [13] and were cross-checked against the wiki item pages [25]–[40].

| Item | Cat | Tier / Cost | Type | Built from | Key stats | Patch | Conf |
|---|---|---|---|---|---|---|---|
| Extended Magazine | Weapon | T1 / 800 | passive | — | +30% max ammo, +8% weapon damage | 2026-03-06 | high |
| Headshot Booster | Weapon | T1 / 800 | passive (internal CD) | — | next headshot on a hero +45 bonus damage, 9 s CD; +30 health | 2025-11-21 | high |
| Titanic Magazine | Weapon | T2 / 1600 | passive | Extended Magazine | +100% max ammo, +14% weapon damage | 2026-04-10 | high |
| Toxic Bullets | Weapon | T3 / 3200 | passive | — | bullets build a bleed: 1.9% max HP/s for 4 s (0.5 s ticks), −35% healing on the target; half effect vs troopers | 2026-06-30 | high |
| Glass Cannon | Weapon | T4 / 6400 | passive | — | +80% weapon damage, −13% max HP, +7% fire rate per hero kill (max 8 stacks, lost on death) | 2026-05-22 | high |
| Extra Health | Vitality | T1 / 800 | passive | — | +210 health | 2026-03-06 | high |
| Sprint Boots | Vitality | T1 / 800 | passive | — | +2 m/s sprint, +2 out-of-combat regen | 2026 | high (API) |
| Healing Rite | Vitality | T1 / 800 | active (targeted, 30 m) | — | 300 HP regen over 20 s (x1.1 SP scaling), +2 m/s sprint; broken by damage; 70 s CD | 2026-05-22 | high |
| Trophy Collector | Vitality | T2 / 1600 | passive | Sprint Boots | see §12 | 2026-09-16 | high |
| Fortitude | Vitality | T3 / 3200 | passive | Extra Health | +375 health; after 10 s without damage regen 2.25% max HP/s; +1.5 m/s move while above 75% HP | 2026-09-16 | high |
| Warp Stone | Vitality | T3 / 3200 | active | — | forward teleport of 11 m; +30% bullet resist for 6 s; 16 s CD | 2025-11-21 | high |
| Unstoppable | Vitality | T4 / 6400 | active | Debuff Reducer | +25% debuff resist, +125 health; active: immune to stun/silence/sleep/root/disarm for 5.5 s; 60 s CD | 2026-05-22 | high |
| Extra Spirit | Spirit | T1 / 800 | passive | — | +10 spirit power | 2025-05-08 | high |
| Mystic Burst | Spirit | T1 / 800 | passive (charge) | — | recharges every 14 s; an ability hit of 80 or more damage adds +40 spirit damage | 2025-10-02 | high |
| Golden Goose Egg | Spirit | T1 / 800 | active (consumed) | — | see §12 | 2026-09-16 | high |
| Improved Spirit | Spirit | T2 / 1600 | passive | Extra Spirit | +18 SP, +75 health (API), +1 m/s sprint (API), +1.5 out-of-combat regen | 2025-05-08 | medium (wiki omits the health/sprint) |
| Boundless Spirit | Spirit | T4 / 6400 | passive | Improved Spirit | +30 SP and +15% of total SP; +75 health; +4 out-of-combat regen | 2026-03-21 | high |
| Refresher | Spirit | T4 / 6400 | active | — | resets all ability cooldowns and charges (0.6 s delay); 300 s CD; the API also shows +15% bullet / +14% spirit resist | 2025-05-08 / API 2026 | medium (conflict on resists) |

---

## Open questions / needs in-game measurement

All of these tests run in a **private bot or sandbox lobby**, using only built-in console commands the game exposes to players (`sv_cheats 1`, the `citadel_*` / `bot` commands shown in the in-game console, a timescale command, or `changeteam`), or plain observation of the HUD and scoreboard. No memory or network inspection.

1. **Deny recipient.** Who receives denied flying-orb souls: the denier and allies near them, or the victim team's two lowest players? *Measure:* 1v1 against a bot, note both players' net worth on the scoreboard, deny 20 orbs, and compare the deltas against `0.5 * bounty * share`.
2. **Ground orb expiry.** Does an unclaimed ground orb vanish, or auto-award? *Measure:* kill a trooper with an ability, walk away, and watch net worth after the lifetime ends (18 s early, 40 s after 20 min).
3. **Sharing radius edge cases.** Is the 45 m / 30 m radius measured in 2D or 3D, and are dead allies counted? *Measure:* two players at measured distances (use known ability ranges or map markers).
4. **Comeback bounty curve.** The kill bonus reaches +126.8% at some gap, but the shape of the curve is unknown. *Measure:* give souls with the cheat command to set specific net-worth gaps (0/5/10/15/20/30%), kill the target bot, and log the payout. Fit a curve.
5. **Trailing income multiplier ramp** (3k deadzone → +26% at a 20% gap). Is it linear? *Measure:* same method, killing troopers at several gaps.
6. **Tick-gold window.** Is it a % of team income per tick, or per rolling window? *Measure:* after 8:00 with a large gap, log the lowest player's net worth every 5 s while teammates farm.
7. **Unsecured conversion formula.** Does the base drain compound 8%/min or grow linearly? *Measure:* farm a large camp at 10 and 20 min and watch the unsecured counter (the HUD shows it separately) drain over time.
8. **Investment bonus on selling.** Does selling lower the bonus? Is the step function exact? *Measure:* buy items up to 4,800 in one category, check the stat panel, sell one, and check again.
9. **Component credit toward investment.** Does upgrading count the full price or only the difference? *Measure:* buy Extra Health, upgrade to Fortitude, and compare total "spent" in the category tooltip with health %.
10. **Selling rules.** Can a hero sell outside a shop? Does the undo window survive a death, or a timer? *Measure:* buy, step out, step back in, and sell.
11. **Objective "nearby" radius** for the 25% share. *Measure:* kill a Guardian with teammate bots at varying distances and compare their payouts.
12. **Urn details** (deposit timers, runner sprint bonus) after the July 2026 patches. *Measure:* spawn with a timescale, carry it, and time the deposit with a stopwatch or recording.
13. **Boon threshold table** above 13.2k (40k cap vs 49.2k). *Measure:* give souls in steps and read the level-up notices.
14. **Soul container ownership.** Do the souls arrive as secured or unsecured for the claimer? Can the owner reclaim their own container? *Measure:* die holding more than the threshold, respawn, and melee your own bag.
15. **Refresher resist conflict** (the wiki says removed in 2025; the API shows 15/14%). *Measure:* buy it and read the stat sheet.

---

## Implementation notes for Godot 4

- **Autoload `EconomyRules` (a Resource, `economy_rules.tres`)** holds every constant in the Values table: bounty formulas as `{base, per_min, cap}`, share arrays, radii, thresholds, and tier prices. Values change every patch, so keep **none** of them in code. Use a small `ScalingValue` Resource (`base`, `per_min`, `start_min`, `cap`) with `eval(minutes)`.
- **`SoulWallet` node / component per hero:** `secured`, `unsecured`, `net_worth`, `spent_by_category: Dictionary`. Signals: `souls_changed`, `net_worth_changed`. Run the unsecured conversion in `_physics_process`. On death, call `drop_container()`.
- **`SoulOrb` scene** (Area3D + state enum SPAWNING/ACTIVE/CLAIMED/DENIED), plus a `GroundOrb` scene with a lifetime Timer. Damage hitboxes check `is_in_group("soul_orb")` and use team to choose claim or deny. Refund the bullet on hit.
- **`BountyService` (autoload):** `award_trooper(pos, killer, bounty)`, `award_hero_kill(victim, participants)`, `award_objective(obj, team)`, `award_neutral(damagers)`. It queries teams and positions, applies the share arrays and comeback multipliers, and credits wallets. Keep per-hero damage logs (`last_damaged_by: {hero: timestamp}`) for the 10 s assist window.
- **`ComebackModel`:** a pure-function script that takes team net-worth arrays and returns the multipliers. Unit-test it against the tables above.
- **Items:** one `ItemData` Resource per item (`id`, `display_name`, `category`, `tier`, `cost` derived from tier, `components: Array[ItemData]`, `is_active`, `imbue: bool`, `stats: Dictionary`, `ability: Script/Resource`). An `ItemDatabase` loads them from a folder or JSON. **Legal data pipeline for prototyping:** the public community API `https://api.deadlock-api.com/v1/assets/items` returns JSON (fields `cost`, `item_tier`, `item_slot_type`, `is_active_item`, `component_items`, `properties`) that an **editor-only import script** can turn into `.tres` placeholders for balancing reference. Tag the imported values as community-datamine, and **rename and retune them before shipping**. Do not ship Valve's item names, icons or text.
- **`Inventory`:** `base_slots=9`, `extra_slots` incremented by a `walker_destroyed(team)` signal, `max_actives=4`. `can_buy(item)` checks souls after component credit, free slots (the upgrade reuses the component's slot), and the active cap.
- **`ShopArea`** (Area3D with `team`, `kind` = BASE/SIDE/SECRET, and `closed` toggled by the lane-guardian-destroyed signal). Record a `purchase_undo_token` per item that is cleared when the hero leaves every ShopArea, to allow the 100% refund.
- **`InvestmentTable`:** a Resource with `thresholds: PackedInt32Array` and `values_by_category`. Apply the stat modifiers through the stat system as a single modifier per category that is replaced whenever spending changes.
- **Analytics hooks (for the "analyze data" goal):** emit an `EconomyEvent` (time, hero, source enum, amount, secured flag) on every credit, and write it to CSV in debug builds. Compare the resulting curves against the public community endpoints `/v1/analytics/lane-soul-curve`, `/v1/analytics/item-stats` and `/v1/analytics/player-performance-curve` on api.deadlock-api.com. These are public aggregate match stats: rate-limited to 200 req/min, and should be cached locally. That comparison shows whether your soul-per-minute pacing matches the real game's.

---

## Sources

All accessed 2026-09-27.

1. https://deadlock.wiki/Souls
2. https://deadlock.wiki/Items (and https://deadlock.wiki/Shop, which redirects to the Curiosity Shop page)
3. https://deadlock.one/en/news/deadlock-patch-notes-09162026-minor-update
4. https://deadlock.wiki/Souls/Update_history
5. https://deadlock.wiki/Update:June_30,_2026
6. https://forums.playdeadlock.com/threads/09-16-2026-update.162572/
7. https://forums.playdeadlock.com/threads/05-22-2026-update.135477/ ; https://tracklock.gg/articles/deadlock-update-05-22-26
8. https://deadlock.wiki/Neutrals
9. https://deadlock.wiki/Sinner%27s_Sacrifice
10. https://deadlock.wiki/Crates
11. https://deadlock.wiki/Golden_Statues
12. https://deadlock.wiki/Mid-Boss
13. https://api.deadlock-api.com/v1/assets/generic-data and https://api.deadlock-api.com/v1/assets/items (public community API; community-datamine; docs at https://api.deadlock-api.com/docs)
14. https://deadlock.wiki/Update:June_30,_2026 (Urn / Rift sections)
15. https://deadlock.wiki/Soul_Urn
16. https://deadlock.wiki/KOTH (Unstable Rift)
17. https://deadlock.wiki/Death
18. https://deadlock.wiki/Golden_Goose_Egg
19. https://deadlock.wiki/Trophy_Collector
20. https://deadlock.wiki/Extra_Spirit (2025-05-08 price change 500→800)
21. https://deadlock.wiki/Refresher (2025-05-08 price change 6000→6400)
22. https://deadlock.wiki/Flex_Slots
23. https://deadlock.wiki/Curiosity_Shop
24. https://deadlock.wiki/Boons
25. https://deadlock.wiki/Extended_Magazine
26. https://deadlock.wiki/Titanic_Magazine
27. https://deadlock.wiki/Headshot_Booster
28. https://deadlock.wiki/Toxic_Bullets
29. https://deadlock.wiki/Glass_Cannon
30. https://deadlock.wiki/Extra_Health
31. https://deadlock.wiki/Healing_Rite
32. https://deadlock.wiki/Fortitude
33. https://deadlock.wiki/Warp_Stone
34. https://deadlock.wiki/Unstoppable
35. https://deadlock.wiki/Improved_Spirit
36. https://deadlock.wiki/Boundless_Spirit
37. https://deadlock.wiki/Mystic_Burst
38. https://deadlock.wiki/Imbue
39. https://forums.playdeadlock.com/threads/04-30-2026-update.129989/ (investment rescale; boon change)
40. https://tracklock.gg/articles/deadlock-update-04-30-26 ; https://liquipedia.net/deadlock/Patch_2026-04-30
41. https://github.com/deadlock-api/deadlock-api (API project; rate-limit notes)

---

## Verification log (2026-09-27)

Adversarial re-check against public sources only: deadlock.wiki pages, official forum patch notes, deadlock.one patch mirror, a web search against tracklock / liquipedia, and the public community JSON API at api.deadlock-api.com (`/v1/assets/generic-data`, `/v1/assets/items`; community-datamine). No game files, memory or network traffic were inspected.

| # | Claim | Checked against | Outcome |
|---|---|---|---|
| 1 | Starting souls 600 | wiki Souls; Souls/Update_history (400→600, Nov 2025) | Confirmed |
| 2 | Trooper bounty 100 + 2/min; flying orb 50% | wiki Update:June_30,_2026 (116+1.16 → 100+2; 40% → 50%); wiki Souls | Confirmed |
| 3 | Trooper share array 1/.54/.36/.25/.20/.16 | API generic-data `trooper_kill_gold_share_frac`; wiki Souls table | Confirmed |
| 4 | Hero kill share 1.25/.575/.283/.175/.11/.083 | API `hero_kill_gold_share_frac`; wiki (rounded) | Confirmed |
| 5 | Hero kill 200 + 50/min, cap 2200 @ 40 min; first blood 125 | June 30 2026 notes (250→200, 150→125); wiki Souls | Confirmed |
| 6 | Sharing radii 45 m / 30 m; ground orb 18→40 s | wiki Souls; Update_history (Nov 2025) | Confirmed |
| 7 | Unsecured drop threshold 50 + 5/min; conversion 0.5%/s + 1.6/s (8%/min) | June 30 2026 notes; Update_history (Dec 2025) | Confirmed (compounding vs linear still open) |
| 8 | Comeback: +126.8% kill, +26% income, 3000 deadzone, 20% peak, 70% redirect | wiki Souls; 09-16-2026 notes via deadlock.one | Confirmed. Note: May 2025 value was +25%, now +26% |
| 9 | Tick gold 2.5% / 1.5% after 8:00 | wiki Souls; Update_history (Dec 2024) | Confirmed |
| 10 | Objective split 25% near; Guardian 1375; Walker 3675; Base Guardians 1000; Shrines 2000; Patron P1 0 | API generic-data; 09-16-2026 notes (30→25%, Guardian +10%, Walker +5%) | Confirmed |
| 11 | Mid-Boss 3000 + 50/min; respawn 7/6/5 | wiki Mid-Boss | Confirmed (the wiki does not state the split rule; "equal split" is still an assumption) |
| 12 | Neutral bounties 41/68/181 +0.44/0.73/1.95 per min; spawn/respawn times; HP | wiki Neutrals (1.08% of base per min) | Confirmed |
| 13 | Sinner's Sacrifice value/HP/payouts | wiki Sinner's Sacrifice | **Corrected:** the +1 soul applies only on a jackpot. Added jackpot buffs and 80 return damage per hit |
| 14 | Crates 518, 23 + 2/min at 60%, spawn timers (tunnel 5/5 min) | wiki Crates; 09-16-2026 notes | Confirmed |
| 15 | Golden Statue buff table and 50% drop | wiki Golden Statues; 05-22-2026 notes (health 15/20/30) | Confirmed |
| 16 | Unstable Rift 1482 + 222/min from min 13, 20 m, 12 s (6–18), 13 orbs, resist 10% + 1%/min max 40% | wiki KOTH; official 09-16-2026 forum post | Confirmed |
| 17 | Respawn curve 8/38/70/85, cap 90, comeback +6..+22 | wiki Death; 09-16-2026 notes (35→38 s at 20 min) | Confirmed |
| 18 | Soul Urn delivery location, payout, favored rules | wiki Soul_Urn (2026-07-13); June 30 2026 notes | **Corrected:** delivery is at the opposite end of the map, not the middle bridge. Recipient (runner only vs shareable orbs) conflicts between sources and is downgraded to low. Deposit channel times and favored thresholds downgraded to low (probably stale) |
| 19 | Golden Goose Egg 400 + 80/min, buff per 80, −15%, counts to NW | API items; wiki Golden_Goose_Egg; 09-16-2026 notes | Confirmed |
| 20 | Trophy Collector 16/min per stack, 16 stacks, 0.15 m sprint, 0.75% range, −15% vs NPC | API items; wiki Trophy_Collector | Confirmed |
| 21 | Tier prices 800/1600/3200/6400 (+9999 Legendary) | API `item_price_per_tier`; wiki Items; wiki Curiosity_Shop | Confirmed |
| 22 | Slots 9 + 3 (per Walker); 4 actives; sell 50% / 100% undo | wiki Flex_Slots (Nov 21 2025); wiki Items; wiki Curiosity_Shop | Confirmed |
| 23 | Investment tables | wiki Items (increments summed); official 04-30-2026 notes | Cumulative wiki values match the spec for all 3 categories. The official 04-30 weapon list differs from the current wiki at steps 6–10, so a later retune happened; weapon downgraded high → medium |
| 24 | Item counts per tier; active count 50 | API items (shopable, by slot type and tier) | Per-tier counts match the API, but the wiki differs on 3 cells (downgraded to medium). **Corrected:** the active count is 44 for T1–T4 (50 included 6 Street Brawl Legendaries) |
| 25 | Boon cap 40k vs 49.2k | wiki Update:April_30,_2026 (quoted change); web search against tracklock / liquipedia | Resolved in favor of 40k (official). The wiki Boons table is stale above 13.2k. Changed low → medium |

**Not independently verified (kept, flagged):** Soul Well 10 souls / 2 s after 2:30 (wiki Souls only; the July 28 2026 date was not re-fetched), deny recipient, the flying-orb 80 ms / 1 s timings (wiki only), the Refresher resist conflict (the API still lists 15% bullet / 14% spirit), and the Urn carrier's extra sprint for the trailing team.

**Legality pass:** no verbatim passages longer than about 15 words, no lore, voice lines or art were found. The item table uses generic, paraphrased numeric stats. Datamined values come only from the public community API and are tagged community-datamine. Nothing in the spec comes from the author extracting game files. The open-question tests use only in-game observation and the player-facing console in private lobbies, which is allowed. Nothing was removed.
