class_name AbilityBar
extends Control
## Ability bar (mockup A, specs/hud.md): 4 slots bottom-centre with the ultimate last, a
## cooldown sweep with the seconds left (decimals under 2 s), charge count, 3 upgrade pips,
## an "unlock"/"+" hint when Alt+key would do something, the level / AP line, and the active
## items to the right.

const SLOT := 76.0
const GAP := 10.0
const ITEM := 50.0
const COL_BG := Color(0.24, 0.26, 0.31, 0.9)
const COL_EDGE := Color(1, 1, 1, 0.25)
const COL_ULT := Color("e8b64a")
const COL_SWEEP := Color(0.02, 0.02, 0.03, 0.72)
const COL_PIP := Color("a66ad8")
const COL_HINT := Color("7fe0d0")

var abilities: HeroAbilities
var _font: Font


func bind(p: HeroAbilities) -> void:
	abilities = p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if abilities == null or abilities.abilities.is_empty():
		return
	var n := abilities.abilities.size()
	var width := n * SLOT + (n - 1) * GAP
	var x0 := (size.x - width) * 0.5
	var y0 := size.y - SLOT - 44.0
	for i in n:
		_draw_slot(i, Rect2(x0 + i * (SLOT + GAP), y0, SLOT, SLOT))
	var lv := abilities.level()
	var line := "Lv %d   AP %d" % [lv, abilities.ap_available()]
	if abilities.unlocks_available() > 0:
		line += "   unlock ready (Alt+key)"
	if abilities.can_refund():
		line += "   Alt+Bksp undo"
	_text(line, Vector2(x0, y0 - 24.0), 14, Color(1, 1, 1, 0.8))
	var ids := abilities.active_items()
	var ix := x0 + width + GAP * 3.0
	for k in ids.size():
		_draw_item(ids[k], HeroAbilities.ITEM_KEY_NAMES[k], Rect2(ix + k * (ITEM + 6.0), y0 + SLOT - ITEM, ITEM, ITEM))


func _draw_slot(i: int, r: Rect2) -> void:
	var a := abilities.abilities[i]
	var c := abilities.casts[i]
	var tier := abilities.tiers[i]
	var edge := COL_ULT if a.is_ultimate else COL_EDGE
	draw_rect(r, COL_BG)
	if tier < 0:
		draw_rect(r, Color(0, 0, 0, 0.45))
	else:
		_sweep(r, c.sweep())
		if c.phase == CastSlot.Phase.CHANNEL or c.phase == CastSlot.Phase.ACTIVE:
			draw_rect(r.grow(-2), Color(1.0, 0.6, 0.2, 0.25))
	draw_rect(r, edge, false, 2.0 if a.is_ultimate else 1.0)
	var name_col := Color(1, 1, 1, 0.35) if tier < 0 else Color.WHITE
	_text_center(a.display_name, Vector2(r.get_center().x, r.position.y + 18.0), 11, name_col, r.size.x - 6.0)
	if tier >= 0 and c.kind() != AbilityData.Kind.PASSIVE:
		var wait := c.wait_left()
		if wait > 0.0:
			_text_center(("%.1f" % wait) if wait < 2.0 else str(ceili(wait)), r.get_center() + Vector2(0, 8), 22, Color.WHITE)
		if c.max_charges > 1:
			_text(str(c.charges), r.position + Vector2(r.size.x - 14.0, r.size.y - 6.0), 14, COL_HINT)
	elif tier >= 0:
		_text_center("passive", r.get_center() + Vector2(0, 6), 11, Color(1, 1, 1, 0.5))
	# key under the slot, pips below it
	_text_center(str(i + 1), Vector2(r.get_center().x, r.end.y + 16.0), 13, Color(1, 1, 1, 0.7))
	for p in 3:
		var pr := Rect2(r.position.x + 10.0 + p * (r.size.x - 20.0) / 3.0, r.end.y + 22.0, (r.size.x - 20.0) / 3.0 - 4.0, 5.0)
		draw_rect(pr, COL_PIP if tier > p else Color(1, 1, 1, 0.15))
	var act := abilities.level_action(i)
	if act != "":
		var tag := "UNLOCK" if act == "unlock" else "+%d AP" % Progression.TIER_AP[tier]
		_text_center(tag, Vector2(r.get_center().x, r.position.y - 4.0), 11, COL_HINT)


func _draw_item(id: StringName, key: String, r: Rect2) -> void:
	var c: CastSlot = abilities.item_casts.get(id)
	var it := ItemDB.get_item(id)
	draw_rect(r, COL_BG)
	if c != null:
		_sweep(r, c.sweep())
		if c.phase == CastSlot.Phase.ACTIVE:
			draw_rect(r.grow(-2), Color(1.0, 0.25, 0.25, 0.3))
	draw_rect(r, _cat_color(it), false, 1.0)
	_text_center(it.display_name.get_slice(" ", 0), Vector2(r.get_center().x, r.position.y + 14.0), 10, Color.WHITE, r.size.x - 4.0)
	if c != null and c.wait_left() > 0.0:
		var w := c.wait_left()
		_text_center(("%.1f" % w) if w < 2.0 else str(ceili(w)), r.get_center() + Vector2(0, 10), 16, Color.WHITE)
	_text_center(key, Vector2(r.get_center().x, r.end.y + 14.0), 12, Color(1, 1, 1, 0.7))


static func _cat_color(it: ItemData) -> Color:
	return [Color("e8923a"), Color("5fbf5a"), Color("a66ad8")][it.category]


## Clockwise dark pie from 12 o'clock covering `frac` of the slot.
func _sweep(r: Rect2, frac: float) -> void:
	if frac <= 0.0:
		return
	var ctr := r.get_center()
	var rad := r.size.length() * 0.5
	var pts := PackedVector2Array([ctr])
	var steps := maxi(2, int(48 * frac))
	for s in steps + 1:
		var ang := -PI * 0.5 + TAU * (1.0 - frac) + TAU * frac * float(s) / steps
		pts.append(ctr + Vector2(cos(ang), sin(ang)) * rad)
	# clip the pie to the slot square
	var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for poly in Geometry2D.intersect_polygons(pts, clip):
		draw_colored_polygon(poly, COL_SWEEP)


func _text(t: String, pos: Vector2, fs: int, col: Color) -> void:
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_center(t: String, pos: Vector2, fs: int, col: Color, max_w: float = 200.0) -> void:
	var p := Vector2(pos.x - max_w * 0.5, pos.y)
	draw_string_outline(_font, p, t, HORIZONTAL_ALIGNMENT_CENTER, max_w, fs, 4, Color.BLACK)
	draw_string(_font, p, t, HORIZONTAL_ALIGNMENT_CENTER, max_w, fs, col)
