class_name MoveState
extends RefCounted
## Plain serializable movement state (design §7.2). Every field is public; tests may set any field.

enum Loco { GROUND, CROUCH, SLIDE, AIR, GROUND_DASH, AIR_DASH, DOWN_DASH, MANTLE, ZIPLINE, ROPE, HEAVY_LUNGE, FORCED }
enum LungePhase { WINDUP, LUNGE, RECOVERY }
enum SlideKind { NORMAL, DASH, DASH_JUMP, AIR }
const CHEAT_INFINITE_STAMINA := 1
const CHEAT_NO_COOLDOWNS := 2

var tick: int = 0
var loco: int = Loco.GROUND
var phase: int = 0                     # sub-phase (LungePhase for HEAVY_LUNGE)
var state_ticks: int = 0               # ticks spent in current loco
var position: Vector3 = Vector3.ZERO   # feet (capsule bottom) in meters
var velocity: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var grounded: bool = true
var ground_normal: Vector3 = Vector3.UP
var crouched: bool = false             # crouch capsule active
var prev_buttons: int = 0
var prev_wish: Vector3 = Vector3.ZERO   # last tick's world wish dir (the air jump reads it; measured session 5)
var prev_wish_raw: Vector3 = Vector3.ZERO   # same, unnormalized key vector in world space (diagonal length sqrt2; session 6)
# stamina (spec: movement.md §7)
var stamina: float = 3.0
var stamina_regen_progress: float = 0.0
var combat_regen_penalty_ticks: int = 0
# per-airtime counters
var air_jumps_used: int = 0
var air_dashes_used: int = 0
var down_dashes_used: int = 0
var wall_jumps_done: int = 0
var wall_fatigue: float = 0.0
var airborne_ticks: int = 0
# sprint (spec: movement.md §3)
var sprint_timer_ticks: int = 0
var sprint_active: bool = false
var sprint_bonus_current: float = 0.0
# dash (spec: movement.md §8, §9, §11)
var dash_ticks: int = 0
var dash_total_ticks: int = 0
var dash_last_fraction: float = 1.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_speed: float = 0.0
var dash_crouch_stored: bool = false
var dash_jump_bonus_ticks: int = 0
# slide (spec: movement.md §13)
var slide_ticks: int = 0
var slide_kind: int = SlideKind.NORMAL
var slide_from_ground: bool = false   # started by a crouch press in GROUND/CROUCH (own penalty onset; session 7)
# down dash detection
var last_air_crouch_press_tick: int = -1
# mantle (spec: movement.md §15)
var mantle_from: Vector3 = Vector3.ZERO
var mantle_to: Vector3 = Vector3.ZERO
var mantle_contact: Vector3 = Vector3.ZERO   # where the capsule meets the face; reached by the end of the climb (session 5)
var mantle_total_ticks: int = 0
var mantle_climb_speed: float = 0.0          # m/s, set at mantle start from the ledge height
var mantle_glide: bool = false
# zipline / rope (spec: movement.md §16, §17)
var zip_rail_id: int = -1
var zip_s: float = 0.0
var zip_dir: int = 1
var zip_ride_ticks: int = 0
var zip_attach_lockout_ticks: int = 0
var zip_exit_momentum_ticks: int = 0
var zip_exit_drag_active: bool = false       # G46: zip exit drag (zip_exit_drag) applies after the zero-drag window until landing
var zip_boost_ticks: int = 0
var rope_id: int = -1
var rope_s: float = 0.0
# melee / parry (spec: movement.md §19)
var heavy_cooldown_ticks: int = 0
var parry_ticks: int = 0
var parry_cooldown_ticks: int = 0
# forced motion
var forced_velocity: Vector3 = Vector3.ZERO
var forced_ticks: int = 0
var forced_gravity: bool = false
var forced_exit_loco: int = -1
# buffers
var jump_buffer_ticks: int = 0
var action_buffer_ticks: int = 0
var action_buffer_button: int = 0
var coyote_ticks: int = 0
# overlays
var modifiers: Array[ActiveModifier] = []
var locks: Array[Dictionary] = []
var pending_ops: Array[Dictionary] = []
var cheat_flags: int = 0

# --- CORE internal fields (serialized; not part of the design §7.2 list) ---
var dash_jump_cancelled: bool = false        # BTN_ABILITY pressed inside the window (spec §9)
var dash_jump_locked: bool = false           # G07: jump pressed before the window opened locks out the dash-jump
var dash_jump_window_open: bool = false      # for DASH_JUMP_WINDOW open/close events
var dash_jumped_this_airtime: bool = false   # landing slide kind DASH_JUMP (spec §13)
var air_dashed_this_airtime: bool = false    # landing slide kind AIR (spec §13)
var zip_knockoff_pending: bool = false       # stun applied on landing (spec §16)
var wall_fatigue_peak: float = 0.0           # linear fatigue recovery (spec §14)
var wall_fatigue_recover_ticks: int = 0
var sprint_ramp_ticks: int = 0               # ticks since sprint activation (spec §3)
var mantle_ticks: int = 0                    # completed mantle ticks
var phase_ticks: int = 0                     # ticks spent in current sub-phase
var mantle_band: int = -1
var ticks_since_combat: int = 1 << 20        # "in combat" for the wall-jump regen penalty (spec §14)
var slide_block_until_crouch_release: bool = false  # crouch storage: no slide until crouch is released (spec §6)
var zip_boost_cooldown_ticks: int = 0        # zipline boost cooldown (spec §16)
var air_dash_drag_pending: bool = false      # PROVISIONAL (G02): end drag owed by the running air dash
var slide_hop_flag: bool = false             # PROVISIONAL (G09): set by a slide jump
var slide_hop_penalty_active: bool = false   # PROVISIONAL (G09): slide-drag air drag active
var slide_hop_penalty_ticks: int = 0         # PROVISIONAL (G09): remaining ticks when the penalty is timed
var slide_hop_ground_ticks: int = 0          # PROVISIONAL (G09): ground ticks not sliding (clears the flag)
var last_wall_jump_tick: int = -1            # PROVISIONAL (G33): tick of the last wall jump this airtime (-1 = none)
var air_dash_drag_land_ticks: int = -1       # PROVISIONAL (G02): ticks left of an air dash that landed (IAD) while its end drag is pending (-1 = not landed)
var air_dash_ramp_target: float = 0.0        # air dash cap mode 3: along-dash speed the ramp stops at
var air_dash_ramp_v0: float = 0.0          # air dash cap mode 3: speed along the dash at its start (measured session 5)
var air_dash_ramp_done: bool = false         # air dash cap mode 3: target reached, only air drag for the rest of the dash
var air_dash_end_drag_ticks_left: int = 0    # end drag mode 4: airborne ticks of the stepped end drag still to run
var air_dash_end_drag_step: float = 0.0      # end drag mode 4: horizontal speed removed per tick

# transient (not serialized, cleared at start of each tick)
var events: Array[Dictionary] = []

const _TYPED_SKIP := ["modifiers", "locks", "pending_ops", "events"]
static var _field_names: PackedStringArray = PackedStringArray()


func _fields() -> PackedStringArray:
	if _field_names.is_empty():
		var names := PackedStringArray()
		for p in get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var n: String = p["name"]
			if n in _TYPED_SKIP or n.begins_with("_"):
				continue
			names.append(n)
		_field_names = names
	return _field_names


func duplicate_state() -> MoveState:
	return MoveState.from_dict(to_dict())


func to_dict() -> Dictionary:
	var d := {}
	for n in _fields():
		d[n] = get(n)
	var mods: Array = []
	for m in modifiers:
		mods.append(m.to_dict())
	d["modifiers"] = mods
	d["locks"] = locks.duplicate(true)
	d["pending_ops"] = pending_ops.duplicate(true)
	return d


static func from_dict(d: Dictionary) -> MoveState:
	var s := MoveState.new()
	for n in s._fields():
		if d.has(n):
			s.set(n, d[n])
	var mods: Array[ActiveModifier] = []
	for md in d.get("modifiers", []):
		mods.append(ActiveModifier.from_dict(md))
	s.modifiers = mods
	var lk: Array[Dictionary] = []
	for l in d.get("locks", []):
		lk.append((l as Dictionary).duplicate(true))
	s.locks = lk
	var po: Array[Dictionary] = []
	for o in d.get("pending_ops", []):
		po.append((o as Dictionary).duplicate(true))
	s.pending_ops = po
	return s


static func _canon(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_nan(f):
				return "nan"
			return roundi(f * 1e6)
		TYPE_VECTOR3:
			var x: Vector3 = v
			return [roundi(x.x * 1e6), roundi(x.y * 1e6), roundi(x.z * 1e6)]
		TYPE_STRING_NAME:
			return String(v)
		TYPE_DICTIONARY:
			var dd: Dictionary = v
			var keys := dd.keys()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			var out: Array = []
			for k in keys:
				out.append([str(k), _canon(dd[k])])
			return out
		TYPE_ARRAY:
			var out2: Array = []
			for e in v:
				out2.append(_canon(e))
			return out2
		TYPE_OBJECT:
			return 0
	return v


## Hash of to_dict() with floats rounded to 1e-6. pending_ops contents are skipped (only the count).
func checksum() -> int:
	var d := to_dict()
	d["pending_ops"] = pending_ops.size()
	return hash(var_to_str(_canon(d)))


func equals(other: MoveState, eps: float = 1e-6) -> bool:
	if other == null:
		return false
	var a := to_dict()
	var b := other.to_dict()
	a.erase("pending_ops")
	b.erase("pending_ops")
	if pending_ops.size() != other.pending_ops.size():
		return false
	return _eq(a, b, eps)


static func _eq(a: Variant, b: Variant, eps: float) -> bool:
	if typeof(a) != typeof(b):
		# int/float mixes after serialization round trips
		if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
			return absf(float(a) - float(b)) <= eps
		return false
	match typeof(a):
		TYPE_FLOAT:
			if is_nan(a) and is_nan(b):
				return true
			return absf(float(a) - float(b)) <= eps
		TYPE_VECTOR3:
			return (a as Vector3).distance_to(b as Vector3) <= eps * 2.0
		TYPE_DICTIONARY:
			var da: Dictionary = a
			var db: Dictionary = b
			if da.size() != db.size():
				return false
			for k in da:
				if not db.has(k) or not _eq(da[k], db[k], eps):
					return false
			return true
		TYPE_ARRAY:
			var aa: Array = a
			var ab: Array = b
			if aa.size() != ab.size():
				return false
			for i in aa.size():
				if not _eq(aa[i], ab[i], eps):
					return false
			return true
	return a == b


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func loco_name() -> String:
	return Loco.keys()[loco] if loco >= 0 and loco < Loco.size() else "?"
