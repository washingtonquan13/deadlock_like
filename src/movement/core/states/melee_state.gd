extends RefCounted
## Parry, light melee and HEAVY_LUNGE (design §7.10, spec: movement.md §19).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const GroundState = preload("res://src/movement/core/states/ground_state.gd")
const AirState = preload("res://src/movement/core/states/air_state.gd")
const MantleState = preload("res://src/movement/core/states/mantle_state.gd")
const DashState = preload("res://src/movement/core/states/dash_state.gd")
const L := MoveState.Loco
const LP := MoveState.LungePhase


static func _melee_allowed(s: MoveState) -> bool:
	return s.loco == L.GROUND or s.loco == L.CROUCH or s.loco == L.SLIDE or s.loco == L.AIR or s.loco == L.DOWN_DASH or s.loco == L.GROUND_DASH


## spec: movement.md §19 parry: 1 s, allowed while ground-dashing; cancels the dash and its momentum.
static func try_parry(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	if not ctx.is_pressed(InputCmd.BTN_PARRY):
		return
	if s.parry_ticks > 0 or s.parry_cooldown_ticks > 0:
		return
	if not _melee_allowed(s):
		return
	s.parry_ticks = sim.cp.parry_ticks
	ModifierStack.add_raw(s, &"parry", ModifierDef.Stat.MOVE_MULT, p.parry_move_mult, p.parry_duration, &"parry")
	if s.loco == L.GROUND_DASH:
		DashState.close_window(sim, s)
		s.loco = L.GROUND if s.grounded else L.AIR
		if s.crouched and s.grounded:
			s.loco = L.CROUCH
		s.velocity.x = 0.0
		s.velocity.z = 0.0
		ctx.zero_h_after_move = true
	sim.emit(s, MoveEvents.PARRY_START)


## spec: movement.md §19 light melee: brief self-slow; airborne melee adds wall-jump fatigue.
static func try_light(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	if not ctx.is_pressed(InputCmd.BTN_MELEE_LIGHT) or not _melee_allowed(s) or s.loco == L.GROUND_DASH:
		return
	ModifierStack.add_raw(s, &"light_melee_slow", ModifierDef.Stat.SLOW, p.light_self_slow, p.light_self_slow_time, &"melee")
	if not s.grounded:
		sim.add_wall_fatigue(s, p.wall_jump_fatigue_per_jump)


## spec: movement.md §19 heavy melee start. Returns true when started.
static func try_heavy(sim: MovementSim, s: MoveState, ctx: Ctx) -> bool:
	var p := sim.cp.params
	if not ctx.is_pressed(InputCmd.BTN_MELEE_HEAVY) or s.heavy_cooldown_ticks > 0:
		return false
	if not _melee_allowed(s) or s.loco == L.GROUND_DASH:
		return false
	if not s.grounded:
		sim.add_wall_fatigue(s, p.wall_jump_fatigue_per_jump)
	if s.loco == L.SLIDE:
		sim.emit(s, MoveEvents.SLIDE_END)
	sim.try_uncrouch(s)
	s.loco = L.HEAVY_LUNGE
	s.phase = LP.WINDUP
	s.phase_ticks = 0
	return true


static func transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var cp := sim.cp
	match s.phase:
		LP.WINDUP:
			if s.phase_ticks >= cp.heavy_windup_ticks:
				s.phase = LP.LUNGE
				s.phase_ticks = 0
		LP.LUNGE:
			# spec: movement.md §19 heavy melee can mantle ledges
			if MantleState.try_start(sim, s, ctx, true):
				s.heavy_cooldown_ticks = MoveUnits.ticks(cp.params.heavy_cooldown_miss)
				return
			if s.phase_ticks >= cp.heavy_lunge_ticks:
				s.phase = LP.RECOVERY
				s.phase_ticks = 0
				# G12 (fixes K28): no clamp to walk speed; recovery zeroes all velocity (see physics)
				s.velocity = Vector3.ZERO
		LP.RECOVERY:
			if s.phase_ticks >= cp.heavy_recovery_ticks:
				_finish(sim, s)


static func _finish(sim: MovementSim, s: MoveState) -> void:
	var p := sim.cp.params
	# spec: movement.md §19 self-slow after the heavy; cooldown 1.3 s (miss; hits are not simulated)
	ModifierStack.add_raw(s, &"heavy_melee_slow", ModifierDef.Stat.SLOW, p.heavy_self_slow, p.heavy_self_slow_time, &"melee")
	s.heavy_cooldown_ticks = MoveUnits.ticks(p.heavy_cooldown_miss)
	s.phase = 0
	s.phase_ticks = 0
	s.loco = L.GROUND if s.grounded else L.AIR


static func physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	if s.phase == LP.LUNGE:
		# G10 (fixes K29): lunge 750 u/s on the ground, 797 u/s in the air, in the facing direction,
		# for up to heavy_lunge_time. PROVISIONAL (G10): constant-speed profile pending H1.
		# Unresolved Q5 conflict: these speeds over heavy_lunge_time give ~11.4 m (ground) / ~12.1 m (air),
		# against ~5 m of lunge distance in other sources. No source gives the speed curve, so none is
		# invented here; the distance mismatch stays open until clip H1.
		var f := sim.facing(s)
		var sp := p.heavy_lunge_speed_ground if s.grounded else p.heavy_lunge_speed_air
		s.velocity.x = f.x * sp
		s.velocity.z = f.z * sp
		if s.grounded:
			s.velocity.y = 0.0
	elif s.phase == LP.RECOVERY:
		# G12 (fixes K30): recovery sets velocity to 0 on all axes (no friction, drag or gravity)
		s.velocity = Vector3.ZERO
		s.phase_ticks += 1
		return
	elif s.grounded:
		GroundState.walk_physics(sim, s, ctx, 0.0)
	else:
		AirState.air_physics(sim, s, ctx, false)
	if not s.grounded:
		sim.gravity_half(s, ctx)
	s.phase_ticks += 1
