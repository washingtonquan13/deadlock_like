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
		sim.add_wall_fatigue(s, p.melee_wall_fatigue)


## spec: movement.md §19 heavy melee start. Returns true when started.
static func try_heavy(sim: MovementSim, s: MoveState, ctx: Ctx) -> bool:
	var p := sim.cp.params
	# measured session 11 (HM_C): a heavy held through the cooldown fires as soon as it ends
	if not (ctx.is_pressed(InputCmd.BTN_MELEE_HEAVY) or ctx.is_held(InputCmd.BTN_MELEE_HEAVY)) or s.heavy_cooldown_ticks > 0:
		return false
	if not _melee_allowed(s) or s.loco == L.GROUND_DASH:
		return false
	if not s.grounded:
		sim.add_wall_fatigue(s, p.melee_wall_fatigue)
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
				# measured session 11 (HM_C, HM_C2): the miss cooldown runs from ~0.23 s into the lunge
				s.heavy_cooldown_ticks = MoveUnits.ticks(cp.params.heavy_cooldown_start + cp.params.heavy_cooldown_miss)
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
	# spec: movement.md §19 self-slow after the heavy (0 by default: not seen in session 11; the cooldown is set at the lunge start; hits are not simulated)
	if p.heavy_self_slow > 0.0:
		ModifierStack.add_raw(s, &"heavy_melee_slow", ModifierDef.Stat.SLOW, p.heavy_self_slow, p.heavy_self_slow_time, &"melee")
	s.phase = 0
	s.phase_ticks = 0
	s.loco = L.GROUND if s.grounded else L.AIR


static func physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	var p := sim.cp.params
	if s.phase == LP.LUNGE:
		# G10, measured session 11 (HM_S/HM_W/HM_J): the lunge speed ramps linearly from a start fraction of the peak
		# (ground 0.59, air 0.43) to the peak (750 ground, 797 air) over ~13 (ground) / ~10 (air) ticks, holds it,
		# and stops dead after heavy_lunge_time (227 u on flat ground). Pre-lunge velocity is replaced. On the ground it runs
		# along the yaw; in the air along the aim, pitch included (HM_J: the fall rate grows with the lunge speed, at
		# ~0.25 of it for a 14.7 deg down aim), with no gravity. Landing mid-lunge switches to the ground speed.
		var cp := sim.cp
		var f0 := p.heavy_lunge_start_frac_ground if s.grounded else p.heavy_lunge_start_frac_air
		var ramp := cp.heavy_lunge_ramp_ticks if s.grounded else cp.heavy_lunge_ramp_ticks_air
		var frac := minf(1.0, f0 + (1.0 - f0) * float(s.phase_ticks + 1) / float(ramp))
		if s.grounded:
			var f := sim.facing(s)
			s.velocity = Vector3(f.x, 0.0, f.z) * p.heavy_lunge_speed_ground * frac
		else:
			s.velocity = Basis.from_euler(Vector3(s.pitch, s.yaw, 0.0)) * Vector3.FORWARD * p.heavy_lunge_speed_air * frac
		s.phase_ticks += 1
		return
	elif s.phase == LP.RECOVERY:
		# G12, measured session 11 (HM_R): the lunge ends at zero speed; on the ground the recovery then allows normal
		# accel but caps speed at heavy_recovery_max_speed (~115 u/s). In the air it still holds velocity at 0 on all
		# axes (no friction, drag or gravity; K30, unmeasured).
		if s.grounded:
			GroundState.walk_physics(sim, s, ctx, sim.cp.effective_move_speed(s, ctx.firing))
			sim.clamp_horizontal(s, p.heavy_recovery_max_speed)
		else:
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
