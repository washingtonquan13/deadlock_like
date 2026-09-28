"""Session 11: unmeasured features toward the confidence goal (Haze, timescale 1, 3 trials each). Run from this folder.
Record from tools/movement_capture: bash scenarios/s11_conf/rec.sh MARK 3 NAME...
H  street_y058b: heavy melee lunge (G10). The driver's "melee" key (q, the game's default Melee bind) is held
   (hold = heavy). Standing, running, and from a standing jump: the lunge speed profile, distance and the hard stop.
   HM_R: W held through a heavy (recovery length, post-heavy self-slow). HM_C: melee held again through the miss
   cooldown (when the next heavy starts).
C  street_y058b: G09 slide-hop flag clear time (SC6/14/24/36; invalid, hop 1 lands on scenery). E: the same, shorter (SE*).
W  wallAd: a second jump press 4/8/12/20 ticks after a wall jump (G33 wall-jump min interval: eaten or not).
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
s = base("HM_R", "street_y058b: W 1..200, melee held 20..60 (heavy while running, W kept down: recovery and self-slow)", 230)
add(s, 1, 200, move=[0, 1]); add(s, 20, 60, buttons=["melee"]); S["HM_R"] = s
s = base("HM_C", "street_y058b: standing, melee held 5..45, then held again 70..220 (next heavy after the miss cooldown)", 260)
add(s, 5, 45, buttons=["melee"]); add(s, 70, 220, buttons=["melee"]); S["HM_C"] = s
s = base("HM_C2", "street_y058b: standing, melee held 5..45, then a fresh hold 115..220 (cooldown start: lunge start vs end)", 260)
add(s, 5, 45, buttons=["melee"]); add(s, 115, 220, buttons=["melee"]); S["HM_C2"] = s
for k in (4, 8, 12, 20):
    s = base("WI%d" % k, "wallAd: W 1..62, jump 60, wall jump 88, second jump press %d, no keys after" % (88 + k), 200)
    add(s, 1, 62, move=[0, 1]); add(s, 60, 60, buttons=["jump"]); add(s, 88, 88, buttons=["jump"]); add(s, 88 + k, 88 + k, buttons=["jump"])
    S["WI%d" % k] = s
# C: G09 slide-hop flag clear time. As s9 SHL up to hop 1 (dash 4, dash jump 31, landing slide, slide hop 103 sets the
# flag), crouch released in the air (no landing slide), W held on the ground, crouch k ticks after hop 1 lands (~152),
# hop 6 ticks into that slide: penalized (air speed pulled toward ~215-240) while the flag holds, ~400 once cleared.
LAND = 152
for k in (6, 14, 24, 36):
    c = LAND + k; T = c + 6 + 90
    s = base("SC%d" % k, "street_y058b: dash 4, dash jump 31, crouch 61..140, slide hop 103, W 140..%d, crouch %d..%d, hop %d, S brake" % (c + 46, c, c + 46, c + 6), T)
    add(s, 1, 31, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 31, 31, buttons=["jump"]); add(s, 61, 140, buttons=["crouch"])
    add(s, 103, 103, buttons=["jump"]); add(s, 141, c + 46, move=[0, 1]); add(s, c, c + 46, buttons=["crouch"]); add(s, c + 6, c + 6, buttons=["jump"])
    add(s, c + 47, T, move=[0, -1]); S["SC%d" % k] = s
# E: shorter than C so both hops stay inside the clear first ~1300 u of the runway (C's hop 1 lands at ~1340 u, where
# the hero hits scenery; from a plain run hop 1 lands at ~330 u/s, below slide entry). W from 1, dash 4, crouch 20..27
# (dash slide), slide hop 26 (sets the flag), lands ~73 (sim) at ~560 u/s; crouch 73+k..hop+2, hop 6 ticks into that
# slide, S brake 60 ticks after hop 2. Hop 2 lands at <=1080 u (k 40).
for k in (2, 8, 12, 16, 24, 40):
    c = 73 + k; h = c + 6; T = h + 90
    s = base("SE%d" % k, "street_y058b: W 1..%d, dash 4, crouch 20..27, slide hop 26, crouch %d..%d, hop %d, S brake" % (h + 60, c, h + 2, h), T)
    add(s, 1, h + 60, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, 20, 27, buttons=["crouch"]); add(s, 26, 26, buttons=["jump"])
    add(s, c, h + 2, buttons=["crouch"]); add(s, h, h, buttons=["jump"]); add(s, h + 61, T, move=[0, -1]); S["SE%d" % k] = s
# R: plain W run from rest (the s7 FSW check): runs since ~15:47 read ~396 u/s at 0.8 s vs 382 before; is the
# hero faster now (buff, souls, item)?
s = base("RUN", "street_y058b: W 1..180 from rest, S brake", 240)
add(s, 1, 180, move=[0, 1]); add(s, 181, 240, move=[0, -1]); S["RUN"] = s
# D: dash slide entry. SE (W held, crouch at 20) slid at ~440 (HUD 635 -> 440 in ~3 ticks); s4 SHJ (W released 23,
# crouch 24) kept ~637. W held vs released x crouch 12/20/24 ticks, no jump, crouch held 40 ticks, S brake.
for c in (12, 20, 24):
    for w in ("W", "R"):
        n = "DC%d%s" % (c, w); wend = c + 40 if w == "W" else c - 1
        s = base(n, "street_y058b: W 1..%d, dash 4, crouch %d..%d, S brake %d.." % (wend, c, c + 40, c + 41), c + 100)
        add(s, 1, wend, move=[0, 1]); add(s, 4, 4, buttons=["dash"]); add(s, c, c + 40, buttons=["crouch"])
        add(s, c + 41, c + 100, move=[0, -1]); S[n] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
print(" ".join(S))
