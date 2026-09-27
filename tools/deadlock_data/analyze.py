#!/usr/bin/env python3
"""Game-design analyses over data/reference/*.csv -> Markdown in data/reports/.

  python analyze.py                      # all reports
  python analyze.py items heroes ttk winrate economy
  python analyze.py calc --hero Infernus --hp 2500 --dist 20 --hs 0.3 --bonus 0.25
      (one-off weapon DPS/TTK calculation printed to the console)

All numbers are REFERENCE observations of Deadlock for a clean-room game. Formulas
marked 'inferred' are our own models, validated where possible against the
API's own derived fields (e.g. shots_per_second).
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics as st
from collections import defaultdict
from pathlib import Path

from common import REF_DIR, REPORT_DIR, UNITS_TO_M, ensure_dirs, utc_now_iso


def load(name: str) -> list[dict]:
    p = REF_DIR / name
    if not p.exists():
        return []
    with p.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def f(v, default=None):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _fmt(x) -> str:
    if x is None:
        return ""
    if isinstance(x, float):
        if math.isinf(x) or math.isnan(x):
            return str(x)
        if abs(x) >= 100 or x.is_integer():
            return f"{x:.0f}"
        return f"{x:.3g}"
    return str(x)


def md_table(headers, rows) -> str:
    out = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    for r in rows:
        out.append("| " + " | ".join(_fmt(x) for x in r) + " |")
    return "\n".join(out)


def header(title, sources) -> str:
    prov = sorted({s for s in sources if s})
    return (f"# {title}\n\n_Generated {utc_now_iso()} by tools/deadlock_data/analyze.py. "
            "REFERENCE ONLY - observations of Deadlock, not our tuning._\n\n"
            "Sources:\n" + "\n".join(f"- `{p}`" for p in prov[:6]) + "\n\n")


def write_report(name, text):
    p = REPORT_DIR / name
    p.write_text(text, encoding="utf-8")
    print(f"  wrote {p.relative_to(REPORT_DIR.parents[1])}")


# ---------------------------------------------------------------- items
def report_items():
    items = load("items.csv")
    if not items:
        return
    by_tier = defaultdict(list)
    stat_rows = defaultdict(list)  # stat -> [(tier, slot, name, value, cost)]
    for it in items:
        tier, cost = int(f(it["tier"], 0)), f(it["cost"], 0)
        by_tier[(it["slot"], tier)].append(it)
        for k, v in json.loads(it["properties_json"] or "{}").items():
            stat_rows[k].append((tier, it["slot"], it["name"], v, cost))
    txt = header("Item cost vs stat efficiency", [i["provenance"] for i in items[:1]])
    txt += "## Shop structure (count / cost per slot & tier)\n\n"
    rows = []
    for (slot, tier), lst in sorted(by_tier.items()):
        costs = [f(i["cost"], 0) for i in lst]
        actives = sum(1 for i in lst if i["is_active"] == "True")
        rows.append((slot, tier, len(lst), min(costs), max(costs), actives))
    txt += md_table(["slot", "tier", "items", "min cost", "max cost", "actives"], rows) + "\n\n"
    txt += ("## Stat per 1000 souls, by tier\n\nFor every stat that appears on >=3 items in >=2 tiers: "
            "median value, and median value per 1000 souls. A falling 'per 1k' column across tiers "
            "means higher tiers pay a premium for the slot (typical: power budget grows slower "
            "than cost, the rest is bought as unique effects).\n\n")
    for stat, lst in sorted(stat_rows.items(), key=lambda kv: -len(kv[1])):
        tiers = sorted({t for t, *_ in lst})
        if len(lst) < 3 or len(tiers) < 2:
            continue
        rows = []
        for t in tiers:
            sub = [(v, c, n) for tt, _s, n, v, c in lst if tt == t]
            vals = [v for v, _c, _n in sub]
            per1k = [v / c * 1000 for v, c, _n in sub if c]
            rows.append((t, len(sub), st.median(vals), st.median(per1k) if per1k else None,
                         ", ".join(n for *_x, n in sub[:4]) + (" ..." if len(sub) > 4 else "")))
        txt += f"### {stat}\n\n" + md_table(["tier", "n", "median value", "median /1k souls", "examples"], rows) + "\n\n"
    write_report("item_efficiency.md", txt)


# ---------------------------------------------------------------- heroes
def report_heroes():
    heroes = load("heroes.csv")
    if not heroes:
        return
    cols = [c for c in heroes[0] if (c.startswith("base_") or c.startswith("wpn_") or c.startswith("perlvl_"))]
    rows = []
    for c in cols:
        vals = [(f(h[c]), h["name"]) for h in heroes if f(h[c]) is not None]
        if len(vals) < 3:
            continue
        nums = sorted(v for v, _ in vals)
        if nums[0] == nums[-1]:
            rows.append((c, nums[0], nums[0], nums[0], 0.0, "all equal", ""))
            continue
        q = st.quantiles(nums, n=4)
        lo = min(vals)[1]
        hi = max(vals)[1]
        rows.append((c, nums[0], q[1], nums[-1], st.pstdev(nums), lo, hi))
    txt = header("Hero base stat distributions", [heroes[0]["provenance"]])
    txt += ("Units: `base_max_move_speed`, dash distances in m / m/s (field names say meters); "
            "`wpn_*_range` in engine units (1 unit = 0.0254 m, inferred), `_m` columns converted. "
            "`wpn_crit_bonus_start` = headshot multiplier at close range.\n\n")
    txt += md_table(["stat", "min", "median", "max", "stdev", "min hero", "max hero"], rows) + "\n\n"
    txt += "## Per-hero summary\n\n"
    hr = []
    for h in sorted(heroes, key=lambda h: h["name"]):
        hr.append((h["name"], h["hero_type"], f(h.get("base_max_health")), f(h.get("base_max_move_speed")),
                   f(h.get("wpn_damage_per_second")), f(h.get("wpn_clip_size")),
                   f(h.get("wpn_damage_falloff_start_range_m")), f(h.get("wpn_damage_falloff_end_range_m"))))
    txt += md_table(["hero", "type", "HP", "move m/s", "DPS", "clip", "falloff start m", "falloff end m"], hr) + "\n"
    write_report("hero_base_stats.md", txt)


# ---------------------------------------------------------------- weapon model
class Weapon:
    """Deadlock-style hitscan/projectile weapon model (inferred from public field names)."""

    def __init__(self, row: dict):
        g = lambda k, d=0.0: f(row.get("wpn_" + k), d)
        self.name = row.get("weapon_name") or row.get("weapon_class")
        self.dmg = g("bullet_damage")
        self.bullets = max(1, int(g("bullets", 1)))
        self.cycle = g("cycle_time", 0.1) or 0.1
        self.clip = max(1, int(g("clip_size", 1)))
        self.reload = g("reload_duration", 2.0)
        self.burst = max(1, int(g("burst_shot_count", 1)))
        self.burst_cd = g("burst_shot_cooldown", 0.0)
        self.f_start, self.f_end = g("damage_falloff_start_range"), g("damage_falloff_end_range")
        self.f_s0, self.f_s1 = g("damage_falloff_start_scale", 1.0), g("damage_falloff_end_scale", 1.0)
        self.f_bias = g("damage_falloff_bias", 0.5) or 0.5
        self.crit0, self.crit1 = g("crit_bonus_start", 1.0), g("crit_bonus_end", 1.0)
        self.crit_r0, self.crit_r1 = g("crit_bonus_start_range", 0.0), g("crit_bonus_end_range", 1.0)
        self.api_sps = g("shots_per_second", None)
        self.api_dps = g("damage_per_second", None)
        self.api_dps_reload = g("damage_per_second_with_reload", None)

    @staticmethod
    def _bias(x, b):  # Source-engine style Bias(); b=0.5 is linear (inferred)
        if x <= 0 or x >= 1 or b <= 0 or b >= 1:
            return min(max(x, 0.0), 1.0)
        return x ** (math.log(b) / math.log(0.5))

    def falloff(self, dist_m: float) -> float:
        d = dist_m / UNITS_TO_M
        if self.f_end <= self.f_start:
            return self.f_s0
        t = self._bias((d - self.f_start) / (self.f_end - self.f_start), self.f_bias)
        return self.f_s0 + (self.f_s1 - self.f_s0) * t

    def hs_mult(self, dist_m: float) -> float:
        d = dist_m / UNITS_TO_M
        span = max(self.crit_r1 - self.crit_r0, 1e-6)
        t = min(max((d - self.crit_r0) / span, 0.0), 1.0)
        return self.crit0 + (self.crit1 - self.crit0) * t

    def shot_interval(self, shot_index: int) -> float:
        """Time after shot `shot_index` (0-based within magazine) until the next one."""
        if self.burst > 1 and (shot_index + 1) % self.burst == 0:
            return self.cycle + self.burst_cd
        return self.cycle

    def model_sps(self) -> float:
        per_burst = self.cycle * self.burst + (self.burst_cd if self.burst > 1 else 0)
        return self.burst / per_burst

    def dmg_per_shot(self, dist_m, hs_rate=0.0, bonus=0.0, flat=0.0) -> float:
        base = (self.dmg + flat) * (1 + bonus) * self.bullets * self.falloff(dist_m)
        return base * (1 + hs_rate * (self.hs_mult(dist_m) - 1))

    def sustained_dps(self, dist_m=0.0, hs_rate=0.0, bonus=0.0, flat=0.0) -> float:
        mag_time = sum(self.shot_interval(i) for i in range(self.clip - 1)) + self.cycle + self.reload
        return self.dmg_per_shot(dist_m, hs_rate, bonus, flat) * self.clip / mag_time

    def ttk(self, hp, dist_m=0.0, hs_rate=0.0, bonus=0.0, flat=0.0, armor=0.0, max_s=300.0):
        """Seconds from first shot to kill (first shot lands at t=0). Includes reloads."""
        per = self.dmg_per_shot(dist_m, hs_rate, bonus, flat) * (1 - armor)
        if per <= 0:
            return math.inf, 0
        need = math.ceil(hp / per)
        t, in_mag = 0.0, 0
        for shot in range(1, need):
            t += self.shot_interval(in_mag)
            in_mag += 1
            if in_mag >= self.clip:
                t += self.reload
                in_mag = 0
            if t > max_s:
                return math.inf, need
        return t, need


def report_ttk():
    heroes = load("heroes.csv")
    if not heroes:
        return
    dists = [5, 15, 25, 40]
    txt = header("Weapon DPS / TTK reference", [heroes[0]["provenance"]])
    txt += (
        "Model (source_type=inferred, our own): damage per shot = bullet_damage x pellets x falloff(d) x "
        "(1 + hs_rate x (hs_mult(d)-1)). Falloff lerps start_scale->end_scale between falloff start/end range "
        "with a Source-style bias curve (bias 0.5 = linear). Headshot multiplier lerps crit_bonus_start->end "
        "over crit ranges. Engine units -> m at 0.0254. Burst weapons: cycle_time between shots, "
        "+burst_shot_cooldown after each burst. `model sps` vs `api sps` checks the fire-rate model against "
        "the API's own derived value.\n\n")
    rows = []
    for h in sorted(heroes, key=lambda h: h["name"]):
        w = Weapon(h)
        flag = "" if w.api_sps and abs(w.model_sps() - w.api_sps) / w.api_sps < 0.02 else " (!)"
        rows.append((h["name"], w.name, w.dmg, w.bullets, w.clip, f"{w.model_sps():.2f}{flag}", w.api_sps,
                     w.api_dps, round(w.sustained_dps(), 1), w.api_dps_reload,
                     *[round(w.falloff(d), 2) for d in dists]))
    txt += "## Fire rate and falloff\n\n" + md_table(
        ["hero", "weapon", "dmg/bullet", "pellets", "clip", "model sps", "api sps", "api dps",
         "model dps w/ reload", "api dps w/ reload"] + [f"falloff@{d}m" for d in dists], rows) + "\n\n"
    txt += ("(!) = our fire-rate model disagrees with the API (weapon has a special mechanic such as "
            "spin-up, charge or alt-fire; measure in-game before relying on it). The API's with-reload DPS "
            "is usually a bit lower than ours - it appears to include an extra ~0.25 s per reload "
            "(unverified; measure it, see specs/_measurement_protocol.md).\n\n"
            "TTK tables: base weapon at level 1, no items, no per-level bullet scaling "
            "(`perlvl_base_bullet_damage_from_level` in heroes.csv), no spirit damage. Real fights "
            "are much shorter because abilities and items add most of the damage.\n\n")
    for hp in (800, 1500):
        rows = []
        for h in sorted(heroes, key=lambda h: h["name"]):
            w = Weapon(h)
            cells = []
            for d in (10, 25, 40):
                for hs in (0.0, 0.3):
                    t, n = w.ttk(hp, d, hs)
                    cells.append("inf" if math.isinf(t) else f"{t:.2f}s/{n}")
            rows.append((h["name"], *cells))
        txt += (f"## TTK vs {hp} HP target, base weapon, no items (time / shots)\n\n" + md_table(
            ["hero"] + [f"{d}m hs{int(hs*100)}%" for d in (10, 25, 40) for hs in (0.0, 0.3)], rows) + "\n\n")
    write_report("weapon_ttk.md", txt)


# ---------------------------------------------------------------- win rates
def pearson(xs, ys):
    if len(xs) < 3:
        return None
    mx, my = st.mean(xs), st.mean(ys)
    sx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    sy = math.sqrt(sum((y - my) ** 2 for y in ys))
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / (sx * sy) if sx and sy else None


def report_winrate():
    rows = [r for r in load("analytics_item_stats.csv") if f(r["cost"])]
    heroes = load("analytics_hero_stats.csv")
    if not rows and not heroes:
        return
    src = [(rows or heroes)[0]["provenance"]]
    txt = header("Win rate vs cost (items) and hero win rates", src)
    txt += ("**Caveat:** item win rate is observational. Items bought late are bought by players who are "
            "already ahead (survivorship), so expensive items look stronger than they are. Treat as a "
            "sanity check, not as a balance target.\n\n")
    if rows:
        tiers = defaultdict(list)
        for r in rows:
            tiers[(r["slot"], int(f(r["tier"])))].append(r)
        t = []
        for k, lst in sorted(tiers.items()):
            wr = [f(r["win_rate"]) for r in lst]
            t.append((k[0], k[1], len(lst), st.mean(wr), min(wr), max(wr),
                      st.mean(f(r["avg_buy_time_s"]) for r in lst) / 60))
        txt += "## By slot and tier\n\n" + md_table(
            ["slot", "tier", "items", "mean WR", "min WR", "max WR", "avg buy min"], t) + "\n\n"
        c1 = pearson([f(r["cost"]) for r in rows], [f(r["win_rate"]) for r in rows])
        c2 = pearson([f(r["avg_buy_time_s"]) for r in rows], [f(r["win_rate"]) for r in rows])
        txt += f"Pearson r(cost, win rate) = {c1:.3f}; r(avg buy time, win rate) = {c2:.3f}\n\n"
        srt = sorted(rows, key=lambda r: f(r["win_rate"]))
        fmt = lambda r: (r["name"], r["slot"], r["tier"], r["cost"], f(r["win_rate"]), r["matches"],
                         round(f(r["avg_buy_time_s"]) / 60, 1))
        hdr = ["item", "slot", "tier", "cost", "WR", "matches", "avg buy min"]
        txt += "## Highest win rate\n\n" + md_table(hdr, [fmt(r) for r in srt[::-1][:12]]) + "\n\n"
        txt += "## Lowest win rate\n\n" + md_table(hdr, [fmt(r) for r in srt[:12]]) + "\n\n"
    if heroes:
        wr = [f(h["win_rate"]) for h in heroes]
        txt += (f"## Heroes\n\nSpread: min {min(wr):.3f}, median {st.median(wr):.3f}, max {max(wr):.3f}, "
                f"stdev {st.pstdev(wr):.3f} over {len(wr)} heroes.\n\n")
        txt += md_table(["hero", "WR", "pick share", "K", "D", "A", "net worth", "player dmg", "accuracy"],
                        [(h["hero_name"], f(h["win_rate"]), f(h["pick_share_of_slots"]), f(h["avg_kills"]),
                          f(h["avg_deaths"]), f(h["avg_assists"]), f(h["avg_net_worth"]),
                          f(h["avg_player_damage"]), f(h["accuracy"])) for h in heroes]) + "\n"
    write_report("winrate_vs_cost.md", txt)


# ---------------------------------------------------------------- economy
def report_economy():
    g = {r["key"]: f(r["value"]) for r in load("analytics_game_stats.csv")}
    eco = load("economy.csv")
    if not g and not eco:
        return
    txt = header("Match economy reference", [(load("analytics_game_stats.csv") or eco)[0]["provenance"]])
    if g:
        dur = g.get("avg_duration_s") or 0
        txt += (f"Average match: {dur/60:.1f} min, K/D/A {g.get('avg_kills', 0):.1f}/"
                f"{g.get('avg_deaths', 0):.1f}/{g.get('avg_assists', 0):.1f}, end net worth "
                f"{g.get('avg_net_worth', 0):.0f} souls, end level {g.get('avg_ending_level', 0):.1f}.\n\n")
        src = {k: v for k, v in g.items() if k.startswith("avg_gold_") and v}
        tot = sum(v for k, v in src.items() if not k.endswith(("_orbs", "_orb", "denied", "death_loss")))
        txt += "## Soul income by source (per player per match)\n\n"
        txt += md_table(["source", "avg souls", "share of listed income", "per minute"],
                        [(k.replace("avg_gold_", ""), v, v / tot if tot else None, v / (dur / 60) if dur else None)
                         for k, v in sorted(src.items(), key=lambda kv: -kv[1])]) + "\n\n"
        txt += "`*_orbs` rows are the part of that source delivered as orbs (subset, excluded from share).\n\n"
        txt += "## All aggregate fields\n\n" + md_table(["field", "value"], sorted(g.items())) + "\n\n"
    if eco:
        txt += "## Economy constants (community-datamine)\n\n" + md_table(
            ["key", "value"], [(r["key"], r["value"]) for r in eco]) + "\n"
    write_report("economy.md", txt)


def calc(args):
    heroes = {h["name"].lower(): h for h in load("heroes.csv")}
    h = heroes.get(args.hero.lower())
    if not h:
        raise SystemExit(f"unknown hero {args.hero!r}; known: {', '.join(sorted(heroes))}")
    w = Weapon(h)
    t, n = w.ttk(args.hp, args.dist, args.hs, args.bonus, args.flat, args.armor)
    print(f"{h['name']} / {w.name} @ {args.dist} m, hs {args.hs:.0%}, +{args.bonus:.0%} weapon dmg, "
          f"armor {args.armor:.0%}")
    print(f"  falloff x{w.falloff(args.dist):.3f}  headshot x{w.hs_mult(args.dist):.2f}")
    print(f"  dmg/shot {w.dmg_per_shot(args.dist, args.hs, args.bonus, args.flat):.1f}  "
          f"sustained DPS {w.sustained_dps(args.dist, args.hs, args.bonus, args.flat) * (1 - args.armor):.1f}")
    print(f"  TTK vs {args.hp:.0f} HP: " + ("> 300 s" if math.isinf(t) else f"{t:.2f}s") + f" ({n} shots)")


REPORTS = {"items": report_items, "heroes": report_heroes, "ttk": report_ttk,
           "winrate": report_winrate, "economy": report_economy}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("what", nargs="*", default=list(REPORTS), help=f"{list(REPORTS)} or calc")
    ap.add_argument("--hero", default="Infernus")
    ap.add_argument("--hp", type=float, default=2500)
    ap.add_argument("--dist", type=float, default=20, help="metres")
    ap.add_argument("--hs", type=float, default=0.0, help="headshot fraction 0..1")
    ap.add_argument("--bonus", type=float, default=0.0, help="weapon damage bonus fraction")
    ap.add_argument("--flat", type=float, default=0.0, help="flat bullet damage bonus")
    ap.add_argument("--armor", type=float, default=0.0, help="target bullet resist fraction")
    a = ap.parse_args(argv)
    ensure_dirs()
    if "calc" in a.what:
        return calc(a)
    for w in a.what:
        REPORTS[w]()


if __name__ == "__main__":
    main()
