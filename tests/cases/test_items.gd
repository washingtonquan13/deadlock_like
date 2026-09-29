extends MoveTestCase
## Stat stacking and shop rules (specs/stats.md, specs/economy.md §14–15). Loose on purpose.


func _sheet(stat: StringName, values: Array) -> StatSheet:
	var s := StatSheet.new()
	for i in values.size():
		s.set_source(StringName("s%d" % i), {stat: values[i]})
	return s


## spec: stats.md implementation notes (worked examples)
func test_stat_folds() -> void:
	assert_near(_sheet(StatDefs.COOLDOWN, [20, 5]).get_stat(StatDefs.COOLDOWN), 24.0, 1e-4, "CDR 1-Π")
	assert_near(_sheet(StatDefs.DURATION, [15, 15]).get_stat(StatDefs.DURATION), 27.75, 1e-4, "duration 1-Π")
	assert_near(_sheet(StatDefs.MOVE_SPEED, [2, 3]).get_stat(StatDefs.MOVE_SPEED), 4.5, 1e-4, "move DR")
	assert_near(_sheet(StatDefs.WEAPON_DAMAGE, [8, 14]).get_stat(StatDefs.WEAPON_DAMAGE), 22.0, 1e-4, "additive pool")
	var fr := StatSheet.new()
	fr.set_source(&"a", {StatDefs.FIRE_RATE: 38})
	fr.set_source(&"b", {StatDefs.FIRE_RATE_SLOW: 25})
	fr.set_source(&"c", {StatDefs.FIRE_RATE_SLOW: 28})
	assert_near(StatDefs.fire_rate_mult(fr), 1.0 / 1.08, 1e-3, "fire rate -8%")
	var clip := StatSheet.new()
	clip.set_source(&"a", {StatDefs.CLIP: 10, StatDefs.CLIP_PCT: 19})
	assert_eq(StatDefs.clip_size(clip, 20), 36, "clip (20+10)*1.19 rounds up")
	done()


## spec: economy.md §14–15
func test_shop_buy_upgrade_sell() -> void:
	var inv := Inventory.new()
	inv.add_souls(2400)
	assert_true(inv.buy(&"wide_mag"), "buy T1")
	assert_near(inv.sheet.get_stat(StatDefs.WEAPON_DAMAGE), 8.0 + 9.0, 1e-4, "item + first investment step")
	assert_eq(inv.price_of(ItemDB.get_item(&"drum_mag")), 800, "component credited")
	assert_true(inv.buy(&"drum_mag"), "upgrade")
	assert_true(not inv.owns(&"wide_mag"), "component consumed")
	assert_eq(inv.owned().size(), 1, "upgrade reuses the slot")
	assert_eq(inv.spent[ItemData.Category.WEAPON], 1600, "spend counts the upgrade once")
	assert_near(inv.sheet.get_stat(StatDefs.WEAPON_DAMAGE), 14.0 + 12.0, 1e-4, "upgrade stats replace the component's")
	inv.leave_shop()
	assert_true(inv.sell(&"drum_mag"), "sell")
	assert_eq(inv.souls, 800 + 800, "50% refund after leaving the shop")
	assert_near(inv.sheet.get_stat(StatDefs.WEAPON_DAMAGE), 0.0, 1e-4, "bonus gone")
	done()


## spec: stats.md §4 health
func test_max_health_formula() -> void:
	var s := StatSheet.new()
	s.set_source(&"invest", {StatDefs.VITALITY: 20})
	s.set_source(&"item", {StatDefs.HEALTH: 210})
	assert_near(StatDefs.max_health(s, 700.0, 30.0, 2), ceilf(760.0 * 1.2 + 210.0), 1e-4, "(base+boons)*(1+vit)+flat")
	done()


## spec: stats.md §4 (clip, max HP) wired through the hero's sheet
func test_hero_stats_hooks() -> void:
	var hs := HeroStats.new()
	var wc := WeaponController.new()
	wc.set_weapon(&"haze")
	var base_clip := wc.weapon.clip_size
	hs.bind(null, wc)
	hs._refresh_health(true)
	var hp0 := hs.max_hp
	hs.inventory.add_souls(1600)
	assert_true(hs.inventory.buy(&"wide_mag") and hs.inventory.buy(&"stout_heart"), "buy")
	assert_true(wc.weapon.clip_size > base_clip, "clip grows")
	assert_true(wc.damage_per_bullet() > wc.base_weapon.damage_at_boons(0), "damage grows")
	assert_true(hs.max_hp > hp0 + 200.0, "max HP grows")
	assert_near(hs.max_hp - hs.hp, 0.0, 1e-3, "missing HP kept")
	wc.free()
	hs.free()
	done()
