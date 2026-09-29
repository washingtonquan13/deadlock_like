class_name AbilityEffects
extends Node3D
## What the kit and the active items do when their CastSlot fires. Spirit damage goes through
## the target's take_bullet_hit with "kind": &"spirit" so amps, totals and numbers all apply.
## Timed self-buffs are StatSheet sources ("buff:<id>"), so they reach movement like items do.

var owner_abilities: HeroAbilities
var hero: HeroStats
var player: PlayerCharacter
var numbers: DamageNumbers
var aim_provider: Callable

var _buffs: Dictionary = {}        # sheet source -> seconds left
var _dash: Dictionary = {}         # active Flame Trail: {a, left, dir, last_drop}
var _flames: Array = []            # [{pos, left, node}]
var _flame_tick: float = 0.0
var _flame_ability: AbilityData
var _heals: Array = []             # [{per_s, left}]
var _kindle: Dictionary = {}       # target id -> {target, build, left, burn, tick}
var _kindle_ability: AbilityData
var _detonate_fx: MeshInstance3D
var _drains: Dictionary = {}       # toggle ability -> {per_tick, tick, acc}


func bind(p_abilities: HeroAbilities, p_numbers: DamageNumbers, projectiles: ProjectileSystem, p_aim: Callable) -> void:
	owner_abilities = p_abilities
	hero = p_abilities.hero
	player = p_abilities.player
	numbers = p_numbers
	aim_provider = p_aim
	p_abilities.effects = self
	if projectiles != null:
		projectiles.bullet_hit.connect(_on_bullet_hit)


func on_event(a: AbilityData, event: StringName) -> void:
	match [a.effect, event]:
		[&"cone_blast", &"cast"]:
			_cone_blast(a)
		[&"fire_dash", &"cast"]:
			_start_dash(a)
		[&"detonate", &"channel_start"]:
			_detonate_fx = _sphere(player.global_position, _p(a, &"radius"), Color(1.0, 0.45, 0.1, 0.12))
		[&"detonate", &"channel_end"]:
			_clear_detonate_fx()
			_detonate(a)
		[&"detonate", &"channel_cancel"]:
			_clear_detonate_fx()
		[&"heal_over_time", &"cast"]:
			var dur := _p(a, &"duration")
			_heals.append({"per_s": _p(a, &"heal_total") / maxf(dur, 0.01), "left": dur})
			_buff(&"buff:" + String(a.id), {StatDefs.SPRINT_SPEED: _p(a, &"sprint_speed")}, dur)
		[&"blood_frenzy", &"toggle_on"]:
			_buff(&"buff:" + String(a.id), {StatDefs.FIRE_RATE: _p(a, &"fire_rate"),
					StatDefs.MOVE_SPEED: _p(a, &"move_speed"), StatDefs.DEBUFF_RESIST: _p(a, &"debuff_resist")}, INF)
			_drains[a] = {"per_tick": _p(a, &"drain") * _p(a, &"tick"), "tick": _p(a, &"tick"), "acc": 0.0}
		[&"blood_frenzy", &"toggle_off"]:
			_buffs.erase(&"buff:" + String(a.id))
			hero.sheet.clear_source(&"buff:" + String(a.id))
			_drains.erase(a)
		[&"blink", &"cast"]:
			_blink(a)
			_buff(&"buff:" + String(a.id), {StatDefs.BULLET_RESIST: _p(a, &"bullet_resist")}, _p(a, &"duration"))


func step(dt: float) -> void:
	for src in _buffs.keys():
		_buffs[src] -= dt
		if _buffs[src] <= 0.0:
			_buffs.erase(src)
			hero.sheet.clear_source(src)
	for h in _heals:
		hero.heal(h["per_s"] * dt)
		h["left"] -= dt
	_heals = _heals.filter(func(h: Dictionary) -> bool: return h["left"] > 0.0)
	for a in _drains:
		var d: Dictionary = _drains[a]
		d["acc"] += dt
		while d["acc"] >= d["tick"]:
			d["acc"] -= d["tick"]
			hero.drain(d["per_tick"])
	_step_dash(dt)
	_step_flames(dt)
	_step_kindling(dt)


# --- Cinder Bolt: a widening cone in front of the camera ---------------------------------

func _cone_blast(a: AbilityData) -> void:
	var ray: Dictionary = aim_provider.call() if aim_provider.is_valid() else {"origin": player.get_eye_position(), "direction": -player.global_basis.z}
	var origin: Vector3 = ray["origin"]
	var dir: Vector3 = ray["direction"]
	var reach := _p(a, &"range")
	var w0 := _p(a, &"cone_width")
	var grow := _p(a, &"cone_growth")
	var dmg := _p(a, &"damage")
	for t: TargetDummy in _targets():
		var to: Vector3 = t.get_center() - origin
		var along := to.dot(dir)
		if along <= 0.0 or along > reach:
			continue
		var half := 0.5 * (w0 + grow * along) + t.body_radius
		if (to - dir * along).length() > half:
			continue
		spirit_hit(t, dmg, _p(a, &"lifesteal"))
		t.apply_amp(_pid(), _p(a, &"amp"), _p(a, &"amp_duration"))   # amps later damage, not this hit
		t.set_status(&"slow", _p(a, &"slow_duration"))
	_cone_fx(origin, dir, reach, w0, grow)


# --- Flame Trail: steerable forced dash that leaves burning ground ------------------------

func _start_dash(a: AbilityData) -> void:
	_dash = {"a": a, "left": _p(a, &"duration"), "last_drop": player.global_position}
	_flame_ability = a
	_buff(&"buff:" + String(a.id), {StatDefs.SLOW_RESIST: _p(a, &"slow_resist")}, _dash["left"])
	_drop_flame(player.global_position)


func _step_dash(dt: float) -> void:
	if _dash.is_empty():
		return
	var a: AbilityData = _dash["a"]
	_dash["left"] -= dt
	var s := player.state
	var flat := _aim_flat()
	var spd := _p(a, &"ground_speed") if s.grounded else _p(a, &"air_speed")
	var vy := 0.0 if s.grounded else s.velocity.y
	var done: bool = _dash["left"] <= 0.0
	# re-pushed each tick so it steers with the camera; 2 ticks so it outlives one missed push
	player.push_external({"op": &"forced_motion", "velocity": flat * spd + Vector3(0, vy, 0),
			"duration": MoveUnits.DT * (1.0 if done else 2.0), "gravity": true, "exit_loco": -1})
	var pos := player.global_position
	if pos.distance_to(_dash["last_drop"]) >= _p(a, &"spacing"):
		_drop_flame(pos)
		_dash["last_drop"] = pos
	if done:
		_dash = {}


func _drop_flame(pos: Vector3) -> void:
	var a := _flame_ability
	var r := _p(a, &"radius")
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.04
	mi.mesh = cm
	mi.material_override = _mat(Color(1.0, 0.4, 0.05, 0.045))
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.03, 0)
	_flames.append({"pos": pos, "left": _p(a, &"flame_duration"), "node": mi})


## One damage tick per target per interval, however many patches overlap it.
func _step_flames(dt: float) -> void:
	if _flames.is_empty():
		return
	for f in _flames:
		f["left"] -= dt
		if f["left"] <= 0.0:
			f["node"].queue_free()
	_flames = _flames.filter(func(f: Dictionary) -> bool: return f["left"] > 0.0)
	_flame_tick += dt
	var tick := _p(_flame_ability, &"tick")
	if _flame_tick < tick:
		return
	_flame_tick -= tick
	var r := _p(_flame_ability, &"radius")
	var dmg := _p(_flame_ability, &"dps") * tick
	for t: TargetDummy in _targets():
		var p: Vector3 = t.global_position
		for f in _flames:
			var d: Vector3 = p - f["pos"]
			if Vector2(d.x, d.z).length() <= r + t.body_radius and absf(d.y) < 2.0:
				spirit_hit(t, dmg, 0.0)
				break


# --- Kindling: bullet hits build up a burn ------------------------------------------------

func _on_bullet_hit(info: Dictionary) -> void:
	if info.get("kind", &"bullet") == &"spirit" or info.get("source_id", 0) != _pid():
		return
	var a := _kindling()
	var t := info.get("target") as TargetDummy
	if a == null or t == null:
		return
	var k: Dictionary = _kindle.get(t.get_instance_id(), {"target": t, "build": 0.0, "left": 0.0, "burn": 0.0, "tick": 0.0})
	if k["burn"] > 0.0:
		return   # no buildup while already burning (unmeasured)
	k["build"] += _p(a, &"buildup_crit" if info.get("is_crit", false) else &"buildup")
	k["left"] = _p(a, &"buildup_duration")
	if k["build"] >= 100.0:
		k["build"] = 0.0
		k["burn"] = _p(a, &"burn_duration")
		k["tick"] = 0.0
		t.set_status(&"burn", k["burn"])
	_kindle[t.get_instance_id()] = k


func _step_kindling(dt: float) -> void:
	if _kindle.is_empty():
		return
	var a := _kindling()
	for id in _kindle.keys():
		var k: Dictionary = _kindle[id]
		if not is_instance_valid(k["target"]) or a == null:
			_kindle.erase(id)
			continue
		if k["burn"] > 0.0:
			var tick := _p(a, &"tick")
			k["burn"] -= dt
			k["tick"] += dt
			if k["tick"] >= tick:
				k["tick"] -= tick
				spirit_hit(k["target"], _p(a, &"dps") * tick, 0.0)
		else:
			k["left"] -= dt
			if k["left"] <= 0.0:
				_kindle.erase(id)


## Build-up 0..100 on a target (for the HUD / tests).
func kindle_buildup(t: Node) -> float:
	return float(_kindle.get(t.get_instance_id(), {}).get("build", 0.0))


func _kindling() -> AbilityData:
	for i in owner_abilities.abilities.size():
		var a := owner_abilities.abilities[i]
		if a.effect == &"kindling" and owner_abilities.is_unlocked(i):
			return a
	return null


# --- Detonate: channel, then a big blast around the caster ---------------------------------

func _detonate(a: AbilityData) -> void:
	var r := _p(a, &"radius")
	var c := player.global_position
	for t: TargetDummy in _targets():
		if t.global_position.distance_to(c) <= r + t.body_radius:
			t.set_status(&"stun", _p(a, &"stun"))
			spirit_hit(t, _p(a, &"damage"), _p(a, &"lifesteal"))
	var fx := _sphere(c, r, Color(1.0, 0.55, 0.15, 0.35))
	_fade(fx, 0.4)


func _clear_detonate_fx() -> void:
	if _detonate_fx != null and is_instance_valid(_detonate_fx):
		_detonate_fx.queue_free()
	_detonate_fx = null


# --- Blink: short teleport in the move direction (the aim if standing still) ----------------

func _blink(a: AbilityData) -> void:
	var s := player.state
	var v := Vector3(s.velocity.x, 0, s.velocity.z)
	var dir := v.normalized() if v.length() > 1.0 else _aim_flat()
	var from := player.global_position + Vector3(0, 1.0, 0)
	var to := from + dir * _p(a, &"distance")
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = (hit["position"] as Vector3) - dir * 0.5
	player.push_external({"op": &"teleport", "position": to - Vector3(0, 1.0, 0), "keep_velocity": true})


# --- shared ------------------------------------------------------------------------------

## Spirit damage from us to a target; lifesteal heals us by that % of the damage dealt.
func spirit_hit(t: TargetDummy, amount: float, lifesteal_pct: float) -> void:
	var c: Vector3 = t.get_center()
	var info := {
		"amount": amount, "is_crit": false, "is_head": false, "kind": &"spirit",
		"distance": c.distance_to(player.global_position), "point": c, "weapon": null,
		"source_id": _pid(), "target": t, "direction": (c - player.global_position).normalized(),
	}
	t.take_bullet_hit(info)
	if numbers != null:
		numbers.on_hit(info)
	if lifesteal_pct > 0.0:
		hero.heal(float(info["amount"]) * lifesteal_pct / 100.0)


func _p(a: AbilityData, name: StringName) -> float:
	return owner_abilities.prop(a, name)


func _pid() -> int:
	return player.get_instance_id()


func _targets() -> Array[TargetDummy]:
	var out: Array[TargetDummy] = []
	for n in get_tree().get_nodes_in_group(ProjectileSystem.TARGET_GROUP):
		if n is TargetDummy:
			out.append(n)
	return out


func _aim_flat() -> Vector3:
	var d: Vector3 = aim_provider.call()["direction"] if aim_provider.is_valid() else -player.global_basis.z
	d.y = 0.0
	return d.normalized() if d.length() > 1e-4 else Vector3.FORWARD


func _buff(src: StringName, stats: Dictionary, seconds: float) -> void:
	hero.sheet.set_source(src, stats)
	_buffs[src] = seconds


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _sphere(pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _mat(c)
	add_child(mi)
	mi.global_position = pos
	return mi


func _cone_fx(origin: Vector3, dir: Vector3, reach: float, w0: float, grow: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5 * w0
	cm.bottom_radius = 0.5 * (w0 + grow * reach)
	cm.height = reach
	mi.mesh = cm
	mi.material_override = _mat(Color(1.0, 0.5, 0.1, 0.25))
	add_child(mi)
	# cylinder axis is +Y; point it along dir, top (narrow end) at the origin
	var up := -dir
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(side, up, side.cross(up))
	mi.global_position = origin + dir * (reach * 0.5)
	_fade(mi, 0.25)


func _fade(mi: MeshInstance3D, seconds: float) -> void:
	var tw := mi.create_tween()
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, seconds)
	tw.tween_callback(mi.queue_free)
