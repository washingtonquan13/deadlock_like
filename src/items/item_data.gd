class_name ItemData
extends RefCounted
## One shop item (specs/economy.md §14). Passive stats go straight onto the owner's StatSheet.

enum Category { WEAPON, VITALITY, SPIRIT }

const TIER_COST := [0, 800, 1600, 3200, 6400]
const CATEGORY_NAMES := ["weapon", "vitality", "spirit"]

var id: StringName = &""
var display_name: String = ""
var category: Category = Category.WEAPON
var tier: int = 1
var cost: int = 800
var component: StringName = &""   # the lower-tier item this upgrades from, "" = none
var is_active: bool = false
var stats: Dictionary = {}        # StringName stat -> float (StatDefs names)


static func from_dict(e: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(e["id"])
	it.display_name = e.get("name", String(it.id))
	it.category = maxi(0, CATEGORY_NAMES.find(e.get("category", "weapon"))) as Category
	it.tier = clampi(int(e.get("tier", 1)), 1, 4)
	it.cost = int(e.get("cost", TIER_COST[it.tier]))
	it.component = StringName(e.get("component", ""))
	it.is_active = bool(e.get("active", false))
	var s: Dictionary = e.get("stats", {})
	for k in s:
		if not StatDefs.is_known(StringName(k)):
			push_warning("ItemData %s: unknown stat '%s'" % [it.id, k])
		it.stats[StringName(k)] = float(s[k])
	return it
