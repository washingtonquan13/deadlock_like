class_name ModifierStack
## Static helpers over MoveState.modifiers (design §7.5).


## A duration of D seconds is active for ticks(D) simulate() calls, counting the one that adds it
## (modifiers are added in step 1 and ticked down in step 2 of the same call).
static func add(state: MoveState, def: ModifierDef, source: StringName) -> void:
	if def == null:
		return
	var n := MoveUnits.ticks(def.duration) if def.duration > 0.0 else -1
	var ticks_left := n + 1 if n > 0 else -1
	match def.stack_mode:
		ModifierDef.StackMode.REFRESH, ModifierDef.StackMode.MAX:
			for m in state.modifiers:
				if m.id == def.id:
					if def.stack_mode == ModifierDef.StackMode.MAX:
						m.value = maxf(m.value, def.value)
					else:
						m.value = def.value
					m.taper_to = def.taper_to
					m.ticks_left = ticks_left
					m.ticks_total = maxi(n, 0)
					m.source = source
					return
		ModifierDef.StackMode.INDEPENDENT:
			var count := 0
			var oldest: ActiveModifier = null
			for m in state.modifiers:
				if m.id == def.id:
					count += 1
					if oldest == null:
						oldest = m
			if count >= maxi(def.max_stacks, 1) and oldest != null:
				state.modifiers.erase(oldest)
	var am := ActiveModifier.new()
	am.id = def.id
	am.stat = def.stat
	am.value = def.value
	am.taper_to = def.taper_to
	am.ticks_left = ticks_left
	am.ticks_total = maxi(n, 0)
	am.source = source
	state.modifiers.append(am)


## Convenience: add a modifier from raw values (used by sim-internal effects).
static func add_raw(state: MoveState, id: StringName, stat: int, value: float, duration: float, source: StringName, taper_to: float = NAN) -> void:
	add(state, ModifierDef.make(id, stat, value, duration, taper_to), source)


static func remove(state: MoveState, id: StringName) -> void:
	var keep: Array[ActiveModifier] = []
	for m in state.modifiers:
		if m.id != id:
			keep.append(m)
	state.modifiers = keep


static func tick_down(state: MoveState) -> void:
	var keep: Array[ActiveModifier] = []
	for m in state.modifiers:
		if m.ticks_left < 0:
			keep.append(m)
			continue
		m.ticks_left -= 1
		if m.ticks_left > 0:
			keep.append(m)
	state.modifiers = keep


static func has_stat(state: MoveState, stat: int) -> bool:
	for m in state.modifiers:
		if m.stat == stat:
			return true
	return false


static func sum(state: MoveState, stat: int) -> float:
	var s := 0.0
	for m in state.modifiers:
		if m.stat == stat:
			s += m.current_value()
	return s


## prod(1 - v)
static func product_complement(state: MoveState, stat: int) -> float:
	var p := 1.0
	for m in state.modifiers:
		if m.stat == stat:
			p *= 1.0 - m.current_value()
	return p


## prod(v); 1.0 when none. Used for MOVE_MULT.
static func product(state: MoveState, stat: int) -> float:
	var p := 1.0
	for m in state.modifiers:
		if m.stat == stat:
			p *= m.current_value()
	return p


## prod(1 + v); 1.0 when none. Used for DASH_DISTANCE_PCT (spec: movement.md §5, §8).
static func product_one_plus(state: MoveState, stat: int) -> float:
	var p := 1.0
	for m in state.modifiers:
		if m.stat == stat:
			p *= 1.0 + m.current_value()
	return p


static func stack_hash(state: MoveState) -> int:
	var a: Array = []
	for m in state.modifiers:
		a.append([String(m.id), m.stat, roundi(m.current_value() * 1e6)])
	return hash(a)
