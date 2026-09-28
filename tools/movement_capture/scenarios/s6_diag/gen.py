"""Session 6 diagonal-air scenarios (DG timing: jump 40, keys from 56, air jump 66). Marks are in MARKS
(recording CLI argument, not a JSON field). move = [x, y]: x = D+/A-, y = W+/S-."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
W, S, A, D = [0, 1], [0, -1], [-1, 0], [1, 0]
WD, WA, SD, SA = [1, 1], [-1, 1], [1, -1], [-1, -1]
PARAMS = [{"name": "air_accel", "min": 0, "max": 100, "note": "placeholder: the sim replay needs one (value unchanged)"}]

# name: (comment, mark, walk key 1..55 or None, air key, key window (from, to), air-jump tick or None)
SCEN = {
    "DRWA":  ("rest, W+A from 56, air jump 66 (mirror of DGRWD: rotation vs per-key weighting)", "street_y148", None, WA, (56, 170), 66),
    "DRSA":  ("rest, S+A from 56, air jump 66 (mirror of DGRSD)", "street_y013", None, SA, (56, 170), 66),
    "DRWDY": ("rest, W+D from 56, air jump 66 (DGRWD repeated at another yaw: world-frame test)", "street", None, WD, (56, 170), 66),
    "DRD":   ("rest, D only from 56, air jump 66 (single-key add direction, right)", "street_y148", None, D, (56, 170), 66),
    "DRA":   ("rest, A only from 56, air jump 66 (single-key add direction, left; A/D symmetry)", "street_y058", None, A, (56, 170), 66),
    "DRWDR": ("rest, W+D 56-64 then released, air jump 66 (previous-tick wish zero: expect no add)", "street_y148", None, WD, (56, 64), 66),
    "DWA":   ("walk W 1-55, jump 40, W+A from 56, air jump 66 (mirror of DGWD)", "street_y148", W, WA, (56, 170), 66),
    "DBSA":  ("backpedal S 30-55 (short: lane), jump 40, S+A from 56, air jump 66 (DGBSA in a longer lane)", "street_y013", S, SA, (56, 170), 66),
}
MARKS = {k: v[1] for k, v in SCEN.items()}


def build(name, c):
    comment, _mark, walk, key, (k0, k1), aj = c
    tl = []
    if walk:
        tl.append({"from": 30 if name == "DBSA" else 1, "to": 55, "move": walk})
    tl.append({"from": 40, "to": 40, "buttons": ["jump"]})
    tl.append({"from": k0, "to": k1, "move": key})
    if aj:
        tl.append({"from": aj, "to": aj, "buttons": ["jump"]})
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0, "sprint_on": True},
            "ticks": 200, "default": {"move": [0, 0], "buttons": []}, "timeline": tl,
            "suppress_sprint": False, "hero": "res://data/movement/heroes/hero_haze.tres", "params": PARAMS}


if __name__ == "__main__":
    for n, c in SCEN.items():
        json.dump(build(n, c), open(os.path.join(HERE, n + ".json"), "w"), indent=1)
        print(n, MARKS[n])
