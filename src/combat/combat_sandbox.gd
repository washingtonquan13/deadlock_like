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
var _player: PlayerCharacter
var _ctrl: LocalController
var _hud_label: Label
var _reload_bar: ProgressBar


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
	_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	if weapon_ctrl == null or event.is_echo():
		return
	if event.is_action_pressed(&"weapon_next"):
		weapon_ctrl.cycle_weapon(1)
	elif event.is_action_pressed(&"weapon_prev"):
		weapon_ctrl.cycle_weapon(-1)


func _process(_delta: float) -> void:
	if weapon_ctrl == null or _hud_label == null or weapon_ctrl.weapon == null:
		return
	var w := weapon_ctrl.weapon
	var s := weapon_ctrl.wstate
	var mode := ""
	if s.mode == WeaponState.Mode.RELOADING:
		mode = "  RELOADING"
	elif s.mode == WeaponState.Mode.RELOADING_SINGLE:
		mode = "  RELOADING (shells)"
	var extra := ""
	if w.spins_up:
		extra = "  spin %d%%" % roundi(s.spin * 100.0)
	_hud_label.text = "%s   %d / %d%s%s\n%.2f dmg x%d  |  %.0f dps  |  %.0f m/s  |  falloff %.0f-%.0f m\n[ / ] change gun   R reload" % [
		w.display_name, s.ammo, w.clip_size, mode, extra,
		w.damage_at_boons(weapon_ctrl.boons), w.pellets, w.burst_dps(), w.bullet_speed, w.falloff_start, w.falloff_end]
	_reload_bar.visible = s.is_reloading()
	_reload_bar.value = s.reload_progress(w) * 100.0


func _on_bullet_hit(info: Dictionary) -> void:
	var lbl := Label3D.new()
	lbl.text = "%.1f" % float(info["amount"]) if float(info["amount"]) < 10.0 else "%d" % roundi(float(info["amount"]))
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true   # same size on screen at any range
	lbl.font_size = 40 if info["is_crit"] else 30
	lbl.pixel_size = 0.0012
	lbl.modulate = Color(1.0, 0.85, 0.2) if info["is_crit"] else Color(1, 1, 1)
	lbl.outline_size = 12
	add_child(lbl)
	var jitter := Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25))
	lbl.global_position = (info["point"] as Vector3) + jitter
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.4 + 0.02 * float(info["distance"]), 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WeaponHud"
	add_child(layer)
	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -460.0
	box.offset_top = -110.0
	box.offset_right = -16.0
	box.offset_bottom = -16.0
	box.alignment = BoxContainer.ALIGNMENT_END
	layer.add_child(box)
	_hud_label = Label.new()
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_label.add_theme_font_size_override(&"font_size", 16)
	_hud_label.add_theme_constant_override(&"outline_size", 4)
	_hud_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	box.add_child(_hud_label)
	_reload_bar = ProgressBar.new()
	_reload_bar.custom_minimum_size = Vector2(200, 8)
	_reload_bar.show_percentage = false
	_reload_bar.visible = false
	box.add_child(_reload_bar)
