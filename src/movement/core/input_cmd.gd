class_name InputCmd
extends RefCounted
## One tick of player intent. Carries HELD bits only; the sim derives edges.
## spec: movement.md §1 (fixed 64 Hz tick); design §6.

const BTN_JUMP          := 1 << 0
const BTN_CROUCH        := 1 << 1
const BTN_DASH          := 1 << 2
const BTN_FIRE          := 1 << 3
const BTN_MELEE_LIGHT   := 1 << 4
const BTN_MELEE_HEAVY   := 1 << 5
const BTN_PARRY         := 1 << 6
const BTN_ABILITY       := 1 << 7   # any ability cast; cancels dash-jump window (spec: movement.md §9)
const BTN_ZIP_BOOST     := 1 << 8
const BTN_OPPOSE_X      := 1 << 9   # left+right both held (spec: movement.md §3 opposing inputs reset sprint)
const BTN_OPPOSE_Y      := 1 << 10  # forward+back both held (spec: movement.md §3)
const BTN_RELOAD        := 1 << 11  # gun only; movement ignores it (docs/design/gun_system_plan.md)
const BTN_MASK          := 0x0FFF

const ANGLE_STEPS := 65536          # 1/65536 turn
const PITCH_LIMIT_STEPS := 16201    # floor(89 deg / 360 * 65536)

var tick: int = 0                   # sim tick this cmd is for
var buttons: int = 0                # HELD bits (edges derived by the sim)
var move_x: int = 0                 # -1 left, 0, +1 right
var move_y: int = 0                 # -1 back, 0, +1 forward
var yaw: float = 0.0                # radians, quantized, wrapped to [0, TAU)
var pitch: float = 0.0              # radians, quantized, clamped to [-89 deg, +89 deg]


static func create(p_tick: int, p_buttons: int, p_move_x: int, p_move_y: int, p_yaw: float, p_pitch: float) -> InputCmd:
	var c := InputCmd.new()
	c.tick = p_tick
	c.buttons = p_buttons & BTN_MASK
	c.move_x = clampi(p_move_x, -1, 1)
	c.move_y = clampi(p_move_y, -1, 1)
	c.yaw = quantize_yaw(p_yaw)
	c.pitch = quantize_pitch(p_pitch)
	return c


static func _yaw_steps(rad: float) -> int:
	return posmod(roundi(rad / TAU * ANGLE_STEPS), ANGLE_STEPS)


static func _pitch_steps(rad: float) -> int:
	return clampi(roundi(rad / TAU * ANGLE_STEPS), -PITCH_LIMIT_STEPS, PITCH_LIMIT_STEPS)


static func quantize_yaw(rad: float) -> float:
	return float(_yaw_steps(rad)) * TAU / ANGLE_STEPS


static func quantize_pitch(rad: float) -> float:
	return float(_pitch_steps(rad)) * TAU / ANGLE_STEPS


func is_held(bit: int) -> bool:
	return (buttons & bit) != 0


## World-space wish direction from this cmd's yaw. Forward is -Z.
func wish_dir() -> Vector3:
	return wish_dir_for(move_x, move_y, yaw)


static func wish_dir_for(mx: int, my: int, p_yaw: float) -> Vector3:
	if mx == 0 and my == 0:
		return Vector3.ZERO
	var d := Basis(Vector3.UP, p_yaw) * Vector3(float(mx), 0.0, -float(my))
	d.y = 0.0
	return d.normalized()


func duplicate_cmd() -> InputCmd:
	var c := InputCmd.new()
	c.tick = tick
	c.buttons = buttons
	c.move_x = move_x
	c.move_y = move_y
	c.yaw = yaw
	c.pitch = pitch
	return c


func to_bytes() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(12)
	b.encode_u32(0, tick & 0xFFFFFFFF)
	b.encode_u16(4, buttons & 0xFFFF)
	b.encode_s8(6, move_x)
	b.encode_s8(7, move_y)
	b.encode_u16(8, _yaw_steps(yaw))
	b.encode_s16(10, _pitch_steps(pitch))
	return b


static func from_bytes(b: PackedByteArray) -> InputCmd:
	var c := InputCmd.new()
	if b.size() < 12:
		push_warning("InputCmd.from_bytes: need 12 bytes, got %d" % b.size())
		return c
	c.tick = b.decode_u32(0)
	c.buttons = b.decode_u16(4) & BTN_MASK
	c.move_x = clampi(b.decode_s8(6), -1, 1)
	c.move_y = clampi(b.decode_s8(7), -1, 1)
	c.yaw = float(b.decode_u16(8)) * TAU / ANGLE_STEPS
	c.pitch = float(b.decode_s16(10)) * TAU / ANGLE_STEPS
	return c


func equals(other: InputCmd) -> bool:
	if other == null:
		return false
	return tick == other.tick and buttons == other.buttons and move_x == other.move_x \
		and move_y == other.move_y and _yaw_steps(yaw) == _yaw_steps(other.yaw) \
		and _pitch_steps(pitch) == _pitch_steps(other.pitch)
