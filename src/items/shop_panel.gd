class_name ShopPanel
extends Control
## Debug shop (mockup B): category tabs, tier columns, souls, 9+3 inventory slots, investment
## bars and a stat readout. B toggles it; while open the mouse is free and firing is blocked.
## Closing counts as leaving the shop (the full-refund window ends).

const CAT_COLORS := [Color("e8923a"), Color("5fbf5a"), Color("a66ad8")]
const CAT_TITLES := ["Weapon", "Vitality", "Spirit"]
const TIERS := [1, 2, 3, 4]

var hero: HeroStats
var sampler: InputSampler

var _cat: int = 0
var _souls: Label
var _tabs: Array[Button] = []
var _columns: Array[VBoxContainer] = []
var _slots: Array[Button] = []
var _bars: Array[ProgressBar] = []
var _bar_labels: Array[Label] = []
var _readout: Label


func bind(p_hero: HeroStats, p_sampler: InputSampler) -> void:
	hero = p_hero
	sampler = p_sampler
	hero.inventory.changed.connect(_refresh)
	_refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).physical_keycode
	if k == KEY_B or (visible and k == KEY_ESCAPE):
		set_open(not visible)
		get_viewport().set_input_as_handled()


func set_open(on: bool) -> void:
	visible = on
	if sampler != null:
		sampler.ui_open = on
		sampler.set_mouse_captured(not on)
	if not on and hero != null:
		hero.inventory.leave_shop()
	_refresh()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 660)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.1, 0.12, 0.97)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override(&"panel", bg)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 10)
	panel.add_child(root)

	# header: tabs, souls, debug buttons
	var head := HBoxContainer.new()
	root.add_child(head)
	for c in 3:
		var t := Button.new()
		t.text = CAT_TITLES[c]
		t.toggle_mode = true
		t.custom_minimum_size = Vector2(120, 34)
		t.add_theme_color_override(&"font_color", CAT_COLORS[c])
		t.add_theme_color_override(&"font_pressed_color", Color.WHITE)
		t.pressed.connect(func() -> void: _cat = c; _refresh())
		head.add_child(t)
		_tabs.append(t)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_souls = Label.new()
	_souls.add_theme_font_size_override(&"font_size", 20)
	_souls.add_theme_color_override(&"font_color", Color("7fe0d0"))
	head.add_child(_souls)
	for d in [["+1000", func() -> void: hero.inventory.add_souls(1000)],
			["+10000", func() -> void: hero.inventory.add_souls(10000)],
			["+slot", func() -> void: hero.inventory.add_extra_slot()],
			["hurt 200", func() -> void: hero.take_damage(200.0)]]:
		var b := Button.new()
		b.text = d[0]
		b.pressed.connect(d[1])
		head.add_child(b)

	# body: tier columns | investment + readout
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 12)
	root.add_child(body)
	for t in TIERS:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(190, 0)
		var h := Label.new()
		h.text = "%d" % ItemData.TIER_COST[t]
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_font_size_override(&"font_size", 18)
		col.add_child(h)
		body.add_child(col)
		_columns.append(col)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(side)
	for c in 3:
		var l := Label.new()
		l.add_theme_color_override(&"font_color", CAT_COLORS[c])
		side.add_child(l)
		_bar_labels.append(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = CAT_COLORS[c]
		bar.add_theme_stylebox_override(&"fill", fill)
		side.add_child(bar)
		_bars.append(bar)
	_readout = Label.new()
	_readout.add_theme_font_size_override(&"font_size", 13)
	side.add_child(_readout)

	# inventory: 9 base + 3 extra slots, click to sell
	var inv_row := HBoxContainer.new()
	inv_row.add_theme_constant_override(&"separation", 6)
	root.add_child(inv_row)
	for i in Inventory.BASE_SLOTS + Inventory.MAX_EXTRA_SLOTS:
		var s := Button.new()
		s.custom_minimum_size = Vector2(86, 56)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override(&"font_size", 12)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(1, 1, 1, 0.04)
		frame.border_color = Color(1, 1, 1, 0.18)
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(4)
		s.add_theme_stylebox_override(&"disabled", frame)
		s.pressed.connect(_on_slot_pressed.bind(i))
		inv_row.add_child(s)
		_slots.append(s)
	var hint := Label.new()
	hint.text = "click an item to buy, a slot to sell   B / Esc close"
	hint.modulate = Color(1, 1, 1, 0.6)
	root.add_child(hint)


func _refresh() -> void:
	if hero == null or not is_inside_tree():
		return
	var inv := hero.inventory
	_souls.text = "%d souls" % inv.souls
	for c in 3:
		_tabs[c].button_pressed = c == _cat
	for ti in TIERS.size():
		var col := _columns[ti]
		for i in range(col.get_child_count() - 1, 0, -1):
			var n := col.get_child(i)
			col.remove_child(n)
			n.queue_free()
		for it: ItemData in ItemDB.by_category_tier(_cat, TIERS[ti]):
			col.add_child(_card(it))
	for c in 3:
		var spent := inv.spent[c]
		var next := _next_threshold(spent)
		var bonus := Inventory.invest_bonus(c, spent)
		var unit := " SP" if c == ItemData.Category.SPIRIT else "%"
		_bar_labels[c].text = "%s  %d spent  +%s%s" % [CAT_TITLES[c], spent, _fmt(bonus), unit] \
				+ ("   next at %d" % next if next > 0 else "")
		_bars[c].max_value = maxf(1.0, next if next > 0 else spent)
		_bars[c].value = spent
	for i in _slots.size():
		var s := _slots[i]
		var id := inv.slots[i]
		s.disabled = i >= inv.slot_count() or id == &""
		if i >= inv.slot_count():
			s.text = "locked"
			s.modulate = Color(1, 1, 1, 0.3)
			s.tooltip_text = ""
		elif id == &"":
			s.text = ""
			s.modulate = Color.WHITE
			s.tooltip_text = ""
		else:
			var it := ItemDB.get_item(id)
			s.text = it.display_name
			s.modulate = CAT_COLORS[it.category].lightened(0.3)
			s.tooltip_text = "sell for %d" % inv.sell_value(id)
	_readout.text = _stat_text()


func _card(it: ItemData) -> Button:
	var inv := hero.inventory
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var why := inv.buy_block_reason(it)
	var price := inv.price_of(it)
	var up := " (upgrade)" if it.component != &"" and inv.owns(it.component) else ""
	if why == "owned":
		up = "  OWNED"
	b.text = "%s  %d%s\n%s" % [it.display_name, price, up, _stats_line(it.stats)]
	b.tooltip_text = ("from " + ItemDB.get_item(it.component).display_name + "\n" if it.component != &"" else "") \
			+ ("" if why == "" else "can't buy: " + why)
	b.add_theme_font_size_override(&"font_size", 12)
	b.add_theme_color_override(&"font_color", CAT_COLORS[it.category].lightened(0.35))
	if why != "":
		b.modulate = Color(1, 1, 1, 0.45) if why != "owned" else Color(0.75, 1.0, 0.75)
	b.pressed.connect(func() -> void: inv.buy(it.id))
	return b


func _on_slot_pressed(i: int) -> void:
	var id := hero.inventory.slots[i]
	if id != &"":
		hero.inventory.sell(id)


func _stat_text() -> String:
	var t := hero.sheet.totals()
	var lines: Array[String] = ["", "max HP %d   regen %.1f/s   SP %s" % [
		int(hero.max_hp), hero.regen_per_second(), _fmt(hero.spirit_power())]]
	for k in t:
		if absf(t[k]) > 1e-6:
			lines.append("%s  %s" % [k, _fmt(t[k])])
	return "\n".join(lines)


static func _stats_line(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for k in stats:
		parts.append("%s %s" % [String(k).replace("_", " "), _fmt(stats[k])])
	return ", ".join(parts)


static func _next_threshold(spent: int) -> int:
	for th in Inventory.INVEST_THRESHOLDS:
		if spent < th:
			return th
	return 0


static func _fmt(v: float) -> String:
	return ("%d" % int(roundf(v))) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)
