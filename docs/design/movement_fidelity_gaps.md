# Movement fidelity gaps (code vs verified behavior)

Status: analysis dated 2026-09-27. Gap statuses were updated on 2026-09-27, after fidelity pass 1, its review fixes and the video-guide research (`specs/movement_behavior/video_guides.md`); see section 0. Latest patch covered: 2026-09-16.
Research basis: `specs/movement_behavior/*.md`. Those files cite public sources only, and this is clean-room work, so no game files were read.
Units: 1 u = 0.0254 m and 1 m/s = 39.37 u/s. The tick rate is 64 Hz. B1/B2/B3 are the dash buckets. "Walk speed" means the effective move speed.

Legend
- **Severity** is feel impact. *Critical* means a skilled player notices within seconds, or it changes route and tech viability. *Major* means it is noticeable in normal play or changes a tech's payoff. *Minor* covers edge cases, numbers that are close, and things only noticed side by side.
- **Confidence** is the research confidence in the real behavior: H (high), M (medium) or L (low). It uses the same letters as the behavior specs.
- **Settle by**: *R* means research alone justifies a change now. *Rec* means the number or formula needs a private-lobby recording (see `specs/movement_behavior/recording_shot_list.md`, clip IDs in brackets). *R+Rec* means the direction is settled, so an interim change is safe, but the constant needs recording.
- The line numbers are for the files as of this date.

---

## 0. Gap status (2026-09-27)

Status key:
- **fixed-settled**: the code matches the research. It is either research-settled with no PROVISIONAL mark, or a supported row that needed no change. A recording only re-checks it.
- **provisional**: an interim model is in code. Every uncertain number is marked `PROVISIONAL (Gxx)` in `movement_params.gd` and at its use. A recording must fit or select it.
- **open**: no change was made (or no model exists yet), because the real behavior or its numbers are unknown.

Counts: **13 fixed-settled, 19 provisional, 18 open** (50 gaps, including the new G49). Clip IDs refer to the revised `specs/movement_behavior/recording_shot_list.md` (session 1: C0, A1, A2, A3, W1, D3, D1, S2).

| ID | Status | Basis (evidence and current code) | Settles with |
|---|---|---|---|
| G05 | fixed-settled | 10.795 m/s = 425 u/s (2026-06-30 notes, V17) | D3 check only |
| G11 | fixed-settled | 13.97 m/s = 550 u/s (walls_and_ledges.md rule 30) | M1 check only |
| G12 | fixed-settled | recovery 0.2833 s zeroes all velocity | - |
| G13 | fixed-settled | closest contact normal (walls_and_ledges.md rule 3, V13 0:12) | - |
| G20 | fixed-settled | crouch press any time during the dash starts the dash slide (V5, V9) | - |
| G22 | fixed-settled | invented clamps K12/K14 removed (V9 3:03); tail speed follows G19 | D1 check only |
| G24 | fixed-settled | supported, no change | - |
| G28 | fixed-settled | 0.5 stamina (wiki Stamina page) | - |
| G31 | fixed-settled | correctly absent | - |
| G38 | fixed-settled | supported, no change | - |
| G39 | fixed-settled | supported, no change | M1 check only |
| G45 | fixed-settled | parry root, gravity kept | - |
| G48 | fixed-settled | supported; end drag skipped in the zip exit window | - |
| G01 | provisional | cap mode 1 (Hyp A), cap = bucket dash speed per V8 2:16; formula contradicted by V8 angle data | A1, A2, A3 |
| G02 | provisional | end drag mode 1 (V8 formula a) + IAD/ZMC/chain exceptions | A1, A2, A3; A8 (exceptions) |
| G03 | provisional | tangential kept x1.0 (V13 0:18, V7 8:19); normal set/add switch | W1 |
| G04 | provisional | tilted contact normal, vertical x0.8 (V14 1:08) | W3 (needs slanted fit geometry) |
| G06 | provisional | length 0.25 settled; open 0.30 vs V17 0.35 s | D3 optional, D5 |
| G07 | provisional | lockout implemented; open tick carries the G06 conflict (PROVISIONAL (G06/G07) in dash_state.gd) | D5 |
| G08 | provisional | value 0.2 settled; per-tick linear form provisional (V15 0:22 supports it) | A2/A3 tails; A4 only if residuals demand |
| G09 | provisional | flag + 0.5 s rule implemented; penalty size and clear time are placeholders | S2; S4 (clear rules) |
| G10 | provisional | 750/797 u/s for up to 0.6 s; distance conflicts with research Q5 | H1 |
| G14 | provisional | wall-jump coyote 2 ticks, emergent edge boost (V12, V13) | W4 |
| G17 | provisional | mode 1 sets 611 u/s globally (V9 0:19) | D3 |
| G18 | provisional | coyote = whole window (dash_jump_coyote_time -1) | D4 |
| G21 | done | 650 u/s all buckets (V5 0:17); dead slide 449 u/s before 0.3 s (measured S11-DC) | - |
| G26 | provisional | wishspeed caps 80/50 u/s above 700 (V8); accel rate unknown | A5 |
| G33 | provisional | vertical-only fatigue, 0.25 floor and 0.125 s min interval are placeholders | W5 |
| G36 | provisional | -600 u/s cap; trigger conditions unsourced | W6 |
| G40 | provisional | takeoff crouch storage implemented; SLIDE takeoff exemption provisional | none scheduled; add a takeoff-crouch clip to session 2 if needed |
| G46 | provisional | 0.25 after the 2 s window; persistence until landing assumed | Z1 |
| G50 | provisional | jump press during an air dash dropped, PROVISIONAL (G50) in dash_state.gd | A9 |
| G15 | open | no code change; V13 1:18 contradicts 'extra drag' (low confidence) | W1 |
| G16 | open | structure confirmed (V13 0:04); kick values under G32 | W2 |
| G19 | open | constant profile kept; no curve parameter yet | D1 |
| G23 | open | facing kept; no evidence | D1 neutral rep |
| G25 | open | zero-and-hold confirmed (V9 0:48); hold duration vs 0.13 s accel phase unknown; no code change | A1 |
| G27 | open | sets vy; horizontal nudge (V3 5:20) not implemented | A6 |
| G29 | measured | session 11: adds 500 u/s to vy, horizontal kept; ground run x0.8 for 28 ticks after | DD_* (done) |
| G30 | open | unknown | A7 (with SM) |
| G32 | open | up 7.0 and kicks 2.0/4.5/6.5 m/s unsourced | W1 (neutral), W2 |
| G34 | open | 0.3048 m unknown | W1 side note |
| G35 | open | not implemented | W5 |
| G37 | open | 0.6 m unknown | M1 |
| G41 | open | no steering; needs slide_turn_rate | S3 |
| G42 | open | not implemented | none scheduled (low priority) |
| G43 | open | values match; form and the 0.6/0.75/1.0 s windows (V15 0:27) not modelled | S1; S2 side read |
| G44 | open | 5 degrees unknown; 830 u/s slope cap evidence (V15 0:16) | none scheduled (low priority) |
| G47 | open | not implemented | Z1 |
| G49 | open | new (video_guides.md, V10): wall strafe / wall boost; expected emergent, unverified | W6 |

Each gap-table row below also carries its status and date in the ID cell.

---

## 1. The two known complaints

### 1.1 "Air dashing can build immense speed"

Root cause: the air dash is an **uncapped additive impulse with no end drag**, and it runs on top of a dash-jump that keeps the full ground-dash speed.

- `core/states/dash_state.gd:59-60` adds `dir * air_dash_speed` to velocity with no cap. The air dash speed is `8 m / duration` (`compiled_move_params.gd:57`). That gives 18.6 m/s (733 u/s) for B1, 17.0 m/s for B2 and 15.7 m/s for B3.
- `dash_state.gd:111-112`: the dash-jump keeps the ground-dash horizontal speed. For B1 that is 16.1 m/s (635 u/s).
- `dash_state.gd:72-77`: the air dash ends with velocity kept, no end drag, and the exit clamp off (`movement_params.gd:91`).
- `air_state.gd:126`: air drag is 0.1 /s, applied as exponential decay. The real value is 0.2.
- Worked example (B1): a forward dash-jump gives 635 u/s, and a forward air dash then gives 635 + 733 = **1368 u/s**. With Stamina Mastery's extra air dash it reaches about **2100 u/s**. A land-crouch then enters an AIR slide at friction 0.1875 and keeps most of it.
- Verified real behavior (`air_movement.md`):
  - The air dash is an impulse whose component along the dash direction is capped at about **700 u/s** (about 900 with Stamina Mastery, possibly before the nerf; SM is now +23%). Confidence: M for the cap, L for the exact formula.
  - A forward dash while already fast gives little or no gain.
  - An angled dash exceeds the cap only through the perpendicular component. This is the strafe dash.
  - About 20% of total velocity is removed at the end of the dash (M-L). The exceptions are IAD, the ZMC window and chaining into another air dash.
  - Real result for the same B1 input: about 700 u/s right after the dash and about 560 u/s after the end drag. Ours is 1368 u/s, **about 2.4x too fast**.
- Fix: gaps G01 and G02.

### 1.2 "Wall bounce feels inaccurate"

There are four independent causes, in order of impact:

1. **All incoming momentum is discarded.** `air_state.gd:96` sets `velocity = n * kick + up`, so the tangential speed along the wall becomes 0.
   - Real: the normal and vertical axes are set to fixed values, and the tangential part is at least partly kept (the Edge Boost page says it "stacks"). Confidence is M, conflicting between the wiki Movement and Edge Boost pages. [G03]
2. **Corner boost is backwards.** `air_state.gd:91-93` redirects the *entire* approach speed along the horizontal normal and multiplies by 0.8. At 900 u/s that throws you straight off the corner at about 720 u/s plus the kick.
   - Real: a convex contact gives an **upward-tilted** normal. The effect is extra height or launch angle, reduced 20% on 2025-10-02. It is not a redirect of approach speed. [G04]
3. **Normal selection.** `air_state.gd:72-78` averages the normals from 8 fixed-direction sweeps (`kinematic_mover.gd:322-361`).
   - Real: the push is along the **closest-point** capsule normal. Averaging tilts the launch when a second wall or a floor lip is within 0.3 m. [G13]
4. **Missing pieces.**
   - There is no Edge Boost (late jump on a vertical edge adds speed along travel) [G14].
   - There is no extra "significant" drag after a wall jump [G15].
   - The input's tangential component is ignored: only `wish·n` picks one of three kicks (`air_state.gd:84-89`) [G16].

---

## 2. Gap table (all mechanics)

Columns: current code (file:line) | real behavior | severity | confidence | settle by | proposed change.

### Ground dash and dash-jump

| ID | Mechanic | Current code | Real behavior | Sev | Conf | Settle | Proposed change |
|---|---|---|---|---|---|---|---|
| G05<br>**fixed-settled** 2026-09-27 | Dash-jump vertical | Sets vy = `dash_jump_vertical_speed` 7.493 m/s = 295 u/s (`movement_params.gd:70`, `dash_state.gd:112`), the same as a normal jump | ~425 u/s (10.8 m/s) vertical | major | M | R | Set to 10.795 m/s. Re-fit horizontal so the total travel is about 19 m [D3]. |
| G06<br>**provisional** 2026-09-27 | Dash-jump window length | 0.30 s open, 0.20 s long (`movement_params.gd:68-69`) | 0.30 to 0.55 s (0.25 s long) since 2026-06-30. Not bucket-scaled. | major | H | R | `dash_jump_window_length` = 0.25. Conflict: V17 gives a 0.35 s open; the official 0.30 s is kept and marked PROVISIONAL (G06). |
| G07<br>**provisional** 2026-09-27 | Early-jump lockout | A jump before the window is only buffered for 0.1 s (`dash_state.gd:100-101`), so a second press inside the window still dash-jumps (`:91-94`) | A jump pressed before the window opens locks out the dash-jump for that dash | major | M | R | Add `s.dash_jump_locked`, set on a jump press when `k < open_tick`. Check it in `:92`. |
| G17<br>**provisional** 2026-09-27 | Dash-jump horizontal | Keeps the current dash speed × 1.0 (`dash_state.gd:111`): 635/579/562 u/s by bucket | Sets about 611 u/s (fit to 19 m). Global or per bucket is unknown. | major | M-L | Rec [D3] | Keep, but add `dash_jump_sets_horizontal` + `dash_jump_horizontal_speed`. Decide after D3 (B1 vs B3 distance). |
| G18<br>**provisional** 2026-09-27 | Coyote dash-jump | `on_ground` = grounded or airborne ≤ 1 tick (`dash_state.gd:90`). Off a ledge the press is only buffered. | A dash-jump shortly after dashing off a ledge works and does not use the air jump | minor | M | Rec [D4] | Add `dash_jump_coyote_time` and use it in place of the 1-tick test |
| G19<br>**open** 2026-09-27 | Dash velocity profile | Constant speed = 10 m / duration every tick (`dash_state.gd:171`), then clamp to walk speed (`:140-141`) | Ends at walk speed. The shape is unknown. The dash hop hints the tail is above walk speed. | major | L | Rec [D1] | Once D1 exists, replace the constant with a sampled curve `ground_dash_profile: Curve` (normalized time to speed), keeping the 10 m area |
| G20<br>**fixed-settled** 2026-09-27 | Dash slide trigger | Only crouch *held at dash end* makes a slide (`dash_state.gd:129-137`) | Crouch at any time during the dash starts the slide | major | M | R | Enter the slide on the crouch press during GROUND_DASH (not stored) |
| G21<br>**provisional** 2026-09-27 | Dash slide speed | The slide inherits the dash speed (635/579/562) | Leif: about 650 u/s in every bucket. A crouch before 0.3 s gives a "dead slide" that ends around 270 u/s. | major | M-L (single source) | Rec [D2] | Params `dash_slide_speed` and `dash_slide_dead_before`, wired after D2 |
| G22<br>**fixed-settled** 2026-09-27 | Dash hop / buffered jump clamp | A buffered jump at dash end first clamps to walk speed (`dash_state.gd:131-132`). The ability-cancel jump also clamps (`:97`). | The dash hop keeps the tail speed. No clamp is documented. | minor | L | Rec [D1] | Remove both clamps once D1 gives a tail speed. The hop then emerges from profile + jump. |
| G23<br>**open** 2026-09-27 | Neutral-input dash direction | Facing (`dash_state.gd:13`, `movement_params.gd:65`) | Unknown | minor | L | Rec [D1 variant] | None until recorded |
| G24<br>**fixed-settled** 2026-09-27 | Parry during dash | Zeroes horizontal (`melee_state.gd:28-35`) | Cancels ground-dash momentum (2026-09-16) | - | H | supported | none |

### Air dash, air jump, down dash, air control

| ID | Mechanic | Current code | Real behavior | Sev | Conf | Settle | Proposed change |
|---|---|---|---|---|---|---|---|
| G01<br>**provisional** 2026-09-27 | Air dash velocity rule | `velocity += dir * speed` with no cap (`dash_state.gd:60`) | Impulse with a directional cap of about 700 u/s (17.8 m/s), about 900 with SM (maybe pre-nerf). Perpendicular velocity is kept. | **critical** | M (cap) / L (formula) | R+Rec [A1-A3] | Implement Hypothesis A now: `v_par_new = max(min(v_par + J, C), min(v_par, C))` with v_perp kept. Add `air_dash_cap` 17.78 m/s and `air_dash_cap_mode` (0 = add-uncapped legacy, 1 = Hyp A, 2 = set-to-C) so A1-A3 can select the mode without code changes. |
| G02<br>**provisional** 2026-09-27 | Air dash end drag | None. Velocity is kept (`dash_state.gd:72-77`). An optional clamp to walk speed is off (`movement_params.gd:91`). | About 20% of total velocity removed at the end. Skipped when landing into a slide (IAD), in the ZMC window, or when chaining another air dash. | **critical** | M-L | R+Rec [A2] | Add `air_dash_end_speed_mult` 0.8 plus the three exceptions. Delete `air_dash_exit_clamp` (it contradicts the drag model). |
| G08<br>**provisional** 2026-09-27 | Air drag value | 0.1 /s, applied as `v *= 1 - k*dt` (`movement_params.gd:101`, `air_state.gd:126`) | Coefficient 0.2. The functional form (linear, exponential or speed²) is unknown. | major | M (value) / L (form) | R (value) + Rec [A2/A3 tails; A4 only if needed] (form) | Set 0.2 now (done). Fit the form from the A2/A3 post-dash tails (A4 removed from the shot list 2026-09-27). |
| G25<br>**open** 2026-09-27 | Air dash vertical | vy zeroed at start and held at 0 (`dash_state.gd:61-62, 178-179`) | Gravity and drag are off during the burst. Whether vy is zeroed is unknown (U-list). | major | L | Rec [A1] | Keep the switch and decide from A1 (vertical overlay trace) |
| G26<br>**provisional** 2026-09-27 | Air strafe | Source-style: wishspeed cap 30 u/s, accel 10, ×0.5 above 450 u/s (`air_state.gd:113-123`, `movement_params.gd:97-100`) | Weak. Stronger below 450 u/s, only redirects at high speed. Leif: "accel limit" 80, 50 above 700 u/s (units unclear). | major | M (qualitative) / L (numbers) | Rec [A5] | Add a second threshold (700 u/s). Fit the cap and accel to A5 turn-rate data. |
| G27<br>**open** 2026-09-27 | Air jump set vs add | Sets vy (`air_state.gd:44-46`) | Unknown. Leif: a double jump adds some horizontal speed from held keys. | minor | L | Rec [A6] | Add `air_jump_horizontal_boost` (default 0) and decide after A6 |
| G28<br>**fixed-settled** 2026-09-27 | Down dash cost | 1.0 (`movement_params.gd:57`) | 0.5 stamina | minor | M | R | Set 0.5 |
| G29<br>**open** 2026-09-27 | Down dash speed | Sets vy = -15 m/s and keeps horizontal (`air_state.gd:25`) | Unknown | minor | L | Rec [A7] | Fit from A7 |
| G30<br>**open** 2026-09-27 | Down dash counter | `down_max` also grows with extra air dashes (`air_state.gd:22`) | SM gives +1 per airtime, but whether down dash shares it is unknown | minor | L | Rec (low priority) | none |
| G31<br>**fixed-settled** 2026-09-27 | Heavy drag after jumping out of a dash slide | Not implemented | Mentioned by one source, L. Spec says do not implement. | - | L | - | none (correctly absent) |

### Walls, corners, edges, mantle

| ID | Mechanic | Current code | Real behavior | Sev | Conf | Settle | Proposed change |
|---|---|---|---|---|---|---|---|
| G03<br>**provisional** 2026-09-27 | Wall jump tangential momentum | Discarded. `velocity = n*kick + up` (`air_state.gd:96`). | Normal and vertical axes set to fixed values. Tangential at least partly kept ("stacks"). | **critical** | M (conflict) | R+Rec [W1] | Decompose incoming v into normal and tangential parts. New velocity = `n*kick + up*vy + t*keep`, with `wall_jump_tangent_keep` defaulting to 1.0 (interim) until W1 fits it. |
| G04<br>**provisional** 2026-09-27 | Corner boost | `h = n * (speed + kick) * 0.8` redirects all approach speed along the normal (`air_state.gd:91-93`) | Convex contact tilts the push normal upward, giving extra height. Reduced 20% (2025-10-02). | **critical** | M | R+Rec [W3] | Replace with a tilted normal: `n' = normalize(n + up*corner_tilt)`, scaled 0.8 on the tilt contribution. Tangential is kept as in G03. |
| G13<br>**fixed-settled** 2026-09-27 | Wall normal selection | Average of up to 8 sweep normals, horizontal only (`air_state.gd:70-78`, `kinematic_mover.gd:322-361`) | Push along the closest-point capsule normal. All walls within a small radius count. | major | M | R | Use the single closest contact's normal (min distance) and keep `convex` from that contact |
| G14<br>**provisional** 2026-09-27 | Edge boost | Missing | A late jump at a vertical edge (1-2 tick window) adds speed along the travel direction | major | M (exists) / L (numbers) | Rec [W4] | Add after W4. Needs an edge-proximity test in `find_walls`. |
| G15<br>**open** 2026-09-27 | Post-wall-jump air drag | Normal air drag | "Significant" extra drag after a wall jump. Value and duration unknown. | major | M (exists) / L (numbers) | Rec [W1] | Add `wall_jump_drag` + `wall_jump_drag_time` and fit from the W1 decay |
| G16<br>**open** 2026-09-27 | Wall jump input shaping | Three kicks chosen by `wish·n` thresholds ±0.3. The tangential input component is ignored (`air_state.gd:84-95`). | Toward = steep at a fixed angle. Away = long and flat. Neutral = in between. Three distinct kick speeds (2025-05-08). No input needed. | major | M (qualitative) / L (numbers) | Rec [W2] | Fit the three (up, out) pairs from W2. Decide whether the tangential input steers. |
| G32<br>**open** 2026-09-27 | Wall jump up speed / kicks | up 7.0 m/s. Kicks 2.0/4.5/6.5 m/s (`movement_params.gd:116-119`). | Unknown | major | L | Rec [W2] | Fit |
| G33<br>**provisional** 2026-09-27 | Wall fatigue curve | Each jump adds 0.25 fatigue, vy × max(0.25, 1 - f), and fatigue recovers over 1.25 s as `(1-t)^k` (`movement_sim.gd:273-281, 643-646`, `air_state.gd:82-83`) | A jump within 1.25 s is weak vertically only and resets the timer. Landing clears it. Air melee adds fatigue. Binary vs graded is unknown. | minor | M (rules) / L (curve) | Rec [W5] | Fit the curve from W5 |
| G34<br>**open** 2026-09-27 | Wall detect distance | 0.3048 m (12 u) (`movement_params.gd:114`) | "Small radius", unknown | minor | L | Rec [W1 side note] | Fit from W1 |
| G35<br>**open** 2026-09-27 | Same-surface lockout | Missing | Reported 2024-12, uncertain | minor | L | Rec [W5] | Only if W5 shows it |
| G36<br>**provisional** 2026-09-27 | Wall slide fall cap | Missing (there is no wall-slide state) | -600 u/s fall cap while wall-sliding | minor | M | Rec (low) | Add `wall_slide_max_fall` 15.24 m/s when touching a wall with a downward velocity |
| G49<br>**open** 2026-09-27 | Wall strafe / wall boost | No explicit handling. Air accel and the air dash run before the kinematic clip; K49 may zero velocity at shallow angles. | Touching a wall, input and air-dash acceleration into the wall is redirected along it; a wall boost angle is about 55 deg from a run, 75 deg off a zipline (video_guides.md G49, V10 0:17 / 1:47 / 2:30) | major | V (single expert) | Rec [W6, W1 K49 note] | None until W6 shows whether it emerges |
| G11<br>**fixed-settled** 2026-09-27 | Mantle glide speed | 8.9 m/s = 350 u/s (`movement_params.gd:134`, `mantle_state.gd:86`) | About 550 u/s (14.0 m/s) into a slide | major | M | R | Set 13.97 m/s |
| G37<br>**open** 2026-09-27 | Mantle reach | 0.6 m (`movement_params.gd:132`) | 212 u reported (L, the geometry meaning is unclear) | minor | L | Rec [M1] | Fit |
| G38<br>**fixed-settled** 2026-09-27 | Mantle momentum | Zeroed at start and end (`mantle_state.gd:57, 79`) | A plain mantle kills momentum | - | H | supported | none |
| G39<br>**fixed-settled** 2026-09-27 | Superglide | A jump is accepted on the first tick after the mantle ends (ground transitions) | Superglide = jump when actionable | - | M | supported | Check buffering in M1 |

### Slide, crouch, ground

| ID | Mechanic | Current code | Real behavior | Sev | Conf | Settle | Proposed change |
|---|---|---|---|---|---|---|---|
| G09<br>**provisional** 2026-09-27 | Slide-hop penalty (slide drag flag) | Missing. A slide jump is always free and clean (`ground_state.gd:21-24`). | After the first slide, jumping out of a flagged slide under 0.5 s is penalized. Ground time or a downhill jump clears the flag. A scroll short hop does not set it. | major | M (rules) / L (penalty size) | R+Rec [S2] | Add `slide_hop_flag`, `slide_hop_min_time` 0.5 and `slide_hop_penalty` (fit from S2) |
| G40<br>**provisional** 2026-09-27 | Crouch storage on takeoff | Crouch storage only for the dash (`dash_state.gd:32, 144-148`). Leaving the ground clears the block (`movement_sim.gd:512`), and landing with crouch held always slides (`movement_sim.gd:548-558`). | Crouch held before the dash **or takeoff** means no slide on landing | major | M | R | Record `crouch_held_at_takeoff` in `_leave_ground` / `do_ground_jump`. `_land` skips the slide while that crouch is still held. |
| G41<br>**open** 2026-09-27 | Slide steering | No input effect at all (`ground_state.gd:111-128`) | W/A/D do not change speed. Steering is rate-limited. | minor | M | Rec [S3] | Add `slide_turn_rate` (deg/s) and fit |
| G42<br>**open** 2026-09-27 | Crouch spam slowdown | Missing | Repeated crouch toggles progressively slow you | minor | M | Rec (low) | Later |
| G43<br>**open** 2026-09-27 | Slide friction form | `v *= 1 - f*dt` (`ground_state.gd:126`) | Values 0.1875 / 3.1875 / 0.6875 match. The form is unknown. | minor | M | Rec [S1] | Fit from the S1 decay curve |
| G44<br>**open** 2026-09-27 | Slope slide threshold | 5 degrees (`movement_params.gd:105`) | "Any speed on a slope". Angle unknown. | minor | L | Rec (low) | none |

### Ziplines, melee, misc

| ID | Mechanic | Current code | Real behavior | Sev | Conf | Settle | Proposed change |
|---|---|---|---|---|---|---|---|
| G10<br>**provisional** 2026-09-27 | Heavy melee lunge | 5 m over 0.3 s = 16.7 m/s (656 u/s) (`movement_params.gd:157-158`, `melee_state.gd:103-105`) | Up to 0.6 s at 750/797 u/s. The distance curve is unknown. | major | M | R (speed, time) + Rec [H1] (curve) | Lunge speed 19.05 m/s, max time 0.6 s |
| G12<br>**fixed-settled** 2026-09-27 | Heavy melee recovery | Clamps to walk speed at lunge end (`melee_state.gd:82`), then friction or air drag with no input (`:108-111`). Time 0.2 s. | Recovery 0.2833 s **zeroes all velocity** | major | M | R | Set velocity to ZERO during recovery. Time 0.2833. Windup 0.36 (`:156`). |
| G45<br>**fixed-settled** 2026-09-27 | Parry movement | ×0.5 move multiplier for 1 s (`movement_params.gd:168`) | Parry roots the player | minor | M | R | `parry_move_mult` 0 (keep gravity) |
| G46<br>**provisional** 2026-09-27 | Zip exit drag after 2 s | Returns to normal air drag 0.1 (`air_state.gd:125-126`) | Drag 0 for 2 s, then **0.25** | minor | M | R | Add `zip_exit_drag` 0.25, used until landing |
| G47<br>**open** 2026-09-27 | Cake jump | Missing. A zip jump adds `jump_speed` to vy (`rail_state.gd:98-101`). | A jump within 0.14 s of attach is special (cake jump) | minor | M (exists) / L (numbers) | Rec [Z1] | Later |
| G48<br>**fixed-settled** 2026-09-27 | Zip dash | No end drag already, because none of our air dashes have one | Zip dash has no end drag | - | M | supported now | When adding G02, exempt the zip dash |
| G50<br>**provisional** 2026-09-27 | Jump press during an air dash | Dropped: no wall jump, mantle, air jump or buffer (`dash_state.gd` AIR_DASH transitions) | No source says what a mid-dash jump press does (V3 4:39 only says velocity is locked to the dash direction) | minor | - | Rec | Record an air dash into a wall with a jump press mid-dash; PROVISIONAL (G50) comment in code |

---

## 3. Every cap, clamp, reset and momentum discard in the code

Verdicts:
- **supported** means it matches the research.
- **contradicted** means research says otherwise.
- **unknown** means no public evidence either way.

| # | Location | What it does | Verdict | Gap |
|---|---|---|---|---|
| K1 | `movement_sim.gd:121-123` | Zero horizontal after move (parry during a dash) | supported | G24 |
| K2 | `movement_sim.gd:159-162` | External impulse op set/add | supported (API; abilities choose) | - |
| K3 | `movement_sim.gd:199-200` | Teleport zeroes velocity unless `keep_velocity` | supported (Warp Stone zeroes) | - |
| K4 | `movement_sim.gd:446-447` | Ground states (not slide) get vy = 0 after the move | supported (engine convention, no evidence against) | - |
| K5 | `movement_sim.gd:477-481` | Snap to ground zeroes vy | supported | - |
| K6 | `movement_sim.gd:512` | Leaving the ground clears crouch-storage slide block | **contradicted** (takeoff storage) | G40 Status: fixed in fidelity pass 1 (G40). |
| K7 | `movement_sim.gd:533-534` | Landing zeroes only vy, with no horizontal clamp | supported (no landing clamp, bhop works) | - |
| K8 | `movement_sim.gd:654-659` | `clamp_horizontal` helper (used by K12, K14, K16, K17, K28) | - | see uses |
| K9 | `movement_sim.gd:644` | Wall fatigue clamped to [0, 1] | unknown | G33 Status: unchanged; still unknown (G33). |
| K10 | `dash_state.gd:43` | Ground dash **sets** velocity and discards prior momentum | supported | - |
| K11 | `dash_state.gd:171` | Ground dash re-sets constant speed every tick (no steering, flat profile) | unknown (profile) | G19 |
| K12 | `dash_state.gd:97` | Ability-cancel jump clamps to walk speed | unknown | G22 Status: removed in the review fixes (no source for the clamp). |
| K13 | `dash_state.gd:111-112` | Dash-jump keeps dash horizontal, sets vy 295 u/s | horizontal unknown, vertical **contradicted** | G17, G05 Status: mode 1 (default) sets 611 u/s along the dash direction, PROVISIONAL (G17); mode 0 keeps the legacy multiplier. |
| K14 | `dash_state.gd:131-132` | Buffered jump at dash end clamps to walk speed | unknown (the dash hop suggests no clamp) | G22 Status: removed in the review fixes (V9 3:03, ground_dash.md rule 12b). |
| K15 | `dash_state.gd:137` | Dash slide inherits dash speed | **contradicted** (M-L: 650 u/s, dead slide) | G21 Status: dash slide 650 u/s in every bucket; dead slide 449 u/s before 0.3 s (session 11). |
| K16 | `dash_state.gd:140-141` | Ground dash exit clamp to walk speed | supported (ends at walk speed) | - |
| K17 | `dash_state.gd:147` | Crouch-stored dash exits clamped to crouch speed | unknown | - Status: removed in the review fixes; the slide block until crouch release is kept. |
| K18 | `dash_state.gd:60` | Air dash adds impulse with **no cap** | **contradicted** | G01 Status: mode 1 (Hyp A cap) is the default, PROVISIONAL (G01). |
| K19 | `dash_state.gd:61-62, 178-179` | Air dash zeroes vy and holds it at 0 | unknown | G25 |
| K20 | `dash_state.gd:72-77` | Air dash end keeps full velocity (no drag). The optional clamp is off. | **contradicted** (about 20% end drag). The clamp option is also contradicted. | G02 Status: end drag added, PROVISIONAL (G02); after an IAD it is deferred to the scheduled dash end. |
| K21 | `air_state.gd:25` | Down dash sets vy = -15 m/s | unknown | G29 |
| K22 | `air_state.gd:44-46` | Air jump sets vy (discards falling speed) | unknown | G27 |
| K23 | `air_state.gd:82` | Wall-jump vertical floor 0.25 × under fatigue | unknown | G33 Status: floor kept, PROVISIONAL (G33); fatigue is vertical-only (walls_and_ledges.md rule 13). |
| K24 | `air_state.gd:91-93` | Corner boost redirects approach speed along the normal × 0.8 | **contradicted** | G04 Status: legacy mode 0 only; mode 1 (tilted normal) is the default (G04). |
| K25 | `air_state.gd:96` | Wall jump **sets** full velocity (tangential momentum discarded) | **contradicted** | G03 Status: tangential velocity kept (G03). |
| K26 | `air_state.gd:115-123` | Air accel capped by wishspeed 30 u/s, halved above 450 u/s | unknown (the 450 threshold is supported, the numbers are not) | G26 Status: caps 80/50 u/s (G26); the high-speed accel factor is now 1.0 because no source gives one. |
| K27 | `air_state.gd:125-126` | Air drag 0.1, suspended for 2 s after zip exit | value **contradicted** (0.2). Suspension supported. | G08, G46 Status: fixed: 0.2 (G08). |
| K28 | `melee_state.gd:82` | Heavy lunge end clamps to walk speed | **contradicted** (recovery zeroes all) | G12 Status: fixed (G12). |
| K29 | `melee_state.gd:103-107` | Lunge sets horizontal to 16.7 m/s | **contradicted** (750/797 u/s) | G10 Status: fixed speeds (G10); the distance conflict with Q5 is open, PROVISIONAL. |
| K30 | `melee_state.gd:108-111` | Recovery keeps momentum under friction or drag | **contradicted** | G12 Status: fixed (G12). |
| K31 | `melee_state.gd:33-35` | Parry zeroes dash horizontal | supported | G24 |
| K32 | `ground_state.gd:94-96` | Ground friction (Source-style, stop speed 100 u/s) | unknown (values Open Q1) | - |
| K33 | `ground_state.gd:103-106` | Ground accel only adds up to wishspeed (above it, friction decays speed) | supported (no hard ground cap) | - |
| K34 | `ground_state.gd:59-62` | Slide ends below crouch speed (4.8 m/s) and zeroes vy | supported | - |
| K35 | `ground_state.gd:76-83` | `enter_slide` speed override (mantle glide) | value **contradicted** | G11 |
| K36 | `ground_state.gd:126` | Slide friction `v *= 1 - f*dt` | values supported, form unknown | G43 |
| K37 | `mantle_state.gd:57` | Mantle start zeroes velocity | supported | - |
| K38 | `mantle_state.gd:79` | Mantle end zeroes velocity | supported | - |
| K39 | `forced_state.gd:21, 45` | Forced motion sets velocity | supported (ability-driven) | - |
| K40 | `rail_state.gd:53` | Rope attach zeroes velocity | unknown | - |
| K41 | `rail_state.gd:82, 189` | Zip attach zeroes, then fixed rail speed | supported | - |
| K42 | `rail_state.gd:100` | Zip jump adds 295 u/s to vy, line velocity kept | unknown | G47 |
| K43 | `rail_state.gd:110` | Rope drop zeroes velocity | unknown | - |
| K44 | `rail_state.gd:113` | Rope jump sets wish × move speed + jump | unknown | - |
| K45 | `rail_state.gd:132` | Knock-off zeroes horizontal, clamps vy ≤ 0 | supported | - |
| K46 | `kinematic_mover.gd:186-188` | Grounded walkable hit re-projects with no speed loss | supported | - |
| K47 | `kinematic_mover.gd:199-211` | Crease: velocity projected onto the crease line | supported (standard collide-and-slide) | - |
| K48 | `kinematic_mover.gd:212-214` | 3 or more planes: velocity = 0 | unknown (engine convention) | - |
| K49 | `kinematic_mover.gd:215-222` | Backtrack kill: a clip that reverses velocity zeroes it (in the air: all of it) | unknown. Can feel like a "sticky" wall at shallow angles. Check in W1. | - |
| K50 | `compiled_move_params.gd:136-141` | Slows cannot push move speed below 2.0 m/s | supported | - |
| K51 | `compiled_move_params.gd:150-158` | Move-speed bonus diminishing returns, k = 12 m/s | supported (stat bonuses only) | - |
| K52 | `compiled_move_params.gd:209-214`, `movement_params.gd:80, 88, 94` | 1 air jump, 1 air dash, 1 down dash per airtime, reset on landing, mantle end, zip or rope attach (`movement_sim.gd:631-640`) | supported | G30 |
| K53 | `movement_sim.gd:112-113, 317-318` | Crouch (not slide) resets sprint | unknown (slide keeping sprint is supported) | - |
| K54 | `movement_params.gd:57` | Down dash costs 1 | **contradicted** (0.5) | G28 Status: fixed (G28). |
| K55 | `movement_params.gd:69` | Dash-jump window 0.2 s | **contradicted** (0.25) | G06 Status: fixed (G06). |
| K56 | `movement_params.gd:168` | Parry move multiplier 0.5 | **contradicted** (root) | G45 Status: fixed (G45). |

There is **no terminal velocity** and **no global horizontal speed cap**. Both match the research: none is known in the air, and the ground has none.

---

## 4. Real behaviors the code is missing

| Missing behavior | Gap | Conf | Settle |
|---|---|---|---|
| Air-dash directional cap (about 700 / about 900 with SM) | G01 | M | R+Rec |
| Air-dash end drag (about 20%) with IAD, ZMC and chain exceptions | G02 | M-L | R+Rec |
| Early-jump dash-jump lockout | G07 | M | R |
| Coyote dash-jump (no air jump used) | G18 | M | Rec |
| Crouch-any-time dash slide, fixed about 650 u/s start, dead slide before 0.3 s | G20, G21 | M / M-L | R / Rec |
| Tangential momentum kept on wall jump | G03 | M | R+Rec |
| Upward-tilted corner-boost normal | G04 | M | R+Rec |
| Edge boost | G14 | M | Rec |
| Post-wall-jump drag | G15 | M | Rec |
| Same-surface wall-jump lockout (uncertain) | G35 | L | Rec |
| Wall-slide fall cap -600 u/s | G36 | M | R |
| Slide-hop (slide drag flag) penalty | G09 | M | R+Rec |
| Crouch storage on takeoff | G40 | M | R |
| Slide steering at a limited rate | G41 | M | Rec |
| Crouch spam slowdown | G42 | M | Rec |
| Double-jump horizontal nudge from held keys | G27 | L | Rec |
| Heavy-melee recovery zeroing all velocity | G12 | M | R |
| Parry root | G45 | M | R |
| Zip exit drag 0.25 after the 2 s window | G46 | M | R |
| Cake jump (≤ 0.14 s) | G47 | M | Rec |
| Majestic Leap landing clamp about 500 u/s (ability-specific; belongs in the ability, not the core) | - | M | R (when the ability is built) |

---

## 5. Top 10 by feel impact

| Rank | Gap | Why it matters | Settle |
|---|---|---|---|
| 1 | G01 air dash uncapped | About 2.4x real speed after dash-jump + air dash. Breaks every route and the stamina economy. | R+Rec |
| 2 | G03 wall jump discards tangential momentum | Every wall bounce kills flow. This is the core of "bounce feels wrong". | R+Rec |
| 3 | G04 corner boost redirects approach speed | Random high-speed ejections off pillars and corners | R+Rec |
| 4 | G02 no air-dash end drag | Compounds G01. Removes the timing skill of IAD, chaining and ZMC. | R+Rec |
| 5 | G05 dash-jump vertical 295 vs 425 u/s | Dash-jumps are too flat and short in air time. The most common tech in the game. | R |
| 6 | G08 air drag 0.1 vs 0.2 | Every airborne second carries twice the momentum it should | R (value) |
| 7 | G06 dash-jump window 0.20 vs 0.25 s | Dash-jumps fail that should succeed (strictest for B1) | R |
| 8 | G07 missing early-jump lockout | Mashing jump is rewarded where the real game punishes it | R |
| 9 | G09 missing slide-hop penalty | Chain slide-hopping is free, so ground speed persists too well | R+Rec |
| 10 | G11 mantle glide 350 vs 550 u/s | Mantle glide, a key route tech, is 36% too slow | R |

Next in line: G12/G10 (heavy melee), G13 (wall normal), G20/G21 (dash slide), G40 (takeoff crouch storage), G26 (air strafe).

**Counts (top 10):**
- 5 can be settled by research alone and changed now: G05, G06, G07, G08 (value), G11.
- 5 need recording for their final constant or formula: G01, G02, G03, G04, G09. All 5 have a research-backed direction, so an interim change (cap mode A at 700 u/s, 0.8 end multiplier, keep tangential, tilted corner normal, slide-hop flag) removes the obviously wrong behavior before the session.

**Counts (whole table, 48 gaps excluding the supported rows; original analysis, superseded by the status counts in section 0):**
- about 14 are research-settled: G05, G06, G07, G08 value, G11, G12, G10 speed, G13, G20, G28, G36, G40, G45, G46.
- about 26 need recording.
- the rest are fine as they are.

---

## 6. Suggested order of work (no code changed here)

1. **Research-only batch (tune + small logic, one PR):** G05, G06, G07, G08, G11, G12, G10 (speed/time), G13, G20, G28, G40, G45, G46.
2. **Interim structural batch:**
   - G01: cap mode A at 17.78 m/s, with modes switchable in `MovementParams`.
   - G02: end multiplier 0.8 plus the exceptions.
   - G03: keep tangential at 1.0.
   - G04: tilted normal.
   - G09: add the flag with a placeholder penalty.

   Each new constant gets a `# spec: movement_behavior/... (Rec <clip>)` comment.
3. **Recording session** (`recording_shot_list.md` session 1, revised 2026-09-27). Then fit the constants and flip modes in `.tres`.
4. Recording session 2 for the remaining provisional and open gaps (see section 0, "Settles with").

Every change must add or update a regression scenario in the existing test list (see `docs/design/movement_status.md`), in particular "B1 dash-jump + forward air dash peak speed ≤ 18 m/s".
