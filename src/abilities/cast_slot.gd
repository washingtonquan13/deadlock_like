class_name CastSlot
extends RefCounted
## Cast state for one ability or active item (specs/abilities.md M5–M8). Tick-driven.
## Every ability is treated as charged: a plain one has 1 charge whose restore time is its
## cooldown. A use costs a charge, starts the restore if it isn't running and sets the
## time-between-charges lockout (not reduced by cooldown reduction, M7).
##   instant:  press -> charge spent -> CAST_DELAY -> "cast"
##   channel:  press -> CAST_DELAY -> CHANNEL -> "channel_end"; cancel -> "channel_cancel"
##             (cancel still puts it on cooldown, M6)
##   toggle:   press -> "toggle_on" (ACTIVE) -> press -> "toggle_off"
## `cd_on_end` moves the charge spend to channel end / toggle off.

signal fired(event: StringName)

enum Phase { IDLE, CAST_DELAY, CHANNEL, ACTIVE }

var data: AbilityData
var phase: Phase = Phase.IDLE
var phase_left: float = 0.0

var cooldown: float = 0.0
var max_charges: int = 1
var between: float = 0.0          # lockout after each use
var cast_delay: float = 0.0
var channel_time: float = 0.0

var charges: int = 1
var restore_left: float = 0.0
var restore_total: float = 0.0
var lockout_left: float = 0.0
var lockout_total: float = 0.0
var _spent_this_cast: bool = false


func _init(p_data: AbilityData = null) -> void:
	data = p_data


## Update the numbers (after stats, upgrades or items change).
## A raised charge cap grants the new charges at once (spec Q4 is open; this is our pick).
## A new cooldown applies from the next restore; a running one keeps its time (Q5 open).
func configure(p_cooldown: float, p_charges: int, p_between: float, p_cast_delay: float, p_channel: float) -> void:
	cooldown = maxf(0.0, p_cooldown)
	between = maxf(0.0, p_between)
	cast_delay = maxf(0.0, p_cast_delay)
	channel_time = maxf(0.0, p_channel)
	var n := maxi(1, p_charges)
	if n > max_charges:
		charges += n - max_charges
	max_charges = n
	charges = mini(charges, max_charges)
	if charges >= max_charges:
		restore_left = 0.0


func kind() -> AbilityData.Kind:
	return data.kind if data != null else AbilityData.Kind.INSTANT


func is_ready() -> bool:
	return phase == Phase.IDLE and charges > 0 and lockout_left <= 0.0


func is_busy() -> bool:
	return phase == Phase.CAST_DELAY or phase == Phase.CHANNEL


## Returns true when the press did something.
func press() -> bool:
	match kind():
		AbilityData.Kind.PASSIVE:
			return false
		AbilityData.Kind.TOGGLE:
			if phase == Phase.ACTIVE:
				phase = Phase.IDLE
				if data.cd_on_end:
					_consume()
				fired.emit(&"toggle_off")
				return true
			if not is_ready():
				return false
			if not data.cd_on_end:
				_consume()
			phase = Phase.ACTIVE
			fired.emit(&"toggle_on")
			return true
		_:
			if not is_ready():
				return false
			_spent_this_cast = false
			if not (kind() == AbilityData.Kind.CHANNEL and data.cd_on_end):
				_consume()
				_spent_this_cast = true
			phase = Phase.CAST_DELAY
			phase_left = cast_delay
			if kind() == AbilityData.Kind.CHANNEL:
				fired.emit(&"channel_start")
			if cast_delay <= 0.0:
				_finish_delay()
			return true


## Stun / jump interrupt: ends a cast delay or channel. It still goes on cooldown (M6).
func cancel() -> bool:
	if not is_busy():
		return false
	phase = Phase.IDLE
	phase_left = 0.0
	if not _spent_this_cast:
		_consume()
	fired.emit(&"channel_cancel" if kind() == AbilityData.Kind.CHANNEL else &"cast_cancel")
	return true


func step(dt: float) -> void:
	lockout_left = maxf(0.0, lockout_left - dt)
	if charges < max_charges:
		restore_left -= dt
		while restore_left <= 0.0 and charges < max_charges:
			charges += 1
			if charges < max_charges:
				restore_total = cooldown
				restore_left += cooldown
			else:
				restore_left = 0.0
	if phase == Phase.CAST_DELAY or phase == Phase.CHANNEL:
		phase_left -= dt
		if phase_left <= 0.0:
			if phase == Phase.CAST_DELAY:
				_finish_delay()
			else:
				_end_channel()


## 0..1 of the cooldown sweep (1 = just used); the restore when out of charges, else the lockout.
func sweep() -> float:
	if charges <= 0 and restore_total > 0.0:
		return clampf(restore_left / restore_total, 0.0, 1.0)
	if lockout_left > 0.0 and lockout_total > 0.0:
		return clampf(lockout_left / lockout_total, 0.0, 1.0)
	return 0.0


## Seconds until the next use is possible.
func wait_left() -> float:
	return maxf(restore_left if charges <= 0 else 0.0, lockout_left)


func _finish_delay() -> void:
	if kind() == AbilityData.Kind.CHANNEL:
		phase = Phase.CHANNEL
		phase_left = channel_time
		if channel_time <= 0.0:
			_end_channel()
	else:
		phase = Phase.IDLE
		fired.emit(&"cast")


func _end_channel() -> void:
	phase = Phase.IDLE
	phase_left = 0.0
	if not _spent_this_cast:
		_consume()
	fired.emit(&"channel_end")


func _consume() -> void:
	charges -= 1
	_spent_this_cast = true
	lockout_left = between
	lockout_total = between
	if restore_left <= 0.0:
		restore_left = cooldown
		restore_total = cooldown
