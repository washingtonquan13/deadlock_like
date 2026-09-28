"""Session 9 open items (Haze, timescale 1, 3 trials each). Run from this folder; writes the scenario jsons.
Record from tools/movement_capture: bash scenarios/s9_open/rec.sh MARK 3 NAME...  (trooper_kill_all first)
Marks: street_y148 (flat street runway), wallA (head-on wall), wallA25 (same wall, view yaw 25).
"""
import json, os
PH = [{"name": "air_accel", "min": 0, "max": 100, "note": "placeholder: the sim replay needs one (value unchanged)"}]
def base(name, comment, T, yaw=0.0):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": yaw, "stamina": 3.0, "sprint_on": True}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": [],
            "suppress_sprint": False, "hero": "res://data/movement/heroes/hero_haze.tres", "params": PH}
def add(s, a, b, move=None, buttons=None):
    e = {"from": a, "to": b}
    if move is not None: e["move"] = move
    if buttons is not None: e["buttons"] = buttons
    s["timeline"].append(e)
S = {}
H = json.loads(os.environ.get("HOPS", "{}"))
# A: G09 chained slide-hop penalty at a fast second hop: dash jump 31 (no flag), landing slide ~97, slide hop 1 at 103 (sets the flag, ~560 u/s),
# hop 2 d ticks after hop 1 lands (~540 u/s). Needs ~1700 u of runway: street_y058 (street_y148 ends at ~1500).
for k, j2 in {"SHL6": H.get("SHL6", 158), "SHL12": H.get("SHL12", 164)}.items():
    s = base(k, "street_y058b: W 1..31, dash 4, dash jump 31, crouch 61..%d, slide hop 103, slide hop %d, crouch off, S brake" % (j2 + 40, j2), j2 + 90)
    add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 31, 31, buttons=["jump"]); add(s, 61, j2 + 40, buttons=["crouch"])
    add(s, 103, 103, buttons=["jump"]); add(s, j2, j2, buttons=["jump"]); add(s, j2 + 41, j2 + 80, move=[0, -1]); S[k] = s
# B: wall-jump diagonals with the key only on the jump tick (as WJD/WJA but no key before the press).
for k, mv in {"WK_WA": [-1, 1], "WK_A": [-1, 0], "WK_SA": [-1, -1], "WK_D": [1, 0], "WK_N": None}.items():
    s = base(k, "wallA: W 1..83 into the wall, jump 60, no keys 84..87, key %s on tick 88 only + wall jump 88" % mv, 200)
    add(s, 1, 83, move=[0, 1]); add(s, 60, 60, buttons=["jump"])
    if mv: add(s, 88, 88, move=mv)
    add(s, 88, 88, buttons=["jump"]); S[k] = s
# C: backpedal run speed from rest.
s = base("FSS", "street_y148 turned: S 1..160 from rest (backpedal run speed)", 224); add(s, 1, 160, move=[0, -1]); S["FSS"] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
