class_name MovementArena
extends Node3D
## Movement test arena (design §11). Builds the greybox layout, lighting and environment,
## and applies the world-space meter grid to every greybox mesh.

const GRID_SHADER := preload("res://src/arena/meter_grid.gdshader")

@export var layout: StringName = &"full"
@export var add_lighting: bool = true

## { "spawn": Vector3, "markers": Dictionary name -> Vector3 } from ArenaBuilder.build.
var info: Dictionary = {}


func _ready() -> void:
	info = ArenaBuilder.build(self, layout)
	if add_lighting:
		_add_environment()
	_apply_grid()


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
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)


func _apply_grid() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GRID_SHADER
	for n in get_tree().get_nodes_in_group(ArenaBuilder.GREYBOX_GROUP):
		var mi := n as MeshInstance3D
		if mi != null and is_ancestor_of(mi):
			mi.material_override = mat
