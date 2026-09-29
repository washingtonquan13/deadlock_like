class_name Inventory
extends RefCounted
## Souls, item slots and investment bonuses (specs/economy.md §14–15). Owned items and the
## per-category investment bonus are sources on the hero's StatSheet (specs/stats.md §3).

signal changed

const BASE_SLOTS := 9
const MAX_EXTRA_SLOTS := 3
const MAX_ACTIVES := 4
const SELL_REFUND := 0.5

## Investment: the highest threshold at or below the souls spent in a category applies.
const INVEST_THRESHOLDS := [800, 1600, 2400, 3200, 4800, 6400, 8000, 11200, 16000, 22400, 28800]
## Weapon: % weapon damage. Vitality: % base HP (the wiki says the first step is 8; the data says 9).
## Spirit: flat spirit power.
const INVEST_BONUS := [
	[9, 12, 15, 18, 46, 54, 62, 74, 86, 100, 115],
	[9, 12, 15, 20, 38, 42, 46, 50, 54, 60, 66],
	[7, 11, 15, 19, 38, 45, 52, 59, 66, 75, 100],
]
const INVEST_STAT := [StatDefs.WEAPON_DAMAGE, StatDefs.VITALITY, StatDefs.SPIRIT_POWER]
const INVEST_SOURCE := [&"invest:weapon", &"invest:vitality", &"invest:spirit"]

var sheet: StatSheet
var souls: int = 0
var extra_slots: int = 0
var slots: Array[StringName] = []   # item id per slot, &"" = empty
var spent: Array[int] = [0, 0, 0]   # souls spent per category (economy §15)
var _paid: Dictionary = {}          # item id -> souls paid in total (for the sell refund)
var _undo: Dictionary = {}          # item id -> true while the full-refund window is open


func _init(p_sheet: StatSheet = null) -> void:
	sheet = p_sheet if p_sheet != null else StatSheet.new()
	slots.resize(BASE_SLOTS + MAX_EXTRA_SLOTS)
	slots.fill(&"")


static func invest_bonus(cat: int, spent_souls: int) -> float:
	var b := 0.0
	for i in INVEST_THRESHOLDS.size():
		if spent_souls >= INVEST_THRESHOLDS[i]:
			b = INVEST_BONUS[cat][i]
	return b


func slot_count() -> int:
	return BASE_SLOTS + extra_slots


func owns(id: StringName) -> bool:
	return slots.has(id)


func owned() -> Array:
	return slots.filter(func(s: StringName) -> bool: return s != &"")


func add_souls(n: int) -> void:
	souls += n
	changed.emit()


func add_extra_slot() -> void:
	extra_slots = mini(extra_slots + 1, MAX_EXTRA_SLOTS)
	changed.emit()


## What buying costs now: an owned component is credited in full.
func price_of(it: ItemData) -> int:
	var comp := ItemDB.get_item(it.component) if it.component != &"" else null
	if comp != null and owns(comp.id):
		return it.cost - _paid.get(comp.id, comp.cost)
	return it.cost


## "" when buyable, else why not.
func buy_block_reason(it: ItemData) -> String:
	if it == null:
		return "unknown item"
	if owns(it.id):
		return "owned"
	if price_of(it) > souls:
		return "souls"
	var upgrading := it.component != &"" and owns(it.component)
	if not upgrading and _free_slot() < 0:
		return "slots"
	if it.is_active:
		var comp_active := upgrading and ItemDB.get_item(it.component).is_active
		if not comp_active and _active_count() >= MAX_ACTIVES:
			return "actives"
	return ""


func can_buy(it: ItemData) -> bool:
	return buy_block_reason(it) == ""


func buy(id: StringName) -> bool:
	var it := ItemDB.get_item(id)
	if not can_buy(it):
		return false
	var price := price_of(it)
	souls -= price
	var slot := _free_slot()
	if it.component != &"" and owns(it.component):
		# the upgrade consumes the component and takes its slot; its spend moves to the upgrade
		var comp := ItemDB.get_item(it.component)
		slot = slots.find(comp.id)
		spent[comp.category] -= _paid.get(comp.id, comp.cost)
		_remove(comp.id)
	slots[slot] = id
	_paid[id] = it.cost
	_undo[id] = true
	spent[it.category] += it.cost
	sheet.set_source(_source(id), it.stats)
	_refresh_investment()
	changed.emit()
	return true


func sell_value(id: StringName) -> int:
	var paid: int = _paid.get(id, 0)
	return paid if _undo.get(id, false) else int(floor(paid * SELL_REFUND))


func sell(id: StringName) -> bool:
	if not owns(id):
		return false
	var it := ItemDB.get_item(id)
	souls += sell_value(id)
	spent[it.category] = maxi(0, spent[it.category] - _paid.get(id, it.cost))   # unverified, economy §15
	slots[slots.find(id)] = &""
	_remove(id)
	_refresh_investment()
	changed.emit()
	return true


## Leaving the shop area closes the full-refund window on everything bought.
func leave_shop() -> void:
	_undo.clear()


func _remove(id: StringName) -> void:
	var i := slots.find(id)
	if i >= 0:
		slots[i] = &""
	_paid.erase(id)
	_undo.erase(id)
	sheet.clear_source(_source(id))


func _refresh_investment() -> void:
	for cat in 3:
		var b := invest_bonus(cat, spent[cat])
		sheet.set_source(INVEST_SOURCE[cat], {INVEST_STAT[cat]: b} if b > 0.0 else {})


func _free_slot() -> int:
	for i in slot_count():
		if slots[i] == &"":
			return i
	return -1


func _active_count() -> int:
	var n := 0
	for id in owned():
		var it := ItemDB.get_item(id)
		if it != null and it.is_active:
			n += 1
	return n


static func _source(id: StringName) -> StringName:
	return StringName("item:" + String(id))
