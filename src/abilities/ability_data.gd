class_name AbilityData
extends RefCounted
## One ability or active item (specs/abilities.md M3–M11). Every number is a property:
## value = base + upgrade deltas + Σ coef × stat, then the property's multiplier (cooldown
## reduction, duration or range), see value().

enum Kind { INSTANT, CHANNEL, TOGGLE, PASSIVE }

const KIND_NAMES := ["instant", "channel", "toggle", "passive"]

var id: StringName = &""
var display_name: String = ""
var kind: Kind = Kind.INSTANT
var is_ultimate: bool = false
var is_item: bool = false
var effect: StringName = &""
## Cooldown starts when the channel ends / the toggle turns off instead of on press.
var cd_on_end: bool = false
## prop -> {base: float, sp: float, boon: float, mult: "cooldown"|"duration"|"range"|"radius"|"charges"|""}
var props: Dictionary = {}
## 3 tiers: {text: String, add: {prop: delta}, sp: {prop: coef}}
var upgrades: Array = []

## Which multiplier a property gets when the data doesn't say.
const DEFAULT_MULT := {
	&"cooldown": "cooldown", &"charges": "charges", &"duration": "duration", &"radius": "radius", &"range": "range",
}


static func from_dict(e: Dictionary) -> AbilityData:
	var a := AbilityData.new()
	a.id = StringName(e["id"])
	a.display_name = e.get("name", String(a.id))
	a.kind = maxi(0, KIND_NAMES.find(e.get("kind", "instant"))) as Kind
	a.is_ultimate = bool(e.get("ultimate", false))
	a.effect = StringName(e.get("effect", ""))
	a.cd_on_end = bool(e.get("cd_on_end", false))
	var p: Dictionary = e.get("props", {})
	for k in p:
		var v: Variant = p[k]
		var d: Dictionary = v if v is Dictionary else {"base": v}
		a.props[StringName(k)] = {
			"base": float(d.get("base", 0.0)), "sp": float(d.get("sp", 0.0)), "boon": float(d.get("boon", 0.0)),
			"mult": String(d.get("mult", DEFAULT_MULT.get(StringName(k), ""))),
		}
	for u in e.get("upgrades", []):
		a.upgrades.append({"text": u.get("text", ""), "add": u.get("add", {}), "sp": u.get("sp", {})})
	return a


func has_prop(prop: StringName) -> bool:
	return props.has(prop)


## Base value with upgrades 1..tier applied, before stats.
func base_value(prop: StringName, tier: int) -> float:
	var v := float(props.get(prop, {}).get("base", 0.0))
	for t in mini(tier, upgrades.size()):
		v += float(upgrades[t]["add"].get(String(prop), 0.0))
	return v


## spec: abilities.md M9–M11. `sp` is total spirit power, `boons` the boon count.
func value(prop: StringName, tier: int, sheet: StatSheet, sp: float, boons: int) -> float:
	var p: Dictionary = props.get(prop, {})
	var v := base_value(prop, tier)
	var sp_coef := float(p.get("sp", 0.0))
	for t in mini(tier, upgrades.size()):
		sp_coef += float(upgrades[t]["sp"].get(String(prop), 0.0))
	v += sp_coef * sp + float(p.get("boon", 0.0)) * boons
	if sheet == null:
		return v
	match String(p.get("mult", "")):
		"cooldown":
			v *= 1.0 - sheet.get_stat(StatDefs.ITEM_COOLDOWN if is_item else StatDefs.COOLDOWN) / 100.0
		"duration":
			v *= 1.0 + sheet.get_stat(StatDefs.DURATION) / 100.0
		"range":
			v *= 1.0 + sheet.get_stat(StatDefs.RANGE) / 100.0
		"radius":
			v *= 1.0 + sheet.get_stat(StatDefs.RADIUS) / 100.0
		"charges":
			# bonus charges only go to abilities that already have charges (M7)
			if v > 1.0 and not is_item:
				v += sheet.get_stat(StatDefs.CHARGES)
	return v
