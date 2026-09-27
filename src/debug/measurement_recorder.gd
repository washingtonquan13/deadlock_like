class_name MeasurementRecorder
extends Node
## Records sim-side "measurements" of the local player, using the same recipes and quantity
## names as specs/_measurement_protocol.md (R1-R4), so sim predictions can be compared row by
## row with in-game measurements (design §10).
##
## The recorder only observes: it listens to PlayerCharacter.ticked, snapshots the fields it
## needs every tick, and analyses the trace on stop(). It never scripts inputs and never
## mutates MoveState. Output goes to user:// only (design §15); data/measurements* is never
## touched by game code.

const CSV_HEADER := "measurement_id,recipe,date,game_build,patch_date,context,cheats_used,hero,items,quantity,trial,value,units,distance_m,conditions,method,fps,frame_start,frame_end,evidence_ref,measured_by,source_type,confidence,notes"
const OUTPUT_DIR := "user://measurements"
const OUTPUT_PATH := "user://measurements/sim_predictions.csv"
const RECIPES: Array[StringName] = [&"R1", &"R2", &"R3", &"R4"]
const TICK_RATE := 64

# R1 steady-speed detection (protocol R1: "hold forward for at least 3 s, read steady velocity").
## Ticks over which speed must stay within STEADY_EPS for a sample to count as steady.
const STEADY_WINDOW := 16
const STEADY_EPS := 0.002          # m/s
const STEADY_MIN_TICKS := 32       # shortest steady segment worth a row (0.5 s)
const MOVING_MIN_SPEED := 0.5      # m/s; below this nothing counts as "moving"
const REST_SPEED := 0.05           # m/s; at or below this the player counts as standing still
const DIR_FORWARD_DOT := 0.9       # cos between velocity and facing for forward / back
const DIR_STRAFE_DOT := 0.2        # |cos| below this counts as strafing
const ACCEL_FRACTION := 0.95       # protocol R1 accel_time_to_max: time to 95%

# R3 slide sample times (protocol R3: slide_speed_t0.5, slide_speed_t1.0).
const SLIDE_SAMPLE_TIMES: Array[float] = [0.5, 1.0]

signal recording_changed(active: bool)

var _recording: bool = false
var _recipe: StringName = &""
var _player: PlayerCharacter = null
var _trace: Array[Dictionary] = []
var _start_time_unix: int = 0


func is_recording() -> bool:
	return _recording


func get_recipe() -> StringName:
	return _recipe


func get_sample_count() -> int:
	return _trace.size()


## Starts observing `player` for `recipe` (R1-R4). A running recording is stopped (and written) first.
func start(recipe: StringName, player: PlayerCharacter) -> void:
	if _recording:
		stop()
	if player == null:
		push_warning("MeasurementRecorder.start: player is null")
		return
	if not RECIPES.has(recipe):
		push_warning("MeasurementRecorder.start: unknown recipe %s" % recipe)
		return
	_recipe = recipe
	_player = player
	_trace.clear()
	_start_time_unix = int(Time.get_unix_time_from_system())
	if not _player.ticked.is_connected(_on_ticked):
		_player.ticked.connect(_on_ticked)
	_recording = true
	# Baseline sample of the current state (the protocol's "getpos before"), so an action on the
	# very first recorded tick still has a start position and a stamina value to compare against.
	# Its events belong to an earlier tick and are dropped.
	if _player.state != null:
		_on_ticked(_player.state.tick, _player.state)
		(_trace[0]["events"] as Array).clear()
	recording_changed.emit(true)


## Stops observing, analyses the trace, appends the rows to get_output_path() and returns them.
func stop() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not _recording:
		return rows
	_recording = false
	if _player != null and is_instance_valid(_player) and _player.ticked.is_connected(_on_ticked):
		_player.ticked.disconnect(_on_ticked)
	match _recipe:
		&"R1":
			rows = _analyse_r1()
		&"R2":
			rows = _analyse_r2()
		&"R3":
			rows = _analyse_r3()
		&"R4":
			rows = _analyse_r4()
	_finish_rows(rows)
	_write_rows(rows)
	recording_changed.emit(false)
	return rows


func get_output_path() -> String:
	return OUTPUT_PATH


func _exit_tree() -> void:
	if _recording:
		stop()


# --- sampling -----------------------------------------------------------------------

func _on_ticked(tick: int, state: MoveState) -> void:
	if not _recording or state == null:
		return
	var smax := 0.0
	var cp := _player.get_compiled_params()
	if cp != null:
		smax = cp.stamina_max(state)
	var mod_ids := PackedStringArray()
	for m in state.modifiers:
		mod_ids.append(String(m.id))
	var evs: Array[Dictionary] = []
	for e in state.events:
		evs.append((e as Dictionary).duplicate(true))
	_trace.append({
		"tick": tick,
		"pos": state.position,
		"vel": state.velocity,
		"h": state.horizontal_speed(),
		"loco": state.loco,
		"yaw": state.yaw,
		"grounded": state.grounded,
		"stamina": state.stamina,
		"stamina_max": smax,
		"sprint": state.sprint_active,
		"crouched": state.crouched,
		"dash_total_ticks": state.dash_total_ticks,
		"dash_last_fraction": state.dash_last_fraction,
		"cheats": state.cheat_flags,
		"items": ";".join(mod_ids),
		"events": evs,
	})


# --- helpers ------------------------------------------------------------------------

static func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


func _path_length(i0: int, i1: int) -> float:
	var d := 0.0
	for i in range(i0 + 1, i1 + 1):
		d += _hdist(_trace[i - 1]["pos"], _trace[i]["pos"])
	return d


func _find_event(i: int, type: StringName) -> Dictionary:
	for e in _trace[i]["events"]:
		if StringName(e.get("type", &"")) == type:
			return e
	return {}


static func _facing(yaw: float) -> Vector3:
	# design §3: yaw 0 faces -Z, positive yaw turns left.
	return Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -1.0)


func _row(quantity: StringName, value: float, units: String, i0: int, i1: int, distance_m: float, conditions: String, notes: String = "") -> Dictionary:
	var s: Dictionary = _trace[clampi(i0, 0, _trace.size() - 1)]
	var e: Dictionary = _trace[clampi(i1, 0, _trace.size() - 1)]
	return {
		"quantity": String(quantity),
		"value": value,
		"units": units,
		"distance_m": distance_m,
		"conditions": conditions,
		"frame_start": int(s["tick"]),
		"frame_end": int(e["tick"]),
		"items": String(s["items"]),
		"cheats": int(s["cheats"]) | int(e["cheats"]),
		"notes": notes,
	}


# --- R1: movement speed (walk and sprint) -------------------------------------------
# Steady ground speed classified by the angle between velocity and facing, plus
# accel_time_to_max = time from rest until 95% of the following steady speed.

func _direction_class(i: int) -> StringName:
	var t: Dictionary = _trace[i]
	if bool(t["sprint"]):
		return &"sprint_speed"
	var v: Vector3 = t["vel"]
	var hv := Vector3(v.x, 0.0, v.z)
	if hv.length() < MOVING_MIN_SPEED:
		return &""
	var d := hv.normalized().dot(_facing(float(t["yaw"])))
	if d >= DIR_FORWARD_DOT:
		return &"move_speed_forward"
	if d <= -DIR_FORWARD_DOT:
		return &"move_speed_back"
	if absf(d) <= DIR_STRAFE_DOT:
		return &"move_speed_strafe"
	return &""


func _is_steady(i: int) -> bool:
	if i < STEADY_WINDOW:
		return false
	var loco := int(_trace[i]["loco"])
	if loco != MoveState.Loco.GROUND:
		return false
	var h := float(_trace[i]["h"])
	if h < MOVING_MIN_SPEED:
		return false
	for k in range(i - STEADY_WINDOW, i):
		if int(_trace[k]["loco"]) != loco or absf(float(_trace[k]["h"]) - h) > STEADY_EPS:
			return false
	return true


func _analyse_r1() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var n := _trace.size()
	# Steady segments: contiguous steady ticks with the same direction class.
	var i := 0
	while i < n:
		var cls := _direction_class(i) if _is_steady(i) else &""
		if cls == &"":
			i += 1
			continue
		var j := i
		var sum := 0.0
		while j < n and _is_steady(j) and _direction_class(j) == cls:
			sum += float(_trace[j]["h"])
			j += 1
		var count := j - i
		if count >= STEADY_MIN_TICKS:
			var seg_start := i - STEADY_WINDOW
			rows.append(_row(cls, sum / float(count), "m/s", seg_start, j - 1,
				_path_length(seg_start, j - 1),
				"ground steady %d ticks" % (count + STEADY_WINDOW),
				"mean horizontal speed over the steady segment"))
		i = j

	# accel_time_to_max: rest -> first tick at >= 95% of the steady speed reached afterwards.
	i = 1
	while i < n:
		var was_rest := float(_trace[i - 1]["h"]) <= REST_SPEED
		var moving := float(_trace[i]["h"]) > REST_SPEED
		if not (was_rest and moving and int(_trace[i]["loco"]) == MoveState.Loco.GROUND):
			i += 1
			continue
		var start := i - 1
		var k := i
		var steady_at := -1
		while k < n and int(_trace[k]["loco"]) == MoveState.Loco.GROUND and float(_trace[k]["h"]) > REST_SPEED:
			if _is_steady(k):
				steady_at = k
				break
			k += 1
		if steady_at >= 0:
			var target := float(_trace[steady_at]["h"]) * ACCEL_FRACTION
			var hit := -1
			for m in range(i, steady_at + 1):
				if float(_trace[m]["h"]) >= target:
					hit = m
					break
			if hit >= 0:
				var secs := float(int(_trace[hit]["tick"]) - int(_trace[start]["tick"])) / TICK_RATE
				rows.append(_row(&"accel_time_to_max", secs, "s", start, hit,
					_path_length(start, hit),
					"from rest to %.3f m/s (95%% of %.3f)" % [target, float(_trace[steady_at]["h"])],
					"sprint %s" % ("on" if bool(_trace[steady_at]["sprint"]) else "off")))
			i = steady_at + 1
		else:
			i = k + 1
	return rows


# --- R2: dash distance and duration, stamina regen -----------------------------------

func _analyse_r2() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var n := _trace.size()
	# Dashes: start at the DASHED event, end when the loco leaves the dash state.
	for i in n:
		var ev := _find_event(i, MoveEvents.DASHED)
		if ev.is_empty():
			continue
		var kind := StringName(ev.get("kind", &""))
		var dash_loco := -1
		var quantity_d := &""
		var quantity_t := &""
		match kind:
			&"ground":
				dash_loco = MoveState.Loco.GROUND_DASH
				quantity_d = &"ground_dash_distance"
				quantity_t = &"ground_dash_duration"
			&"air":
				dash_loco = MoveState.Loco.AIR_DASH
				quantity_d = &"air_dash_distance"
				quantity_t = &"air_dash_duration"
			_:
				continue  # down dash has no protocol quantity
		if int(_trace[i]["loco"]) != dash_loco:
			continue
		var j := i
		while j + 1 < n and int(_trace[j + 1]["loco"]) == dash_loco:
			j += 1
		if j + 1 >= n:
			continue  # recording stopped mid-dash
		var start := maxi(0, i - 1)          # position before the dash tick (protocol: getpos before)
		var ticks_in := j - i + 1
		# The last dash tick may be fractional (design §2 #3); use the sim's own fraction.
		var frac := float(_trace[i]["dash_last_fraction"])
		var total := int(_trace[i]["dash_total_ticks"])
		var dur_ticks := float(ticks_in)
		var note := "tick-count %d" % ticks_in
		if total == ticks_in and frac > 0.0 and frac <= 1.0:
			dur_ticks = float(ticks_in - 1) + frac
			note += ", last tick fraction %.3f" % frac
		var ended := MoveState.Loco.keys()[int(_trace[j + 1]["loco"])] as String
		var cond := "bucket %s, ended in %s" % [str(ev.get("bucket", "?")), ended]
		rows.append(_row(quantity_d, _hdist(_trace[start]["pos"], _trace[j]["pos"]), "m", start, j,
			_path_length(start, j), cond, "straight-line start/end horizontal distance"))
		rows.append(_row(quantity_t, dur_ticks / TICK_RATE, "s", i, j,
			_path_length(start, j), cond, note))

	# stamina_regen_time: from a spend until one more bar is back, uninterrupted by another spend.
	var regen_from := -1
	var regen_start_tick := 0   # tick before the spend (protocol: time from the spend)
	var regen_base := 0.0
	for i in range(1, n):
		var prev := float(_trace[i - 1]["stamina"])
		var cur := float(_trace[i]["stamina"])
		if cur < prev - 1e-6:
			regen_from = i
			regen_start_tick = int(_trace[i - 1]["tick"])
			regen_base = cur
			continue
		if regen_from >= 0 and cur >= regen_base + 1.0 - 1e-5:
			var secs := float(int(_trace[i]["tick"]) - regen_start_tick) / TICK_RATE
			rows.append(_row(&"stamina_regen_time", secs, "s", regen_from, i, 0.0,
				"from %.2f to %.2f of %.1f bars" % [regen_base, cur, float(_trace[i]["stamina_max"])],
				"protocol measures from 0 bars; sim regen is per bar"))
			regen_from = -1 if cur >= float(_trace[i]["stamina_max"]) - 1e-5 else i
			regen_start_tick = int(_trace[i]["tick"])
			regen_base = cur
	return rows


# --- R3: slide speed and decay --------------------------------------------------------

func _analyse_r3() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var n := _trace.size()
	var i := 0
	while i < n:
		if int(_trace[i]["loco"]) != MoveState.Loco.SLIDE or (i > 0 and int(_trace[i - 1]["loco"]) == MoveState.Loco.SLIDE):
			i += 1
			continue
		var j := i
		while j + 1 < n and int(_trace[j + 1]["loco"]) == MoveState.Loco.SLIDE:
			j += 1
		if j + 1 >= n:
			break  # recording stopped mid-slide
		var ev := _find_event(i, MoveEvents.SLIDE_START)
		var kind_txt := str(ev.get("kind", "?"))
		if ev.has("kind") and typeof(ev["kind"]) == TYPE_INT:
			var kinds: Array = MoveState.SlideKind.keys()
			var k := int(ev["kind"])
			if k >= 0 and k < kinds.size():
				kind_txt = kinds[k]
		var cond := "kind %s, ended in %s" % [kind_txt, MoveState.Loco.keys()[int(_trace[j + 1]["loco"])]]
		var start := maxi(0, i - 1)
		rows.append(_row(&"slide_entry_speed", float(_trace[i]["h"]), "m/s", i, i, 0.0, cond, "speed on the first slide tick"))
		for t in SLIDE_SAMPLE_TIMES:
			# after round(t*64) slide ticks (slide tick n = trace index i + n - 1)
			var idx := i + roundi(t * TICK_RATE) - 1
			if idx <= j:
				rows.append(_row(StringName("slide_speed_t%.1f" % t), float(_trace[idx]["h"]), "m/s", i, idx,
					_path_length(start, idx), cond, "after %d slide ticks" % roundi(t * TICK_RATE)))
		rows.append(_row(&"slide_distance", _path_length(start, j), "m", start, j,
			_path_length(start, j), cond, "horizontal path length"))
		rows.append(_row(&"slide_duration", float(j - i + 1) / TICK_RATE, "s", i, j,
			_path_length(start, j), cond, "%d slide ticks" % (j - i + 1)))
		i = j + 1
	return rows


# --- R4: jump height and airtime, mantle height -------------------------------------
# Apex = max y between JUMPED and LANDED (design §10).

func _analyse_r4() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var n := _trace.size()
	var jump_i := -1
	var jump_kind := ""
	var base_y := 0.0
	var apex_y := -INF
	var apex_i := -1
	var mantle_max := -1.0
	var mantle_i := -1
	var mantle_count := 0
	for i in n:
		var t: Dictionary = _trace[i]
		var pos: Vector3 = t["pos"]
		var landed := _find_event(i, MoveEvents.LANDED)
		if jump_i >= 0:
			if pos.y > apex_y:
				apex_y = pos.y
				apex_i = i
			if not landed.is_empty():
				var start := maxi(0, jump_i - 1)
				var cond := "kind %s" % jump_kind
				rows.append(_row(&"jump_apex_height", apex_y - base_y, "m", start, apex_i, 0.0, cond,
					"max y minus takeoff y"))
				rows.append(_row(&"jump_airtime", float(int(t["tick"]) - int(_trace[start]["tick"])) / TICK_RATE, "s", start, i,
					_path_length(start, i), cond, "takeoff to LANDED tick; landing height %+.3f m" % (pos.y - base_y)))
				jump_i = -1
		var jumped := _find_event(i, MoveEvents.JUMPED)
		if not jumped.is_empty():
			# A second jump before landing (air jump, wall jump) starts a new measurement.
			jump_i = i
			jump_kind = str(jumped.get("kind", "?"))
			base_y = (_trace[maxi(0, i - 1)]["pos"] as Vector3).y
			apex_y = pos.y
			apex_i = i
		var mantle := _find_event(i, MoveEvents.MANTLE_START)
		if not mantle.is_empty():
			mantle_count += 1
			jump_i = -1  # a mantle ends the jump measurement
			var hm := float(mantle.get("height_m", 0.0))
			if hm > mantle_max:
				mantle_max = hm
				mantle_i = i
	if mantle_i >= 0:
		rows.append(_row(&"mantle_max_height", mantle_max, "m", mantle_i, mantle_i, 0.0,
			"max of %d mantles" % mantle_count, "%.1f u" % (mantle_max / 0.0254)))
	return rows


# --- output ---------------------------------------------------------------------------

func _finish_rows(rows: Array[Dictionary]) -> void:
	var date := Time.get_date_string_from_system()
	var hero_id := "unknown"
	if _player != null and is_instance_valid(_player) and _player.hero != null:
		hero_id = String(_player.hero.hero_id)
	var trials := {}
	var seq := 0
	for r in rows:
		seq += 1
		var q: String = r["quantity"]
		trials[q] = int(trials.get(q, 0)) + 1
		var cheats := int(r["cheats"])
		var cheat_txt := "none"
		if cheats != 0:
			var parts := PackedStringArray()
			if cheats & MoveState.CHEAT_INFINITE_STAMINA:
				parts.append("infinite_stamina")
			if cheats & MoveState.CHEAT_NO_COOLDOWNS:
				parts.append("no_cooldowns")
			cheat_txt = ";".join(parts)
		r["measurement_id"] = "sim-%s-%d-%03d" % [String(_recipe), _start_time_unix, seq]
		r["recipe"] = String(_recipe)
		r["date"] = date
		r["game_build"] = "sim"
		r["patch_date"] = ""
		r["context"] = "godot-sandbox"
		r["cheats_used"] = cheat_txt
		r["hero"] = hero_id
		r["trial"] = trials[q]
		r["method"] = "sim-trace"
		r["fps"] = TICK_RATE
		r["evidence_ref"] = "sim ticks %d-%d" % [int(r["frame_start"]), int(r["frame_end"])]
		r["measured_by"] = "sim"
		r["source_type"] = "sim-prediction"
		r["confidence"] = "high"
		r.erase("cheats")


static func _csv_field(v: Variant) -> String:
	var s: String
	if typeof(v) == TYPE_FLOAT:
		s = "%.6f" % float(v)
	else:
		s = str(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n"):
		s = "\"" + s.replace("\"", "\"\"") + "\""
	return s


func _write_rows(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var is_new := not FileAccess.file_exists(OUTPUT_PATH)
	var f: FileAccess
	if is_new:
		f = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	else:
		f = FileAccess.open(OUTPUT_PATH, FileAccess.READ_WRITE)
	if f == null:
		push_warning("MeasurementRecorder: cannot open %s (%s)" % [OUTPUT_PATH, error_string(FileAccess.get_open_error())])
		return
	if is_new:
		f.store_line(CSV_HEADER)
	else:
		f.seek_end()
	var cols := CSV_HEADER.split(",")
	for r in rows:
		var fields := PackedStringArray()
		for c in cols:
			fields.append(_csv_field(r.get(c, "")))
		f.store_line(",".join(fields))
	f.close()
