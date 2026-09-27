# In-game measurement protocol (legal, first-hand)

Goal: check or refine reference numbers by **observing Deadlock ourselves**, without touching game files, memory or network traffic.
Record every result in `data/measurements/*.csv`, using `data/measurements/template.csv` as the header.

## Ground rules

1. **Only use private contexts:** a Private Lobby or custom match, the Hero Sandbox, or a Bot match. **Never** use cheats or run tests in matchmaking. Console cheats are only allowed where the game itself enables them, and griefing or holding up real players is not acceptable.
2. Only use observation tools the game itself provides: console commands, the HUD, damage numbers, and screen recording with OBS or ShadowPlay. **No** memory readers, packet sniffers, file extractors or overlays that inject into the game.
3. Note the **game build or patch date** for every session. The in-game build number is shown in the main menu/console. The patch date comes from https://forums.playdeadlock.com/forums/changelog.10/.
4. Take at least **3 trials** of each measurement and record every one, not just the average.
5. Record the video frame numbers of the start and end events. At 60 fps a frame is 16.7 ms and at 120 fps it is 8.3 ms. Frame counting is usually the most accurate timer.

## Setting up a test session

| Step | Command / action | Verified? | Source |
|---|---|---|---|
| Open console | Enable the console in settings, then press the console key | medium: widely reported | https://deadlock.wiki/Console_commands (updated 2026-09-26) |
| Create a private lobby | Use the Play menu's custom or private lobby option. `private_lobby_create` is also reported. | UI: high. Command: **unverified** | Pro Game Guides / clubtsp (2024–25 blogs) |
| Load the map yourself | `map dl_midtown` (also `dl_streets`) | medium | wiki Console commands; Steam guide 3581373326 (Oct 2025) |
| Enable cheats (private only) | `sv_cheats true` | medium | wiki; Steam guide 3581373326; forum thread 58903 (Mar 2025) |
| Sandbox testing menu | `citadel_hero_testing_enabled 1`. Opening the menu needs no cheats, but using it does. | medium | wiki Console commands |
| Unlimited souls and ability points | `citadel_hero_testing_infinite_money 1` (cheat) | medium | wiki; Steam guide 3581373326 |
| Give a set amount of souls | `citadel_give_gold <n>` (cheat) | **low**: a single 2025 guide | Steam guide 3581373326 |
| Max souls and abilities | `kingme` (grants 1.2M souls and max abilities, cheat) | medium | wiki; Steam guide 3376396910 (2024) |
| Pick a hero | `selecthero <internal_name>`. List internal names with `dump_hero_names` (cheat). | medium | wiki |
| Invulnerable self | `citadel_enable_no_hero_death` / `citadel_disable_no_hero_death` | medium | wiki |
| Set own health | `healthpct <0-100>`; `hurtme` deals 10 damage to self | medium | wiki |
| Fast cooldowns | `citadel_enable_fast_cooldowns` (every cooldown becomes 2 s). **Disable it before measuring cooldowns.** | medium | wiki |
| Fast stamina | `citadel_enable_fast_stamina` / `citadel_disable_fast_stamina` | medium | wiki |
| Buy items anywhere | `citadel_allow_purchasing_anywhere 1` | medium | wiki; Steam guide 3581373326 |
| Infinite ammo | `sv_infinite_ammo 1`. **Turn it off for reload and TTK tests.** | low | Steam guide 3581373326 |
| Spawn a target dummy or bot | `citadel_create_unit` spawns an allied dummy in front of you (cheat) | medium | wiki |
| Spawn an NPC or trooper | `npc_create <type>` | **low**: a 2024 guide | Steam guide 3376396910 |
| Freeze or unfreeze AI | `ai_setenabled 0/1`; `ai_step` / `ai_resume` | low | Steam guides 3581373326, 3376396910 |
| Kill all lane troopers | `trooper_kill_all` | low | Steam guide 3376396910 |
| Respawn neutral camps | `citadel_spawn_nearby_neutrals` (cheat) | medium | wiki |
| Practice bots | `citadel_spawn_practice_bots 0/1`, `citadel_spawn_practice_bots_count <n>`, `citadel_solo_bot_match` | medium | wiki |
| Show position **and velocity** | `cl_showpos 1` | medium: several sources | Steam guides 3376396910 and 3581373326; search results for deadlocker.tv |
| Read or set position | `getpos` / `setpos x y z` | low | Steam guide 3376396910 |
| Fly | `noclip` | medium | Steam guides; wiki Console commands does **not** list it |
| Game speed | `host_timescale <x>` (for example 0.2 for slow motion). **Do not use it while timing things.** | low–medium | Steam guide 3376396910; deadlocker.tv snippet |
| DPS meter | `hud_damagemeter 1` (cheat) | medium | wiki; Steam guides |
| Multiply damage | `citadel_dps_multiplier`, `citadel_weapon_damage_multiplier`. **Leave both at 1.0.** | medium | wiki |
| Movement speed scale | `citadel_player_move_speed_scale`. **Leave it at 1.0.** | medium | wiki |
| Hide HUD (for clean video) | `citadel_hud_visible 0` | medium | wiki |
| Wall-jump / corner-boost debug view | `citadel_wall_detection_debug 1` | low | Steam guide 3376396910 |
| Pause | `citadel_pause` | medium | wiki |
| Hero Labs mode | This was an experimental-hero mode in 2024. **Unverified whether it still exists in 2026**, so use Sandbox or private lobbies instead. | unverified | - |
| FPS / net graph | `cl_showfps`, `cq_netgraph`: **unverified** for Deadlock | unverified | - |

Known limitation: some sandbox convars report "only server operator can change its value" even in a private match with `sv_cheats true`. See forums.playdeadlock.com thread 58903 (2025-03-17).

**Reference distances:** measure them with `cl_showpos` / `getpos` coordinates. Engine units convert to metres at 1 unit = 0.0254 m (our inference; the falloff start of 708.661 units shows as 18 m). Check this conversion once with the distance-calibration recipe (R0) below.

## Recipes

Each recipe says what to record. Use the `quantity` names in the CSV.

### R0: Distance calibration (do this first)
1. `noclip` off. Stand on flat ground and run `getpos` (or read `cl_showpos`). Walk straight and run `getpos` again.
2. Compare the unit distance with a known in-game measurement, such as an ability range shown in its tooltip in metres. Cast at max range and use `getpos` at both ends.
3. Record `unit_to_m`. We expect 0.0254.

### R1: Movement speed (walk and sprint)
1. Flat, straight corridor. `cl_showpos 1`. No items and no buffs.
2. Hold forward for at least 3 s. Read the steady velocity from `cl_showpos` as `move_speed_ups`. Also time a fixed distance: `getpos` at start and end, with frame-counted time.
3. Repeat while sprinting, backpedalling and strafing. Movement is typically slower when not moving forward.
4. Record `move_speed_forward`, `move_speed_back`, `move_speed_strafe`, `sprint_speed`, plus `accel_time_to_max` (frames from key press to steady velocity).
5. Compare with `base_max_move_speed` / `base_sprint_speed` in `data/reference/heroes.csv`.

### R2: Dash distance and duration
1. Stand still and run `getpos`. Dash forward once on the ground, then run `getpos`. The distance is the dash length, including any drift.
2. Count frames from the dash input until velocity drops back to walk speed.
3. Repeat in the air (jump, then dash at the apex) and while moving.
4. Record `ground_dash_distance`, `ground_dash_duration`, `air_dash_distance`, `air_dash_duration`, `stamina_regen_time`. The last one is the time from 0 stamina until one charge is back; use fast stamina **off**.
5. Reference values from the community datamine: 10 m / ~0.68 s ground, 8 m air.

### R3: Slide speed and decay
1. Sprint to max speed, then crouch to slide on flat ground. Record `cl_showpos` velocity in video every frame, or every 5 frames.
2. Record `slide_entry_speed`, `slide_speed_t0.5`, `slide_speed_t1.0`, and so on, plus `slide_distance` and `slide_duration`. Repeat downhill if a slope helps.
3. Fit an exponential or linear decay afterwards.

### R4: Jump height, gravity and air control
1. Stand under a wall with a height reference, or use `getpos` z at the apex while paused or frame-stepping.
2. Record `jump_apex_height` and `jump_airtime` (frames from takeoff to landing). Gravity follows as g = 8h / t².
3. Double or mantle checks: record `mantle_max_height`.

### R5: Weapon falloff
1. `sv_cheats true`. Spawn a stationary dummy with `citadel_create_unit` or use a trooper held by `ai_setenabled 0`. Turn fast cooldowns off, infinite ammo off and all multipliers to 1.0.
2. Put yourself at distances D = 5, 10, 15, 18, 20, 25, 30, 35, 40, 50 m. Check each with `getpos` or `cl_showpos` on both entities.
3. Fire single body shots and read the floating damage numbers. Record `damage_per_bullet` at each distance, 5 samples each. Record headshots separately.
4. Compare with the falloff curve in `data/reports/weapon_ttk.md`. Record the `damage_falloff_bias` shape: is the curve linear or bent?

### R6: Headshot multiplier
1. Same setup as R5, at close range (5 m) and long range (40 m).
2. Record `headshot_damage` / `bodyshot_damage` as the ratio. The reference is 1.65 at base. Check whether it changes with distance: `crit_bonus_start` / `crit_bonus_end`.

### R7: Fire rate, magazine and reload
1. Infinite ammo **off**. Hold fire on an empty wall and record video.
2. Count shots and frames: `shots_per_second` = (shots − 1) / time from first to last shot.
3. `reload_time` runs from the last shot to the first shot of the next magazine. Also time from the reload key press to the moment the ammo counter refills. This checks the ~0.25 s gap that our model does not explain.
4. Weapons with spin-up, charge or burst (Lash, Paige, Paradox, Seven and others flagged "(!)" in the TTK report): record the full shot timestamps sequence.

### R8: TTK, the end-to-end check
1. Target: a hero dummy or bot at a known max health, where the HUD shows its HP. Invulnerability off.
2. From distance D, body shots only: record frames from the first damage number to death, as `ttk_s`. Then again with a fixed headshot rate if feasible, or 100% headshots at close range.
3. Compare with `python analyze.py calc --hero <X> --hp <HP> --dist <D> --hs <rate>`.

### R9: Trooper wave timing and composition
1. Private lobby, no cheats needed. Run a match timer (the in-game clock).
2. Record `wave_spawn_time` for the first 10 waves in one lane, `wave_composition` (normal/melee/medic counts), and `trooper_walk_time` from the spawn gate to the first guardian.
3. Record `trooper_hp`, and check it against `npc_units.csv` (300 HP for `trooper_normal` in build 6701).

### R10: Soul orbs and last hits
1. Kill troopers with a last hit and record `soul_orb_spawn_delay` (frames from death to the orb appearing), `orb_lifetime` (frames until it despawns if nobody shoots it), and `orb_value`: the souls gained when you secure it against when you don't. Also record `deny_value` (an enemy orb you shoot).
2. Neutral camps: record `neutral_respawn_time` using `citadel_spawn_nearby_neutrals` **off**.
3. Economy reference: `data/reports/economy.md` (lane creeps are about 36% of soul income, plus orbs).

### R11: Ability numbers (per hero, as needed)
1. Fast cooldowns **off**. Record `cooldown_s` (frames from the cast to the ability becoming ready again), `cast_range_m` (`getpos` at the edge), `damage` from damage numbers at 0 spirit power, `duration_s`, and `spirit_scaling` (damage at 0 and at +X spirit, from shop items).
2. Compare with `abilities.csv` (`key_properties_json`).

## Recording format

Use `data/measurements/template.csv`. One row per trial. Keep raw video files outside the repo, and put a timestamp or path reference in `evidence_ref`.
Set `source_type` to `community-measurement` for our own measurements. Use `inferred` for values derived from others, for example gravity computed from h and t. Set `confidence` to high when the spread is small across 3 or more trials, medium otherwise, and low for a single trial.
