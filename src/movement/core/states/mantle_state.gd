extends RefCounted
## MANTLE (design §7.10, spec: movement.md §15).

const Ctx = preload("res://src/movement/core/states/sim_context.gd")
const GroundState = preload("res://src/movement/core/states/ground_state.gd")
const L := MoveState.Loco
const RISE_PORTION := 0.6


## spec: movement.md §15 trigger: jump pressed or held + forward input toward a ledge.
## `forced` skips the input requirement (heavy melee can mantle, spec: movement.md §19).
static func try_start(sim: MovementSim, s: MoveState, ctx: Ctx, forced: bool) -> bool:
	var p := sim.cp.params
	if (ctx.mask & ControlLocks.MANTLE) != 0:
		return false
	var fwd: Vector3
	if forced:
		fwd = sim.facing(s)
	else:
		if not (ctx.is_pressed(InputCmd.BTN_JUMP) or ctx.is_held(InputCmd.BTN_JUMP)):
			return false
		if (ctx.mask & ControlLocks.JUMP) != 0:
			return false
		if p.mantle_requires_forward and ctx.move_y <= 0:
			return false
		if not ctx.has_move:
			return false
		fwd = ctx.wish
	var ledge := sim.mover.find_ledge(s.position, fwd, s.crouched)
	if not ledge["found"]:
		return false
	var h: float = ledge["height"]
	# spec: movement.md §15 bands are ledge heights above the ground. Mid-jump the feet are already
	# raised, so measure from the floor under the player instead (else a 170 u ledge reads as
	# ~157 u a few ticks into the jump and is wrongly mantled). No floor below: use the feet.
	if not s.grounded:
		var top_y := s.position.y + h
		var max_u: int = p.mantle_band_tops_u[p.mantle_band_tops_u.size() - 1] if not p.mantle_band_tops_u.is_empty() else 160
		var floor_y := sim.mover.floor_y_below(s.position, float(max_u) * MoveUnits.HU + 0.1)
		if not is_nan(floor_y):
			h = top_y - floor_y
	var band := sim.cp.mantle_band_for_height(h)
	if band < 0:
		return false
	var total := sim.cp.mantle_ticks_for_band(band)
	if total <= 0:
		return false
	if s.loco == L.SLIDE:
		sim.emit(s, MoveEvents.SLIDE_END)
	s.loco = L.MANTLE
	s.mantle_from = s.position
	s.mantle_to = ledge["top"]
	s.mantle_total_ticks = total
	s.mantle_ticks = 0
	s.mantle_band = band
	s.mantle_glide = false
	s.velocity = Vector3.ZERO
	s.grounded = false
	s.jump_buffer_ticks = 0
	s.action_buffer_ticks = 0
	s.action_buffer_button = 0
	sim.emit(s, MoveEvents.MANTLE_START, {"height_m": h, "band": band})
	return true


static func transitions(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	if s.mantle_ticks < s.mantle_total_ticks:
		return
	# spec: movement.md §15 ends grounded with air actions refreshed
	var dir := Vector3(s.mantle_to.x - s.mantle_from.x, 0.0, s.mantle_to.z - s.mantle_from.z)
	s.position = s.mantle_to
	var pr := sim.mover.probe_ground_dist(s.position, s.crouched, sim.cp.params.ground_probe_distance + 0.02)
	if pr["hit"] and pr["walkable"]:
		s.position += Vector3.DOWN * float(pr["distance"])
		s.ground_normal = pr["normal"]
	else:
		s.ground_normal = Vector3.UP
	s.grounded = true
	s.velocity = Vector3.ZERO
	sim.refresh_air(s)
	s.last_air_crouch_press_tick = -1
	sim.emit(s, MoveEvents.MANTLE_END)
	if ctx.is_held(InputCmd.BTN_CROUCH):
		# spec: movement.md §15 mantle glide into a slide
		GroundState.enter_slide(sim, s, MoveState.SlideKind.NORMAL, sim.cp.params.mantle_glide_speed, dir)
		s.mantle_glide = true   # after enter_slide, which clears it (G09: a superglide sets no slide-hop flag)
	else:
		# stand up if there is room, otherwise stay crouched (spec: movement.md §6, §15)
		sim.try_uncrouch(s)
		s.loco = L.CROUCH if s.crouched else L.GROUND


## Scripted motion: smoothstep rise at the start position, then forward onto the top.
static func physics(sim: MovementSim, s: MoveState, ctx: Ctx) -> void:
	ctx.skip_move = true
	s.mantle_ticks += 1
	var t := clampf(float(s.mantle_ticks) / float(maxi(1, s.mantle_total_ticks)), 0.0, 1.0)
	var a := s.mantle_from
	var b := s.mantle_to
	var prev := s.position
	if t < RISE_PORTION:
		var u := smoothstep(0.0, 1.0, t / RISE_PORTION)
		s.position = Vector3(a.x, lerpf(a.y, b.y, u), a.z)
	else:
		var u2 := smoothstep(0.0, 1.0, (t - RISE_PORTION) / (1.0 - RISE_PORTION))
		s.position = Vector3(lerpf(a.x, b.x, u2), b.y, lerpf(a.z, b.z, u2))
	s.velocity = (s.position - prev) / MoveUnits.DT
