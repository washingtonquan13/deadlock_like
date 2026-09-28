"""Session 7 ramp slides (Haze, timescale 1, 3 trials each). Run from this folder; writes the scenario jsons.
Marks: ramp1_top (pawn 263.7,-356.7,96, yaw 97.8 = downhill, ~world +y) and ramp1_bot (pawn 255.4,176,-32, yaw 272.5
= uphill). The spawn-area "steps" collide as a smooth ramp (user). No teleport scans: the slope profile comes from RWALK.
Record from tools/movement_capture:
  TAIL=1.5 DIR=s7_ramp bash scenarios/rec.sh ramp1_top 3 RRUN RDASH RBOT RWALK RJ   (RSW here was renamed RSWtop)
  TAIL=1.5 DIR=s7_ramp bash scenarios/rec.sh ramp1_slope 3 RS0 RSW   (ramp1_top is flat: RS0 there does nothing)
  TAIL=1.5 DIR=s7_ramp bash scenarios/rec.sh ramp1_bot 3 RUP
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
s = base("RS0", "ramp1_top: crouch 1..256 from standstill on the slope entry, no keys", 256)
add(s, 1, 256, buttons=["crouch"]); S["RS0"] = s
s = base("RSW", "ramp1_top: crouch 1..256 and W 1..256 from standstill", 256)
add(s, 1, 256, move=[0, 1], buttons=["crouch"]); S["RSW"] = s
s = base("RRUN", "ramp1_top: W 1..32 (run down), crouch 33..288, no keys during the slide", 288)
add(s, 1, 32, move=[0, 1]); add(s, 33, 288, buttons=["crouch"]); S["RRUN"] = s
s = base("RDASH", "ramp1_top: W 1..23, dash 4 (ground dash downhill), crouch 24..280 (dash slide on the slope)", 280)
add(s, 1, 23, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 24, 280, buttons=["crouch"]); S["RDASH"] = s
s = base("RBOT", "ramp1_top: W 1..64 (run 1 s down the ramp), crouch 65..384 (slide starts low on the slope, runs out on the flat)", 384)
add(s, 1, 64, move=[0, 1]); add(s, 65, 384, buttons=["crouch"]); S["RBOT"] = s
s = base("RWALK", "ramp1_top: W 1..192 (plain run down the ramp and onto the flat, no crouch)", 192)
add(s, 1, 192, move=[0, 1]); S["RWALK"] = s
s = base("RJ", "ramp1_top: W 1..32, crouch 33..224, slide jump at 56 (mid-ramp downhill slide jump), crouch held through the landing", 224)
add(s, 1, 32, move=[0, 1]); add(s, 33, 224, buttons=["crouch"]); add(s, 56, 56, buttons=["jump"]); S["RJ"] = s
s = base("RUP", "ramp1_bot (facing uphill): W 1..23, dash 4, crouch 24..352 (dash slide up the ramp; held until it stops / slides back)", 352)
add(s, 1, 23, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 24, 352, buttons=["crouch"]); S["RUP"] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
