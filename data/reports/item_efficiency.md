# Item cost vs stat efficiency

_Generated 2026-09-27T05:19:50+00:00 by tools/deadlock_data/analyze.py. REFERENCE ONLY - observations of Deadlock, not our tuning._

Sources:
- `items|https://api.deadlock-api.com/v1/assets/items?language=english|retrieved=2026-09-27|client_version=latest(6701)|source_type=community-datamine`

## Shop structure (count / cost per slot & tier)

| slot | tier | items | min cost | max cost | actives |
|---|---|---|---|---|---|
| spirit | 1 | 8 | 800 | 800 | 2 |
| spirit | 2 | 12 | 1600 | 1600 | 3 |
| spirit | 3 | 13 | 3200 | 3200 | 4 |
| spirit | 4 | 16 | 6400 | 6400 | 9 |
| spirit | 5 | 7 | 9999 | 9999 | 4 |
| vitality | 1 | 8 | 800 | 800 | 2 |
| vitality | 2 | 15 | 1600 | 1600 | 3 |
| vitality | 3 | 14 | 3200 | 3200 | 7 |
| vitality | 4 | 17 | 6400 | 6400 | 6 |
| vitality | 5 | 7 | 9999 | 9999 | 2 |
| weapon | 1 | 7 | 800 | 800 | 0 |
| weapon | 2 | 16 | 1600 | 1600 | 2 |
| weapon | 3 | 19 | 3200 | 3200 | 5 |
| weapon | 4 | 11 | 6400 | 6400 | 1 |
| weapon | 5 | 3 | 9999 | 9999 | 0 |

## Stat per 1000 souls, by tier

For every stat that appears on >=3 items in >=2 tiers: median value, and median value per 1000 souls. A falling 'per 1k' column across tiers means higher tiers pay a premium for the slot (typical: power budget grows slower than cost, the rest is bought as unique effects).

### BonusHealth

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 5 | 60 | 75 | Mystic Regeneration, Rusted Barrel, Extra Health, Rebuttal ... |
| 2 | 8 | 67.5 | 42.2 | Improved Spirit, Mystic Slow, Spirit Sap, Bullet Lifesteal ... |
| 3 | 20 | 75 | 23.4 | Decay, Disarming Hex, Knockdown, Radiant Regeneration ... |
| 4 | 15 | 125 | 19.5 | Boundless Spirit, Lightning Scroll, Magic Carpet, Scourge ... |
| 5 | 3 | 350 | 35 | Unstable Concoction, Nullification Burst, Shadow Strike |

### OutOfCombatHealthRegen

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 5 | 1 | 1.25 | Golden Goose Egg, Extra Regen, Grit, Sprint Boots ... |
| 2 | 10 | 2 | 1.25 | Improved Spirit, Battle Vest, Enchanter's Emblem, Enduring Speed ... |
| 3 | 7 | 4 | 1.25 | Superior Cooldown, Bullet Resilience, Spirit Resilience, Blood Tribute ... |
| 4 | 5 | 4 | 0.625 | Boundless Spirit, Transcendent Cooldown, Divine Barrier, Healing Tempo ... |

### BaseAttackDamagePercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 3 | 8 | 10 | Extended Magazine, High-Velocity Rounds, Restorative Shot |
| 2 | 7 | 9 | 5.62 | Bullet Resist Shredder, Battle Vest, Bullet Lifesteal, Fleetfoot ... |
| 3 | 8 | 10 | 3.12 | Fury Trance, Cultist Sacrifice, Escalating Resilience, Express Shot ... |
| 4 | 8 | 13.5 | 2.11 | Colossus, Inhibitor, Leech, Phantom Strike ... |
| 5 | 1 | 150 | 15 | Unstable Concoction |

### TechResist

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 5 | 8 | 5 | Cold Front, Mystic Vulnerability, Enchanter's Emblem, Restorative Locket ... |
| 3 | 5 | 10 | 3.12 | Greater Expansion, Dispel Magic, Fury Trance, Spirit Resilience ... |
| 4 | 12 | 13 | 2.03 | Arctic Blast, Echo Shard, Escalating Exposure, Ethereal Shift ... |

### BonusMoveSpeed

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 4 | 1.75 | 1.09 | Enduring Speed, Guardian Ward, Active Reload, Stalker |
| 3 | 10 | 1.75 | 0.547 | Radiant Regeneration, Surge of Power, Counterspell, Fortitude ... |
| 4 | 4 | 2.62 | 0.41 | Ethereal Shift, Divine Barrier, Healing Tempo, Juggernaut |
| 5 | 3 | 5 | 0.5 | Shrink Ray, Unstable Concoction, Cloak of Opportunity |

### BulletResist

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 7 | 9 | 5.62 | Bullet Resist Shredder, Suppressor, Battle Vest, Return Fire ... |
| 3 | 6 | 14.5 | 4.53 | Superior Duration, Bullet Resilience, Metal Skin, Warp Stone ... |
| 4 | 7 | 10 | 1.56 | Echo Shard, Refresher, Cheat Death, Indomitable ... |

### TechPower

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 10 | 12.5 | Extra Spirit |
| 2 | 6 | 7 | 4.38 | Improved Spirit, Suppressor, Enchanter's Emblem, Healbane ... |
| 3 | 1 | 8 | 2.5 | Decay |
| 4 | 9 | 12 | 1.88 | Boundless Spirit, Magic Carpet, Mercurial Magnum, Diviner's Kevlar ... |
| 5 | 2 | 95 | 9.5 | Mystic Conduit, Unstable Concoction |

### BonusFireRate

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 9 | 11.2 | Rapid Rounds |
| 2 | 5 | 20 | 12.5 | Quicksilver Reload, Battle Vest, Active Reload, Kinetic Dash ... |
| 3 | 3 | 26 | 8.12 | Blood Tribute, Burst Fire, Heroic Aura |
| 4 | 8 | 16.5 | 2.58 | Focus Lens, Mercurial Magnum, Healing Tempo, Capacitor ... |
| 5 | 2 | 27.5 | 2.75 | Shrink Ray, Infinite Rounds |

### BonusSprintSpeed

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 4 | 1.5 | 1.88 | Golden Goose Egg, Rusted Barrel, Healing Rite, Sprint Boots |
| 2 | 6 | 0.75 | 0.469 | Improved Spirit, Mystic Slow, Slowing Hex, Trophy Collector ... |
| 3 | 6 | 0.875 | 0.273 | Disarming Hex, Rescue Beam, Heroic Aura, Hunter's Aura ... |
| 4 | 2 | 0.75 | 0.117 | Lightning Scroll, Vortex Web |

### Radius

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 1 | 1.25 | Restorative Shot |
| 2 | 2 | 16.5 | 10.3 | Restorative Locket, Mystic Shot |
| 3 | 3 | 15 | 4.69 | Alchemical Fire, Heroic Aura, Hunter's Aura |
| 4 | 3 | 14 | 2.19 | Mystic Reverb, Colossus, Lucky Shot |
| 5 | 6 | 17 | 1.7 | Mystic Conduit, Mystical Piano, Unstable Concoction, Celestial Blessing ... |

### BuffDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 6 | 7.5 | Rebuttal |
| 2 | 2 | 9 | 5.62 | Quicksilver Reload, Guardian Ward |
| 3 | 2 | 4.5 | 1.41 | Counterspell, Dispel Magic |
| 4 | 6 | 9.5 | 1.48 | Ethereal Shift, Mercurial Magnum, Divine Barrier, Diviner's Kevlar ... |
| 5 | 2 | 6 | 0.6 | Celestial Blessing, Cloak of Opportunity |

### Damage

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 40 | 50 | Mystic Burst |
| 2 | 2 | 69.5 | 43.4 | Cold Front, Quicksilver Reload |
| 3 | 2 | 57.5 | 18 | Silence Wave, Tankbuster |
| 4 | 4 | 125 | 19.5 | Arctic Blast, Lightning Scroll, Mercurial Magnum, Capacitor |
| 5 | 3 | 200 | 20 | Frostbite Charm, Electric Slippers, Nullification Burst |

### TechRadiusMultiplier

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 20 | 25 | Mystic Expansion |
| 2 | 1 | 8 | 5 | Guardian Ward |
| 3 | 6 | 9 | 2.81 | Greater Expansion, Knockdown, Healing Nova, Rescue Beam ... |
| 4 | 3 | 8 | 1.25 | Spirit Burn, Vortex Web, Divine Barrier |
| 5 | 1 | 40 | 4 | Mystic Conduit |

### TechRangeMultiplier

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 20 | 25 | Mystic Expansion |
| 2 | 1 | 8 | 5 | Guardian Ward |
| 3 | 6 | 9 | 2.81 | Greater Expansion, Knockdown, Healing Nova, Rescue Beam ... |
| 4 | 3 | 8 | 1.25 | Spirit Burn, Vortex Web, Divine Barrier |
| 5 | 1 | 40 | 4 | Mystic Conduit |

### SlowPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 20 | 12.5 | Slowing Hex, Slowing Bullets |
| 3 | 4 | 28 | 8.75 | Lifestrike, Majestic Leap, Point Blank, Weighted Shots |
| 4 | 6 | 35 | 5.47 | Arctic Blast, Lightning Scroll, Vortex Web, Colossus ... |

### MaxStacks

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 3 | 16 | 10 | Restorative Locket, Trophy Collector, Split Shot |
| 3 | 2 | 7 | 2.19 | Berserker, Spirit Rend |
| 4 | 5 | 8 | 1.25 | Escalating Exposure, Siphon Bullets, Crushing Fists, Glass Cannon ... |
| 5 | 1 | 1 | 0.1 | Shadow Strike |

### DebuffDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 3 | 8 | 5 | Spirit Shredder Bullets, Stalker, Weakening Headshot |
| 3 | 2 | 8 | 2.5 | Hollow Point, Spirit Rend |
| 4 | 5 | 8 | 1.25 | Spirit Burn, Inhibitor, Crippling Headshot, Crushing Fists ... |
| 5 | 1 | 4 | 0.4 | Haunting Shot |

### ProcChance

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 2 | 100 | 125 | Headshot Booster, Restorative Shot |
| 2 | 1 | 100 | 62.5 | Mystic Shot |
| 3 | 2 | 57.5 | 18 | Headhunter, Tesla Bullets |
| 4 | 3 | 25 | 3.91 | Armor Piercing Rounds, Capacitor, Lucky Shot |
| 5 | 2 | 82.5 | 8.25 | Haunting Shot, Infinite Rounds |

### GroundDashReductionPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 3 | -20 | -12.5 | Mystic Slow, Slowing Hex, Slowing Bullets |
| 3 | 2 | -20 | -6.25 | Metal Skin, Weighted Shots |
| 4 | 3 | -22 | -3.44 | Lightning Scroll, Vortex Web, Colossus |
| 5 | 1 | -36 | -3.6 | Haunting Shot |

### SlowDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 3.5 | 2.19 | Slowing Bullets |
| 3 | 4 | 2.5 | 0.781 | Lifestrike, Majestic Leap, Point Blank, Weighted Shots |
| 4 | 4 | 3 | 0.469 | Arctic Blast, Phantom Strike, Capacitor, Glass Cannon |

### HealAmpReceivePenaltyPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | -35 | -21.9 | Healbane |
| 3 | 2 | -42.5 | -13.3 | Decay, Toxic Bullets |
| 4 | 4 | -50 | -7.81 | Spirit Burn, Cheat Death, Inhibitor, Crippling Headshot |
| 5 | 1 | -40 | -4 | Haunting Shot |

### HealAmpRegenPenaltyPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | -35 | -21.9 | Healbane |
| 3 | 2 | -42.5 | -13.3 | Decay, Toxic Bullets |
| 4 | 4 | -50 | -7.81 | Spirit Burn, Cheat Death, Inhibitor, Crippling Headshot |
| 5 | 1 | -40 | -4 | Haunting Shot |

### TickRate

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 0.5 | 0.312 | Stalker |
| 3 | 4 | 0.5 | 0.156 | Decay, Alchemical Fire, Blood Tribute, Toxic Bullets |
| 4 | 2 | 0.375 | 0.0586 | Scourge, Spirit Burn |
| 5 | 1 | 1 | 0.1 | Shadow Strike |

### ProcCooldown

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 1 | 0.625 | Mystic Shot |
| 3 | 2 | 1.1 | 0.344 | Spirit Rend, Tesla Bullets |
| 4 | 3 | 0.7 | 0.109 | Escalating Exposure, Siphon Bullets, Capacitor |
| 5 | 2 | 0.65 | 0.065 | Electric Slippers, Haunting Shot |

### BonusClipSizePercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 30 | 37.5 | Extended Magazine |
| 2 | 4 | 20 | 12.5 | Active Reload, Intensifying Magazine, Recharging Rush, Titanic Magazine |
| 3 | 1 | 35 | 10.9 | Escalating Resilience |
| 4 | 2 | 25 | 3.91 | Mercurial Magnum, Lucky Shot |

### StaminaCooldownReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 12 | 15 | Extra Stamina |
| 2 | 2 | 12 | 7.5 | Arcane Surge, Kinetic Dash |
| 3 | 2 | 2 | 0.625 | Stamina Mastery, Weighted Shots |
| 5 | 2 | 110 | 11 | Celestial Blessing, Seraphim Wings |

### CooldownReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 11.5 | 7.19 | Compress Cooldown, Enchanter's Emblem |
| 3 | 1 | 20 | 6.25 | Superior Cooldown |
| 4 | 3 | 7 | 1.09 | Transcendent Cooldown, Witchmail, Spellslinger |
| 5 | 1 | 40 | 4 | Mystic Conduit |

### BonusMeleeDamagePercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 12 | 15 | Melee Lifesteal |
| 2 | 1 | 10 | 6.25 | Melee Charge |
| 3 | 2 | 11.5 | 3.59 | Spirit Snatch, Lifestrike |
| 4 | 2 | 26 | 4.06 | Colossus, Crushing Fists |
| 5 | 1 | 30 | 3 | Runed Gauntlets |

### AbilityLifestealPercentHero

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 11.5 | 7.19 | Spirit Lifesteal, Spirit Shredder Bullets |
| 3 | 1 | 10 | 3.12 | Spirit Rend |
| 4 | 4 | 20.5 | 3.2 | Mystic Reverb, Infuser, Leech, Spiritual Overflow |

### StatusResistancePercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 25 | 15.6 | Debuff Reducer |
| 3 | 2 | 28.5 | 8.91 | Blood Tribute, Weighted Shots |
| 4 | 3 | 25 | 3.91 | Scourge, Spellbreaker, Unstoppable |
| 5 | 1 | 40 | 4 | Nullification Burst |

### DamageThreshold

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 3 | 225 | 141 | Spirit Shielding, Weapon Shielding, Recharging Rush |
| 4 | 3 | 175 | 27.3 | Spirit Burn, Spellbreaker, Witchmail |
| 5 | 1 | 300 | 30 | Mystic Conduit |

### CombatBarrier

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 200 | 250 | Grit |
| 2 | 2 | 300 | 188 | Spirit Shielding, Weapon Shielding |
| 3 | 1 | 200 | 62.5 | Majestic Leap |
| 4 | 2 | 800 | 125 | Divine Barrier, Diviner's Kevlar |
| 5 | 1 | 500 | 50 | Cloak of Opportunity |

### BuildUpDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 5 | 3.12 | Slowing Bullets |
| 3 | 2 | 5 | 1.56 | Toxic Bullets, Weighted Shots |
| 4 | 4 | 5 | 0.781 | Inhibitor, Glass Cannon, Silencer, Spiritual Overflow |

### BuildUpPerShot

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 0.7 | 0.437 | Slowing Bullets |
| 3 | 2 | 0.99 | 0.309 | Toxic Bullets, Weighted Shots |
| 4 | 4 | 1.06 | 0.166 | Inhibitor, Glass Cannon, Silencer, Spiritual Overflow |

### BulletArmorReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | -8 | -10 | Rusted Barrel |
| 2 | 1 | -10 | -6.25 | Bullet Resist Shredder |
| 3 | 4 | -10 | -3.12 | Disarming Hex, Alchemical Fire, Hollow Point, Hunter's Aura |

### TechArmorDamageReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | -6 | -7.5 | Spirit Strike |
| 2 | 2 | -8 | -5 | Mystic Vulnerability, Spirit Shredder Bullets |
| 3 | 2 | -10 | -3.12 | Spirit Snatch, Spirit Rend |
| 4 | 1 | -8 | -1.25 | Escalating Exposure |

### BonusAbilityDurationPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 18.5 | 11.6 | Arcane Surge, Duration Extender |
| 3 | 1 | 28 | 8.75 | Superior Duration |
| 4 | 3 | 15 | 2.34 | Magic Carpet, Diviner's Kevlar, Spiritual Overflow |

### SpiritPower

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 13.5 | 8.44 | Arcane Surge, Mystic Shot |
| 3 | 4 | 9 | 2.81 | Counterspell, Healing Nova, Veil Walker, Alchemical Fire |

### Stamina

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 1 | 1.25 | Extra Stamina |
| 2 | 2 | 1 | 0.625 | Arcane Surge, Kinetic Dash |
| 3 | 1 | 2 | 0.625 | Stamina Mastery |
| 5 | 2 | 2.5 | 0.25 | Electric Slippers, Shadow Strike |

### MeleeResistPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 2 | 19 | 23.8 | Rebuttal, Close Quarters |
| 3 | 2 | 24 | 7.5 | Torment Pulse, Point Blank |
| 4 | 1 | 25 | 3.91 | Juggernaut |
| 5 | 1 | 50 | 5 | Runed Gauntlets |

### BulletLifestealPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 14.5 | 9.06 | Bullet Lifesteal, Active Reload |
| 3 | 1 | 14 | 4.38 | Fury Trance |
| 4 | 3 | 13 | 2.03 | Leech, Vampiric Burst, Frenzy |

### BonusBulletSpeedPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 60 | 75 | High-Velocity Rounds |
| 2 | 1 | 60 | 37.5 | Opening Rounds |
| 3 | 2 | 60 | 18.8 | Express Shot, Sharpshooter |
| 4 | 1 | 60 | 9.38 | Armor Piercing Rounds |
| 5 | 1 | 200 | 20 | Infinite Rounds |

### MovementSpeedSlow

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 36 | 22.5 | Cold Front, Mystic Slow |
| 4 | 2 | 28 | 4.38 | Lightning Scroll, Mystic Reverb |
| 5 | 1 | 32 | 3.2 | Haunting Shot |

### StunDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 3 | 1 | 0.5 | 0.156 | Knockdown |
| 4 | 2 | 0.75 | 0.117 | Lightning Scroll, Crushing Fists |
| 5 | 2 | 2.5 | 0.25 | Mystical Piano, Unstable Concoction |

### DPS

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 17 | 10.6 | Stalker |
| 3 | 1 | 45 | 14.1 | Alchemical Fire |
| 4 | 1 | 24 | 3.75 | Spirit Burn |
| 5 | 2 | 198 | 19.8 | Prism Blast, Shadow Strike |

### BonusAbilityCharges

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 1 | 1.25 | Extra Charge |
| 3 | 2 | 1.5 | 0.469 | Rapid Recharge, Cultist Sacrifice |
| 5 | 1 | 4 | 0.4 | Omnicharge Signet |

### OutgoingDamagePenaltyPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | -15 | -18.8 | Golden Goose Egg |
| 4 | 2 | -27.5 | -4.3 | Cursed Relic, Inhibitor |
| 5 | 1 | -40 | -4 | Haunting Shot |

### AbilityChargeUpTime

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 14 | 17.5 | Mystic Burst |
| 2 | 1 | 18 | 11.2 | Quicksilver Reload |
| 3 | 1 | 14 | 4.38 | Tankbuster |
| 4 | 1 | 14 | 2.19 | Mercurial Magnum |

### FireRateSlow

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 32 | 40 | Rusted Barrel |
| 2 | 1 | 28 | 17.5 | Suppressor |
| 3 | 1 | 15 | 4.69 | Hunter's Aura |
| 4 | 1 | 40 | 6.25 | Juggernaut |

### MagicResistReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | -9 | -5.62 | Spirit Sap |
| 3 | 1 | -7 | -2.19 | Spirit Rend |
| 4 | 2 | -12.5 | -1.95 | Focus Lens, Crippling Headshot |

### BonusHealthRegen

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 2.5 | 3.12 | Extra Regen |
| 2 | 1 | 3 | 1.88 | Healing Booster |
| 4 | 2 | 7 | 1.09 | Healing Tempo, Juggernaut |

### BarrierDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 4 | 5 | Grit |
| 2 | 2 | 8 | 5 | Spirit Shielding, Weapon Shielding |
| 3 | 1 | 8 | 2.5 | Majestic Leap |

### ActiveBonusMoveSpeed

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 3 | 1.88 | Fleetfoot |
| 3 | 3 | 2 | 0.625 | Dispel Magic, Fury Trance, Heroic Aura |

### BulletResistReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | -9 | -5.62 | Stalker, Weakening Headshot |
| 4 | 2 | -10.5 | -1.64 | Crippling Headshot, Crushing Fists |

### BonusSpiritForChargedAbilities

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 7 | 8.75 | Extra Charge |
| 3 | 1 | 14 | 4.38 | Rapid Recharge |
| 5 | 1 | 50 | 5 | Omnicharge Signet |

### MinimumDamage

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 80 | 100 | Mystic Burst |
| 3 | 1 | 165 | 51.6 | Tankbuster |
| 4 | 1 | 100 | 15.6 | Mystic Reverb |

### LightMeleeCooldownMult

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 2 | 1.75 | 2.19 | Spirit Strike, Melee Lifesteal |
| 3 | 1 | 1.5 | 0.469 | Lifestrike |

### DamageHeight

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 7 | 4.38 | Cold Front |
| 4 | 1 | 7 | 1.09 | Arctic Blast |
| 5 | 1 | 4 | 0.4 | Nullification Burst |

### EndRadius

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 10 | 6.25 | Cold Front |
| 4 | 1 | 16 | 2.5 | Arctic Blast |
| 5 | 1 | 20 | 2 | Nullification Burst |

### SpreadDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 0.6 | 0.375 | Cold Front |
| 4 | 1 | 0.6 | 0.0938 | Arctic Blast |
| 5 | 1 | 0.5 | 0.05 | Nullification Burst |

### StartRadius

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 2 | 1.25 | Cold Front |
| 4 | 1 | 2 | 0.312 | Arctic Blast |
| 5 | 1 | 2 | 0.2 | Nullification Burst |

### TechPowerReduction

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | -30 | -18.8 | Spirit Sap |
| 3 | 1 | -25 | -7.81 | Spirit Snatch |
| 4 | 1 | -30 | -4.69 | Focus Lens |

### MoveWhileShootingSpeedPenaltyReductionPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 100 | 62.5 | Fleetfoot |
| 3 | 2 | 100 | 31.2 | Surge of Power, Fury Trance |

### AirControlPercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 3 | 1 | 100 | 31.2 | Majestic Leap |
| 4 | 1 | 25 | 3.91 | Magic Carpet |
| 5 | 1 | 100 | 10 | Seraphim Wings |

### LifeThreshold

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 65 | 40.6 | Battle Vest, Enchanter's Emblem |
| 3 | 1 | 65 | 20.3 | Hollow Point |

### SlowResistancePercent

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 2 | 32.5 | 20.3 | Enduring Speed, Fleetfoot |
| 4 | 1 | 50 | 7.81 | Juggernaut |

### NonHeroAbilityLifestealTooltipOnly

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 3 | 1.88 | Spirit Lifesteal |
| 4 | 2 | 3 | 0.469 | Infuser, Spiritual Overflow |

### NonPlayerBonusWeaponPower

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 1 | 1 | 25 | 31.2 | Monster Rounds |
| 2 | 1 | -15 | -9.38 | Trophy Collector |
| 3 | 1 | 30 | 9.38 | Cultist Sacrifice |

### InvisAlertWhenFading

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 3 | 2 | 1 | 0.312 | Veil Walker, Shadow Weave |
| 5 | 1 | 1 | 0.1 | Shadow Strike |

### InvisFadeToDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 3 | 2 | 0.425 | 0.133 | Veil Walker, Shadow Weave |
| 5 | 1 | 0.2 | 0.02 | Shadow Strike |

### RevealOnDamageDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 3 | 2 | 1 | 0.312 | Veil Walker, Shadow Weave |
| 5 | 1 | 1.5 | 0.15 | Shadow Strike |

### RevealOnSpottedDuration

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 3 | 2 | 1.38 | 0.43 | Veil Walker, Shadow Weave |
| 5 | 1 | 0.25 | 0.025 | Shadow Strike |

### SlideScale

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 35 | 21.9 | Fleetfoot |
| 3 | 1 | 50 | 15.6 | Burst Fire |
| 5 | 1 | 80 | 8 | Electric Slippers |

### MeleeDistanceScale

| tier | n | median value | median /1k souls | examples |
|---|---|---|---|---|
| 2 | 1 | 50 | 31.2 | Melee Charge |
| 4 | 1 | 60 | 9.38 | Crushing Fists |
| 5 | 1 | 150 | 15 | Runed Gauntlets |

