@tool
class_name Zipline
extends Path3D
## Scene-side zipline (design §7.12). PlayerCharacter bakes it into a ZiplineRail for the sim.

const BAKE_SPACING := 0.25

## CUSTOM uses lane_speed; INNER/OUTER resolve from MovementParams.zip_speed_inner/outer in the sim.
enum Lane { CUSTOM, INNER, OUTER }

@export var lane: Lane = Lane.CUSTOM   # spec: movement.md §16 inner 18 m/s, outer 21 m/s (data-driven)
@export var lane_speed: float = 18.0   # used only for Lane.CUSTOM
@export var express: bool = false      # spec: movement.md §16 express line, multiplier = MovementParams.zip_express_mult


func _ready() -> void:
	add_to_group(&"zipline")


func to_rail(id: int) -> ZiplineRail:
	var pts := PackedVector3Array()
	if curve != null and curve.point_count >= 2:
		var total := curve.get_baked_length()
		var n := maxi(1, ceili(total / BAKE_SPACING))
		var xf := global_transform
		for i in n + 1:
			var off := total * float(i) / float(n)
			pts.append(xf * curve.sample_baked(off, false))
	# lane/express speed is resolved by the sim from MovementParams (RailState.rail_speed)
	return ZiplineRail.new(id, pts, lane_speed, int(lane), express)
