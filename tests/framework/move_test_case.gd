class_name MoveTestCase
extends RefCounted
## Base class for headless movement tests (design §12). Every method named test_* is run by
## tests/run_tests.gd. A test must call done() as its last statement; a test that never reaches
## done() (script error, early return) is reported as FAIL.

const L := MoveState.Loco
const B_JUMP := InputCmd.BTN_JUMP
const B_CROUCH := InputCmd.BTN_CROUCH
const B_DASH := InputCmd.BTN_DASH
const B_FIRE := InputCmd.BTN_FIRE
const B_PARRY := InputCmd.BTN_PARRY
const B_ABILITY := InputCmd.BTN_ABILITY

var tree: SceneTree
var harness: SimHarness
var failures: PackedStringArray = PackedStringArray()
var completed: bool = false
## Most dash tests predate the measured neutral-dash rule and press dash with no move input to mean
## "dash toward facing" (spec §8). new_harness keeps that rule unless a test sets this to true.
var measured_neutral_dash: bool = false


func before_each() -> void:
	pass


func after_each() -> void:
	if harness != null:
		harness.free_all()
		harness = null


## Frees the previous harness (if any) and creates a new one. Follow with `await harness.ready()`.
func new_harness(layout: StringName = &"flat", params: MovementParams = null, hero: HeroMovementStats = null) -> SimHarness:
	if harness != null:
		harness.free_all()
	if params == null:
		params = MovementParams.new()
	params.neutral_dash_does_nothing = measured_neutral_dash
	harness = SimHarness.create(tree, layout, params, hero)
	return harness


func done() -> void:
	completed = true


# --- assertions ---------------------------------------------------------------------

func fail(msg: String) -> void:
	failures.append(msg)


func assert_true(c: bool, msg: String) -> void:
	if not c:
		fail(msg)


func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	if typeof(a) != typeof(b) and not (typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]):
		fail("%s: expected %s (%s) got %s (%s)" % [msg, str(b), type_string(typeof(b)), str(a), type_string(typeof(a))])
	elif a != b:
		fail("%s: expected %s got %s" % [msg, str(b), str(a)])


func assert_near(a: float, b: float, eps: float, msg: String) -> void:
	if is_nan(a) or not (absf(a - b) <= eps):
		fail("%s: expected %.6f got %.6f (eps %s)" % [msg, b, a, eps])


func assert_vec_near(a: Vector3, b: Vector3, eps: float, msg: String) -> void:
	if not (a.distance_to(b) <= eps):
		fail("%s: expected %s got %s (eps %s)" % [msg, str(b), str(a), eps])


# --- helpers ------------------------------------------------------------------------

static func cmd(t: int, buttons: int = 0, mx: int = 0, my: int = 0, yaw: float = 0.0) -> InputCmd:
	return InputCmd.create(t, buttons, mx, my, yaw, 0.0)


## Callable holding the same buttons and move input every tick.
static func hold(buttons: int = 0, mx: int = 0, my: int = 0, yaw: float = 0.0) -> Callable:
	return func(t: int) -> InputCmd: return InputCmd.create(t, buttons, mx, my, yaw, 0.0)


## Hero stats with a dash bucket and gravity scale.
static func hero_with(bucket: int = 1, gravity_scale: float = 1.0) -> HeroMovementStats:
	var h := HeroMovementStats.new()
	h.dash_bucket = bucket
	h.gravity_scale = gravity_scale
	return h


## Params with the pre-measurement air dash (G01 Hyp A cap, V8 (a) end drag) for tests that pin that model.
static func legacy_air_dash(p: MovementParams = null) -> MovementParams:
	if p == null:
		p = MovementParams.new()
	p.air_dash_cap_mode = 1
	p.air_dash_end_drag_mode = 1
	p.air_dash_keeps_air_drag = false
	return p


static func count_loco(tr: Array[Dictionary], loco: int) -> int:
	var n := 0
	for e in tr:
		if int(e["loco"]) == loco:
			n += 1
	return n


## Index of the first trace entry with `loco`, or -1.
static func first_loco(tr: Array[Dictionary], loco: int, from: int = 0) -> int:
	for i in range(from, tr.size()):
		if int(tr[i]["loco"]) == loco:
			return i
	return -1


## Index of the first trace entry holding an event of `type` (optionally with payload key == value).
static func first_event(tr: Array[Dictionary], type: StringName, key: String = "", value: Variant = null, from: int = 0) -> int:
	for i in range(from, tr.size()):
		for ev in tr[i]["events"]:
			if StringName(ev.get("type", &"")) != type:
				continue
			if key == "" or ev.get(key) == value:
				return i
	return -1


static func has_event(entry: Dictionary, type: StringName, key: String = "", value: Variant = null) -> bool:
	for ev in entry["events"]:
		if StringName(ev.get("type", &"")) == type and (key == "" or ev.get(key) == value):
			return true
	return false


## Feet height that rests a capsule of `radius` on a plane sloped `angle_deg` (plus a small gap).
static func slope_rest_offset(radius: float, angle_deg: float) -> float:
	return radius * (1.0 / cos(deg_to_rad(angle_deg)) - 1.0) + 0.005


## Scripted 600-tick input used by the determinism and serialization tests (T29, T30):
## walking, jump, dash, dash-jump, air dash, landing slide, dash slide, air jump, strafing.
static func demo_cmd(t: int) -> InputCmd:
	var b := 0
	var mx := 0
	var my := 0
	var yaw := 0.0
	if t <= 100:
		my = 1
		yaw = 0.002 * float(t)
	elif t <= 149:
		my = 1
		yaw = 0.2
		if t == 101:
			b |= B_JUMP
	elif t <= 229:
		my = 1
		yaw = 0.2
		if t == 150:
			b |= B_DASH
		if t == 171:
			b |= B_JUMP          # k = 20 completed dash ticks: dash-jump
		if t == 185:
			b |= B_DASH          # air dash
	elif t <= 300:
		my = 1
		yaw = 0.2 - 0.004 * float(t - 229)
		b |= B_CROUCH            # landing / slope slide, then crouch walk
	elif t <= 429:
		my = 1
		yaw = -0.1
		if t == 320:
			b |= B_DASH
		if t >= 330 and t <= 420:
			b |= B_CROUCH        # dash slide
	elif t <= 459:
		my = 1
		mx = 1
		yaw = -0.1
		if t == 430 or t == 440:
			b |= B_JUMP          # jump, then air jump
	else:
		my = 1
		mx = 1 if (t / 20) % 2 == 0 else -1
		yaw = -0.1 + 0.3 * sin(float(t) * 0.05)
		if t == 500:
			b |= B_JUMP
		if t == 520:
			b |= B_DASH
	return InputCmd.create(t, b, mx, my, yaw, 0.0)
