class_name GunFx
extends Node3D
## Muzzle flashes, impact sparks and bullet marks. Visual only. Like the tracers, everything is
## plain data drawn through a few MultiMeshes, so nothing is instanced per shot or per hit.
## Hook it up with connect_weapon() and connect_projectiles().

@export var flash_time: float = 0.05
@export var flash_size: float = 0.32
@export var flash_color: Color = Color(1.0, 0.8, 0.45)
@export var flash_light_energy: float = 2.5
@export var impact_time: float = 0.09
@export var spark_count: int = 7
@export var spark_speed: float = 6.0
@export var spark_life: float = 0.22
@export var spark_gravity: float = 12.0
@export var world_spark_color: Color = Color(1.0, 0.75, 0.4)
@export var body_spark_color: Color = Color(1.0, 0.95, 0.9)
@export var crit_spark_color: Color = Color(1.0, 0.8, 0.15)
@export var mark_life: float = 6.0
@export var mark_size: float = 0.13
@export var max_marks: int = 128

var player: PlayerCharacter

var _flashes: Array = []   # [eye_offset: Vector3, aim: Vector3, age, size]
var _glows: Array = []     # impact glow: [pos, age, color, size]
var _sparks: Array = []    # [pos, vel, age, color]
var _marks: Array = []     # [transform, age]
var _glow_mm: MultiMesh
var _spark_mm: MultiMesh
var _mark_mm: MultiMesh
var _light: OmniLight3D
var _light_age := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 12345
	_glow_mm = _make_mm(_glow_mesh())
	_spark_mm = _make_mm(_spark_mesh())
	_mark_mm = _make_mm(_mark_mesh())
	_light = OmniLight3D.new()
	_light.light_color = flash_color
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)


func connect_weapon(wc: WeaponController) -> void:
	player = wc.player
	wc.muzzle_fired.connect(_on_muzzle_fired)


func connect_projectiles(ps: ProjectileSystem) -> void:
	ps.world_hit.connect(_on_world_hit)
	ps.bullet_hit.connect(_on_bullet_hit)


func _on_muzzle_fired(_muzzle: Vector3, eye_offset: Vector3, aim: Vector3) -> void:
	_flashes.append([eye_offset, aim, 0.0, flash_size * _rng.randf_range(0.8, 1.2)])
	_light_age = 0.0


func _on_world_hit(point: Vector3, normal: Vector3) -> void:
	_glows.append([point + normal * 0.05, 0.0, world_spark_color, 0.4])
	_burst(point + normal * 0.02, normal, world_spark_color, spark_count)
	if normal.length_squared() > 0.5:
		var z := normal.normalized()
		var x := z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
		var b := Basis(x, z.cross(x), z).rotated(z, _rng.randf() * TAU)
		var s := mark_size * _rng.randf_range(0.8, 1.2)
		_marks.append([Transform3D(b * Basis.from_scale(Vector3(s, s, s)), point + z * 0.004), 0.0])
		if _marks.size() > max_marks:
			_marks.pop_front()


func _on_bullet_hit(info: Dictionary) -> void:
	var crit: bool = info["is_crit"]
	var col := crit_spark_color if crit else body_spark_color
	var p: Vector3 = info["point"]
	var back := -(info["direction"] as Vector3)
	_glows.append([p + back * 0.05, 0.0, col, 0.45 if crit else 0.32])
	_burst(p, back, col, spark_count + (3 if crit else 0))


func _burst(p: Vector3, n: Vector3, col: Color, count: int) -> void:
	for k in count:
		var d := (n + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1.0), _rng.randf_range(-1, 1)) * 0.8).normalized()
		_sparks.append([p, d * spark_speed * _rng.randf_range(0.5, 1.2), 0.0, col])


func _process(delta: float) -> void:
	var eye := player.get_eye_position() if player != null else Vector3.ZERO
	# glow quads: muzzle flashes (riding the rendered player) and impact flashes
	_grow(_glow_mm, _flashes.size() + _glows.size())
	var n := 0
	var k := 0
	while k < _flashes.size():
		var fl: Array = _flashes[k]
		fl[2] += delta
		var left := 1.0 - float(fl[2]) / flash_time
		if left <= 0.0:
			_flashes.remove_at(k)
			continue
		k += 1
		var p: Vector3 = eye + (fl[0] as Vector3) + (fl[1] as Vector3) * 0.12
		var sz := float(fl[3]) * (0.6 + 0.4 * left)
		_glow_mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(sz, sz, sz)), p))
		_glow_mm.set_instance_color(n, flash_color * left)
		n += 1
	k = 0
	while k < _glows.size():
		var g: Array = _glows[k]
		g[1] += delta
		var left := 1.0 - float(g[1]) / impact_time
		if left <= 0.0:
			_glows.remove_at(k)
			continue
		k += 1
		var sz := float(g[3]) * (0.5 + 0.5 * left)
		_glow_mm.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(sz, sz, sz)), g[0]))
		_glow_mm.set_instance_color(n, (g[2] as Color) * left)
		n += 1
	_glow_mm.visible_instance_count = n

	# sparks: short streaks along their velocity, falling
	_grow(_spark_mm, _sparks.size())
	n = 0
	k = 0
	while k < _sparks.size():
		var s: Array = _sparks[k]
		s[2] += delta
		var left := 1.0 - float(s[2]) / spark_life
		if left <= 0.0:
			_sparks.remove_at(k)
			continue
		k += 1
		var v: Vector3 = s[1]
		v += Vector3.DOWN * spark_gravity * delta
		s[1] = v
		s[0] = (s[0] as Vector3) + v * delta
		var sp := v.length()
		var dir := v / sp if sp > 1e-4 else Vector3.UP
		var length := maxf(0.04, sp * 0.03)
		_spark_mm.set_instance_transform(n, Transform3D(ProjectileSystem._streak_basis(dir, 0.025, length), (s[0] as Vector3) - dir * length * 0.5))
		_spark_mm.set_instance_color(n, (s[3] as Color) * left)
		n += 1
	_spark_mm.visible_instance_count = n

	# bullet marks: fade out over their last second
	_grow(_mark_mm, _marks.size())
	n = 0
	k = 0
	while k < _marks.size():
		var m: Array = _marks[k]
		m[1] += delta
		if float(m[1]) > mark_life:
			_marks.remove_at(k)
			continue
		k += 1
		_mark_mm.set_instance_transform(n, m[0])
		_mark_mm.set_instance_color(n, Color(1, 1, 1, clampf(mark_life - float(m[1]), 0.0, 1.0)))
		n += 1
	_mark_mm.visible_instance_count = n

	_light_age += delta
	var lf := maxf(0.0, 1.0 - _light_age / flash_time)
	_light.light_energy = flash_light_energy * lf
	_light.visible = lf > 0.0
	if lf > 0.0 and not _flashes.is_empty():
		_light.global_position = eye + (_flashes[_flashes.size() - 1][0] as Vector3)


func _make_mm(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 64
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)
	return mm


static func _grow(mm: MultiMesh, need: int) -> void:
	if need > mm.instance_count:
		var vis := mm.visible_instance_count
		mm.instance_count = need * 2
		mm.visible_instance_count = vis


static func _radial(inner: Color, outer: Color, size: int = 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _glow_mesh() -> Mesh:
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _radial(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	mat.no_depth_test = false
	q.material = mat
	return q


func _spark_mesh() -> Mesh:
	var b := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	b.material = mat
	return b


func _mark_mesh() -> Mesh:
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _radial(Color(0.05, 0.05, 0.05, 0.9), Color(0.1, 0.1, 0.1, 0.0))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	return q
