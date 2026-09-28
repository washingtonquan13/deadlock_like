"""Shared loader: valid HUD rows -> (tick, hud, pos) arrays."""
import csv, numpy as np, os, glob
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "rec_auto")
def load(path):
    rows = [r for r in csv.DictReader(open(path)) if r["valid"] == "1" and r["vel_scalar"] != ""]
    tk = np.array([float(r["t"]) * 64 + 1 for r in rows])
    sp = np.array([float(r["vel_scalar"]) for r in rows])
    pos = np.array([[float(r["pos_x"]), float(r["pos_y"]), float(r["pos_z"])] for r in rows])
    return tk, sp, pos
def trials(setname, name):
    return sorted(glob.glob(os.path.join(ROOT, setname, name, "*.csv")))
