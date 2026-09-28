class_name CompiledMoveParams
extends RefCounted
## Params + hero compiled into tick values and effective-speed helpers (design §7.6).

var params: MovementParams        # read-only reference
var hero: HeroMovementStats
var params_hash: int = 0
# precomputed tick values
var dash_jump_open_tick: int = 20      # spec: movement.md §9; PROVISIONAL (G06): 0.30 s official vs V17 0.35 s
var dash_jump_close_tick: int = 35     # inclusive (G06: 0.55 s)
var dash_jump_coyote_ticks: int = -1   # PROVISIONAL (G18): <0 = whole window
var ground_dash_ticks_exact: float = 39.68
var air_dash_ticks_exact: float = 27.52
var ground_dash_speed: float = 0.0
var air_dash_speed: float = 0.0
var down_dash_window_ticks: int = 28
var sprint_delay_ticks: int = 192
# extra precomputed values (CORE additions)
var action_buffer_ticks: int = 7
var jump_buffer_ticks: int = 0
var coyote_ticks: int = 0
var dash_jump_bonus_ticks: int = 16
var wall_fatigue_recovery_ticks: int = 80
var zip_lockout_ticks: int = 192
var zip_knockoff_window_ticks: int = 192
var zip_knockoff_stun_ticks: int = 160
var zip_exit_momentum_ticks: int = 128
var zip_boost_ticks: int = 2048
var zip_boost_cooldown_ticks: int = 23040
var zip_boost_unlock_ticks: int = 23040
var heavy_windup_ticks: int = 23
var heavy_lunge_ticks: int = 22
var heavy_lunge_ramp_ticks: int = 13
var heavy_lunge_ramp_ticks_air: int = 10
var heavy_recovery_ticks: int = 13
var parry_ticks: int = 64
var combat_penalty_ticks: int = 320
var in_combat_ticks: int = 192
var damage_slow_ticks: int = 64
var slide_jump_store_crouch_ticks: int = 14
var slide_hop_min_ticks: int = 32       # PROVISIONAL (G09)
var slide_hop_penalty_ticks: int = -1   # PROVISIONAL (G09): <0 = until landing
var slide_hop_clear_ticks: int = 16     # PROVISIONAL (G09)
var wall_jump_min_interval_ticks: int = 10  # G33 (measured session 11)
var floor_min_normal_y: float = 0.7
var slide_slope_min_normal_y: float = 0.996


static func build(p_params: MovementParams, p_hero: HeroMovementStats) -> CompiledMoveParams:
	var c := CompiledMoveParams.new()
	c.params = p_params if p_params != null else MovementParams.new()
	c.hero = p_hero if p_hero != null else HeroMovementStats.new()
	var p := c.params
	var h := c.hero
	var b := clampi(h.dash_bucket, 1, 3) - 1
	# spec: movement.md §9 dash-jump window, evaluated after the dash tick (design §2 #14)
	c.dash_jump_open_tick = MoveUnits.ticks(p.dash_jump_window_open)
	c.dash_jump_close_tick = MoveUnits.ticks(p.dash_jump_window_open + p.dash_jump_window_length) - 1
	c.dash_jump_coyote_ticks = -1 if p.dash_jump_coyote_time < 0.0 else MoveUnits.ticks(p.dash_jump_coyote_time)
	# spec: movement.md §8 ground dash, §11 air dash
	var gd: float = p.ground_dash_durations[mini(b, p.ground_dash_durations.size() - 1)]
	var ad: float = p.air_dash_durations[mini(b, p.air_dash_durations.size() - 1)]
	c.ground_dash_ticks_exact = gd * MoveUnits.TICK_RATE
	c.air_dash_ticks_exact = ad * MoveUnits.TICK_RATE
	c.ground_dash_speed = p.ground_dash_distance / gd
	c.air_dash_speed = p.air_dash_distance / ad
	c.down_dash_window_ticks = MoveUnits.ticks(p.down_dash_double_tap_window)
	c.sprint_delay_ticks = MoveUnits.ticks(p.sprint_delay)
	c.action_buffer_ticks = MoveUnits.ticks(p.action_buffer_time)
	c.jump_buffer_ticks = MoveUnits.ticks(p.jump_buffer_time)
	c.coyote_ticks = MoveUnits.ticks(p.coyote_time)
	c.dash_jump_bonus_ticks = MoveUnits.ticks(p.dash_jump_air_control_time)
	c.wall_fatigue_recovery_ticks = maxi(1, MoveUnits.ticks(p.wall_jump_fatigue_recovery))
	c.zip_lockout_ticks = MoveUnits.ticks(p.zip_attach_lockout)
	c.zip_knockoff_window_ticks = MoveUnits.ticks(p.zip_knockoff_window)
	c.zip_knockoff_stun_ticks = MoveUnits.ticks(p.zip_knockoff_stun)
	c.zip_exit_momentum_ticks = MoveUnits.ticks(p.zip_exit_momentum_time)
	c.zip_boost_ticks = MoveUnits.ticks(p.zip_boost_duration)
	c.zip_boost_cooldown_ticks = MoveUnits.ticks(p.zip_boost_cooldown)      # spec: movement.md §16
	c.zip_boost_unlock_ticks = MoveUnits.ticks(p.zip_boost_unlock_time)     # spec: movement.md §16
	c.heavy_windup_ticks = MoveUnits.ticks(p.heavy_windup_time)
	c.heavy_lunge_ticks = maxi(1, MoveUnits.ticks(p.heavy_lunge_time))
	c.heavy_lunge_ramp_ticks = maxi(1, MoveUnits.ticks(p.heavy_lunge_ramp_time))
	c.heavy_lunge_ramp_ticks_air = maxi(1, MoveUnits.ticks(p.heavy_lunge_ramp_time_air))
	c.heavy_recovery_ticks = MoveUnits.ticks(p.heavy_recovery_time)
	c.parry_ticks = MoveUnits.ticks(p.parry_duration)
	c.combat_penalty_ticks = MoveUnits.ticks(p.wall_jump_combat_regen_penalty_time)
	c.in_combat_ticks = MoveUnits.ticks(p.in_combat_time)                  # spec: movement.md §14
	c.damage_slow_ticks = MoveUnits.ticks(p.damage_slow_duration)
	c.slide_jump_store_crouch_ticks = MoveUnits.ticks(p.slide_jump_store_crouch_time)
	c.slide_hop_min_ticks = MoveUnits.ticks(p.slide_hop_min_time)                     # PROVISIONAL (G09)
	c.slide_hop_penalty_ticks = -1 if p.slide_hop_penalty_time < 0.0 else MoveUnits.ticks(p.slide_hop_penalty_time)
	c.slide_hop_clear_ticks = maxi(1, MoveUnits.ticks(p.slide_hop_clear_time))
	c.wall_jump_min_interval_ticks = MoveUnits.ticks(p.wall_jump_min_interval)        # G33 (measured session 11)
	c.floor_min_normal_y = cos(deg_to_rad(p.max_floor_angle_deg))
	c.slide_slope_min_normal_y = cos(deg_to_rad(p.slide_slope_min_angle_deg))
	c.params_hash = hash([_res_signature(p), _res_signature(h)])
	return c


static func _res_signature(r: Resource) -> String:
	var parts: Array = []
	for prop in r.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		parts.append([prop["name"], r.get(prop["name"])])
	return var_to_str(parts)


# --- lookups ------------------------------------------------------------------

## spec: movement.md §13 slide penalty onset by Slide Bonus (largest table entry <= bonus).
## from_ground: a NORMAL slide started by a crouch press on the ground (measured session 7, s7_open SE*).
func slide_onset_ticks(slide_kind: int, slide_bonus: float, from_ground: bool = false) -> int:
	var table: Array[float] = params.slide_onset_table
	if slide_kind == MoveState.SlideKind.NORMAL and from_ground:
		table = params.slide_onset_table_ground
	elif slide_kind == MoveState.SlideKind.DASH_JUMP:
		table = params.slide_onset_table_dash_jump
	elif slide_kind == MoveState.SlideKind.DASH:
		table = params.slide_onset_table_dash
	var idx := 0
	for i in params.slide_bonus_table.size():
		if params.slide_bonus_table[i] <= slide_bonus + 1e-6:
			idx = i
	idx = mini(idx, table.size() - 1)
	return MoveUnits.ticks(table[idx])


## spec: movement.md §15 mantle bands; design §2 #23 (h rounded to whole u). -1 = no mantle.
func mantle_band_for_height(h_m: float) -> int:
	var h_u := roundi(h_m / MoveUnits.HU)
	if h_u < params.mantle_min_height_u:
		return -1
	var tops := params.mantle_band_tops_u
	if tops.is_empty() or h_u > tops[tops.size() - 1]:
		return -1
	for i in tops.size():
		if h_u < tops[i]:
			return i
	return tops.size() - 1



# --- effective values -----------------------------------------------------------

## spec: movement.md §5 slow fraction after resist: total = 1 - prod(1 - Si), actual = total*(1 - resist).
func actual_slow(state: MoveState) -> float:
	var total := 1.0 - ModifierStack.product_complement(state, ModifierDef.Stat.SLOW)
	var resist := clampf(ModifierStack.sum(state, ModifierDef.Stat.SLOW_RESIST), 0.0, 1.0)
	return clampf(total * (1.0 - resist), 0.0, 1.0)


func _apply_slow(speed: float, state: MoveState) -> float:
	# spec: movement.md §5 slows cannot push speed below the 2.0 m/s floor
	var floor_s := params.slow_floor_speed
	if speed > floor_s:
		speed = (speed - floor_s) * (1.0 - actual_slow(state)) + floor_s
	return speed


## spec: movement.md §3 total sprint bonus (hero base + items).
func sprint_total(state: MoveState) -> float:
	return hero.base_sprint_speed + ModifierStack.sum(state, ModifierDef.Stat.SPRINT_BONUS)


## design §7.6 steps 1-8.
func effective_move_speed(state: MoveState, firing: bool) -> float:
	var base := hero.base_move_speed
	# 1. spec: movement.md §4 diminishing returns on move-speed bonuses
	var k := params.move_bonus_dr_k
	var prod := 1.0
	for m in state.modifiers:
		if m.stat == ModifierDef.Stat.MOVE_BONUS:
			prod *= 1.0 - m.current_value() / k
	var bonus := k * (1.0 - prod)
	# 2. spec: movement.md §4 vent multiplies base part only
	var base_part := base + bonus
	if ModifierStack.sum(state, ModifierDef.Stat.VENT) > 0.0:
		base_part *= params.vent_speed_mult
	# 3-4. spec: movement.md §3 sprint
	var speed := base_part
	if state.sprint_active:
		speed += state.sprint_bonus_current
	# 5. spec: movement.md §5 damage slow applies to the part above base
	var d := ModifierStack.sum(state, ModifierDef.Stat.DAMAGE_SLOW)
	if d > 0.0 and speed > base:
		speed = base + (speed - base) * (1.0 - clampf(d, 0.0, 1.0))
	# 6. spec: movement.md §2 firing penalty
	if firing and ModifierStack.sum(state, ModifierDef.Stat.FIRING_PENALTY_IMMUNE) <= 0.0:
		speed *= params.firing_speed_mult
	# 7. spec: movement.md §5 slows with floor
	speed = _apply_slow(speed, state)
	# 8. raw multipliers (parry, melee self-slow; spec: movement.md §19)
	speed *= ModifierStack.product(state, ModifierDef.Stat.MOVE_MULT)
	return maxf(speed, 0.0)


## spec: movement.md §6 crouch speed; slows and MOVE_MULT apply, firing does not.
func effective_crouch_speed(state: MoveState) -> float:
	var speed := _apply_slow(hero.crouch_speed, state)
	speed *= ModifierStack.product(state, ModifierDef.Stat.MOVE_MULT)
	return maxf(speed, 0.0)


## spec: movement.md §12 air drag rises by 35% of the actual slow.
func effective_air_drag(state: MoveState) -> float:
	return params.air_drag * (1.0 + params.slow_air_drag_factor * actual_slow(state))


## spec: movement.md §7
func stamina_max(state: MoveState) -> float:
	return maxf(0.0, hero.stamina_max + ModifierStack.sum(state, ModifierDef.Stat.STAMINA_MAX))


## spec: movement.md §7 per-bar regen time = cooldown / (1 + sum recovery), in fractional ticks.
func stamina_bar_ticks(state: MoveState) -> float:
	var rec := ModifierStack.sum(state, ModifierDef.Stat.STAMINA_RECOVERY)
	return hero.stamina_cooldown * MoveUnits.TICK_RATE / maxf(0.01, 1.0 + rec)


## spec: movement.md §10 gravity with hero scale and GRAVITY_PCT modifiers.
func gravity(state: MoveState) -> float:
	return params.gravity * hero.gravity_scale * maxf(0.0, 1.0 + ModifierStack.sum(state, ModifierDef.Stat.GRAVITY_PCT))


func air_jumps_max(state: MoveState) -> int:
	return params.air_jumps_per_airtime + roundi(ModifierStack.sum(state, ModifierDef.Stat.AIR_JUMPS))


func air_dashes_max(state: MoveState) -> int:
	return params.air_dashes_per_airtime + roundi(ModifierStack.sum(state, ModifierDef.Stat.AIR_DASHES))


## spec: movement.md §7 Stamina Mastery style air-action distance bonus.
func air_action_scale(state: MoveState) -> float:
	return 1.0 + ModifierStack.sum(state, ModifierDef.Stat.AIR_ACTION_DIST_PCT)


## spec: movement.md §8 dash distance modifiers; design §2 #21 (scale speed by default).
func ground_dash_speed_for(state: MoveState) -> float:
	var s := ModifierStack.product_one_plus(state, ModifierDef.Stat.DASH_DISTANCE_PCT)
	return ground_dash_speed * (s if params.dash_distance_scale_mode == 1 else 1.0)


func ground_dash_ticks_for(state: MoveState) -> float:
	var s := ModifierStack.product_one_plus(state, ModifierDef.Stat.DASH_DISTANCE_PCT)
	return ground_dash_ticks_exact * (s if params.dash_distance_scale_mode == 0 else 1.0)


func air_dash_speed_for(state: MoveState) -> float:
	var s := ModifierStack.product_one_plus(state, ModifierDef.Stat.DASH_DISTANCE_PCT) * air_action_scale(state)
	return air_dash_speed * (s if params.dash_distance_scale_mode == 1 else air_action_scale(state))


## G01 directional cap C (PROVISIONAL (G01), V8 2:16): the bucket's air dash speed incl. SM and dash
## modifiers, unless air_dash_cap_override > 0 (then override scaled by the same modifiers).
func air_dash_cap_for(state: MoveState) -> float:
	if params.air_dash_cap_override > 0.0:
		return params.air_dash_cap_override * air_dash_speed_for(state) / maxf(air_dash_speed, 1e-9)
	return air_dash_speed_for(state)


func air_dash_ticks_for(state: MoveState) -> float:
	var s := ModifierStack.product_one_plus(state, ModifierDef.Stat.DASH_DISTANCE_PCT)
	return air_dash_ticks_exact * (s if params.dash_distance_scale_mode == 0 else 1.0)


func slide_bonus(state: MoveState) -> float:
	return ModifierStack.sum(state, ModifierDef.Stat.SLIDE_BONUS)
