class_name AbilityDB
extends RefCounted
## Loads data/abilities/abilities.json: abilities by id and hero kits (4 ids, last = ultimate).

const PATH := "res://data/abilities/abilities.json"

static var _by_id: Dictionary = {}
static var _kits: Dictionary = {}


static func _load() -> void:
	if not _by_id.is_empty():
		return
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (j is Dictionary):
		push_error("AbilityDB: can't parse " + PATH)
		return
	for e in j.get("abilities", []):
		var a := AbilityData.from_dict(e)
		_by_id[a.id] = a
	var kits: Dictionary = j.get("kits", {})
	for k in kits:
		_kits[StringName(k)] = kits[k].map(func(s: String) -> StringName: return StringName(s))


static func get_ability(id: StringName) -> AbilityData:
	_load()
	return _by_id.get(id)


## The 4 abilities of a kit, or [] for an unknown kit.
static func kit(key: StringName) -> Array[AbilityData]:
	_load()
	var out: Array[AbilityData] = []
	for id in _kits.get(key, []):
		out.append(_by_id[id])
	return out


static func kit_keys() -> Array:
	_load()
	return _kits.keys()
