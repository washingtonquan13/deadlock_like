class_name WeaponData
extends Resource
## One hero's primary gun (spec: combat.md §2 weapon model). Meters, seconds, m/s.
## Tuned values live in res://data/weapons/weapons.json (loaded by WeaponDB).

@export var key: StringName = &""
@export var display_name: String = ""
@export_group("Damage")
@export var bullet_damage: float = 5.0
@export var bullet_damage_per_boon: float = 0.0
@export var pellets: int = 1
@export var falloff_start: float = 20.0
@export var falloff_end: float = 57.5
@export var falloff_end_scale: float = 0.1
## combat.md §4 Apollo: no damage past falloff_end.
@export var hard_range_cutoff: bool = false
@export var can_crit: bool = true
@export var pierce: bool = false
## combat.md §3 attacker-side headshot weakening (Drifter -0.45).
@export var crit_bonus_scale: float = 0.0
@export_group("Cycle")
@export var cycle_time: float = 0.2
@export var burst_count: int = 1
@export var burst_interval: float = 0.0
@export var spins_up: bool = false
@export var spin_cycle_time: float = 0.0
@export var spin_up_rate: float = 0.0
@export var spin_down_rate: float = 0.0
@export_group("Ammo")
@export var clip_size: int = 20
## Full reload time; for single-shell reloads, the time per shell.
@export var reload_time: float = 2.5
@export var reload_single: bool = false
@export var reload_single_delay: float = 0.0
@export_group("Projectile")
@export var bullet_speed: float = 500.0
@export var gravity_scale: float = 0.0
@export var bullet_radius: float = 0.0762
@export var bullet_lifetime: float = 2.0
@export var bullet_range: float = 177.8
@export_group("Handling")
@export var shoot_move_speed_pct: float = 0.75
## Approximations (docs/design/gun_system_plan.md): cone half-angles in degrees.
@export var spread_base: float = 0.25
@export var spread_bloom_per_shot: float = 0.0
@export var spread_bloom_max: float = 0.0
@export var spread_bloom_decay: float = 4.0
## Visual-only pitch kick per shot (degrees).
@export var recoil_kick: float = 0.4


func damage_at_boons(boons: int) -> float:
	return bullet_damage + bullet_damage_per_boon * boons


## combat.md §2 DPS formulas (burst DPS, no reload).
func burst_dps() -> float:
	return bullet_damage * pellets * burst_count / cycle_time


func sustained_dps() -> float:
	var mag := bullet_damage * pellets * clip_size
	var full_reload := reload_time
	if reload_single:
		full_reload = reload_single_delay + reload_time * clip_size
	var shots := float(clip_size) / burst_count
	return mag / (shots * cycle_time + full_reload)


func max_travel_time() -> float:
	return minf(bullet_lifetime, bullet_range / maxf(bullet_speed, 0.001))
