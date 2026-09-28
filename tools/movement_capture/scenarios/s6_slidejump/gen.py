"""Session 6 slide-jump probes (Haze, mark street_y148, timescale 1, 3 trials each). Run from this folder.
Lane: clean along y148 up to ~1290 u camera displacement (SLDJ/DJC deflect at ~1300); curb step (~16 u) at ~680 u.
Every scenario stays forward along the lane and brakes (crouch released, S) before ~1250 u.

Questions (see fitsj.py / landfit.py / cut2.py for the existing-data analysis):
  A. Non-dash slide jump: is there a takeoff cut? (existing: only SLDJ, wall-clipped).  -> NSJ48, NSJ52, SHH6, SHH40 (a DJ-landing-slide jump does not fit the lane: >1300 u)
  B. Chained slide hops (G09 slide-drag penalty; sim: +0.8/s air drag if flagged and < 0.5 s into the slide).  -> SHH6 vs SHH40
  C. Landing-into-slide loss: DJ landings at 572 lose nothing (DJC/DJC2/SLDJ), slide-jump and DJ+S landings at
     377-428 lose ~6% (one ground-friction tick, x0.9375). Speed threshold, or landing kind / crouch timing?
     -> DJS1, DJS3, DJS7, DJS7L (+ the landings of NSJ48, SHH6, SHH40)
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
def press(s, *ks):
    for k in ks: add(s, k, k, buttons=["jump"])
S = {}
# A1/A2: normal slide out of the post-dash friction decay (dash ends ~tick 45; speed falls ~30 u/s per tick to 386).
# Crouch 3 or 7 ticks after the dash end -> a NORMAL slide at ~515 / ~400 (read the entry speed off the HUD; a 641-643
# first slide tick would mean the game still counted it as a dash slide). Slide jump 10 ticks later (early: lands back
# into a slide if fast enough). Crouch released 60 ticks after the jump, then S brakes.
for c in (48, 52):
    s = base("NSJ%d" % c, "W 1..%d, dash 4, crouch %d (normal slide after the dash end), slide jump at %d; crouch off %d, S brake" % (c - 1, c, c + 10, c + 70), c + 110)
    add(s, 1, c - 1, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, c, c + 69, buttons=["crouch"])
    press(s, c + 10); add(s, c + 70, c + 100, move=[0, -1]); S[s["name"]] = s
# B: chained slide hops from a dash slide. As SHJ3 (W 1..23, dash 4, crouch 24.., jump 27): lands into a landing slide
# at ~383 (tick ~74). Second jump at landing-slide tick ~6 (80: flagged and < 0.5 s -> G09 penalty in the sim) or ~40
# (114: > 0.5 s, no penalty). Crouch held 70 ticks past the second jump (through its landing), then S brake.
for k, j2 in (("6", 80), ("40", 114)):
    e = j2 + 70   # crouch held through the second landing (~j2 + 47), then released and S brake
    s = base("SHH" + k, "dash slide, slide jump 27 (lands into a slide ~74), second slide jump at %d (landing-slide tick ~%s); crouch off %d, S brake" % (j2, k, e), e + 50)
    add(s, 1, 23, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 24, e - 1, buttons=["crouch"])
    press(s, 27, j2); add(s, e, e + 40, move=[0, -1]); S[s["name"]] = s
# C: dash-jump landing speed split. As DJC (W 1..31, dash 4, jump 31; lands ~98 at 572) with S in the air for n
# ticks from 40 (~12 u/s per tick -> ~560 / ~529 / ~476 at landing in the sim; DJS1 = any air input vs speed), crouch from 61 (held in the air, as DJC/LSD12) or from
# 97 (just before touchdown, as DJC2/SLDJ). Crouch off at 115, S brake.
for n, cf, nm in ((1, 61, "DJS1"), (3, 61, "DJS3"), (7, 61, "DJS7"), (7, 97, "DJS7L")):
    s = base(nm, "dash jump 31 (as DJC), S 40..%d, crouch %d..114 (landing slide ~98), then S brake" % (39 + n, cf), 170)
    add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); press(s, 31)
    add(s, 40, 39 + n, move=[0, -1]); add(s, cf, 114, buttons=["crouch"]); add(s, 115, 160, move=[0, -1]); S[nm] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
