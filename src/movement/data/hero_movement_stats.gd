class_name HeroMovementStats
extends Resource
## Per-hero movement stats (docs/design/movement_architecture.md section 8.2).
## Authored by hand from specs/movement.md tables. data/reference* is never loaded.

@export var hero_id: StringName = &"default"
@export var base_move_speed: float = 7.2        # spec: movement.md §2, §4
@export var base_sprint_speed: float = 1.6      # spec: movement.md §3
@export var crouch_speed: float = 4.8           # spec: movement.md §6
@export var stamina_max: float = 3.0            # spec: movement.md §7
@export var stamina_cooldown: float = 4.5       # spec: movement.md §7
@export_range(1, 3) var dash_bucket: int = 1    # spec: movement.md §8, §11
@export var gravity_scale: float = 1.0          # spec: movement.md §10
@export var spirit_move_coeff: float = 0.0      # spec: movement.md §4

## Dash bucket roster (fixes the "most others B1" spec error): wiki Stamina page per
## specs/movement_behavior/ground_dash.md Q10. Keys are lower-case hero names.
const DASH_BUCKET_ROSTER := {
	1: ["calico", "celeste", "grey talon", "haze", "holliday", "ivy", "mina", "paradox", "the doorman"],
	2: ["apollo", "billy", "drifter", "graves", "infernus", "lash", "mcginnis", "mirage", "pocket", "seven",
		"silver", "sinclair", "vindicta", "viscous", "vyper", "warden", "wraith", "yamato"],
	3: ["abrams", "bebop", "dynamo", "kelvin", "lady geist", "mo & krill", "paige", "rem", "shiv", "venator", "victor"],
}


## Dash bucket (1..3) for a hero name, or 0 when the hero is not in the roster.
static func dash_bucket_for(hero_name: String) -> int:
	var key := hero_name.strip_edges().to_lower()
	for b in DASH_BUCKET_ROSTER:
		if key in DASH_BUCKET_ROSTER[b]:
			return int(b)
	return 0
