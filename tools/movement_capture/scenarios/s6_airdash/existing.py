"""Session 6: what the existing air-dash recordings establish about entry speed (HUD only).
Run from tools/movement_capture:  .venv/Scripts/python.exe scenarios/s6_airdash/existing.py [csv glob ...]
(new set: "rec_auto/s6_airdash/*/*.csv"). h_in is unsigned and only good to ~+-20 u/s at low h (HUD lags ~1 tick;
a 1-tick error in the dash time moves vz by 12 u/s); it is much tighter for high h.
Per trial: takeoff and dash onset from HUD steps, vz at the dash pinned from the plain-jump launch
(vz0 = 290, g = 796), entry h = sqrt(HUD_pre^2 - vz^2), peak HUD after the dash (gravity off, so HUD = h),
and the model peak (frac*8m/dur + 0.26*v_par0; perpendicular kept)."""
import csv, glob, json, math, os
G, VZ0 = 796.0, 290.0
TGT = {"street": 554.1, "street_inf": 516.1, "street_abr": 484.7, "street_y148": 554.1}   # session 5 intercepts
SLOPE = {"street": 0.240, "street_inf": 0.260, "street_abr": 0.266, "street_y148": 0.240}
MODEL_C = {"street": 0.759 * 8 * 39.3701 / 0.43, "street_inf": 0.776 * 8 * 39.3701 / 0.47,
           "street_abr": 0.789 * 8 * 39.3701 / 0.51, "street_y148": 0.759 * 8 * 39.3701 / 0.43}

def rows(f):
    out = []
    for r in csv.DictReader(open(f)):
        if r["valid"] == "1":
            out.append((float(r["t"]) * 64 + 1, float(r["vel_scalar"])))
    return out

def first_step(rs, after, sign, thr):
    for i in range(1, len(rs)):
        if rs[i][0] > after and sign * (rs[i][1] - rs[i - 1][1]) > thr:
            return i
    return None

def analyse(csvf):
    inp = json.load(open(csvf.replace(".csv", "_inputs.json")))
    ev = inp["inputs"]; mark = inp.get("mark")
    sp = sorted(e["tick"] for e in ev if e["kind"] == "down" and e["arg"] == "space")
    if not sp:
        return None
    jt = sp[0]
    dts = [e["tick"] for e in ev if e["kind"] == "down" and e["arg"] == "lshift" and e["tick"] > jt]
    if not dts:
        return None
    dt_in = dts[-1]
    held = sorted(set(e["arg"] for e in ev if e["kind"] == "down" and dt_in - 3 <= e["tick"] <= dt_in + 1
                      and e["arg"] in "wasd") | set(
        e["arg"] for e in ev if e["kind"] == "down" and e["tick"] < dt_in and e["arg"] in "wasd"
        and not any(u["kind"] == "up" and u["arg"] == e["arg"] and e["tick"] <= u["tick"] <= dt_in for u in ev)))
    rs = rows(csvf)
    last_sp = max(s for s in sp if s < dt_in)
    gd = [e["tick"] for e in ev if e["kind"] == "down" and e["arg"] == "lshift" and e["tick"] < jt]
    k = jt - gd[-1] if gd else None
    if last_sp != jt:
        vz0 = 522.0            # an air jump sets vz 522
    elif k is not None and 20 <= k <= 35:
        vz0 = 416.0            # dash jump (session 5: vz0 ~414-419)
    elif k is not None and k <= 60:
        vz0 = 283.0            # plain jump off a dash tail (session 4: ~283)
    else:
        vz0 = VZ0
    it = first_step(rs, last_sp - 0.5, +1, 4.0)
    idn = first_step(rs, dt_in - 0.5, -1, 4.0)
    if it is None or idn is None:
        return None
    t_to, t_d = rs[it - 1][0], rs[idn - 1][0]
    hud_pre = rs[idn - 1][1]
    vz = vz0 - G * (t_d - t_to) / 64.0
    h = math.sqrt(max(0.0, hud_pre ** 2 - vz ** 2))
    win = [r for r in rs[idn:] if r[0] < t_d + 16]
    pk = max(win, key=lambda r: r[1])
    return dict(file=os.path.relpath(csvf).replace("\\", "/"), mark=mark, held=held, jump=jt, dash=dt_in,
                t_takeoff=t_to, t_dash=t_d, air_ticks=t_d - t_to, vz=vz, hud_pre=hud_pre, h=h,
                peak=pk[1], rise=pk[0] - t_d)

if __name__ == "__main__":
    import sys
    pats = sys.argv[1:] or ["rec_auto/A_air_b*/*.csv", "rec_auto/A_probe_b*/*.csv", "rec_auto/stam/SAJ*/*.csv"]
    fs = sorted(f for p in pats for f in glob.glob(p))
    print("%-42s %-11s %-6s %5s %6s %6s %6s %7s %5s %7s" % ("trial", "mark", "keys", "air", "vz", "HUDpre", "h_in", "peak", "rise", "c+m*h"))
    for f in fs:
        r = analyse(f)
        if r is None:
            print("%-42s (no air dash / not detected)" % f); continue
        pred = TGT.get(r["mark"], float("nan")) + SLOPE.get(r["mark"], float("nan")) * r["h"]
        print("%-42s %-11s %-6s %5.1f %6.1f %6.1f %6.1f %7.1f %5.1f %7.1f" % (
            r["file"][9:], r["mark"], "".join(r["held"]), r["air_ticks"], r["vz"], r["hud_pre"], r["h"], r["peak"], r["rise"], pred))
