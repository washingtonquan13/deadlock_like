class_name MovementDebugOverlay
extends CanvasLayer
## Movement debug HUD (design §10). Reads the player only through the ticked(tick, state)
## signal and changes it only through public PlayerCharacter methods.
##
## Keys (input actions defined by CORE, design §5):
##   F1 show/hide  F2 timescale 1/0.5/0.25/0.1  F3 infinite stamina  F4 next teleport point
##   F5 pause sim  F6 step one tick (paused)  F7 start/stop measurement  F8 teleport to first point

const TIMESCALES: Array[float] = [1.0, 0.5, 0.25, 0.1]
const TELEPORT_GROUP := &"teleport_points"
const LOCK_NAMES := {
	ControlLocks.MOVE: "MOVE", ControlLocks.JUMP: "JUMP", ControlLocks.DASH: "DASH",
	ControlLocks.CROUCH: "CROUCH", ControlLocks.SPRINT: "SPRINT", ControlLocks.STAMINA: "STAMINA",
	ControlLocks.ZIPLINE: "ZIPLINE", ControlLocks.MANTLE: "MANTLE", ControlLocks.MELEE: "MELEE",
	ControlLocks.TURN: "TURN",
}
const STAT_NAMES_FALLBACK := "?"
const HU := 0.0254

@export var player_path: NodePath

var player: PlayerCharacter = null

var _timescale_index: int = 0
var _teleport_index: int = -1
var _last_tick: int = -1
var _status_msg: String = ""
var _status_ticks: int = 0

@onready var _root: Control = $Root
@onready var _readout: Label = $Root/Panel/VBox/Readout
@onready var _graph: SpeedGraph = $Root/Panel/VBox/SpeedGraph
@onready var _recipe_select: OptionButton = $Root/Panel/VBox/RecordRow/Recipe
@onready var _record_label: Label = $Root/Panel/VBox/RecordRow/RecordStatus
@onready var _help: Label = $Root/Panel/VBox/Help
@onready var _recorder: MeasurementRecorder = $MeasurementRecorder


func _ready() -> void:
	_recipe_select.clear()
	for r in MeasurementRecorder.RECIPES:
		_recipe_select.add_item(String(r))
	_recipe_select.focus_mode = Control.FOCUS_NONE  # never steal Space/keys from gameplay
	_recorder.recording_changed.connect(func(_on: bool) -> void: _refresh_record_label())
	_help.text = "F1 hide  F2 timescale  F3 inf. stamina  F4/F8 teleport  F5 pause  F6 step  F7 record  F9 next map"
	_timescale_index = maxi(0, TIMESCALES.find(Engine.time_scale))
	_bind_player()
	_refresh_record_label()


func _exit_tree() -> void:
	# Leave the engine as we found it when the overlay goes away.
	Engine.time_scale = 1.0


func _bind_player() -> void:
	var p: Node = null
	if not player_path.is_empty():
		p = get_node_or_null(player_path)
	if p == null:
		p = _find_player(get_tree().current_scene if get_tree().current_scene != null else get_tree().root)
	if p is PlayerCharacter:
		player = p as PlayerCharacter
		if not player.ticked.is_connected(_on_player_ticked):
			player.ticked.connect(_on_player_ticked)
		_readout.text = "waiting for first tick..."
	else:
		_readout.text = "MovementDebugOverlay: no PlayerCharacter (set player_path)"


static func _find_player(n: Node) -> PlayerCharacter:
	if n == null:
		return null
	if n is PlayerCharacter:
		return n as PlayerCharacter
	for c in n.get_children():
		var f := _find_player(c)
		if f != null:
			return f
	return null


# --- input toggles -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if event.is_echo():
		return
	if event.is_action_pressed(&"debug_toggle_overlay"):
		_root.visible = not _root.visible
	elif event.is_action_pressed(&"debug_cycle_timescale"):
		_timescale_index = (_timescale_index + 1) % TIMESCALES.size()
		Engine.time_scale = TIMESCALES[_timescale_index]
		_flash("timescale %.2f" % Engine.time_scale)
	elif event.is_action_pressed(&"debug_infinite_stamina"):
		_toggle_infinite_stamina()
	elif event.is_action_pressed(&"debug_teleport_next"):
		_teleport_step(false)
	elif event.is_action_pressed(&"debug_teleport_spawn"):
		_teleport_step(true)
	elif event.is_action_pressed(&"debug_pause"):
		if player != null:
			player.sim_paused = not player.sim_paused
			_flash("sim paused" if player.sim_paused else "sim running")
			_refresh_readout_paused()
	elif event.is_action_pressed(&"debug_step"):
		if player != null and player.sim_paused:
			player.step_ticks(1)
	elif event.is_action_pressed(&"debug_record"):
		_toggle_recording()
	else:
		return
	get_viewport().set_input_as_handled()


## F3: spec cheat CHEAT_INFINITE_STAMINA (design §7.9 step 8). Applied by the sim next tick.
func _toggle_infinite_stamina() -> void:
	if player == null or player.state == null:
		return
	var on := (player.state.cheat_flags & MoveState.CHEAT_INFINITE_STAMINA) == 0
	player.debug_set_infinite_stamina(on)
	_flash("infinite stamina %s" % ("ON" if on else "OFF"))


## F4 cycles through Marker3Ds in group teleport_points sorted by node name; F8 goes to the first.
func _teleport_step(to_first: bool) -> void:
	if player == null:
		return
	var points: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(TELEPORT_GROUP):
		if n is Node3D:
			points.append(n as Node3D)
	if points.is_empty():
		_flash("no teleport points")
		return
	points.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
	if to_first:
		_teleport_index = 0
	else:
		_teleport_index = (_teleport_index + 1) % points.size()
	var target := points[_teleport_index]
	player.teleport(target.global_position, false)
	_flash("teleport -> %s" % target.name)


func _toggle_recording() -> void:
	if player == null:
		return
	if _recorder.is_recording():
		var rows := _recorder.stop()
		_flash("wrote %d rows -> %s" % [rows.size(), ProjectSettings.globalize_path(_recorder.get_output_path())], 64 * 6)
	else:
		var recipe := MeasurementRecorder.RECIPES[clampi(_recipe_select.selected, 0, MeasurementRecorder.RECIPES.size() - 1)]
		_recorder.start(recipe, player)
	_refresh_record_label()


func _flash(msg: String, ticks: int = 64 * 2) -> void:
	_status_msg = msg
	_status_ticks = ticks
	print("[debug] ", msg)


func _refresh_record_label() -> void:
	if _record_label == null:
		return
	if _recorder.is_recording():
		_record_label.text = "REC %s  (%d ticks)  F7 to stop" % [_recorder.get_recipe(), _recorder.get_sample_count()]
		_record_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		_record_label.text = "F7 record selected recipe"
		_record_label.modulate = Color(1, 1, 1, 0.8)


func _refresh_readout_paused() -> void:
	# ticked is not emitted while paused, so rebuild the text from the last state we were given.
	if player != null and player.state != null and _root.visible:
		_readout.text = _build_text(player.state.tick, player.state)


# --- readout -----------------------------------------------------------------------

func _on_player_ticked(tick: int, state: MoveState) -> void:
	if _status_ticks > 0:
		_status_ticks -= 1
	_graph.push_sample(tick, state.horizontal_speed(), state.velocity.y, state.loco)
	_last_tick = tick
	if _recorder.is_recording():
		_refresh_record_label()
	if _root.visible:
		_readout.text = _build_text(tick, state)


func _build_text(tick: int, s: MoveState) -> String:
	var lines := PackedStringArray()
	var h := s.horizontal_speed()
	var paused := player != null and player.sim_paused
	lines.append("tick %d   timescale %.2f%s" % [tick, Engine.time_scale, "   [PAUSED]" if paused else ""])
	var phase_txt := str(s.phase)
	if s.loco == MoveState.Loco.HEAVY_LUNGE and s.phase >= 0 and s.phase < MoveState.LungePhase.size():
		phase_txt = MoveState.LungePhase.keys()[s.phase]
	lines.append("loco %s  phase %s  state_ticks %d" % [s.loco_name(), phase_txt, s.state_ticks])
	lines.append("h speed %6.3f m/s  (%6.1f u/s)" % [h, h / HU])
	lines.append("v speed %+6.3f m/s" % s.velocity.y)
	lines.append("vel (%+.3f, %+.3f, %+.3f)" % [s.velocity.x, s.velocity.y, s.velocity.z])
	lines.append("pos (%.3f, %.3f, %.3f)" % [s.position.x, s.position.y, s.position.z])

	# Stamina (spec: movement.md §7).
	var smax := 0.0
	var cp: CompiledMoveParams = player.get_compiled_params() if player != null else null
	if cp != null:
		smax = cp.stamina_max(s)
	var bars := ""
	for b in int(ceil(smax)):
		bars += "#" if s.stamina >= float(b + 1) - 1e-5 else "."
	var inf := "  [INF]" if (s.cheat_flags & MoveState.CHEAT_INFINITE_STAMINA) != 0 else ""
	lines.append("stamina %.3f / %.1f  [%s]  regen %3.0f%%%s" % [s.stamina, smax, bars, s.stamina_regen_progress * 100.0, inf])
	if s.combat_regen_penalty_ticks > 0:
		lines.append("  combat regen penalty %.2f s" % (float(s.combat_regen_penalty_ticks) / MoveUnits.TICK_RATE))

	# Per-airtime counters (spec: movement.md §10, §11, §14).
	lines.append("air: jumps %d  dashes %d  down %d  walljumps %d  fatigue %.2f  airborne %d" % [
		s.air_jumps_used, s.air_dashes_used, s.down_dashes_used, s.wall_jumps_done, s.wall_fatigue, s.airborne_ticks])

	# Sprint (spec: movement.md §3).
	var sprint_txt := "ACTIVE +%.2f m/s" % s.sprint_bonus_current if s.sprint_active else "off (%.2f / %.2f s)" % [
		float(s.sprint_timer_ticks) / MoveUnits.TICK_RATE,
		float(cp.sprint_delay_ticks) / MoveUnits.TICK_RATE if cp != null else 0.0]
	lines.append("sprint %s" % sprint_txt)
	if cp != null:
		lines.append("eff move %.3f  crouch %.3f m/s" % [cp.effective_move_speed(s, false), cp.effective_crouch_speed(s)])

	# Dash / slide detail while relevant.
	match s.loco:
		MoveState.Loco.GROUND_DASH, MoveState.Loco.AIR_DASH:
			lines.append("dash %d / %d ticks  last frac %.3f  window %s" % [s.dash_ticks, s.dash_total_ticks, s.dash_last_fraction,
				"OPEN" if s.dash_jump_window_open else "closed"])
		MoveState.Loco.SLIDE:
			var kinds: Array = MoveState.SlideKind.keys()
			var kind_name: String = kinds[s.slide_kind] if s.slide_kind >= 0 and s.slide_kind < kinds.size() else "?"
			lines.append("slide %s  %d ticks" % [kind_name, s.slide_ticks])

	# Modifiers with remaining time. Timers store ticks+1 (CORE timer storage), so the ticks still
	# to run after this one are ticks_left - 1.
	if s.modifiers.is_empty():
		lines.append("modifiers: none")
	else:
		lines.append("modifiers:")
		var stat_keys: Array = ModifierDef.Stat.keys()
		for m in s.modifiers:
			var stat_name: String = stat_keys[m.stat] if m.stat >= 0 and m.stat < stat_keys.size() else STAT_NAMES_FALLBACK
			var left := "perm" if m.ticks_left < 0 else "%.2f s" % (float(maxi(0, m.ticks_left - 1)) / MoveUnits.TICK_RATE)
			lines.append("  %s  %s %+.3f  %s" % [m.id, stat_name, m.current_value(), left])

	# Locks.
	var mask := ControlLocks.active_mask(s)
	lines.append("locks: %s" % _lock_text(mask))

	# Ground.
	var angle := rad_to_deg(acos(clampf(s.ground_normal.y, -1.0, 1.0))) if s.grounded else 0.0
	lines.append("grounded %s  floor %.1f deg  crouched %s" % ["yes" if s.grounded else "no", angle, "yes" if s.crouched else "no"])

	if _status_ticks > 0 and _status_msg != "":
		lines.append("> " + _status_msg)
	return "\n".join(lines)


static func _lock_text(mask: int) -> String:
	if mask == 0:
		return "none"
	if (mask & ControlLocks.STUN) == ControlLocks.STUN:
		var extra := mask & ~ControlLocks.STUN
		return "STUN" + ("" if extra == 0 else " +" + _lock_text(extra))
	var parts := PackedStringArray()
	for bit in LOCK_NAMES:
		if mask & int(bit):
			parts.append(LOCK_NAMES[bit])
	return "|".join(parts) + " (0x%x)" % mask
