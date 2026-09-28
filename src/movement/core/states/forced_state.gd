extends RefCounted
## FORCED motion from the &"forced_motion" op (design §7.8, §7.10).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const L := MoveState.Loco


static func enter(sim: MovementSim, s: MoveState, op: Dictionary) -> void:
	if s.loco == L.SLIDE:
		sim.emit(s, MoveEvents.SLIDE_END)
	if s.dash_jump_window_open:
		s.dash_jump_window_open = false
		sim.emit(s, MoveEvents.DASH_JUMP_WINDOW, {"open": false})
	s.forced_velocity = op.get("velocity", Vector3.ZERO)
	s.forced_ticks = MoveUnits.ticks(float(op.get("duration", 0.0)))
	s.forced_gravity = bool(op.get("gravity", false))
	s.forced_exit_loco = int(op.get("exit_loco", -1))
	s.zip_rail_id = -1
	s.rope_id = -1
	s.loco = L.FORCED
	s.velocity = s.forced_velocity
	if s.forced_velocity.y > 0.0:
		s.grounded = false
		s.ground_normal = Vector3.UP


static func finish(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	s.forced_ticks = 0
	var exit := s.forced_exit_loco
	s.forced_exit_loco = -1
	if exit == L.GROUND or exit == L.CROUCH or exit == L.SLIDE:
		s.loco = exit if s.grounded else L.AIR
	elif exit == L.AIR:
		s.loco = L.AIR
	else:
		sim.settle_loco(s)
	if s.loco == L.SLIDE:
		s.crouched = true
		s.slide_ticks = 0
		s.slide_penalty_ticks = 0


static func physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var fv := s.forced_velocity
	var vy := s.velocity.y if s.forced_gravity else fv.y
	s.velocity = Vector3(fv.x, vy, fv.z)
	if s.forced_gravity and not s.grounded:
		sim.gravity_half(s, ctx)
	s.forced_ticks -= 1
