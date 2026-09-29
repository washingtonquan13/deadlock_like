class_name Progression
extends RefCounted
## Boon levels from total souls earned (specs/abilities.md M1–M3). Level = boon count.

## Total souls for levels 0..35 (2026-06-30 curve).
const THRESHOLDS := [
	600, 800, 1100, 1500, 2000, 2600, 3200, 3800, 4500, 5200,
	5900, 6600, 7400, 8200, 9000, 9800, 10700, 11600, 12500, 13400,
	14400, 15500, 16700, 18000, 19500, 21200, 23100, 25200, 27500, 30000,
	32700, 35600, 38700, 42000, 45500, 49200,
]
## Levels that grant an ability unlock instead of an AP; the last one is the ultimate.
const UNLOCK_LEVELS := [0, 2, 4, 7]
const ULTIMATE_LEVEL := 7
const MAX_LEVEL := 35
## AP per upgrade tier (T1, T2, T3).
const TIER_AP := [1, 2, 5]
const REFUND_WINDOW := 10.0


## Highest level whose threshold is at or below `souls`; -1 below the starting souls.
static func level_for(souls: int) -> int:
	var lv := -1
	for i in THRESHOLDS.size():
		if souls >= THRESHOLDS[i]:
			lv = i
	return lv


## AP earned by `level`: every level from 1 up that is not an unlock level.
static func ap_total(level: int) -> int:
	var n := 0
	for l in range(1, mini(level, MAX_LEVEL) + 1):
		if not UNLOCK_LEVELS.has(l):
			n += 1
	return n


## Regular (non-ultimate) unlocks earned by `level`.
static func regular_unlocks(level: int) -> int:
	var n := 0
	for l in UNLOCK_LEVELS:
		if l != ULTIMATE_LEVEL and level >= l:
			n += 1
	return n


static func ultimate_unlocked(level: int) -> bool:
	return level >= ULTIMATE_LEVEL
