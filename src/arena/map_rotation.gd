class_name MapRotation
extends RefCounted
## Map rotation for the sandbox scene. The first entry is the default; F9 advances and reloads.
## `--map=<id>` after `--` on the command line picks the starting map.

const MAPS: Array[StringName] = [&"three_lane", &"full"]
const NAMES := {&"three_lane": "Three Lanes", &"full": "Movement Debug"}

static var _index: int = -1


static func current() -> StringName:
	if _index < 0:
		_index = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--map="):
				var i := MAPS.find(StringName(a.trim_prefix("--map=")))
				if i >= 0:
					_index = i
	return MAPS[_index]


static func next() -> StringName:
	current()
	_index = (_index + 1) % MAPS.size()
	return MAPS[_index]


static func display_name(id: StringName) -> String:
	return NAMES.get(id, String(id))
