# Gun System Plan

Status: approved to build (2026-09-28). Target: Godot 4.4.1, GDScript. The behavior authority is `specs/combat.md`: §1 pipeline, §2 weapon model, §3 crits, §4 falloff and the per-hero table. Where this plan and the spec disagree, the spec wins.

## Scope

**In scope (pass 1): every hero's primary gun (38 heroes).** Every gun is a data record from the combat.md table. The special behaviors are small, shared code paths:

| Mechanic | Heroes |
|---|---|
| Pellets (shotguns, spread pattern) | Abrams 9, Calico 9, Drifter 3, Mo & Krill 4, Pocket 7, Shiv 6, Silver 7, Yamato 5 |
| Burst | Lash / Seven 3 @ 0.084 s, Paradox 5 @ 0.0735 s, Sinclair 2 @ 0.105 s |
| Spin-up | McGinnis 0.21 → 0.084 s, Victor 0.198 → 0.171 s |
| Single-shell reload | Abrams (0.705 s + 0.352 s per shell), Silver (0.5 s + 0.3 s per shell) |
| No crits | Graves, Paige |
| Pierce | Paige |
| Hard range cutoff | Apollo 25.4 m; range caps for Bebop (32 m) and Rem (76.2 m) |
| Slow, fat or short-lived projectiles | Celeste, Paige, Kelvin, Drifter (0.054 s), Vyper (0.5 s) |

Also in scope:
- The damage pipeline: base plus boons, falloff, crit, attacker crit bonus scale, and defender crit received scale.
- Health on a dummy target.
- The fire-rate modifier formula from §12.
- Reload multiplier hooks.
- Approximate spread and recoil.

**Out of scope for now:**
- Alt-fires, abilities and items (Build-Up, headshot procs, Active Reload).
- Resists and barriers beyond a single multiplier hook.
- Lifesteal, melee damage, parry and networking.
- Spirit-power scaling of clip size (for example Haze's).

**No in-game measurement** (see memory `gun-system-scope`). Mechanics come from the spec. Spread and recoil are tuned by eye and are only meant to be close. Recoil is nominal game juice.

## Architecture

The guns follow the movement system's approach: a pure, tick-based sim plus a thin scene layer.

1. **`WeaponData`** (Resource, `src/combat/weapon_data.gd`):
   - Holds every field from the §2 table, in **meters and seconds** like the movement sim, plus approximate spread and recoil fields.
   - The tuned values live in `res://data/weapons/weapons.json`. `tools/weapons/gen_weapons.py` generates that file from the combat.md table, and it is our own data file.
   - `WeaponDB` loads the file into `WeaponData` by hero key.
   - `data/reference_godot/` is never loaded.
2. **`CombatMath`** (static):
   - `falloff_scale(d)`.
   - `crit_mult(attacker_scale, received_scale)`, which is `1 + 0.65 × (1 + a) × r` using the inferred formulas.
   - `fire_rate_mult(bonuses, slows)` from §12.
   - `bullet_damage(boons)`.
3. **`WeaponSim`** (pure, a RefCounted state object):
   - `step(state, data, fire_held, reload_pressed, mods) -> Array[shot]` runs once per 64 Hz tick.
   - States: IDLE, FIRING, BURSTING, RELOADING and RELOADING_SINGLE.
   - Timers are **float seconds**, not integer ticks. Cycle times like 0.105 s aren't whole ticks, and fast guns fire more than once in some ticks. Each shot carries its sub-tick time offset, so a bullet starts part-way along its first step and the fire rate stays exact.
   - Other rules:
     - The trigger is held for automatic weapons. Burst guns fire the whole burst on one press or hold.
     - The gun auto-reloads when empty.
     - Firing cancels a single-shell reload but keeps the shells already loaded.
     - Spin-up works in both directions: `spin` runs from 0 to 1 at `spin_up_rate`/s while firing and falls at `spin_down_rate`/s otherwise. The cycle time is a lerp from the base to the max spin cycle time.
4. **`ProjectileSystem`** (Node3D, one per world):
   - **Bullets are plain data** in parallel packed arrays: position, velocity, age, lifetime, radius, damage record index and alive flag. Dead slots go on a free list and get reused. That reuse is all the "pooling" there is. Nothing is a physics body.
   - **Each tick, for each bullet:**
     - Integrate the gravity drop (`gravity_scale` × 9.81 m/s²) and compute the segment p0 → p1.
     - **World:** one `intersect_ray` against WORLD, treating the bullet as a point against the world (`bullet_radius_vs_world` ≈ 0).
     - **Units:** a segment-vs-capsule distance test against each registered `Hitbox` (a body capsule plus a head capsule), using the bullet radius. It is plain math with no physics query. The earliest hit along the segment wins, and a head hit counts as a crit.
     - Paige's bullets pierce: they keep going and never hit the same unit twice.
   - **Rendering:** one `MultiMeshInstance3D` of stretched tracer quads, rewritten each frame from the live slots.
   - **Why this scales:** thousands of bullets cost thousands of ray casts and some capsule math per tick, and no physics-body churn. The stress test holds about 4000 live bullets. Real Deadlock lags at high fire rates, so matching it isn't a goal.
5. **`Hitbox` / `DamageTarget`**:
   - A `TargetDummy` (`src/combat/target_dummy.gd`) with HP, a body capsule, a head capsule and `crit_damage_received_scale`.
   - It emits a `damaged(info)` signal for floating damage numbers and resets HP after a delay.
6. **`WeaponController`** (Node on the player):
   - Reads `BTN_FIRE` from the same InputCmd the movement sim consumes. `BTN_RELOAD` is new.
   - The muzzle is the eye position. The aim direction goes toward the point under the crosshair: a camera ray to the world, falling back to 100 m. This matches the over-the-shoulder camera.
   - It feeds shots to the ProjectileSystem.
   - It drives `ctx.firing`, which movement already uses for the 0.75 slow.
   - It adds a small view punch as recoil.

## Spread and recoil (approximate)

- Spread is a cone half-angle: `spread = base + bloom`. Each shot adds `bloom_per_shot`, which decays at `bloom_decay`/s up to `bloom_max`. The spec mentions Haze at 0.4 per shot decaying at 4/s, which we treat as degrees.
- Shotgun pellets use a fixed ring pattern with a little jitter, so they're consistent enough to learn.
- Rifles get base 0.25°. Automatics get bloom 0.2–0.4° per shot. Shotguns use their pattern cone.
- Recoil is visual only: a pitch kick of 0.3–1.0° per shot that recovers within about 0.15 s. It never changes the sim aim.
- Determinism: spread uses a seeded RNG, seeded from (tick, shot index).

## Build order (commit after each)

1. Plan doc, weapons.json generator plus data, and WeaponData/WeaponDB/CombatMath with numeric tests (falloff, crit, DPS checks).
2. The WeaponSim FSM with tests: Haze fire rate and clip, a Lash burst, McGinnis spin-up and Abrams single reload.
3. The ProjectileSystem, the TargetDummy with capsule hit math, and a stress test with thousands of bullets and a timing budget.
4. Sandbox integration: the WeaponController, a hero gun picker, a HUD for ammo and reload, damage numbers and dummies in the arena.
5. Spread and recoil juice.

## Tests (minimal, loose)

- Falloff at start, mid and end, and Apollo's cutoff.
- The crit formula for Drifter and for Seven as the defender.
- Shots over a 2 s hold (Haze ≈ clip-limited), a burst cadence, spin-up shortening the cycle, and single-shell reload filling one shell at a time.
- A bullet hits a dummy's head or body at range. A bullet stops at a wall. Gravity drops a bullet.
- The stress test finishes under a loose budget.
