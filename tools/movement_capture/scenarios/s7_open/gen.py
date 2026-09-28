"""Session 7 open items (Haze, timescale 1, 3 trials each). Run from this folder; writes the scenario jsons.
Record from tools/movement_capture: bash scenarios/s7_open/rec.sh MARK 3 NAME...  (trooper_kill_all first)
Marks: street_y148 (flat street runway, used by s6_slidejump / s6_diag), wallA (head-on wall), truckA (mantle).
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
# G: slide entry speed on flat ground. W from rest, crouch pressed at tick N and held 96 ticks, W released at N-1.
SE = {"SEPROBE": None, "SE300": 26, "SE320": 29, "SE330": 31, "SE340": 34, "SE360": 40, "SE333": 32, "SE336": 33}
import os
SE.update(json.loads(os.environ.get("SE_EXTRA", "{}")))
for k, n in SE.items():
    if n is None:
        s = base(k, "street_y148: W 1..96 from rest (HUD ramp for picking the SE crouch ticks)", 128); add(s, 1, 96, move=[0, 1])
    else:
        s = base(k, "street_y148: W 1..%d from rest, crouch %d..%d (no keys during it): slide or crouch-walk?" % (n - 1, n, n + 95), n + 128)
        add(s, 1, n - 1, move=[0, 1]); add(s, n, n + 95, buttons=["crouch"])
    S[k] = s
# A: landing-loss threshold. Dash jump 31 (as DJS/LSD12), S in the air from 40 for H ticks, crouch 61..250.
for k, h in {"LT460": 8, "LT450": 9, "LT440": 10, "LT465": 7.5}.items():
    if h == 7.5:  # 7 ticks of S and one of S+A (about 0.7 of an S tick backwards)
        s = base(k, "street_y148: dash jump 31, S 40..46 and S+A 47 in the air, crouch 61..250 (landing slide)", 260)
        add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 31, 31, buttons=["jump"])
        add(s, 40, 46, move=[0, -1]); add(s, 47, 47, move=[-1, -1]); add(s, 61, 250, buttons=["crouch"]); S[k] = s; continue
    s = base(k, "street_y148: dash jump 31, S 40..%d in the air (%d ticks), crouch 61..250 (landing slide)" % (39 + h, h), 260)
    add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 31, 31, buttons=["jump"])
    add(s, 40, 39 + h, move=[0, -1]); add(s, 61, 250, buttons=["crouch"]); S[k] = s
# B: G09 chained slide-hop penalty. As SHH6: dash slide, slide jump 27 (lands into a slide ~74), second jump at 74+d.
for k, (j2, fast) in {"SHH12": (86, False), "SHH20": (94, False), "SHH30": (104, False), "SHH6F": (103, True)}.items():
    if fast:  # W in the air adds nothing above run speed, so the fast entry is a dash-jump landing slide (~480, as DJS)
        s = base(k, "street_y148: W 1..31, dash 4, dash jump 31, crouch 61..169 (landing slide ~97), slide hop %d (~6 ticks after landing), crouch off 170, S brake" % j2, 224)
        add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 31, 31, buttons=["jump"]); add(s, 61, 169, buttons=["crouch"])
    else:
        s = base(k, "street_y148: dash 4, crouch 24..169, slide jump 27, second slide jump %d, crouch off 170, S brake" % j2, 224)
        add(s, 1, 23, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 24, 169, buttons=["crouch"]); add(s, 27, 27, buttons=["jump"])
    add(s, j2, j2, buttons=["jump"]); add(s, 170, 210, move=[0, -1]); S[k] = s
# C: no-key air jump.
s = base("NK1", "street_y148: jump 1 from standstill, air jump 20 with no keys", 128)
add(s, 1, 1, buttons=["jump"]); add(s, 20, 20, buttons=["jump"]); S["NK1"] = s
s = base("NK2", "street_y148: W 1..63 (run), jump 40, W released at 64, air jump 66 with no keys", 160)
add(s, 1, 63, move=[0, 1]); add(s, 40, 40, buttons=["jump"]); add(s, 66, 66, buttons=["jump"]); S["NK2"] = s
# D: wall jump tangential kick (copies of scenarios/wall WJD/WJA at wallA).
for k, mv in {"WJD": [1, 0], "WJA": [-1, 0]}.items():
    s = base(k, "wallA: W 1..83 into the wall, jump 60, %s 84..150, wall jump 88" % ("D" if mv[0] > 0 else "A"), 260)
    add(s, 1, 83, move=[0, 1]); add(s, 60, 60, buttons=["jump"]); add(s, 84, 150, move=mv); add(s, 88, 88, buttons=["jump"]); S[k] = s
# F: strafe run speed from rest, 160 ticks.
for k, mv in {"FSD": [1, 0], "FSA": [-1, 0], "FSWA": [-1, 1], "FSW": [0, 1]}.items():
    s = base(k, "street_y148: move %s 1..160 from rest (strafe run speed)" % mv, 224); add(s, 1, 160, move=mv); S[k] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
