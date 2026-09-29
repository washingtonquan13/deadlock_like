class_name HeroStats
extends Node
## A hero's stat sheet, inventory and health (specs/stats.md, economy.md §14–15, combat.md §7).
## Pushes the sheet into the gun (WeaponController.set_stats) and into the movement modifier
## stack, so each system keeps its own stacking (movement does its own move-speed DR).

signal health_changed(hp: float, max_hp: float)
signal level_changed(level: int)

## Combat timer vs heroes (combat.md §7): out-of-combat regen starts this long after damage.
const COMBAT_TIMER := 4.0

## Sheet stat -> movement modifier stat and the factor from our units to its units.
const MOVE_STATS := {
	StatDefs.MOVE_SPEED: [ModifierDef.Stat.MOVE_BONUS, 1.0],
	StatDefs.SPRINT_SPEED: [ModifierDef.Stat.SPRINT_BONUS, 1.0],
	StatDefs.STAMINA: [ModifierDef.Stat.STAMINA_MAX, 1.0],
	StatDefs.STAMINA_RECOVERY: [ModifierDef.Stat.STAMINA_RECOVERY, 0.01],
	StatDefs.AIR_MOVE: [ModifierDef.Stat.AIR_ACTION_DIST_PCT, 0.01],
	StatDefs.SLOW_RESIST: [ModifierDef.Stat.SLOW_RESIST, 0.01],
}

@export var hero_key: StringName = &"haze"
## Boon count = level from total souls earned (abilities.md M1); never goes down.
var boons: int = 0
@export var starting_souls: int = 600

var sheet := StatSheet.new()
var inventory: Inventory
var player: PlayerCharacter
var weapon_ctrl: WeaponController

var hp: float = 0.0
var max_hp: float = 0.0
var since_damage: float = 1e9

var _move_ids: Array[StringName] = []
var _base: Dictionary = {}


func _init() -> void:
	inventory = Inventory.new(sheet)
	inventory.souls = starting_souls
	inventory.earned = starting_souls
	sheet.changed.connect(_on_sheet_changed)
	inventory.changed.connect(_update_level)


func _ready() -> void:
	inventory.souls = starting_souls
	inventory.earned = starting_souls
	_update_level()
	_refresh_health(true)


func bind(p: PlayerCharacter, wc: WeaponController) -> void:
	player = p
	weapon_ctrl = wc
	if wc != null:
		wc.boons = boons
		wc.set_stats(sheet)
	_push_movement()


func set_hero(key: StringName) -> void:
	hero_key = key
	_refresh_health(false)


func base_regen() -> float:
	return float(_hero().get("regen", 2.0))


## HP/s right now: base + items always, plus out-of-combat regen after the combat timer.
func regen_per_second() -> float:
	var r := base_regen() + sheet.get_stat(StatDefs.REGEN)
	if since_damage >= COMBAT_TIMER:
		r += sheet.get_stat(StatDefs.OOC_REGEN)
	return r


func spirit_power() -> float:
	return StatDefs.spirit_power(sheet, boons * float(_hero().get("spirit_per_boon", 1.1)))


func _update_level() -> void:
	var lv := maxi(boons, Progression.level_for(inventory.earned))
	if lv == boons:
		return
	boons = lv
	if weapon_ctrl != null:
		weapon_ctrl.boons = boons
	_refresh_health(false)
	level_changed.emit(boons)


func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	since_damage = 0.0
	health_changed.emit(hp, max_hp)


## Self-inflicted health cost (toggle drains): doesn't start the combat timer and stops at
## 1 HP (whether a drain can kill is unmeasured).
func drain(amount: float) -> void:
	hp = maxf(minf(hp, 1.0), hp - amount)
	health_changed.emit(hp, max_hp)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func _process(delta: float) -> void:
	since_damage += delta
	if hp < max_hp and hp > 0.0:
		heal(regen_per_second() * delta)


func _hero() -> Dictionary:
	if _base.is_empty() or _base.get("_key") != hero_key:
		_base = WeaponDB.get_hero(hero_key).duplicate()
		_base["_key"] = hero_key
	return _base


func _on_sheet_changed() -> void:
	_refresh_health(false)
	_push_movement()


## Max HP from the spec formula. A change in max HP moves current HP by the same amount
## (stats.md Open question 6 is unmeasured; this keeps the missing HP the same).
func _refresh_health(fill: bool) -> void:
	var h := _hero()
	var new_max := StatDefs.max_health(sheet, float(h.get("health", 700.0)), float(h.get("health_per_boon", 0.0)), boons)
	if fill or max_hp <= 0.0:
		hp = new_max
	else:
		hp = clampf(hp + (new_max - max_hp), 1.0, new_max)
	max_hp = new_max
	health_changed.emit(hp, max_hp)


## One movement modifier per (source, stat), so move speed keeps its per-source DR.
func _push_movement() -> void:
	if player == null:
		return
	for id in _move_ids:
		player.push_external({"op": &"remove_modifier", "id": id})
	_move_ids.clear()
	for src in sheet.sources():
		var m := sheet.get_source(src)
		for stat in m:
			if not MOVE_STATS.has(stat):
				continue
			var map: Array = MOVE_STATS[stat]
			var id := StringName("stat:%s:%s" % [src, stat])
			var def := ModifierDef.make(id, int(map[0]), float(m[stat]) * float(map[1]))
			player.push_external({"op": &"add_modifier", "def": def, "source": src})
			_move_ids.append(id)
