class_name StatSheet
extends RefCounted
## A hero's bonus stats (specs/stats.md). Sources (an item, an investment bonus, a buff) each set
## their own stat -> value map; every stat folds its sources with its stacking rule from StatDefs.
## Subsystems read the folded totals and derive their final values (weapon, movement, health).

signal changed

var _sources: Dictionary = {}   # StringName source -> Dictionary {StringName stat: float}
var _cache: Dictionary = {}     # StringName stat -> float
var _dirty: bool = true


## Replaces everything this source gives. An empty map removes the source.
func set_source(source: StringName, stats: Dictionary) -> void:
	if stats.is_empty():
		if not _sources.has(source):
			return
		_sources.erase(source)
	else:
		if _sources.get(source, {}) == stats:
			return
		_sources[source] = stats.duplicate()
	_dirty = true
	changed.emit()


func clear_source(source: StringName) -> void:
	set_source(source, {})


func has_source(source: StringName) -> bool:
	return _sources.has(source)


func sources() -> Array:
	return _sources.keys()


## The stat -> value map one source gives (empty when absent).
func get_source(source: StringName) -> Dictionary:
	return _sources.get(source, {})


## The folded bonus for a stat (0 when nothing gives it; see StatDefs for each stat's rule).
func get_stat(stat: StringName) -> float:
	if _dirty:
		_rebuild()
	return float(_cache.get(stat, 0.0))


## Every stat with a non-zero total (for the stat panel / debug).
func totals() -> Dictionary:
	if _dirty:
		_rebuild()
	return _cache.duplicate()


func _rebuild() -> void:
	var lists: Dictionary = {}
	for src in _sources:
		var m: Dictionary = _sources[src]
		for stat in m:
			if not lists.has(stat):
				lists[stat] = []
			lists[stat].append(float(m[stat]))
	_cache.clear()
	for stat in lists:
		_cache[stat] = StatDefs.fold(stat, lists[stat])
	_dirty = false
