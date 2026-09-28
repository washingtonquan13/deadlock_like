"""Session 11: unmeasured features toward the confidence goal (Haze, timescale 1, 3 trials each). Run from this folder.
Record from tools/movement_capture: bash scenarios/s11_conf/rec.sh MARK 3 NAME...
H  street_y058b: heavy melee lunge (G10). The driver's "melee" key (q, the game's default Melee bind) is held
   (hold = heavy). Standing, running, and from a standing jump: the lunge speed profile, distance and the hard stop.
"""
import json
PH = [{"name": "air_accel", "min": 0, "max": 100, "note": "placeholder: the sim replay needs one (value unchanged)"}]
def base(name, comment, T):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0, "sprint_on": True}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": [],
            "suppress_sprint": False, "hero": "res://data/movement/heroes/hero_haze.tres", "params": PH}
def add(s, a, b, move=None, buttons=None):
    e = {"from": a, "to": b}
    if move is not None: e["move"] = move
    if buttons is not None: e["buttons"] = buttons
    s["timeline"].append(e)
S = {}
s = base("HM_S", "street_y058b: standing, melee held 5..45 (heavy), no keys after", 160)
add(s, 5, 45, buttons=["melee"]); S["HM_S"] = s
s = base("HM_W", "street_y058b: W 1..90 (to ~390 u/s), melee held 50..90 (heavy while running)", 200)
add(s, 1, 90, move=[0, 1]); add(s, 50, 90, buttons=["melee"]); S["HM_W"] = s
s = base("HM_J", "street_y058b: standing jump 5, melee held 8..48 (heavy from a near-standstill jump)", 170)
add(s, 5, 5, buttons=["jump"]); add(s, 8, 48, buttons=["melee"]); S["HM_J"] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
