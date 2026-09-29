class_name Crosshair
extends Control
## Reticle, stamina arc, ammo count and hit markers (specs/hud.md).
## spec: movement.md §7 stamina bars (full / partial regen / empty).
## spec: movement.md §9 UI cue: the stamina bars flash light blue while the dash-jump window is open.

@export_group("Reticle")
@export var dot_radius: float = 1.5
@export var line_length: float = 6.0
@export var line_gap: float = 5.0
@export var line_width: float = 2.0
@export var color_reticle: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var color_border: Color = Color(0.0, 0.0, 0.0, 0.6)

@export_group("Stamina")
@export var arc_radius: float = 31.0
@export var arc_width: float = 9.0
@export var segment_deg: float = 32.0
@export var segment_gap_px: float = 4.0
@export var color_full: Color = Color("#E0E0E0D9")
@export var color_partial: Color = Color("#E8C040")
@export var color_empty: Color = Color(0.05, 0.05, 0.05, 0.55)
@export var color_window: Color = Color("#6CC8E8")
@export var flash_hz: float = 12.0

@export_group("Ammo")
@export var ammo_font_size: int = 17
@export var color_ammo: Color = Color("#F0F0F0")
@export var color_ammo_max: Color = Color("#A8A8A8")
@export var color_infinite: Color = Color("#7CE08A")
@export var inf_size: float = 26.0
@export var inf_line: float = 3.0
@export var ring_radius: float = 16.0

@export_group("Hit markers")
@export var hit_time: float = 0.15
@export var hit_inner: float = 8.0
@export var hit_outer: float = 14.0
@export var color_hit: Color = Color(1, 1, 1, 1)
@export var color_crit: Color = Color("#F0D020")
@export var color_crit_border: Color = Color("#D02010")

var _player: PlayerCharacter = null
var _weapon: WeaponController = null
var _window_open: bool = false
var _flash_time: float = 0.0
var _hit_age: float = 1e9
var _hit_crit: bool = false
var _inf_age: float = 1e9
var _font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Arial", "Segoe UI", "sans-serif"])
	_font.font_weight = 700


func bind_player(p: PlayerCharacter) -> void:
	if _player != null and is_instance_valid(_player):
		if _player.dash_jump_window.is_connected(_on_dash_jump_window):
			_player.dash_jump_window.disconnect(_on_dash_jump_window)
	_player = p
	_window_open = false
	if _player != null:
		_player.dash_jump_window.connect(_on_dash_jump_window)
	queue_redraw()


## Shows the gun's ammo, reload and spin under the reticle.
func bind_weapon(wc: WeaponController) -> void:
	_weapon = wc


## Flashes a hit marker; crit = headshot style.
func show_hit(crit: bool) -> void:
	# a body hit landing right after a crit keeps the crit marker
	_hit_crit = crit or (_hit_crit and _hit_age < hit_time * 0.5)
	_hit_age = 0.0


func _on_dash_jump_window(open: bool) -> void:
	_window_open = open
	_flash_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _window_open:
		_flash_time += delta
	_hit_age += delta
	var inf := _weapon != null and is_instance_valid(_weapon) and _weapon.wstate != null and _weapon.wstate.infinite_ammo
	_inf_age = _inf_age + delta if inf else 0.0
	queue_redraw()


func _draw() -> void:
	var c := (size * 0.5).round()
	_draw_reticle(c)
	_draw_hit_marker(c)
	_draw_weapon(c)
	_draw_stamina(c)


func _draw_reticle(c: Vector2) -> void:
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a := c + d * line_gap
		var b := c + d * (line_gap + line_length)
		draw_line(a - d, b + d, color_border, line_width + 2.0)
		draw_line(a, b, color_reticle, line_width)
	draw_circle(c, dot_radius + 1.0, color_border)
	draw_circle(c, dot_radius, color_reticle)


func _draw_hit_marker(c: Vector2) -> void:
	if _hit_age >= hit_time:
		return
	var f := 1.0 - _hit_age / hit_time
	var grow := 1.0 + 0.25 * f
	for k in 4:
		var d := Vector2.from_angle(PI * 0.25 + k * PI * 0.5)
		var a := c + d * hit_inner * grow
		var b := c + d * hit_outer * grow
		if _hit_crit:
			draw_line(a - d, b + d, Color(color_crit_border, f), 4.5)
			draw_line(a, b, Color(color_crit, f), 2.0)
		else:
			draw_line(a - d, b + d, Color(color_border, 0.6 * f), 4.0)
			draw_line(a, b, Color(color_hit, f), 2.0)


func _draw_weapon(c: Vector2) -> void:
	if _weapon == null or not is_instance_valid(_weapon) or _weapon.weapon == null:
		return
	var w := _weapon.weapon
	var s := _weapon.wstate
	# reload (guess, specs/hud.md §1.5) and spin-up (§1.4) rings around the reticle
	if s.is_reloading():
		draw_arc(c, ring_radius, 0.0, TAU, 48, color_empty, 3.0)
		var p := clampf(s.reload_progress(w), 0.0, 1.0)
		if p > 0.0:
			draw_arc(c, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * p, 48, color_reticle, 2.0)
	elif w.spins_up and s.spin > 0.0:
		draw_arc(c, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(s.spin, 0.0, 1.0), 48, Color(0.75, 0.75, 0.75, 0.8), 2.0)
	# ammo under the stamina arc: "12 / 30", replaced by ∞ while sliding
	var fs := ammo_font_size
	var y := c.y + arc_radius + arc_width + 6.0 + fs
	if s.infinite_ammo:
		# pops in when the slide starts
		var pop := 1.0 + 0.35 * clampf(1.0 - _inf_age / 0.15, 0.0, 1.0)
		_draw_infinity(Vector2(c.x, y - fs * 0.36), inf_size * pop)
		return
	var cur := "%d" % s.ammo
	var rest := " / %d" % w.clip_size
	var wc := _font.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var wr := _font.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := c.x - (wc + wr) * 0.5
	var ol := 5
	var olc := Color(0, 0, 0, 0.85)
	draw_string_outline(_font, Vector2(x, y), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, olc)
	draw_string(_font, Vector2(x, y), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color_ammo)
	draw_string_outline(_font, Vector2(x + wc, y), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, olc)
	draw_string(_font, Vector2(x + wc, y), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color_ammo_max)


## Lemniscate drawn as a line so it reads at any size, unlike the thin font glyph.
func _draw_infinity(at: Vector2, width: float) -> void:
	var pts := PackedVector2Array()
	var a := width * 0.5
	for k in 41:
		var t := TAU * k / 40.0
		var d := 1.0 + sin(t) * sin(t)
		pts.append(at + Vector2(a * cos(t) / d, 1.5 * a * sin(t) * cos(t) / d))
	draw_polyline(pts, Color(0, 0, 0, 0.85), inf_line + 3.0, true)
	draw_polyline(pts, color_infinite, inf_line, true)


func _draw_stamina(c: Vector2) -> void:
	if _player == null or not is_instance_valid(_player) or _player.state == null:
		return
	var cp := _player.get_compiled_params()
	if cp == null:
		return
	var st := _player.state
	var count := int(ceil(cp.stamina_max(st) - 1e-5))
	if count <= 0:
		return
	# segments spread symmetrically about straight down (+y is down, so PI/2), with a fixed
	# pixel gap between them
	var seg := deg_to_rad(segment_deg)
	var gap := segment_gap_px / arc_radius
	var a0 := PI * 0.5 + (count * seg + (count - 1) * gap) * 0.5
	var flashing := _window_open and fmod(_flash_time * flash_hz, 1.0) < 0.5
	var regen_i := int(floor(st.stamina + 1e-5))
	# fill from screen left (larger angle here) to the right
	for i in count:
		var start := a0 - i * (seg + gap)
		var fill := clampf(st.stamina - float(i), 0.0, 1.0)
		var col := color_window if flashing else color_full
		if fill < 1.0 and i == regen_i:
			fill = maxf(fill, clampf(st.stamina_regen_progress, 0.0, 1.0))
			col = color_window if flashing else color_partial
		draw_colored_polygon(_sector(c, start, start - seg), color_empty)
		if fill > 0.0:
			draw_colored_polygon(_sector(c, start, start - seg * fill), col)


## Annular sector between two angles, ends cut along the radius.
func _sector(c: Vector2, from: float, to: float) -> PackedVector2Array:
	var r0 := arc_radius - arc_width * 0.5
	var r1 := arc_radius + arc_width * 0.5
	var n := maxi(2, ceili(absf(to - from) / 0.05))
	var pts := PackedVector2Array()
	for k in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(from, to, float(k) / n)) * r1)
	for k in n + 1:
		pts.append(c + Vector2.from_angle(lerpf(to, from, float(k) / n)) * r0)
	return pts
