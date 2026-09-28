# Movement Architecture (final, synthesized)

Status: approved for implementation. Target: Godot 4.4.1, GDScript. Authority: `specs/movement.md` (behavior) and `specs/_measurement_protocol.md` (measurement). Where this document and the spec disagree on behavior, the spec wins and this document gets fixed.

## 0. Scoring and decision

| Design | Spec fidelity | Netcode readiness | Extensibility (abilities/items) | Impl. risk in 4.4 (10 = low risk) | Testability | Total |
|---|---|---|---|---|---|---|
| A: spec-faithful Source-style loop, one monolithic controller | 9 | 7 | 6 | 7 | 9 | 38 |
| B: deterministic pure-sim, netcode-first | 8 | 10 | 6 | 6 | 9 | **39** |
| C: composable modifier/forced-motion framework | 7 | 7 | 10 | 5 | 7 | 36 |

B has the highest total and A has the highest fidelity. **Final design = A's mechanics and state set, run inside B's pure-simulation and netcode contract.** From C it takes the ModifierStack, ControlLocks and a light FORCED state. C's full generic motion-graph framework is not taken. It is deferred behind a reserved hook.

Math errors found while checking the three proposals are corrected in the tests in section 13:
- A's DR example: +2, +2, +3 gives 5.75, not 6.75.
- A's air-drag example gives 9.0477, not 9.0487.
- C used 0.75 as the slide friction. It is 0.1875.
- Jump landing is on tick 39, not 40.
- Recovery at +12% finishes on tick 258, not 257.
- B's slide exit assumed a 4.75 crouch speed. With 4.8 it is tick 69, not 70.

## 1. Base on an existing Source-like controller, or build our own?

**Build our own, clean-room.** Existing controllers can be read as general background only, and only where they are MIT or CC0. We write every line ourselves. There are five reasons:

1. **The mechanics don't match.** Public "Source movement" controllers solve Quake/CS/TF2 bhop and air-strafe. Deadlock's core is different, and most of it would have to be rewritten anyway:
   - set-velocity ground dashes with buckets and a dash-jump window;
   - stamina bars;
   - two-stage slide friction;
   - mantle height bands;
   - wall-jump fatigue;
   - ziplines;
   - MOBA speed stacking with DR, slow floor and sprint ramp.
   The shared part is small and well known: friction, accelerate, clip velocity and step-up. It is about 150 lines, and we derive it from the published math (section 8).
2. **Licensing.** The most faithful ports come from the GPL Quake/HL SDK lineage or from GPL Godot controllers. The clean-room rule forbids copying them and forbids referencing Valve code. Writing our own removes that audit burden.
3. **Velocity ownership.** Almost every Godot controller calls `move_and_slide()`. That call owns floor snapping, velocity clipping and platform velocity. We need exact control of every m/s so the spec numbers reproduce to 1e-3.
4. **Rollback.** Netcode needs `simulate(state, cmd)` to be pure, with serializable state and integer tick timers. Retrofitting that into a node-state controller costs more than writing it.
5. **Testability.** The headless runner must drive the sim with synthetic InputCmds and no Input singleton. Controllers that read `Input` inside `_physics_process` can't do that.

Our own controller can be better than those references in the ways that matter here: exact spec numbers, data-driven tuning, determinism, and headless tests. It does not need to be smarter at the generic parts.

## 2. Conflict resolutions (explicit)

| # | Conflict | A / B / C position | Resolution |
|---|---|---|---|
| 1 | Scene body | A: CharacterBody3D + `move_and_slide`. B: PhysicsServer probe bodies. C: CharacterBody3D + custom sweeps | Keep a **CharacterBody3D** (motion_mode FLOATING) as scene presence for areas, hits and editor use, but **never call `move_and_slide`**. Collision uses two PhysicsServer3D probe bodies, one stand and one crouch capsule, with collision_layer 0 and mask WORLD, through `PhysicsServer3D.body_test_motion` (B). |
| 2 | Sim shape | A: methods on the node. B: pure `simulate(state, cmd)`. C: component graph | **Pure sim (B).** `MovementSim.simulate(state, cmd)` mutates only `state` and reads only `state`, `cmd`, compiled params and world collision. There are no globals, no Input, no Time and no randomness. |
| 3 | Timers | A: float seconds. B: integer ticks | **Integer ticks.** `ticks(s) = ceil(s*64 - 1e-6)`. The one exception is dashes: they run full ticks plus one fractional last tick, so distance stays exact (10 m / 8 m). |
| 4 | Button edges | A/C: cmd carries pressed flags. B: derive from previous buttons | **Derive (B).** InputCmd carries only held bits. The sim computes `pressed = buttons & ~state.prev_buttons`. InputSampler latches sub-tick taps so a tap is never lost. |
| 5 | View angles | float radians vs quantized | Float radians **quantized to 1/65536 turn** at creation. They serialize as u16 yaw and s16 pitch, bit-exact. |
| 6 | Crouch | A: CROUCH state. B/C: flag on GROUND | **Separate CROUCH state (A).** It has its own speed, capsule and slide entry rules. |
| 7 | Stun | A: STUNNED state. C: lock | **ControlLock overlay (C).** Stun = lock mask. The locomotion state keeps running, so a stunned player still falls and slides. |
| 8 | Parry | A: PARRY state. C: overlay | **Overlay.** Parry is a modifier plus a timer. On start it cancels a ground dash and its momentum (spec section 19). Parry itself belongs to combat. Movement only reacts. |
| 9 | Ability-driven motion | C: full motion framework. A/B: none | **Light FORCED state** driven by an external op (velocity, duration, gravity on/off, exit state). `MovementHook` is a reserved interface only (section 7.6). No implementation now. |
| 10 | Modifiers | A: flat stat fields. C: ModifierStack | **ModifierStack (C)** of ModifierDef resources keyed by StringName. It compiles to effective speeds each tick with a params hash. |
| 11 | Stamina | integer bars + timer vs float | **Float bars.** `can_spend(c)` = `stamina + 1e-5 >= c`. One bar regens at a time. Per-bar time is `cooldown / (1 + sum(recovery))` (spec section 7, assumed formula). |
| 12 | Slide friction | Source friction with stop_speed vs proportional | **Proportional**: `v *= 1 - f*dt` with no stop_speed. f = 0.1875 before the penalty onset and the penalty value after it. C's 0.75 was wrong. |
| 13 | Accel/friction defaults | A: 5/4. B: 4/4. C: 10/5 | **ground_accel = ground_friction = 4.0.** `MovementParams.validate()` warns if accel < friction, because steady speed then falls short of wishspeed. Tune later from Open Q1. |
| 14 | Dash-jump window boundary | open at 0.3 s, length 0.2 s | Evaluated **after** the dash tick. With k = completed dash ticks, the window is **open for 20 <= k <= 31**: `ticks(0.3)` = 20, and it closes before tick 32 = 0.5 s. |
| 15 | Slide penalty boundary | `>` vs `>=` | Penalty friction applies on ticks where `slide_ticks >= ticks(onset)`, for example 48 for 0.75 s. |
| 16 | Tuning baseline | tests read .tres vs script defaults | **Formula tests use `MovementParams.new()` script defaults.** These are the frozen spec baseline and never get tuned in code. Tuning happens only in `.tres`. A separate conformance test checks that high-confidence fields in the shipped `.tres` still match the spec. |
| 17 | Visual smoothing | engine physics interpolation vs manual | **Physics interpolation off.** PlayerCharacter keeps previous and current sim positions. `get_render_position()` lerps them with `Engine.get_physics_interpolation_fraction()`. Camera and visuals are `top_level`. |
| 18 | Netcode now or later | B: full HistoryRing/Reconciler now | **Contract now, implementation deferred.** The pure sim, serializable MoveState/InputCmd, checksum, `duplicate_state()` and event suppression during resim ship now. HistoryRing, Reconciler and transport ship later. |
| 19 | Physics engine | Jolt vs GodotPhysics | **Jolt** by default. CORE adds a parity script that runs the collision tests under both engines (section 13.3). |
| 20 | Down dash cost | 0.5 vs 1 (spec conflict) | **1.0**, data-driven (`cost_down_dash`), marked low confidence. |
| 21 | Dash distance modifiers | scale duration vs speed | **Scale speed**, so the dash-jump window timing stays fixed. `dash_distance_scale_mode` allows switching after Open Q6. |
| 22 | Air jump | set vs add vertical velocity | **Set** (`air_jump_sets_vertical = true`), per Source convention. Flag kept. |
| 23 | Mantle band edges | float compare | Height is rounded to whole u: `h_u = roundi(h / 0.0254)`. Bands: [32,64) → 0.2 s, [64,96) → 0.3 s, [96,128) → 0.4 s, [128,160] → 0.5 s. Outside [32,160] there is no mantle. |
| 24 | Player vs player collision | on/off | **Off.** Probe bodies mask only WORLD. |
| 25 | Ground dash end | keep speed vs clamp | If the dash does not become a slide, horizontal speed on the end tick is clamped to the current effective move speed (`ground_dash_exit_clamp = true`). Low confidence, Open Q6. |
| 26 | Jump pressed during dash outside window | ignore vs normal jump | **Ignored.** It stays in the action buffer, so a press within `action_buffer_time` of dash end becomes a normal jump. |
| 27 | Hero data | load `data/reference/heroes.csv` vs authored | Authored `.tres` only. **`data/reference*` is never loaded at runtime.** |

## 3. Units, tick, conventions

- Meters everywhere. `1 u = 0.0254 m`. Spec u-values are converted once in `MovementParams` defaults.
- Fixed tick: `physics/common/physics_ticks_per_second = 64`, `DT = 1/64`. `physics/common/max_physics_steps_per_frame = 8`. `physics/common/physics_interpolation = false`.
- Forward is -Z. Yaw 0 faces -Z, and positive yaw turns left (Godot's rotation about +Y). Wish direction: `Basis(Vector3.UP, yaw) * Vector3(move_x, 0, -move_y)`, normalized when nonzero.
- Collision layers, named in project.godot:
  - 1 WORLD: static geometry and ramps;
  - 2 PLAYER: the CharacterBody3D;
  - 3 TRIGGER: Area3D;
  - 4 PROBE: unused and reserved.
  The player body has layer 2 and mask 0. Probe bodies have layer 0 and mask 1.
- Every class below lives under `res://`. `class_name` values are global. No two teams create the same path.

## 4. File layout and ownership

```
project.godot                                   CORE
data/movement/movement_params.tres              CORE
data/movement/heroes/hero_default_b1.tres       CORE  (base 7.2, sprint 1.6, bucket 1)
data/movement/heroes/hero_heavy_b2.tres         CORE  (base 6.4, bucket 2, stamina_cooldown 5.5)
data/movement/heroes/hero_heavy_b3.tres         CORE  (base 6.45, bucket 3, sprint 4.0, stamina_cooldown 5.5)
data/movement/modifiers/*.tres                  CORE  (example ModifierDefs: sprint_boots, enduring_speed, fleetfoot_slide, extra_stamina, slow_30, slow_20)
src/movement/core/move_units.gd                 CORE  class_name MoveUnits
src/movement/core/input_cmd.gd                  CORE  class_name InputCmd
src/movement/core/move_state.gd                 CORE  class_name MoveState
src/movement/core/active_modifier.gd            CORE  class_name ActiveModifier
src/movement/core/move_events.gd                CORE  class_name MoveEvents
src/movement/core/control_locks.gd              CORE  class_name ControlLocks
src/movement/core/modifier_stack.gd             CORE  class_name ModifierStack
src/movement/core/compiled_move_params.gd       CORE  class_name CompiledMoveParams
src/movement/core/kinematic_mover.gd            CORE  class_name KinematicMover
src/movement/core/movement_sim.gd               CORE  class_name MovementSim
src/movement/core/states/*.gd                   CORE  (internal; free-form, no class_name required)
src/movement/data/movement_params.gd            CORE  class_name MovementParams
src/movement/data/hero_movement_stats.gd        CORE  class_name HeroMovementStats
src/movement/data/modifier_def.gd               CORE  class_name ModifierDef
src/movement/world/zipline.gd                   CORE  class_name Zipline      (extends Path3D)
src/movement/world/zipline_rail.gd              CORE  class_name ZiplineRail  (RefCounted)
src/movement/world/climb_rope.gd                CORE  class_name ClimbRope    (extends Node3D)
src/movement/world/rope_rail.gd                 CORE  class_name RopeRail     (RefCounted)
src/movement/player_character.gd                CORE  class_name PlayerCharacter
scenes/player/player_character.tscn             CORE  (no camera)
tools/test_parity.ps1                           CORE

src/camera/input_sampler.gd                     CAMERA+INPUT  class_name InputSampler
src/camera/camera_rig.gd                        CAMERA+INPUT  class_name CameraRig
src/camera/crosshair.gd                         CAMERA+INPUT  class_name Crosshair
src/camera/local_controller.gd                  CAMERA+INPUT  class_name LocalController
scenes/player/local_controller.tscn             CAMERA+INPUT

src/debug/movement_debug_overlay.gd             DEBUG  class_name MovementDebugOverlay
src/debug/speed_graph.gd                        DEBUG  class_name SpeedGraph
src/debug/measurement_recorder.gd               DEBUG  class_name MeasurementRecorder
scenes/debug/movement_debug_overlay.tscn        DEBUG

src/arena/arena_builder.gd                      ARENA  class_name ArenaBuilder
src/arena/movement_arena.gd                     ARENA  class_name MovementArena
src/arena/meter_grid.gdshader                   ARENA
scenes/arena/movement_arena.tscn                ARENA
scenes/main/movement_sandbox.tscn               ARENA  (composes arena + player + local_controller + debug overlay)
tests/run_tests.gd                              ARENA  (extends SceneTree)
tests/framework/move_test_case.gd               ARENA  class_name MoveTestCase
tests/framework/sim_harness.gd                  ARENA  class_name SimHarness
tests/cases/test_*.gd                           ARENA
```

Rule: **CORE's first commit (M0) contains every CORE file in section 7 as a skeleton.** Each skeleton has the exact signatures and signals, with default returns. The other three teams build against those skeletons, and no one edits another team's files. If a team needs a new API, it goes into the "requests" list at the end of this document for the next revision. Teams do not patch around missing APIs.

## 5. project.godot (CORE)

- `application/run/main_scene = "res://scenes/main/movement_sandbox.tscn"`. ARENA creates that scene. Until it exists, a missing main scene is harmless for headless tests.
- `physics/common/physics_ticks_per_second = 64`, `physics/common/max_physics_steps_per_frame = 8`, `physics/common/physics_interpolation = false`.
- `physics/3d/physics_engine = "Jolt Physics"`.
- `layer_names/3d_physics/layer_1 = "WORLD"`, `layer_2 = "PLAYER"`, `layer_3 = "TRIGGER"`, `layer_4 = "PROBE"`.
- `display/window/size/viewport_width = 1600`, `viewport_height = 900`.
- Input map. CORE defines all of these. Only CAMERA+INPUT and DEBUG read them.

| Action | Default | Reader |
|---|---|---|
| move_forward / move_back / move_left / move_right | W / S / A / D | InputSampler |
| jump | Space | InputSampler |
| crouch | Left Ctrl, C | InputSampler |
| dash | Left Shift | InputSampler |
| fire | Mouse Left | InputSampler |
| melee_light | Q | InputSampler |
| melee_heavy | Q (hold), plus Mouse Button 5 as a direct heavy | InputSampler |
| parry | F | InputSampler |
| ability_1 | E (used for dash-jump cancel tests) | InputSampler |
| zipline_boost | V | InputSampler |
| toggle_mouse_capture | Escape | InputSampler |
| debug_toggle_overlay | F1 | DEBUG |
| debug_cycle_timescale | F2 | DEBUG |
| debug_infinite_stamina | F3 | DEBUG |
| debug_teleport_next | F4 | DEBUG |
| debug_pause | F5 | DEBUG |
| debug_step | F6 | DEBUG |
| debug_record | F7 | DEBUG |
| debug_teleport_spawn | F8 | DEBUG |

Light versus heavy on Q (tap vs hold): the sampler emits `BTN_MELEE_HEAVY` while Q has been held for 0.2 s or more. Otherwise it emits `BTN_MELEE_LIGHT` for the tap. The sim never sees timing of real keys.

## 6. InputCmd (CORE, `src/movement/core/input_cmd.gd`)

```gdscript
class_name InputCmd
extends RefCounted

const BTN_JUMP          := 1 << 0
const BTN_CROUCH        := 1 << 1
const BTN_DASH          := 1 << 2
const BTN_FIRE          := 1 << 3
const BTN_MELEE_LIGHT   := 1 << 4
const BTN_MELEE_HEAVY   := 1 << 5
const BTN_PARRY         := 1 << 6
const BTN_ABILITY       := 1 << 7   # any ability cast; cancels dash-jump window (spec section 9)
const BTN_ZIP_BOOST     := 1 << 8
const BTN_MASK          := 0x01FF

const ANGLE_STEPS := 65536          # 1/65536 turn

var tick: int = 0                   # sim tick this cmd is for
var buttons: int = 0                # HELD bits (edges derived by the sim)
var move_x: int = 0                 # -1 left, 0, +1 right
var move_y: int = 0                 # -1 back, 0, +1 forward
var yaw: float = 0.0                # radians, quantized, wrapped to [0, TAU)
var pitch: float = 0.0              # radians, quantized, clamped to [-89 deg, +89 deg]

static func create(p_tick: int, p_buttons: int, p_move_x: int, p_move_y: int, p_yaw: float, p_pitch: float) -> InputCmd
static func quantize_yaw(rad: float) -> float     # wrap, round to step, return radians
static func quantize_pitch(rad: float) -> float   # clamp, round to step, return radians
func is_held(bit: int) -> bool
func wish_dir() -> Vector3                         # world-space, y = 0, normalized or ZERO
func duplicate_cmd() -> InputCmd
func to_bytes() -> PackedByteArray                 # 12 bytes: u32 tick, u16 buttons, s8 move_x, s8 move_y, u16 yaw_steps, s16 pitch_steps (little endian)
static func from_bytes(b: PackedByteArray) -> InputCmd
func equals(other: InputCmd) -> bool
```

`create()` clamps move_x and move_y to -1..1, masks buttons with BTN_MASK and quantizes the angles. Tests build cmds only through `create()`.

## 7. CORE public API

### 7.1 MoveUnits (`src/movement/core/move_units.gd`)

```gdscript
class_name MoveUnits
const HU := 0.0254
const TICK_RATE := 64
const DT := 1.0 / 64.0
static func hu(u: float) -> float          # u -> m
static func to_hu(m: float) -> float       # m -> u
static func ticks(seconds: float) -> int   # ceil(seconds * 64 - 1e-6), min 0
static func secs(t: int) -> float
```

### 7.2 MoveState (`src/movement/core/move_state.gd`)

This is plain serializable data. Every field is public. Tests may write any field directly to set up a scenario, such as putting the player into SLIDE at 16.129 m/s.

```gdscript
class_name MoveState
extends RefCounted

enum Loco { GROUND, CROUCH, SLIDE, AIR, GROUND_DASH, AIR_DASH, DOWN_DASH, MANTLE, ZIPLINE, ROPE, HEAVY_LUNGE, FORCED }
enum LungePhase { WINDUP, LUNGE, RECOVERY }
enum SlideKind { NORMAL, DASH, DASH_JUMP, AIR }
const CHEAT_INFINITE_STAMINA := 1
const CHEAT_NO_COOLDOWNS := 2

var tick: int
var loco: int                  # Loco
var phase: int                 # sub-phase (LungePhase for HEAVY_LUNGE)
var state_ticks: int           # ticks spent in current loco
var position: Vector3          # feet (capsule bottom) in meters
var velocity: Vector3
var yaw: float
var pitch: float
var grounded: bool
var ground_normal: Vector3
var crouched: bool             # crouch capsule active
var prev_buttons: int
# stamina
var stamina: float
var stamina_regen_progress: float      # 0..1 of the bar currently regenerating
var combat_regen_penalty_ticks: int
# per-airtime counters
var air_jumps_used: int
var air_dashes_used: int
var down_dashes_used: int
var wall_jumps_done: int
var wall_fatigue: float                # 0 = fresh
var airborne_ticks: int
# sprint
var sprint_timer_ticks: int            # ticks since last reset
var sprint_active: bool
var sprint_bonus_current: float        # applied sprint m/s (ramp state)
# dash
var dash_ticks: int                    # completed dash ticks
var dash_total_ticks: int
var dash_last_fraction: float          # 0<f<=1 for the last tick
var dash_dir: Vector3
var dash_speed: float
var dash_crouch_stored: bool
var dash_jump_bonus_ticks: int         # remaining +30% air control ticks
# slide
var slide_ticks: int
var slide_kind: int
# down dash detection
var last_air_crouch_press_tick: int    # -1 if none
# mantle
var mantle_from: Vector3
var mantle_to: Vector3
var mantle_total_ticks: int
var mantle_glide: bool
# zipline / rope
var zip_rail_id: int                   # -1 none
var zip_s: float                       # meters along rail
var zip_dir: int                       # +1 / -1
var zip_ride_ticks: int
var zip_attach_lockout_ticks: int
var zip_exit_momentum_ticks: int
var zip_boost_ticks: int
var rope_id: int
var rope_s: float
# melee / parry
var heavy_cooldown_ticks: int
var parry_ticks: int
var parry_cooldown_ticks: int
# forced motion
var forced_velocity: Vector3
var forced_ticks: int
var forced_gravity: bool
var forced_exit_loco: int
# buffers
var jump_buffer_ticks: int
var action_buffer_ticks: int
var action_buffer_button: int
var coyote_ticks: int
# overlays
var modifiers: Array[ActiveModifier]
var locks: Array[Dictionary]           # { "mask": int, "ticks": int, "source": StringName }
var pending_ops: Array[Dictionary]     # applied at step 1 of next tick
var cheat_flags: int
# transient (not serialized, cleared at start of each tick)
var events: Array[Dictionary]

func duplicate_state() -> MoveState          # deep copy, events empty
func to_dict() -> Dictionary                 # no events
static func from_dict(d: Dictionary) -> MoveState
func checksum() -> int                       # hash of to_dict() with floats rounded to 1e-6
func equals(other: MoveState, eps: float = 1e-6) -> bool
func horizontal_speed() -> float
func loco_name() -> String
```

`ActiveModifier` (`active_modifier.gd`, RefCounted): `id: StringName`, `stat: int`, `value: float`, `taper_to: float`, `ticks_left: int` (-1 = permanent), `ticks_total: int`, `source: StringName`. It has `current_value() -> float`, which linearly tapers value→taper_to over ticks_total, and `duplicate_mod()`.

### 7.3 MoveEvents (`move_events.gd`)

An event is `{ "type": StringName, "tick": int, ...payload }`. The type constants are:

`LANDED {impact_speed}`, `JUMPED {kind: &"ground"|&"air"|&"dash_jump"|&"wall"|&"slide"}`, `DASHED {kind: &"ground"|&"air"|&"down", bucket}`, `STATE_CHANGED {from, to}`, `STAMINA_CHANGED {value, max}`, `DASH_JUMP_WINDOW {open}`, `SLIDE_START {kind}`, `SLIDE_PENALTY`, `SLIDE_END`, `MANTLE_START {height_m, band}`, `MANTLE_END`, `WALL_JUMP {count, fatigue}`, `ZIP_ATTACH {rail_id}`, `ZIP_DETACH {reason}`, `SPRINT_START`, `SPRINT_RESET {reason}`, `TELEPORTED`, `LOCKED {mask}`, `PARRY_START`.

### 7.4 ControlLocks (`control_locks.gd`)

```gdscript
class_name ControlLocks
const MOVE := 1; const JUMP := 2; const DASH := 4; const CROUCH := 8
const SPRINT := 16; const STAMINA := 32; const ZIPLINE := 64; const MANTLE := 128
const MELEE := 256; const TURN := 512
const STUN := MOVE | JUMP | DASH | CROUCH | SPRINT | ZIPLINE | MANTLE | MELEE | TURN
static func active_mask(state: MoveState) -> int
static func add(state: MoveState, mask: int, ticks: int, source: StringName) -> void
static func tick_down(state: MoveState) -> void
```

### 7.5 Modifiers

`ModifierDef` (Resource, `src/movement/data/modifier_def.gd`):

| Field | Type | Default |
|---|---|---|
| id | StringName | &"" |
| stat | int (ModifierDef.Stat) | Stat.MOVE_BONUS |
| value | float | 0.0 |
| taper_to | float | NAN (= no taper) |
| duration | float (s, 0 = permanent) | 0.0 |
| stack_mode | int (REFRESH, INDEPENDENT, MAX) | REFRESH |
| max_stacks | int | 1 |

`enum Stat` has these members:
- `MOVE_BONUS` (m/s, DR-stacked)
- `SPRINT_BONUS` (m/s, additive)
- `SLOW` (fraction, multiplicative)
- `SLOW_RESIST` (fraction, additive)
- `DASH_DISTANCE_PCT` (fraction, multiplicative on dash distance)
- `STAMINA_MAX` (bars)
- `STAMINA_RECOVERY` (fraction, additive)
- `AIR_JUMPS` (count)
- `AIR_DASHES` (count)
- `AIR_ACTION_DIST_PCT` (fraction, for Stamina Mastery)
- `SLIDE_BONUS` (fraction, for the onset lookup)
- `GRAVITY_PCT` (fraction)
- `FIRING_PENALTY_IMMUNE` (0/1)
- `VENT` (0/1)
- `DAMAGE_SLOW` (fraction applied above base)
- `ROPE_SLOW` (fraction)
- `MOVE_MULT` (raw multiplier, used for parry and melee self-slow)

```gdscript
class_name ModifierStack
static func add(state: MoveState, def: ModifierDef, source: StringName) -> void
static func remove(state: MoveState, id: StringName) -> void
static func tick_down(state: MoveState) -> void
static func sum(state: MoveState, stat: int) -> float
static func product_complement(state: MoveState, stat: int) -> float   # prod(1 - v)
static func stack_hash(state: MoveState) -> int
```

### 7.6 CompiledMoveParams (`compiled_move_params.gd`)

```gdscript
class_name CompiledMoveParams
extends RefCounted
var params: MovementParams        # read-only reference
var hero: HeroMovementStats
var params_hash: int
# precomputed tick values (examples; CORE may add more, never remove)
var dash_jump_open_tick: int      # 20
var dash_jump_close_tick: int     # 31 inclusive
var ground_dash_ticks_exact: float  # duration * 64, e.g. 39.68
var air_dash_ticks_exact: float
var ground_dash_speed: float      # distance / duration
var air_dash_speed: float
var down_dash_window_ticks: int   # 28
var sprint_delay_ticks: int       # 192

static func build(params: MovementParams, hero: HeroMovementStats) -> CompiledMoveParams
func slide_onset_ticks(slide_kind: int, slide_bonus: float) -> int
func mantle_band_for_height(h_m: float) -> int         # -1 = no mantle; 0..3
func effective_move_speed(state: MoveState, firing: bool) -> float
func effective_crouch_speed(state: MoveState) -> float
func effective_air_drag(state: MoveState) -> float
func stamina_max(state: MoveState) -> float
func stamina_bar_ticks(state: MoveState) -> float      # cooldown*64/(1+sum recovery), fractional
# reserved, not implemented in v1:
# func get_hook(loco: int) -> Object   # MovementHook
```

`effective_move_speed` applies these steps in order:
1. `bonus = K*(1 - prod(1 - Bi/K))` over MOVE_BONUS mods.
2. `base_part = base_move + bonus`, multiplied by the vent mult (1.7) if VENT is active.
3. `sprint_part = sprint_bonus_current` if sprint is active.
4. `speed = base_part + sprint_part`.
5. If there is a damage slow d: `speed = base + (speed - base)*(1 - d)`, applied only when speed > base.
6. Firing: `speed *= 0.75` unless immune.
7. Slows: `total = 1 - prod(1 - Si)`, `actual = total*(1 - sum resist)`, `speed = (speed - 2)*(1 - actual) + 2` when speed > 2.
8. `speed *= MOVE_MULT` product.

The firing multiplier is not applied to crouch speed.

### 7.7 KinematicMover (`kinematic_mover.gd`)

```gdscript
class_name KinematicMover
extends RefCounted
func _init(world: World3D, params: MovementParams) -> void   # creates stand + crouch probe bodies (layer 0, mask WORLD)
func dispose() -> void                                        # frees probe RIDs
func move(state: MoveState, motion: Vector3, crouched: bool) -> Dictionary
	# collide-and-slide (<= max_bumps), crease handling, backtrack kill, two-pass step-up when grounded
	# returns { "position": Vector3, "velocity": Vector3, "blocked": bool, "hit_normals": PackedVector3Array }
func probe_ground(pos: Vector3, crouched: bool) -> Dictionary   # 2 u probe + center ray; { "hit": bool, "normal": Vector3, "distance": float }
func step_down(pos: Vector3, crouched: bool) -> Vector3          # conditional snap down up to step_height
func can_stand(pos: Vector3) -> bool
func find_walls(pos: Vector3, crouched: bool, radius: float) -> Array[Dictionary]   # [{ "normal": Vector3, "point": Vector3, "convex": bool }]
func find_ledge(pos: Vector3, forward: Vector3, crouched: bool) -> Dictionary        # { "found": bool, "height": float, "top": Vector3, "depth": float }
func test_motion(from: Vector3, motion: Vector3, crouched: bool) -> Dictionary      # raw body_test_motion wrapper
```

### 7.8 MovementSim (`movement_sim.gd`)

```gdscript
class_name MovementSim
extends RefCounted
var cp: CompiledMoveParams
var mover: KinematicMover
var resimulating: bool = false     # when true, events are still written to state.events but PlayerCharacter must not emit signals

func _init(p_cp: CompiledMoveParams, world: World3D) -> void
func dispose() -> void
func new_state(pos: Vector3, yaw: float) -> MoveState       # GROUND, full stamina, all counters reset
func simulate(state: MoveState, cmd: InputCmd) -> void       # advances exactly one tick; state.tick += 1
func push_external(state: MoveState, op: Dictionary) -> void # queued; applied at step 1 of next simulate
func set_params(p_cp: CompiledMoveParams) -> void
func set_world_features(ziplines: Array[ZiplineRail], ropes: Array[RopeRail]) -> void
```

External ops go through `push_external`. Unknown ops push_warning and are ignored.

| op | payload | effect |
|---|---|---|
| &"impulse" | `velocity: Vector3, mode: &"add"/&"set"` | velocity change, leaves ground if y > 0 |
| &"add_modifier" | `def: ModifierDef, source: StringName` | ModifierStack.add |
| &"remove_modifier" | `id: StringName` | ModifierStack.remove |
| &"lock" | `mask: int, duration: float, source: StringName` | ControlLocks.add |
| &"forced_motion" | `velocity: Vector3, duration: float, gravity: bool, exit_loco: int` | enter FORCED |
| &"teleport" | `position: Vector3, keep_velocity: bool` | set position, re-probe ground, TELEPORTED event |
| &"damage" | `from_hero: bool, is_dot: bool, source: StringName` | sprint reset, damage slow, zipline lockout, knockoff, rope slow, mantle-hit slow |
| &"combat_interaction" | none | resets sprint timer |
| &"refresh_air_actions" | none | resets per-airtime counters |
| &"set_cheats" | `flags: int` | set cheat_flags |

### 7.9 Per-tick order inside `simulate`

1. Clear `state.events`. Compute `pressed = cmd.buttons & ~prev_buttons` and `released`. Set yaw and pitch from cmd; turning is capped by the heavy-melee turn-rate mult while in HEAVY_LUNGE. Apply and clear `pending_ops`, in order.
2. Tick down timers: modifiers, locks, cooldowns, buffers, coyote, zip timers, dash-jump bonus, and wall fatigue recovery (linear to 0 over 1.25 s). Update the sprint timer and ramp.
3. Mask input with `ControlLocks.active_mask`. A locked MOVE zeroes wishdir. A locked JUMP/DASH/CROUCH/MELEE drops those pressed and held bits. A locked TURN keeps the previous yaw.
4. Transitions, highest priority first:
   - FORCED end;
   - parry start, which cancels GROUND_DASH and sets horizontal velocity to 0;
   - zipline attach or detach;
   - mantle start;
   - dash start (ground, air, down);
   - dash-jump;
   - wall jump;
   - jump or air jump;
   - slide enter or exit;
   - crouch enter or exit;
   - GROUND/AIR.
   Each state's transition function lives in `states/`.
5. State physics: friction, accelerate, and the first gravity half-step `vy -= g*dt/2`. States that suspend gravity skip it: GROUND_DASH, AIR_DASH, MANTLE, ZIPLINE, ROPE, and FORCED when gravity is false.
6. Move: `mover.move(state, velocity*dt*frac, crouched)`. `frac` is 1, or the fractional last dash tick. Step-up applies only when grounded at tick start.
7. Categorize: probe the ground and step down if we were grounded and are not moving up faster than 2.54 m/s. Apply the second gravity half-step if still airborne. On landing, emit LANDED, refresh air actions, reset wall fatigue, and enter slide if crouch is held and a slide rule applies.
8. Stamina regen: skip it when cheat INFINITE_STAMINA is on, which also keeps stamina at max.
9. Set `prev_buttons = cmd.buttons`, increment `state_ticks` (reset on change) and `tick`. Emit STATE_CHANGED or STAMINA_CHANGED when those values changed this tick.

### 7.10 State rules (summary of CORE behavior; spec sections in brackets)

- **GROUND / CROUCH** [2, 6]:
  - Source friction: `drop = max(v, stop_speed)*friction*dt` when v > 0.
  - Source accelerate: `add = wish - v·wishdir`, capped at `accel*wish*dt`.
  - wish = effective move speed. In CROUCH it is effective crouch speed.
  - Crouch enters when crouch is held and the slide rules don't apply. It exits when crouch is released and `can_stand`.
- **SLIDE** [13]:
  - Enters on a crouch press or hold while grounded if horizontal speed > 8.89 m/s, or the ground angle is >= 5°, or on a dash end with crouch held (DASH kind), or on landing with crouch held (AIR, or DASH_JUMP if dash-jumped this airtime).
  - Friction: `v *= 1 - f*dt`, with f = 0.1875 while `slide_ticks < onset` and the penalty value after. The penalty is 3.1875, or 0.6875 for DASH_JUMP.
  - Onset comes from the bonus lookup table (section 8).
  - On slopes, add the gravity component along the slope, `g*sin(theta)` in the downhill direction.
  - No wishdir acceleration.
  - Exits when horizontal speed < effective crouch speed (to CROUCH or GROUND), on crouch release, or on a jump (normal ground jump, kind &"slide").
- **AIR** [10, 12]:
  - Source air accelerate: wish capped at `air_wishspeed_cap`, accel `air_accel`, multiplied by `air_accel_high_speed_mult` when horizontal speed > 11.43 m/s and by `(1 + 0.30)` while `dash_jump_bonus_ticks > 0`.
  - Then linear drag: `vh *= 1 - drag*dt`, where `drag = air_drag*(1 + 0.35*actual_slow)`.
  - Air jump sets vy = air_jump_speed.
  - Down dash comes from two crouch presses within 28 ticks while airborne.
- **GROUND_DASH** [8, 9]:
  - Costs 1 stamina.
  - Sets horizontal velocity to `dash_speed*dash_dir`, where dash_dir is the wishdir or, if neutral, the facing direction.
  - Runs `floor(T)` full ticks, then one tick with `frac = T - floor(T)` when that is > 1e-6. T is `ground_dash_ticks_exact`, adjusted by the dash distance scale.
  - The dash-jump check comes after the tick (k = completed ticks). In the window, a jump costs +1 stamina, keeps the horizontal dash velocity, sets vy = `dash_jump_vertical_speed` and starts the air-control bonus. BTN_ABILITY pressed during the window cancels the window for this dash.
  - If crouch was held before the dash started (crouch storage), the dash never becomes a slide.
- **AIR_DASH** [11]: costs 1 stamina. Adds `air_dash_speed*dir` to velocity and zeroes vy. Gravity and drag are suspended for its ticks, using the same fractional last tick.
- **DOWN_DASH** [11]: costs `cost_down_dash`. Sets vy = -down_dash_speed and keeps horizontal velocity.
- **Wall jump** [14]:
  - Available in AIR when `find_walls` returns a wall within `wall_detect_distance` and jump is pressed. It is not a state.
  - The first jump per airtime is free. Later ones cost 0.5.
  - vy = `wall_jump_up_speed*max(min_mult, 1 - wall_fatigue)`. Fatigue then increases by `wall_jump_fatigue_per_jump`.
  - Horizontal velocity is set to the wall normal times a kick speed chosen by the input's dot with the normal: toward < -0.3, neutral, away > 0.3.
  - On a convex corner, use the averaged capsule normal and multiply by `corner_boost_mult`.
- **MANTLE** [15]:
  - Triggered by jump pressed or held, forward input toward a ledge, and `find_ledge` finding one with `h_u` in [32,160] and depth >= 6 u.
  - Duration comes from the band.
  - Position is interpolated with smoothstep from `mantle_from` up to the ledge height, then forward onto the top.
  - All actions are locked. The mantle ends GROUNDED with air actions refreshed.
  - Crouch held on completion enters SLIDE, with speed = `mantle_glide_speed`.
- **ZIPLINE** [16]: attaches when within `zip_attach_radius` of a rail and jump is pressed, if the lockout is 0. The rest:
  - Speed = rail speed × (1 + boost).
  - Attaching resets sprint and refreshes air actions.
  - Crouch detaches, keeping velocity along the line for 2 s with drag suspended. Jump also detaches, adding jump_speed.
  - Damage from a hero while `zip_ride_ticks < 192` knocks the player off. The knockoff zeroes horizontal velocity and adds a STUN lock that starts on landing, via a pending flag.
- **ROPE** [17]: climb at `rope_climb_speed` while jump is held, times (1 - rope slow). Detach with crouch, or jump off.
- **HEAVY_LUNGE** [19]:
  - WINDUP ticks, with move mult 0.
  - LUNGE sets horizontal velocity to facing × (lunge distance / lunge time).
  - RECOVERY, then a self-slow modifier.
  - Can mantle during LUNGE.
  - Airborne heavy adds wall fatigue.
- **FORCED**: velocity = forced_velocity, optional gravity, for forced_ticks. Then it goes to forced_exit_loco, or to GROUND or AIR by probe.

### 7.11 PlayerCharacter (`src/movement/player_character.gd`, scene `scenes/player/player_character.tscn`)

```gdscript
class_name PlayerCharacter
extends CharacterBody3D

signal ticked(tick: int, state: MoveState)
signal state_changed(from_loco: int, to_loco: int)
signal landed(impact_speed: float)
signal jumped(kind: StringName)
signal dashed(kind: StringName)
signal stamina_changed(value: float, max_value: float)
signal dash_jump_window(open: bool)
signal mantled(height_m: float, band: int)
signal movement_event(ev: Dictionary)          # every event, after the typed signal

@export var params: MovementParams             # default: preload("res://data/movement/movement_params.tres")
@export var hero: HeroMovementStats            # default: preload("res://data/movement/heroes/hero_default_b1.tres")
@export var spawn_yaw: float = 0.0
var sim: MovementSim
var state: MoveState                           # read-only for non-CORE code
var sim_paused: bool = false

func set_input_source(src: Object) -> void     # src must implement build_cmd(tick: int) -> InputCmd; null = neutral cmds
func get_render_position() -> Vector3          # interpolated feet position
func get_render_eye_height() -> float          # interpolated between stand/crouch eye heights
func get_eye_position() -> Vector3             # render position + eye height
func get_compiled_params() -> CompiledMoveParams
func set_hero(h: HeroMovementStats) -> void    # recompile, keep state
func teleport(pos: Vector3, keep_velocity: bool = false) -> void
func push_external(op: Dictionary) -> void
func step_ticks(n: int) -> void                # runs n ticks immediately (used while paused)
func debug_set_infinite_stamina(on: bool) -> void
func get_state_name() -> String
```

Behavior:
- `_ready` creates the sim from `CompiledMoveParams.build(params, hero)` and `get_world_3d()`. It collects the `&"zipline"` and `&"climb_rope"` groups into rails.
- `_physics_process` does nothing when paused. Otherwise it runs one `simulate()`, sets `global_position`, resizes the CollisionShape3D for crouch, and emits signals from `state.events`.
- The `Visual` child is `top_level` and is placed at `get_render_position()` in `_process`.
- The scene tree is PlayerCharacter (layer PLAYER, mask 0), then CollisionShape3D (CapsuleShape3D r 0.4064, h 1.8288, centered at y = h/2), then Visual (Node3D with a MeshInstance3D capsule and a small box "nose" at -Z). There is no camera.

### 7.12 World features

- `Zipline extends Path3D`. It has `@export var lane_speed: float = 18.0` and `@export var express: bool = false`, joins group `&"zipline"` in `_ready`, and has `func to_rail(id: int) -> ZiplineRail`.
- `ZiplineRail extends RefCounted`. It has `id: int`, `points: PackedVector3Array` (baked world-space points, 0.25 m spacing), `speed: float`, `closest(pos: Vector3) -> Dictionary {s, point, distance}`, `sample(s: float) -> Vector3`, `tangent(s: float) -> Vector3` and `length() -> float`.
- `ClimbRope extends Node3D`. It has `@export var length: float = 10.0` (the rope hangs from the node origin down −Y), joins group `&"climb_rope"`, and has `func to_rail(id: int) -> RopeRail`.
- `RopeRail` has `id`, `top: Vector3`, `bottom: Vector3` and `closest(pos) -> Dictionary`.

## 8. Data resources

### 8.1 MovementParams (`src/movement/data/movement_params.gd`, instance `data/movement/movement_params.tres`)

All fields are `@export`. Defaults are the frozen spec baseline. Confidence: H = high, M = medium, L = low/guess, the last pending measurement. `func validate() -> PackedStringArray` returns the warnings: accel < friction, array lengths mismatched, non-monotonic mantle bands.

| Field | Type | Default | Unit | Spec § | Conf |
|---|---|---|---|---|---|
| tick_rate | int | 64 | Hz | 1 | M |
| unit_m | float | 0.0254 | m/u | 1 | H |
| capsule_radius | float | 0.4064 | m (16 u) | 20 | L |
| capsule_height_stand | float | 1.8288 | m (72 u) | 20 | L |
| capsule_height_crouch | float | 1.2192 | m (48 u) | 20 | L |
| eye_height_stand | float | 1.6256 | m (64 u) | 20 | L |
| eye_height_crouch | float | 1.0668 | m (42 u) | 20 | L |
| crouch_eye_lerp_time | float | 0.1 | s (visual only) | 6 | L |
| step_height | float | 0.4572 | m (18 u) | impl notes | L |
| ground_probe_distance | float | 0.0508 | m (2 u) | impl notes | L |
| max_floor_angle_deg | float | 45.573 | deg (normal.y >= 0.7) | impl notes | L |
| collision_margin | float | 0.001 | m | impl notes | L |
| max_bumps | int | 4 | count | impl notes | L |
| ground_accel | float | 4.0 | 1/s | 2 (Open Q1) | L |
| ground_friction | float | 4.0 | 1/s | 2 (Open Q1) | L |
| stop_speed | float | 2.54 | m/s (100 u/s) | 2 | L |
| backpedal_mult | float | 1.0 | x | 2 (Open Q2) | M |
| strafe_mult | float | 1.0 | x | 2 (Open Q2) | M |
| firing_speed_mult | float | 0.75 | x | 2 | H |
| sprint_delay | float | 3.0 | s | 3 | M |
| sprint_instant_cap | float | 2.5 | m/s | 3 | H |
| sprint_ramp_rate | float | 0.6 | m/s per s | 3 | H |
| sprint_reset_on_opposing_input | bool | true | - | 3 | M |
| move_bonus_dr_k | float | 12.0 | m/s | 4 | M |
| vent_speed_mult | float | 1.7 | x (sprint excluded) | 4 | M |
| slow_floor_speed | float | 2.0 | m/s | 5 | H |
| slow_air_drag_factor | float | 0.35 | fraction of slow | 5, 12 | H |
| damage_slow_fraction | float | 0.20 | fraction above base | 5 | H |
| damage_slow_duration | float | 1.0 | s | 5 (Open Q16) | L |
| rope_damage_slow | float | 0.40 | fraction | 5, 17 | H |
| rope_damage_slow_time | float | 4.0 | s | 5, 17 | H |
| stamina_epsilon | float | 0.00001 | bars | 7 | - |
| stamina_display_cap | int | 8 | bars | 7 | M |
| cost_ground_dash | float | 1.0 | bars | 7, 8 | H |
| cost_air_dash | float | 1.0 | bars | 7, 11 | H |
| cost_dash_jump_extra | float | 1.0 | bars | 7, 9 | H |
| cost_air_jump | float | 1.0 | bars | 7, 10 | H |
| cost_wall_jump_subsequent | float | 0.5 | bars | 7, 14 | H |
| cost_down_dash | float | 1.0 | bars | 7, 11 | L (conflict 0.5/1) |
| wall_jump_combat_regen_penalty | float | 0.25 | fraction | 7, 14 | M |
| wall_jump_combat_regen_penalty_time | float | 5.0 | s | 7, 14 | M |
| ground_dash_distance | float | 10.0 | m | 8 | H |
| ground_dash_durations | Array[float] | [0.62, 0.68, 0.72] | s per bucket | 8 | H |
| dash_neutral_uses_facing | bool | true | - | 8 | L |
| dash_distance_scale_mode | int | 1 | 0 = duration, 1 = speed | 8 (Open Q6) | L |
| ground_dash_exit_clamp | bool | true | - | 8 (Open Q6) | L |
| dash_jump_window_open | float | 0.3 | s after dash start | 9 | H |
| dash_jump_window_length | float | 0.2 | s | 9 | H |
| dash_jump_vertical_speed | float | 7.493 | m/s (295 u/s) | 9 (Open Q8) | L |
| dash_jump_horizontal_mult | float | 1.0 | x | 9 (Open Q8) | L |
| dash_jump_air_control_bonus | float | 0.30 | fraction | 9 | H |
| dash_jump_air_control_time | float | 0.25 | s | 9 | H |
| jump_speed | float | 7.493 | m/s (295 u/s) | 10 | M |
| gravity | float | 24.562 | m/s^2 (967 u/s^2) | 10 | L |
| air_jump_speed | float | 13.26 | m/s (~522 u/s, measured session 4) | 10 | H |
| air_jump_sets_vertical | bool | true | - | 10 | L |
| air_jumps_per_airtime | int | 1 | count | 10 | H |
| coyote_time | float | 0.0 | s | 10 (Open Q20) | L |
| jump_buffer_time | float | 0.0 | s | 10 (Open Q20) | L |
| action_buffer_time | float | 0.1 | s (dash/melee/parry) | 10 | L |
| air_dash_distance | float | 8.0 | m | 11 | M |
| air_dash_durations | Array[float] | [0.43, 0.47, 0.51] | s per bucket | 11 | H |
| air_dashes_per_airtime | int | 1 | count | 11 | H |
| air_dash_suspends_gravity | bool | true | - | 11 | M |
| down_dash_double_tap_window | float | 0.4375 | s (28 ticks) | 11 | H |
| down_dash_speed | float | 15.0 | m/s | 11 (Open Q7) | L |
| down_dashes_per_airtime | int | 1 | count | 11 | M |
| air_accel | float | 10.0 | 1/s | 12 (Open Q5) | L |
| air_wishspeed_cap | float | 0.762 | m/s (30 u/s) | 12 | L |
| air_strafe_threshold | float | 11.43 | m/s (450 u/s) | 12 | M |
| air_accel_high_speed_mult | float | 0.5 | x above threshold | 12 | L |
| air_drag | float | 0.1 | 1/s (proportional) | 12 (Open Q5) | L |
| slide_entry_speed | float | 8.89 | m/s (350 u/s) | 13 | H |
| slide_slope_min_angle_deg | float | 5.0 | deg | 13 | L |
| slide_friction | float | 0.1875 | 1/s (proportional) | 13 | M |
| slide_penalty_friction | float | 3.1875 | 1/s | 13 | M |
| slide_penalty_friction_dash_jump | float | 0.6875 | 1/s | 13 | M |
| slide_bonus_table | Array[float] | [0.0, 0.35, 0.50, 0.80] | slide bonus fraction | 13 | M |
| slide_onset_table | Array[float] | [0.75, 1.00, 1.25, 1.50] | s (last entry L) | 13 | M |
| slide_onset_table_dash_jump | Array[float] | [1.00, 1.25, 1.50, 1.75] | s (last entry L) | 13 | M |
| wall_detect_distance | float | 0.3048 | m beyond capsule (12 u) | 14 (Open Q12) | L |
| wall_max_normal_y | float | 0.3 | abs(normal.y) | 14 | L |
| wall_jump_up_speed | float | 7.0 | m/s | 14 (Open Q12) | L |
| wall_jump_kick_toward | float | 2.0 | m/s | 14 | L |
| wall_jump_kick_neutral | float | 4.5 | m/s | 14 | L |
| wall_jump_kick_away | float | 6.5 | m/s | 14 | L |
| wall_jump_free_count | int | 1 | count | 14 | H |
| wall_jump_fatigue_per_jump | float | 0.25 | vertical mult loss | 14 | L |
| wall_jump_fatigue_min_mult | float | 0.25 | x | 14 | L |
| wall_jump_fatigue_recovery | float | 1.25 | s | 14 | H |
| corner_boost_mult | float | 0.8 | x (after -20%) | 14 | M |
| mantle_min_height_u | int | 32 | u | 15 | M |
| mantle_band_tops_u | Array[int] | [64, 96, 128, 160] | u | 15 | M |
| mantle_climb_speed | float | 5.476 | m/s (~215.6 u/s, measured session 4) | 15 | H |
| mantle_exit_speed | float | 4.496 | m/s (~177 u/s, kept after; measured session 4) | 15 | H |
| mantle_min_depth | float | 0.1524 | m (6 u) | 15 | M |
| mantle_reach | float | 0.6 | m forward probe | 15 (212 u unresolved) | L |
| mantle_requires_forward | bool | true | - | 15 | M |
| mantle_glide_speed | float | 13.64 | m/s (~537 u/s, measured session 4) | 15 | H |
| mantle_hit_slow_start | float | 0.80 | fraction | 15 | M |
| mantle_hit_slow_end | float | 0.20 | fraction | 15 | M |
| mantle_hit_slow_time | float | 2.0 | s | 15 | M |
| zip_speed_inner | float | 18.0 | m/s | 16 | H |
| zip_speed_outer | float | 21.0 | m/s | 16 | H |
| zip_boost_mult | float | 0.8 | fraction | 16 | H |
| zip_boost_duration | float | 32.0 | s | 16 | H |
| zip_attach_radius | float | 1.0 | m | 16 (Open Q14) | L |
| zip_attach_lockout | float | 3.0 | s | 16 | H |
| zip_knockoff_window | float | 3.0 | s | 16 | H |
| zip_knockoff_stun | float | 2.5 | s | 16 | H |
| zip_exit_momentum_time | float | 2.0 | s | 16 | M |
| rope_climb_speed | float | 4.0 | m/s | 17 | L |
| rope_attach_radius | float | 0.8 | m | 17 | L |
| heavy_windup_time | float | 0.35 | s | 19 (Open Q15) | L |
| heavy_lunge_distance | float | 5.0 | m | 19 | L |
| heavy_lunge_time | float | 0.3 | s | 19 | L |
| heavy_recovery_time | float | 0.2 | s | 19 | L |
| heavy_turn_rate_mult | float | 0.3 | x | 19 | L |
| heavy_cooldown_hit | float | 1.0 | s | 19 | H |
| heavy_cooldown_miss | float | 1.3 | s | 19 | H |
| light_self_slow | float | 0.2 | fraction | 19 | L |
| light_self_slow_time | float | 0.3 | s | 19 | L |
| heavy_self_slow | float | 0.3 | fraction | 19 | L |
| heavy_self_slow_time | float | 0.5 | s | 19 | L |
| parry_duration | float | 1.0 | s | 19 | M |
| parry_move_mult | float | 0.5 | x | 19 | L |
| parry_fail_cooldown | float | 4.5 | s | 19 | M |
| fall_damage_enabled | bool | false | - | 18 | H |

### 8.2 HeroMovementStats (`src/movement/data/hero_movement_stats.gd`)

| Field | Type | Default | Unit | Spec § |
|---|---|---|---|---|
| hero_id | StringName | &"default" | - | - |
| base_move_speed | float | 7.2 | m/s | 2, 4 |
| base_sprint_speed | float | 1.6 | m/s | 3 |
| crouch_speed | float | 4.8 | m/s | 6 |
| stamina_max | float | 3.0 | bars | 7 |
| stamina_cooldown | float | 4.5 | s per bar | 7 |
| dash_bucket | int | 1 | 1..3 | 8, 11 |
| gravity_scale | float | 1.0 | x | 10 |
| spirit_move_coeff | float | 0.0 | m/s per spirit | 4 |

The `.tres` values are authored by hand from the spec tables. `data/reference/*.csv` is never loaded at runtime.

## 9. CAMERA+INPUT contract

- **InputSampler** (`extends Node`):
  - Exports: `mouse_sensitivity: float = 0.0022` (rad per pixel), `invert_y: bool = false`, `heavy_hold_time: float = 0.2`.
  - Methods:
	- `build_cmd(tick: int) -> InputCmd`, which returns `InputCmd.create(...)` and then clears the latches;
	- `get_view_yaw() -> float` and `get_view_pitch() -> float`, which are unquantized for the camera;
	- `set_view(yaw: float, pitch: float) -> void`;
	- `set_mouse_captured(on: bool) -> void`.
  - It reads the Input singleton and InputEventMouseMotion only.
  - Any button press seen since the last `build_cmd` is ORed into held bits for that cmd (the tap latch).
  - It never touches MoveState.
- **CameraRig** (`extends Node3D`, `top_level = true`):
  - Exports: `shoulder_offset: Vector3 = Vector3(0.55, 0.15, 0.0)`, `distance: float = 2.6`, `collision_radius: float = 0.2`, `fov_deg: float = 90.0`.
  - Methods: `set_target(p: PlayerCharacter) -> void`, `set_sampler(s: InputSampler) -> void`, `get_camera() -> Camera3D`, `get_aim_ray() -> Dictionary {origin: Vector3, direction: Vector3}`.
  - Each `_process`, the pivot is `p.get_eye_position()`. Rotation comes from the sampler yaw and pitch. The camera is pulled in by `PhysicsDirectSpaceState3D.cast_motion` with a sphere, mask WORLD, excluding the player RID.
- **Crosshair** (`extends Control`):
  - Methods: `bind_player(p: PlayerCharacter) -> void`.
  - It draws a center dot and stamina pips (full, partial, empty).
  - The pips flash light blue while the `dash_jump_window(open)` signal is open (spec section 9 UI cue).
- **LocalController** (`extends Node`):
  - Exports: `player_path: NodePath`.
  - In `_ready` it calls `player.set_input_source($InputSampler)`, `$CameraRig.set_target(player)`, `$CameraRig.set_sampler($InputSampler)` and `$UI/Crosshair.bind_player(player)`. It then makes the camera current.
- Scene `scenes/player/local_controller.tscn`: LocalController with children InputSampler, CameraRig > Camera3D, and UI (CanvasLayer) > Crosshair.

## 10. DEBUG contract

- **MovementDebugOverlay** (`extends CanvasLayer`, scene `scenes/debug/movement_debug_overlay.tscn`). Exports `player_path: NodePath`.
  - Readout: loco, phase and state_ticks; horizontal speed in m/s and u/s; vertical speed; the velocity vector; stamina (float and bars); regen progress; per-airtime counters; sprint state and bonus; active modifiers with remaining time; the lock mask; grounded and floor angle; tick; and `Engine.time_scale`.
  - Toggles (actions from section 5):
	- F1 shows or hides the overlay.
	- F2 cycles timescale 1, 0.5, 0.25, 0.1 through `Engine.time_scale`.
	- F3 toggles infinite stamina via `player.debug_set_infinite_stamina(bool)`.
	- F4 teleports to the next Marker3D in group `&"teleport_points"`, sorted by node name. F8 teleports to the first one.
	- F5 toggles `player.sim_paused`. F6 calls `player.step_ticks(1)` while paused.
	- F7 starts or stops the MeasurementRecorder on the selected recipe. An OptionButton selects R1 to R4.
  - It uses the `ticked(tick, state)` signal only and never mutates state except through the public PlayerCharacter methods above.
- **SpeedGraph** (`extends Control`):
  - Methods: `push_sample(tick: int, h_speed: float, v_speed: float, loco: int) -> void`, `clear() -> void`.
  - Exports: `window_seconds: float = 5.0`, `max_speed: float = 25.0`.
  - It draws horizontal speed, with vertical speed as a second line. Loco changes are vertical ticks, and there are horizontal guide lines at 2.0, 4.8, 8.89 and 11.43 m/s.
- **MeasurementRecorder** (`extends Node`):
  - `const CSV_HEADER := "measurement_id,recipe,date,game_build,patch_date,context,cheats_used,hero,items,quantity,trial,value,units,distance_m,conditions,method,fps,frame_start,frame_end,evidence_ref,measured_by,source_type,confidence,notes"`.
  - Methods:
	- `start(recipe: StringName, player: PlayerCharacter) -> void`;
	- `stop() -> Array[Dictionary]`, which returns and writes the rows;
	- `get_output_path() -> String`, which is `user://measurements/sim_predictions.csv` and appends, writing the header if the file is new.
  - Rows use `source_type = sim-prediction`, `method = sim-trace`, `fps = 64`, `game_build = sim`, `measured_by = sim` and `confidence = high`.
  - The quantity names come from the protocol:
	- R1: move_speed_forward, move_speed_back, move_speed_strafe, sprint_speed, accel_time_to_max (time to 95%).
	- R2: ground_dash_distance, ground_dash_duration, air_dash_distance, air_dash_duration, stamina_regen_time.
	- R3: slide_entry_speed, slide_speed_t0.5, slide_speed_t1.0, slide_distance, slide_duration.
	- R4: jump_apex_height, jump_airtime, mantle_max_height.
  - The recorder observes what the player does. It does not script inputs. The detection rules follow `specs/_measurement_protocol.md`, for example dash start and end from DASHED/STATE_CHANGED events, and apex as the maximum y between JUMPED and LANDED.

## 11. ARENA contract

- **ArenaBuilder** (`extends RefCounted`, all static; every body is a StaticBody3D on layer WORLD with a BoxShape3D or ConvexPolygonShape3D):
  - `build(root: Node3D, layout: StringName = &"full") -> Dictionary` returns `{ "spawn": Vector3, "markers": Dictionary }`. The markers dictionary maps names to Vector3 values.
  - `add_floor(root: Node3D, size: Vector2 = Vector2(200, 200)) -> StaticBody3D`
  - `add_box(root: Node3D, center: Vector3, size: Vector3, name: String = "") -> StaticBody3D`
  - `add_ramp(root: Node3D, base_center: Vector3, angle_deg: float, length: float, width: float, yaw: float = 0.0) -> StaticBody3D`
  - `add_stairs(root: Node3D, origin: Vector3, step_height: float, step_depth: float, count: int, width: float) -> Node3D`
  - `add_ledge(root: Node3D, front_center: Vector3, height_u: int, depth: float = 2.0, width: float = 3.0) -> StaticBody3D`
  - `add_wall(root: Node3D, center: Vector3, size: Vector3) -> StaticBody3D`
  - `add_zipline(root: Node3D, points: PackedVector3Array, lane_speed: float) -> Zipline`
  - `add_rope(root: Node3D, top: Vector3, length: float) -> ClimbRope`
  - `add_marker(root: Node3D, name: String, pos: Vector3) -> Marker3D`, which also joins group `&"teleport_points"`
- The `&"full"` layout places everything at fixed coordinates. Markers are named `NN_name` so they sort in order.
  - 01_spawn (0, 0, 0).
  - 02_sprint_lane: a lane from z = 0 to z = -60. Floor markers every 1 m, and Label3D distance labels every 5 m.
  - 03_ramps: at x = 20, ramps of 10, 20, 30, 45 and 50 degrees. 45 is walkable and 50 is not.
  - 04_slide_slope: at x = -30, a 20 degree slope 30 m long, 6 m wide.
  - 05_stairs: at x = 40, flights with step heights 8 u, 16 u, 18 u and 20 u. The 20 u flight must block.
  - 06_walls: at x = 60, parallel walls 3 m apart, 12 m tall and 20 m long; a lone tall wall; a 2x2 m pillar for the corner boost.
  - 07_mantle: at x = 80, ledges of 24, 32, 64, 96, 128, 160 and 170 u, each 2 m deep and spaced 4 m apart, plus one 160 u wall with only 4 u depth.
  - 08_zipline: a 60 m rail from (-50, 5, 0) to (-50, 9, -60) at 18 m/s, and a parallel 21 m/s rail at x = -54.
  - 09_rope: a 10 m rope at (-70, 12, 0).
  - 10_jump_gauge: a pole with 0.1 m ticks up to 2 m.
- **MovementArena** (`extends Node3D`, scene `scenes/arena/movement_arena.tscn`) calls `ArenaBuilder.build(self)` in `_ready`. It also adds a WorldEnvironment and a DirectionalLight3D, and applies `meter_grid.gdshader` (world-space triplanar, 1 m lines, bold 5 m lines) to all greybox meshes.
- **Sandbox** (`scenes/main/movement_sandbox.tscn`): MovementArena, PlayerCharacter (instanced at spawn), LocalController (player_path set) and MovementDebugOverlay (player_path set).

## 12. Headless test runner (ARENA)

- The command is `"<godot console exe>" --headless --path "C:\Godot Projects\deadlock_like\deadlock_like" -s res://tests/run_tests.gd`, after one `--import`. The exit code is 0 on pass and 1 on any fail.
- `run_tests.gd extends SceneTree`. In `_initialize()` it starts an async runner:
  - It loads every `res://tests/cases/test_*.gd` (each `extends MoveTestCase`) and calls every method whose name starts with `test_`, awaiting it.
  - It prints `PASS name` or `FAIL name: message`, then a summary, and then calls `quit(code)`.
- `MoveTestCase`:
  - Has `var harness: SimHarness`.
  - Assertions: `assert_near(a: float, b: float, eps: float, msg: String) -> void`, `assert_true(c: bool, msg: String) -> void`, `assert_eq(a, b, msg: String) -> void`, `assert_vec_near(a: Vector3, b: Vector3, eps: float, msg: String) -> void`.
  - Hooks: `before_each() -> void`, `after_each() -> void`, which frees the harness.
- `SimHarness`:
  - `static func create(tree: SceneTree, layout: StringName = &"flat", params: MovementParams = null, hero: HeroMovementStats = null) -> SimHarness`. Null means `.new()` defaults.
	- It adds a root Node3D to `tree.root` and builds `ArenaBuilder` geometry (`&"flat"` = floor only, `&"full"` = everything, `&"none"` = no geometry).
	- It must be followed by `await harness.ready()`, which awaits `tree.physics_frame` twice so the space contains the new bodies.
  - `var sim: MovementSim`, `var state: MoveState`, `var trace: Array[Dictionary]`. Each trace entry is `{tick, pos, vel, loco, stamina, events}`.
  - `func run(ticks: int, cmd_fn: Callable) -> void`. `cmd_fn(tick: int) -> InputCmd` is called synchronously for each tick, then `sim.simulate(state, cmd)` runs.
  - `func free_all() -> void`.
- Rules:
  - Tests never use the Input singleton, never instance PlayerCharacter, LocalController or DEBUG scenes, and never depend on frame time.
  - The sim loop runs synchronously between physics frames. The M0 spike confirms that `body_test_motion` against freshly built static bodies is valid there, on both engines.
- `tools/test_parity.ps1` (CORE) runs the suite twice. The second run writes a temporary `override.cfg` with `physics/3d/physics_engine="GodotPhysics3D"`, then deletes it.

## 13. Required tests (numbers verified; tolerances in brackets)

Common setup: `MovementParams.new()`, and a hero from `HeroMovementStats.new()` (base 7.2, sprint 1.6, crouch 4.8, bucket 1). The sprint timer is held off by a `combat_interaction` op each tick unless the test says otherwise. Flat floor. "Tick n" means the value after the n-th `simulate()` since the scenario began.

### 13.1 Pure numeric (flat floor)

| ID | Scenario | Expected |
|---|---|---|
| T01 | `MoveUnits.ticks` | ticks(0.62) = 40, ticks(0.3) = 20, ticks(0.75) = 48, ticks(1.0) = 64, ticks(0.4375) = 28, ticks(0.2) = 13, ticks(0.3) = 20, ticks(0.4) = 26, ticks(0.5) = 32; hu(350) = 8.89 [exact / 1e-9] |
| T02 | From rest, hold W (w = 7.2) | Speed after ticks 1/2/3 = 0.45 / 0.74125 / 1.0325 [1e-5]; first tick with speed >= 6.84 (95%) is 48; after 400 ticks, abs(v - 7.2) < 1e-4 |
| T03 | At 7.2 steady, release W | Speed is 0 first at tick 33; distance travelled 1.38984 m [1e-4] |
| T04 | Standing jump | y(19) = 1.14211, y(20) = 1.14226 [1e-4]; apex at tick 20; grounded again on tick 39 (y(39) = +0.00568 is within the 0.0508 m probe), LANDED event on tick 39 |
| T05 | Ground dash from rest, buckets 1/2/3 | Horizontal speed 16.129 / 14.706 / 13.889 [1e-3]; ticks in GROUND_DASH 40 / 44 / 47; displacement 10.000 m [1e-3]; stamina 3 → 2 |
| T06 | Dash-jump window (B1) | Jump pressed after k completed ticks: k = 19 no dash-jump, k = 20 yes, k = 31 yes, k = 32 no; on success stamina 3 → 1, DASH_JUMP_WINDOW open event at k = 20, close at k = 32; BTN_ABILITY at k = 22 then jump at k = 24 gives no dash-jump |
| T07 | Dash then crouch held → slide (buckets 1/2/3) | Speed at slide tick 48 = 14.010 / 12.774 / 12.064 [1e-3]; then 21 / 20 / 19 penalty ticks (f = 3.1875) until speed < 4.8 → exit to CROUCH at slide tick 69 / 68 / 67 |
| T08 | State set to SLIDE, kind DASH_JUMP, 16.129 m/s | Speed at slide tick 64 = 13.368 [1e-3]; then 95 ticks at f = 0.6875 until < 4.8 |
| T09 | Air dash from hover (vy = 0, gravity_scale 0 hero), buckets 1/2/3 | Added horizontal speed 18.605 / 17.021 / 15.686 [1e-3]; 28 / 31 / 33 dash ticks; displacement 8.000 m [1e-3] |
| T10 | Air drag, hero gravity_scale 0, 10 m/s horizontal, no input | After 64 ticks, 9.0477 [1e-4]; with a 50% SLOW modifier (drag 0.1175), 8.8904 [1e-4] |
| T11 | Stamina recovery | Spend 1 at full (3 → 2): bar full again at tick 288 (4.5 s); with STAMINA_RECOVERY 0.12, at tick 258 (257.14 → 258) |
| T12 | DR | MOVE_BONUS +2 → bonus 2.0; +2, +2, +3 → 5.75 [1e-6] |
| T13 | Slows | Speed 8.2 (hero base 8.2, no sprint), SLOW 0.3 and 0.2, SLOW_RESIST 0.25 → 6.154 [1e-3]; SLOW 0.99 → speed >= 2.0 |
| T14 | Damage slow | Sprinting at 8.8 (7.2 + 1.6) + damage op → 8.48 [1e-6] |
| T15 | Vent | VENT active, sprinting → (7.2 x 1.7) + 1.6 = 13.84 [1e-6] |
| T16 | Sprint ramp, hero sprint 4.0 | Sprint activates on tick 192 of no interaction with +2.5; reaches +4.0 exactly 160 ticks (2.5 s) later; crouch resets to 0 |
| T17 | Down-dash double tap | Airborne, crouch presses 28 ticks apart → DOWN_DASH; 29 apart → none |
| T18 | Air jump | 1 per airtime, costs 1, vy set to air_jump_speed; second air jump refused; refreshed after landing |
| T19 | Locks and parry | STUN lock blocks jump, dash and move (velocity decays by friction only); BTN_PARRY during GROUND_DASH → loco GROUND, horizontal speed 0 on that tick |
| T20 | Crouch | Crouch-walk steady speed 4.8 [1e-4]; firing does not change it; slide not entered at 7.2 on flat; slide entered at 9.0 |

### 13.2 Collision (geometry built with ArenaBuilder)

| ID | Scenario | Expected |
|---|---|---|
| T21 | Slope slide on 20° ramp from rest, crouch held | Speed after 48 ticks = 5.868 [0.01] |
| T22 | Stairs | 8, 16 and 18 u steps climbed while walking with no loss of grounded; 20 u step blocks |
| T23 | Wall slide | Walking at 7.2 into a wall at 45° keeps tangential speed 7.2·cos45 = 5.091 [0.01] and never penetrates |
| T24 | Ramps | 45° ramp walkable (grounded); 50° ramp not grounded, slides down |
| T25 | Mantle bands | Ledges 32/64/96/128/160 u → MANTLE ticks 13/20/26/32/32, ends grounded on top, air actions refreshed; 24 u → no mantle (stepped or jumped); 170 u → no mantle; 4 u depth → no mantle; mantle with crouch held → SLIDE |
| T26 | Wall jump | First free, second costs 0.5; second vertical speed < first (fatigue); fatigue 0 after landing |
| T27 | Zipline | Attach within radius: speed 18.0 along rail [1e-3], air counters refreshed, sprint reset; crouch detach keeps rail velocity for 128 ticks without drag |
| T28 | Rope | Holding jump climbs at 4.0 m/s [1e-3]; with ROPE_SLOW 0.4 → 2.4 |

### 13.3 Contract tests

| ID | Scenario | Expected |
|---|---|---|
| T29 | Determinism | A scripted 600-tick input sequence mixing walking, jump, dash, dash-jump, slide and air dash, run twice → identical `checksum()` every tick. At tick 300, `duplicate_state()` then resim 300 ticks with `resimulating = true` → identical final checksum |
| T30 | Serialization | `InputCmd.from_bytes(to_bytes())` equals the original, 1000 random cmds; `MoveState.from_dict(to_dict())` `equals()` the original after the T29 run |
| T31 | Conformance | `load("res://data/movement/movement_params.tres")` has H-confidence fields equal to the `.new()` defaults (dash durations, costs, slide frictions, zip speeds, sprint values, firing mult, slow floor); `validate()` returns no warnings |
| T32 | No Input | Scan `res://src/movement/**` and `res://tests/**` for the regex `\bInput\.` → zero matches |
| T33 | Parity | `tools/test_parity.ps1` runs T02–T05 and T21–T25 on Jolt and GodotPhysics3D; both pass |

## 14. Milestones (each ends with the full suite green)

1. **M0, spike plus skeletons.** CORE owns this.
   - All CORE public files as skeletons with exact signatures. project.godot and the input map.
   - Proof that `body_test_motion` works from a SceneTree script after `await physics_frame`, on both engines.
   - ARENA ships `run_tests.gd`, SimHarness, ArenaBuilder with `&"flat"`, and T01.
   - CAMERA+INPUT and DEBUG start against the skeletons.
2. **M1:** GROUND, CROUCH, AIR, jump and collision. T02–T04, T20, T22–T24, T29, T30, T32.
3. **M2:** stamina, dashes, dash-jump, slide, modifiers and locks. T05–T19, T21, T31.
4. **M3:** wall jump and mantle. T25 and T26.
5. **M4:** zipline, rope, heavy lunge and FORCED. T27, T28, T33.
6. **Later (not in this plan):** HistoryRing, Reconciler, transport, and the MovementHook implementation.

## 15. Rules for all tracks

- Clean-room:
  - no GPL code, and no code ported from Quake or HL SDK derivatives;
  - no Valve code or assets;
  - MIT/CC0 sources may inform the design, but nothing is copied.
- All tunables live in MovementParams, HeroMovementStats or ModifierDef. No magic numbers in states except math constants.
- `data/reference*` and `data/measurements*` are never loaded by game code or tests. MeasurementRecorder writes to `user://` only.
- Changes to a public contract in sections 6–12 require a revision of this document. Requests go into the list below.

## 16. Contract change requests

(empty)
