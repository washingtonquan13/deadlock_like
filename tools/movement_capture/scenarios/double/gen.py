"""Double (air) jump probes (session 4). Mark street. Walk W, ground jump at tick 40, air jump at 40+k.
Keys from the air jump on are under test: does the air jump set or add vz, and does it redirect horizontal speed?"""
import json
J = 40
def base(name, comment, T=200):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": []}
def dbl(name, comment, k, after, walk=True, pre=(0, 1)):
    s = base(name, comment)
    if walk:
        s["timeline"].append({"from": 1, "to": J + k - 1, "move": list(pre)})
    s["timeline"].append({"from": J, "to": J, "buttons": ["jump"]})
    s["timeline"].append({"from": J + k, "to": J + k, "buttons": ["jump"]})
    if after is not None:
        s["timeline"].append({"from": J + k, "to": 170, "move": after})
    return s
S = {}
for k in (8, 16, 24, 36):
    S["DBW%d" % k] = dbl("DBW%d" % k, "walk, jump, air jump %d ticks later, W held throughout (vz rule)" % k, k, [0, 1])
S["DB0"] = dbl("DB0", "walk, jump, air jump at +24, no key from the air jump (horizontal kept?)", 24, None)
S["DBS"] = dbl("DBS", "walk, jump, air jump at +24, S from the air jump (redirect backwards?)", 24, [0, -1])
S["DBD"] = dbl("DBD", "walk, jump, air jump at +24, D from the air jump (redirect sideways?)", 24, [1, 0])
S["DBR"] = dbl("DBR", "standing jump, air jump at +24 with D from the air jump (burst from rest?)", 24, [1, 0], walk=False)
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
# WJAJ (wallfat) hinted at a boost along the wish when the air jump starts with v.wish small; the camera near the wall
# is unreliable, so test in the open: jump 40, S 42..66 brakes the forward speed to ~0, W from 67, air jump at 76.
for name, aj in (("DBX", True), ("DBX0", False)):
    s = base(name, "walk, jump 40, S 42..66 (fwd ~0), W from 67%s" % (", air jump 76" if aj else " (control)"))
    s["timeline"] = [{"from": 1, "to": 41, "move": [0, 1]}, {"from": 40, "to": 40, "buttons": ["jump"]},
                     {"from": 42, "to": 66, "move": [0, -1]}, {"from": 67, "to": 170, "move": [0, 1]}]
    if aj:
        s["timeline"].append({"from": 76, "to": 76, "buttons": ["jump"]})
    S[name] = s
    json.dump(s, open(name + ".json", "w"), indent=1)
# DBX shows a boost along the wish. Which rule: raise the wish component (other components kept) or redirect?
#  DBL/DBL0: walk W (fwd ~walk), jump 40, W released and D held from 56, air jump 66 (control without)
#  DBRW: standing jump 40, W from 56, air jump 66 (boost from rest?)
#  DBB: walk W, jump 40, S from 56 (fwd still large), air jump 66 (does v.wish << 0 get raised?)
X = {"DBL": ([1, 0], True, True), "DBL0": ([1, 0], True, False), "DBRW": ([0, 1], False, True), "DBB": ([0, -1], True, True)}
for name, (key, walk, aj) in X.items():
    s = base(name, "%s jump 40, key %s from 56%s" % ("walk," if walk else "standing", key, ", air jump 66" if aj else " (control)"))
    if walk:
        s["timeline"].append({"from": 1, "to": 55, "move": [0, 1]})
    s["timeline"] += [{"from": 40, "to": 40, "buttons": ["jump"]}, {"from": 56, "to": 170, "move": key}]
    if aj:
        s["timeline"].append({"from": 66, "to": 66, "buttons": ["jump"]})
    json.dump(s, open(name + ".json", "w"), indent=1)
# Route R1 showed a diagonal (S+D) air jump adding far more than the 1-D rule predicts. Diagonal probes, same timing:
#  DGBSD/DGBSD0: backpedal S, jump 40, S+D from 56, air jump 66 (control without)
#  DGWD: walk W, jump 40, W+D from 56, air jump 66;  DGRWD: standing jump 40, W+D from 56, air jump 66
G = {"DGBSD": ([0, -1], [1, -1], True, True), "DGBSD0": ([0, -1], [1, -1], True, False),
     "DGWD": ([0, 1], [1, 1], True, True), "DGRWD": (None, [1, 1], False, True)}
for name, (pre, key, walk, aj) in G.items():
    s = base(name, "%s jump 40, keys %s from 56%s" % ("walk %s," % pre if walk else "standing", key, ", air jump 66" if aj else " (control)"))
    if walk:
        s["timeline"].append({"from": 1, "to": 55, "move": pre})
    s["timeline"] += [{"from": 40, "to": 40, "buttons": ["jump"]}, {"from": 56, "to": 170, "move": key}]
    if aj:
        s["timeline"].append({"from": 66, "to": 66, "buttons": ["jump"]})
    json.dump(s, open(name + ".json", "w"), indent=1)
# Backward diagonals added more, skewed toward the side key. Mirror, from rest, and the ground direction of S+D:
#  DGBSA: backpedal S, jump 40, S+A from 56, air jump 66;  DGRSD: standing jump 40, S+D from 56, air jump 66
#  DGGSD: ground S+D from standstill 1..90 (no jump)
G2 = {"DGBSA": ([0, -1], [-1, -1], True), "DGRSD": (None, [1, -1], False)}
for name, (pre, key, walk) in G2.items():
    s = base(name, "%s jump 40, keys %s from 56, air jump 66" % ("walk %s," % pre if walk else "standing", key))
    if walk:
        s["timeline"].append({"from": 1, "to": 55, "move": pre})
    s["timeline"] += [{"from": 40, "to": 40, "buttons": ["jump"]}, {"from": 56, "to": 170, "move": key},
                      {"from": 66, "to": 66, "buttons": ["jump"]}]
    json.dump(s, open(name + ".json", "w"), indent=1)
s = base("DGGSD", "ground S+D from standstill 1..90, no jump (ground direction of the diagonal)", T=120)
s["timeline"] = [{"from": 1, "to": 90, "move": [1, -1]}]
json.dump(s, open("DGGSD.json", "w"), indent=1)
