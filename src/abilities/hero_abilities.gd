class_name HeroAbilities
extends Node
## A hero's 4 ability slots and active items (specs/abilities.md). Owns unlocks, AP and the
## upgrade refund window, evaluates properties against the stat sheet, and steps every
## CastSlot on the player's movement tick. Effects live in AbilityEffects.
## Keys: 1–4 cast, Alt+1–4 unlock / upgrade, Alt+Backspace undo the last upgrade (10 s window),
## Z X T G cast active items in slot order.

signal changed

const ABILITY_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const ITEM_KEYS := [KEY_Z, KEY_X, KEY_T, KEY_G]
const ITEM_KEY_NAMES := ["Z", "X", "T", "G"]
const MAX_TIER := 3

var hero: HeroStats
var player: PlayerCharacter
var sampler: InputSampler
var effects: AbilityEffects

var kit_key: StringName = &""
var abilities: Array[AbilityData] = []
var tiers: Array[int] = [-1, -1, -1, -1]      # -1 locked, 0 unlocked, 1..3 upgraded
var casts: Array[CastSlot] = []
var ap_spent: int = 0
var item_casts: Dictionary = {}               # item id -> CastSlot

var _refund: Array = []                       # [[slot, seconds left]], newest last
var _queue: Array = []                        # presses waiting for the next tick: [kind, key]


func bind(p_hero: HeroStats, p_player: PlayerCharacter, p_sampler: InputSampler) -> void:
	hero = p_hero
	player = p_player
	sampler = p_sampler
	hero.inventory.changed.connect(_sync_items)
	hero.level_changed.connect(func(_l: int) -> void: changed.emit())
	if player != null:
		player.ticked.connect(func(_t: int, _s: MoveState) -> void: step(MoveUnits.DT))
		player.jumped.connect(func(_k: StringName) -> void: cancel_channels())
	_sync_items()


func set_kit(key: StringName) -> void:
	kit_key = key
	abilities = AbilityDB.kit(key)
	tiers = [-1, -1, -1, -1]
	ap_spent = 0
	_refund.clear()
	casts.clear()
	for i in abilities.size():
		var c := CastSlot.new(abilities[i])
		c.fired.connect(_on_fired.bind(abilities[i]))
		casts.append(c)
	_configure_all()
	changed.emit()


func level() -> int:
	return maxi(0, hero.boons) if hero != null else 0


func ap_available() -> int:
	return Progression.ap_total(level()) - ap_spent


func unlocks_available() -> int:
	var used := 0
	for i in abilities.size():
		if tiers[i] >= 0 and not abilities[i].is_ultimate:
			used += 1
	return Progression.regular_unlocks(level()) - used


func is_unlocked(i: int) -> bool:
	return i < tiers.size() and tiers[i] >= 0


## What Alt+key on slot i would do: "unlock", "upgrade", or "" when it can't.
func level_action(i: int) -> String:
	if i >= abilities.size():
		return ""
	if tiers[i] < 0:
		if abilities[i].is_ultimate:
			return "unlock" if Progression.ultimate_unlocked(level()) else ""
		return "unlock" if unlocks_available() > 0 else ""
	if tiers[i] >= MAX_TIER:
		return ""
	return "upgrade" if ap_available() >= Progression.TIER_AP[tiers[i]] else ""


func level_up(i: int) -> bool:
	match level_action(i):
		"unlock":
			tiers[i] = 0
		"upgrade":
			ap_spent += Progression.TIER_AP[tiers[i]]
			tiers[i] += 1
			_refund.append([i, Progression.REFUND_WINDOW])
		_:
			return false
	_configure_all()
	changed.emit()
	return true


## Undo the newest upgrade still inside its window (unlocks can't be refunded, M4).
func refund_last() -> bool:
	if _refund.is_empty():
		return false
	var i: int = _refund.pop_back()[0]
	tiers[i] -= 1
	ap_spent -= Progression.TIER_AP[tiers[i]]
	_configure_all()
	changed.emit()
	return true


func can_refund() -> bool:
	return not _refund.is_empty()


## Kit ability value at its current tier, or an item's (tier 0).
func prop(a: AbilityData, name: StringName) -> float:
	var i := abilities.find(a)
	var tier := maxi(0, tiers[i]) if i >= 0 else 0
	return a.value(name, tier, hero.sheet, hero.spirit_power(), level())


func tier_of(a: AbilityData) -> int:
	var i := abilities.find(a)
	return tiers[i] if i >= 0 else 0


func press_ability(i: int) -> void:
	_queue.append([&"ability", i])


func press_item(n: int) -> void:
	var ids := active_items()
	if n < ids.size():
		_queue.append([&"item", ids[n]])


func cancel_channels() -> void:
	for c in casts:
		if c.kind() == AbilityData.Kind.CHANNEL:
			c.cancel()


## Owned active item ids in inventory slot order (their cast keys).
func active_items() -> Array:
	var out := []
	for id in hero.inventory.owned():
		var it := ItemDB.get_item(id)
		if it != null and it.ability != null:
			out.append(id)
	return out


func step(dt: float) -> void:
	for q in _queue:
		_do_press(q[0], q[1])
	_queue.clear()
	for r in _refund:
		r[1] -= dt
	_refund = _refund.filter(func(r: Array) -> bool: return r[1] > 0.0)
	_configure_all()
	for c in casts:
		c.step(dt)
	for id in item_casts:
		item_casts[id].step(dt)
	if effects != null:
		effects.step(dt)


func _do_press(kind: StringName, key: Variant) -> void:
	var c: CastSlot
	if kind == &"ability":
		if not is_unlocked(key):
			return
		c = casts[key]
	else:
		c = item_casts.get(key)
	if c != null and c.press():
		_refund.clear()   # any cast closes the refund window (M4)
		changed.emit()


func _on_fired(event: StringName, a: AbilityData) -> void:
	if effects != null:
		effects.on_event(a, event)
	changed.emit()


func _configure_all() -> void:
	if hero == null:
		return
	for i in casts.size():
		_configure(casts[i])
	for id in item_casts:
		_configure(item_casts[id])


func _configure(c: CastSlot) -> void:
	var a := c.data
	var charges := int(roundf(prop(a, &"charges"))) if a.has_prop(&"charges") else 1
	c.configure(prop(a, &"cooldown"), charges, a.base_value(&"between", tier_of(a)),
			a.base_value(&"cast_delay", tier_of(a)), prop(a, &"channel"))


func _sync_items() -> void:
	var ids := active_items()
	for id in item_casts.keys():
		if not ids.has(id):
			var c: CastSlot = item_casts[id]
			if c.phase == CastSlot.Phase.ACTIVE and effects != null:
				effects.on_event(c.data, &"toggle_off")   # sold while on
			item_casts.erase(id)
	for id in ids:
		if not item_casts.has(id):
			var a := ItemDB.get_item(id).ability
			var c := CastSlot.new(a)
			c.fired.connect(_on_fired.bind(a))
			item_casts[id] = c
	_configure_all()
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if sampler != null and sampler.ui_open:
		return
	var e := event as InputEventKey
	var k := e.physical_keycode
	var i := ABILITY_KEYS.find(k)
	if i >= 0:
		if e.alt_pressed:
			level_up(i)
		else:
			press_ability(i)
		get_viewport().set_input_as_handled()
	elif e.alt_pressed and k == KEY_BACKSPACE:
		refund_last()
		get_viewport().set_input_as_handled()
	elif ITEM_KEYS.has(k) and not e.alt_pressed:
		press_item(ITEM_KEYS.find(k))
		get_viewport().set_input_as_handled()
