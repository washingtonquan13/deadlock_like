# Clean-room specs

These files are the boundary between observing Deadlock and implementing our game.
Implementation code in `src/` cites these specs, never the game itself. Tuned values for
our game live in `data/`; `data/reference*/` is reference-only.

| Spec | Covers |
|---|---|
| [movement.md](movement.md) | walk/sprint, stamina, dash buckets, slide, jumps, wall jump, mantle, ziplines, melee movement |
| [combat.md](combat.md) | weapon model, falloff, headshots, damage types, resists, shields, lifesteal, CC, melee/parry, respawn, boons |
| [abilities.md](abilities.md) | ability slots/types, spirit power scaling, CDR, charges, AP/upgrade tiers, levels, hero stat blocks, archetypes |
| [economy.md](economy.md) | soul sources, orbs/denies, bounties, comeback, shop tiers, slots/flex, investment bonuses, items |
| [map_and_objectives.md](map_and_objectives.md) | lanes, trooper waves/AI, guardians/walkers/shrines/patron, mid boss, camps, urn, match flow |
| [_data_sources.md](_data_sources.md) | which public data sources are legal to use and how |
| [_measurement_protocol.md](_measurement_protocol.md) | private-lobby measurement recipes + console commands |

Every value row carries source, source type (official / wiki / community-datamine /
community-measurement / inferred), patch/date and confidence. Each spec ends with a
verification log from an independent fact-check pass (2026-09-27, game patch 2026-09-16).

## Refreshing reference data

```
python tools/deadlock_data/fetch.py
python tools/deadlock_data/normalize.py
python tools/deadlock_data/analyze.py
python tools/deadlock_data/export_godot.py
```

## Top items to measure in a private lobby
- Gravity, ground/air acceleration and friction (not published anywhere)
- Air jump behavior (set vs add vertical velocity) and down-dash stamina cost (0.5 vs 1)
- Unit conversion (assumed 1 u = 0.0254 m) — calibrate first
- Heavy melee lunge distance / wind-up
- Reload overhead (API DPS suggests ~0.25 s extra per reload)
