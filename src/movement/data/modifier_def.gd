class_name ModifierDef
extends Resource
## A data-driven movement modifier (docs/design/movement_architecture.md section 7.5).

enum Stat {
	MOVE_BONUS,             # m/s, DR-stacked (spec: movement.md §4)
	SPRINT_BONUS,           # m/s, additive (spec: movement.md §3)
	SLOW,                   # fraction, multiplicative (spec: movement.md §5)
	SLOW_RESIST,            # fraction, additive (spec: movement.md §5)
	DASH_DISTANCE_PCT,      # fraction, multiplicative on dash distance (spec: movement.md §5, §8)
	STAMINA_MAX,            # bars (spec: movement.md §7)
	STAMINA_RECOVERY,       # fraction, additive (spec: movement.md §7)
	AIR_JUMPS,              # count (spec: movement.md §10)
	AIR_DASHES,             # count (spec: movement.md §11)
	AIR_ACTION_DIST_PCT,    # fraction (Stamina Mastery, spec: movement.md §7)
	SLIDE_BONUS,            # fraction, onset lookup (spec: movement.md §13)
	GRAVITY_PCT,            # fraction (spec: movement.md §10)
	FIRING_PENALTY_IMMUNE,  # 0/1 (spec: movement.md §2)
	VENT,                   # 0/1 (spec: movement.md §4)
	DAMAGE_SLOW,            # fraction applied above base (spec: movement.md §5)
	ROPE_SLOW,              # fraction (spec: movement.md §17)
	MOVE_MULT,              # raw multiplier (parry / melee self-slow, spec: movement.md §19)
}

enum StackMode { REFRESH, INDEPENDENT, MAX }

@export var id: StringName = &""
@export var stat: Stat = Stat.MOVE_BONUS
@export var value: float = 0.0
@export var taper_to: float = NAN               # NAN = no taper
@export var duration: float = 0.0               # seconds, 0 = permanent
@export var stack_mode: StackMode = StackMode.REFRESH
@export var max_stacks: int = 1


static func make(p_id: StringName, p_stat: int, p_value: float, p_duration: float = 0.0, p_taper_to: float = NAN, p_mode: int = StackMode.REFRESH) -> ModifierDef:
	var d := ModifierDef.new()
	d.id = p_id
	d.stat = p_stat
	d.value = p_value
	d.duration = p_duration
	d.taper_to = p_taper_to
	d.stack_mode = p_mode
	return d
