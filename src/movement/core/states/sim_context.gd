extends RefCounted
## Per-tick scratch data shared by the state helpers. Never stored in MoveState.

var cmd: InputCmd
var tick_no: int = 0              # tick being produced (state.tick + 1)
var held: int = 0                 # held buttons after lock masking
var pressed: int = 0              # pressed edges after lock masking
var released: int = 0
var raw_pressed: int = 0          # pressed edges before masking
var mask: int = 0                 # active ControlLocks mask
var move_x: int = 0
var move_y: int = 0
var wish: Vector3 = Vector3.ZERO  # world-space wish dir (ZERO when MOVE locked or no input)
var has_move: bool = false
var firing: bool = false
var grounded_start: bool = false
var loco_start: int = 0
var stamina_start: float = 0.0
var stamina_max_start: float = 0.0
var prev_yaw: float = 0.0
var frac: float = 1.0             # fraction of the tick simulated (dash last tick)
var gravity_applied: bool = false # first gravity half-step applied this tick
var skip_move: bool = false       # position set by a scripted state
var zero_h_after_move: bool = false
var sprint_reset: bool = false    # sprint was reset this tick (skip timer increment)
var sprint_reset_reason: StringName = &""


func is_pressed(bit: int) -> bool:
	return (pressed & bit) != 0


func is_held(bit: int) -> bool:
	return (held & bit) != 0


func is_released(bit: int) -> bool:
	return (released & bit) != 0
