class_name CombatSandbox
extends Node3D
## Adds guns to the movement sandbox (docs/design/gun_system_plan.md): the ProjectileSystem, a
## WeaponController on the local player, target dummies along the sprint lane, floating damage
## numbers and a small ammo HUD. [ / ] cycle through every hero's gun, R reloads. HeroStats
## gives the player items, souls and HP; B opens the debug shop.

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
var hero: HeroStats
var shop: ShopPanel
var _hp_bar: ProgressBar
var _hp_label: Label


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
	hero = HeroStats.new()
	hero.name = "HeroStats"
	hero.hero_key = weapon_key
	add_child(hero)
	hero.bind(_player, weapon_ctrl)
	weapon_ctrl.weapon_changed.connect(func(w: WeaponData) -> void:
		if w.key != hero.hero_key:
			hero.set_hero(w.key))
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
	hero.health_changed.connect(_on_health_changed)
	_on_health_changed(hero.hp, hero.max_hp)


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
	_info.text = "%s  |  %.2f x%d dmg  |  %.0f m/s  |  +%d%% wpn  |  %d SP
[ / ] change gun    R reload    B shop" % [
		w.display_name, weapon_ctrl.damage_per_bullet(), w.pellets, w.bullet_speed,
		int(hero.sheet.get_stat(StatDefs.WEAPON_DAMAGE)), int(hero.spirit_power())]
	_hp_label.text = "%d / %d   +%.1f/s" % [ceili(hero.hp), int(hero.max_hp), hero.regen_per_second()]


func _on_health_changed(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp


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

	var hp_box := VBoxContainer.new()
	hp_box.anchor_top = 1.0
	hp_box.anchor_bottom = 1.0
	hp_box.offset_left = 16.0
	hp_box.offset_top = -64.0
	hp_box.offset_right = 296.0
	hp_box.offset_bottom = -12.0
	layer.add_child(hp_box)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override(&"font_size", 16)
	_hp_label.add_theme_constant_override(&"outline_size", 4)
	_hp_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hp_box.add_child(_hp_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(280, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("5fbf5a")
	_hp_bar.add_theme_stylebox_override(&"fill", fill)
	hp_box.add_child(_hp_bar)

	var shop_layer := CanvasLayer.new()
	shop_layer.name = "ShopLayer"
	shop_layer.layer = 10   # above the debug HUD
	add_child(shop_layer)
	shop = ShopPanel.new()
	shop.name = "Shop"
	shop_layer.add_child(shop)
	shop.bind(hero, _ctrl.get_sampler() if _ctrl != null else null)
