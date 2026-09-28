"""Automated movement capture: plays a scenario timeline into the game and records the cl_showpos HUD.

Observation only: synthetic keyboard/mouse in, screen capture of the HUD out (see gameio.py).
Use in a private Sandbox lobby only. F10 aborts; any input stops if the game loses focus.

Commands (run from tools/movement_capture with the venv python):
  python driver/driver.py focus                       brings the game window to the front
  python driver/driver.py setup [--timescale 0.25]    sv_cheats, cl_showpos, fast stamina, host_timescale
  python driver/driver.py read                        one HUD read (checks the ROI and OCR)
  python driver/driver.py mark NAME                   saves the current pos + yaw as a start mark
  python driver/driver.py calibrate                   measures degrees per mouse count
  python driver/driver.py run SCENARIO --mark NAME [--trials 3] [--timescale 1] [--clip D1] [--tail 1.0]
  python driver/driver.py extract DIR                 OCR the recorded trials in DIR -> CSV per trial

Timing: scenario ticks are 1-based at 64 Hz; tick k is sent at real time (k-1)/64/timescale after the
trial start. Game time in the CSV is (capture stamp - trial start) * timescale, so t = 0 is the first input.
`host_timescale` must match --timescale; `run` sets it through the console.

Facing: the mark's yaw is the scenario's start.yaw_deg. A timeline yaw_deg becomes a mouse flick of
(yaw_deg - start.yaw_deg) * yaw_sign degrees, counter-clockwise positive (game yaw increases to the left).
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MC = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, MC)
import gameio as gio  # noqa: E402
import mc_post  # noqa: E402
import mc_ocr  # noqa: E402

CONFIG = os.path.join(HERE, "driver_config.json")
MARKS = os.path.join(HERE, "marks.json")
TICK = 1.0 / 64.0

DEFAULT_CONFIG = {
    "_comment": "Edit keys to match your in-game binds. roi is x, y, w, h in physical screen pixels.",
    "exe": "deadlock.exe",
    "console_key": "f7",
    "roi": [0, 217, 567, 146],
    "layout": "layouts/showpos_default.json",
    "grid_templates": "layouts/showpos_grid_1080p.npz",
    "keys": {"forward": "w", "back": "s", "left": "a", "right": "d",
             "dash": "lshift", "jump": "space", "crouch": "lctrl"},
    "deg_per_count": 0.0351875,
    "yaw_sign": 1.0,
    "min_press_ms": 25,
    "yaw_tolerance_deg": 0.1,
    "still_speed": 1.0,
}


def load_json(path, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return default


def save_json(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2)


def config() -> dict:
    c = dict(DEFAULT_CONFIG)
    c.update(load_json(CONFIG, {}))
    if not os.path.exists(CONFIG):
        save_json(CONFIG, c)
    return c


def wrap180(a: float) -> float:
    return (a + 180.0) % 360.0 - 180.0


class Hud:
    def __init__(self, cfg):
        self.cfg = cfg
        self.cap = gio.Capture(cfg["roi"])
        self.reader = gio.HudReader(os.path.join(MC, cfg["layout"]), os.path.join(MC, cfg.get("grid_templates", "")))

    def read(self, tries: int = 5, need=None) -> dict:
        if need is None:  # DL_BLIND_TURN=1 (see run_trial): the ang line may be unreadable
            need = ("pos_x", "pos_y", "pos_z") if os.environ.get("DL_BLIND_TURN") == "1" else ("pos_x", "pos_y", "pos_z", "ang_yaw")
        for _ in range(tries):
            v = self.reader.read(self.cap.grab())
            if all(k in v for k in need):
                return v
            time.sleep(0.05)
        raise RuntimeError("could not read the HUD (is cl_showpos 1 on and the ROI right?) got %r" % v)

    def speed(self, v) -> float:
        return float(v.get("vel_scalar", float("nan")))

    def wait_still(self, timeout: float = 10.0, need: int = 3) -> dict:
        """Waits until S reads ~0 and pos is unchanged for `need` reads in a row."""
        t_end = time.perf_counter() + timeout
        ok, last = 0, None
        while time.perf_counter() < t_end:
            gio.check_abort()
            v = self.read()
            p = (v["pos_x"], v["pos_y"], v["pos_z"])
            sp = self.speed(v)
            if sp != sp and os.environ.get("DL_BLIND_TURN") == "1":
                sp = 0.0  # vel line hidden too: position alone decides
            still = sp <= self.cfg["still_speed"] and last is not None and max(abs(a - b) for a, b in zip(p, last)) < 0.5
            ok = ok + 1 if still else 0
            last = p
            if ok >= need:
                return v
        raise RuntimeError("hero did not come to rest within %.0f s" % timeout)


# ----------------------------------------------------------------------------------------------
# timeline -> input events (same merge rules as tools_fit/fit_core.gd _build_cmds)
# ----------------------------------------------------------------------------------------------

def tick_states(sc: dict) -> list[dict]:
    st = sc.get("start", {})
    d = sc.get("default", {})
    yaw0 = float(st.get("yaw_deg", 0.0))
    out = []
    for t in range(1, int(sc.get("ticks", 128)) + 1):
        mv = list(d.get("move", [0, 0]))
        yaw = float(d.get("yaw_deg", yaw0))
        btn = set(n.lower() for n in d.get("buttons", []))
        for e in sc.get("timeline", []):
            if int(e.get("from", 0)) <= t <= int(e.get("to", e.get("from", 0))):
                btn |= set(n.lower() for n in e.get("buttons", []))
                if "move" in e:
                    mv = list(e["move"])
                if "yaw_deg" in e:
                    yaw = float(e["yaw_deg"])
        out.append({"tick": t, "move": mv, "buttons": btn, "yaw_rel": yaw - yaw0})
    return out


def held_keys(state: dict, keys: dict) -> set[str]:
    x, y = state["move"]
    k = set()
    if y > 0: k.add(keys["forward"])
    if y < 0: k.add(keys["back"])
    if x > 0: k.add(keys["right"])
    if x < 0: k.add(keys["left"])
    for b in state["buttons"]:
        if b not in keys:
            raise KeyError("scenario button %r has no key in driver_config.json keys" % b)
        k.add(keys[b])
    return k


def compile_events(sc: dict, cfg: dict, timescale: float) -> list[tuple]:
    """-> sorted [(t_real, kind, arg, tick)], kind in down/up/mouse. Presses shorter than min_press_ms real
    are stretched to it (the log records the real times actually sent)."""
    keys = cfg["keys"]
    states = tick_states(sc)
    ev = []
    prev_keys, prev_yaw = set(), 0.0
    down_at = {}
    for s in states:
        t = (s["tick"] - 1) * TICK / timescale
        cur = held_keys(s, keys)
        for k in sorted(cur - prev_keys):
            ev.append([t, "down", k, s["tick"]])
            down_at[k] = t
        for k in sorted(prev_keys - cur):
            ev.append([max(t, down_at[k] + cfg["min_press_ms"] / 1000.0), "up", k, s["tick"]])
        if abs(s["yaw_rel"] - prev_yaw) > 1e-9:
            dyaw = (s["yaw_rel"] - prev_yaw) * cfg["yaw_sign"]
            ev.append([t, "mouse", int(round(-dyaw / cfg["deg_per_count"])), s["tick"]])
            prev_yaw = s["yaw_rel"]
        prev_keys = cur
    t_end = len(states) * TICK / timescale
    for k in sorted(prev_keys):
        ev.append([max(t_end, down_at[k] + cfg["min_press_ms"] / 1000.0), "up", k, len(states) + 1])
    order = {"up": 0, "mouse": 1, "down": 2}
    ev.sort(key=lambda e: (e[0], order[e[1]]))
    return [tuple(e) for e in ev]


def release_all(cfg):
    for k in set(cfg["keys"].values()):
        gio.key_up(k)


# ----------------------------------------------------------------------------------------------
# commands
# ----------------------------------------------------------------------------------------------

def cmd_setup(a, cfg):
    gio.console(["sv_cheats true", "cl_showpos 1", "citadel_disable_fast_stamina", "citadel_rapid_stamina_regen false", "host_timescale %g" % a.timescale],
                cfg["console_key"], cfg["exe"])
    print("setup sent (timescale %g)" % a.timescale)


def cmd_read(a, cfg):
    gio.require_game(cfg["exe"])
    print(json.dumps(Hud(cfg).read(), indent=1))


def cmd_mark(a, cfg):
    """Saves the hero's position, not the HUD's. cl_showpos prints the third-person camera position, which sits
    ~96 u behind/right of the hero and moves with yaw and pitch (tested 2026-09-27). The hero's position is found
    by teleporting to the HUD point H: the HUD then reads H + o, so the camera offset o = HUD' - H and the
    hero stood at H - o. The hero is then teleported back there, so nothing depends on a camera model."""
    gio.require_game(cfg["exe"])
    hud = Hud(cfg)
    v = hud.wait_still()
    h = (v["pos_x"], v["pos_y"], v["pos_z"])
    gio.console(["setpos %.3f %.3f %.3f" % h], cfg["console_key"], cfg["exe"])
    v2 = hud.wait_still(timeout=15)
    o = (v2["pos_x"] - h[0], v2["pos_y"] - h[1], v2["pos_z"] - h[2])
    pawn = (h[0] - o[0], h[1] - o[1], h[2] - o[2])
    gio.console(["setpos %.3f %.3f %.3f" % pawn], cfg["console_key"], cfg["exe"])
    v3 = hud.wait_still(timeout=15)
    back = math.dist((v3["pos_x"], v3["pos_y"], v3["pos_z"]), h)
    marks = load_json(MARKS, {})
    # store where the HUD actually lands after the return teleport: that is what a later setpos reproduces
    marks[a.name] = {"pawn": list(pawn), "hud": [v3["pos_x"], v3["pos_y"], v3["pos_z"]], "yaw": v["ang_yaw"], "pitch": v["ang_pitch"],
                     "cam_offset": list(o), "return_error_u": round(back, 3)}
    save_json(MARKS, marks)
    print("mark %s = %s" % (a.name, json.dumps(marks[a.name])))
    if back > 2.0:
        print("WARNING: returning to the hero position missed the original HUD point by %.1f u" % back)


def turn_to(hud: Hud, cfg, yaw_t: float, pitch_t: float | None = None, iters: int = 8) -> dict:
    tol = cfg["yaw_tolerance_deg"]
    for _ in range(iters):
        gio.require_game(cfg["exe"])
        gio.check_abort()
        v = hud.read(need=("ang_yaw", "ang_pitch"))
        ey = wrap180(yaw_t - v["ang_yaw"])
        ep = 0.0 if pitch_t is None else pitch_t - v["ang_pitch"]
        if abs(ey) <= tol and abs(ep) <= tol:
            return v
        if abs(ey) > tol:
            gio.mouse_dx(int(round(-ey / cfg["deg_per_count"])))
        if abs(ep) > tol:
            gio.mouse_dy(int(round(ep / cfg["deg_per_count"])))
        time.sleep(0.12)
    raise RuntimeError("could not reach yaw %.3f pitch %s (last %.3f %.3f)" % (yaw_t, pitch_t, v["ang_yaw"], v["ang_pitch"]))


def cmd_calibrate(a, cfg):
    gio.require_game(cfg["exe"])
    hud = Hud(cfg)
    rates = []
    for counts in (a.counts, -a.counts):
        y0 = hud.read()["ang_yaw"]
        gio.mouse_dx(counts)
        time.sleep(0.2)
        y1 = hud.read()["ang_yaw"]
        rates.append(wrap180(y0 - y1) / counts)  # right (+counts) decreases yaw
        print("counts %+d: yaw %.4f -> %.4f  (%.7f deg/count)" % (counts, y0, y1, rates[-1]))
    dpc = float(np.mean(rates))
    cfg2 = load_json(CONFIG, dict(DEFAULT_CONFIG))
    cfg2["deg_per_count"] = dpc
    save_json(CONFIG, cfg2)
    print("deg_per_count = %.7f saved" % dpc)


def run_trial(hud: Hud, cfg, mark: dict, events: list, timescale: float, tail_game: float, pre_real: float):
    exe = cfg["exe"]
    gio.require_game(exe)
    release_all(cfg)
    try:
        hud.wait_still(timeout=15)
    except RuntimeError:
        if os.environ.get("DL_BLIND_TURN") != "1":
            raise
        time.sleep(2.0)  # the last trial ended where the HUD is unreadable (e.g. against a wall): wait it out
    if "pawn" not in mark:
        raise RuntimeError("old-format mark: re-create it with `driver.py mark NAME`")
    gio.console(["setpos %.3f %.3f %.3f" % tuple(mark["pawn"])], cfg["console_key"], exe)
    hud.wait_still(timeout=15)
    # DL_BLIND_TURN=1: when a bright background hides the ang line, keep the view already set by hand (setpos
    # keeps the camera angles) and only check the position
    blind = os.environ.get("DL_BLIND_TURN") == "1"
    try:
        turn_to(hud, cfg, mark["yaw"], mark["pitch"])
    except RuntimeError:
        if not blind:
            raise
    time.sleep(0.15)
    v = hud.read(need=("pos_x", "pos_y", "pos_z") if blind else ("pos_x", "pos_y", "pos_z", "ang_yaw"))
    yaw = v.get("ang_yaw", mark["yaw"])
    miss = math.dist((v["pos_x"], v["pos_y"], v["pos_z"]), mark["hud"])
    if miss > 2.0:
        raise RuntimeError("after setpos + turn the HUD is %.1f u from the mark's HUD point" % miss)
    time.sleep(max(0.3, 0.6 / timescale))  # stamina/landing settle after the turn
    start_state = hud.wait_still(timeout=5, need=2)

    cap = hud.cap
    cap.start()
    time.sleep(pre_real)
    log = []
    t0 = time.perf_counter()
    try:
        for t_rel, kind, arg, tick in events:
            gio.precise_sleep_until(t0 + t_rel)
            gio.require_game(exe)
            gio.check_abort()
            ts = time.perf_counter() - t0
            if kind == "down":
                gio.key_down(arg)
            elif kind == "up":
                gio.key_up(arg)
            else:
                gio.mouse_dx(arg, chunk=10 ** 6)
            log.append({"t_real": ts, "t_plan": t_rel, "kind": kind, "arg": arg, "tick": tick})
        t_last = events[-1][0] if events else 0.0
        gio.precise_sleep_until(t0 + t_last + tail_game / timescale)
    finally:
        release_all(cfg)
        cap.stop()
    return {
        "t0_perf": t0, "timescale": timescale, "inputs": log, "start_hud": start_state, "start_yaw": yaw,
        "frames": np.stack(cap.frames) if cap.frames else np.zeros((0, 1, 1), np.uint8),
        "stamps": np.array(cap.stamps) - t0,
        "late_ms_max": max((1000 * (e["t_real"] - e["t_plan"]) for e in log), default=0.0),
    }


def cmd_run(a, cfg):
    with open(a.scenario, encoding="utf-8") as f:
        sc = json.load(f)
    marks = load_json(MARKS, {})
    if a.mark not in marks:
        raise SystemExit("no mark %r (have: %s). Stand there and run: driver.py mark %s" % (a.mark, ", ".join(marks), a.mark))
    mark = marks[a.mark]
    events = compile_events(sc, cfg, a.timescale)
    clip = a.clip or sc.get("clip") or os.path.splitext(os.path.basename(a.scenario))[0]
    out = a.out or os.path.join(MC, "rec_auto", clip)
    os.makedirs(out, exist_ok=True)
    print("%s: %d input events, %d ticks, timescale %g -> %s" % (clip, len(events), sc.get("ticks", 128), a.timescale, out))
    gio.require_game(cfg["exe"])
    gio.console(["host_timescale %g" % a.timescale], cfg["console_key"], cfg["exe"])
    hud = Hud(cfg)
    try:
        for i in range(1, a.trials + 1):
            name = "%s_ts%s_t%d" % (a.tag, ("%g" % a.timescale).replace(".", "p"), i) if a.tag else "ts%s_t%d" % (("%g" % a.timescale).replace(".", "p"), i)
            r = run_trial(hud, cfg, mark, events, a.timescale, a.tail, a.pre)
            base = os.path.join(out, name)
            np.savez_compressed(base + "_frames.npz", frames=r["frames"], stamps=r["stamps"])
            meta = {k: r[k] for k in ("t0_perf", "timescale", "inputs", "start_hud", "start_yaw", "late_ms_max")}
            meta.update({"scenario": os.path.abspath(a.scenario), "mark": a.mark, "mark_value": mark, "roi": cfg["roi"],
                         "layout": cfg["layout"], "keys": cfg["keys"], "deg_per_count": cfg["deg_per_count"],
                         "frames": int(len(r["stamps"])), "pre_real_s": a.pre})
            save_json(base + "_inputs.json", meta)
            fps = (len(r["stamps"]) - 1) / (r["stamps"][-1] - r["stamps"][0]) if len(r["stamps"]) > 1 else 0
            print("  trial %d: %d frames (%.0f/s real), worst input lateness %.2f ms -> %s" % (i, len(r["stamps"]), fps, r["late_ms_max"], base))
    finally:
        release_all(cfg)
        if a.timescale != 1.0 and not a.keep_timescale:
            try:
                gio.console(["host_timescale 1"], cfg["console_key"], cfg["exe"])
            except gio.NotForeground:
                print("NOTE: host_timescale is still %g (the game lost focus)" % a.timescale)


def extract_trial(npz_path: str, reader: gio.HudReader, layout: dict) -> dict:
    base = npz_path[: -len("_frames.npz")]
    meta = load_json(base + "_inputs.json", {})
    ts = float(meta.get("timescale", 1.0))
    d = np.load(npz_path)
    frames, stamps = d["frames"], d["stamps"]
    cols = mc_ocr.all_columns(layout)
    raw = {c: [] for c in cols}
    texts, idx, t = [], [], []
    prev_img = None
    for i in range(len(frames)):
        img = frames[i]
        if prev_img is not None and np.array_equal(img, prev_img):
            continue  # identical capture: no new game frame, skip rather than add a duplicate row
        vals = reader.read(img)
        prev_img = img
        idx.append(i)
        t.append(float(stamps[i]) * ts)
        texts.append(reader.text(img))
        for c in cols:
            raw[c].append(vals.get(c, float("nan")))
    opts = {"hampel_window": 3, "hampel_k": 4.0, "tol_pos": 3.0, "tol_vel": 3.0, "tol_ang": 1.0}
    rows, summary = mc_post.process(idx, np.array(t), raw, layout, opts)
    mc_post.write_csv(base + ".csv", rows)
    summary.update({"source": os.path.abspath(npz_path), "timescale": ts, "time": "game seconds from the first input",
                    "units_per_meter": layout.get("units_per_meter"), "up_axis": layout.get("up_axis"),
                    "frames_captured": int(len(frames)), "frames_distinct": len(idx), "cleaning": opts})
    save_json(base + "_summary.json", summary)
    with open(base + "_ocr_text.txt", "w", encoding="utf-8") as f:
        for i, tx in zip(idx, texts):
            f.write("%d\t%s\n" % (i, tx))
    return summary


def cmd_extract(a, cfg):
    layout = mc_ocr.load_layout(os.path.join(MC, cfg["layout"]))
    reader = gio.HudReader(os.path.join(MC, cfg["layout"]), os.path.join(MC, cfg.get("grid_templates", "")))
    files = sorted(f for f in os.listdir(a.dir) if f.endswith("_frames.npz"))
    if a.only:
        files = [f for f in files if a.only in f]
    for f in files:
        s = extract_trial(os.path.join(a.dir, f), reader, layout)
        print("%s: %d distinct of %d captured" % (f, s["frames_distinct"], s["frames_captured"]))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("focus")
    s = sub.add_parser("setup"); s.add_argument("--timescale", type=float, default=1.0)
    sub.add_parser("read")
    s = sub.add_parser("mark"); s.add_argument("name")
    s = sub.add_parser("calibrate"); s.add_argument("--counts", type=int, default=1000)
    s = sub.add_parser("run")
    s.add_argument("scenario"); s.add_argument("--mark", required=True)
    s.add_argument("--trials", type=int, default=3); s.add_argument("--timescale", type=float, default=1.0)
    s.add_argument("--clip"); s.add_argument("--tag", default=""); s.add_argument("--out")
    s.add_argument("--tail", type=float, default=1.0, help="game seconds recorded after the last input")
    s.add_argument("--pre", type=float, default=0.3, help="real seconds recorded before the first input")
    s.add_argument("--keep-timescale", action="store_true")
    s = sub.add_parser("extract"); s.add_argument("dir"); s.add_argument("--only")
    s = sub.add_parser("events"); s.add_argument("scenario"); s.add_argument("--timescale", type=float, default=1.0)
    a = p.parse_args(argv)
    cfg = config()
    if a.cmd == "events":
        with open(a.scenario, encoding="utf-8") as f:
            for e in compile_events(json.load(f), cfg, a.timescale):
                print("%8.4f  %-5s %-8s tick %d" % e)
        return 0
    {"focus": lambda a, c: print("focused" if gio.focus_game(c["exe"]) else "could not focus the game"),
     "setup": cmd_setup, "read": cmd_read, "mark": cmd_mark, "calibrate": cmd_calibrate,
     "run": cmd_run, "extract": cmd_extract}[a.cmd](a, cfg)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (gio.NotForeground, gio.Aborted) as e:
        try:
            release_all(config())
        except Exception:
            pass
        print("STOPPED:", e)
        sys.exit(2)
