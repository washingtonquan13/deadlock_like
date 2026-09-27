class_name SpeedGraph
extends Control
## Rolling speed plot for the movement debug overlay (design §10).
## Horizontal speed is the main line and vertical speed the second line. Loco changes are
## vertical ticks. Guide lines mark the spec thresholds:
##   2.0 m/s   slow floor            (spec: movement.md §5)
##   4.8 m/s   crouch speed / slide exit (spec: movement.md §6, §13)
##   8.89 m/s  slide entry speed     (spec: movement.md §13)
##   11.43 m/s air strafe threshold  (spec: movement.md §12)
## The x axis is sim ticks, not frame time, so pausing and single-stepping draw correctly.

const TICK_RATE := 64
const GUIDES: Array[float] = [2.0, 4.8, 8.89, 11.43]
## Share of the plot height given to negative vertical speed (below the zero line).
const NEG_FRACTION := 0.25

@export var window_seconds: float = 5.0
@export var max_speed: float = 25.0

@export var color_background: Color = Color(0.05, 0.06, 0.08, 0.72)
@export var color_h_speed: Color = Color(0.35, 0.85, 1.0)
@export var color_v_speed: Color = Color(1.0, 0.7, 0.3, 0.85)
@export var color_guide: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var color_zero: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var color_loco_tick: Color = Color(0.7, 1.0, 0.5, 0.6)

var _ticks: PackedInt32Array = PackedInt32Array()
var _h: PackedFloat32Array = PackedFloat32Array()
var _v: PackedFloat32Array = PackedFloat32Array()
var _loco: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(420, 140)


func push_sample(tick: int, h_speed: float, v_speed: float, loco: int) -> void:
	# A tick that goes backwards (resim, state reload) invalidates the history.
	if not _ticks.is_empty() and tick <= _ticks[_ticks.size() - 1]:
		clear()
	_ticks.append(tick)
	_h.append(h_speed)
	_v.append(v_speed)
	_loco.append(loco)
	var window := _window_ticks()
	var drop := 0
	while drop < _ticks.size() and _ticks[drop] < tick - window:
		drop += 1
	if drop > 0:
		_ticks = _ticks.slice(drop)
		_h = _h.slice(drop)
		_v = _v.slice(drop)
		_loco = _loco.slice(drop)
	queue_redraw()


func clear() -> void:
	_ticks.clear()
	_h.clear()
	_v.clear()
	_loco.clear()
	queue_redraw()


func _window_ticks() -> int:
	return maxi(1, roundi(window_seconds * TICK_RATE))


## Maps a speed to a y pixel. Zero sits NEG_FRACTION above the bottom; positive speeds use the
## rest of the height up to max_speed; negative vertical speeds clamp at -max_speed*NEG_FRACTION.
func _y_for(speed: float) -> float:
	var h := size.y
	var zero_y := h * (1.0 - NEG_FRACTION)
	var top := maxf(0.001, max_speed)
	var clamped := clampf(speed, -top * NEG_FRACTION / (1.0 - NEG_FRACTION), top)
	return zero_y - clamped / top * zero_y


func _x_for(tick: int, last_tick: int) -> float:
	var window := float(_window_ticks())
	return size.x * (1.0 - float(last_tick - tick) / window)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, color_background, true)
	var font := get_theme_default_font()
	var fsize := 11

	# Guide lines with labels.
	for g in GUIDES:
		var gy := _y_for(g)
		draw_line(Vector2(0.0, gy), Vector2(size.x, gy), color_guide, 1.0)
		if font != null:
			draw_string(font, Vector2(3.0, gy - 2.0), "%.2f" % g, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color_guide * Color(1, 1, 1, 2.5))
	var zy := _y_for(0.0)
	draw_line(Vector2(0.0, zy), Vector2(size.x, zy), color_zero, 1.0)

	if _ticks.size() < 1:
		return
	var last := _ticks[_ticks.size() - 1]

	# Loco change ticks, with the new state's short name.
	for i in range(1, _ticks.size()):
		if _loco[i] != _loco[i - 1]:
			var lx := _x_for(_ticks[i], last)
			draw_line(Vector2(lx, 0.0), Vector2(lx, size.y), color_loco_tick, 1.0)
			if font != null:
				draw_string(font, Vector2(lx + 2.0, fsize + 1.0), _loco_short(_loco[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize - 1, color_loco_tick)

	if _ticks.size() < 2:
		return
	var hp := PackedVector2Array()
	var vp := PackedVector2Array()
	hp.resize(_ticks.size())
	vp.resize(_ticks.size())
	for i in _ticks.size():
		var x := _x_for(_ticks[i], last)
		hp[i] = Vector2(x, _y_for(_h[i]))
		vp[i] = Vector2(x, _y_for(_v[i]))
	draw_polyline(vp, color_v_speed, 1.0)
	draw_polyline(hp, color_h_speed, 2.0)

	if font != null:
		var legend := "h %.2f  v %.2f m/s" % [_h[_h.size() - 1], _v[_v.size() - 1]]
		draw_string(font, Vector2(size.x - 150.0, size.y - 4.0), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.8))


static func _loco_short(loco: int) -> String:
	var keys: Array = MoveState.Loco.keys()
	if loco < 0 or loco >= keys.size():
		return "?"
	var n: String = keys[loco]
	return n.substr(0, 6)
