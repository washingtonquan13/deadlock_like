class_name WeaponController
extends Node
## Gives a PlayerCharacter a gun (docs/design/gun_system_plan.md). Steps WeaponSim once per sim
## tick from the same InputCmd buttons the movement sim consumed, and hands shots to the
## ProjectileSystem. Bullets leave the eye toward the point under the crosshair.

signal shot_fired(kick_deg: float)
signal weapon_changed(w: WeaponData)
signal reload_started

@export var player_path: NodePath
@export var projectiles_path: NodePath
@export var weapon_key: StringName = &"haze"
@export var boons: int = 0
## Fire-rate and reload multipliers (combat.md §12 / reload modifiers); 1 = base.
@export var fire_rate_mult: float = 1.0
@export var reload_mult: float = 1.0
## Where the crosshair ray stops when it hits nothing (m).
@export var max_aim_distance: float = 150.0

var player: PlayerCharacter
var projectiles: ProjectileSystem
var weapon: WeaponData
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
	weapon = w
	wstate = WeaponSim.new_state(w)
	wstate.time = float(player.state.tick) / 64.0 if player != null and player.state != null else 0.0
	weapon_changed.emit(w)


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
	var shots := WeaponSim.step(wstate, weapon, fire, reload, fire_rate_mult, reload_mult)
	if wstate.is_reloading() and not was_reloading:
		reload_started.emit()
	if shots.is_empty() or projectiles == null:
		return
	var muzzle := s.position + Vector3.UP * (player.params.eye_height_crouch if s.crouched else player.params.eye_height_stand)
	var aim := _aim_direction(muzzle, s)
	var dmg := weapon.damage_at_boons(boons)
	for shot in shots:
		for d in WeaponSim.shot_directions(weapon, aim, float(shot["spread"]), int(shot["index"])):
			projectiles.spawn(muzzle, d, weapon, dmg, player.get_instance_id(), float(shot["lead"]))
		shot_fired.emit(weapon.recoil_kick)


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
