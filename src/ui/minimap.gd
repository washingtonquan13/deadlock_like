class_name Minimap
extends Control
## Bottom-right minimap (specs/hud.md), north (-Z) up. Draws the layout's baked terrain image
## (when it has one), top-down footprints of every box collider, zipline routes, the layout's
## icons, and the player with a view cone from the camera. M toggles a large centred view.
## Works for any MovementArena layout; the rect comes from info["minimap"] or a default.
## Boxes tagged with meta "minimap" = &"roof" draw translucent, &"skip" not at all. Terrain and
## footprints sit on a child layer that only redraws when the size changes.

const SMALL := 260.0
const LARGE := 820.0
const MARGIN := 16.0
const TEAM_COLORS: Array[Color] = [Color("3cc6d0"), Color("f0913a")]
const C_NEUTRAL := Color(0.95, 0.8, 0.3)
const C_BG := Color(0.2, 0.22, 0.23)

var arena: MovementArena
var player: Node3D
var large := false

var _rect := Rect2(-100, -100, 200, 200)
var _tex: Texture2D
var _icons: Array = []
var _boxes: Array = []      # [PackedVector2Array world corners, Color]
var _rails: Array = []      # PackedVector2Array world points
var _name := ""
var _font: Font
var _static: Control


func bind(p_arena: MovementArena, p_player: Node3D) -> void:
	arena = p_arena
	player = p_player
	if arena == null:
		return
	var mm: Dictionary = arena.info.get("minimap", {})
	_rect = mm.get("rect", _rect)
	_icons = mm.get("icons", [])
	_name = mm.get("name", "")
	var img: Image = mm.get("image")
	if img != null:
		_tex = ImageTexture.create_from_image(img)
	_collect_geometry()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = ThemeDB.fallback_font
	_static = Control.new()
	_static.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static.show_behind_parent = true
	_static.draw.connect(_draw_static)
	_static.resized.connect(_static.queue_redraw)
	add_child(_static)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		large = not large
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	if large:
		var s := minf(LARGE, vp.y - 60.0)
		size = Vector2(s, s)
		position = (vp - size) * 0.5
	else:
		size = Vector2(SMALL, SMALL)
		position = vp - size - Vector2(MARGIN, MARGIN)
	_static.size = size
	queue_redraw()


## World xz to local pixels.
func to_map(p: Vector2) -> Vector2:
	return (p - _rect.position) / _rect.size * size


func _collect_geometry() -> void:
	for body in arena.find_children("*", "StaticBody3D", true, false):
		var sb := body as StaticBody3D
		var tag: StringName = sb.get_meta(&"minimap", &"")
		if tag == &"skip":
			continue
		for cs in sb.get_children():
			if not (cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D):
				continue
			var bs := (cs as CollisionShape3D).shape as BoxShape3D
			var xf := (cs as CollisionShape3D).global_transform
			var h := bs.size * 0.5
			var top := xf.origin.y + h.y
			if top < -2.0:
				continue                                          # underground furniture
			var poly := PackedVector2Array()
			for c: Vector3 in [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]:
				var w := xf * c
				poly.append(Vector2(w.x, w.z))
			# taller buildings read darker
			var col := Color(0.36, 0.37, 0.40).lerp(Color(0.12, 0.13, 0.16), clampf(top / 45.0, 0.0, 1.0))
			col.a = 0.9
			if tag == &"roof":
				col = Color(0.62, 0.62, 0.66, 0.4)                # over tunnels: show what's below
			elif bs.size.y < 1.0:
				col = Color(0.62, 0.58, 0.48)                     # decks
			elif bs.size.x * bs.size.z > 1500.0:
				col = Color(0.5, 0.52, 0.5) if _tex != null else Color(0.42, 0.44, 0.45)   # plateaus, floors
			_boxes.append([poly, col])
	for z in arena.find_children("*", "Zipline", true, false):
		var zl := z as Zipline
		if zl.curve == null or zl.curve.point_count < 2:
			continue
		var pts := PackedVector2Array()
		if zl.use_points:
			for i in zl.curve.point_count:
				var w := zl.global_transform * zl.curve.get_point_position(i)
				pts.append(Vector2(w.x, w.z))
		else:
			var total := zl.curve.get_baked_length()
			var n := maxi(1, ceili(total / 4.0))
			for i in n + 1:
				var w := zl.global_transform * zl.curve.sample_baked(total * i / n)
				pts.append(Vector2(w.x, w.z))
		_rails.append(pts)


func _draw_static() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_static.draw_rect(r, C_BG)
	if _tex != null:
		_static.draw_texture_rect(_tex, r, false)
	for b in _boxes:
		var poly := PackedVector2Array()
		for p: Vector2 in b[0]:
			poly.append(to_map(p))
		_static.draw_colored_polygon(poly, b[1])
	for pts: PackedVector2Array in _rails:
		var line := PackedVector2Array()
		for p in pts:
			line.append(to_map(p))
		_static.draw_polyline(line, Color(1, 1, 1, 0.55), 1.5 if large else 1.0)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var k := size.x / SMALL
	for ic: Dictionary in _icons:
		_draw_icon(ic, k)
	_draw_player(k)
	draw_rect(r, Color(1, 1, 1, 0.35), false, 1.0)
	if large:
		_text("%s   (M close, F9 next map)" % _name, Vector2(8, 22), 16)
	elif _name != "":
		_text(_name, Vector2(6, 16), 12)


func _draw_icon(ic: Dictionary, k: float) -> void:
	var p := to_map(ic["pos"])
	var team: int = ic.get("team", -1)
	var col := TEAM_COLORS[team] if team >= 0 else C_NEUTRAL
	match ic["kind"]:
		&"patron":
			_square(p, 6.0 * k, col)
		&"shrine", &"walker":
			_square(p, 4.5 * k, col)
		&"guardian", &"base_guardian":
			_square(p, 3.0 * k, col)
		&"shop":
			_diamond(p, 3.5 * k, col.lerp(C_NEUTRAL, 0.6))
		&"secret_shop":
			_diamond(p, 5.0 * k, C_NEUTRAL)
		&"camp_small":
			draw_circle(p, 2.0 * k, Color(0.9, 0.8, 0.4, 0.9))
		&"camp_medium":
			draw_circle(p, 2.8 * k, Color(0.9, 0.7, 0.3, 0.9))
		&"camp_large":
			draw_circle(p, 3.6 * k, Color(0.95, 0.55, 0.25, 0.9))
		&"boss":
			draw_circle(p, 5.0 * k, Color(0.7, 0.4, 0.9))
			draw_arc(p, 5.0 * k, 0, TAU, 20, Color.BLACK, 1.0)
		&"powerup":
			draw_circle(p, 3.0 * k, Color(0.3, 0.95, 0.95))
		&"spawn":
			draw_arc(p, 5.0 * k, 0, TAU, 20, col, 2.0)


func _draw_player(k: float) -> void:
	if player == null:
		return
	var pos := player.global_position
	var p := to_map(Vector2(pos.x, pos.z))
	var fwd := Vector2(0, -1)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := -cam.global_basis.z
		if Vector2(f.x, f.z).length() > 1e-3:
			fwd = Vector2(f.x, f.z).normalized()
	# view cone
	var reach := 26.0 * k
	var half := deg_to_rad(40.0)
	var cone := PackedVector2Array([p])
	for i in 9:
		cone.append(p + fwd.rotated(-half + 2.0 * half * i / 8.0) * reach)
	draw_colored_polygon(cone, Color(1, 1, 1, 0.18))
	var side := Vector2(-fwd.y, fwd.x)
	var s := 5.0 * maxf(1.0, k * 0.8)
	var tri := PackedVector2Array([p + fwd * s * 1.4, p - fwd * s * 0.8 + side * s * 0.9, p - fwd * s * 0.8 - side * s * 0.9])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.BLACK, 1.0)


func _square(p: Vector2, h: float, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), col)
	draw_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), Color.BLACK, false, 1.0)


func _diamond(p: Vector2, h: float, col: Color) -> void:
	var d := PackedVector2Array([p + Vector2(0, -h), p + Vector2(h, 0), p + Vector2(0, h), p + Vector2(-h, 0)])
	draw_colored_polygon(d, col)
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color.BLACK, 1.0)


func _text(t: String, pos: Vector2, fs: int) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
