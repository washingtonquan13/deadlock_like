class_name MoveUnits
## Unit and tick helpers. spec: movement.md §1 (1 u = 0.0254 m, 64 Hz tick).

const HU := 0.0254
const TICK_RATE := 64
const DT := 1.0 / 64.0


static func hu(u: float) -> float:
	return u * HU


static func to_hu(m: float) -> float:
	return m / HU


## ceil(seconds * 64 - 1e-6), never negative.
static func ticks(seconds: float) -> int:
	return maxi(0, ceili(seconds * TICK_RATE - 1e-6))


static func secs(t: int) -> float:
	return float(t) / TICK_RATE
