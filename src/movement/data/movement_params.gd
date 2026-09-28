class_name MovementParams
extends Resource
## Global movement tunables (docs/design/movement_architecture.md section 8.1).
## Script defaults are the frozen spec baseline (specs/movement.md). Tune only in .tres files.
## Units: meters, seconds, m/s. 1 u = 0.0254 m.

# --- units / tick -------------------------------------------------------------
@export var tick_rate: int = 64                                  # spec: movement.md §1
@export var unit_m: float = 0.0254                               # spec: movement.md §1

# --- capsule / collision --------------------------------------------------------
@export var capsule_radius: float = 0.4064                       # spec: movement.md §20 (16 u)
@export var capsule_height_stand: float = 1.8288                 # spec: movement.md §20 (72 u)
@export var capsule_height_crouch: float = 1.2192                # spec: movement.md §20 (48 u)
@export var eye_height_stand: float = 1.6256                     # spec: movement.md §20 (64 u)
@export var eye_height_crouch: float = 1.0668                    # spec: movement.md §20 (42 u)
@export var crouch_eye_lerp_time: float = 0.1                    # spec: movement.md §6 (visual only)
@export var step_height: float = 0.4572                          # impl notes (18 u)
@export var ground_probe_distance: float = 0.0508                # impl notes (2 u)
@export var max_floor_angle_deg: float = 45.573                  # impl notes (normal.y >= 0.7)
@export var collision_margin: float = 0.001
@export var max_bumps: int = 4

# --- ground locomotion ----------------------------------------------------------
@export var ground_accel: float = 4.0                            # spec: movement.md §2 (Open Q1)
# measured session 5 (Haze k 4.15, Infernus k 4.9 -> k * run = 1601 u/s^2): accel = ground_accel * this, for every
# hero. With friction 4 the ground steady state is 400 u/s; wishspeeds above that are unmeasured. Crouch-walk accel is
# unmeasured too (it uses the same constant).
@export var ground_accel_ref_speed: float = 10.16                # 400 u/s
@export var ground_friction: float = 4.0                         # spec: movement.md §2 (Open Q1)
@export var stop_speed: float = 2.54                             # spec: movement.md §2 (100 u/s)
@export var backpedal_mult: float = 1.0                          # spec: movement.md §2 (Open Q2)
@export var strafe_mult: float = 1.0                             # spec: movement.md §2 (Open Q2)
@export var firing_speed_mult: float = 0.75                      # spec: movement.md §2

# --- sprint ---------------------------------------------------------------------
@export var sprint_delay: float = 3.0                            # spec: movement.md §3
@export var sprint_instant_cap: float = 2.5                      # spec: movement.md §3
@export var sprint_ramp_rate: float = 0.6                        # spec: movement.md §3
@export var sprint_reset_on_opposing_input: bool = true          # spec: movement.md §3 (opposing keys held, InputCmd.BTN_OPPOSE_X/Y)
@export var sprint_stop_speed: float = 0.254                      # spec: movement.md §3 "stopping": no move input and below 10 u/s (value not in spec)
@export var sprint_reset_on_stop: bool = false                   # measured: sprint survives a 1 s stop and is on from standstill (session2_findings.md); true = spec §3 "stopping"

# --- stacking / slows -----------------------------------------------------------
@export var move_bonus_dr_k: float = 12.0                        # spec: movement.md §4
@export var vent_speed_mult: float = 1.7                         # spec: movement.md §4
@export var slow_floor_speed: float = 2.0                        # spec: movement.md §5
@export var slow_air_drag_factor: float = 0.35                   # spec: movement.md §5, §12
@export var damage_slow_fraction: float = 0.20                   # spec: movement.md §5
@export var damage_slow_duration: float = 1.0                    # spec: movement.md §5 (Open Q16)
@export var rope_damage_slow: float = 0.40                       # spec: movement.md §5, §17
@export var rope_damage_slow_time: float = 4.0                   # spec: movement.md §5, §17

# --- stamina --------------------------------------------------------------------
@export var stamina_epsilon: float = 0.00001                     # spec: movement.md §7
@export var stamina_display_cap: int = 8                         # spec: movement.md §7
@export var cost_ground_dash: float = 1.0                        # spec: movement.md §7, §8
@export var cost_air_dash: float = 1.0                           # spec: movement.md §7, §11
@export var cost_dash_jump_extra: float = 1.0                    # spec: movement.md §7, §9
@export var cost_air_jump: float = 1.0                           # spec: movement.md §7; user-confirmed costs 1 (session-4 SAJ "free" was fast-stamina contaminated)
@export var cost_wall_jump_subsequent: float = 0.5               # spec: movement.md §7, §14
@export var cost_down_dash: float = 0.5                          # G28: 0.5 per wiki Stamina page (fidelity gaps, research-settled; K54)
@export var wall_jump_combat_regen_penalty: float = 0.25         # spec: movement.md §7, §14
@export var wall_jump_combat_regen_penalty_time: float = 5.0     # spec: movement.md §7, §14
@export var in_combat_time: float = 3.0                          # spec: movement.md §14 "in combat" = hero/neutral interaction or damage within this window (value not in spec)

# --- ground dash / dash-jump ----------------------------------------------------
@export var ground_dash_distance: float = 10.0                   # spec: movement.md §8
@export var ground_dash_durations: Array[float] = [0.62, 0.68, 0.72]  # spec: movement.md §8. Speed = distance / duration matches B1-B3 exactly (session2_findings.md)
@export var dash_neutral_uses_facing: bool = true                # spec: movement.md §8
@export var dash_distance_scale_mode: int = 1                    # 0 = scale duration, 1 = scale speed; 1 per ground_dash.md rule 6 (dash slow scales speed, not duration)
@export var ground_dash_exit_clamp: bool = false                 # Open Q6 settled: no clamp, speed decays by ground friction (session2_findings.md)
@export var ground_dash_whole_ticks: bool = true                 # floor(duration x 64) full ticks, no fractional last tick: fits B1-B3 (session2_findings.md)
@export var neutral_dash_does_nothing: bool = true              # measured: a ground or air dash with no move input does nothing (session2_findings.md); false = spec §8 dash toward facing
@export var dash_jump_window_open: float = 0.3                   # G06: 0.30 s per the 2026-06-30 notes (ground_dash.md rule 11, ziplines_melee_misc E15); PROVISIONAL (G06): conflicts with V17 "0.05 s later" (0.35 s, video_guides.md), pending clip D-series
@export var dash_jump_window_length: float = 0.25                # G06: window 0.30-0.55 s (ground_dash.md rule 11; K55)
@export var dash_jump_vertical_speed: float = 10.795             # G05: 425 u/s (ground_dash.md rule 13; K13 vertical)
@export var dash_jump_coyote_time: float = -1.0                  # PROVISIONAL (G18): <0 = whole window stays open after dashing off a ledge (ground_dash.md rule 15); exact grace pending recording
# G17 dash-jump horizontal. 0 = legacy: keep the bucket's dash speed x dash_jump_horizontal_mult (K13,
# contradicted); 1 = SET to dash_jump_set_speed in every bucket, prior discarded (ground_dash.md rule 13 /
# momentum table, video_guides V9 0:19 "same velocity for every bucket"). The value is measured (session 4).
@export var dash_jump_speed_mode: int = 1
@export var dash_jump_set_speed: float = 17.856                  # measured session 4: 703 u/s set for Haze (B1, dash 635) and Abrams (B3, dash 547); was ~611 from V9
@export var dash_jump_horizontal_mult: float = 1.0               # legacy mode 0 only (K13, contradicted by V9 0:19)
@export var dash_jump_air_control_bonus: float = 0.30            # spec: movement.md §9
@export var dash_jump_air_control_time: float = 0.25             # spec: movement.md §9
# G21 dash slide start speed: SET along the dash direction on every dash-slide entry, all buckets
# (video_guides V5 0:17 "always starts at 650 u/s"; Leif). < 0 = keep the current dash speed (K15, ground_dash.md
# rule 7 wording). PROVISIONAL (G21): single source; the "dead slide" before 0.3 s is not modeled; pending clip D2.
@export var dash_slide_speed: float = 16.511                   # measured session 5: 650 u/s; friction on the entry tick makes the first slide tick read 643 (game 641-643)

# --- jump / gravity -------------------------------------------------------------
@export var jump_speed: float = 7.62                             # measured ~300 u/s on plain jumps (session2_findings.md); spec §10 was 7.493 (295 u/s)
@export var gravity: float = 20.32                               # measured 798-801 u/s^2 on plain jumps (session2_findings.md); spec §10 was 24.562 (967 u/s^2)
@export var air_jump_speed: float = 13.26                        # measured session 4: vz set to ~522 u/s (was 7.493 = 295)
@export var air_jump_sets_vertical: bool = true                  # measured session 4: set, not added (rise ~168 u for any vz before)
# measured session 5 (DB*/DG* refit with drag, session5_audit.md): along the previous tick's wish the air jump tops
# v.wish up toward run speed, adding at most this much; no gate, no cap on |h|; nothing with no key held.
@export var air_jump_wish_add_max: float = 5.08                  # 200 u/s
@export var air_jumps_per_airtime: int = 1                       # spec: movement.md §10
@export var coyote_time: float = 0.0                             # spec: movement.md §10 (Open Q20)
@export var jump_buffer_time: float = 0.0                        # spec: movement.md §10 (Open Q20)
@export var action_buffer_time: float = 0.1                      # spec: movement.md §10

# --- air dash / down dash -------------------------------------------------------
@export var air_dash_distance: float = 8.0                       # spec: movement.md §11
@export var air_dash_durations: Array[float] = [0.43, 0.47, 0.51]  # spec: movement.md §11
@export var air_dash_whole_ticks: bool = false                   # as ground_dash_whole_ticks; measured air dashes do not fit it (session2_findings.md)
@export var air_dashes_per_airtime: int = 1                      # spec: movement.md §11
@export var air_dash_suspends_gravity: bool = true               # spec: movement.md §11
@export var air_dash_zero_vertical: bool = true                  # design §7.10: air dash zeroes vy (spec §11 says impulse; see deviations)
@export var air_dash_exit_clamp: bool = false                    # DEPRECATED (G02): contradicted by the end-drag model; kept off, only for A/B comparison
# G01 directional cap. 0 = legacy uncapped add (K18, contradicted), 1 = Hypothesis A
# v_par' = max(min(v_par + J, C), min(v_par, C)) with v_perp kept, 2 = set v_par = C (v_perp kept).
# PROVISIONAL (G01): V8 2:16 cap = per-bucket dash speed (732/670/642 u/s; ours derive from
# air_dash_distance / air_dash_durations, SM-scaled); Hyp A contradicts Leif's angle data (best angle
# 75 deg, not 90) so mode selection is pending recording clips A1, A2, A3.
# 3 = measured ramp (session2_findings.md, probes A_probe_b1..b3; refit session 5): v_perp kept; each dash tick
# v_par += min((rate - damping_c * (v_par - v_par0)) / duration * dt, target - v_par), with v_par0 the speed along
# the dash at its start and target = target_frac[bucket] * bucket air dash speed + entry_frac * v_par0.
@export var air_dash_cap_mode: int = 3
@export var air_dash_cap_override: float = -1.0                  # PROVISIONAL (G01): <= 0 = cap C is the bucket's air dash speed (V8); gap table's flat 17.78 m/s (700 u/s) is the alternative; pending A1-A3
@export var air_dash_ramp_rate: float = 49.0                     # measured session 5: 49 m/s (accel x duration)
@export var air_dash_ramp_damping_c: float = 0.85                # measured session 5: damps on the speed gained since the dash start, not on v_par (36 trials, rms 3.9)
@export var air_dash_ramp_target_fracs: Array[float] = [0.759, 0.776, 0.789]  # measured session 5: peak intercepts 554.1/516.1/484.7 u/s over 8 m / duration
@export var air_dash_ramp_entry_frac: float = 0.26               # measured session 5-6: peak slope vs entry v_par >= 0 (holds to +673, E700W)
@export var air_dash_ramp_entry_frac_neg: float = 0.35           # measured session 6: peak slope for entries against the dash (E386S -348 -> 434, E700S -641 -> 327); B2/B3 only probed near -60
@export var air_dash_keeps_air_drag: bool = true                 # measured: speed decays ~0.19/s during the dash (spec §11 suspends drag)
@export var air_dash_drag: float = 0.2                           # measured session 4: 1/s during the air dash only (A_air_b1 572 -> 538 over 0.31 s)
# G02 end drag at the airborne end of an air dash. 0 = off, 1 = V8 (a) v' = max(min(v, floor), v - frac*(v - offset)),
# 2 = V9 (b) v' = v - frac*max(0, v - floor), 3 = flat v' = v*(1 - frac) ("20% of total", V1/V6),
# 4 = measured: the excess over floor is removed in equal steps over air_dash_end_drag_ticks airborne ticks
# (537 -> ~482 u/s for B1, 497 -> ~482 for B2, none below 480; session2_findings.md).
# Skipped in the zip exit window, when landed before the dash ends (IAD), and when another air dash
# starts first; a wall jump does not cancel it (V10 3:18). PROVISIONAL (G02): pending recording clip A2.
@export var air_dash_end_drag_mode: int = 4
@export var air_dash_end_drag_ticks: int = 7                     # measured: ~7 ticks for B1 and B2
@export var air_dash_end_drag_frac: float = 0.2                  # PROVISIONAL (G02): 20% (V8 2:38, V9 1:09, V2 3:03); pending A2
@export var air_dash_end_drag_offset: float = 2.032              # PROVISIONAL (G02): 80 u/s, formula (a) only (V8 2:38); pending A2
@export var air_dash_end_drag_floor: float = 12.192              # PROVISIONAL (G02): 480 u/s, no drag below (V8, V9 1:09); pending A2
@export var air_dash_end_drag_prop: float = 0.175              # measured session 6 (mode 4): at most 17.5% of the speed is removed (fast dashes keep ~81% with air drag)
@export var air_dash_end_drag_excess_keep: float = 0.25        # measured session 6 (mode 4): 25% of the excess over the floor is kept (settles 490-517 at 565-637)
# G02 IAD: landing during an air dash keeps the drag pending until the dash's scheduled end. It is skipped
# only when the player is then in a SLIDE on level ground (V2 0:11, V9 1:41); leaving the ground first (bhop,
# any drop) applies it at once (V2 0:33 / 3:03, V9 1:58). "Level" = ground normal y >= this value.
# PROVISIONAL (G02): V2 1:36 says a 2-3 u rise breaks it; the exact tolerance is pending clip A2.
@export var air_dash_iad_level_normal_y: float = 0.9999
@export var down_dash_double_tap_window: float = 0.4375          # spec: movement.md §11 (28 ticks)
@export var down_dash_speed: float = 15.0                        # spec: movement.md §11 (Open Q7)
@export var down_dashes_per_airtime: int = 1                     # spec: movement.md §11

# --- air control ----------------------------------------------------------------
@export var air_accel: float = 2.0                               # measured session 4 (Haze): ~780 u/s^2 = 2.0 x walk 386 u/s; scaling with walk speed is Source-style, assumed
@export var air_wishspeed_cap: float = 2.032                     # PROVISIONAL (G26): 80 u/s (V8, V3, V6, V16; spec 30 u/s contradicted, K26); pending recording clip A5
@export var air_wishspeed_cap_fast: float = 1.27                 # PROVISIONAL (G26): 50 u/s above air_fast_threshold (V8); pending A5
@export var air_fast_threshold: float = 17.78                    # PROVISIONAL (G26): 700 u/s horizontal (V8); pending A5
@export var air_strafe_threshold: float = 11.43                  # 450 u/s regime split (air_movement.md rule 27, wiki E8; conflicts with V8's 700, slide_and_slopes.md)
# K26: the x0.5 accel above 450 u/s has no source (the wiki gives the split, not a factor; V8/Leif model
# only the 700 u/s wishspeed cap), so it is neutral (1.0). PROVISIONAL (G26): pending A5.
@export var air_accel_high_speed_mult: float = 1.0
@export var air_drag: float = 0.2                                # measured session 5 (vz0 pinned by airtime): 0.196-0.228 on jumps, dash jumps, after an air dash

# --- slide ----------------------------------------------------------------------
@export var slide_entry_speed: float = 8.89                      # spec: movement.md §13 (350 u/s)
@export var slide_slope_min_angle_deg: float = 5.0               # spec: movement.md §13
@export var slide_friction: float = 0.1875                       # spec: movement.md §13; session 1 measured 0.189 on landing slides
# measured session 3: a ground-dash slide decays at 0.694/s (video_guides: ~0.6 since 2026-03-06, ~0.18 before)
@export var slide_friction_dash: float = 0.694
@export var slide_slope_friction: float = 0.0                     # measured session 7 (s7_ramp): normal slide on a slide slope, before the penalty
@export var slide_slope_friction_dash: float = 0.24               # measured session 7 (s7_ramp RDASH): dash slide on a slide slope, before the penalty
@export var slide_penalty_friction: float = 3.1875               # spec: movement.md §13
@export var slide_penalty_friction_dash_jump: float = 0.6875     # spec: movement.md §13; unused since session 4 (landings no longer make DASH_JUMP slides)
# measured session 3: with a move key held, slide velocity turns toward the key direction at this rate,
# speed unchanged; the mouse alone does not steer. 0 disables.
@export var slide_turn_rate_deg: float = 92.0
@export var slide_bonus_table: Array[float] = [0.0, 0.35, 0.50, 0.80]        # spec: movement.md §13
# measured session 4 (lslide): a landing slide hits the penalty 44 ticks (0.69 s) after touchdown (spec 0.75);
# the spec's +0.25 s per bonus step is kept
@export var slide_onset_table: Array[float] = [0.69, 0.94, 1.19, 1.44]
# measured session 5: the penalty starts 1.00 s into a ground-dash slide (session 3's 0.96 was paired with the low 636 entry)
@export var slide_onset_table_dash: Array[float] = [1.00, 1.25, 1.50, 1.75]  # knee - t(643) median 62.95 ticks; bonus steps unmeasured
@export var slide_onset_table_dash_jump: Array[float] = [1.00, 1.25, 1.50, 1.75]  # spec: movement.md §13; unused since session 4
# measured session 4 (hop): a jump out of a ground-dash slide cuts horizontal speed to x0.75 (0.74-0.79 at
# 350-640 u/s); jumps out of a landing slide or from walking are not cut.
@export var slide_jump_speed_mult_dash: float = 0.75
# measured session 4 (hop): a slide jump at least this far into the slide stores held crouch like a ground
# jump (lands crouched, no slide); earlier ones land back into a slide. PROVISIONAL: threshold between
# 11 and 18 ticks (SHJ10 slid, SHJ19 did not).
@export var slide_jump_store_crouch_time: float = 0.22
# G09 slide-hop penalty ("slide drag", slide_and_slopes.md rule 13; V4 0:47/2:13, V5 1:49, V15 1:14/1:39).
# Any slide jump sets the flag (not a dash-cancel short hop, not a superglide); with the flag set, a
# slide jump earlier than slide_hop_min_time into the slide adds slide_hop_penalty_drag to air drag.
# The flag clears after slide_hop_clear_time on the ground not sliding, or on a downhill slide jump.
# The zip exit drag immunity blocks it. PROVISIONAL (G09): pending recording clip S2.
@export var slide_hop_enabled: bool = true
@export var slide_hop_min_time: float = 0.5                      # PROVISIONAL (G09): 0.5 s (V4 0:34, V15 1:14, Eskay V7); pending S2
@export var slide_hop_penalty_drag: float = 1.3                  # PROVISIONAL (G09): measured session 6 (SHH6 hop ~6 ticks into the slide): extra drag decays (+1.5/s ticks 4-12, +0.9 12-22, ~0 after); box 1.3 x 20 ticks matches apex 229 and landing 214
@export var slide_hop_penalty_time: float = 0.3125               # PROVISIONAL (G09): 20 ticks (session 6; drag x time ~0.4 is the fitted valley); < 0 = until landing
# measured session 6: a landing into a NORMAL slide below this speed loses one ground-friction tick (x0.9375).
# PROVISIONAL: threshold bracketed 428-466 u/s (LSD12 loses at 427, DJS7 keeps at 469).
@export var landing_slide_friction_speed: float = 11.43           # 450 u/s
@export var slide_hop_clear_time: float = 0.25                   # PROVISIONAL (G09): placeholder for "a short time on the ground" (V4 2:13); pending S2

# --- wall jump ------------------------------------------------------------------
@export var wall_detect_distance: float = 0.3048                 # spec: movement.md §14 (Open Q12)
@export var wall_max_normal_y: float = 0.3                       # spec: movement.md §14
@export var wall_jump_up_speed: float = 13.183                   # measured session 3: ~519 u/s launch at vz = 0 before the press
@export var wall_jump_up_vz_gain_fall: float = 0.30              # measured session 3: launch vz += gain * vz before the press while falling (-221 -> 453)
@export var wall_jump_up_vz_gain_rise: float = 0.12              # measured session 3: same while rising (+215 -> 542)
@export var wall_jump_kick_toward: float = 5.461                 # measured session 3: 215 u/s off the wall with W held straight in (d = -1)
@export var wall_jump_kick_neutral: float = 6.807                # measured session 3: 268 u/s with no key; the kick is interpolated linearly in d = wish.normal
@export var wall_jump_kick_away: float = 9.169                   # measured session 3: 361 u/s with S held straight away (d = +1)
@export var wall_jump_kick_tangent: float = 3.734                 # measured session 3: 147 u/s along the wall per unit of the wish's tangential component (A/D)
@export var wall_jump_free_count: int = 1                        # spec: movement.md §14
@export var wall_slide_max_fall: float = 15.24                   # G36: -600 u/s fall cap on a wall (walls_and_ledges.md rule 21); PROVISIONAL (G36): trigger (airborne + wall contact + falling) pending recording
@export var wall_jump_fatigue_per_jump: float = 1.0              # measured session 4 (wallfat): each wall jump sets fatigue to full
@export var wall_jump_fatigue_min_mult: float = 0.0              # measured session 4: no floor (the base up speed goes to ~0 right after a wall jump)
@export var melee_wall_fatigue: float = 0.25                     # PROVISIONAL: airborne melee fatigue (spec §19); amount unmeasured, keeps the pre-session-4 value
# G33: a wall jump too soon after the previous one gives no height and no distance (video_guides V7 14:14),
# and extra jump presses next to a wall are eaten, not spent as an air jump (V18 Stairs 1:21). Modeled as a
# minimum interval between wall jumps; a press inside it is consumed with no effect.
# PROVISIONAL (G33): 0.125 s placeholder ("slightly longer than a double jump or a dash", V7); pending clip W5.
@export var wall_jump_min_interval: float = 0.125
@export var wall_jump_fatigue_recovery: float = 1.95             # measured session 4 (wallfat): linear recovery over ~125 ticks
@export var wall_jump_fatigue_recovery_exponent: float = 1.0      # measured session 4: linear fits (rms ~8 u/s)
# G03 wall jump: incoming velocity is split into normal and tangential parts; tangential is kept
# (V13 0:18, V6 17:09, V7 8:19). PROVISIONAL (G03): pending recording clip W1.
@export var wall_jump_tangent_keep: float = 0.95                 # measured session 3: incoming tangent kept at ~0.9-1.0 (165 -> 147 at 25 deg, 250 -> 245 at 45 deg)
@export var wall_jump_normal_mode: int = 0                       # PROVISIONAL (G03): 0 = normal axis set to the kick, 1 = kick added to the incoming normal speed; pending W1

# --- mantle ---------------------------------------------------------------------
@export var mantle_min_height_u: int = 32                        # spec: movement.md §15
@export var mantle_band_tops_u: Array[int] = [64, 96, 128, 162]  # measured session 7 (mantle2 truck: a 162 u ledge mantles from a ground press; lower bound, true max unmeasured)
@export var mantle_climb_speed: float = 3.353                    # measured session 4 (3 heights): average climb 132 u/s + ...
@export var mantle_climb_speed_per_height: float = 1.2           # ... 1.2/s x ledge height (66 u ~211, 94 u ~249, 162 u ~328 u/s)
@export var mantle_exit_speed: float = 4.496                     # measured session 4: ~177 u/s forward onto the top, kept after
@export var mantle_min_depth: float = 0.1524                     # spec: movement.md §15 (6 u)
@export var mantle_reach: float = 0.6                            # spec: movement.md §15
@export var mantle_requires_forward: bool = true                 # spec: movement.md §15
@export var mantle_glide_speed: float = 13.64                    # measured session 4: ~537 u/s after the exit phase
@export var mantle_hit_slow_start: float = 0.80                  # spec: movement.md §15
@export var mantle_hit_slow_end: float = 0.20                    # spec: movement.md §15
@export var mantle_hit_slow_time: float = 2.0                    # spec: movement.md §15

# --- zipline / rope -------------------------------------------------------------
@export var zip_speed_inner: float = 18.0                        # spec: movement.md §16
@export var zip_speed_outer: float = 21.0                        # spec: movement.md §16
@export var zip_boost_mult: float = 0.8                          # spec: movement.md §16
@export var zip_boost_duration: float = 32.0                     # spec: movement.md §16
@export var zip_boost_cooldown: float = 360.0                     # spec: movement.md §16
@export var zip_boost_unlock_time: float = 360.0                  # spec: movement.md §16 (match clock = sim time)
@export var zip_express_mult: float = 0.8                         # spec: movement.md §16 express lines +80%
@export var zip_attach_radius: float = 1.0                       # spec: movement.md §16 (Open Q14)
@export var zip_attach_lockout: float = 3.0                      # spec: movement.md §16
@export var zip_knockoff_window: float = 3.0                     # spec: movement.md §16
@export var zip_knockoff_stun: float = 2.5                       # spec: movement.md §16
@export var zip_exit_momentum_time: float = 2.0                  # spec: movement.md §16
@export var zip_exit_drag: float = 0.25                          # G46: air drag after the 2 s zero-drag window (ziplines_melee_misc.md); PROVISIONAL (G46): persistence until landing assumed (research Q3)
@export var rope_climb_speed: float = 4.0                        # spec: movement.md §17
@export var rope_attach_radius: float = 0.8                      # spec: movement.md §17

# --- melee / parry --------------------------------------------------------------
@export var heavy_windup_time: float = 0.36                      # G12: 0.36 s windup (ziplines_melee_misc.md)
@export var heavy_lunge_speed_ground: float = 19.05              # G10: 750 u/s (ziplines_melee_misc.md; K29); PROVISIONAL (G10): profile pending H1
@export var heavy_lunge_speed_air: float = 20.2438               # G10: 797 u/s (ziplines_melee_misc.md; K29); PROVISIONAL (G10): profile pending H1
@export var heavy_lunge_time: float = 0.6                        # G10: max lunge time 0.6 s (no target contact simulated); PROVISIONAL (G10): contradicts "half a dash" (research Q5), pending H1
@export var heavy_recovery_time: float = 0.2833                  # G12: 0.2833 s, velocity zeroed on all axes (ziplines_melee_misc.md; K28, K30)
@export var heavy_turn_rate_mult: float = 0.3                    # spec: movement.md §19
@export var heavy_cooldown_hit: float = 1.0                      # spec: movement.md §19
@export var heavy_cooldown_miss: float = 1.3                     # spec: movement.md §19
@export var light_self_slow: float = 0.2                         # spec: movement.md §19
@export var light_self_slow_time: float = 0.3                    # spec: movement.md §19
@export var heavy_self_slow: float = 0.3                         # spec: movement.md §19
@export var heavy_self_slow_time: float = 0.5                    # spec: movement.md §19
@export var parry_duration: float = 1.0                          # spec: movement.md §19
@export var parry_move_mult: float = 0.0                         # G45: parry roots the player; gravity kept (ziplines_melee_misc.md; K56)
@export var parry_fail_cooldown: float = 4.5                     # spec: movement.md §19

# --- misc -----------------------------------------------------------------------
@export var fall_damage_enabled: bool = false                    # spec: movement.md §18


## Returns human-readable warnings; empty means the params are consistent.
func validate() -> PackedStringArray:
	var w := PackedStringArray()
	if ground_accel < ground_friction:
		w.append("ground_accel (%f) < ground_friction (%f): ground steady speed %f m/s falls short of ground_accel_ref_speed" % [ground_accel, ground_friction, ground_accel * ground_accel_ref_speed / ground_friction])
	if ground_dash_durations.size() != 3:
		w.append("ground_dash_durations must have 3 entries (dash buckets 1..3)")
	if air_dash_durations.size() != 3:
		w.append("air_dash_durations must have 3 entries (dash buckets 1..3)")
	if slide_bonus_table.size() != slide_onset_table.size() or slide_bonus_table.size() != slide_onset_table_dash_jump.size() or slide_bonus_table.size() != slide_onset_table_dash.size():
		w.append("slide_bonus_table / slide_onset_table / slide_onset_table_dash_jump lengths differ")
	for i in range(1, slide_bonus_table.size()):
		if slide_bonus_table[i] < slide_bonus_table[i - 1]:
			w.append("slide_bonus_table is not monotonic at index %d" % i)
	var prev: int = mantle_min_height_u
	for i in mantle_band_tops_u.size():
		if mantle_band_tops_u[i] <= prev:
			w.append("mantle_band_tops_u is not monotonic at index %d" % i)
		prev = mantle_band_tops_u[i]
	for d in ground_dash_durations:
		if d <= 0.0:
			w.append("ground dash duration must be > 0")
	for d in air_dash_durations:
		if d <= 0.0:
			w.append("air dash duration must be > 0")
	if air_dash_cap_mode < 0 or air_dash_cap_mode > 3:
		w.append("air_dash_cap_mode must be 0..3")
	if air_dash_ramp_target_fracs.size() != 3:
		w.append("air_dash_ramp_target_fracs must have 3 entries (dash buckets 1..3)")
	if air_dash_end_drag_mode < 0 or air_dash_end_drag_mode > 4:
		w.append("air_dash_end_drag_mode must be 0..4")
	if air_dash_end_drag_ticks < 1:
		w.append("air_dash_end_drag_ticks must be >= 1")
	if wall_jump_normal_mode < 0 or wall_jump_normal_mode > 1:
		w.append("wall_jump_normal_mode must be 0..1")
	if dash_jump_speed_mode < 0 or dash_jump_speed_mode > 1:
		w.append("dash_jump_speed_mode must be 0..1")
	# value sanity checks (not gameplay caps): fractions in [0, 1], magnitudes and times >= 0
	for pair in [["air_dash_end_drag_frac", air_dash_end_drag_frac], ["wall_jump_fatigue_min_mult", wall_jump_fatigue_min_mult], ["air_accel_high_speed_mult", air_accel_high_speed_mult]]:
		if float(pair[1]) < 0.0 or float(pair[1]) > 1.0:
			w.append("%s must be in [0, 1] (got %f)" % [pair[0], float(pair[1])])
	for pair in [["air_dash_end_drag_floor", air_dash_end_drag_floor], ["air_dash_end_drag_offset", air_dash_end_drag_offset],
			["wall_jump_tangent_keep", wall_jump_tangent_keep],
			["wall_jump_min_interval", wall_jump_min_interval], ["air_wishspeed_cap", air_wishspeed_cap],
			["air_wishspeed_cap_fast", air_wishspeed_cap_fast],
			["slide_hop_penalty_drag", slide_hop_penalty_drag], ["slide_hop_min_time", slide_hop_min_time],
			["slide_hop_clear_time", slide_hop_clear_time], ["dash_jump_set_speed", dash_jump_set_speed],
			["heavy_lunge_time", heavy_lunge_time], ["air_accel", air_accel], ["air_drag", air_drag]]:
		if float(pair[1]) < 0.0:
			w.append("%s must be >= 0 (got %f)" % [pair[0], float(pair[1])])
	if air_fast_threshold <= 0.0:
		w.append("air_fast_threshold must be > 0")
	if wall_slide_max_fall <= 0.0:
		w.append("wall_slide_max_fall must be > 0")
	if air_wishspeed_cap_fast > air_wishspeed_cap:
		w.append("air_wishspeed_cap_fast (%f) > air_wishspeed_cap (%f): V8 has the fast cap lower" % [air_wishspeed_cap_fast, air_wishspeed_cap])
	if air_dash_iad_level_normal_y <= 0.0 or air_dash_iad_level_normal_y > 1.0:
		w.append("air_dash_iad_level_normal_y must be in (0, 1]")
	if air_dash_exit_clamp and air_dash_end_drag_mode != 0:
		w.append("air_dash_exit_clamp (deprecated) and air_dash_end_drag_mode both active")
	if tick_rate != 64:
		w.append("tick_rate %d differs from the 64 Hz baseline" % tick_rate)
	return w
