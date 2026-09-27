class_name ActiveModifier
extends RefCounted
## A modifier instance living on a MoveState (design §7.2 / §7.5).

var id: StringName = &""
var stat: int = 0
var value: float = 0.0
var taper_to: float = NAN
var ticks_left: int = -1       # -1 = permanent
var ticks_total: int = 0
var source: StringName = &""


## Linear taper value -> taper_to over ticks_total (spec: movement.md §15 mantle-hit slow 80% -> 20%).
func current_value() -> float:
	if is_nan(taper_to) or ticks_total <= 0 or ticks_left < 0:
		return value
	var elapsed := float(ticks_total - ticks_left)
	var t := clampf(elapsed / float(ticks_total), 0.0, 1.0)
	return lerpf(value, taper_to, t)


func duplicate_mod() -> ActiveModifier:
	var m := ActiveModifier.new()
	m.id = id
	m.stat = stat
	m.value = value
	m.taper_to = taper_to
	m.ticks_left = ticks_left
	m.ticks_total = ticks_total
	m.source = source
	return m


func to_dict() -> Dictionary:
	return {
		"id": String(id), "stat": stat, "value": value,
		"taper_to": taper_to, "ticks_left": ticks_left,
		"ticks_total": ticks_total, "source": String(source),
	}


static func from_dict(d: Dictionary) -> ActiveModifier:
	var m := ActiveModifier.new()
	m.id = StringName(d.get("id", ""))
	m.stat = int(d.get("stat", 0))
	m.value = float(d.get("value", 0.0))
	m.taper_to = float(d.get("taper_to", NAN))
	m.ticks_left = int(d.get("ticks_left", -1))
	m.ticks_total = int(d.get("ticks_total", 0))
	m.source = StringName(d.get("source", ""))
	return m
