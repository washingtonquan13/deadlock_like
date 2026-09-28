"""Session 6: air dash entry-speed sweep (Haze, mark street_y148, record at host_timescale 0.25, 3 trials each).
Run from this folder: ../../.venv/Scripts/python.exe gen.py

The existing air-dash fit (rec_auto/A_air_b*, A_probe_b*) only covers entry v_par0 of about -80..+110 u/s. These
scenarios put known entry speeds into the same rising-jump air dash:
  entry along the dash  ~ +200 (W 12 ticks), +386 (sprint), ~+520 (plain jump off a ground dash, k=42),
                          ~+700 (dash jump), -386 (sprint, S dash), -700 (dash jump, S dash),
  diagonals             W+D 45 deg at sprint (273/273) and after a dash jump (~495/495).
Rules shared by all: the key that sets the dash direction is held from 2 ticks before the dash press (as the A_probe
set did) and released 2 ticks after it; no key otherwise after that, so the post-dash trace is drag only and the
landing stops the hero by ground friction (short lane). Forward keys held before the jump never change the air
speed above 80 u/s along W (air wishspeed cap), so W is simply kept down until the dash.
Lane: all runs stay within the extents of clean street_y148 recordings (fwd <= ~1100 u, right <= ~300 u, back
<= ~250 u); check the sim extents printed by simcheck.sh."""
import json

PLACEHOLDER = [{"name": "air_accel", "min": 0, "max": 100,
                "note": "placeholder: the sim replay needs one (value unchanged)"}]


def base(name, comment, ticks):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0, "sprint_on": True},
            "ticks": ticks, "default": {"move": [0, 0], "buttons": []}, "timeline": [],
            "suppress_sprint": False, "hero": "res://data/movement/heroes/hero_haze.tres",
            "record": {"mark": "street_y148", "timescale": 0.25, "trials": 3,
                       "note": "driver.py takes the timescale on the command line (--timescale 0.25); "
                               "this block is documentation only"},
            "params": PLACEHOLDER}


def ev(s, a, b, move=None, buttons=None):
    e = {"from": a, "to": b}
    if move is not None:
        e["move"] = move
    if buttons:
        e["buttons"] = buttons
    s["timeline"].append(e)


def run_jump_dash(name, comment, run_to, dash_key, dash_at, ticks=150, ground_dash=None):
    """W from tick 1 to run_to (jump on run_to), air dash at dash_at with dash_key held dash_at-2..dash_at+2.
    ground_dash: tick of a ground dash press while running (dash jump or plain jump off the dash)."""
    s = base(name, comment, ticks)
    w_end = dash_at - 3 if dash_key != [0, 1] else dash_at + 2
    ev(s, 1, w_end, move=[0, 1])
    if ground_dash:
        ev(s, ground_dash, ground_dash, buttons=["dash"])
    ev(s, run_to, run_to, buttons=["jump"])
    if dash_key != [0, 1]:
        ev(s, dash_at - 2, dash_at + 2, move=dash_key)
    ev(s, dash_at, dash_at, buttons=["dash"])
    return s


S = {
    # entry ~ +200: W 12 ticks from rest, jump, forward air dash 12 ticks later (sim: ~190 at the dash)
    "E200W": run_jump_dash("E200W", "W 1..12, jump 12, W air dash 24 (entry ~+200 along)", 12, [0, 1], 24),
    # entry ~ +386: sprint run, jump 40, forward air dash 52
    "E386W": run_jump_dash("E386W", "sprint W 1..40, jump 40, W air dash 52 (entry ~+386 along)", 40, [0, 1], 52),
    # entry -386: sprint run, jump 40, S air dash 52
    # (jump 20 ticks later than E386W so the backward drift after landing stays in front of the mark)
    "E386S": run_jump_dash("E386S", "sprint W 1..60, jump 60, S air dash 72 (entry ~-386 along, back dash)", 60, [0, -1], 72),
    # 45 deg at sprint: along ~273, perpendicular ~273
    "E386WD": run_jump_dash("E386WD", "sprint W 1..40, jump 40, W+D air dash 52 (45 deg: ~273 along, ~273 across)", 40, [1, 1], 52),
    # entry ~ +520: ground dash 4, plain jump at k=42 (tick 46, off the dash tail; game allows k>=41), forward air dash 58
    "E520W": run_jump_dash("E520W", "W, ground dash 4, plain jump 46 (k=42), W air dash 58 (entry ~+500..550 along)", 46, [0, 1], 58,
                           ground_dash=4),
    # entry ~ +700: dash jump (dash 4, jump 26 = DJ22), forward air dash 40
    "E700W": run_jump_dash("E700W", "W, dash 4, dash jump 26, W air dash 40 (entry ~+700 along)", 26, [0, 1], 40, ground_dash=4),
    # entry ~ -700: dash jump, S air dash 40
    "E700S": run_jump_dash("E700S", "W, dash 4, dash jump 26, S air dash 40 (entry ~-700 along, back dash)", 26, [0, -1], 40,
                           ground_dash=4),
    # 45 deg after a dash jump: along ~495, perpendicular ~495
    "E700WD": run_jump_dash("E700WD", "W, dash 4, dash jump 26, W+D air dash 40 (45 deg: ~495 along, ~495 across)", 26, [1, 1], 40,
                            ground_dash=4),
}

if __name__ == "__main__":
    for k, v in S.items():
        with open(k + ".json", "w") as f:
            json.dump(v, f, indent=1)
    print("wrote", ", ".join(S))
