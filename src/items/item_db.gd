class_name ItemDB
extends RefCounted
## Loads res://data/items/items.json (our item catalog).

const PATH := "res://data/items/items.json"

static var _items: Dictionary = {}   # id -> ItemData
static var _order: Array = []        # ids in file order


static func _load() -> void:
	if not _items.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("ItemDB: cannot open %s" % PATH)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for e in d.get("items", []):
		var it := ItemData.from_dict(e)
		_items[it.id] = it
		_order.append(it.id)


static func get_item(id: StringName) -> ItemData:
	_load()
	return _items.get(id) as ItemData


static func all() -> Array:
	_load()
	var out: Array = []
	for id in _order:
		out.append(_items[id])
	return out


## Items of one category and tier, in catalog order (the shop's columns).
static func by_category_tier(cat: int, tier: int) -> Array:
	return all().filter(func(it: ItemData) -> bool: return it.category == cat and it.tier == tier)
