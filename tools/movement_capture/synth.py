"""Synthetic cl_showpos-style recordings with known values, for testing extract.py.

The overlay text format here is our guess at a Source-style readout (the Deadlock format is
unverified); the point is to test OCR, parsing and cleaning against known ground truth.

  python synth.py --out _synth/clip.mp4 [--seconds 4] [--fps 60] [--vel vector|scalar]
                  [--render-fps 60] [--glitch 0.03] [--stutter 0.02] [--seed 1]

Writes the mp4 and <name>_truth.csv (frame, t, pos, vel, corrupted).
"""
from __future__ import annotations

import argparse
import csv
import math
import os

import cv2
import numpy as np

G = 967.0  # u/s^2, only used to make the synthetic trajectory look like a jump arc


def trajectory(seconds: float, dt: float = 1.0 / 960.0) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Piecewise motion with steps, ramps and gravity arcs. Returns (t, pos[n,3], vel[n,3]) in u, z up."""
    n = int(seconds / dt) + 1
    t = np.arange(n) * dt
    pos = np.zeros((n, 3))
    vel = np.zeros((n, 3))
    p = np.array([-1234.56, 2345.67, 128.0])
    v = np.zeros(3)
    yaw = math.radians(37.0)
    fwd = np.array([math.cos(yaw), math.sin(yaw), 0.0])
    side = np.array([-math.sin(yaw), math.cos(yaw), 0.0])
    ground_z = 128.0
    airborne = False
    jumped = dashed = dragged = landed = False
    for i in range(n):
        tt = t[i]
        if tt < 0.25:
            v = np.zeros(3)
        elif tt < 0.9:  # accelerate to run speed
            v = fwd * min(283.0, (tt - 0.25) * 1100.0)
        elif tt < 1.3:  # ground dash: instant set
            v = fwd * 635.0
        elif not jumped:  # dash-jump
            v = fwd * 611.0 + np.array([0.0, 0.0, 425.0])
            jumped = airborne = True
        elif airborne:
            if tt >= 1.55 and not dashed:  # air dash: sideways impulse, vz zeroed
                v = v + side * 500.0
                dashed = True
            if dashed and tt < 1.98:
                v[2] = 0.0
            else:
                if dashed and not dragged:
                    v[:2] *= 0.8
                    dragged = True
                v[2] -= G * dt
                v[:2] *= (1.0 - 0.5 * dt)
        elif landed:
            v[:2] *= (1.0 - 4.0 * dt)  # ground friction after landing
        p = p + v * dt
        if airborne and p[2] < ground_z and v[2] < 0:
            p[2] = ground_z
            v[2] = 0.0
            airborne = False
            landed = True
        pos[i] = p
        vel[i] = v
    return t, pos, vel


def sample(t_src, arr, t):
    return np.stack([np.interp(t, t_src, arr[:, k]) for k in range(arr.shape[1])], axis=1)


def overlay_lines(p, v, ang, vel_mode: str) -> list[str]:
    lines = ["name: Player", "pos: %.2f %.2f %.2f" % tuple(p), "ang: %.2f %.2f %.2f" % tuple(ang)]
    if vel_mode == "vector":
        lines.append("vel: %.2f %.2f %.2f" % tuple(v))
    else:
        lines.append("vel: %.2f" % float(np.linalg.norm(v)))
    return lines


TEXT_ORIGIN = (24, 40)
LINE_DY = 24
FONT = cv2.FONT_HERSHEY_SIMPLEX
FONT_SCALE = 0.6


def draw_text(img, lines):
    x, y = TEXT_ORIGIN
    for k, ln in enumerate(lines):
        org = (x, y + k * LINE_DY)
        # drop shadow (same thickness: OpenCV's glyph advance grows with thickness)
        cv2.putText(img, ln, (org[0] + 1, org[1] + 1), FONT, FONT_SCALE, (0, 0, 0), 1, cv2.LINE_AA)
        cv2.putText(img, ln, (org[0] + 2, org[1] + 2), FONT, FONT_SCALE, (0, 0, 0), 1, cv2.LINE_AA)
        cv2.putText(img, ln, org, FONT, FONT_SCALE, (235, 235, 235), 1, cv2.LINE_AA)


def background(w, h, k, rng_base):
    """Textured, moving, fairly dark background (the readout is bright text with a shadow)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    g = 40 + 50 * (0.5 + 0.5 * np.sin((xx + 3 * k) / 97.0) * np.cos((yy - 2 * k) / 71.0))
    img = np.stack([g * 0.9, g, g * 1.1], axis=-1)
    img += rng_base[(k * 7) % rng_base.shape[0]][:h, :w]
    # a moving bright object far from the readout
    cx = int(w * 0.6 + 200 * math.sin(k / 20.0))
    cv2.circle(img, (cx, int(h * 0.6)), 60, (200, 210, 220), -1)
    return np.clip(img, 0, 255).astype(np.uint8)


def make_video(out: str, seconds: float = 4.0, fps: float = 60.0, vel_mode: str = "vector", render_fps: float | None = None,
               glitch: float = 0.03, stutter: float = 0.0, seed: int = 1, size=(1280, 720)) -> str:
    rng = np.random.default_rng(seed)
    w, h = size
    render_fps = render_fps or fps
    t_src, pos_src, vel_src = trajectory(seconds + 0.2)
    n = int(seconds * fps)
    noise = [rng.normal(0, 10, (h, w, 3)).astype(np.float32) for _ in range(5)]
    noise = np.stack(noise)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    vw = cv2.VideoWriter(out, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    if not vw.isOpened():
        raise RuntimeError("VideoWriter could not open %s" % out)
    truth_rows = []
    game_t = 0.0
    last_render_t = -1.0
    for k in range(n):
        tv = k / fps
        # the game renders at render_fps; a stutter repeats the previous game frame
        rt = math.floor(tv * render_fps + 1e-9) / render_fps
        if stutter > 0 and rng.random() < stutter and last_render_t >= 0:
            rt = last_render_t
        game_t = rt
        last_render_t = rt
        p = sample(t_src, pos_src, np.array([game_t]))[0]
        v = sample(t_src, vel_src, np.array([game_t]))[0]
        yaw_deg = (37.0 + 40.0 * game_t) % 360.0
        ang = np.array([-5.25 + 3 * math.sin(game_t), yaw_deg, 0.0])
        # the overlay prints rounded values; truth is what is printed
        pr, vr, ar = np.round(p, 2), np.round(v, 2), np.round(ang, 2)
        img = background(w, h, k, noise)
        draw_text(img, overlay_lines(pr, vr, ar, vel_mode))
        corrupted = 0
        if glitch > 0 and rng.random() < glitch:
            # a flash over part of the numbers (muzzle flash / particle)
            x0 = int(rng.integers(70, 260))
            y0 = TEXT_ORIGIN[1] + LINE_DY * int(rng.integers(0, 4)) - 16
            cv2.rectangle(img, (x0, y0), (x0 + int(rng.integers(20, 60)), y0 + 20), (255, 255, 255), -1)
            corrupted = 1
        vw.write(img)
        truth_rows.append([k, tv, game_t, *pr, *vr, float(np.round(np.linalg.norm(v), 2)), *ar, corrupted])
    vw.release()
    truth = os.path.splitext(out)[0] + "_truth.csv"
    with open(truth, "w", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(["frame", "t", "game_t", "pos_x", "pos_y", "pos_z", "vel_x", "vel_y", "vel_z", "vel_scalar",
                     "ang_pitch", "ang_yaw", "ang_roll", "corrupted"])
        wr.writerows(truth_rows)
    return truth


def read_truth(path: str) -> dict:
    with open(path, newline="") as f:
        r = list(csv.DictReader(f))
    return {k: np.array([float(row[k]) for row in r]) for k in r[0].keys()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--seconds", type=float, default=4.0)
    ap.add_argument("--fps", type=float, default=60.0)
    ap.add_argument("--render-fps", type=float, default=None)
    ap.add_argument("--vel", choices=["vector", "scalar"], default="vector")
    ap.add_argument("--glitch", type=float, default=0.03)
    ap.add_argument("--stutter", type=float, default=0.0)
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args()
    print(make_video(a.out, a.seconds, a.fps, a.vel, a.render_fps, a.glitch, a.stutter, a.seed))


if __name__ == "__main__":
    main()
