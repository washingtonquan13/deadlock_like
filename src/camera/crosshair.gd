class_name Crosshair
extends Control
## Center dot plus stamina pips (design §9).
## spec: movement.md §7 stamina bars (full / partial regen / empty).
## spec: movement.md §9 UI cue: pips flash light blue while the dash-jump window is open.

@export var dot_radius: float = 2.5
@export var pip_size: Vector2 = Vector2(14.0, 4.0)
@export var pip_gap: float = 4.0
@export var pip_offset_y: float = 22.0
@export var color_dot: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var color_full: Color = Color(0.95, 0.85, 0.35, 0.95)
@export var color_partial: Color = Color(0.95, 0.85, 0.35, 0.55)
@export var color_empty: Color = Color(0.1, 0.1, 0.1, 0.55)
@export var color_window: Color = Color(0.55, 0.85, 1.0, 1.0)   # light blue
@export var flash_hz: float = 12.0

var _player: PlayerCharacter = null
var _window_open: bool = false
var _flash_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func bind_player(p: PlayerCharacter) -> void:
	if _player != null and is_instance_valid(_player):
		if _player.dash_jump_window.is_connected(_on_dash_jump_window):
			_player.dash_jump_window.disconnect(_on_dash_jump_window)
	_player = p
	_window_open = false
	if _player != null:
		_player.dash_jump_window.connect(_on_dash_jump_window)
	queue_redraw()


func _on_dash_jump_window(open: bool) -> void:
	_window_open = open
	_flash_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _window_open:
		_flash_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, dot_radius, color_dot)
	if _player == null or not is_instance_valid(_player) or _player.state == null:
		return
	var cp := _player.get_compiled_params()
	if cp == null:
		return
	var st := _player.state
	var max_bars := cp.stamina_max(st)
	var pip_count := int(ceil(max_bars - 1e-5))
	if pip_count <= 0:
		return
	var total_w := pip_count * pip_size.x + (pip_count - 1) * pip_gap
	var x0 := center.x - total_w * 0.5
	var y0 := center.y + pip_offset_y
	# flash on/off at flash_hz while the dash-jump window is open
	var flashing := _window_open and fmod(_flash_time * flash_hz, 1.0) < 0.5
	for i in pip_count:
		var r := Rect2(Vector2(x0 + i * (pip_size.x + pip_gap), y0), pip_size)
		draw_rect(r, color_empty)
		var fill := clampf(st.stamina - float(i), 0.0, 1.0)
		if fill < 1.0 and i == int(floor(st.stamina + 1e-5)):
			# the one bar currently regenerating (spec §7: one bar regens at a time)
			fill = maxf(fill, clampf(st.stamina_regen_progress, 0.0, 1.0))
			if fill > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)),
					color_window if flashing else color_partial)
			continue
		if fill > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)),
				color_window if flashing else color_full)
		elif flashing:
			draw_rect(r, color_window, false, 1.0)
