"""Session 10: the three biggest open accuracy gaps (Haze, timescale 1, 3 trials each). Run from this folder.
Record from tools/movement_capture: bash scenarios/s10_gains/rec.sh MARK 3 NAME...
A  ramp1_slope (on the 26.5 deg smooth ramp, facing downhill): W 1..k from rest, then crouch only -> slow-entry slide
   (S8-SL: game ~460 u/s^2 at 190-360 u/s vs sim ~300).
B  wallAd (head-on wall, yaw 0, pitch 45): wall-jump neutral kick vs approach (released early / late, rising / falling),
   and held keys through the press (single key and diagonals: the held-diagonal kick size).
C  street_y058b (1500 u runway): fast jumps (slide hop at ~560 u/s after a dash jump) with a key held square to the
   motion: the lateral speed growth is the air accel above 450 u/s, and its plateau is the wishspeed cap.
D  street_y058b: a 90 deg air dash after a dash jump (~850 u/s), then a square key: the >700 u/s wishspeed cap (G26).
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
# A: slow-entry slides (W 5/8/12 ticks -> ~60/110/160 u/s), crouch held to the bottom and onto the flat
for k in (5, 8, 12):
    s = base("RL%d" % k, "ramp1_slope: W 1..%d from rest, crouch %d..%d (slow-entry slide down the ramp)" % (k, k + 1, k + 200), k + 200)
    add(s, 1, k, move=[0, 1]); add(s, k + 1, k + 200, buttons=["crouch"]); S["RL%d" % k] = s
# B: wall jump. W into the wall, ground jump 60 (apex ~ tick 84), wall jump at J.
for k, (rel, J, note) in {"WN_E": (62, 88, "W released at 62 (right after the jump)"),
                          "WN_R": (70, 72, "W released at 70, press at 72 (rising fast)"),
                          "WN_F": (84, 104, "W released at 84, press at 104 (falling)")}.items():
    s = base(k, "wallAd: W 1..%d, jump 60, wall jump %d, no keys after: %s" % (rel, J, note), 200)
    add(s, 1, rel, move=[0, 1]); add(s, 60, 60, buttons=["jump"]); add(s, J, J, buttons=["jump"]); S[k] = s
for k, mv in {"WH_A": [-1, 0], "WH_WA": [-1, 1], "WH_SA": [-1, -1], "WH_S": [0, -1], "WH_W": [0, 1]}.items():
    s = base(k, "wallAd: W 1..83, jump 60, keys %s held 84..120 (from 4 ticks before the press), wall jump 88" % mv, 200)
    add(s, 1, 83, move=[0, 1]); add(s, 60, 60, buttons=["jump"]); add(s, 84, 120, move=mv); add(s, 88, 88, buttons=["jump"]); S[k] = s
# C: fast air strafe. Dash jump 31, landing slide, slide hop 103 (~560 u/s), key square to the motion from 106 to landing.
for k, mv in {"FA_A": [-1, 0], "FA_D": [1, 0], "FA_N": None}.items():
    s = base(k, "street_y058b: W 1..31, dash 4, dash jump 31, crouch 61..103, slide hop 103, %s 106..160, S brake 170..220" % (mv or "no keys"), 230)
    add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 31, 31, buttons=["jump"]); add(s, 61, 103, buttons=["crouch"])
    add(s, 103, 103, buttons=["jump"])
    if mv: add(s, 106, 160, move=mv)
    add(s, 170, 220, move=[0, -1]); S[k] = s
# C baseline below 450: a plain run jump (386 u/s) with the same square key
s = base("FA_L", "street_y058b: W 1..40, jump 40, A 43..90 (air accel below 450 u/s, same geometry)", 130)
add(s, 1, 40, move=[0, 1]); add(s, 40, 40, buttons=["jump"]); add(s, 43, 90, move=[-1, 0]); S["FA_L"] = s
# D: air strafe above 700 u/s. Dash 4, dash jump 26, A held 38..42 with an air dash at 40 (90 deg left, ~850 u/s),
# then keys square to the ~40 deg-left velocity: none, S+A or W+D from 76 (after the dash ends), or S+A through the dash.
for k, (a, mv) in {"FF_N": (None, None), "FF_SA": (76, [-1, -1]), "FF_WD": (76, [1, 1]), "FF_SAE": (44, [-1, -1])}.items():
    s = base(k, "street_y058b: W 1..37, dash 4, dash jump 26, A 38..42, air dash 40, %s to 110, S brake 120..170" % ("no keys" if mv is None else "%s %d" % (mv, a)), 180)
    add(s, 1, 37, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 26, 26, buttons=["jump"]); add(s, 38, 42, move=[-1, 0])
    add(s, 40, 40, buttons=["dash"])
    if mv: add(s, a, 110, move=mv)
    add(s, 120, 170, move=[0, -1]); S[k] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
