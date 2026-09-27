class_name PlayerCharacter
extends CharacterBody3D
## Thin scene wrapper around MovementSim (design §7.11). The sim owns all movement; this node
## feeds it InputCmds, mirrors the state into the scene and re-emits events as signals.
## Never reads the Input singleton (T32).

signal ticked(tick: int, state: MoveState)
signal state_changed(from_loco: int, to_loco: int)
signal landed(impact_speed: float)
signal jumped(kind: StringName)
signal dashed(kind: StringName)
signal stamina_changed(value: float, max_value: float)
signal dash_jump_window(open: bool)
signal mantled(height_m: float, band: int)
signal movement_event(ev: Dictionary)          # every event, after the typed signal

@export var params: MovementParams = preload("res://data/movement/movement_params.tres")
@export var hero: HeroMovementStats = preload("res://data/movement/heroes/hero_default_b1.tres")
@export var spawn_yaw: float = 0.0

var sim: MovementSim
var state: MoveState                           # read-only for non-CORE code
var sim_paused: bool = false

var _cp: CompiledMoveParams
var _input_source: Object = null
var _prev_pos: Vector3 = Vector3.ZERO
var _cur_pos: Vector3 = Vector3.ZERO
var _prev_eye: float = 0.0
var _cur_eye: float = 0.0
var _shape_crouched: bool = false
var _prev_yaw: float = 0.0
var _cur_yaw: float = 0.0
## True when the last sim tick teleported (render interpolation snapped); camera code may use it
## to reset its own smoothing (e.g. the boom length).
var snapped_this_tick: bool = false

@onready var _collision: CollisionShape3D = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
@onready var _visual: Node3D = get_node_or_null(^"Visual") as Node3D


func _ready() -> void:
	if params == null:
		params = MovementParams.new()
	if hero == null:
		hero = HeroMovementStats.new()
	_cp = CompiledMoveParams.build(params, hero)
	sim = MovementSim.new(_cp, get_world_3d())
	_collect_world_features()
	state = sim.new_state(global_position, spawn_yaw)
	_prev_pos = state.position
	_cur_pos = state.position
	_cur_eye = params.eye_height_stand
	_prev_eye = _cur_eye
	_prev_yaw = state.yaw
	_cur_yaw = state.yaw
	if _collision != null and _collision.shape is CapsuleShape3D:
		# unique shape so crouch resizing never touches a shared resource
		_collision.shape = _collision.shape.duplicate()
	_apply_collision_shape()
	if _visual != null:
		_visual.top_level = true
		_visual.global_position = state.position
		_visual.rotation = Vector3(0.0, state.yaw, 0.0)


func _exit_tree() -> void:
	if sim != null:
		sim.dispose()


func _collect_world_features() -> void:
	var zips: Array[ZiplineRail] = []
	var ropes: Array[RopeRail] = []
	var i := 0
	for n in get_tree().get_nodes_in_group(&"zipline"):
		if n is Zipline:
			zips.append((n as Zipline).to_rail(i))
			i += 1
	var j := 0
	for n in get_tree().get_nodes_in_group(&"climb_rope"):
		if n is ClimbRope:
			ropes.append((n as ClimbRope).to_rail(j))
			j += 1
	sim.set_world_features(zips, ropes)


func _physics_process(_delta: float) -> void:
	if sim_paused or sim == null:
		return
	_tick_once()


func _process(_delta: float) -> void:
	if _visual != null and state != null:
		_visual.global_position = get_render_position()
		_visual.rotation = Vector3(0.0, get_render_yaw(), 0.0)


func _tick_once() -> void:
	var cmd: InputCmd = null
	if _input_source != null and _input_source.has_method(&"build_cmd"):
		cmd = _input_source.call(&"build_cmd", state.tick + 1) as InputCmd
	if cmd == null:
		cmd = InputCmd.create(state.tick + 1, 0, 0, 0, state.yaw, state.pitch)
	_prev_pos = state.position
	_prev_eye = _cur_eye
	_prev_yaw = state.yaw
	sim.simulate(state, cmd)
	_cur_pos = state.position
	_cur_yaw = state.yaw
	# spec: movement.md §6 visual-only eye lerp between stand and crouch heights
	var target_eye := params.eye_height_crouch if state.crouched else params.eye_height_stand
	var rate := absf(params.eye_height_stand - params.eye_height_crouch) / maxf(0.001, params.crouch_eye_lerp_time) * MoveUnits.DT
	_cur_eye = move_toward(_cur_eye, target_eye, rate)
	# A teleport must not be interpolated (no streak from the old spot to the new one).
	snapped_this_tick = false
	for ev in state.events:
		if StringName((ev as Dictionary).get("type", &"")) == MoveEvents.TELEPORTED:
			snapped_this_tick = true
			break
	if snapped_this_tick:
		_prev_pos = _cur_pos
		_prev_eye = _cur_eye
		_prev_yaw = _cur_yaw
	global_position = state.position
	_apply_collision_shape()
	_emit_events()


func _apply_collision_shape() -> void:
	if _collision == null or not (_collision.shape is CapsuleShape3D):
		return
	if state != null and state.crouched == _shape_crouched and _collision.position.y > 0.0:
		return
	_shape_crouched = state.crouched if state != null else false
	var cap := _collision.shape as CapsuleShape3D
	var h := params.capsule_height_crouch if _shape_crouched else params.capsule_height_stand
	cap.radius = params.capsule_radius
	cap.height = h
	_collision.position = Vector3(0.0, h * 0.5, 0.0)


func _emit_events() -> void:
	if sim.resimulating:
		return
	for ev in state.events:
		var p: Dictionary = ev
		match StringName(ev.get("type", &"")):
			MoveEvents.STATE_CHANGED:
				state_changed.emit(int(p.get("from", 0)), int(p.get("to", 0)))
			MoveEvents.LANDED:
				landed.emit(float(p.get("impact_speed", 0.0)))
			MoveEvents.JUMPED:
				jumped.emit(StringName(p.get("kind", &"")))
			MoveEvents.DASHED:
				dashed.emit(StringName(p.get("kind", &"")))
			MoveEvents.STAMINA_CHANGED:
				stamina_changed.emit(float(p.get("value", 0.0)), float(p.get("max", 0.0)))
			MoveEvents.DASH_JUMP_WINDOW:
				dash_jump_window.emit(bool(p.get("open", false)))
			MoveEvents.MANTLE_START:
				mantled.emit(float(p.get("height_m", 0.0)), int(p.get("band", -1)))
		movement_event.emit(ev)
	ticked.emit(state.tick, state)


# --- public API (design §7.11) ------------------------------------------------------

## src must implement build_cmd(tick: int) -> InputCmd; null = neutral cmds.
func set_input_source(src: Object) -> void:
	_input_source = src


## Interpolated feet position between the last two sim ticks.
func get_render_position() -> Vector3:
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	if sim_paused:
		f = 1.0
	return _prev_pos.lerp(_cur_pos, f)


## Interpolated visual yaw between the last two sim ticks.
func get_render_yaw() -> float:
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	if sim_paused:
		f = 1.0
	return lerp_angle(_prev_yaw, _cur_yaw, f)


func get_render_eye_height() -> float:
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	if sim_paused:
		f = 1.0
	return lerpf(_prev_eye, _cur_eye, f)


func get_eye_position() -> Vector3:
	return get_render_position() + Vector3.UP * get_render_eye_height()


func get_compiled_params() -> CompiledMoveParams:
	return _cp


## Recompile with a new hero; the current state is kept.
func set_hero(h: HeroMovementStats) -> void:
	if h == null:
		return
	hero = h
	_cp = CompiledMoveParams.build(params, hero)
	if sim != null:
		sim.set_params(_cp)


func teleport(pos: Vector3, keep_velocity: bool = false) -> void:
	push_external({"op": &"teleport", "position": pos, "keep_velocity": keep_velocity})
	if sim_paused:
		# apply now so paused tools see the new position without stepping
		state.position = pos
		if not keep_velocity:
			state.velocity = Vector3.ZERO
		_prev_pos = pos
		_cur_pos = pos
		global_position = pos


func push_external(op: Dictionary) -> void:
	if sim != null and state != null:
		sim.push_external(state, op)


## Runs n ticks immediately (used while paused).
func step_ticks(n: int) -> void:
	if sim == null:
		return
	for i in maxi(0, n):
		_tick_once()


func debug_set_infinite_stamina(on: bool) -> void:
	var flags := state.cheat_flags
	if on:
		flags |= MoveState.CHEAT_INFINITE_STAMINA
	else:
		flags &= ~MoveState.CHEAT_INFINITE_STAMINA
	push_external({"op": &"set_cheats", "flags": flags})


func get_state_name() -> String:
	return state.loco_name() if state != null else "?"
