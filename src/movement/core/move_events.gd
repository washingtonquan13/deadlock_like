class_name MoveEvents
## Event type constants. An event is { "type": StringName, "tick": int, ...payload } (design §7.3).

const LANDED := &"LANDED"                       # {impact_speed}
const JUMPED := &"JUMPED"                       # {kind}
const DASHED := &"DASHED"                       # {kind, bucket}
const STATE_CHANGED := &"STATE_CHANGED"         # {from, to}
const STAMINA_CHANGED := &"STAMINA_CHANGED"     # {value, max}
const DASH_JUMP_WINDOW := &"DASH_JUMP_WINDOW"   # {open}
const SLIDE_START := &"SLIDE_START"             # {kind}
const SLIDE_PENALTY := &"SLIDE_PENALTY"
const SLIDE_END := &"SLIDE_END"
const MANTLE_START := &"MANTLE_START"           # {height_m, band}
const MANTLE_END := &"MANTLE_END"
const WALL_JUMP := &"WALL_JUMP"                 # {count, fatigue}
const ZIP_ATTACH := &"ZIP_ATTACH"               # {rail_id}
const ZIP_DETACH := &"ZIP_DETACH"               # {reason}
const SPRINT_START := &"SPRINT_START"
const SPRINT_RESET := &"SPRINT_RESET"           # {reason}
const TELEPORTED := &"TELEPORTED"
const LOCKED := &"LOCKED"                       # {mask}
const PARRY_START := &"PARRY_START"
const AIR_DASH_END_DRAG := &"AIR_DASH_END_DRAG" # {from, to} PROVISIONAL (G02)
const SLIDE_DRAG := &"SLIDE_DRAG"               # {slide_ticks} PROVISIONAL (G09) slide-hop penalty applied


static func make(type: StringName, tick: int, payload: Dictionary = {}) -> Dictionary:
	var e := {"type": type, "tick": tick}
	e.merge(payload)
	return e


static func push(state: MoveState, type: StringName, payload: Dictionary = {}) -> void:
	# Events raised during simulate() belong to the tick being produced (state.tick + 1).
	state.events.append(make(type, state.tick + 1, payload))
