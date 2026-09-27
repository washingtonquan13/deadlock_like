# Movement recording shot list (private lobby)

Revised 2026-09-27, after fidelity pass 1 and the video-guide research (`video_guides.md`, sources V1-V18).

Purpose: settle the numeric and formula gaps in `docs/design/movement_fidelity_gaps.md` (IDs G..) with the fewest clips possible. Most gaps now have a provisional model in code with an enum switch or a named parameter. Each clip below says which scenario in `tools/movement_capture/scenarios/` will consume it, which parameters it fits, which `fixed` modes to compare, and the expert numbers (V-refs) it must reproduce.

Protocol: `specs/_measurement_protocol.md` applies in full.
- Private lobby or sandbox only.
- Record the build number and patch date.
- At least 3 trials per measurement, unless a clip says otherwise.
- Use frame counting for time.
- Put the results in `data/measurements/*.csv` from `template.csv`, with `source_type = community-measurement`.

Clean-room rule: observe the game only through its own console and HUD, plus screen capture. Do not read game files, memory or traffic.

Pipeline for every clip (`tools/movement_capture/README.md`): record, then `extract.py calibrate` (once per resolution and HUD setup), then `extract.py extract` to a CSV, then `res://tools_fit/fit_runner.gd --scenario=... --measured=...`. "(to write)" means the scenario file does not exist yet. Copy the named template, then set the timeline, `start` and `align` from the first trial. A scenario can pin enum modes with `"fixed": {...}`. Model selection means fitting the same trials once per mode and comparing the RMSE in `report.md`. Integer params cannot be fitted directly.

## Setup (once, about 5 min)

Verification levels are copied from `_measurement_protocol.md`. Where a command is **unverified** or **low**, the clip also lists a fallback that does not need it.

| Step | Command / action | Verified? |
|---|---|---|
| Create lobby | Play menu, then custom or private lobby (UI). `private_lobby_create` is a fallback. | UI: high. Command: **unverified** |
| Map | `map dl_midtown` | medium |
| Cheats | `sv_cheats true` | medium |
| Hero | `dump_hero_names`, then `selecthero <name>` | medium |
| Stamina | `citadel_enable_fast_stamina` (turn it **off** for any stamina-cost clip) | medium |
| Overlay | `cl_showpos 1`, which shows position, velocity and angles. This is the only read-out the extractor uses. | medium |
| Invulnerable | `citadel_enable_no_hero_death` | medium |
| Items | `citadel_hero_testing_enabled 1`, `citadel_hero_testing_infinite_money 1` (or `kingme`), `citadel_allow_purchasing_anywhere 1`. Session 1 uses no items. | medium |
| Speed scale | `citadel_player_move_speed_scale` must stay at 1 | medium |
| Clean view | `citadel_hud_visible 0`. Check that the `cl_showpos` text still shows. If it does not, keep the HUD on. | medium |
| Slow motion | `host_timescale`: **do not use while recording**. The fitter needs real-time video. Step through the recording frame by frame instead. | low-medium |
| Teleport reset | `getpos` / `setpos x y z`. Fallback: mark a start spot on the map and walk back. | **low** |
| Wall debug | `citadel_wall_detection_debug 1` (optional, W1 only) | **low** |
| Pause | `citadel_pause` | medium |
| FPS check | `cl_showfps`. Fallback: the OBS stats dock. | **unverified** |

OBS: 120 fps if possible (60 minimum), CBR at a high bitrate, a native-resolution canvas and a constant frame rate. Keep the overlay over dark, plain scenery for OCR. Name each file `<clip>_<hero>_t<n>.mp4`, for example `A2_haze_t1.mp4`.

How to read the overlay:
- `cl_showpos` velocity is in u/s. The extractor writes `speed_h` (horizontal |v|), `vel_z` and `ang_yaw` per frame. The fitter's `h_along` and `h_across` channels split horizontal velocity along and across the heading measured in `align.ref_window`.
- The `cl_showpos` layout is **assumed** in `layouts/showpos_default.json`. C0 checks it.

Heroes (bucket roster from the wiki Stamina page, see `ground_dash.md` Q10). Sim heroes: `hero_default_b1.tres`, `hero_heavy_b3.tres`.
- **B1: Haze.** Alternates: Calico, Ivy.
- **B3: Abrams.** Alternates: Kelvin, Bebop.
- B2 (Seven, Wraith, Infernus) is not needed in session 1.

Use B1 unless the clip says otherwise. Carry no items.

What changed from the previous list (evidence: `video_guides.md` section 3):
- **A1** now also decides the G02 end-drag formula. A dash from rest ends near the cap (B1 about 732 u/s), where formula (a) gives about 602, formula (b) about 682 and a flat x0.8 about 586 (V8 2:38, V9 1:09).
- **A2** is B1 only. V9 0:19 says the dash-jump speed is the same for every bucket, so the B3 repeat moved to D3, which measures it directly.
- **A3** is now an angle sweep (45°, 75°, 90°). Hypothesis A (the current mode 1) predicts the best angle is always 90°. V8 3:01 says about 72° at this speed. This clip is the acceptance test for G01.
- **W1** replaces the 900 u/s run with an angled approach. The normal axis can only show "set vs add" (G03 mode 0 vs 1) when the incoming velocity has a normal part.
- **D1** is the "dash curve": the per-frame ground-dash speed profile (G19). It is also the only clip for G22 and G23.
- **S2** starts from a dash-jump landing, not a dash slide. Since 2026-03-06, jumping out of a dash slide has its own air-drag penalty (V17), which would mix with the slide-hop penalty.
- **Removed: A4** (air-drag form). V15 0:22 and V6 14:09 support the current per-second, per-tick form. A2 and A3 now fit through to landing and give a first read of the G08 form. A4 comes back only if those residuals show a systematic shape.
- **Moved to session 2:** W3 (corner boost), because the fitter has no slanted-geometry type yet. D2, D4, W2, W4, W5, M1, S1, S3, H1 and Z1 also moved there, and A6, A7, A8, A9, D5, S4 and W6 are new clips there.

---

## Session 1: air dash, wall jump, dash-jump, dash curve, slide-hop (about 40 min, including setup)

Order: C0, A1, A2, A3, W1, D3, D1, S2. Clip time: about 36 min. Setup: about 5 min. If time runs short, cut the extra B3 reps in A1 and D3 first, then D1.

### C0: Overlay and unit calibration (3 min)
- **Goal:** check the `cl_showpos` text format, the ROI and the units before anything else.
- **Setup:** flat corridor, over dark scenery. Stand still 3 s, then walk forward (W only, no sprint) for 2 s, then stop.
- **Read:** the `pos` and `vel` lines as shown (screenshot one frame). Also the steady walk speed, and the position change against the time.
- **Reps:** 2.
- **Consumer:** `extract.py calibrate` (writes the ROI JSON), then `extract.py label-dump` and `train-templates` from these frames. Check `layouts/showpos_default.json` against the screenshot and fix `names` / `full_regex` if the format differs. No fit scenario.
- **Pass:** walk speed reads the hero's base speed (Haze about 283 u/s in our data), and position change / time equals the velocity readout within 1%. If not, stop and fix the layout or the units before recording anything else.

### A1: Air dash from rest, forward (5 min)
- **Goal:** the dash impulse and cap per bucket, the acceleration phase, vertical hold, and the end-drag formula.
- **Setup:** fast stamina OFF. Ground jump in place with no input. At the apex, tap dash while holding W only. Hold nothing afterwards until landing.
- **Read:** `speed_h` and `vel_z` every frame from the dash press to landing.
- **Reps:** 3 with B1 (Haze), plus 2 with B3 (Abrams).
- **Consumer:** `scenarios/air_dash_from_rest.json` (exists). Timeline: jump at tick 1 and dash at the apex tick, move `[0, 1]` only on the dash tick. Weights `speed_h` 1, `vel_v` 1, `pos_v` 4. Hero `hero_default_b1.tres`, or `hero_heavy_b3.tres` for the B3 trials.
  - Fit: `air_dash_distance` (G01 impulse, with J = distance / bucket duration), `air_dash_end_drag_frac`, and `air_dash_end_drag_floor` (optional) (G02).
  - Compare with `fixed`: `air_dash_end_drag_mode` 1 (formula a), 2 (formula b) and 3 (flat x0.8). Also compare `air_dash_zero_vertical` true and false (G25).
- **Check against:**
  - Peak `speed_h`: B1 about 732 u/s (V8 2:16). B3: ours is 617.6 u/s (0.51 s duration); V8's 642 is from before the B3 duration change.
  - Speed after the end drag: about 602 (a), 682 (b) or 586 (flat). This is the main G02 formula decision.
  - `vel_z` held at 0 during the dash (V9 0:48); G25 is how long it is held.
  - The acceleration takes about 0.13 s (V8 2:10), while our model steps at once. A systematic `speed_h` residual in the first 0.13 s is a model gap. Write it up under G01; do not tune it away.
- **Resolves:** G01 (impulse and per-bucket cap), G02 (formula), G25.

### A2: Dash-jump into a forward air dash (4 min), the "immense speed" clip
- **Goal:** confirm that a forward air dash above the cap gives no gain, and that only the end drag applies.
- **Setup:** ground dash W. Dash-jump inside the window. On the frame after takeoff, air dash with W only. Hold W until landing.
- **Read:** `speed_h` just before the air dash (the dash-jump speed), the peak, the first frame after the burst, and landing. Also `vel_z` throughout.
- **Reps:** 3 with B1.
- **Consumer:** `scenarios/air_dash_after_dash_jump.json` (exists).
  - Fit: `air_dash_distance` (G01), `dash_jump_vertical_speed` (G05 check), `dash_jump_set_speed` (G17) and `air_dash_end_drag_frac` (G02).
  - Compare with `fixed`: `air_dash_cap_mode` 1 vs 2, and `air_dash_end_drag_mode` 1 vs 2.
  - Extend `fit_window` to landing (about 1.7 s is already set). The post-drag tail is the first read of the G08 drag form.
- **Check against:** pre-dash about 611 u/s (V9 0:19 / 19 m). Peak about 732 u/s. After the drag, about 602 u/s under formula (a). A peak near 611 + 732 = 1343 would mean the dash is additive, which contradicts V1 0:31 and V8 2:16.
- **Resolves:** G01, G02 (with A1), G17 (with D3), G08 form (first read).

### A3: Dash-jump then an angled air dash, 45° / 75° / 90° (6 min)
- **Goal:** the air-dash formula. Is the perpendicular part kept (Hypothesis A), or does the dash rotate the velocity toward the dash direction?
- **Setup:** as A2, but air dash at an angle to the travel direction:
  - 45°: hold W+D at the dash, with no mouse movement.
  - 90°: hold D only at the dash.
  - 75°: flick the mouse about 30° right just before the dash, then hold W+D.
  - The extractor's `ang_yaw` gives the true angle from the recording, so small errors are fine; log them.
- **Read:** velocity components along and across the original travel direction before the dash, at the peak, and after the end drag, plus the heading change.
- **Reps:** 2 per angle (6 trials).
- **Consumer:** `scenarios/air_dash_angled.json` (exists; as written it is the 45° case). Put the angle in the timeline's `move` and `yaw_deg` on the dash tick. Set `ref_window` before the dash. Weights `h_along` 1, `h_across` 1, `vel_v` 1.
  - Fit: `air_dash_distance`, `air_dash_end_drag_frac`.
  - Compare with `fixed`: `air_dash_cap_mode` 1 (Hyp A) vs 2 (set). A fit that is poor under both modes means the rotate-toward-dash model (V3 4:39, V10 1:47) is needed. That is a code change under G01, not a new cap.
- **Check against:**
  - Pre-dash speed is about 611 u/s, which is 0.83 of the B1 cap. The best angle should be about 72°, between 60° at 0.5x and 75° at 1x cap (V8 3:01). Hypothesis A predicts 90° is best: about 953 u/s before the drag and about 778 after formula (a).
  - The pre-drag speeds (about 800-950 u/s) also give G02 data above the cap.
- **Resolves:** G01 formula (the mode decision), G02 at high speed.

### W1: Wall jump at speed, neutral input (6 min)
- **Goal:** tangential keep, normal set vs add, the vertical speed and the neutral kick. Also the post-jump decay, detect distance and wall stickiness.
- **Setup:** a long, flat vertical wall. Dash-jump so you travel along the wall.
  - (a) Parallel: about 1 m from the wall, drift in, then jump with **no input** on touching.
  - (b) Angled: approach at about 30° into the wall, then jump with no input on touching.
  - Hold no keys for 1 s afterwards.
- **Read:** the velocity components along and into the wall 1-2 frames before and after the jump. Also `vel_z` after, and `speed_h` over the next 0.8 s.
- **Reps:** 3 of (a) and 3 of (b), at dash-jump speed (about 611 u/s).
- **Consumer:**
  - (a) `scenarios/wall_jump_neutral.json` (exists). Set `start.vel_mps` from the video.
  - (b) `scenarios/wall_jump_neutral_angled.json` (exists; incoming normal component in `start.vel_mps`).
  - Fit: `wall_jump_up_speed` and `wall_jump_kick_neutral` (G32), and `wall_jump_tangent_keep` (G03).
  - Compare with `fixed`: `wall_jump_normal_mode` 0 (set) vs 1 (add) on the (b) trials.
- **Check against:**
  - The tangential part is kept ("stacks", V13 0:18; "carries momentum", V7 8:19). The velocity angles away from the wall (V18 Strafing 208 2:10).
  - After the jump, the decay should follow the plain air drag of 0.2. Faster decay supports G15 "significant drag". A slower decay with strafe held matches V13 1:18's lateral bonus (not tested here: keys are neutral).
  - (b) at a shallow angle: any sudden loss of speed on contact is K49 (the backtrack kill). Note the frame.
  - Optional side read with `citadel_wall_detection_debug 1`: the distance at which the wall jump becomes available (G34).
- **Resolves:** G03, G32 (neutral kick and up speed), G15 (whether drag is extra), K49, G34 (side note).

### D3: Dash-jump distance, B1 vs B3 (4 min)
- **Goal:** the dash-jump's horizontal and vertical speed, and whether they are global.
- **Setup:** flat open ground. Dash W, then dash-jump in the middle of the window. Hold nothing else until landing.
- **Read:** `vel_z` and `speed_h` on the takeoff frame, the ground distance from takeoff to landing (`pos` difference), and the airtime in frames.
- **Reps:** 3 with B1, plus 2 with B3.
- **Consumer:** `scenarios/dash_jump_flat.json` (exists). Weights `speed_h` 1, `vel_v` 1, `pos_h` 1, `pos_v` 4.
  - Fit: `dash_jump_set_speed` (G17), `dash_jump_vertical_speed` (G05 check), and `gravity` (optional cross-check).
  - `fixed`: `dash_jump_speed_mode` 1.
  - Run the B1 and B3 trials separately and compare `dash_jump_set_speed`.
- **Check against:** vertical 425 u/s and a distance of about 19 m (2026-06-30 notes, V17). The same horizontal speed for B1 and B3 (V9 0:19).
- **Optional (+2 min, if ahead of time):** 3 trials with a single jump press as early as you dare. Log the frames from dash start to takeoff for each success (`vel_z` about 425). The earliest success brackets `dash_jump_window_open`: 0.30 s (official) vs 0.35 s (V17) (G06).
- **Resolves:** G17, G05 (check), G06 (optional).

### D1: Ground dash speed profile, the "dash curve" (3 min)
- **Goal:** the shape of the ground-dash speed over time, and the tail speed.
- **Setup:** flat ground, standing still. Dash W with no jump or crouch. Hold nothing for 1 s after the dash.
- **Read:** `speed_h` on every frame from dash start to 0.9 s, and the frame where speed reaches walk speed.
- **Reps:** 3 with B1, plus 1 with **no input held** (a neutral dash), noting facing vs. travel heading.
- **Consumer:** `scenarios/ground_dash_profile.json` (exists). Weights `speed_h` 1, `pos_h` 1.
  - Fit: `ground_dash_durations[0]` and `ground_dash_distance`.
  - The code has no curve parameter yet: the constant-speed model is the null hypothesis. Keep `residuals.csv` from the best fit, because the measured `speed_h` trace **is** the sampled curve that G19's `ground_dash_profile` would use.
- **Check against:**
  - A flat-then-drop profile means the current model is right.
  - An eased shape is evidence for G19. The tail at 0.55-0.62 s shows whether the dash hop keeps speed above walk speed (V9 3:03, G22).
  - Neutral: the travel heading equals facing, or not (G23).
- **Resolves:** G19, G22 (confirms the clamp removal), G23.

### S2: Slide-hop penalty (5 min)
- **Goal:** the size of the slide-drag penalty, and the 0.5 s rule.
- **Setup:** dash-jump forward (a dash-jump does not set the flag), and hold crouch before landing (an air-entry slide at about 600 u/s).
  - (a) Jump out at about 0.3 s. This first slide jump is free but sets the flag (V4 0:47). Land crouched, slide, and jump again at about 0.3 s. This jump is flagged and early, so it should be penalized. Land and slide once more, then let the slide finish.
  - (b) The same, but jump out of the second slide at about 0.6 s. This is within the 0.5-0.75 s window, so no penalty is expected (V4 1:01).
- **Read:** `speed_h` just before each jump, through the air, and just after each landing. Also the slide durations (frames from landing to jump).
- **Reps:** 3 chains of (a) and 3 of (b).
- **Consumer:** `scenarios/slide_hop_chain.json` (exists; as written it is variant (a)). The timeline is: dash, dash-jump, crouch held, then jump and crouch ticks copied from each trial.
  - Fit: `slide_hop_penalty_drag`, and `slide_hop_penalty_time` (optional; < 0 means until landing).
  - `fixed`: `slide_hop_min_time` 0.5. Fit (b) first: it must fit with **no** penalty. If it does not, the 0.5 s rule or the flag model is wrong, so stop and write it up.
  - The slide segments also constrain `slide_friction` (a check on 0.1875) before the 0.75 s air-entry window.
- **Check against:** the penalty is an air-drag-type loss that lasts through the airtime (V4 0:34, V15 1:14). "Too early is much worse than too late" (V7 7:05).
- **Resolves:** G09 (penalty size and duration), and a G43 check (slide friction value) as a side read.

**Session 1 total:** setup 5 min + clips about 36 min.

---

## Session 2: second priority (about 45-60 min, can be split)

Every row names its consumer scenario. All are "to write" unless marked "exists". Template: `air_dash_after_dash_jump.json` for flat clips, `wall_jump_neutral.json` for wall clips.

| Clip | Goal | Setup and input | Consumer: scenario, fitted params, `fixed` modes | Check against (V-refs) | Resolves |
|---|---|---|---|---|---|
| A5 | Air strafe | (a) From about 300 u/s: a 180° mouse turn holding A or D. (b) The same from about 800 u/s (dash-jump plus an angled dash). | `air_strafe.json`: `air_accel`, `air_wishspeed_cap`, `air_wishspeed_cap_fast`, `air_fast_threshold` (optional). Weights `h_along`, `h_across`. | Cap 80 u/s, 50 above 700 (V8 0:28, V3 2:45). The lockout cone is about 80° at about 460 u/s. The keyboard-turn optimum is 480-500 u/s (V8 1:40). | G26 |
| A6 | Air jump | Jump, then at the apex: (a) a double jump with no input, (b) one holding W, (c) one while falling fast after a long drop | `air_jump.json`: `air_jump_speed`. Compare `air_jump_sets_vertical` true vs false. `air_jump_horizontal_boost` needs code first. | A double jump adds some horizontal speed from held keys (V3 5:20). | G27 |
| A7 | Down dash | Jump, then double-tap crouch at the apex. Fast stamina OFF; watch the stamina bar. With Stamina Mastery, try two down dashes in one airtime. | `down_dash.json`: `down_dash_speed` | Cost 0.5 (already settled, G28: check only) | G29, G30 |
| A8 | Air-dash drag exceptions (needs Stamina Mastery) | (a) A dash-jump, an air dash, then a second air dash right after the first ends. (b) An air dash, a wall jump during the pending drag, then land. | `air_dash_chain.json`: `air_dash_end_drag_frac`. `fixed`: the A1-A3 winning modes. | A second air dash cancels the drag (V2 3:03). A wall jump does not (V10 3:18). The SM cap is +23% (V8 2:16, scaled). | G02 exceptions |
| A9 | Jump press during an air dash | An air dash along a wall, pressing jump mid-dash (then along a mantle-height ledge) | `air_dash_jump_press.json`: no fit, event check only | V3 4:39 only says velocity is locked | G50 |
| D2 | Dash slide speed and dead slide | Dash W, then crouch at about 0.1, 0.3, 0.4 s and at dash end. Use B1 and B3. | `dash_slide.json`: `dash_slide_speed` | 650 u/s in every bucket (V5 0:17). A crouch before the window opens gives a dead slide ending near 270 (V5 1:21). A late crouch starts below 500. | G21 |
| D4 | Coyote dash-jump | Dash off a ledge. Press jump 1, 3 and 6 frames after leaving the edge. | `dash_jump_coyote.json`: `dash_jump_coyote_time` | vy about 425, and whether a later air jump still works | G18 |
| D5 | Dash-jump window and early lockout | Single jump presses at spaced times, 0.25-0.60 s after the dash, then an early press followed by a press in the window | `dash_jump_window.json`: no fit; tick check against `dash_jump_window_open` | 0.30 s (official) vs 0.35 s (V17); window length 0.25 s | G06, G07 |
| W2 | Wall jump input shaping | Standing still next to a wall, jump holding toward, neutral, away and along the wall | `wall_jump_input.json`: `wall_jump_kick_toward`, `wall_jump_kick_away`, `wall_jump_up_speed` | Toward is steep, away is long and flat. Input never pushes parallel to the wall (V13 0:04, V7 8:03). | G16, G32 |
| W3 | Corner boost | Surf a slanted ledge top and jump in contact, then the same approach on the flat face | `corner_boost.json`: `corner_boost_mult`. `fixed` `corner_boost_mode` 1. **Needs a slanted `geometry` type in `fit_core.gd` first.** | No coyote (V11 0:26). Graded strength (V11 2:18). The nerf cut only vertical (V14 1:08). | G04 |
| W4 | Edge boost | Run or dash along a wall toward its outer edge; jump late as you pass the edge. Include a walk-off edge. | `edge_boost.json`: `wall_jump_coyote_time` | "A few ticks" after contact loss (V13 0:26). Tighter at high speed (V12 1:41). | G14 |
| W5 | Wall fatigue and lockout | In a chimney: four wall jumps as fast as possible, then pairs about 0.6 s and 1.3 s apart; the same wall twice | `wall_fatigue.json`: `wall_jump_fatigue_per_jump`, `wall_jump_fatigue_recovery`, `wall_jump_min_interval` | No cap on the count. A too-soon jump gives no height or distance (V7 14:14). Extra presses are eaten (V18 Stairs 1:21). | G33, G35 |
| W6 | Wall slide and wall strafe | (a) Fall pressed against a wall from a height. (b) Strafe and strafe-dash into a wall at about 55° from its parallel. | `wall_slide.json`: `wall_slide_max_fall`. (b) has no parameter yet; residual only. | "Much lower" fall cap (V10 1:11). The wall boost angle is about 55° from a run (V10 2:30). | G36, G49 |
| M1 | Mantle | Sprint into a 64-96 u ledge with jump + W and crouch held. Repeat as a superglide. | `mantle_glide.json`: `mantle_reach`. Check `mantle_glide_speed` (settled, G11). | A mantle slide redirects within ±90° (V6 20:26). A superglide does not set the slide-hop flag. | G37, G39 check |
| S1 | Slide decay windows | Plain slides at about 450 u/s: from the ground, from an air landing, and from a dash. Crouch held. | `slide_decay.json`: `slide_friction`, `slide_penalty_friction`, `slide_onset_table[0]` | Windows of 0.6 s (ground), 0.75 s (air) and 1.0 s (dash). A slope resets the window to 0.6 s (V15 0:27). | G43 |
| S3 | Slide steering | A slide, then a slow 90° mouse turn holding W | `slide_steer.json`: needs `slide_turn_rate` code first; residual only | Inputs never change slide speed (V15 0:05) | G41 |
| S4 | Slide-hop flag clearing | (a) A flagged chain, then stand still 0.1 / 0.3 / 0.6 s, then slide and jump early. (b) A scroll short hop into a short slide. (c) A downhill slide jump. | `slide_hop_chain.json` variants: `slide_hop_clear_time` | Scroll short hop and superglide do not set the flag (V5 1:49, V15). A downhill jump clears it (V4 2:13). | G09 clear rules |
| H1 | Heavy melee lunge | Standing and airborne heavy melee into empty space (B1). Add one B3 trial. | `heavy_melee.json`: `heavy_lunge_speed_ground`, `heavy_lunge_speed_air`, `heavy_lunge_time` | 750/797 u/s; recovery zeroes all velocity. The distance conflicts with research Q5. | G10 |
| Z1 | Zip exit and cake jump | Ride a zipline, then (a) crouch off and record 3 s, (b) jump within about 0.1 s of attaching, (c) jump after 1 s | `zip_exit.json`: `zip_exit_drag`; (b) and (c) are event checks | 2 s of zero drag, then 0.25. Drop speed 250-590 u/s (V8 3:47). | G46, G47 |

---

## After recording

1. Fill the CSV rows (one row per trial). For each quantity, name the clip ID in `quantity`, for example `A2_peak_speed`.
2. For each fitted parameter, follow `tools/movement_capture/README.md` section 7:
   - All trials must agree within a few percent.
   - A result that is AT BOUND or FLAT is not a finding.
   - A systematic residual is a model gap to write up, never a reason to add a cap or clamp.
3. Apply a value by hand to the `.tres` with a comment such as `# PROVISIONAL (G01): fitted from A1_haze_t1..t3, spread 1.8 %`. When a clip settles a model, pick the enum mode and remove the others.
4. In `movement_fidelity_gaps.md`, update the gap's **Status** (to fixed-settled, with the fitted value, spread and clip), and change *Settle* to "measured".
5. Clips whose result contradicts the research go back into the matching `specs/movement_behavior/*.md` file under "Conflicts", with the video reference. For example: A3 fits neither cap mode, or S2 (b) shows a penalty.
