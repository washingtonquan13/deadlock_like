class_name InputSampler
extends Node
## Turns local devices into one InputCmd per sim tick (design §9, §6).
## Reads the Input singleton for held state and InputEvents for mouse look and tap latches.
## Never touches MoveState; the sim derives button edges from held bits (design §2 #4).

@export var mouse_sensitivity: float = 0.0022   # rad per pixel
@export var invert_y: bool = false
@export var heavy_hold_time: float = 0.2        # s; Q held this long = heavy melee (design §5; session 11 measured ~13-14 ticks)

const PITCH_LIMIT := deg_to_rad(89.0)           # matches InputCmd pitch clamp

## Plain held-button actions -> InputCmd bits. Melee is handled separately (tap vs hold).
const ACTION_BITS := {
	&"jump": InputCmd.BTN_JUMP,
	&"crouch": InputCmd.BTN_CROUCH,
	&"dash": InputCmd.BTN_DASH,
	&"fire": InputCmd.BTN_FIRE,
	&"reload": InputCmd.BTN_RELOAD,
	&"parry": InputCmd.BTN_PARRY,
	&"ability_1": InputCmd.BTN_ABILITY,
	&"zipline_boost": InputCmd.BTN_ZIP_BOOST,
}

var _yaw: float = 0.0
var _pitch: float = 0.0
var _mouse_captured: bool = false
## A menu (the shop) owns the cursor: mouse buttons go to the UI, not to firing or recapture.
var ui_open: bool = false

## Tap latch: any press seen since the last build_cmd is ORed into that cmd's held bits.
var _latched: int = 0

# melee tap/hold tracking (design §5; spec: combat.md melee light vs heavy)
var _q_down: bool = false
var _q_down_usec: int = 0
var _q_heavy_emitted: bool = false
var _direct_heavy_down: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# drop stale key state so nothing sticks while alt-tabbed
		_q_down = false
		_q_heavy_emitted = false
		_direct_heavy_down = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _mouse_captured:
			var rel := (event as InputEventMouseMotion).relative
			# positive yaw turns left (design §3), so mouse right decreases yaw
			_yaw = fposmod(_yaw - rel.x * mouse_sensitivity, TAU)
			var dy := rel.y * mouse_sensitivity
			_pitch = clampf(_pitch + (dy if invert_y else -dy), -PITCH_LIMIT, PITCH_LIMIT)
		return

	if event.is_echo():
		return

	if event.is_action_pressed(&"toggle_mouse_capture") and not ui_open:
		set_mouse_captured(not _mouse_captured)
		get_viewport().set_input_as_handled()
		return

	if ui_open and event is InputEventMouseButton:
		return

	# a click while released recaptures the mouse instead of firing
	if not _mouse_captured and event is InputEventMouseButton and event.is_pressed():
		set_mouse_captured(true)
		get_viewport().set_input_as_handled()
		return

	for action: StringName in ACTION_BITS:
		if event.is_action_pressed(action):
			_latched |= int(ACTION_BITS[action])

	# Q is bound to both melee_light and melee_heavy; melee_light identifies Q itself.
	if event.is_action(&"melee_light"):
		if event.is_pressed():
			_q_down = true
			_q_down_usec = Time.get_ticks_usec()
			_q_heavy_emitted = false
		elif _q_down:
			_q_down = false
			if not _q_heavy_emitted:
				# released before heavy_hold_time -> light tap, latched for the next cmd
				_latched |= InputCmd.BTN_MELEE_LIGHT
			_q_heavy_emitted = false
	elif event.is_action(&"melee_heavy"):
		# direct heavy binding (Mouse Button 5)
		_direct_heavy_down = event.is_pressed()
		if _direct_heavy_down:
			_latched |= InputCmd.BTN_MELEE_HEAVY


## Returns the cmd for `tick` and clears the tap latches.
func build_cmd(tick: int) -> InputCmd:
	var buttons := _latched
	for action: StringName in ACTION_BITS:
		if Input.is_action_pressed(action):
			buttons |= int(ACTION_BITS[action])

	if _q_down and not _q_heavy_emitted:
		if float(Time.get_ticks_usec() - _q_down_usec) / 1_000_000.0 >= heavy_hold_time:
			_q_heavy_emitted = true
	if (_q_down and _q_heavy_emitted) or _direct_heavy_down:
		buttons |= InputCmd.BTN_MELEE_HEAVY

	var r := Input.is_action_pressed(&"move_right")
	var l := Input.is_action_pressed(&"move_left")
	var f := Input.is_action_pressed(&"move_forward")
	var b := Input.is_action_pressed(&"move_back")
	var move_x := int(r) - int(l)
	var move_y := int(f) - int(b)
	# spec: movement.md §3 holding opposing inputs resets sprint (the axis alone cancels to 0)
	if r and l:
		buttons |= InputCmd.BTN_OPPOSE_X
	if f and b:
		buttons |= InputCmd.BTN_OPPOSE_Y

	if ui_open:
		buttons &= ~InputCmd.BTN_FIRE
	_latched = 0
	return InputCmd.create(tick, buttons, move_x, move_y, _yaw, _pitch)


## Unquantized view yaw for the camera (radians, [0, TAU)).
func get_view_yaw() -> float:
	return _yaw


## Unquantized view pitch for the camera (radians, clamped to +-89 deg).
func get_view_pitch() -> float:
	return _pitch


func set_view(yaw: float, pitch: float) -> void:
	_yaw = fposmod(yaw, TAU)
	_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)


func set_mouse_captured(on: bool) -> void:
	_mouse_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return _mouse_captured
