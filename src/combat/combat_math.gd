class_name CombatMath
extends RefCounted
## Pure combat formulas (spec: combat.md §3, §4, §12).

const BASE_CRIT_BONUS := 0.65   # 1.65x headshot (combat.md §3, since 2025-11-21)


## combat.md §4 linear falloff; Apollo-style hard cut-off gives 0 past the end.
static func falloff_scale(w: WeaponData, d: float) -> float:
	if w.hard_range_cutoff and d > w.falloff_end + 1e-6:
		return 0.0
	if d <= w.falloff_start:
		return 1.0
	if d >= w.falloff_end:
		return w.falloff_end_scale
	return lerpf(1.0, w.falloff_end_scale, (d - w.falloff_start) / (w.falloff_end - w.falloff_start))


## combat.md §3 (inferred formulas): attacker bonus scale shrinks the +0.65, the defender's
## crit_damage_received_scale shrinks what is left.
static func crit_mult(attacker_bonus_scale: float, received_scale: float) -> float:
	return 1.0 + BASE_CRIT_BONUS * (1.0 + attacker_bonus_scale) * received_scale


## combat.md §12: additive bonuses minus the multiplicative slow stack, floored at -50%.
## Returns the multiplier on fire RATE (divide cycle times by it).
static func fire_rate_mult(bonuses: Array = [], slows: Array = []) -> float:
	var bonus := 0.0
	for b in bonuses:
		bonus += float(b)
	var keep := 1.0
	for s in slows:
		keep *= 1.0 - float(s)
	var m := maxf(bonus - (1.0 - keep), -0.5)
	return 1.0 + m if m >= 0.0 else 1.0 / (1.0 + absf(m))
