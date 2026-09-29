class_name CombatSandbox
extends Node3D
## Adds guns to the movement sandbox (docs/design/gun_system_plan.md): the ProjectileSystem, a
## WeaponController on the local player, target dummies along the sprint lane, floating damage
## numbers and a small ammo HUD. [ / ] cycle through every hero's gun, R reloads.

@export var player_path: NodePath
@export var local_controller_path: NodePath
@export var weapon_key: StringName = &"haze"
## Dummies beside the sprint lane (the lane has 5 m labels), feet positions.
@export var dummy_positions: PackedVector3Array = PackedVector3Array([
	Vector3(3.0, 0.0, -10.0), Vector3(3.0, 0.0, -20.0), Vector3(3.0, 0.0, -30.0),
	Vector3(3.0, 0.0, -45.0), Vector3(3.0, 0.0, -60.0),
])

var projectiles: ProjectileSystem
var weapon_ctrl: WeaponController
var fx: GunFx
var _player: PlayerCharacter
var _ctrl: LocalController
var numbers: DamageNumbers
var _crosshair: Crosshair
var _info: Label


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerCharacter
	_ctrl = get_node_or_null(local_controller_path) as LocalController
	projectiles = ProjectileSystem.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	for p in dummy_positions:
		var d := TargetDummy.new()
		add_child(d)
		d.global_position = p
		d.rotation.y = PI
	if _player == null:
		return
	weapon_ctrl = WeaponController.new()
	weapon_ctrl.name = "WeaponController"
	weapon_ctrl.weapon_key = weapon_key
	add_child(weapon_ctrl)
	weapon_ctrl.player = _player
	weapon_ctrl.projectiles = projectiles
	weapon_ctrl.set_weapon(weapon_key)
	_player.ticked.connect(weapon_ctrl._on_player_ticked)
	if _ctrl != null:
		weapon_ctrl.aim_provider = _ctrl.get_aim_ray
		var rig := _ctrl.get_node_or_null(^"CameraRig")
		if rig != null and rig.has_method(&"add_recoil"):
			weapon_ctrl.shot_fired.connect(rig.add_recoil)
	projectiles.bullet_hit.connect(_on_bullet_hit)
	fx = GunFx.new()
	fx.name = "GunFx"
	add_child(fx)
	fx.connect_weapon(weapon_ctrl)
	fx.connect_projectiles(projectiles)
	numbers = DamageNumbers.new()
	numbers.name = "DamageNumbers"
	add_child(numbers)
	if _ctrl != null:
		_crosshair = _ctrl.get_node_or_null(^"UI/Crosshair") as Crosshair
		if _crosshair != null:
			_crosshair.bind_weapon(weapon_ctrl)
	_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	if weapon_ctrl == null or event.is_echo():
		return
	if event.is_action_pressed(&"weapon_next"):
		weapon_ctrl.cycle_weapon(1)
	elif event.is_action_pressed(&"weapon_prev"):
		weapon_ctrl.cycle_weapon(-1)


func _on_bullet_hit(info: Dictionary) -> void:
	numbers.on_hit(info)
	if _crosshair != null and info.get("source_id", 0) == _player.get_instance_id():
		_crosshair.show_hit(info["is_crit"])


func _process(_delta: float) -> void:
	if weapon_ctrl == null or _info == null or weapon_ctrl.weapon == null:
		return
	var w := weapon_ctrl.weapon
	_info.text = "%s  |  %.2f x%d dmg  |  %.0f dps  |  %.0f m/s
[ / ] change gun    R reload" % [
		w.display_name, w.damage_at_boons(weapon_ctrl.boons), w.pellets, w.burst_dps(), w.bullet_speed]


## Ammo, reload and hit markers live on the crosshair (specs/hud.md); this is only a small
## sandbox info line in the corner.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WeaponHud"
	add_child(layer)
	_info = Label.new()
	_info.anchor_left = 1.0
	_info.anchor_right = 1.0
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = -520.0
	_info.offset_top = -60.0
	_info.offset_right = -16.0
	_info.offset_bottom = -12.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_info.modulate = Color(1, 1, 1, 0.7)
	_info.add_theme_font_size_override(&"font_size", 14)
	_info.add_theme_constant_override(&"outline_size", 4)
	_info.add_theme_color_override(&"font_outline_color", Color.BLACK)
	layer.add_child(_info)
