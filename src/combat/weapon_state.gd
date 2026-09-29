class_name WeaponState
extends RefCounted
## Serializable gun state for WeaponSim (spec: combat.md §2 firing state machine). Times are
## seconds on the sim clock (float, not ticks: cycle times like 0.105 s are not whole ticks).

enum Mode { IDLE, RELOADING, RELOADING_SINGLE }

var mode: int = Mode.IDLE
var time: float = 0.0               # sim clock at the start of the next step
var ammo: int = 0
var next_shot_time: float = 0.0     # earliest start of the next trigger cycle
var burst_left: int = 0             # shots still queued in the current burst
var next_burst_time: float = 0.0
var reload_end: float = 0.0         # full reload: when the clip refills
var reload_next: float = 0.0        # single-shell: when the next shell goes in
var spin: float = 0.0               # 0..1 spin-up (McGinnis, Victor)
var bloom: float = 0.0              # extra spread, degrees
var shots_fired: int = 0            # total shots (seeds spread)
var prev_fire: bool = false
var infinite_ammo: bool = false    # set per step (sliding)


func is_reloading() -> bool:
	return mode != Mode.IDLE


func reload_progress(w: WeaponData) -> float:
	match mode:
		Mode.RELOADING:
			return clampf(1.0 - (reload_end - time) / maxf(w.reload_time, 1e-6), 0.0, 1.0)
		Mode.RELOADING_SINGLE:
			return float(ammo) / maxf(1.0, w.clip_size)
	return 0.0
