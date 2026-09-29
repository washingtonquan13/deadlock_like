class_name WeaponController
extends Node
## Gives a PlayerCharacter a gun (docs/design/gun_system_plan.md). Steps WeaponSim once per sim
## tick from the same InputCmd buttons the movement sim consumed, and hands shots to the
## ProjectileSystem. Bullets leave the gun muzzle toward the point under the crosshair, so the
## tracer drawn along a bullet is exactly where it goes.

signal shot_fired(kick_deg: float)
signal weapon_changed(w: WeaponData)
signal reload_started
## Per trigger shot: where it left from and the muzzle's offset from the eye (for visuals that
## follow the rendered player).
signal muzzle_fired(muzzle: Vector3, eye_offset: Vector3, aim: Vector3)

@export var player_path: NodePath
@export var projectiles_path: NodePath
@export var weapon_key: StringName = &"haze"
@export var boons: int = 0
## Fire-rate and reload multipliers (combat.md §12 / reload modifiers); 1 = base.
@export var fire_rate_mult: float = 1.0
@export var reload_mult: float = 1.0
## Gun muzzle in view space (right, up, forward is -z) from the eye. Right of the 0.41 m player
## capsule so it clears the shooter; a wall between the eye and it pulls it back.
@export var muzzle_offset: Vector3 = Vector3(0.55, -0.35, -0.4)
## Where the crosshair ray stops when it hits nothing (m).
@export var max_aim_distance: float = 150.0

var player: PlayerCharacter
var projectiles: ProjectileSystem
## The gun as fired: base_weapon with the stat sheet's clip, reload, speed and range applied.
var weapon: WeaponData
var base_weapon: WeaponData
## Item and investment stats (specs/stats.md §4); null = the bare gun.
var stats: StatSheet
var wstate: WeaponState
## Callable() -> {origin: Vector3, direction: Vector3}: the crosshair ray. Empty = aim from the sim view angles.
var aim_provider: Callable

var _prev_buttons: int = 0
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	player = get_node_or_null(player_path) as PlayerCharacter
	projectiles = get_node_or_null(projectiles_path) as ProjectileSystem
	_ray.collision_mask = ProjectileSystem.WORLD_MASK
	set_weapon(weapon_key)
	if player != null:
		player.ticked.connect(_on_player_ticked)


func set_weapon(key: StringName) -> void:
	var w := WeaponDB.get_weapon(key)
	if w == null:
		push_warning("WeaponController: unknown weapon '%s'" % key)
		return
	weapon_key = key
	base_weapon = w
	_rebuild_weapon()
	wstate = WeaponSim.new_state(weapon)
	wstate.time = float(player.state.tick) / 64.0 if player != null and player.state != null else 0.0
	weapon_changed.emit(weapon)


func set_stats(sheet: StatSheet) -> void:
	if stats != null and stats.changed.is_connected(_on_stats_changed):
		stats.changed.disconnect(_on_stats_changed)
	stats = sheet
	if stats != null:
		stats.changed.connect(_on_stats_changed)
	_on_stats_changed()


func _on_stats_changed() -> void:
	if base_weapon == null:
		return
	_rebuild_weapon()
	if wstate != null:
		wstate.ammo = mini(wstate.ammo, weapon.clip_size)
	weapon_changed.emit(weapon)


## specs/stats.md §4: clip (base + flat) × (1 + %) rounded up; bullet speed and falloff range %.
## Damage % and fire rate are applied per shot (damage_per_bullet, effective_fire_rate_mult).
func _rebuild_weapon() -> void:
	if stats == null:
		weapon = base_weapon
		return
	weapon = base_weapon.duplicate()
	weapon.clip_size = StatDefs.clip_size(stats, base_weapon.clip_size)
	weapon.bullet_speed = base_weapon.bullet_speed * StatDefs.bullet_speed_mult(stats)
	var r := maxf(0.0, 1.0 + stats.get_stat(StatDefs.FALLOFF_RANGE) / 100.0)
	weapon.falloff_start = base_weapon.falloff_start * r
	weapon.falloff_end = base_weapon.falloff_end * r


## Bullet damage at our boons after the weapon damage pool (stats.md §4).
func damage_per_bullet() -> float:
	var base := weapon.damage_at_boons(boons)
	return StatDefs.bullet_damage(stats, base) if stats != null else base


func effective_fire_rate_mult() -> float:
	return fire_rate_mult * (StatDefs.fire_rate_mult(stats) if stats != null else 1.0)


func effective_reload_mult() -> float:
	return reload_mult * (StatDefs.reload_mult(stats) if stats != null else 1.0)


func cycle_weapon(step: int) -> void:
	var keys := WeaponDB.keys()
	var i := keys.find(weapon_key)
	set_weapon(keys[posmod(i + step, keys.size())])


func can_fire(s: MoveState) -> bool:
	return s.loco != MoveState.Loco.MANTLE and s.loco != MoveState.Loco.HEAVY_LUNGE and s.parry_ticks <= 0


func _on_player_ticked(_tick: int, s: MoveState) -> void:
	if weapon == null:
		return
	var buttons := s.prev_buttons   # the cmd the sim just consumed
	var fire := (buttons & InputCmd.BTN_FIRE) != 0 and can_fire(s)
	var reload := (buttons & InputCmd.BTN_RELOAD) != 0 and (_prev_buttons & InputCmd.BTN_RELOAD) == 0
	_prev_buttons = buttons
	var was_reloading := wstate.is_reloading()
	# spec: slide_and_slopes.md rule 26, infinite ammo while sliding
	var slide := s.loco == MoveState.Loco.SLIDE
	var shots := WeaponSim.step(wstate, weapon, fire, reload, effective_fire_rate_mult(), effective_reload_mult(), slide)
	if wstate.is_reloading() and not was_reloading:
		reload_started.emit()
	if shots.is_empty() or projectiles == null:
		return
	var eye := s.position + Vector3.UP * (player.params.eye_height_crouch if s.crouched else player.params.eye_height_stand)
	var muzzle := _muzzle(eye, s)
	var aim := _aim_direction(muzzle, s)
	var dmg := damage_per_bullet()
	for shot in shots:
		for d in WeaponSim.shot_directions(weapon, aim, float(shot["spread"]), int(shot["index"])):
			projectiles.spawn(muzzle, d, weapon, dmg, player.get_instance_id(), float(shot["lead"]))
		shot_fired.emit(weapon.recoil_kick)
		muzzle_fired.emit(muzzle, muzzle - eye, aim)


func _muzzle(eye: Vector3, s: MoveState) -> Vector3:
	var m := eye + Basis.from_euler(Vector3(s.pitch, s.yaw, 0.0)) * muzzle_offset
	_ray.from = eye
	_ray.to = m
	_ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		m = eye.lerp(hit["position"], 0.9)
	return m


## Toward the world point under the crosshair (the camera sits behind the shoulder, so bullets
## converge on what the crosshair covers), else along the sim view angles.
func _aim_direction(muzzle: Vector3, s: MoveState) -> Vector3:
	var view := Basis.from_euler(Vector3(s.pitch, s.yaw, 0.0)) * Vector3.FORWARD
	if not aim_provider.is_valid():
		return view
	var r: Dictionary = aim_provider.call()
	var o: Vector3 = r["origin"]
	var dir: Vector3 = (r["direction"] as Vector3).normalized()
	var target := o + dir * max_aim_distance
	_ray.from = o
	_ray.to = target
	_ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		target = hit["position"]
	# shootable targets under the crosshair count too
	var best := o.distance_to(target)
	for n in get_tree().get_nodes_in_group(ProjectileSystem.TARGET_GROUP):
		if n == player:
			continue
		for cap in n.call(&"get_hit_capsules"):
			var f := ProjectileSystem._segment_capsule_first(o, target, cap[0], cap[1], float(cap[2]))
			if f >= 0.0 and f * best < best:
				best = f * best
				target = o + dir * best
	var to := target - muzzle
	# a point behind or right at the muzzle (camera pressed into a wall) would shoot backwards
	if to.length() < 0.5 or to.normalized().dot(dir) < 0.2:
		return dir
	return to.normalized()
