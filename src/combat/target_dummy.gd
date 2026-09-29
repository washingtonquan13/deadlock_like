class_name TargetDummy
extends Node3D
## Shootable dummy with a body capsule and a head capsule (docs/design/gun_system_plan.md).
## Feet at the node origin. Resets to full HP a short while after it stops taking damage.

signal damaged(info: Dictionary)
signal died

@export var max_health: float = 800.0
@export var crit_damage_received_scale: float = 1.0
@export var body_radius: float = 0.38
@export var body_bottom: float = 0.35
@export var body_top: float = 1.2         # hemisphere tops out at 1.58, under the head
@export var head_radius: float = 0.2
@export var head_center: float = 1.72
@export var reset_delay: float = 3.0
@export var show_visual: bool = true

var health: float = 800.0
var total_damage: float = 0.0
var _since_hit: float = 0.0
var _label: Label3D
## Timed debuffs shown on the label: name -> seconds left (slow, stun, burn; dummies don't act).
var statuses: Dictionary = {}
## Damage amp per attacker (abilities: "takes +x% damage from the caster"): source id -> [pct, left].
var amps: Dictionary = {}


func _ready() -> void:
	add_to_group(ProjectileSystem.TARGET_GROUP)
	health = max_health
	if show_visual:
		_build_visual()


func get_hit_capsules() -> Array:
	var o := global_position
	return [
		[o + Vector3(0, body_bottom, 0), o + Vector3(0, body_top, 0), body_radius, false],
		[o + Vector3(0, head_center - head_radius * 0.3, 0), o + Vector3(0, head_center + head_radius * 0.3, 0), head_radius, true],
	]


func take_bullet_hit(info: Dictionary) -> void:
	var amp: Array = amps.get(info.get("source_id", 0), [])
	if not amp.is_empty():
		info["amount"] = float(info.get("amount", 0.0)) * (1.0 + float(amp[0]) / 100.0)
	var amount := float(info.get("amount", 0.0))
	health -= amount
	total_damage += amount
	_since_hit = 0.0
	damaged.emit(info)
	if health <= 0.0:
		died.emit()
		health = max_health
	_refresh_label()


func set_status(status: StringName, seconds: float) -> void:
	statuses[status] = maxf(seconds, float(statuses.get(status, 0.0)))
	_refresh_label()


func apply_amp(source_id: int, pct: float, seconds: float) -> void:
	amps[source_id] = [pct, seconds]
	set_status(&"amp", seconds)


## Chest height, where abilities aim and numbers spawn.
func get_center() -> Vector3:
	return global_position + Vector3(0, (body_top + body_bottom) * 0.5, 0)


func _process(delta: float) -> void:
	_since_hit += delta
	if not statuses.is_empty() or not amps.is_empty():
		for k in statuses.keys():
			statuses[k] -= delta
			if statuses[k] <= 0.0:
				statuses.erase(k)
		for k in amps.keys():
			amps[k][1] -= delta
			if amps[k][1] <= 0.0:
				amps.erase(k)
		_refresh_label()
	if _since_hit > reset_delay and health < max_health:
		health = max_health
		_refresh_label()


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.35, 0.3)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = body_radius
	cm.height = body_top - body_bottom + body_radius * 2.0
	body.mesh = cm
	body.material_override = mat
	body.position = Vector3(0, (body_top + body_bottom) * 0.5, 0)
	add_child(body)
	var head := MeshInstance3D.new()
	var hm := CapsuleMesh.new()
	hm.radius = head_radius
	hm.height = head_radius * 2.6
	head.mesh = hm
	var hmat := mat.duplicate() as StandardMaterial3D
	hmat.albedo_color = Color(0.9, 0.75, 0.3)
	head.material_override = hmat
	head.position = Vector3(0, head_center, 0)
	add_child(head)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, head_center + 0.45, 0)
	_label.font_size = 40
	_label.pixel_size = 0.004
	add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	if _label != null:
		var tags := PackedStringArray()
		for k in statuses:
			tags.append(String(k).to_upper())
		_label.text = "%d / %d" % [ceili(maxf(health, 0.0)), int(max_health)] 				+ ("" if tags.is_empty() else "
" + " ".join(tags))
		_label.visible = health < max_health or not tags.is_empty()   # full-HP labels just clutter the lane
