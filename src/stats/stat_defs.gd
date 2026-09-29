class_name StatDefs
## The stats a StatSheet knows and how each one stacks (specs/stats.md §2), plus the derived
## values subsystems read (§4 order of computation). Percentages are whole numbers (25 = 25%),
## speeds are m/s, like the spec's source data.

enum Kind {
	FLAT,        # Σ v
	ADD_PCT,     # Σ p (read as 1 + Σp/100)
	MULT_STACK,  # 1 − Π(1 − p/100), as a percent
	PRODUCT,     # Π(1 + p/100) − 1, as a percent
	MOVE_DR,     # 12 × (1 − Π(1 − b/12)) m/s (movement.md §4)
}

const MOVE_DR_K := 12.0

# --- Weapon ---
const WEAPON_DAMAGE := &"weapon_damage"         # % of base bullet damage (items + weapon investment)
const BULLET_DAMAGE_POST := &"bullet_damage_post" # flat per bullet, after the % pool
const FIRE_RATE := &"fire_rate"                 # % bonus
const FIRE_RATE_SLOW := &"fire_rate_slow"       # % slow on us
const CLIP := &"clip"                           # flat bullets, before the %
const CLIP_PCT := &"clip_pct"                   # %
const RELOAD_TIME := &"reload_time"             # % of reload duration, negative = faster (low confidence)
const BULLET_SPEED := &"bullet_speed"           # %
const FALLOFF_RANGE := &"falloff_range"         # %
const CRIT_BONUS := &"crit_bonus"               # % on the headshot bonus
const BULLET_LIFESTEAL := &"bullet_lifesteal"   # %
const BULLET_SHRED := &"bullet_shred"           # % taken off the target's bullet resist
# --- Vitality ---
const HEALTH := &"health"                       # flat max HP, after the vitality %
const VITALITY := &"vitality"                   # % of base + boon HP (vitality investment)
const HEALTH_PCT := &"health_pct"               # % of total max HP, applied last (Glass Cannon style)
const REGEN := &"regen"                         # HP/s
const OOC_REGEN := &"ooc_regen"                 # HP/s out of combat
const BULLET_RESIST := &"bullet_resist"         # %
const SPIRIT_RESIST := &"spirit_resist"         # %
const MELEE_RESIST := &"melee_resist"           # %
const DEBUFF_RESIST := &"debuff_resist"         # % (stacking disputed; combat.md chose multiplicative)
const HEAL_AMP := &"heal_amp"                   # % healing effectiveness
const HEAL_PENALTY := &"heal_penalty"           # % less healing received
# --- Movement ---
const MOVE_SPEED := &"move_speed"               # m/s, diminishing returns
const SPRINT_SPEED := &"sprint_speed"           # m/s
const SLOW_RESIST := &"slow_resist"             # %, additive
const STAMINA := &"stamina"                     # bars
const STAMINA_RECOVERY := &"stamina_recovery"   # % on the regen rate
const AIR_MOVE := &"air_move"                   # % air dash / jump distance
# --- Spirit ---
const SPIRIT_POWER := &"spirit_power"           # flat SP (items + spirit investment)
const SPIRIT_POWER_PCT := &"spirit_power_pct"   # %, multiplicative
const COOLDOWN := &"cooldown"                   # % ability CDR
const ITEM_COOLDOWN := &"item_cooldown"         # % item CDR
const DURATION := &"duration"                   # % ability duration
const RANGE := &"range"                         # % ability range
const RADIUS := &"radius"                       # % ability radius
const CHARGES := &"charges"                     # bonus ability charges
const SPIRIT_LIFESTEAL := &"spirit_lifesteal"   # %
const SPIRIT_SHRED := &"spirit_shred"           # %
# --- Melee ---
const MELEE_DAMAGE := &"melee_damage"           # %

const KINDS := {
	WEAPON_DAMAGE: Kind.ADD_PCT,
	BULLET_DAMAGE_POST: Kind.FLAT,
	FIRE_RATE: Kind.ADD_PCT,
	FIRE_RATE_SLOW: Kind.MULT_STACK,
	CLIP: Kind.FLAT,
	CLIP_PCT: Kind.ADD_PCT,
	RELOAD_TIME: Kind.ADD_PCT,
	BULLET_SPEED: Kind.ADD_PCT,
	FALLOFF_RANGE: Kind.ADD_PCT,
	CRIT_BONUS: Kind.ADD_PCT,
	BULLET_LIFESTEAL: Kind.ADD_PCT,
	BULLET_SHRED: Kind.MULT_STACK,
	HEALTH: Kind.FLAT,
	VITALITY: Kind.ADD_PCT,
	HEALTH_PCT: Kind.ADD_PCT,
	REGEN: Kind.FLAT,
	OOC_REGEN: Kind.FLAT,
	BULLET_RESIST: Kind.MULT_STACK,
	SPIRIT_RESIST: Kind.MULT_STACK,
	MELEE_RESIST: Kind.MULT_STACK,
	DEBUFF_RESIST: Kind.MULT_STACK,
	HEAL_AMP: Kind.ADD_PCT,
	HEAL_PENALTY: Kind.MULT_STACK,
	MOVE_SPEED: Kind.MOVE_DR,
	SPRINT_SPEED: Kind.FLAT,
	SLOW_RESIST: Kind.ADD_PCT,
	STAMINA: Kind.FLAT,
	STAMINA_RECOVERY: Kind.ADD_PCT,
	AIR_MOVE: Kind.ADD_PCT,
	SPIRIT_POWER: Kind.FLAT,
	SPIRIT_POWER_PCT: Kind.PRODUCT,
	COOLDOWN: Kind.MULT_STACK,
	ITEM_COOLDOWN: Kind.MULT_STACK,
	DURATION: Kind.MULT_STACK,
	RANGE: Kind.MULT_STACK,
	RADIUS: Kind.MULT_STACK,
	CHARGES: Kind.FLAT,
	SPIRIT_LIFESTEAL: Kind.ADD_PCT,
	SPIRIT_SHRED: Kind.MULT_STACK,
	MELEE_DAMAGE: Kind.ADD_PCT,
}


static func kind(stat: StringName) -> Kind:
	if not KINDS.has(stat):
		push_warning("StatDefs: unknown stat '%s', summing it" % stat)
		return Kind.FLAT
	return KINDS[stat]


static func is_known(stat: StringName) -> bool:
	return KINDS.has(stat)


## Folds every source's value for one stat with its stacking rule.
static func fold(stat: StringName, values: Array) -> float:
	match kind(stat):
		Kind.MULT_STACK:
			var keep := 1.0
			for v in values:
				keep *= 1.0 - float(v) / 100.0
			return (1.0 - keep) * 100.0
		Kind.PRODUCT:
			var p := 1.0
			for v in values:
				p *= 1.0 + float(v) / 100.0
			return (p - 1.0) * 100.0
		Kind.MOVE_DR:
			var keep := 1.0
			for v in values:
				keep *= 1.0 - float(v) / MOVE_DR_K
			return MOVE_DR_K * (1.0 - keep)
		_:
			var s := 0.0
			for v in values:
				s += float(v)
			return s


# --- Derived values (specs/stats.md §4) ---

## Max HP = ((base + boons × per_boon) × (1 + vit%) + flat) × (1 + hp%), rounded up.
static func max_health(sheet: StatSheet, base: float, per_boon: float, boons: int) -> float:
	var hp := (base + boons * per_boon) * (1.0 + sheet.get_stat(VITALITY) / 100.0) + sheet.get_stat(HEALTH)
	hp *= maxf(0.0, 1.0 + sheet.get_stat(HEALTH_PCT) / 100.0)
	return ceilf(hp - 1e-6)


## Bullet damage = base (with boons) × (1 + weapon%) + post-scale flat.
static func bullet_damage(sheet: StatSheet, base_with_boons: float) -> float:
	return base_with_boons * maxf(0.0, 1.0 + sheet.get_stat(WEAPON_DAMAGE) / 100.0) + sheet.get_stat(BULLET_DAMAGE_POST)


## Multiplier on fire rate: bonuses add, slows stack, the total is floored at −50% (combat.md §12).
static func fire_rate_mult(sheet: StatSheet) -> float:
	var m := maxf(sheet.get_stat(FIRE_RATE) / 100.0 - sheet.get_stat(FIRE_RATE_SLOW) / 100.0, -0.5)
	return 1.0 + m if m >= 0.0 else 1.0 / (1.0 + absf(m))


## Clip = (base + flat) × (1 + Σ%), rounded up (wiki Ammo). Never below 1.
static func clip_size(sheet: StatSheet, base: int) -> int:
	var c := (base + sheet.get_stat(CLIP)) * (1.0 + sheet.get_stat(CLIP_PCT) / 100.0)
	return maxi(1, ceili(c - 1e-6))


## Multiplier on reload time (negative % = faster; stacking inferred additive, low confidence).
static func reload_mult(sheet: StatSheet) -> float:
	return maxf(0.0, 1.0 + sheet.get_stat(RELOAD_TIME) / 100.0)


static func bullet_speed_mult(sheet: StatSheet) -> float:
	return maxf(0.0, 1.0 + sheet.get_stat(BULLET_SPEED) / 100.0)


## SP = (boons × per_boon + Σflat) × Π(1 + %).
static func spirit_power(sheet: StatSheet, boon_sp: float) -> float:
	return maxf(0.0, (boon_sp + sheet.get_stat(SPIRIT_POWER)) * (1.0 + sheet.get_stat(SPIRIT_POWER_PCT) / 100.0))
