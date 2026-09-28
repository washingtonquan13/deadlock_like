"""Post-processing of per-frame readouts: monotonic time, duplicate frames, outlier rejection,
derived velocity and the output CSV.

Nothing here encodes game behavior. The only thresholds are data-cleaning ones (Hampel window,
k, absolute tolerances) and they are CLI options, reported in the summary JSON.
"""
from __future__ import annotations

import csv
import math

import numpy as np

NAN = float("nan")


def monotonic_times(frames: list[int], fps: float, msec: list[float] | None) -> tuple[np.ndarray, int]:
    """Frame time in seconds. With msec (container timestamps) the series is forced strictly
    increasing: a non-increasing stamp is replaced by previous + 1/fps. Returns (t, fixes)."""
    n = len(frames)
    if msec is None:
        return np.array([f / fps for f in frames], dtype=np.float64), 0
    t = np.array(msec, dtype=np.float64) / 1000.0
    fixes = 0
    for i in range(1, n):
        if not (t[i] > t[i - 1]) or not math.isfinite(t[i]):
            t[i] = t[i - 1] + (frames[i] - frames[i - 1]) / fps
            fixes += 1
    return t, fixes


def mark_duplicates(values: dict[str, np.ndarray], keys: list[str]) -> np.ndarray:
    """A frame whose readout equals the previous parsed frame on every key is a duplicate: the
    game did not render a new frame (capture fps > game fps) or the encoder repeated a frame."""
    n = len(next(iter(values.values())))
    dup = np.zeros(n, dtype=bool)
    last = None
    for i in range(n):
        cur = tuple(values[k][i] for k in keys if k in values)
        if any(math.isnan(c) for c in cur) or not cur:
            continue
        if last is not None and cur == last:
            dup[i] = True
        last = cur
    return dup


def hampel(x: np.ndarray, usable: np.ndarray, window: int, k: float, abs_tol: float) -> np.ndarray:
    """Outlier mask. For each usable sample: median / MAD over the `window` nearest usable
    neighbours on each side; outlier if |x - median| > k * 1.4826 * MAD + abs_tol.
    A step change (dash start) is not an outlier because the median follows the step; spikes
    shorter than `window` samples are."""
    idx = np.flatnonzero(usable & np.isfinite(x))
    out = np.zeros(len(x), dtype=bool)
    if len(idx) < 3:
        return out
    vals = x[idx]
    m = len(idx)
    for j in range(m):
        a, b = max(0, j - window), min(m, j + window + 1)
        w = vals[a:b]
        med = np.median(w)
        mad = np.median(np.abs(w - med))
        if abs(vals[j] - med) > k * 1.4826 * mad + abs_tol:
            out[idx[j]] = True
    return out


def derivative(t: np.ndarray, x: np.ndarray, usable: np.ndarray) -> np.ndarray:
    """Non-uniform central difference over usable samples; one-sided at the ends."""
    d = np.full(len(x), NAN)
    idx = np.flatnonzero(usable & np.isfinite(x))
    if len(idx) < 2:
        return d
    tt, xx = t[idx], x[idx]
    for j in range(len(idx)):
        if j == 0:
            a, b = 0, 1
        elif j == len(idx) - 1:
            a, b = j - 1, j
        else:
            a, b = j - 1, j + 1
        dt = tt[b] - tt[a]
        if dt > 0:
            d[idx[j]] = (xx[b] - xx[a]) / dt
    return d


def axes(up_axis: str) -> tuple[str, str, str]:
    """(horizontal a, horizontal b, vertical) component suffixes."""
    up = up_axis.lower()
    if up == "z":
        return "x", "y", "z"
    if up == "y":
        return "x", "z", "y"
    raise ValueError("up_axis must be 'z' or 'y'")


def process(frames: list[int], t: np.ndarray, raw: dict[str, list[float]], layout: dict, opts: dict) -> tuple[list[dict], dict]:
    """Builds output rows. opts: hampel_window, hampel_k, tol_pos, tol_vel, tol_ang."""
    n = len(frames)
    vals = {k: np.array(v, dtype=np.float64) for k, v in raw.items()}
    for k in ["pos_x", "pos_y", "pos_z", "vel_x", "vel_y", "vel_z", "vel_scalar", "vel_scalar2", "ang_pitch", "ang_yaw", "ang_roll"]:
        vals.setdefault(k, np.full(n, NAN))
    parsed = np.isfinite(vals["pos_x"]) & np.isfinite(vals["pos_y"]) & np.isfinite(vals["pos_z"])
    dup_keys = [k for k in vals if np.isfinite(vals[k]).any()]
    dup = mark_duplicates(vals, dup_keys)
    usable = parsed & ~dup
    flags = [[] for _ in range(n)]
    for i in range(n):
        if not parsed[i]:
            flags[i].append("unparsed")
        if dup[i]:
            flags[i].append("dup")
    outliers = 0
    W, K = int(opts["hampel_window"]), float(opts["hampel_k"])
    tol = {"pos": float(opts["tol_pos"]), "vel": float(opts["tol_vel"]), "ang": float(opts["tol_ang"])}
    for key in list(vals.keys()):
        grp = key.split("_")[0]
        if grp not in tol:
            continue
        x = vals[key]
        if not np.isfinite(x[usable]).any():
            continue
        if grp == "ang" and key == "ang_yaw":
            # unwrap yaw so 359 -> 0 is not a spike
            fin = np.isfinite(x)
            x2 = x.copy()
            x2[fin] = np.rad2deg(np.unwrap(np.deg2rad(x[fin])))
            x = x2
        mask = hampel(x, usable, W, K, tol[grp])
        for i in np.flatnonzero(mask):
            flags[i].append("outlier:" + key)
            outliers += 1
        vals[key] = np.where(mask, NAN, vals[key])
    # a frame with a rejected position is unusable for position-based quantities
    pos_ok = usable & np.isfinite(vals["pos_x"]) & np.isfinite(vals["pos_y"]) & np.isfinite(vals["pos_z"])
    der = {c: derivative(t, vals["pos_" + c], pos_ok) for c in ("x", "y", "z")}
    ha, hb, vv = axes(layout.get("up_axis", "z"))
    has_vec = np.isfinite(vals["vel_x"]) & np.isfinite(vals["vel_y"]) & np.isfinite(vals["vel_z"]) & usable
    rows = []
    for i in range(n):
        if has_vec[i]:
            vx, vy, vz, src = vals["vel_x"][i], vals["vel_y"][i], vals["vel_z"][i], "readout"
        elif pos_ok[i]:
            vx, vy, vz, src = der["x"][i], der["y"][i], der["z"][i], "derived"
        else:
            vx = vy = vz = NAN
            src = ""
        v = {"x": vx, "y": vy, "z": vz}
        valid = bool(pos_ok[i] and math.isfinite(vx))
        rows.append({
            "frame": frames[i],
            "t": t[i],
            "pos_x": vals["pos_x"][i], "pos_y": vals["pos_y"][i], "pos_z": vals["pos_z"][i],
            "vel_x": vx, "vel_y": vy, "vel_z": vz,
            "speed_h": math.hypot(v[ha], v[hb]) if math.isfinite(v[ha]) and math.isfinite(v[hb]) else NAN,
            "speed_v": v[vv],
            "vel_scalar": vals["vel_scalar"][i],
            "vel_scalar2": vals["vel_scalar2"][i],
            "vel_x_derived": der["x"][i], "vel_y_derived": der["y"][i], "vel_z_derived": der["z"][i],
            "ang_pitch": vals["ang_pitch"][i], "ang_yaw": vals["ang_yaw"][i], "ang_roll": vals["ang_roll"][i],
            "vel_source": src,
            "dup": int(dup[i]),
            "valid": int(valid),
            "flags": ";".join(flags[i]),
        })
    # consistency: readout velocity vs position derivative (only meaningful with a vector readout)
    both = has_vec & np.isfinite(der["x"])
    cons = None
    if both.sum() > 3:
        dv = np.sqrt((vals["vel_x"][both] - der["x"][both]) ** 2 + (vals["vel_y"][both] - der["y"][both]) ** 2 + (vals["vel_z"][both] - der["z"][both]) ** 2)
        cons = {"median_abs_diff_ups": float(np.median(dv)), "p90_abs_diff_ups": float(np.percentile(dv, 90))}
    summary = {
        "frames": n,
        "parsed": int(parsed.sum()),
        "duplicates": int(dup.sum()),
        "outlier_values_rejected": outliers,
        "valid_rows": int(sum(r["valid"] for r in rows)),
        "velocity_source": "readout-vector" if has_vec.any() else ("derived-from-position" if pos_ok.any() else "none"),
        "vel_readout_vs_derived": cons,
    }
    return rows, summary


COLUMNS = ["frame", "t", "pos_x", "pos_y", "pos_z", "vel_x", "vel_y", "vel_z", "speed_h", "speed_v",
           "vel_scalar", "vel_scalar2", "vel_x_derived", "vel_y_derived", "vel_z_derived",
           "ang_pitch", "ang_yaw", "ang_roll", "vel_source", "dup", "valid", "flags"]


def write_csv(path: str, rows: list[dict]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(COLUMNS)
        for r in rows:
            out = []
            for c in COLUMNS:
                v = r[c]
                if isinstance(v, float):
                    out.append("" if not math.isfinite(v) else ("%.6f" % v if c == "t" else "%.4f" % v))
                else:
                    out.append(v)
            w.writerow(out)
