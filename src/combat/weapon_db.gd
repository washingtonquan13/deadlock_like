class_name WeaponDB
extends RefCounted
## Loads res://data/weapons/weapons.json (our tuned gun data) into WeaponData resources.

const PATH := "res://data/weapons/weapons.json"

static var _cache: Dictionary = {}          # key -> WeaponData
static var _hero: Dictionary = {}           # key -> {health, health_per_boon, regen, crit_damage_received_scale}


static func _load() -> void:
	if not _cache.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("WeaponDB: cannot open %s" % PATH)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k in d:
		var e: Dictionary = d[k]
		var w := WeaponData.new()
		w.key = StringName(k)
		w.display_name = e.get("name", k)
		w.bullet_range = float(e.get("range", 177.8))
		for prop in w.get_property_list():
			var n: String = prop["name"]
			if e.has(n) and n != "key":
				w.set(n, e[n])
		_cache[StringName(k)] = w
		_hero[StringName(k)] = {
			"health": float(e.get("hero_health", 700.0)),
			"health_per_boon": float(e.get("hero_health_per_boon", 0.0)),
			"regen": float(e.get("hero_regen", 1.0)),
			"spirit_per_boon": float(e.get("hero_spirit_per_boon", 1.1)),
			"crit_damage_received_scale": float(e.get("crit_damage_received_scale", 1.0)),
		}


static func keys() -> Array:
	_load()
	var k := _cache.keys()
	k.sort()
	return k


static func get_weapon(key: StringName) -> WeaponData:
	_load()
	return _cache.get(key) as WeaponData


static func get_hero(key: StringName) -> Dictionary:
	_load()
	return _hero.get(key, {})
