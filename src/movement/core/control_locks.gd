class_name ControlLocks
## Control lock overlay (design §7.4). Stun is a lock mask, not a state (design §2 #7).

const MOVE := 1
const JUMP := 2
const DASH := 4
const CROUCH := 8
const SPRINT := 16
const STAMINA := 32
const ZIPLINE := 64
const MANTLE := 128
const MELEE := 256
const TURN := 512
const STUN := MOVE | JUMP | DASH | CROUCH | SPRINT | ZIPLINE | MANTLE | MELEE | TURN


static func active_mask(state: MoveState) -> int:
	var m := 0
	for l in state.locks:
		if int(l.get("ticks", 0)) > 0:
			m |= int(l.get("mask", 0))
	return m


## A lock of N ticks is active for the N simulate() calls starting with the one that adds it.
static func add(state: MoveState, mask: int, ticks: int, source: StringName) -> void:
	if ticks <= 0 or mask == 0:
		return
	for l in state.locks:
		if StringName(l.get("source", &"")) == source and int(l.get("mask", 0)) == mask:
			l["ticks"] = maxi(int(l["ticks"]), ticks + 1)
			return
	# +1 because tick_down runs in step 2 of the same simulate() call.
	state.locks.append({"mask": mask, "ticks": ticks + 1, "source": source})


static func tick_down(state: MoveState) -> void:
	var keep: Array[Dictionary] = []
	for l in state.locks:
		l["ticks"] = int(l["ticks"]) - 1
		if int(l["ticks"]) > 0:
			keep.append(l)
	state.locks = keep
