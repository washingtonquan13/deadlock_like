# Map & Objectives Spec

> Clean-room observation record. Describes observed behavior of Deadlock (Valve) for the purpose of independent reimplementation. No game code or assets were used.

## Summary

Deadlock is a 6v6 third-person hero shooter/MOBA. Since the Map Rework (2025-02-25) the map has **3 lanes** (was 4): Yellow ("York", outer), Blue ("Broadway", middle) and Green ("Park/Greenwich", outer). The map is mirror-symmetric across the horizontal midline (team 0 bottom, team 1 top).

Each lane holds this structure chain per team, from mid outward to the base:

- **Lane Guardian** (Tier 1)
- **Walker** (Tier 2)
- **2 Base Guardians** (Tier 3)

Each base has **2 Shrines**, then the **Patron**. The Patron has 2 phases, and the match is won by killing the **Weakened Patron** (phase 2).

Troopers spawn in waves every 30/25/20 s (by match time) and ride team ziplines to the front line.

Neutral objectives:

- **Mid-Boss**: grants the **Rejuvenator** revive buff.
- **Soul Urn**: a carry-to-deliver objective.
- **Unstable Rift**: a king-of-the-hill objective added 2026-06-30.
- **Powerups**, **neutral camps**, **Sinner's Sacrifice vaults**, **crates** and **Golden Statues**.

Verticality comes from ziplines, ropes, jump pads, stairs, rooftops, tunnels and vents, plus 2 underground teleporter pairs.

Structures carry anti-cheese rules:

- time-scaling damage resist (Guardians and Walkers)
- enemy-count-scaling bullet resist (Walkers, Base Guardians, Shrines)
- **backdoor protection**: DR and regen when no enemy troopers are near

Average match length in the public API sample (normal mode, since about 2026-08-17) is **about 38.4 min**.

Unit note: the game uses Source 2 units; 1 m ≈ 39.37 units. The wiki quotes metres (m) and m/s. Values tagged community-datamine come from third-party parsing of public patch data (deadlock-api.com, deadlock.wiki templates); this project did NOT parse any game files.

## Mechanics

### Lanes and layout
- Team size is 6v6. There are 3 lanes, per the Map Rework of 2025-02-25 (it was 4 lanes before). Street Brawl is a separate single-lane mode.
- Each team has one zipline per lane. Players spawn in a base spawn room and start the match attached to their lane zipline.
- The middle lane (Blue) has the slowest zipline, 18 m/s. The outer lanes are 21 m/s.
- Per team per lane, the structure order walking from mid to base is: Guardian, then Walker, then 2 Base Guardians. Next come the 2 Shrines in the base, then the Patron.
- Shops (10 total):
  - 2 base shops, whose buy radius covers the whole spawn room.
  - 6 side shops, one per lane per team. A side shop closes permanently when that lane's Guardian dies.
  - 2 neutral underground "secret" shops, located between Blue and each outer lane.
- Spawn room:
  - Heals allies 6% max HP + 60 HP per second.
  - Has 4 invulnerable base turrets.
  - Soul well starts at 3:00 per the map page (verified 2026-09-27; an earlier draft said 2:30, which no source found supports). Orb size and rate are unverified.
- Juke rooms are dead-end rooms with a vision-blocking veil at the entrance.
- Rooftops have lightning towers that punish camping. There are 2 zones:
  - A larger zone that only hits grounded players.
  - A zone within about 5 m above the tower that always hits.
- Map rework history relevant to layout:
  - 2025-04-04: the outer-lane teleporters were removed.
  - 2025-05-08: teleporters became available from 0:00.
  - 2025-07-29: the teleporters behind the Walkers were removed.
  - 2026-03-06: 2 neutral camps were added near specific Walkers.

### Abstract map topology (for reimplementation)
```
                 [Team1 Patron pit / Weakened Patron]
                 [Shrine] [Shrine]      (T1 base, spawn room + 4 turrets + shop)
       Y-BG x2          B-BG x2           G-BG x2      (Base Guardians)
       Y-Walker         B-Walker          G-Walker
       Y-Guardian       B-Guardian        G-Guardian   (side shop each)
   ---- Yellow bridge ---- MID (Mid-Boss sewer pit, Blue lane access) ---- Green bridge ----   (Urn/Rift/Powerups on bridges)
       Y-Guardian       B-Guardian        G-Guardian
       Y-Walker         B-Walker          G-Walker
       Y-BG x2          B-BG x2           G-BG x2
                 [Shrine] [Shrine]      (T0 base)
                 [Team0 Patron pit]
   Underground: 2 secret shops + 2 teleporter pairs between Blue and the outer lanes; tunnels/vents.
```
- Minimap-relative positions from the API map endpoint, with the map as a unit square, left = x and top = y, team0 at the bottom:

  | Structure | left (x) | top (y), team0 | top (y), team1 |
  |---|---|---|---|
  | Tier-1 Guardians | 0.21 / 0.45 / 0.69 | 0.53 | 0.39 |
  | Walkers | 0.25 / 0.45 / 0.65 | 0.67 | 0.25 |
  | Patrons | 0.45 | 0.79 | 0.11 |
  | Weakened-Patron "core" | 0.35 | 0.93 | 0.0 |

- Zipline polyline lengths are computed from the API spline control points (community-datamine):
  - Blue lane: about 687 m base-to-base, with ±37 m lateral wiggle.
  - Each outer lane: about 812 m, curving out to about ±209 m lateral.
  - All lanes span ±293 m along the long axis. Zipline height is 19–38 m above map origin.
- Map radius is 10752 units (≈273 m).

### Trooper waves
- Waves spawn in every lane for both teams:
  - every 30 s from 0:00 to 20:00
  - every 25 s from 20:00 to 35:00
  - every 20 s after 35:00
- Composition:
  - 0:00–5:00: 3 Ranged + 1 Medic.
  - After 5:00: 2 Ranged + 1 Melee + 1 Medic.
- Troopers ride the team zipline in a vessel (1 HP) that enemies can shoot down, then walk the lane. The zipline extends as far as the lane is pushed.
- Stats and bounty are in the Values table. Bounty is split 50% into an undeniable ground orb and 50% into a deniable floating orb. A melee last hit gives 100% instantly.
- Per-target damage and resist multipliers mean troopers hurt objectives much more than heroes do, per trooper.
- Scaling:
  - Spirit resist 20% at 25 min, 70% at 50 min.
  - +50% HP at 35 min.
  - +35% DR near or in the enemy base.
- Medic heal pack: (13% missing HP + 150 + 2/min) ÷ nearby heroes, 35 m radius. Enemies must pick it up.
- Super Troopers: after an enemy Shrine dies, troopers in that lane get +60% damage and +40% HP and yield 15% less bounty. Blue lane gets them only after both shrines die (a 2026-03-06 note conflicts, see Open questions).
- Rift Troopers (reward from the Unstable Rift):
  - At least 5 spawn, 0.5 s apart. They give no souls.
  - First rift: +100% HP and damage, 25% melee resist, 30% spirit resist.
  - Each later rift adds +20% HP/damage (capped at 160%) and +5% spirit resist (capped at 45%).
  - A trailing team gets up to +9 extra.
- Targeting and aggro (sparse public detail):
  - Troopers walk the lane and attack the nearest enemy trooper, hero or structure in sight. Sight is 41 m vs NPCs and 18 m vs heroes.
  - Players cannot pull troopers off a Guardian they are attacking.
  - Parry stuns troopers.
  - Whether troopers re-aggro onto heroes who damage allied heroes is undocumented (see Open questions).

### Lane Guardian (Tier 1)
- Stationary. It has a melee swipe (5 m) that can be parried; a parry stuns it 2 s and blocks its melee for 5 s.
- It has a headshot weak point (brazier). It has no backdoor protection.
- It is invulnerable when no enemy is within 24 m, and cannot be damaged by players outside its attack range.
- Targeting: it attacks the closest enemy, but switches to an enemy who damages an allied hero within 15 m.
- Time DR: +50% at 0:00, falling linearly to -50% at 12:00, then flat. Heroes additionally get -25% bullet resist against it.
  - Wiki formula for bullet damage BD: `BD * (0.5 + t/720) * 1.25 * 0.9`, with t in s, clamped at 12:00.
- Its death closes that team's side shop in that lane.

### Walker (Tier 2)
- Can only be damaged after its lane Guardian dies. It is immune when no enemy is within 22 m.
- Base HP 6000. When other Walkers of the same team die, the remaining ones grow to 9000, then 12000, and heal.
- Time DR: +65% falling to -65% over 18 min. It also gets extra weapon resist when many attackers are within 51 m: 20% at 3 enemies, rising to 50% at 6.
- Aura: allied heroes within 28 m get +15% bullet and +15% spirit resist.
- Attacks:
  - Fire Beam: 2% max HP per second, spirit damage.
  - Stomp: 350 + 15% max HP, 15 m radius, 2 s stun, 7 s cooldown.
  - Rocket barrage: 6 × 200 damage, leaves a fire pool (25/s for 5 s, -10% resists), 10 s cooldown.
- Has backdoor protection.
- Each Walker kill grants every player on the killing team 1 Extra item slot (up to 3). Base slots have been 9 since 2025-11-21.

### Base Guardians (Tier 3)
- 2 per lane per team. They have a non-parryable melee and no headshot weak point.
- Enemy-scaling bullet resist: 40%, minus 20% per nearby enemy hero.
- Has backdoor protection.
- When both in a lane die, the killing team gets a permanent +80% "Express" zipline in that lane.

### Shrines
- 2 per base. HP is 5000 each; the second becomes 10000 after the first dies (2026-03-06).
- Invulnerable until at least one lane's pair of Base Guardians is dead (2026-05-22). Cannot be damaged from off its platform.
- Enemy-scaling resist: 60%, minus 20% per hero. Reportedly buggy.
- Has backdoor protection.
- Killing one gives the attackers Super Troopers.
- Both must die to make the Patron vulnerable.

### Backdoor protection
- Applies to Walkers, Base Guardians, Shrines and the Patron while no enemy troopers are near the structure (about 40 m, community-datamine).
- Grants DR and HP regen. The regen only restores HP lost while protected.
- Base structures lose protection if any enemy zipline is pushed up to the base.
- There is a 14 s buffer before protection re-applies after troopers leave.
- Destroying a protected structure snaps that team's zipline forward.

### Patron (two phases) and win condition
- Phase 1:
  - HP 12000, growing +250/min from 20:00.
  - Invulnerable until both Shrines die.
  - Out-of-combat regen 120 HP/s after 20 s. Backdoor adds +75 HP/s.
  - Laser: 440 + 5% target HP per second, range 76 m, -10% resists, leaves burning ground.
  - Shrine Defense: after a 3.5 s delay, 300 + 20% HP damage plus a curse.
- On phase-1 death:
  - A constant 12 s death sequence plays (2025-09-04). There is a brief invulnerability, then it reforms as an orb in the pit.
  - "Last Stand" adjusts dead defenders' timers: those with ≥30 s left get -20 s; those with 10–30 s left are set to 10 s; those with ≤10 s left are unchanged.
- Phase 2 (Weakened Patron):
  - HP 12000, growing +450/min starting 1 min into phase 2.
  - Immune to damage from outside the pit.
  - Defender DR: 50% if 1 defender has stood in the pit for more than 2 s; 100% with 2 or more defenders (2025-12-17).
  - Damage Pulse: 75/s to up to 3 enemies within 19 m.
  - Pit Explosion: 300 + 20% HP after a 3.5 s delay, 15 s cooldown.
- **Win condition**: reduce the Weakened Patron to 0 HP.

### Mid-Boss and Rejuvenator
- Spawns at 0:00 (2026-05-22) in the central sewer pit, entered from the Blue lane.
- Only damageable from inside the pit. It targets the closest player in the pit.
- It has a regenerating shield. It roars at 50% HP, which is a global alert.
- Respawns 7 min after the first kill, then 6, then 5.
- Kill reward is split across the killing team: 3000 + 50/min souls, plus 2 permanent stat buffs per player.
- Rejuvenator crystal:
  - Descends for 6 s.
  - Each heavy melee hit grants 1 credit, up to 3. Either team can steal credits.
  - The first player to hit it is fully healed.
- Buff: lasts 3 min (2026-06-30), with a warning at 30 s left. A dead player with the buff revives in place after 3 s at 100% HP, consuming one team credit (max 1 per player).
  - Kills on reviving players give no souls.
  - Reviving players do not contest objectives.
  - The stat bonuses were removed 2025-11-21.

### Neutral camps
- 3 tiers (Small / Medium / Large), plus Sinner's Sacrifice vaults and tunnel cockroaches.
- Camp souls are split evenly among all damagers and are unsecured (lost on death if above the threshold).
- Camp respawn timer starts when the last unit of the camp dies.
- Some camps start burrowed (invulnerable) and unburrow when a player approaches. Units have weak-point crits (eye).
- Scaling from match start: HP +2.1%/min, damage +0.5%/min, bounty +1.08% of base per min.
- Sinner's Sacrifice:
  - A melee-only slot machine. Each hit costs the hitter 80 damage.
  - Pays a fraction of its bounty per hit.
  - After 400 damage a jackpot timing window runs. A light-melee kill in the window gives 1 buff; a heavy-melee kill gives 4.

### Soul Urn (reworked 2026-06-30 / 2026-07-09)
- Spawns at 10:00, then every 5 min, alternating Yellow and Green bridges (Yellow first). It descends for 12.5 s.
- Picked up with melee. It must be delivered to the drop point on the opposite side of the map.
- If no one picks it up for 3 min, it walks slowly toward the drop via the mid stairs.
- Carrier restrictions and buffs:
  - Buffs: +2 m/s move speed, +1 stamina, +10% dash distance, +25% stamina regen, 100% slow resist.
  - Cannot use ziplines or teleporters. Cannot parry.
  - Drops the Urn on enemy melee, stun or death.
- A trailing-team carrier also gets resists and +5 m/s sprint, scaling with net-worth deficit.
- Reward value is locked at spawn. It decays after 45 s held and expires after 45 s more. It is paid as deniable orbs, plus 4 stat buffs.

### Unstable Rift (added 2026-06-30)
- Appears on a random side lane's bridge. First at 11:00 ± 1 min, then every 7 ± 1 min.
- Sequence: visual effect, then a global announcement 60 s later (wiki, re-checked 2026-09-27; a 40 s variant is unsourced), then the capture opens 20 s after that.
- Capture zone: radius 20 m, takes 12 s. Progress is not faster with more players. A contested zone does not progress. Players in the zone are revealed.
- Trailing team (up to 15% net-worth deficit):
  - Captures in 6 s, while the leader needs 18 s.
  - Gets a resist aura within 35 m: 10% + 1%/min, capped at 40% at 30 min (2026-09-16; was a flat 35%).
- Reward: bounty split equally across the team, plus Rift Troopers.
- If contested for 60 s (warning at 50 s), the souls burst into 13 orbs.

### Powerups
- 2 bridge spawn locations. First spawn at 5:00, then every 5:00.
- Claimed by heavy melee. Lasts 160 s and is lost on death.
- 4 types: Casting, Gun, Movement, Survival. Values scale linearly from 5 to 40 min.
- The 10:00 spawn guarantees the 2 types that did not appear at 5:00.

### Breakables and stat buffs
- Crates:
  - 518 on the map. Spawn at 3:00 (2026-05-22), respawn every 3 min.
  - 60% chance to drop 23 + 2/min unsecured souls.
- Golden Statues: 50% chance to drop a permanent stat buff.
- Exceptions:
  - The room above Mid spawns its breakables at 10:00.
  - Tunnel breakables spawn at 5:00 and respawn every 5:00 (2026-09-16).
- Stat buff types:
  - 6 types, pseudo-random: fire rate, ammo, CDR, weapon damage, HP and spirit.
  - Each type has a 1/7 chance, except HP at 2/7.
  - Buff level is L1 before 10:00, L2 from 10:00 and L3 from 30:00.

### Teleporters, ziplines, ropes, jump pads and verticality
- Teleporters: 2 underground pairs next to the secret shops. 4 s channel, then +3 m/s for 5 s on arrival. Available from 0:00.
- Zipline rules:
  - Speed boost: +80% for 32 s, 360 s cooldown, unlocks at 6:00.
  - Taking enemy hero or structure damage blocks attaching for 3 s.
  - Being knocked off deals 15% max HP and a 2.5 s stun, starting on landing.
  - After 3 s of riding, the rider cannot be knocked off but takes +53.6% damage ("Hyperline").
  - Dropping off keeps momentum for 2 s.
- Ropes:
  - Melee on a climber slows it 80%, decaying to 20% over 2 s.
  - Climbing is 40% slower if the climber took hero damage in the last 4 s.
- Jump pads:
  - Taking damage within 0.6 s of launch (2025-10-24 value; the 0.9 s figure on the same wiki page is older text) stuns until 0.2 s after landing.
  - This is followed by a 30% slow for 2 s and 15% max HP damage.
- Tunnels and vents:
  - +70% move speed in tunnels. Entry is blocked for 4 s after combat.
  - Vents are usable only by certain heroes.
  - Cockroaches: 1 soul each, 30 s respawn.

### Respawn, match start and match length
- Respawn timer interpolates linearly between these points:
  - 8 s at 5 min
  - 38 s at 20 min (2026-09-16)
  - 70 s at 30 min
  - 85 s at 40 min
  - capped at 90 s
- Respawn penalties:
  - +10 s if killed by a non-player unit.
  - After 10 min, rich players get a comeback penalty of +6 s up to +22 s.
- Unsecured souls drop in a container on death if they are at least 50 + 5/min.
- Starting souls are 600. The laning phase ends at 8:00, after which catch-up soul trickle applies.
- Match timeline:

  | Time | Events |
  |---|---|
  | 0:00 | Mid-Boss, waves, teleporters |
  | 2:00 | small camps |
  | 3:00 | soul well (was listed as 2:30; corrected) |
  | 3:00 | crates |
  | 5:00 | melee troopers, powerups, medium camps, tunnel breakables |
  | 6:00 | zipline boost unlocks |
  | 8:00 | large camps, vaults, end of laning |
  | 10:00 | Urn, L2 buffs, mid-room breakables |
  | ~11:00 | Rift |
  | 12:00 | Guardians at minimum resist |
  | 18:00 | Walkers at minimum resist |
  | 20:00 | 25 s waves, Patron HP growth |
  | 30:00 | L3 buffs |
  | 35:00 | 20 s waves, trooper +50% HP |

- Average match duration is about 2307 s (38.4 min) over about 1.77M normal-mode matches since about 2026-08-17. Median and distribution are not fetched.

## Values

| Parameter | Value | Units | Source type | Patch/date | Confidence | Source |
|---|---|---|---|---|---|---|
| Players per team | 6 | players | wiki | 2026 | high | [1] |
| Lane count | 3 | lanes | official | 2025-02-25 | high | [1][35] |
| Lane count before rework | 4 | lanes | wiki | pre-2025-02-25 | high | [1] |
| Zipline speed, middle lane | 18 | m/s | wiki | 2026 | high | [19] |
| Zipline speed, outer lanes | 21 | m/s | wiki | 2026 | high | [19] |
| Zipline speed boost | +80 | % | wiki | 2026 | high | [19] |
| Zipline boost duration | 32 | s | wiki | 2026 | high | [19] |
| Zipline boost cooldown | 360 | s | wiki | 2026 | high | [19] |
| Zipline boost unlock | 6:00 | mm:ss | wiki | 2026 | high | [19] |
| Express zipline after both BGs die | +80 | % speed | wiki | 2026 | high | [5][19] |
| Zipline attach block after damage | 3 | s | wiki | 2026 | high | [19] |
| Zipline knock-off damage | 15 | % max HP | wiki | 2026 | high | [19] |
| Zipline knock-off stun | 2.5 | s | wiki | 2026 | high | [19] |
| Zipline knock-off immunity after riding | 3 | s | wiki | 2026 | med | [19] |
| Hyperline extra damage taken | 53.6 | % | wiki | 2026 | med | [19] |
| Zipline drop momentum preserve | 2 | s | wiki | 2026 | med | [19] |
| Trooper zipline vessel HP | 1 | HP | community-datamine | 2026 | med | [2] |
| Blue lane zipline length | ~687 | m | community-datamine | 2026-09 | med | [31] |
| Outer lane zipline length | ~812 | m | community-datamine | 2026-09 | med | [31] |
| Lane long-axis extent | ±293 | m | community-datamine | 2026-09 | med | [31] |
| Outer lane max lateral offset | ~209 | m | community-datamine | 2026-09 | med | [31] |
| Zipline height range | 18.6–38.2 | m | community-datamine | 2026-09 | med | [31] |
| Map radius | 10752 (≈273) | units (m) | community-datamine | 2026-09 | med | [31] |
| Shops total | 10 | count | wiki | 2026 | high | [27][1] |
| Side shops | 6 (1/lane/team) | count | wiki | 2026 | high | [1] |
| Secret shops | 2 | count | wiki | 2026 | high | [27] |
| Item tier costs | 800/1600/3200/6400 | souls | wiki | 2026 | high | [1] |
| Spawn room heal | 6% + 60 | %maxHP + HP per s | wiki | 2026 | high | [1] |
| Base turrets per spawn | 4 | count | wiki | 2026 | high | [24] |
| Base turret max DPS | 288 | dmg/s | wiki | 2026 | med | [24] |
| Base turret per-shot damage | 144 | dmg | wiki | 2026 | med | [24] |
| Base turret cone | 90 | deg | wiki | 2026 | med | [24] |
| Soul well start | 3:00 (old draft: 2:30, unsupported) | mm:ss | wiki | 2026 | med | [1] |
| Soul well orb | 10 souls / 2 s (not found on map page 2026-09-27) | souls, s | wiki | 2026 | low | [1] |
| Lightning tower damage | 10% max HP / 2 s | true dmg | wiki | 2026 | med | [1] |
| Lightning tower strike delay | 1 | s | wiki | 2026 | med | [1] |
| Lightning tower always-hit height | ~5 | m | wiki | 2026 | low | [1] |
| Teleporter pairs | 2 | pairs | wiki | 2025-07-29 | high | [20] |
| Teleporter channel | 4 | s | wiki | 2026 | high | [20] |
| Teleporter exit speed buff | +3 / 5 | m/s / s | wiki | 2026 | med | [20] |
| Teleporter available from | 0:00 | mm:ss | wiki | 2025-05-08 | high | [20] |
| Jump pad damage-stun window | 0.6 (was 0.9 -> 0.6; 0.9 is older text) | s | wiki | 2025-10-24 | med | [21] |
| Jump pad post-landing slow | 30% for 2 s | %, s | wiki | 2026 | med | [21] |
| Jump pad interrupt damage | 15 | % max HP | wiki | 2026 | med | [21] |
| Rope melee slow | 80 → 20 over 2 s | % | wiki | 2026 | med | [22] |
| Rope climb penalty after hero dmg | -40% for 4 s | %, s | wiki | 2026 | med | [22] |
| Tunnel move speed bonus | +70 | % | wiki | 2026 | med | [23] |
| Tunnel entry block after combat | 4 | s | wiki | 2026 | med | [23] |
| Cockroach bounty / respawn | 1 / 30 | souls / s | wiki | 2026 | med | [23] |
| Bug camp spawn / interval | 120 / 120 | s | community-datamine | 2026-09 | med | [32] |
| Wave interval 0–20 min | 30 | s | wiki | 2026 | high | [2] |
| Wave interval 20–35 min | 25 | s | wiki | 2026 | high | [2] |
| Wave interval 35+ min | 20 | s | wiki | 2026 | high | [2] |
| Wave comp 0–5 min | 3 ranged + 1 medic | units | wiki | 2026 | high | [2] |
| Wave comp 5+ min | 2 ranged + 1 melee + 1 medic | units | wiki | 2026 | high | [2] |
| Ranged trooper HP | 300 | HP | wiki | 2026 | high | [2] |
| Ranged trooper DPS vs heroes | 28 | dmg/s | wiki | 2026 | high | [2] |
| Ranged trooper range | 25 | m | wiki | 2026 | high | [2] |
| Ranged trooper melee | 25 | dmg | wiki | 2026 | med | [2] |
| Trooper bullet damage | 36 | dmg | community-datamine | 2026-09 | med | [30] |
| Trooper weapon cycle | 1.03 | s | community-datamine | 2026-09 | med | [30] |
| Trooper walk speed | 6.3 (248 u/s) | m/s | wiki | 2026 | high | [2][30] |
| Trooper sprint speed | 13 | m/s | wiki | 2026 | med | [2] |
| Melee trooper HP | 400 | HP | wiki | 2026 | high | [2] |
| Melee trooper damage | 80 | dmg | wiki | 2026 | high | [2] |
| Melee trooper range | 3 | m | wiki | 2026 | med | [2] |
| Melee trooper walk speed | 8.1 | m/s | wiki | 2026 | med | [2] |
| Medic trooper HP | 350 | HP | wiki | 2026 | high | [2] |
| Medic trooper DPS | 28 | dmg/s | wiki | 2026 | med | [2] |
| Medic trooper range | 36 (1400 u) | m | wiki | 2026 | med | [2][30] |
| Trooper DPS vs troopers | 35 | dmg/s | wiki | 2026 | med | [2] |
| Trooper DPS vs Guardian | 14.4 | dmg/s | wiki | 2026 | med | [2] |
| Trooper DPS vs Walker | 24 | dmg/s | wiki | 2026 | med | [2] |
| Trooper DPS vs Base Guardian | 80 | dmg/s | wiki | 2026 | med | [2] |
| Trooper DPS vs Shrine | 50 | dmg/s | wiki | 2026 | med | [2] |
| Trooper DPS vs Patron | 50 | dmg/s | wiki | 2026 | med | [2] |
| Trooper resist vs hero bullets | -25 | % | wiki | 2026 | med | [2] |
| Trooper resist vs troopers | 42.5 | % | wiki | 2026 | med | [2] |
| Trooper resist vs Walker | 80 | % | wiki | 2026 | med | [2] |
| Trooper resist vs Base Guardian | 67.5 | % | wiki | 2026 | med | [2] |
| Trooper resist vs Patron | 50 | % | wiki | 2026 | med | [2] |
| Trooper spirit resist @25 / @50 min | 20 / 70 | % | wiki | 2026 | med | [2] |
| Trooper DR near enemy base | +35 | % | wiki | 2026 | med | [2] |
| Trooper HP bonus at 35 min | +50 | % | wiki | 2026 | med | [2] |
| Trooper out-of-combat regen | 7 | HP/s | wiki | 2026 | low | [2] |
| Trooper sight vs NPCs | 41 | m | wiki | 2026 | med | [2] |
| Trooper sight vs heroes | 18 (700 u) | m | wiki | 2026 | med | [2][30] |
| Trooper bounty | 100 + 2/min | souls | official | 2026-06-30 | high | [2][37] |
| Trooper bounty (previous) | 116 + 1.16/min | souls | wiki | pre-2026-06-30 | high | [2] |
| Trooper bounty ground/floating split | 50 / 50 | % | wiki | 2026 | high | [2] |
| Ground orb lifetime | 18 → 40 after 10 min | s | wiki | 2026 | med | [2] |
| Floating orb auto-pop | ~1 (0.4–0.7 spawn delay, 0.7 life) | s | community-datamine | 2026-09 | med | [2][32] |
| Trooper soul share by #players 1..6 | 100/54/36/25/20/16 | % each | wiki | 2026 | med | [2] |
| Trooper soul share radius | 45 from orb / 30 from killer | m | wiki | 2026 | med | [2] |
| Medic heal pack | 13% missing + 150 + 2/min | HP | wiki | 2026 | med | [2] |
| Medic pack radius | 35 | m | wiki | 2026 | med | [2] |
| Medic pack pickup range | 18 (10 min) → 30 (18 min) | m | wiki | 2026 | low | [2] |
| Super Trooper damage / HP | +60 / +40 | % | wiki | 2026 | high | [2][6] |
| Super Trooper bounty reduction | -15 | % | wiki | 2026 | med | [2] |
| Rift Troopers minimum count | 5 | units | wiki | 2026-06-30 | med | [14] |
| Rift Trooper spawn spacing | 0.5 | s | wiki | 2026-06-30 | med | [14] |
| Rift Trooper first HP/dmg bonus | +100 | % | wiki | 2026-06-30 | med | [14] |
| Rift Trooper melee / spirit resist | 25 / 30 | % | wiki | 2026-06-30 | med | [14] |
| Rift Trooper per-rift scaling | +20% (cap 160%), +5% spirit (cap 45%) | % | wiki | 2026-06-30 | med | [14] |
| Rift Trooper trailing extra count | up to +9 (14 total) | units | wiki | 2026-06-30 | low | [14] |
| Guardian HP | 5500 | HP | wiki | 2026 | high | [3] |
| Guardian DPS | 116 | dmg/s | wiki | 2026 | high | [3] |
| Guardian range | 34 (1338.58 u) | m | wiki | 2026 | high | [3][30] |
| Guardian bullet resist | 10 | % | wiki | 2026 | high | [3] |
| Guardian time DR start → end | +50 → -50 over 12 min | % | official | 2026-05-22 | high | [3][38] |
| Guardian time DR start (previous) | +75 | % | wiki | pre-2026-05-22 | high | [3] |
| Hero bullet resist penalty vs Guardian/BG | -25 | % | wiki | 2026 | med | [3][5] |
| Guardian invuln radius (no enemy) | 24 | m | wiki | 2026 | med | [3] |
| Guardian retarget radius (ally hero hit) | 15 | m | wiki | 2026 | med | [3][40] |
| Guardian melee range | 5 (196.85 u) | m | wiki | 2026 | med | [3][30] |
| Guardian parry stun / melee lockout | 2 / 5 | s | wiki | 2026 | med | [3] |
| Guardian bounty | 1375 (1500 -> 1250 on 2026-06-30, +10% on 2026-09-16) | souls | wiki | 2026-09-16 | high | [3][36] |
| Walker HP (3 / 2 / 1 alive) | 6000 / 9000 / 12000 | HP | wiki | 2026 | high | [4] |
| Walker time DR | +65 → -65 over 18 min | % | wiki | 2026 | high | [4] |
| Walker bullet resist | 35 | % | wiki | 2026 | med | [4] |
| Walker crowd weapon resist | 20 (3 enemies) → 50 (6) within 51 m | % | wiki | 2026 | med | [4] |
| Walker DPS | 125 | dmg/s | wiki | 2026 | med | [4] |
| Walker range | 24 | m | wiki | 2026 | med | [4] |
| Walker melee | 300 | dmg | wiki | 2026 | med | [4] |
| Walker immune radius (no enemy) | 22 | m | wiki | 2026 | med | [4] |
| Walker ally resist aura | +15 bullet / +15 spirit, 28 m | %, m | wiki | 2026 | med | [4] |
| Walker Fire Beam | 2 | % max HP/s | wiki | 2026 | med | [4] |
| Walker Stomp damage | 350 + 15% max HP | dmg | wiki | 2026 | med | [4] |
| Walker Stomp radius / stun / cd | 15 / 2 / 7 | m / s / s | wiki | 2026 | med | [4] |
| Walker rockets | 6 × 200 | dmg | wiki | 2026 | med | [4] |
| Walker fire pool | 25/s for 5 s, -10% resist | dmg | wiki | 2026 | med | [4] |
| Walker rocket cooldown | 10 | s | wiki | 2026 | med | [4] |
| Walker bounty | 3675 (4000 -> 3500 on 2026-06-30, +5% on 2026-09-16) | souls | wiki | 2026-09-16 | high | [4][36] |
| Extra item slots from Walkers | 1 per kill, max 3 | slots | wiki | 2025-11-21 | high | [25] |
| Base item slots | 9 | slots | wiki | 2025-11-21 | high | [25] |
| Base Guardians per lane per team | 2 | count | wiki | 2026 | high | [5] |
| Base Guardian HP | 4000 | HP | official | 2026-03-10 | high | [5] |
| Base Guardian HP (previous) | 5500 | HP | wiki | pre-2026-03-10 | high | [5] |
| Base Guardian DPS | 116 | dmg/s | wiki | 2026 | med | [5] |
| Base Guardian range | 31.75 | m | wiki | 2026 | med | [5] |
| Base Guardian melee range | 6.35 | m | wiki | 2026 | med | [5] |
| Base Guardian bullet resist | 20 (was 10 before 2026-03-30) | % | wiki | 2026-03-30 | med | [5] |
| Base Guardian enemy-scaling resist | 40 - 20 per nearby hero | % | wiki | 2026 | med | [5] |
| Base Guardian bounty | 1000 | souls | wiki | 2026 | med | [5] |
| Shrines per base | 2 | count | wiki | 2026 | high | [6] |
| Shrine HP (first / second after first dies) | 5000 / 10000 | HP | official | 2026-03-06 | med | [6][39] |
| Shrine datamine max_health_final | 8775 (generator 5000) | HP | community-datamine | 2026-09 | low | [30] |
| Shrine bullet resist | 20 (wiki patch history mentions 10; internally inconsistent) | % | wiki | 2026 | low | [6] |
| Shrine enemy-scaling resist | 60 - 20 per hero | % | wiki | 2026 | low | [6] |
| Shrine bounty | 2000 | souls | wiki | 2026 | med | [6] |
| Backdoor DR (Walker/BG/Shrine) | 65 | % | wiki | 2026 | high | [7] |
| Backdoor regen (Walker/BG/Shrine) | 65 | HP/s | wiki | 2026 | high | [7] |
| Backdoor DR / regen (Patron) | 65 / 75 | % / HP/s | wiki | 2026 | high | [7][8] |
| Backdoor re-apply buffer | 14 | s | wiki | 2026 | med | [7] |
| Backdoor trooper detection range | 1575 (≈40) | units (m) | community-datamine | 2026-09 | med | [30] |
| Patron phase 1 HP | 12000 | HP | wiki | 2026 | high | [8] |
| Patron phase 1 HP growth | +250/min from 20:00 | HP | wiki | 2026 | med | [8] |
| Patron out-of-combat regen (both phases) | 120 after 20 s | HP/s, s | community-datamine | 2026-09 | med | [8][30] |
| Patron laser | 440 + 5% HP per s | spirit dmg | wiki | 2026 | med | [8] |
| Patron laser range | 76 | m | wiki | 2026 | med | [8] |
| Patron Shrine Defense | 300 + 20% HP after 3.5 s | dmg, s | wiki | 2026 | med | [8] |
| Patron phase 1 death sequence | 12 | s | official | 2025-09-04 | med | [8] |
| Last Stand respawn reduction | -20 s if ≥30 s; set 10 s if 10–30 s | s | wiki | 2026 | med | [8] |
| Weakened Patron HP | 12000 | HP | wiki | 2026 | high | [8] |
| Weakened Patron HP growth | +450/min from 1 min into phase 2 | HP | wiki | 2026 | med | [8] |
| Weakened Patron pulse | 75/s, 3 targets, 19 m | dmg, m | wiki | 2026 | med | [8] |
| Weakened Patron pit explosion | 300 + 20% HP, 3.5 s delay, 15 s cd | dmg, s | wiki | 2026 | med | [8] |
| Weakened Patron defender DR | 50 (1 def >2 s) / 100 (2+) | % | wiki | 2025-12-17 | med | [8] |
| Mid-Boss first spawn | 0:00 | mm:ss | official | 2026-05-22 | high | [9][38] |
| Mid-Boss HP | 13000 + 195/min after spawn | HP | wiki | 2026 | med | [9] |
| Mid-Boss regen | 15 | HP/s | wiki | 2026 | low | [9] |
| Mid-Boss bullet / debuff resist | 15 / 35 | % | wiki | 2026 | med | [9] |
| Mid-Boss attack | 20 per hit, 100 DPS | dmg | wiki | 2026 | med | [9] |
| Mid-Boss range | 38 | m | wiki | 2026 | med | [9] |
| Mid-Boss shield | 35 + 5/min, regenerating | HP | wiki | 2026 | low | [9] |
| Mid-Boss respawn (1st/2nd/3rd+) | 7 / 6 / 5 | min | wiki | 2026 | med | [9] |
| Mid-Boss datamine spawn interval | 420 | s | community-datamine | 2026-09 | med | [32] |
| Mid-Boss kill souls | 3000 + 50/min (team) | souls | wiki | 2026 | med | [9] |
| Mid-Boss stat buffs per player | 2 | buffs | wiki | 2026 | med | [9] |
| Avg first Mid-Boss kill time | ~1622 (27 min) | s | community-measurement | 2026-08→09 | med | [34] |
| Rejuvenator descent | 6 | s | wiki | 2026 | med | [10] |
| Rejuvenator credits | 3 (1 per heavy melee) | credits | wiki | 2026 | med | [10] |
| Rejuvenator buff duration | 3 (was 4) | min | official | 2026-06-30 | high | [10][37] |
| Rejuvenator revive delay | 3 | s | wiki | 2026 | med | [10] |
| Rejuvenator revive HP | 100 | % | wiki | 2026 | med | [10] |
| Small neutral HP / dmg / bounty | 129 / 2.42 / 41 | HP / dmg / souls | wiki | 2026 | med | [11] |
| Medium neutral HP / dmg / bounty | 322 / 6.13 / 68 | HP / dmg / souls | wiki | 2026 | med | [11] |
| Large neutral HP / dmg / bounty | 1133 / 9.1 / 181 | HP / dmg / souls | wiki | 2026 | med | [11] |
| Neutral bullet/spirit resist (S, M / L) | 50/45 ; 60/55 | % | wiki | 2026 | med | [11] |
| Large neutral melee damage taken | -20 | % | wiki | 2026 | low | [11] |
| Neutral attack cycle | 0.5 | s | wiki | 2026 | med | [11] |
| Neutral attack range | 38 | m | wiki | 2026 | low | [11] |
| Neutral HP / dmg / bounty growth | +2.1 / +0.5 / +1.08 | %/min | wiki | 2026 | med | [11] |
| Small camps | 4 × 3 units | count | wiki | 2026 | med | [11] |
| Small camp first spawn / respawn | 120 / 85 | s | community-datamine | 2026-09 | high | [11][32] |
| Medium camps | 22 | count | wiki | 2026 | med | [11] |
| Medium camp first spawn / respawn | 300 / 290 | s | community-datamine | 2026-05-22 | high | [11][32][38] |
| Large camps | 12 | count | wiki | 2026 | med | [11] |
| Large camp first spawn / respawn | 480 / 335 | s | community-datamine | 2026-09 | high | [11][32] |
| Vault (Sinner's Sacrifice) count | 10 | count | wiki | 2026 | med | [12] |
| Vault first spawn / respawn | 480 / 300 | s | community-datamine | 2026-09 | high | [12][32] |
| Vault HP | 500 | HP | wiki | 2026 | med | [12] |
| Vault light / heavy melee damage | 50 / 100 | dmg | wiki | 2026 | med | [12] |
| Vault retaliation | 80 | dmg | wiki | 2026 | med | [12] |
| Vault bounty | 310 + 3.35/min | souls | wiki | 2026 | med | [12] |
| Vault jackpot window | 1.3 of 3 s loop, after 400 dmg | s | wiki | 2026 | low | [12] |
| Urn first spawn / interval | 10:00 / 5:00 | mm:ss | wiki | 2026-06-30 | high | [13] |
| Urn descent | 12.5 | s | wiki | 2026-07-09 | med | [13] |
| Urn idle-walk start | 3 | min | wiki | 2026-07-09 | med | [13] |
| Urn carrier move speed | +2 (cap 15) | m/s | wiki | 2026-07-09 | med | [13] |
| Urn carrier stamina / dash / regen | +1 / +10% / +25% | -, %, % | wiki | 2026-07-09 | med | [13] |
| Urn trailing carrier resist | 10% + 1%/min, cap 40% | % | wiki | 2026-07-09 | low | [13] |
| Urn trailing carrier sprint | +5 | m/s | wiki | 2026-07-09 | low | [13] |
| Urn decay / expire | 45 / +45 | s | wiki | 2026-07-09 | med | [13] |
| Urn reward | 250 + 70/min + 4 buffs | souls | wiki | 2026-07-09 | med | [13] |
| Rift first spawn | 11:00 ± 1:00 | mm:ss | official | 2026-06-30 | med | [14][37] |
| Rift interval | 7 ± 1 | min | official | 2026-06-30 | med | [14] |
| Rift warning → announce → open | 60 → +20 (40 s variant unsourced) | s | wiki | 2026-06-30 | med | [14] |
| Rift capture radius | 20 | m | wiki | 2026-06-30 | med | [14] |
| Rift capture time (even / trailing / leader) | 12 / 6 / 18 | s | wiki | 2026-06-30 | med | [14] |
| Rift trailing resist aura | 10% + 1%/min (max 40% at 30 min), 35 m; was flat 35% | % | official | 2026-09-16 | high | [14][36] |
| Rift bounty | 1482 + 222/min from 13 min | souls | wiki | 2026-06-30 | med | [14] |
| Rift contest timeout / orbs | 60 s / 13 | s / orbs | wiki | 2026-06-30 | med | [14] |
| Rift give-up orb lifetime | 25 | s | community-datamine | 2026-09 | med | [32] |
| Powerup first spawn / interval | 300 / 300 | s | community-datamine | 2026-09 | high | [15][32] |
| Powerup duration | 160 | s | community-datamine | 2026-09 | high | [15][32] |
| Powerup pickup radius | 85 (≈2.2) | units (m) | community-datamine | 2026-09 | med | [32] |
| Powerup unclaimed expiry | 300 | s | community-datamine | 2026-09 | med | [32] |
| Powerup scaling window | 5 → 40 | min | community-datamine | 2026-09 | high | [32] |
| Casting powerup | +15→65 spirit, +12→20% CDR | - | community-datamine | 2026-09 | high | [15][32] |
| Gun powerup | +12→35% fire rate, +35→70% ammo | % | community-datamine | 2026-09 | high | [15][32] |
| Movement powerup | +2→4 stamina, +1.5→4 m/s sprint | -, m/s | community-datamine | 2026-09 | high | [15][32] |
| Movement powerup regen / zipline | +20→50% / +40→80% | % | wiki | 2026 | med | [15] |
| Survival powerup | +200→750 HP, +4→40 regen | HP, HP/s | community-datamine | 2026-09 | high | [15][32] |
| Crate count | 518 | count | wiki | 2026 | low | [16] |
| Breakable first spawn / respawn | 180 / 180 | s | community-datamine | 2026-05-22 | high | [16][32] |
| Crate soul drop chance | 60 | % | community-datamine | 2026-09 | high | [16][32] |
| Crate soul drop | 23 + 2/min | souls | wiki | 2026 | med | [16] |
| Statue buff drop chance | 50 | % | community-datamine | 2026-09 | high | [17][32] |
| Buff level 2 / 3 time | 10 / 30 | min | community-datamine | 2026-09 | high | [17][32] |
| Buff L1 fire rate/ammo/CDR/wpn/HP/spirit | 1.5/3/0.5/3/15/2 | %,%,%,%,HP,- | wiki | 2026-06-11 | med | [17] |
| Buff L2 | 2/5/0.75/4/20/3 | same | wiki | 2026-06-11 | med | [17] |
| Buff L3 | 2.5/7/1/6/30/4 | same | wiki | 2026-06-11 | med | [17] |
| Buff type weights | 1/7 each, HP 2/7 | prob | wiki | 2026 | med | [17] |
| Respawn @5 / 20 / 30 / 40 min | 8 / 38 / 70 / 85 (20 min was 35) | s | official | 2026-09-16 | high | [18][36][42] |
| Respawn cap | 90 | s | wiki | 2026 | med | [18] |
| Respawn penalty if killed by NPC | +10 | s | wiki | 2026 | med | [18] |
| Rich-player respawn penalty | +6 → +22 after 10 min | s | wiki | 2026 | low | [18] |
| Unsecured soul drop threshold | 50 + 5/min | souls | wiki | 2026 | med | [18] |
| Starting souls | 600 | souls | wiki | 2026 | high | [26] |
| Hero kill bounty | 200 + 50/min, cap 2200 | souls | wiki | 2026 | med | [26] |
| First blood bonus | 125 | souls | wiki | 2026 | med | [26] |
| Objective split nearby / team | 25 / 75 (history: 40 -> 30 on 2026-07-09, 30 -> 25 on 2026-09-16) | % | official | 2026-09-16 | high | [26][36][42] |
| Comeback soul bonus | up to +26 | % | wiki | 2026 | low | [26] |
| Laning phase end | 8:00 | mm:ss | wiki | 2026 | med | [26] |
| Catch-up trickle lowest two | 2.5 / 1.5 | % team souls/s | wiki | 2026 | low | [26] |
| Avg match duration (normal) | 2307 (38.4) | s (min) | community-measurement | 2026-08-17→09-27 | high | [34] |
| Avg trooper souls per player per match | ~10829 | souls | community-measurement | 2026-08→09 | med | [34] |
| Avg neutral souls per player per match | ~5386 | souls | community-measurement | 2026-08→09 | med | [34] |
| Avg last hits per player | ~180 | kills | community-measurement | 2026-08→09 | med | [34] |
| Avg final net worth per player | ~44226 | souls | community-measurement | 2026-08→09 | med | [34] |
| Street Brawl lane count field | 4 | index/count | community-datamine | 2026-09 | low | [33] |

## Open questions / needs in-game measurement

All measurements are for a **private sandbox / hero-test / bot lobby** that you host. Use `sv_cheats 1` where the game allows it; this is an in-client developer console, not a memory or network inspection. Useful commands:

- `host_timescale`
- `npc_create <unit>`, e.g. `npc_create trooper_melee`
- `citadel_force_spawn_idol` (Urn)
- `citadel_koth_dev_test_spawn` (Rift)
- `god`
- `noclip`
- `cl_showpos 1` for position readout
- `net_graph`, or the in-game damage numbers

Confirm exact command names in-client, and never use them in matchmaking.

1. **Trooper aggro rules.** Do troopers switch to a hero who damages an allied hero? What is the priority order among troopers, heroes and structures?
   - Method: spawn allied and enemy troopers with `npc_create`. Have a bot hero shoot an allied hero near enemy troopers and watch their target. Repeat with a hero shooting troopers vs structures.
2. **Wave spawn offset and first-wave time.** When is the exact first wave (0:00 or delayed)? Do all 3 lanes spawn in sync?
   - Method: bot match, record timestamps of trooper spawns per lane with a screen timer at `host_timescale 1`.
3. **Lane walking distance and trooper meet points.** At what time do first waves collide per lane?
   - Method: `cl_showpos 1` at spawn, at meet point and at each structure. Compare against the API spline lengths (~687 m / ~812 m).
4. **Pre-game countdown length** (warm-up before 0:00).
   - Method: stopwatch in a private lobby from load-in to 0:00.
5. **Shrine HP conflict.** The wiki says 5000 then 10000; the datamine says 8775 max_health_final.
   - Method: sandbox, destroy Base Guardians with `god` on, then read the shrine health bar and its change after killing the first shrine.
6. **Objective soul split.** Largely resolved 2026-09-27: official 09-16-2026 notes set nearby share 30% -> 25% (rest split across all 6); the Walker page's 40/60 is stale (pre-2026-07-09). Still worth confirming the Guardian (whole-team equal split?) behaviour in-game.
   - Method: 2 heroes per team in a bot lobby, one near and one far. Kill a Guardian and read each soul counter delta.
7. **Guardian retarget details.** The 15 m ally-damage switch: does it include spirit damage? Is there a switch cooldown?
   - Method: sandbox with an enemy bot and ally bot under the Guardian. Log which unit is targeted per shot.
8. **Exact neutral camp compositions and positions** (22 medium camps in 6 compositions).
   - Method: sandbox at `host_timescale 4` past 8:00. Use noclip to visit each camp and record unit counts and `cl_showpos`.
9. **Rift announcement timing** (wiki says 60 s; 40 s variant unsourced; confirm by stopwatch).
   - Method: `citadel_koth_dev_test_spawn` in sandbox and stopwatch the phases. Also check the natural spawn in a bot match.
10. **Blue-lane Super Trooper rule** (one shrine vs both shrines).
    - Method: sandbox, kill 1 shrine, then compare trooper HP bars in Blue vs outer lanes.
11. **Jump pad damage window** (current wiki/patch value 0.6 s since 2025-10-24; confirm).
    - Method: bot shoots you at set delays after launch. Record the earliest delay that does not stun.
12. **Walker attack selection logic** (beam vs stomp vs rockets thresholds).
    - Method: sandbox with 1 and then 3 heroes in range. Log ability order and timing.
13. **Backdoor trooper radius** (about 40 m datamine).
    - Method: push a trooper wave toward a Walker and note the distance (`cl_showpos`) where the protection VFX or regen stops.
14. **Median match duration and distribution.** Only the mean is known.
    - Method: public API query (see Godot notes), not in-game.
15. **Mid-Boss shield exact regen rate and roar effect.**
    - Method: sandbox, damage to 50% and time the shield refill.

## Implementation notes for Godot 4

- **Data-driven Resources.** Add one `Resource` per archetype, stored as `.tres` in `res://data/map/`. Every field should carry the Values table row so balance changes need no code:
  - `StructureDef`:
    - hp, hp_growth_per_min, growth_start_s
    - bullet_resist, spirit_resist
    - time_dr_start, time_dr_end, time_dr_duration_s
    - enemy_scaling_resist_base, enemy_scaling_resist_per_hero
    - invuln_no_enemy_radius_m
    - backdoor (dr, regen)
    - bounty, attack list
  - `TrooperDef`: hp, dps_by_target_type Dictionary, resist_by_attacker_type Dictionary, speed, sight ranges.
  - `CampDef`: tier, units, first_spawn_s, respawn_s, scaling per minute.
  - `ObjectiveTimerDef`: Urn, Rift, powerups, breakables.
- **MatchClock autoload** (`MatchTimeline.gd`). Keep a single authoritative `match_time_s` and emit signals such as `minute_changed` and `wave_tick`. Drive every spawn from a sorted list of timeline events built from Resources, e.g. wave interval as a piecewise function `[(0,30),(1200,25),(2100,20)]`.
- **Lanes.** Use one `Path3D` per lane per team for the trooper walk path and the zipline curve. The API splines give relative proportions: middle lane about 687 m, outer lanes about 812 m. Scale them to your own level.
  - Implement zipline riding as a `PathFollow3D`, with speed 18 or 21 m/s × boost multipliers.
  - Implement "zipline extends with push" by clamping the rideable `progress` to the frontmost friendly trooper's `progress`.
- **Damage pipeline.** Use multiplicative resist stacking: `final = raw * Π(1 - r_i)`. Negative resist amplifies damage. Time DR on Guardians and Walkers is `lerp(start, end, clamp(t/duration, 0, 1))`.
  - Tag attackers with an `attacker_class` enum (HERO, TROOPER, STRUCTURE, NEUTRAL) so per-target DPS and resist tables apply.
- **Zones.** Use `Area3D` for:
  - backdoor trooper-proximity sphere (~40 m)
  - structure invuln radius
  - Mid-Boss and Patron pits (damage only from inside)
  - Rift capture cylinder (20 m)
  - spawn-room heal and turrets
  - lightning-tower zones

  Backdoor state machine: PROTECTED ↔ UNPROTECTED with a 14 s re-apply timer. Regen may only restore HP lost while protected; track `hp_lost_while_protected`.
- **Structure gating graph.** Each lane is a list of Guardian → Walker → [BG, BG]. Shrines require any lane's BG pair to be dead. The Patron requires both Shrines. Phase 2 spawns on Patron death, and the match ends on phase-2 death. Implement it as a small DAG with `is_vulnerable()` computed from the parents' state.
- **Soul orbs.** Troopers drop 2 orbs: a ground orb (undeniable, 18/40 s life) and a floating orb (deniable, about 0.7–1 s). Share per player uses the 1..6 table, radius 45 m from the orb or 30 m from the killer.
- **Respawn.** Piecewise-linear curve `[(300,8),(1200,38),(1800,70),(2400,85)]`, clamped at 90 s, plus modifiers.
- **Legal data analysis setup** (answers the user's "analyze data from the game (that is legal)" request):
  - Use the public, community-run **deadlock-api.com** REST API. It publishes aggregated match statistics and community-parsed patch data. It needs no game-file access, no client memory or network sniffing, and no ToS-breaking automation. Respect the rate limit (about 200 req/min/IP) and cache results.
  - Key endpoints (see [29]):

    | Endpoint | Returns |
    |---|---|
    | `GET /v1/analytics/game-stats?game_mode=normal&min_unix_timestamp=…` | avg duration, kills, souls by source, first Mid-Boss time |
    | `GET /v1/analytics/lane-soul-curve` | laning economy curves |
    | `GET /v1/analytics/kill-death-stats` | kill/death positions, useful for heatmaps |
    | `GET /v1/matches/metadata?include_objectives=true&include_mid_boss=true` | per-match objective destruction timestamps, used to fit tower-fall timing |
    | `GET /v1/matches/{id}/metadata` | a single match |
    | `GET /v1/patches` | patch list, to tag every number with a date |
    | `GET /v1/assets/npc-units`, `/map`, `/misc-entities`, `/generic-data` | community-datamine unit stats, map splines, spawner timers. Always tag these `community-datamine` |
    | `/v1/sql` | read-only SQL over their ClickHouse match tables, for custom aggregates |

  - Suggested tooling: a small offline Python or GDScript `EditorScript` (`tools/fetch_deadlock_api.gd`) that uses `HTTPRequest` to pull these JSONs into `res://data/reference/` with a timestamp. A diff script can then compare them against our `.tres` values to flag drift after each patch.
  - Do NOT import Valve assets or names into shipped content. Use the data only as tuning references.
- Keep all names in our implementation original (e.g. "Sentinel", "Colossus", "Heart"); the Deadlock names are used here only for traceability.

## Sources

All accessed 2026-09-27.

1. https://deadlock.wiki/The_Cursed_Apple — accessed 2026-09-27
2. https://deadlock.wiki/Trooper — accessed 2026-09-27
3. https://deadlock.wiki/Lane_Guardian — accessed 2026-09-27
4. https://deadlock.wiki/Walker — accessed 2026-09-27
5. https://deadlock.wiki/Base_Guardian — accessed 2026-09-27
6. https://deadlock.wiki/Shrine — accessed 2026-09-27
7. https://deadlock.wiki/Backdoor_Protection — accessed 2026-09-27
8. https://deadlock.wiki/Patron — accessed 2026-09-27
9. https://deadlock.wiki/Mid-Boss — accessed 2026-09-27
10. https://deadlock.wiki/Rejuvenator — accessed 2026-09-27
11. https://deadlock.wiki/Neutral — accessed 2026-09-27
12. https://deadlock.wiki/Sinner%27s_Sacrifice — accessed 2026-09-27
13. https://deadlock.wiki/Soul_Urn — accessed 2026-09-27
14. https://deadlock.wiki/Unstable_Rift — accessed 2026-09-27
15. https://deadlock.wiki/Powerups — accessed 2026-09-27
16. https://deadlock.wiki/Crate — accessed 2026-09-27
17. https://deadlock.wiki/Golden_Statue — accessed 2026-09-27
18. https://deadlock.wiki/Death — accessed 2026-09-27
19. https://deadlock.wiki/Ziplines — accessed 2026-09-27
20. https://deadlock.wiki/Teleporter — accessed 2026-09-27
21. https://deadlock.wiki/Jump_Pad — accessed 2026-09-27
22. https://deadlock.wiki/Ropes — accessed 2026-09-27
23. https://deadlock.wiki/Tunnel — accessed 2026-09-27
24. https://deadlock.wiki/Base_Turret — accessed 2026-09-27
25. https://deadlock.wiki/Extra_Slots — accessed 2026-09-27
26. https://deadlock.wiki/Souls — accessed 2026-09-27
27. https://deadlock.wiki/The_Curiosity_Shop — accessed 2026-09-27
28. https://deadlock.wiki/Structures — accessed 2026-09-27
29. https://api.deadlock-api.com/openapi.json — accessed 2026-09-27
30. https://api.deadlock-api.com/v1/assets/npc-units — accessed 2026-09-27 (community-datamine)
31. https://api.deadlock-api.com/v1/assets/map — accessed 2026-09-27 (community-datamine)
32. https://api.deadlock-api.com/v1/assets/misc-entities — accessed 2026-09-27 (community-datamine)
33. https://api.deadlock-api.com/v1/assets/generic-data — accessed 2026-09-27 (community-datamine)
34. https://api.deadlock-api.com/v1/analytics/game-stats?game_mode=normal&min_unix_timestamp=1787000000 — accessed 2026-09-27
35. https://forums.playdeadlock.com/forums/changelog.10/ — accessed 2026-09-27
36. https://forums.playdeadlock.com/threads/09-16-2026-update.162572/ — accessed 2026-09-27
37. https://forums.playdeadlock.com/threads/06-30-2026-update.146261/ — accessed 2026-09-27
38. https://forums.playdeadlock.com/threads/05-22-2026-update.135477/ — accessed 2026-09-27
39. https://forums.playdeadlock.com/threads/03-06-2026-update.114328/ — accessed 2026-09-27
40. https://forums.playdeadlock.com/threads/guardian-doesnt-re-aggro-to-someone-attacking-a-friendly-hero.135047/ — accessed 2026-09-27
41. https://liquipedia.net/deadlock/Patches — accessed 2026-09-27
42. https://tracklock.gg/articles/deadlock-update-09-16-26-patch-notes (third-party mirror of official 09-16-2026 notes; also patchbot.io) — accessed 2026-09-27

## Verification log (2026-09-27)

Adversarial re-check of ~25 implementation-critical claims against public sources only (deadlock.wiki, deadlock-api.com public endpoints, official 09-16-2026 patch notes via third-party mirrors). No game files, memory or network traffic were inspected.

| # | Claim | Checked against | Outcome |
|---|---|---|---|
| 1 | Wave interval 30/25/20 s at 0/20/35 min | [2] | Confirmed |
| 2 | Wave composition 3R+1M then 2R+1Melee+1M at 5 min | [2] | Confirmed |
| 3 | Trooper HP 300/400/350, DPS 28, walk 6.3/8.1, sprint 13 | [2] | Confirmed |
| 4 | Trooper bounty 100 + 2/min (was 116 + 1.16/min, 2026-06-30), 50/50 orb split | [2] | Confirmed |
| 5 | Super Troopers +60% dmg / +40% HP / -15% bounty; Blue needs both shrines | [2][6] | Confirmed (Shrine page states Blue rule explicitly) |
| 6 | Guardian HP 5500, DPS 116, range 34 m, time DR +50 -> -50 over 12 min | [3] | Confirmed (2026-05-22 change from +75) |
| 7 | Guardian bounty 1375 | [3], 09-16 notes | Confirmed; history added (1500 -> 1250 -> 1375). Wiki is the direct source, so type changed official -> wiki |
| 8 | Walker HP 6000/9000/12000, time DR +/-65 over 18 min, abilities | [4] | Confirmed |
| 9 | Walker bounty 3675 | [4] | Confirmed; history added (4000 -> 3500 -> 3675) |
| 10 | Base Guardian HP 4000 (from 5500, 2026-03-10), resist 40 - 20/hero | [5] | Confirmed; bullet resist 20 dated 2026-03-30 (was 10) |
| 11 | Shrine HP 5000 / 10000 | [6] | Confirmed on wiki; datamine 8775 conflict remains (open question 5) |
| 12 | Shrine bullet resist 20 | [6] | Downgraded to low: wiki patch history mentions 10%, inconsistent with its own infobox |
| 13 | Backdoor 65% DR / 65 HP/s; Patron 65% / 75 HP/s; 14 s buffer | [7] | Confirmed. Trooper detection radius (~40 m) is NOT on the wiki page; remains community-datamine only |
| 14 | Patron 12000 HP, +250/min from 20:00; Weakened 12000, +450/min; 12 s death sequence; defender DR 50/100 | [8] | Confirmed; wiki also lists 120 HP/s regen for phase 2 (row note added) |
| 15 | Mid-Boss spawn 0:00, 13000 + 195/min, respawn 7/6/5 min, 3000 + 50/min souls | [9] | Confirmed |
| 16 | Rejuvenator 3 min buff (was 4, 2026-06-30), 3 s revive, 100% HP | [10] | Confirmed |
| 17 | Zipline 18 / 21 m/s, boost +80% / 32 s / 360 s, knock-off 15% + 2.5 s | [19] | Confirmed |
| 18 | Respawn 8/38/70/85 s, cap 90 | [18], 09-16 notes [42] | Confirmed (20-min point 35 -> 38 on 2026-09-16); upgraded to high |
| 19 | Objective split 25 / 75 | [26], 09-16 notes [42] | Confirmed (30 -> 25); upgraded to high; open question 6 largely resolved |
| 20 | Starting souls 600, hero bounty 200 + 50/min cap 2200, unsecured drop threshold 50 + 5/min | [26] | Confirmed (threshold is on the Souls page, not the Death page) |
| 21 | Urn 10:00 / 5:00, 12.5 s descent, 250 + 70/min + 4 buffs | [13] | Confirmed |
| 22 | Rift 11 +/- 1 min, 7 +/- 1 min, 20 m, 12/6/18 s, 1482 + 222/min | [14] | Confirmed |
| 23 | Rift trailing resist aura | [14], 09-16 notes | CORRECTED: patch date 2026-06-30 -> 2026-09-16 (was flat 35%); confidence low -> high |
| 24 | Rift announce timing 60 s vs 40 s | [14] | Wiki gives 60 s; 40 s has no source found; low -> med |
| 25 | Soul well start 2:30 | [1] | CORRECTED: 2:30 -> 3:00 (only 3:00 is sourced; no Soul Well wiki page exists, 404). Orb value 10 souls / 2 s not found on map page, downgraded to low |
| 26 | Jump pad stun window 0.9 s | [21] | CORRECTED: 0.9 -> 0.6 s (0.6 is the 2025-10-24 value; 0.9 is older text on the same page) |
| 27 | Neutral camp HP/dmg/bounty, 2:00/5:00/8:00 spawns, 85/290/335 s respawns | [11][1] | Confirmed |
| 28 | Powerups 5:00 / 5:00 / 160 s, stat ranges | [15] | Confirmed |
| 29 | Crates 518, 3:00 / 3:00, 60% for 23 + 2/min; tunnels 5:00 (2026-09-16) | [16] | Confirmed (crate count still single-source, stays low) |
| 30 | Golden Statue 50%, L2/L3 at 10/30 min, buff table, HP 2/7 weight | [17] | Confirmed |
| 31 | Avg match 2306.9 s over 1,774,284 matches; first Mid-Boss 1621.8 s; net worth 44226; last hits 180 | [34] live API | Confirmed |
| 32 | Teleporters: 2 pairs, 4 s channel, +3 m/s for 5 s, from 0:00 (2025-05-08) | [20] | Confirmed |

Legality pass: no verbatim passages longer than a short formula or a few words were found; no lore, voice lines or art are included. All datamined values are attributed to third-party public sources (deadlock-api.com asset endpoints, wiki) and tagged community-datamine; nothing indicates the spec author parsed game files. Spline lengths and map positions are derived arithmetic on a public API response, still tagged community-datamine. The Open questions section proposes only in-client developer-console measurement in private lobbies, which is not file extraction or memory/network inspection; left as-is with its existing "never in matchmaking" caveat.

Not independently verified (left at stated confidence): trooper per-target DPS / resist tables, Walker crowd resist details, lightning tower always-hit height, vault jackpot window, catch-up trickle percentages, rich-player respawn penalty curve, backdoor trooper radius, shrine datamine 8775.

