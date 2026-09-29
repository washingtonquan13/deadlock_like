class_name WeaponSim
extends RefCounted
## Pure gun state machine (spec: combat.md §2). One step per 64 Hz tick; fire rate stays exact
## because shots carry their sub-tick time. Automatic on hold for every gun; burst guns fire
## the whole burst per cycle (cycle_time is burst start to burst start, which is what the
## spec's burst DPS formula implies).

const DT := 1.0 / 64.0


static func new_state(w: WeaponData) -> WeaponState:
	var s := WeaponState.new()
	s.ammo = w.clip_size
	return s


## Current trigger cycle time (spin-up lerps from cycle_time to spin_cycle_time).
static func cycle_time(s: WeaponState, w: WeaponData, rate_mult: float = 1.0) -> float:
	var c := w.cycle_time
	if w.spins_up:
		c = lerpf(w.cycle_time, w.spin_cycle_time, s.spin)
	return c / maxf(rate_mult, 0.01)


## Advance one tick. Returns the shots fired this tick, in order:
## { "time": sim time of the shot, "lead": seconds between the shot and the end of this tick,
##   "spread": cone half-angle in degrees, "index": shot counter (seeds the spread) }.
## infinite_ammo: shots cost no ammo (sliding: specs/movement_behavior/slide_and_slopes.md rule 26).
static func step(s: WeaponState, w: WeaponData, fire_held: bool, reload_pressed: bool,
		rate_mult: float = 1.0, reload_mult: float = 1.0, infinite_ammo: bool = false) -> Array:
	var shots: Array = []
	s.infinite_ammo = infinite_ammo
	var t0 := s.time
	var t1 := t0 + DT
	var fire_pressed := fire_held and not s.prev_fire
	s.prev_fire = fire_held

	# spin-up (combat.md §2): rates are fractions of the spin range per second (inferred)
	if w.spins_up:
		if fire_held and s.ammo > 0 and s.mode == WeaponState.Mode.IDLE:
			s.spin = minf(1.0, s.spin + w.spin_up_rate * DT)
		else:
			s.spin = maxf(0.0, s.spin - w.spin_down_rate * DT)
	s.bloom = maxf(0.0, s.bloom - w.spread_bloom_decay * DT)

	if reload_pressed and s.mode == WeaponState.Mode.IDLE and s.burst_left == 0 and s.ammo < w.clip_size:
		_start_reload(s, w, t0, reload_mult)

	# single-shell: a fresh trigger press with a shell loaded interrupts the reload (keeps shells)
	if s.mode == WeaponState.Mode.RELOADING_SINGLE and fire_pressed and s.ammo > 0:
		s.mode = WeaponState.Mode.IDLE
	_advance_reload(s, w, t1, reload_mult)

	while true:
		if s.burst_left > 0:
			var tb := maxf(s.next_burst_time, t0)
			if tb >= t1:
				break
			_fire(s, w, tb, t1, shots)
			s.burst_left -= 1
			s.next_burst_time = tb + w.burst_interval / maxf(rate_mult, 0.01)
			if s.ammo <= 0:
				s.burst_left = 0
				_start_reload(s, w, tb, reload_mult)
				_advance_reload(s, w, t1, reload_mult)
			continue
		if s.mode == WeaponState.Mode.IDLE and fire_held and s.ammo > 0:
			var t := maxf(s.next_shot_time, t0)
			if t >= t1:
				break
			s.next_shot_time = t + cycle_time(s, w, rate_mult)
			if w.burst_count > 1:
				s.next_shot_time += w.burst_count * w.burst_interval / maxf(rate_mult, 0.01)
			s.burst_left = maxi(1, w.burst_count)
			s.next_burst_time = t
			continue
		break
	s.time = t1
	return shots


static func _fire(s: WeaponState, w: WeaponData, t: float, t1: float, shots: Array) -> void:
	shots.append({"time": t, "lead": t1 - t, "spread": w.spread_base + s.bloom, "index": s.shots_fired})
	s.shots_fired += 1
	if not s.infinite_ammo:
		s.ammo -= 1
	s.bloom = minf(w.spread_bloom_max, s.bloom + w.spread_bloom_per_shot)


static func _start_reload(s: WeaponState, w: WeaponData, t: float, reload_mult: float) -> void:
	if w.reload_single:
		s.mode = WeaponState.Mode.RELOADING_SINGLE
		s.reload_next = t + (w.reload_single_delay + w.reload_time) * reload_mult
	else:
		s.mode = WeaponState.Mode.RELOADING
		s.reload_end = t + w.reload_time * reload_mult


static func _advance_reload(s: WeaponState, w: WeaponData, t1: float, reload_mult: float) -> void:
	if s.mode == WeaponState.Mode.RELOADING and s.reload_end < t1:
		s.ammo = w.clip_size
		s.mode = WeaponState.Mode.IDLE
		s.next_shot_time = maxf(s.next_shot_time, s.reload_end)
	elif s.mode == WeaponState.Mode.RELOADING_SINGLE:
		while s.reload_next < t1 and s.ammo < w.clip_size:
			s.ammo += 1
			s.next_shot_time = maxf(s.next_shot_time, s.reload_next)
			s.reload_next += w.reload_time * reload_mult
		if s.ammo >= w.clip_size:
			s.mode = WeaponState.Mode.IDLE


## Pellet/bullet directions for one shot: pellets > 1 use a fixed ring pattern (center + rings)
## with a little seeded jitter; single bullets get a seeded random point in the spread cone.
static func shot_directions(w: WeaponData, aim: Vector3, spread_deg: float, seed_index: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var fwd := aim.normalized()
	var right := fwd.cross(Vector3.UP)
	if right.length_squared() < 1e-8:
		right = fwd.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(fwd).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_index * 7919 + 17)
	var cone := deg_to_rad(spread_deg)
	var n := maxi(1, w.pellets)
	for i in n:
		var r := 0.0
		var a := 0.0
		if n == 1:
			r = sqrt(rng.randf()) * cone
			a = rng.randf() * TAU
		elif i == 0 and n % 2 == 1:
			r = cone * 0.1 * rng.randf()
			a = rng.randf() * TAU
		else:
			var ring := n - (n % 2)
			var k := i - (n % 2)
			r = cone * (0.55 if k % 2 == 0 and ring >= 6 else 1.0) * (0.9 + 0.1 * rng.randf())
			a = TAU * float(k) / ring + (rng.randf() - 0.5) * 0.3
		out.append((fwd + (right * cos(a) + up * sin(a)) * tan(r)).normalized())
	return out
