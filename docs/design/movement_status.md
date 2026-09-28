# Movement prototype: status

Status as of 2026-09-27. Godot 4.4.1, Jolt Physics, 64 Hz sim. Design: `docs/design/movement_architecture.md`. Behaviour spec: `specs/movement.md`.

## How to run

Godot console executable used below:

```
$G = "D:\PortablePrograms\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe"
$P = "C:\Godot Projects\deadlock_like\deadlock_like"
```

| What | Command |
|---|---|
| Import / reimport | `& $G --headless --path $P --import` |
| Play the sandbox (main scene) | `& $G --path $P` (or open the project in the editor and press F5) |
| Headless smoke run of the main scene | `& $G --headless --path $P --quit-after 300` |
| Full test suite | `& $G --headless --path $P -s res://tests/run_tests.gd` |
| Subset of tests | `& $G --headless --path $P -s res://tests/run_tests.gd -- --filter=T04,T22` |
| Physics parity (Jolt vs GodotPhysics3D, T33) | `powershell -ExecutionPolicy Bypass -File tools\test_parity.ps1` |

The main scene is `res://scenes/main/movement_sandbox.tscn`. It contains the greybox arena (`scenes/arena/movement_arena.tscn`), the `PlayerCharacter`, the `LocalController` (input sampler, camera rig and crosshair) and the `MovementDebugOverlay`. All are wired through `player_path`.

Measurement CSVs from the recorder (F7) are appended to `user://measurements/sim_predictions.csv`.

## Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Space | Jump (hold toward a ledge to mantle) |
| Left Ctrl or C | Crouch / slide |
| Left Shift | Dash (ground / air; crouch + dash in air = down dash) |
| Left mouse | Fire (only affects move speed while firing) |
| Q tap | Light melee (fires on release, under 0.2 s) |
| Q hold (0.2 s or more), Mouse 5 | Heavy melee |
| F | Parry |
| E | Ability 1 (dash-jump cancel) |
| V | Zipline boost |
| Esc | Toggle mouse capture (a click re-captures) |
| F1 | Show/hide the debug overlay |
| F2 | Time scale 1 / 0.5 / 0.25 / 0.1 |
| F3 | Infinite stamina |
| F4 / F8 | Teleport to next arena station / to the first one |
| F5 | Pause the sim |
| F6 | Step one tick (while paused) |
| F7 | Start/stop a measurement recording (recipe picked in the overlay) |

## Test results

Final run after the review fixes: `44 passed, 0 failed (about 3.0 s)` on Jolt (32 numbered tests, the arena smoke test and 11 review regression tests in `tests/cases/test_review_fixes.gd`). The parity script passes the T33 subset (T02–T05, T21–T25) on both Jolt and GodotPhysics3D. A headless `--import` and a 300-frame headless run of the main scene report no errors or warnings.

| ID | Test | Result | Notes |
|---|---|---|---|
| T01 | Units and ticks | pass | |
| T02 | Walk acceleration | pass | |
| T03 | Walk stop | pass | |
| T04 | Standing jump | pass | Fixed in integration (see below) |
| T05 | Ground dash buckets | pass | |
| T06 | Dash-jump window | pass | Updated in fidelity pass 1 (G06): window 0.30-0.55 s, last tick k=35, close event k=36 |
| T07 | Dash slide buckets | pass | |
| T08 | Dash-jump slide | pass | |
| T09 | Air dash buckets | pass | |
| T10 | Air drag | pass | Updated in fidelity pass 1 (G08): drag 0.2/s gives 8.1847, and 7.9023 under SLOW 0.5 (was 9.0477 / 8.8905 at 0.1/s) |
| T11 | Stamina regen | pass | |
| T12 | Move bonus diminishing returns | pass | |
| T13 | Slows | pass | |
| T14 | Sprint and damage slow | pass | Rewritten in review: default damage resets sprint (7.2 m/s, SPRINT_RESET reason damage); `resets_sprint: false` damage gives 8.48 with sprint kept; a +2 m/s MOVE_BONUS item (9.2 m/s) checks the §5 damage slow (8.8 m/s) |
| T15 | Vent | pass | |
| T16 | Sprint ramp | pass | End rewritten in review: a crouch press while sprinting slides with sprint kept; the slide ending in CROUCH resets sprint |
| T17 | Down dash double tap | pass | |
| T18 | Air jump | pass | |
| T19 | Stun and parry | pass | |
| T20 | Crouch | pass | |
| T21 | Slope slide | pass | |
| T22 | Stairs | pass | Fixed in integration (see below) |
| T23 | Wall slide | pass | |
| T24 | Walkable limit | pass | |
| T25 | Mantle bands | pass | Fixed in integration (see below) |
| T26 | Wall jump | pass | |
| T27 | Zipline | pass | |
| T28 | Rope | pass | |
| T29 | Determinism | pass | |
| T30 | Serialization | pass | |
| T31 | Params resource | pass | |
| T32 | No Input singleton in sim | pass | |
| T33 | Physics parity | pass | `tools/test_parity.ps1` |
| - | Arena smoke (`test_arena_full_layout`) | pass | Extra test, not numbered |
| RF1 | Downhill stays grounded | pass | Walk down 25° and 40° ramps, ground dash down 25°: 0 airborne ticks |
| RF2 | Step-down and stairs descent | pass | Off a 0.3 m step and down 16 u stairs: 0 airborne ticks |
| RF3 | Downhill dash-jump | pass | Jump at k=22 on a 12° downhill dash-jumps |
| RF4 | Crouch storage never slides | pass | Flat and 20° slope; ends in CROUCH |
| RF5 | Sprint resets | pass | Opposing keys reset, turning around does not, stopping clears the timer |
| RF6 | Wall-jump combat penalty | pass | Penalty only after a combat interaction |
| RF7 | Jump buffer | pass | `jump_buffer_time` 0.1: press 2 ticks before landing becomes a free ground jump; default 0 still air-jumps |
| RF8 | Crouched mantle ends standing | pass | Plus the GROUND + crouch-capsule safety net |
| RF9 | Zipline boost and clearance | pass | Locked before 360 s, +80% after, cooldown blocks a re-press; 1.2 m rail keeps feet above the floor |
| RF10 | Fatigue exponent | pass | k=1 and k=2 at half recovery |
| RF11 | Melee self-slow is a SLOW | pass | |

### Integration fixes

All three failures were in CORE code. The tests were kept at their spec values.

1. **T04 jump height (+0.87 mm).** `KinematicMover.test_motion` returned the engine's travel even when nothing was hit. That travel includes contact recovery (depenetration inside the 1 mm margin), so the first tick of a jump off the floor gained about 0.9 mm. An unobstructed sweep now returns exactly the requested motion.
2. **T22 stairs blocked.** When the step-up pass traced back down, the capsule's round bottom touched the tread's front edge. That contact has a slanted normal (n.y about 0.5–0.7), so the step was rejected. `KinematicMover.move` now also accepts a down contact that faces up and lies above the start height by no more than `step_height`. The capsule then rides over the edge. 8, 16 and 18 u steps climb without leaving the ground; 20 u still blocks.
3. **T25 170 u ledge mantled.** `MantleState.try_start` measured ledge height from the feet in mid-jump, so a 170 u ledge read as about 157 u. When airborne it now measures from the first walkable floor straight below (new helper `KinematicMover.floor_y_below`). If there is no floor below, it falls back to the feet.

### Review fixes

A code review raised 24 findings. All were applied, except where a deviation is recorded below. The largest fix was to ground separation: `_categorize` compared the horizontal velocity with the tilted ground normal. As a result, walking or dashing downhill, and walking off steps, counted as leaving the ground. Walking and dash states now separate only on `velocity.y`. SLIDE, whose velocity lies in the plane, still uses the normal. Other fixes:

- Sprint rules (§3).
- Jump buffer wiring (§10).
- Crouch storage (§6).
- Zipline boost cooldown and unlock, lanes from params, and a collision sweep with a clamped hang offset while riding (§16).
- Mantle uncrouch.
- Teleport snapping and yaw interpolation in `PlayerCharacter`.
- Mover query caching.
- Real depenetration travel kept in `test_motion`.
- Item data values.

## Fidelity pass 1 (research-settled)

This pass implemented the gaps marked R (research-settled) in `docs/design/movement_fidelity_gaps.md`, plus the G18 coyote dash-jump, the dash bucket roster and the dash-slow rule. G01-G04 and G09 (and K18, K20, K24, K25) were out of scope because another engineer owns them. Every code change cites its gap ID. Numbers that are not fully settled are marked `PROVISIONAL (Gxx)` in the code and in `movement_params.gd`.

Suite: `60 passed, 0 failed (about 4.8 s)`. That is the 44 earlier tests plus 16 new ones in `tests/cases/test_fidelity_pass1.gd`.

| Gap | Change | Test |
|---|---|---|
| G05 (K13 vertical) | `dash_jump_vertical_speed` 7.493 -> 10.795 m/s (425 u/s). Flat dash-jump airtime is now about 0.879 s. | `test_fp1_g05_dash_jump_vertical` |
| G06 (K55) | `dash_jump_window_length` 0.2 -> 0.25. The last tick moves from k=31 to k=35. | `test_t06_dash_jump_window` (updated) |
| G07 | New `MoveState.dash_jump_locked`: a jump pressed at k < 20 locks out the dash-jump for that dash. The early press stays buffered, since what it does instead is undocumented. | `test_fp1_g07_early_jump_lockout` |
| G08 (K27) | `air_drag` 0.1 -> 0.2 -> 0 -> **0.2** (session 5: the session-4 "no drag" was a fit artifact; with vz0 pinned by airtime every flight shows ~0.2/s). The air dash uses its own `air_dash_drag` 0.2. | `test_t10_air_drag` (updated) |
| G10 (K29) | New `heavy_lunge_speed_ground` 19.05 and `heavy_lunge_speed_air` 20.2438 replace `heavy_lunge_distance`. `heavy_lunge_time` 0.3 -> 0.6. **Moved to provisional (review):** 750/797 u/s over 0.6 s gives about 11.4/12.1 m, against about 5 m in research Q5. The conflict is unresolved and no speed curve is invented; pending H1. | `test_fp1_g10_heavy_lunge_ground`, `test_fp1_g10_heavy_lunge_air` |
| G11 (K35) | `mantle_glide_speed` 8.9 -> 13.97 m/s. | `test_fp1_g11_mantle_glide` |
| G12 (K28, K30) | Recovery zeroes velocity on every axis, with no gravity. The lunge-end walk-speed clamp is removed. `heavy_recovery_time` 0.2 -> 0.2833 and `heavy_windup_time` 0.35 -> 0.36. | `test_fp1_g12_heavy_recovery_zero` (windup also in `test_fp1_g10_heavy_lunge_ground`) |
| G13 | The wall jump uses the closest contact's normal and `convex` flag (`find_walls` now returns `distance`), not the average. | `test_fp1_g13_closest_wall_normal` |
| G18 | New `dash_jump_coyote_time` (default -1 = the whole window): after dashing off a ledge the window stays open, and the dash-jump uses no air jump. PROVISIONAL. | `test_fp1_g18_coyote_dash_jump` |
| G20 | A crouch press during GROUND_DASH (grounded) starts the DASH slide at the current speed. A crouch held at dash start stays stored. | `test_fp1_g20_dash_slide_on_press` |
| G28 (K54) | `cost_down_dash` 1.0 -> 0.5. | `test_fp1_g28_down_dash_cost` |
| G36 | New `wall_slide_max_fall` 15.24 m/s (-600 u/s), applied after categorize while in AIR, falling faster than the cap and touching a wall. **Moved to provisional (review):** the trigger conditions are not sourced. | `test_fp1_g36_wall_slide_cap` |
| G40 (K6) | Crouch held at takeoff (`_leave_ground`, `do_ground_jump`, and the dash-jump when crouch was stored) sets `slide_block_until_crouch_release`. The block is cleared only by releasing crouch, in the air or on the ground. `_land` crouches instead of sliding while it is set. A slide jump stores it too, unless it comes earlier than `slide_jump_store_crouch_time` (0.22 s, PROVISIONAL) into the slide; that one lands back into a slide (measured session 4). A jump out of a dash slide also cuts horizontal speed by `slide_jump_speed_mult_dash` 0.75. | `test_fp1_g40_crouch_storage_takeoff`, `test_fp1_dash_slide_jump` |
| S4-LS | A dash-jump landing no longer forces a DASH_JUMP slide. With crouch held it slides only above `slide_entry_speed` or on a slide slope, as a NORMAL slide. `slide_onset_table[0]` is 0.69 s (44 ticks after touchdown; spec 0.75), and the bonus steps are shifted to match. Measured session 4 (lslide). | `test_fp1_dash_jump_landing_slide` |
| S4-WF | Wall-jump fatigue: set to 1 per wall jump, linear recovery 1.95 s, scales only the base up speed (no floor); kick unfatigued | `session4_findings.md` "Wall-jump fatigue", rec_auto/wallfat | `test_wall_jump_fatigue_second_jump` |
| S7-SE | A crouch press on the ground needs `slide_entry_speed` on slopes too (no slope exception). Measured session 7: RS0 (rest) and RSW (crouch-walk 187) on ramp1 never slide. The landing path keeps its slope clause. | `test_t21_slope_slide` |
| S7-SL | Slides on slopes: velocity stays horizontal (no plane projection, no speed change at the top or bottom), plus a horizontal downhill accel g*tan(theta). Before the penalty, slope friction is 0 for a normal slide and 0.24/s for a dash slide. No slide (normal or dash) starts while moving uphill on a slide slope. Measured session 7 on one 26.5° ramp (RBOT/RDASH/RUP replays within ~5%); PROVISIONAL until a second angle. | wedge replay `scenarios/s7_fit_ramp` |
| S7-GO | A slide started by a crouch press on the ground (GROUND/CROUCH, `MoveState.slide_from_ground`) uses `slide_onset_table_ground` [0.60, 0.85, 1.10, 1.35]: the penalty starts 38 ticks after the press (game 38.0-39.3, s7_open SE340/SE360). Landing slides keep `slide_onset_table` (0.69 s). Bonus steps unmeasured. `slide_entry_speed` 350 u/s re-confirmed (slides at 350.2-350.7, not at <=347.5, lag-aligned). | `test_fp1_standing_slide_onset` |
| S7-WJ | `wall_jump_kick_tangent` 147 -> 107 u/s: the A/D kick adds on top of the incoming tangent the air strafe built before the press (kept x0.95). Session 3's 147 was the total, so the sim double-counted the pre-strafe (launch ~190 vs game 139-161; now ~150). Diagonals unfit. No-key air jump confirmed: no horizontal change (NK1/NK2). | `test_measured_wall_jump_launch` |
| S4-AJ | Air jump costs 1 stamina (`cost_air_jump` 1; the session-4 "free" reading was contaminated by fast stamina, corrected by the user). Along the previous tick's wish it tops v.wish up toward run speed by at most ~200 u/s; no gate, no cap on |h|, nothing with no key (session 5 refit with drag; DBL 434, DG diag ~454). Session 6: the add direction is the unnormalized key vector clamped per world axis to [-1, 1], with the cap scaled by its length, so diagonals lean toward the nearest world 45-degree line (yaw-dependent, 200-283 u/s from rest). | `session4_findings.md` "Air jump: stamina and horizontal", `session5_audit.md`, `session6_findings.md`, rec_auto/stam, rec_auto/double, rec_auto/s6_diag, rec_auto/s6_diagverify | `test_measured_air_jump_wish_accel`, `test_measured_air_jump_diagonal_world_clamp`, `test_t18_air_jump` |
| S4-MT | Mantle climb speed grows with the ledge height: average 132 + 1.2 x H u/s (66 u ~211, 94 u ~249, 162 u ~328), one constant speed per mantle. The two-phase profile inside the climb is not modeled. Session 7: the top band is 162 u (was 160), because the truck cargo top (162.0 u) mantles from a ground press. That is a lower bound, since the true max is unmeasured. | `session4_findings.md` "Taller mantles", `session7_findings.md` "Mantle max height", rec_auto/mantle2 | `test_t25_mantle_bands` |
| G45 (K56) | `parry_move_mult` 0.5 -> 0 (root). Gravity is kept. | `test_fp1_g45_parry_root` |
| G46 | New `zip_exit_drag` 0.25 and `MoveState.zip_exit_drag_active`. The drag applies after the 2 s zero-drag window until landing, and is cleared on attach and knock-off. PROVISIONAL, research Q3. | `test_fp1_g46_zip_exit_drag` |
| Roster | `HeroMovementStats.DASH_BUCKET_ROSTER` and `dash_bucket_for()` hold 9 / 18 / 11 heroes from the wiki Stamina page. `specs/movement.md` bucket row corrected, and the window-length row too. | `test_fp1_dash_bucket_roster` |
| Dash slow | `dash_distance_scale_mode` 1 (scale speed) now cites ground_dash.md rule 6. The value is unchanged. | `test_fp1_dash_slow_scales_speed` |

Tests changed because research proves them wrong:

- **T06:** the window is 0.25 s, not 0.2 s (G06).
- **T10:** air drag is 0.2, not 0.1 (G08).

T07 passed unchanged in this pass. It holds crouch from tick 2, so under G20 the slide starts at k=1 rather than at dash end. The review fixes below changed it for G21.

Deferred (Rec, not research-settled):

- **G17:** dash-jump horizontal speed and the 19 m re-fit. Now provisional; see the review fixes.
- **G21:** 650 u/s dash slide (K15). Now provisional; see the review fixes.
- **`docs/design/movement_architecture.md`:** the parameter table still shows the old defaults.

## Fidelity pass 1 (provisional)

This pass makes interim structural changes for gaps that still need a recording (G01-G04, G09, G14, G26). Every number is a `MovementParams` field marked `PROVISIONAL (Gxx)` with its evidence and the clip that will settle it. Ambiguous models get an enum switch, so a clip can pick the model without code changes. No new caps or clamps were invented beyond what the sources describe.

Suite: `71 passed, 0 failed (about 4.3 s)`. That is the 60 earlier tests plus 11 new ones in `tests/cases/test_fidelity_pass1_provisional.gd`. No existing test changed.

| Gap | Provisional change and value | Params | Evidence | Settling clip | Test |
|---|---|---|---|---|---|
| G01 | The air dash adds up to the cap along the dash direction (Hyp A): v_par = max(v_par, min(v_par + J, C)); v_perp is kept, and vy is zeroed as before. C defaults to the bucket's dash speed (B1 732 u/s); an override of 17.78 gives the flat 700 u/s model. Mode 0 is the legacy uncapped add; mode 2 sets v_par = C. | `air_dash_cap_mode` 1, `air_dash_cap_override` -1 | V8 dash-jump plus air dash worked example; gap table cap of 700 u/s | A1-A3 | `test_fpp_g01_g02_dash_jump_air_dash_601`, `test_fpp_g01_g02_alt_model_560`, `test_fpp_g01_perpendicular_kept` |
| G02 | When an air dash ends airborne, a one-time drag hits horizontal speed. Mode 1 (formula a, default): v' = max(min(v, 480 u/s), v - 0.2(v - 80 u/s)), giving about 601.98 u/s after a B1 dash-jump plus air dash. Mode 2 (formula b): 20% of the speed above 480 u/s. Mode 3: flat x0.8 (560 u/s with the 700 cap). Skipped in the zip exit window (ZMC), on landing mid-dash (IAD) and when chained into another air dash. `air_dash_exit_clamp` is deprecated; `validate()` warns if both are active. | `air_dash_end_drag_mode` 1, `air_dash_end_drag_frac` 0.2, `air_dash_end_drag_offset` 2.032, `air_dash_end_drag_floor` 12.192 | V8 end drag formula and worked example; ZMC and IAD guides | A2 | `test_fpp_g02_end_drag_formulas`, `test_fpp_g02_zip_and_iad_skip`, `test_fpp_g02_chain_cancels_drag`, plus the two G01 worked-example tests |
| G03 | The wall jump keeps the tangential velocity (x `wall_jump_tangent_keep`). The normal axis is set to the kick (mode 0) or gets the kick added (mode 1). The vertical axis is set as before. | `wall_jump_tangent_keep` 1.0, `wall_jump_normal_mode` 0 | Wall-jump guides: speed along the wall is kept | W1 | `test_fpp_g03_wall_jump_keeps_tangent` |
| G04 | A slanted, upward-tilted contact (ledge-top edge; `find_walls(include_slanted)`) is a corner boost: the kick goes along the tilted contact normal, with the vertical part x `corner_boost_mult`. The approach speed is no longer redirected. Mode 0 keeps the legacy convex redirect (K24). | `corner_boost_mode` 1, `corner_boost_mult` 0.8 (now vertical part only) | Corner boost guides and the 2025-10-02 nerf note; K24 contradicted | W3 | `test_fpp_g04_corner_boost_tilted` |
| G14 | Edge boost: a wall jump stays possible for 2 ticks after the last flat-wall contact, using the remembered normal. Corner boosts never use the memory. The memory is cleared on landing and on a wall jump. | `wall_jump_coyote_time` 0.03125 | V13, V6 and V7 edge-boost segments | W4 | `test_fpp_g14_wall_jump_coyote` |
| G09 | Slide drag: the first slide jump sets a flag, without penalty. A later flagged slide jump after less than 0.5 s of sliding adds `slide_hop_penalty_drag` to the air drag until landing (or for `slide_hop_penalty_time` when that is 0 or more). The flag clears after 0.25 s on the ground without sliding, and after a downhill slide jump. Superglide (mantle glide) and the zip exit window are exempt. The drag size and the clear time are placeholders. | `slide_hop_enabled` true, `slide_hop_min_time` 0.5, `slide_hop_penalty_drag` 1.34, `slide_hop_penalty_time` 0.3125 (session 7 SHH6/12/20/30: plateau x0.652-0.661 at any hop delay 6-30 ticks, none at 40 or after a dash-jump first jump; box fit of a decaying drag), `slide_hop_clear_time` 0.25 | Slide-hop guides (0.5 s rule, first-jump exemption, downhill exemption) | S2 | `test_fpp_g09_slide_hop_penalty` |
| G26 | Air wishspeed cap 80 u/s, 50 u/s above 700 u/s. It was 30 u/s. | `air_wishspeed_cap` 0.762 -> 2.032, `air_wishspeed_cap_fast` 1.27, `air_fast_threshold` 17.78 | V8 air strafe numbers | A5 | `test_fpp_g26_air_wishspeed_caps` |

New events:

- `AIR_DASH_END_DRAG` {from, to}.
- `SLIDE_DRAG` {slide_ticks}.
- `WALL_JUMP` gains `corner` and `coyote`.

Notes:

- **G48:** the only coverage for a zip dash is that the end drag is skipped in the zip exit window. The sim has no zip dash.
- **G15:** skipped. The evidence has low confidence and contradicts itself.
- **Step 3:** every value above is to be refit from the named clips A1-A5, W1, W3, W4 and S2 in the recording session. When a clip settles a model, pick the enum mode, then remove the others.

## Fidelity pass 1 review fixes

These fixes come from the review of both fidelity passes. They follow the same rule: match the official behavior, and never invent a cap, clamp or limit. Every new number is marked `PROVISIONAL (Gxx)` in `movement_params.gd` and at its use.

Suite: `76 passed, 0 failed (about 4.5 s)`. That is the 71 earlier tests plus 5 new ones in `tests/cases/test_fidelity_pass1_provisional.gd`. The fit self-test gives `14 passed, 0 failed`.

| Gap / K | Change | Evidence | Test |
|---|---|---|---|
| G02 IAD | An air dash that lands keeps its end drag pending until the dash's scheduled end (`MoveState.air_dash_drag_land_ticks`, handled by `MovementSim._iad_end_drag`). Leaving the ground before then (a bhop, a drop) applies the drag on that tick. At the scheduled end, only a SLIDE on level ground (`air_dash_iad_level_normal_y` 0.9999) skips it; anything else gets the drag. A new air dash or ground dash replaces it (the ground-dash case is by analogy and PROVISIONAL). Before this fix, any landing skipped the drag. | V2 0:11 / 0:33 / 3:03, V9 1:41 / 1:58 | `test_fpp_g02_zip_and_iad_skip` (slide on flat stays exempt), `test_fpp_g02_iad_no_crouch_drags_at_end`, `test_fpp_g02_iad_bhop_drags` |
| G06 | `dash_jump_window_open` stays at 0.30 s (official notes, 2026-06-30). Marked PROVISIONAL because V17 gives 0.35 s. | official notes; V17 conflict | `test_t06_dash_jump_window`, `test_fpp_g06_airborne_jump_after_window_not_dash_jump` (new: after dashing off a ledge, a press at k=39 is not a dash-jump) |
| G17 (K13) | New `dash_jump_speed_mode` 1 (default) sets horizontal speed to `dash_jump_set_speed` 15.5194 m/s (611 u/s) along the dash direction. Mode 0 keeps the legacy multiplier. | V9 0:19; PROVISIONAL, pending D3 | `test_fp1_g18_coyote_dash_jump` (updated); the fit self-test now fits `dash_jump_set_speed` |
| G21 (K15) | New `dash_slide_speed` 16.51 m/s (650 u/s) in every bucket, set on both dash-slide entries (`DashState.enter_dash_slide`). A value below 0 keeps the dash speed. The dead slide before 0.3 s is not modelled yet. | V5 0:17, Leif; PROVISIONAL, pending D2 | `test_t07_dash_slide_buckets`, `test_fp1_g20_dash_slide_on_press` (both updated) |
| G33 | New `wall_jump_min_interval` 0.125 s: a jump press next to a wall within the interval after a wall jump is eaten (no stamina, no air jump). Fatigue stays vertical-only (confirmed session 4, see S4-WF). | V7 14:14, V18 1:21; official 2025-05-08 notes (fatigue is vertical only); pending W5 | `test_fpp_g33_double_press_one_wall_jump`; `test_t26_wall_jump` sets the interval to 0 to keep testing cost and fatigue |
| G14 / G50 | Wall contact memory is tracked in AIR, AIR_DASH and DOWN_DASH, and is not re-armed on the wall-jump tick. It is cleared on landing, as is `last_wall_jump_tick`. A jump press during an air dash is still dropped. That is unsourced and is logged as new gap G50. | V13, V6, V7; G50 pending a recording | `test_fpp_g50_air_dash_along_wall` |
| G26 | `air_accel_high_speed_mult` 0.5 -> 1.0: no source gives a high-speed factor (K26). `air_accel` is marked PROVISIONAL. The 450 u/s strafe threshold stays (wiki E8). | air_movement.md rule 27, wiki E8 | `test_fpp_g26_air_wishspeed_caps` |
| G04 | `corner_boost_mult` marked PROVISIONAL. | 2025-10-02 nerf note | `test_fpp_g04_corner_boost_tilted` |
| G09 | Every slide jump sets the slide-hop flag, dash slides included. air_movement.md rule 39 (wiki) predates the 2026-03-06 slide-jump change, and Leif 2026-05 says it is "set on any slide jump". A dash-jump does not set it. | slide_and_slopes.md lines 64, 235, 254, 297 | `test_fpp_g09_slide_hop_penalty` |
| K12, K14, K17 | Removed invented clamps: the dash-cancel jump clamp, the clamp before the buffered jump at ground dash end, and the crouch-speed clamp on a crouch-stored dash exit. The crouch-stored exit still blocks the slide until crouch is released. | V9 3:03, ground_dash.md rule 12b, G22 | existing dash tests |
| Wall jump guard | A contact normal with no horizontal part is not a wall jump. | review | existing wall tests |
| Params | `validate()` checks the new and the fitted fields (ranges, `air_wishspeed_cap_fast` <= `air_wishspeed_cap`, the IAD normal in (0, 1]). | review | `test_contract` |
| Fitting | `fit_core` reports `validate()` warnings for the best candidate. It writes indexed params back as a whole array (packed arrays included) and rejects int params. It computes the initial RMSE for every channel, and maps y-up data to z-up with a rotation instead of a reflection. | review | fit self-test |

Findings skipped with reasons:

- **Horizontal wall-jump fatigue:** fatigue is vertical-only per the official 2025-05-08 notes (walls_and_ledges.md rule 13). V7 14:14's "no height, no distance" is covered by the G33 min interval.
- **Excluding dash slides from the slide-hop flag:** the rule 39 source is stale (see G09 above).

## Known deviations

These are decisions made where the spec is silent or where the design was adjusted. Details are in each part's notes.

- **Sprint:** follows §3. These resets set the timer to 0:
  - damage (default `resets_sprint: true`; payload `false` opts out)
  - a combat interaction
  - being in CROUCH (a crouch press that starts a slide keeps sprint)
  - holding opposing keys (the `BTN_OPPOSE_X/Y` bits set by `InputSampler`)
  - stopping: no move input and horizontal speed below `sprint_stop_speed` (0.254 m/s, a guess)

  Turning or backpedalling does not reset sprint. The §3 reset and the §5 hero-damage slow both apply, so damage while sprinting drops to base speed.
- **Modifiers:** `enduring_speed` is split into a move-bonus def and a slow-resist def (one stat per ModifierDef). Fleetfoot and Extra Stamina likewise have companion defs (`fleetfoot_no_fire_penalty`, `extra_stamina_recovery`). Melee self-slows are `Stat.SLOW`, so they are resisted and floored per §5. The parry 0.5 `MOVE_MULT` is an unspecified placeholder, kept until measured.
- **Slide:** on slopes, velocity stays horizontal and a downhill accel g*tan(theta) is added before friction (session 7). The slide low-speed exit and the dash end are checked in the next tick's transitions.
- **Corner boost:** mode 1 (default, G04) kicks along the tilted contact normal, with the vertical part x `corner_boost_mult` 0.8 (PROVISIONAL). Legacy mode 0 is `n * (h_speed + kick) * 0.8` (K24, contradicted).
- **Wall fatigue (measured session 4):** each wall jump sets fatigue to 1. It recovers linearly over 1.95 s and scales only the 519 u/s base up speed, not the fall-speed term or the kick. Airborne melee fatigue (0.25) is still provisional.
- **Wall-jump regen penalty:** "in combat" means a damage or combat-interaction op happened within `in_combat_time` (3 s, a guess).
- **Parry:** a failed parry has no automatic cooldown.
- **Heavy melee:** its cooldown always uses the miss value (1.3 s), because hits are not simulated. The heavy-hero turn cap scales yaw change per tick.
- **Stamina:** stored as whole bars plus a separate regen progress, so a spend never uses a partial bar.
- **Air dash:**
  - Zeroing vy at the start follows design §7.10. The spec (§11) says only that the dash adds an impulse, so this is switchable with `air_dash_zero_vertical` (default true).
  - Velocity is kept at the end, apart from the G02 end drag (after an IAD, deferred to the dash's scheduled end). The optional `air_dash_exit_clamp` (default off, deprecated) clamps it to move speed.
  - Landing ends the dash.
  - A ground dash off a ledge applies gravity.
- **Crouch storage:** a ground dash started with crouch held keeps its speed at the exit (the crouch-speed clamp, K17, was removed). CROUCH->SLIDE is then blocked until crouch is released (on any surface, including slide slopes).
- **Air crouch:** does not shrink the capsule.
- **Timers:** stored as ticks+1, so an N-tick duration lasts exactly N ticks under the design §7.9 order. The overlay shows `(ticks_left - 1)/64` s.
- **Zipline:**
  - The `Zipline.lane` enum (INNER/OUTER) resolves speed from `zip_speed_inner`/`zip_speed_outer`. CUSTOM keeps `lane_speed`.
  - Express lines use `1 + zip_express_mult` (0.8).
  - The boost has a 360 s cooldown and unlocks at 360 s of sim time (`state.tick`, a stand-in for match time).
  - While riding, the capsule is swept to each rail target. The hang offset is clamped above geometry, and a head-on block detaches with reason `blocked`.
- **Mantle height:** measured from the floor under the player while airborne (integration fix 3).
- **Mantle reach:** `mantle_reach` stays 0.6 m. The spec's 212 u (5.38 m) "activation distance" is low confidence and unresolved (design §8.1).
- **Stairs:** the step-up accepts tread-edge contacts (integration fix 2). As a result, the capsule's rounded bottom makes climbing a smooth ramp rather than discrete Source-style steps.
- **Input:** presses are latched from `_input` events so sub-frame taps reach the sim. A light melee registers on Q release.
- **Recorder:** `stamina_regen_time` is measured per bar, not from 0 bars.

## Uncertain values

Values marked L in the design's parameter table are guesses. They need in-game measurement (use the R1–R4 recorder recipes and `specs/movement.md` measurement protocol) before they are trusted:

- **Ground feel:** `ground_friction` 4.0 and `stop_speed` 2.54 m/s are measured. The accel step is a constant `ground_accel` × `ground_accel_ref_speed` = 1600 u/s² for every hero (measured session 5, was 4 × wishspeed). Wishspeeds above 400 u/s and crouch-walk accel are unmeasured.
- **Jump:**
  - `gravity` 24.562 m/s² is inferred from 295 u/s and 45 u.
  - `air_jump_speed` (Open Q4) is a guess. `dash_jump_vertical_speed` is 425 u/s (G05); `dash_jump_set_speed` 611 u/s is provisional (G17).
  - T04 checks self-consistency with these values, not ground truth.
- **Air control:** `air_accel` 10 (PROVISIONAL, G26), `air_wishspeed_cap` 2.032 m/s and 1.27 m/s above 700 u/s (PROVISIONAL, G26). `air_drag` 0.2 (measured session 5); the air dash has its own `air_dash_drag` 0.2.
- **Slide landing (session 6):** a landing into a normal slide below `landing_slide_friction_speed` (466 u/s; measured session 7 LT440-465, bracketed 461-471) takes one ground-friction tick (x0.9375). Slide-jump takeoff cuts re-verified with drag: dash slide x0.75, normal slide x1.0.
- **Air dash ramp (mode 3):** refit session 5. The ramp damps on the speed gained since the dash start (`air_dash_ramp_rate` 49, `air_dash_ramp_damping_c` 0.85), and the peak target is fracs 0.759/0.776/0.789 plus 0.26 × entry speed (0.35 × when the entry is against the dash; session 6, entries -641..+673 for Haze). End drag (mode 4, session 6): over 7 ticks it removes 75% of the excess over 480 u/s but at most 17.5% of the speed, so fast dashes settle at ~81% (E700W 670 -> 542) instead of the flat 480.
- **Dash:** `down_dash_speed` 15 m/s (Open Q7) and the exit clamp (Open Q6). The down dash cost is settled at 0.5 (G28), and the scaling mode is settled as speed (ground_dash.md rule 6).
- **Wall jump:** speeds, kicks and fatigue amounts (Open Q12). The 0.125 s min interval is provisional (G33). Fatigue is measured (S4-WF).
- **Mantle:** `mantle_reach` 0.6 m (the 212 u "activation distance" is unresolved); `mantle_glide_speed` is 13.97 m/s (G11).
- **Rails:** `zip_attach_radius` 1.0 m (Open Q14), rope climb speed 4 m/s and attach radius.
- **Melee:** the heavy lunge profile (constant 750/797 u/s for up to 0.6 s) is provisional pending H1 (G10). Turn rate and melee self-slows are still Open Q15.
- **Capsule and collision:** capsule and eye dimensions, `step_height` 18 u, probe distance, collision margin. These are Source conventions, not Deadlock measurements.
- **Buffers:** coyote time and jump buffer (0, Open Q20), action buffer 0.1 s. With a non-zero buffer, a press in the air counts as a buffered ground jump, not an air jump, when the fall within the buffer window reaches walkable ground.
- **Sprint and combat:** `sprint_stop_speed` 0.254 m/s, `in_combat_time` 3 s, `zip_express_mult` 0.8.

## Remaining issues

- Mouse look, Q tap/hold melee, the crosshair and the overlay have only been checked headless. They have not been play-tested with real input on screen.
- Resting feet can sit about 0.1 mm above the floor after a ground snap: the probe's travel still includes recovery when it hits. This is harmless, and the tests allow for it.
- Climbing stairs is a smooth ramp-like rise, not discrete Source-style steps. Visual and camera step smoothing may be wanted.
- CameraRig does not yet reset its boom on teleport. `PlayerCharacter.snapped_this_tick` is exposed for it (CAMERA part).
- Remaining hot-path allocations:
  - a CameraRig shape query and exclude array every frame
  - a `Ctx` per tick
  - `pending_ops.duplicate()` per tick

  The mover's sweep, ray and shape queries are now cached.
- ArenaBuilder still passes lane speed constants to `add_zipline` (ARENA part). Set `Zipline.lane` there to use the params.
- The recorder's air-dash recipe measures distance during the dash, not to landing (DEBUG part).
- Rope climbing still sets the position without a collision sweep.
- `InputSampler.build_cmd` (CAMERA part) was edited minimally to set the opposing-key bits.
- On exit, Jolt may print RID leak warnings if a scratch script does not call `SimHarness.free_all()` / `MovementSim.dispose()`. Project code and the test runner are clean.
