"""Fit wall-jump launch with known gravity (800 u/s^2) and air drag (0.2/s): per trial find wall contact and
the kick, then least-squares the launch velocity. fwd uses drag only; lat also gets a constant accel term
(air strafe from a held key). Prints u/s."""
import sys, glob, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from analyze import track
G, DRAG = 800.0, 0.2
W = float(os.environ.get("W", "0.5"))
TPRESS = float(os.environ.get("TPRESS", str(87 / 64)))   # jump press sent at tick 88
rows = {}
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        t, fwd, lat, z, sp, yaw = track(p)
        name = os.path.basename(d)
        after = t > TPRESS
        # kick = first frame after the press where the hero moves away from the wall
        k = np.argmax(after & (np.r_[0, np.diff(fwd)] < -1.0))
        if not after[k]:
            print(name, "no kick"); continue
        tj = TPRESS + 1 / 64
        m = (t >= t[k]) & (t <= tj + W) & (z > 0.3 / .0254 * 0 + z[k] - 1)
        tau = t[m] - tj
        e = (1 - np.exp(-DRAG * tau)) / DRAG
        vf = np.linalg.lstsq(np.c_[np.ones_like(e), e], fwd[m], rcond=None)[0][1]
        cl = np.linalg.lstsq(np.c_[np.ones_like(e), e, tau ** 2 / 2], lat[m], rcond=None)[0]
        vz = np.linalg.lstsq(np.c_[np.ones_like(tau), tau], z[m] + G / 2 * tau ** 2, rcond=None)[0][1]
        # free-gravity check
        gz = -2 * np.polyfit(tau, z[m], 2)[0]
        print("%-4s %s  kick_frame_t=%.3f  v_fwd %7.1f  v_lat %6.1f (a_lat %6.1f)  v_z %6.1f  | free-fit g %.0f  | pre-contact fwd speed %.1f"
              % (name, os.path.basename(p)[:6], t[k], vf, cl[1], cl[2], vz, gz, np.nanmax(sp[(t > 1.1) & (t < 1.25)])))
