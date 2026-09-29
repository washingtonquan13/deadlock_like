class_name DamageNumbers
extends Node3D
## Floating damage numbers (specs/hud.md §4): a small number per hit that rises and fades at the
## impact, and one large running total beside each target that grows while hits keep landing.

@export var hit_font_size: int = 26
@export var crit_font_size: int = 30
@export var total_font_size: int = 46
@export var hit_life: float = 0.7
@export var total_linger: float = 2.0
@export var hit_color: Color = Color("#F4F4F4")
@export var hit_outline: Color = Color(0.1, 0.1, 0.1)
@export var crit_color: Color = Color("#F0D020")
@export var crit_outline: Color = Color("#FF9C00")
@export var spirit_color: Color = Color("#C58CFF")      # spirit damage reads purple
@export var spirit_outline: Color = Color("#3A1460")
@export var fade_color: Color = Color(0.55, 0.55, 0.2)   # numbers go olive as they rise
@export var total_color: Color = Color("#FFFFE0")
## Running total position: this far above the target's feet, and this many pixels to the side.
@export var total_height: float = 1.4
@export var total_offset_px: float = 110.0

var _font: SystemFont
var _totals: Dictionary = {}   # target instance id -> [Label3D, total, since_hit, target]


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Arial", "Segoe UI", "sans-serif"])
	_font.font_weight = 800


func on_hit(info: Dictionary) -> void:
	var amount := float(info["amount"])
	var crit: bool = info["is_crit"]
	var spirit: bool = info.get("kind", &"bullet") == &"spirit"
	var lbl := _label(crit_font_size if crit else hit_font_size, 8,
		spirit_color if spirit else (crit_color if crit else hit_color),
		spirit_outline if spirit else (crit_outline if crit else hit_outline))
	lbl.text = _fmt(amount)
	add_child(lbl)
	lbl.global_position = (info["point"] as Vector3) + Vector3(randf_range(-0.12, 0.12), 0.05, randf_range(-0.12, 0.12))
	var rise := 0.35 + 0.012 * float(info["distance"])   # keeps the rise visible at range
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + rise, hit_life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lbl, "modulate", fade_color, hit_life)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, hit_life * 0.5).set_delay(hit_life * 0.5)
	tw.tween_property(lbl, "modulate:a", 0.0, hit_life * 0.5).set_delay(hit_life * 0.5)
	tw.chain().tween_callback(lbl.queue_free)
	var target := info.get("target") as Node3D
	if target != null:
		_add_total(target, amount)


func _add_total(target: Node3D, amount: float) -> void:
	var id := target.get_instance_id()
	var e: Array = _totals.get(id, [])
	if e.is_empty():
		var lbl := _label(total_font_size, 14, total_color, Color.BLACK)
		lbl.offset = Vector2(total_offset_px, 0.0)
		add_child(lbl)
		e = [lbl, 0.0, 0.0, target]
		_totals[id] = e
	e[1] = float(e[1]) + amount
	e[2] = 0.0
	var l: Label3D = e[0]
	l.text = _fmt(float(e[1]))
	l.modulate.a = 1.0
	l.scale = Vector3.ONE * 1.15   # small pop per hit


func _process(delta: float) -> void:
	for id in _totals.keys():
		var e: Array = _totals[id]
		var l: Label3D = e[0]
		var t: Node3D = e[3]
		e[2] = float(e[2]) + delta
		if not is_instance_valid(t) or float(e[2]) > total_linger:
			l.queue_free()
			_totals.erase(id)
			continue
		l.global_position = t.global_position + Vector3.UP * total_height
		l.scale = l.scale.lerp(Vector3.ONE, minf(1.0, delta * 12.0))
		l.modulate.a = clampf((total_linger - float(e[2])) / 0.4, 0.0, 1.0)
		l.outline_modulate.a = l.modulate.a


func _label(font_size: int, outline: int, col: Color, outline_col: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.font = _font
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true   # same size on screen at any range
	lbl.pixel_size = 0.0012
	lbl.font_size = font_size
	lbl.outline_size = outline
	lbl.modulate = col
	lbl.outline_modulate = outline_col
	lbl.render_priority = 10
	lbl.outline_render_priority = 9
	return lbl


static func _fmt(v: float) -> String:
	return "%.1f" % v if v < 10.0 else "%d" % roundi(v)
