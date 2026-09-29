class_name MovementArena
extends Node3D
## Movement test arena (design §11). Builds the greybox layout, lighting and environment,
## and applies the world-space meter grid to every greybox mesh.

const GRID_SHADER := preload("res://src/arena/meter_grid.gdshader")

## Empty = the current MapRotation entry.
@export var layout: StringName = &""
@export var add_lighting: bool = true
## Sibling moved to the layout spawn before its own _ready (siblings ready after this node).
@export var player_path: NodePath = ^"../PlayerCharacter"

## { "spawn", "markers", optional "spawn_yaw", "dummies", "minimap", "fog" } from ArenaBuilder.build.
var info: Dictionary = {}


func _ready() -> void:
	if layout == &"":
		layout = MapRotation.current()
	info = ArenaBuilder.build(self, layout)
	if add_lighting:
		_add_environment()
	_apply_grid()
	var p := get_node_or_null(player_path) as PlayerCharacter
	if p != null and not p.is_node_ready():
		p.global_position = get_spawn() + Vector3.UP * 0.05
		p.spawn_yaw = info.get("spawn_yaw", p.spawn_yaw)


## F9: next map in the rotation (reloads the scene).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_next_map") and not event.is_echo():
		get_viewport().set_input_as_handled()
		MapRotation.next()
		get_tree().reload_current_scene.call_deferred()


func get_spawn() -> Vector3:
	return to_global(info.get("spawn", Vector3.ZERO))


func get_markers() -> Dictionary:
	return info.get("markers", {})


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if info.get("fog", false):
		env.fog_enabled = true
		env.fog_density = 0.0009
		env.fog_light_color = Color(0.62, 0.68, 0.76)
		env.fog_aerial_perspective = 0.5
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)


func _apply_grid() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GRID_SHADER
	for n in get_tree().get_nodes_in_group(ArenaBuilder.GREYBOX_GROUP):
		var mi := n as MeshInstance3D
		if mi != null and is_ancestor_of(mi):
			mi.material_override = mat
