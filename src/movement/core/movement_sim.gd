class_name MovementSim
extends RefCounted
## Pure, deterministic movement simulation (design §7.8 / §7.9).
## simulate() reads only the state, the cmd, compiled params and world collision.
## No Input singleton, no wall-clock time, no randomness.

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const GroundState = preload("res://src/movement/core/states/ground_state.gd")
const AirState = preload("res://src/movement/core/states/air_state.gd")
const DashState = preload("res://src/movement/core/states/dash_state.gd")
const MantleState = preload("res://src/movement/core/states/mantle_state.gd")
const RailState = preload("res://src/movement/core/states/rail_state.gd")
const MeleeState = preload("res://src/movement/core/states/melee_state.gd")
const ForcedState = preload("res://src/movement/core/states/forced_state.gd")

const L := MoveState.Loco
const LEAVE_GROUND_SPEED := 2.54   # impl notes: 100 u/s upward separates from the ground

var cp: CompiledMoveParams
var mover: KinematicMover
var resimulating: bool = false     # when true, events are still written to state.events but PlayerCharacter must not emit signals
var ziplines: Array[ZiplineRail] = []
var ropes: Array[RopeRail] = []


func _init(p_cp: CompiledMoveParams, world: World3D) -> void:
	cp = p_cp if p_cp != null else CompiledMoveParams.build(null, null)
	mover = KinematicMover.new(world, cp.params)


func dispose() -> void:
	if mover != null:
		mover.dispose()


func set_params(p_cp: CompiledMoveParams) -> void:
	if p_cp == null:
		return
	cp = p_cp
	mover.params = cp.params


func set_world_features(p_ziplines: Array[ZiplineRail], p_ropes: Array[RopeRail]) -> void:
	ziplines = p_ziplines
	ropes = p_ropes


func new_state(pos: Vector3, yaw: float) -> MoveState:
	var s := MoveState.new()
	s.position = pos
	s.yaw = InputCmd.quantize_yaw(yaw)
	s.loco = L.GROUND
	s.stamina = cp.stamina_max(s)
	s.stamina_regen_progress = 0.0
	var pr := mover.probe_ground(pos, false)
	s.grounded = pr["hit"] and pr["walkable"]
	s.ground_normal = pr["normal"] if s.grounded else Vector3.UP
	if not s.grounded:
		s.loco = L.AIR
	return s


func push_external(state: MoveState, op: Dictionary) -> void:
	state.pending_ops.append(op)


# ============================================================================
# simulate: design §7.9 per-tick order
# ============================================================================

func simulate(s: MoveState, cmd: InputCmd) -> void:
	var p := cp.params
	var ctx := Ctx.new()
	ctx.cmd = cmd
	ctx.tick_no = s.tick + 1
	ctx.loco_start = s.loco
	ctx.grounded_start = s.grounded
	ctx.stamina_start = s.stamina
	ctx.stamina_max_start = cp.stamina_max(s)
	ctx.prev_yaw = s.yaw

	# --- 1. events, edges, view, pending ops ---------------------------------
	s.events.clear()
	var held := cmd.buttons & InputCmd.BTN_MASK
	ctx.raw_pressed = held & ~s.prev_buttons
	ctx.pressed = ctx.raw_pressed
	ctx.released = s.prev_buttons & ~held
	ctx.held = held
	if s.loco == L.HEAVY_LUNGE:
		# spec: movement.md §19 reduced turn rate during heavy melee
		var d := wrapf(cmd.yaw - s.yaw, -PI, PI)
		s.yaw = InputCmd.quantize_yaw(s.yaw + d * p.heavy_turn_rate_mult)
	else:
		s.yaw = cmd.yaw
	s.pitch = cmd.pitch
	var ops := s.pending_ops.duplicate()
	s.pending_ops.clear()
	for op in ops:
		_apply_op(s, op, ctx)

	# --- 2. timers ----------------------------------------------------------------
	_tick_timers(s)

	# --- 3. lock masking + sprint ------------------------------------------------------
	ctx.mask = ControlLocks.active_mask(s)
	_mask_input(s, ctx)
	_update_sprint(s, ctx)
	# G40: crouch storage (dash or takeoff) lasts until crouch is released, on the ground or in the air
	if not ctx.is_held(InputCmd.BTN_CROUCH):
		s.slide_block_until_crouch_release = false

	# --- 4. transitions -------------------------------------------------------------
	_transitions(s, ctx)
	# spec: movement.md §3 crouching resets sprint; sliding (and an air crouch) keeps it
	if s.loco == L.CROUCH:
		reset_sprint(s, ctx, &"crouch")

	# --- 5. state physics ----------------------------------------------------------
	_physics(s, ctx)

	# --- 6. move ---------------------------------------------------------------------
	if not ctx.skip_move:
		_move(s, ctx)
	if ctx.zero_h_after_move:
		s.velocity.x = 0.0
		s.velocity.z = 0.0
	DashState.post_move(self, s, ctx)

	# --- 7. categorize -------------------------------------------------------------
	_categorize(s, ctx)
	_wall_slide_cap(s)

	# --- 8. stamina regen ------------------------------------------------------------
	_stamina_regen(s)

	# --- 9. bookkeeping ---------------------------------------------------------------
	_iad_end_drag(s)
	_track_contacts(s, ctx)
	s.prev_buttons = cmd.buttons & InputCmd.BTN_MASK
	s.prev_wish = ctx.wish
	s.prev_wish_raw = Basis(Vector3.UP, s.yaw) * Vector3(float(ctx.move_x), 0.0, -float(ctx.move_y))
	if s.loco != ctx.loco_start:
		s.state_ticks = 1
		emit(s, MoveEvents.STATE_CHANGED, {"from": ctx.loco_start, "to": s.loco})
	else:
		s.state_ticks += 1
	if s.grounded:
		s.airborne_ticks = 0
	else:
		s.airborne_ticks += 1
	var mx := cp.stamina_max(s)
	if absf(s.stamina - ctx.stamina_start) > 1e-9 or absf(mx - ctx.stamina_max_start) > 1e-9:
		emit(s, MoveEvents.STAMINA_CHANGED, {"value": s.stamina, "max": mx})
	s.tick += 1


# ============================================================================
# step 1: external ops (design §7.8 table)
# ============================================================================

func _apply_op(s: MoveState, op: Dictionary, ctx: Ctx) -> void:
	var p := cp.params
	var kind: StringName = StringName(op.get("op", op.get("type", &"")))
	match kind:
		&"impulse":
			var v: Vector3 = op.get("velocity", Vector3.ZERO)
			if StringName(op.get("mode", &"add")) == &"set":
				s.velocity = v
			else:
				s.velocity += v
			if s.velocity.y > 0.0 and s.grounded:
				s.grounded = false
				if s.loco == L.GROUND or s.loco == L.CROUCH or s.loco == L.SLIDE:
					if s.loco == L.SLIDE:
						emit(s, MoveEvents.SLIDE_END)
					try_uncrouch(s)
					s.loco = L.AIR
		&"add_modifier":
			var def: ModifierDef = op.get("def", null)
			ModifierStack.add(s, def, StringName(op.get("source", &"")))
		&"remove_modifier":
			ModifierStack.remove(s, StringName(op.get("id", &"")))
		&"lock":
			var mask := int(op.get("mask", 0))
			ControlLocks.add(s, mask, MoveUnits.ticks(float(op.get("duration", 0.0))), StringName(op.get("source", &"")))
			emit(s, MoveEvents.LOCKED, {"mask": mask})
		&"forced_motion":
			ForcedState.enter(self, s, op)
		&"teleport":
			_teleport(s, op.get("position", s.position), bool(op.get("keep_velocity", false)))
		&"damage":
			_apply_damage(s, op, ctx)
		&"combat_interaction":
			# spec: movement.md §3 hero/neutral interaction resets the sprint timer
			reset_sprint(s, ctx, &"combat")
			s.ticks_since_combat = 0   # spec: movement.md §14 "in combat"
		&"refresh_air_actions":
			refresh_air(s)
		&"set_cheats":
			s.cheat_flags = int(op.get("flags", 0))
		_:
			push_warning("MovementSim: unknown external op '%s' ignored" % kind)


func _teleport(s: MoveState, pos: Vector3, keep_velocity: bool) -> void:
	s.position = pos
	if not keep_velocity:
		s.velocity = Vector3.ZERO
	match s.loco:
		L.MANTLE, L.ZIPLINE, L.ROPE, L.GROUND_DASH, L.AIR_DASH, L.DOWN_DASH, L.HEAVY_LUNGE, L.FORCED, L.SLIDE:
			s.zip_rail_id = -1
			s.rope_id = -1
			s.loco = L.GROUND
	var pr := mover.probe_ground(pos, s.crouched)
	s.grounded = pr["hit"] and pr["walkable"]
	s.ground_normal = pr["normal"] if s.grounded else Vector3.UP
	if s.grounded:
		if s.loco == L.AIR:
			s.loco = L.GROUND
		refresh_air(s)
	else:
		if s.loco == L.GROUND or s.loco == L.CROUCH:
			s.loco = L.AIR
	if s.loco != L.CROUCH:
		s.crouched = false
	emit(s, MoveEvents.TELEPORTED)


func _apply_damage(s: MoveState, op: Dictionary, ctx: Ctx) -> void:
	var p := cp.params
	var from_hero := bool(op.get("from_hero", true))
	var is_dot := bool(op.get("is_dot", false))
	var src := StringName(op.get("source", &"damage"))
	# spec: movement.md §3 taking damage resets sprint (design §7.8 damage op); a payload may opt
	# out with `resets_sprint: false`. spec: movement.md §5 damage slow: 20% of the speed above base.
	s.ticks_since_combat = 0   # spec: movement.md §14 "in combat"
	if bool(op.get("resets_sprint", true)):
		reset_sprint(s, ctx, &"damage")
	ModifierStack.add_raw(s, &"damage_slow", ModifierDef.Stat.DAMAGE_SLOW, p.damage_slow_fraction, p.damage_slow_duration, src)
	if from_hero:
		# spec: movement.md §16 zipline attach lockout after hero/objective damage
		s.zip_attach_lockout_ticks = maxi(s.zip_attach_lockout_ticks, cp.zip_lockout_ticks + 1)
		# spec: movement.md §17 rope climb 40% slower for 4 s
		ModifierStack.add_raw(s, &"rope_damage_slow", ModifierDef.Stat.ROPE_SLOW, p.rope_damage_slow, p.rope_damage_slow_time, src)
		# spec: movement.md §16 knock-off in the first 3 s of riding; DoT never knocks off
		if s.loco == L.ZIPLINE and not is_dot and s.zip_ride_ticks < cp.zip_knockoff_window_ticks:
			RailState.knockoff(self, s)
	# spec: movement.md §15 melee hit while mantling: 80% slow tapering to 20% over 2 s
	if s.loco == L.MANTLE and bool(op.get("melee", false)):
		ModifierStack.add_raw(s, &"mantle_hit_slow", ModifierDef.Stat.SLOW, p.mantle_hit_slow_start, p.mantle_hit_slow_time, src, p.mantle_hit_slow_end)


# ============================================================================
# step 2 / 3
# ============================================================================

func _tick_timers(s: MoveState) -> void:
	ModifierStack.tick_down(s)
	ControlLocks.tick_down(s)
	s.heavy_cooldown_ticks = maxi(0, s.heavy_cooldown_ticks - 1)
	s.parry_ticks = maxi(0, s.parry_ticks - 1)
	s.parry_cooldown_ticks = maxi(0, s.parry_cooldown_ticks - 1)
	s.jump_buffer_ticks = maxi(0, s.jump_buffer_ticks - 1)
	s.action_buffer_ticks = maxi(0, s.action_buffer_ticks - 1)
	if s.action_buffer_ticks == 0:
		s.action_buffer_button = 0
	s.coyote_ticks = maxi(0, s.coyote_ticks - 1)
	s.zip_attach_lockout_ticks = maxi(0, s.zip_attach_lockout_ticks - 1)
	s.zip_exit_momentum_ticks = maxi(0, s.zip_exit_momentum_ticks - 1)
	s.zip_boost_ticks = maxi(0, s.zip_boost_ticks - 1)
	s.dash_jump_bonus_ticks = maxi(0, s.dash_jump_bonus_ticks - 1)
	s.combat_regen_penalty_ticks = maxi(0, s.combat_regen_penalty_ticks - 1)
	s.zip_boost_cooldown_ticks = maxi(0, s.zip_boost_cooldown_ticks - 1)
	# G09: a timed slide-drag penalty (slide_hop_penalty_time >= 0) ends when its ticks run out
	if s.slide_hop_penalty_active and cp.slide_hop_penalty_ticks >= 0:
		s.slide_hop_penalty_ticks = maxi(0, s.slide_hop_penalty_ticks - 1)
		if s.slide_hop_penalty_ticks == 0:
			s.slide_hop_penalty_active = false
	s.ticks_since_combat = mini(s.ticks_since_combat + 1, 1 << 20)
	if (s.cheat_flags & MoveState.CHEAT_NO_COOLDOWNS) != 0:
		s.heavy_cooldown_ticks = 0
		s.parry_cooldown_ticks = 0
		s.zip_attach_lockout_ticks = 0
		s.zip_boost_cooldown_ticks = 0
	# spec: movement.md §14 wall-jump fatigue recovers over 1.25 s; curve (1-t)^k, k data-driven
	if s.wall_fatigue > 0.0:
		s.wall_fatigue_recover_ticks += 1
		var t := clampf(float(s.wall_fatigue_recover_ticks) / float(cp.wall_fatigue_recovery_ticks), 0.0, 1.0)
		var k := maxf(cp.params.wall_jump_fatigue_recovery_exponent, 1e-3)
		s.wall_fatigue = maxf(0.0, s.wall_fatigue_peak * pow(1.0 - t, k))
		if s.wall_fatigue <= 1e-9:
			s.wall_fatigue = 0.0
			s.wall_fatigue_peak = 0.0
			s.wall_fatigue_recover_ticks = 0


func _mask_input(s: MoveState, ctx: Ctx) -> void:
	var m := ctx.mask
	var drop := 0
	if m & ControlLocks.JUMP:
		drop |= InputCmd.BTN_JUMP
	if m & ControlLocks.DASH:
		drop |= InputCmd.BTN_DASH
	if m & ControlLocks.CROUCH:
		drop |= InputCmd.BTN_CROUCH
	if m & ControlLocks.MELEE:
		drop |= InputCmd.BTN_MELEE_LIGHT | InputCmd.BTN_MELEE_HEAVY | InputCmd.BTN_PARRY
	if m & ControlLocks.ZIPLINE:
		drop |= InputCmd.BTN_ZIP_BOOST
	ctx.held &= ~drop
	ctx.pressed &= ~drop
	if m & ControlLocks.TURN:
		s.yaw = ctx.prev_yaw
	if m & ControlLocks.MOVE:
		ctx.move_x = 0
		ctx.move_y = 0
	else:
		ctx.move_x = ctx.cmd.move_x
		ctx.move_y = ctx.cmd.move_y
	ctx.wish = InputCmd.wish_dir_for(ctx.move_x, ctx.move_y, s.yaw)
	ctx.has_move = ctx.wish != Vector3.ZERO
	ctx.firing = ctx.is_held(InputCmd.BTN_FIRE)


## spec: movement.md §3 sprint state machine and ramp.
func _update_sprint(s: MoveState, ctx: Ctx) -> void:
	var p := cp.params
	# Crouching resets only when the result is CROUCH (checked here and again after transitions),
	# so a crouch press that starts a slide keeps sprint (spec: movement.md §3 persists through slides).
	if s.loco == L.CROUCH:
		reset_sprint(s, ctx, &"crouch")
	elif (ctx.mask & (ControlLocks.MOVE | ControlLocks.SPRINT)) != 0:
		reset_sprint(s, ctx, &"cc")
	elif p.sprint_reset_on_opposing_input and (ctx.cmd.buttons & (InputCmd.BTN_OPPOSE_X | InputCmd.BTN_OPPOSE_Y)) != 0:
		# spec: movement.md §3 holding opposing inputs
		reset_sprint(s, ctx, &"opposing")
	elif p.sprint_reset_on_stop and not ctx.has_move and s.horizontal_speed() < p.sprint_stop_speed:
		# spec: movement.md §3 stopping
		reset_sprint(s, ctx, &"stop")
	if not ctx.sprint_reset:
		s.sprint_timer_ticks += 1
	if not ctx.has_move:
		# coasting without input: no bonus this tick; the timer survives until fully stopped
		s.sprint_active = false
		s.sprint_bonus_current = 0.0
		s.sprint_ramp_ticks = 0
		return
	var total := cp.sprint_total(s)
	if not s.sprint_active:
		if s.sprint_timer_ticks >= cp.sprint_delay_ticks:
			s.sprint_active = true
			s.sprint_ramp_ticks = 0
			emit(s, MoveEvents.SPRINT_START)
	else:
		s.sprint_ramp_ticks += 1
	if s.sprint_active:
		# first +2.5 m/s instantly, the rest at 0.6 m/s per second
		var inst := minf(p.sprint_instant_cap, total)
		s.sprint_bonus_current = minf(total, inst + p.sprint_ramp_rate * float(s.sprint_ramp_ticks) * MoveUnits.DT)


func reset_sprint(s: MoveState, ctx: Ctx, reason: StringName) -> void:
	var was := s.sprint_active or s.sprint_timer_ticks > 0
	s.sprint_timer_ticks = 0
	s.sprint_active = false
	s.sprint_bonus_current = 0.0
	s.sprint_ramp_ticks = 0
	if ctx != null:
		ctx.sprint_reset = true
		ctx.sprint_reset_reason = reason
	if was and reason != &"combat":
		emit(s, MoveEvents.SPRINT_RESET, {"reason": reason})


# ============================================================================
# step 4: transitions (priority order, design §7.9)
# ============================================================================

func _transitions(s: MoveState, ctx: Ctx) -> void:
	# FORCED end / FORCED overrides everything else
	if s.loco == L.FORCED:
		if s.forced_ticks <= 0:
			ForcedState.finish(self, s, ctx)
		else:
			return
	# parry start (cancels a ground dash and its momentum)
	MeleeState.try_parry(self, s, ctx)
	match s.loco:
		L.MANTLE:
			MantleState.transitions(self, s, ctx)
			return
		L.ZIPLINE, L.ROPE:
			RailState.transitions(self, s, ctx)
			return
	# zipline / rope attach
	if RailState.try_attach(self, s, ctx):
		return
	# melee
	if MeleeState.try_heavy(self, s, ctx):
		return
	MeleeState.try_light(self, s, ctx)
	match s.loco:
		L.GROUND, L.CROUCH, L.SLIDE:
			GroundState.transitions(self, s, ctx)
		L.AIR, L.DOWN_DASH:
			AirState.transitions(self, s, ctx)
		L.GROUND_DASH, L.AIR_DASH:
			DashState.transitions(self, s, ctx)
		L.HEAVY_LUNGE:
			MeleeState.transitions(self, s, ctx)


# ============================================================================
# step 5: physics
# ============================================================================

func _physics(s: MoveState, ctx: Ctx) -> void:
	match s.loco:
		L.GROUND:
			GroundState.walk_physics(self, s, ctx, cp.effective_move_speed(s, ctx.firing))
		L.CROUCH:
			GroundState.walk_physics(self, s, ctx, cp.effective_crouch_speed(s))
		L.SLIDE:
			GroundState.slide_physics(self, s, ctx)
		L.AIR, L.DOWN_DASH:
			AirState.air_physics(self, s, ctx, true)
			gravity_half(s, ctx)
		L.GROUND_DASH, L.AIR_DASH:
			DashState.physics(self, s, ctx)
		L.MANTLE:
			MantleState.physics(self, s, ctx)
		L.ZIPLINE, L.ROPE:
			RailState.physics(self, s, ctx)
		L.HEAVY_LUNGE:
			MeleeState.physics(self, s, ctx)
		L.FORCED:
			ForcedState.physics(self, s, ctx)


## spec: movement.md §10 gravity, integrated in two half-steps around the move.
func gravity_half(s: MoveState, ctx: Ctx) -> void:
	s.velocity.y -= cp.gravity(s) * MoveUnits.DT * 0.5
	ctx.gravity_applied = true


# ============================================================================
# step 6: move
# ============================================================================

func _move(s: MoveState, ctx: Ctx) -> void:
	var motion := s.velocity * MoveUnits.DT * ctx.frac
	if s.grounded and is_ground_loco(s.loco):
		motion = KinematicMover.project_on_ground(Vector3(motion.x, 0.0, motion.z), s.ground_normal)
	if motion.length_squared() < 1e-14:
		return
	var r := mover.move(s, motion, s.crouched)
	s.position = r["position"]
	var v: Vector3 = r["velocity"]
	if s.grounded and is_ground_loco(s.loco):
		v.y = 0.0
	s.velocity = v


static func is_ground_loco(loco: int) -> bool:
	return loco == L.GROUND or loco == L.CROUCH or loco == L.SLIDE or loco == L.GROUND_DASH or loco == L.HEAVY_LUNGE or loco == L.FORCED


# ============================================================================
# step 7: categorize
# ============================================================================

func _categorize(s: MoveState, ctx: Ctx) -> void:
	var p := cp.params
	match s.loco:
		L.MANTLE, L.ZIPLINE, L.ROPE:
			return
	var walking := s.loco == L.GROUND or s.loco == L.CROUCH or s.loco == L.SLIDE
	if s.grounded and (walking or s.loco == L.GROUND_DASH or s.loco == L.HEAVY_LUNGE or s.loco == L.FORCED):
		# impl notes: separation is an upward-speed test. Ground states (SLIDE included, session 7) keep vy = 0 and a
		# horizontal velocity whose dot with a downhill normal is positive and must not detach.
		var separating := s.velocity.y > LEAVE_GROUND_SPEED
		if not separating:
			var dist := p.step_height if ctx.grounded_start else p.ground_probe_distance
			var g := _find_ground(s.position, s.crouched, dist)
			if g["ok"]:
				s.position = g["position"]
				s.ground_normal = g["normal"]
				s.grounded = true
				if walking or s.loco == L.GROUND_DASH:
					s.velocity.y = 0.0
				elif s.velocity.y < 0.0:
					s.velocity.y = 0.0
				_finish_gravity(s, ctx)
				return
		_leave_ground(s, ctx)
		_finish_gravity(s, ctx)
		return
	# airborne
	if s.velocity.y <= LEAVE_GROUND_SPEED:
		var g2 := _find_ground(s.position, s.crouched, p.ground_probe_distance)
		if g2["ok"]:
			_land(s, ctx, g2)
			return
	_finish_gravity(s, ctx)


## G36: -600 u/s fall cap while touching a wall (walls_and_ledges.md rule 21).
## PROVISIONAL (G36): trigger = airborne AIR + falling faster than the cap + a wall within
## wall_detect_distance; the exact wall-slide trigger is pending recording.
func _wall_slide_cap(s: MoveState) -> void:
	var cap := cp.params.wall_slide_max_fall
	if s.grounded or s.loco != L.AIR or s.velocity.y >= -cap:
		return
	if mover.find_walls(s.position, s.crouched, cp.params.wall_detect_distance).is_empty():
		return
	s.velocity.y = -cap


func _finish_gravity(s: MoveState, ctx: Ctx) -> void:
	if ctx.gravity_applied and not s.grounded:
		s.velocity.y -= cp.gravity(s) * MoveUnits.DT * 0.5


func _find_ground(pos: Vector3, crouched: bool, dist: float) -> Dictionary:
	var pr := mover.probe_ground_dist(pos, crouched, dist)
	if pr["hit"] and pr["walkable"]:
		return {"ok": true, "position": pos + Vector3.DOWN * float(pr["distance"]), "normal": pr["normal"]}
	return {"ok": false}


func _leave_ground(s: MoveState, ctx: Ctx) -> void:
	s.grounded = false
	s.ground_normal = Vector3.UP
	s.coyote_ticks = cp.coyote_ticks
	# G40 (fixes K6): crouch held at takeoff is stored, so landing does not slide while it stays held.
	# PROVISIONAL (G40): leaving the ground from SLIDE is exempt (the crouch is in use, not stored); pending recording.
	if ctx.is_held(InputCmd.BTN_CROUCH) and s.loco != L.SLIDE:
		s.slide_block_until_crouch_release = true
	match s.loco:
		L.GROUND, L.CROUCH, L.SLIDE:
			if s.loco == L.SLIDE:
				emit(s, MoveEvents.SLIDE_END)
			try_uncrouch(s)
			s.loco = L.AIR


func try_uncrouch(s: MoveState) -> void:
	if s.crouched and mover.can_stand(s.position):
		s.crouched = false


## Landing (design §7.9 step 7): LANDED, refresh air actions, reset fatigue, slide-on-land.
func _land(s: MoveState, ctx: Ctx, g: Dictionary) -> void:
	var p := cp.params
	var impact := -s.velocity.y
	s.position = g["position"]
	s.ground_normal = g["normal"]
	s.grounded = true
	if s.velocity.y < 0.0:
		s.velocity.y = 0.0
	emit(s, MoveEvents.LANDED, {"impact_speed": maxf(0.0, impact)})
	var air_dashed := s.air_dashed_this_airtime
	refresh_air(s)
	s.last_air_crouch_press_tick = -1
	s.zip_exit_drag_active = false   # G46: zip exit drag lasts until landing
	s.slide_hop_penalty_active = false   # PROVISIONAL (G09): slide drag lasts until landing
	s.slide_hop_penalty_ticks = 0
	s.air_dash_end_drag_ticks_left = 0   # end drag mode 4 is airborne only; ground friction takes over
	# G02 IAD: an air dash that lands keeps its end drag pending until the dash's scheduled end; see
	# _iad_end_drag. PROVISIONAL (G02): V2 0:11 / 0:33 / 3:03, V9 1:41 / 1:58; pending clip A2.
	if s.loco == L.AIR_DASH and s.air_dash_drag_pending:
		s.air_dash_drag_land_ticks = maxi(0, s.dash_total_ticks - s.dash_ticks + 1)   # post_move already counted this tick
	else:
		s.air_dash_drag_pending = false
		s.air_dash_drag_land_ticks = -1
	s.last_wall_jump_tick = -1
	s.jump_deferred = false
	# spec: movement.md §16 knock-off stun starts on landing
	if s.zip_knockoff_pending:
		s.zip_knockoff_pending = false
		ControlLocks.add(s, ControlLocks.STUN, cp.zip_knockoff_stun_ticks, &"zip_knockoff")
		emit(s, MoveEvents.LOCKED, {"mask": ControlLocks.STUN})
	match s.loco:
		L.AIR, L.DOWN_DASH, L.AIR_DASH:
			s.loco = L.GROUND
			if ctx.is_held(InputCmd.BTN_CROUCH) and s.slide_block_until_crouch_release:
				# G40: crouch held since the dash or takeoff: no slide on landing
				GroundState.enter_crouch(self, s)
			elif ctx.is_held(InputCmd.BTN_CROUCH):
				# spec: movement.md §13 slide on landing / air slide. Measured session 4 (lslide): a dash-jump landing
				# is a normal landing slide (speed or slope needed; same friction, penalty and onset).
				var kind := -1
				if air_dashed:
					kind = MoveState.SlideKind.AIR
				elif s.horizontal_speed() > p.slide_entry_speed or on_slide_slope(s):
					kind = MoveState.SlideKind.NORMAL
				if kind >= 0:
					# measured session 6 (s6_slidejump): a landing into a normal slide below landing_slide_friction_speed
					# takes one ground-friction tick first (x0.9375 at 376-461 u/s); none at 471+ u/s (session 7, s7_open LT*).
					var hv := s.horizontal_speed()
					if kind == MoveState.SlideKind.NORMAL and hv < p.landing_slide_friction_speed and hv > 1e-6:
						var ns := maxf(0.0, hv - maxf(hv, p.stop_speed) * p.ground_friction * MoveUnits.DT)
						s.velocity.x *= ns / hv
						s.velocity.z *= ns / hv
					GroundState.enter_slide(self, s, kind, -1.0)
				else:
					GroundState.enter_crouch(self, s)
			else:
				try_uncrouch(s)


func on_slide_slope(s: MoveState) -> bool:
	return s.grounded and s.ground_normal.y < cp.slide_slope_min_normal_y


# ============================================================================
# step 8: stamina (spec: movement.md §7)
# ============================================================================

func _stamina_regen(s: MoveState) -> void:
	var mx := cp.stamina_max(s)
	if (s.cheat_flags & MoveState.CHEAT_INFINITE_STAMINA) != 0:
		s.stamina = mx
		s.stamina_regen_progress = 0.0
		return
	if s.stamina >= mx - 1e-9:
		s.stamina = mx
		s.stamina_regen_progress = 0.0
		return
	var rate := 1.0 / cp.stamina_bar_ticks(s)
	if s.combat_regen_penalty_ticks > 0:
		rate *= 1.0 - cp.params.wall_jump_combat_regen_penalty
	s.stamina_regen_progress += rate
	if s.stamina_regen_progress >= 1.0 - 1e-6:
		s.stamina_regen_progress = maxf(0.0, s.stamina_regen_progress - 1.0)
		if s.stamina_regen_progress < 1e-6:
			s.stamina_regen_progress = 0.0
		s.stamina += 1.0
		var r := roundf(s.stamina)
		if absf(s.stamina - r) < 1e-6:
			s.stamina = r
	if s.stamina >= mx - 1e-9:
		s.stamina = mx
		s.stamina_regen_progress = 0.0


# ============================================================================
# shared helpers used by states/*.gd
# ============================================================================

func emit(s: MoveState, type: StringName, payload: Dictionary = {}) -> void:
	MoveEvents.push(s, type, payload)


func can_spend(s: MoveState, cost: float) -> bool:
	if cost <= 0.0:
		return true
	if (s.cheat_flags & MoveState.CHEAT_INFINITE_STAMINA) != 0:
		return true
	if (ControlLocks.active_mask(s) & ControlLocks.STAMINA) != 0:
		return false
	return s.stamina + cp.params.stamina_epsilon >= cost


## spec: movement.md §7 spending; fails under a STAMINA lock.
func spend(s: MoveState, cost: float) -> bool:
	if not can_spend(s, cost):
		return false
	if cost > 0.0 and (s.cheat_flags & MoveState.CHEAT_INFINITE_STAMINA) == 0:
		s.stamina = maxf(0.0, s.stamina - cost)
		var r := roundf(s.stamina * 2.0) * 0.5
		if absf(s.stamina - r) < 1e-6:
			s.stamina = r
	return true


## spec: movement.md §10, §14 per-airtime counters refresh.
func refresh_air(s: MoveState) -> void:
	s.air_jumps_used = 0
	s.air_dashes_used = 0
	s.down_dashes_used = 0
	s.wall_jumps_done = 0
	s.wall_fatigue = 0.0
	s.wall_fatigue_peak = 0.0
	s.wall_fatigue_recover_ticks = 0
	s.dash_jumped_this_airtime = false
	s.air_dashed_this_airtime = false


func add_wall_fatigue(s: MoveState, amount: float) -> void:
	s.wall_fatigue = clampf(s.wall_fatigue + amount, 0.0, 1.0)
	s.wall_fatigue_peak = s.wall_fatigue
	s.wall_fatigue_recover_ticks = 0


func facing(s: MoveState) -> Vector3:
	return Basis(Vector3.UP, s.yaw) * Vector3.FORWARD


## Clamp horizontal speed (used at dash end, spec: movement.md §8 / design §2 #25).
func clamp_horizontal(s: MoveState, max_speed: float) -> void:
	var h := Vector2(s.velocity.x, s.velocity.z)
	if h.length() > max_speed:
		h = h.normalized() * max_speed
		s.velocity.x = h.x
		s.velocity.z = h.y


## Normal jump (ground, slide or ended dash). spec: movement.md §10.
func do_ground_jump(s: MoveState, ctx: Ctx, kind: StringName) -> void:
	var early_slide_jump := s.loco == L.SLIDE and s.slide_ticks < cp.slide_jump_store_crouch_ticks
	if s.loco == L.SLIDE:
		_slide_hop(s)
		emit(s, MoveEvents.SLIDE_END)
		# measured session 4: a jump out of a ground-dash slide cuts horizontal speed
		if s.slide_kind == MoveState.SlideKind.DASH:
			s.velocity.x *= cp.params.slide_jump_speed_mult_dash
			s.velocity.z *= cp.params.slide_jump_speed_mult_dash
	try_uncrouch(s)
	s.velocity.y = cp.params.jump_speed
	s.grounded = false
	# G40 (fixes K6): crouch held at takeoff is stored until released. Measured session 4: a slide jump
	# stores it too, except one made early in the slide (that one lands back into a slide).
	if ctx.is_held(InputCmd.BTN_CROUCH) and not early_slide_jump:
		s.slide_block_until_crouch_release = true
	s.ground_normal = Vector3.UP
	s.coyote_ticks = 0
	s.jump_buffer_ticks = 0
	if (s.action_buffer_button & InputCmd.BTN_JUMP) != 0:
		s.action_buffer_ticks = 0
		s.action_buffer_button = 0
	s.loco = L.AIR
	emit(s, MoveEvents.JUMPED, {"kind": kind})


## G09 slide-hop penalty ("slide drag"; slide_and_slopes.md rule 13, V4 0:47 / 2:13, V5 1:49,
## V15 1:14 / 1:39). Called for a jump out of a SLIDE, before the ground normal is reset.
## PROVISIONAL (G09): pending recording clip S2.
func _slide_hop(s: MoveState) -> void:
	var p := cp.params
	if not p.slide_hop_enabled:
		return
	# a superglide (jump out of the mantle glide slide) neither sets nor triggers the flag
	if s.mantle_glide:
		return
	# a downhill slide jump clears the flag
	var nh := Vector3(s.ground_normal.x, 0.0, s.ground_normal.z)
	if on_slide_slope(s) and nh.dot(Vector3(s.velocity.x, 0.0, s.velocity.z)) > 0.0:
		s.slide_hop_flag = false
		s.slide_hop_ground_ticks = 0
		return
	# flagged and earlier than slide_hop_min_time into this slide: air-drag penalty, unless the zip
	# exit drag immunity is running (V6/V15)
	if s.slide_hop_flag and s.slide_ticks < cp.slide_hop_min_ticks and s.zip_exit_momentum_ticks <= 0:
		s.slide_hop_penalty_active = true
		s.slide_hop_penalty_ticks = maxi(0, cp.slide_hop_penalty_ticks)
		emit(s, MoveEvents.SLIDE_DRAG, {"slide_ticks": s.slide_ticks})
	# Every slide jump sets the flag, dash slides included. PROVISIONAL (G09): air_movement.md rule 39
	# (wiki E13, "dash sliding does not set the flag") predates the 2026-03-06 slide-jump change
	# (slide_and_slopes.md lines 64/235/297); Leif 2026-05 (slide_and_slopes.md line 254) says it is "set on
	# any slide jump", with only the scroll short hop exempt. E13's "dash-jumping sets it" comes from the same
	# stale page, so a dash-jump (not a slide jump) does not set it here. Pending S2.
	s.slide_hop_flag = true
	s.slide_hop_ground_ticks = 0


## G02 IAD (PROVISIONAL (G02), pending clip A2). After an air dash lands with its end drag pending:
## - leaving the ground before the dash's scheduled end (bhop out of the IAD, any drop) applies the drag
##   at once (V2 0:33, V2 3:03 "a plain bhop out of an IAD still gets the drag", V9 1:58);
## - at the scheduled end, a SLIDE on level ground skips it (V2 0:11, V9 1:41 "only an IAD into a slide on
##   a level surface"); anything else (no crouch, a slope) applies it;
## - a new air dash replaces it (V2 3:03; handled in DashState.try_air_dash).
## Open: whether a drop shortly after the scheduled end still brings the drag back (V2 0:33 wording).
func _iad_end_drag(s: MoveState) -> void:
	if not s.air_dash_drag_pending or s.air_dash_drag_land_ticks < 0 or s.loco == L.AIR_DASH:
		return
	if not s.grounded:
		DashState.apply_air_dash_end_drag(self, s)
		return
	if s.air_dash_drag_land_ticks > 0:
		s.air_dash_drag_land_ticks -= 1
		return
	if s.loco == L.SLIDE and s.ground_normal.y >= cp.params.air_dash_iad_level_normal_y:
		s.air_dash_drag_pending = false
		s.air_dash_drag_land_ticks = -1
		return
	DashState.apply_air_dash_end_drag(self, s)


## G09: ground time not sliding clears the slide-hop flag. Runs in bookkeeping, after categorize.
func _track_contacts(s: MoveState, ctx: Ctx) -> void:
	if s.grounded and (s.loco == L.GROUND or s.loco == L.CROUCH or s.loco == L.GROUND_DASH):
		if s.slide_hop_flag:
			s.slide_hop_ground_ticks += 1
			if s.slide_hop_ground_ticks >= cp.slide_hop_clear_ticks:
				s.slide_hop_flag = false
				s.slide_hop_ground_ticks = 0
	else:
		s.slide_hop_ground_ticks = 0


## Ground/air state from the current grounded flag.
func settle_loco(s: MoveState) -> void:
	s.loco = L.GROUND if s.grounded else L.AIR


func get_zipline(id: int) -> ZiplineRail:
	for z in ziplines:
		if z.id == id:
			return z
	return null


func get_rope(id: int) -> RopeRail:
	for r in ropes:
		if r.id == id:
			return r
	return null
