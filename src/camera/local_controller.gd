class_name LocalController
extends Node
## Wires the local player's devices, camera and HUD to a PlayerCharacter (design §9).

@export var player_path: NodePath

var player: PlayerCharacter = null

@onready var _sampler: InputSampler = $InputSampler
@onready var _rig: CameraRig = $CameraRig
@onready var _crosshair: Crosshair = $UI/Crosshair


func _ready() -> void:
	if player_path.is_empty():
		push_warning("LocalController: player_path not set")
		return
	player = get_node_or_null(player_path) as PlayerCharacter
	if player == null:
		push_warning("LocalController: no PlayerCharacter at %s" % player_path)
		return
	# start looking where the player spawns facing
	_sampler.set_view(player.spawn_yaw, 0.0)
	player.set_input_source(_sampler)
	_rig.set_target(player)
	_rig.set_sampler(_sampler)
	_crosshair.bind_player(player)
	_rig.get_camera().make_current()
	if DisplayServer.get_name() != "headless":
		_sampler.set_mouse_captured(true)


func get_sampler() -> InputSampler:
	return _sampler


func get_aim_ray() -> Dictionary:
	return _rig.get_aim_ray()
