class_name CameraRig
extends Node3D
## Over-the-shoulder third-person camera (design §9). The rig sits on the player's interpolated
## eye position and is rotated by the sampler's unquantized view angles. The Camera3D child is
## pushed back along the shoulder offset and pulled in by a sphere cast against WORLD.

@export var shoulder_offset: Vector3 = Vector3(0.55, 0.15, 0.0)
@export var distance: float = 2.6
@export var collision_radius: float = 0.2
@export var fov_deg: float = 90.0
## How fast (fraction of full boom per second) the camera eases back out after being pulled in.
@export var pull_out_speed: float = 6.0

const WORLD_MASK := 1   # collision layer 1 WORLD (design §3)

var _target: PlayerCharacter = null
var _sampler: InputSampler = null
var _camera: Camera3D = null
var _boom_fraction: float = 1.0
var _query_shape: SphereShape3D = SphereShape3D.new()


func _ready() -> void:
	top_level = true
	process_priority = 100   # after PlayerCharacter moved its visual this frame
	_camera = get_node_or_null(^"Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	_camera.fov = fov_deg
	_camera.near = 0.05


func set_target(p: PlayerCharacter) -> void:
	_target = p


func set_sampler(s: InputSampler) -> void:
	_sampler = s


func get_camera() -> Camera3D:
	return _camera


## Ray through the screen center (the crosshair), in world space.
func get_aim_ray() -> Dictionary:
	if _camera == null:
		return {"origin": global_position, "direction": -global_basis.z}
	var t := _camera.global_transform
	return {"origin": t.origin, "direction": (-t.basis.z).normalized()}


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _camera == null:
		return
	var yaw := 0.0
	var pitch := 0.0
	if _sampler != null:
		yaw = _sampler.get_view_yaw()
		pitch = _sampler.get_view_pitch()
	elif _target.state != null:
		yaw = _target.state.yaw
		pitch = _target.state.pitch

	var pivot := _target.get_eye_position()
	var view_basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))   # YXZ: yaw then pitch
	global_transform = Transform3D(view_basis, pivot)
	_camera.fov = fov_deg

	var local_boom := shoulder_offset + Vector3(0.0, 0.0, distance)
	var hit_fraction := _cast_boom(pivot, view_basis * local_boom)
	if hit_fraction < _boom_fraction:
		_boom_fraction = hit_fraction   # pull in immediately so we never see through walls
	else:
		_boom_fraction = minf(hit_fraction, _boom_fraction + pull_out_speed * delta)
	_camera.position = local_boom * _boom_fraction
	_camera.rotation = Vector3.ZERO


## Sphere cast from the pivot along the boom; returns the safe fraction in [0, 1].
func _cast_boom(from: Vector3, motion: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return 1.0
	var space := world.direct_space_state
	if space == null:
		return 1.0
	_query_shape.radius = collision_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _query_shape
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = motion
	q.collision_mask = WORLD_MASK
	q.exclude = [_target.get_rid()]
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var res := space.cast_motion(q)
	if res.size() < 1:
		return 1.0
	return clampf(res[0], 0.0, 1.0)
