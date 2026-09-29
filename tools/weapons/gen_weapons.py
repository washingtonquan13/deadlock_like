"""Generate res://data/weapons/weapons.json (our tuned gun data) from the per-hero table in specs/combat.md.
Units: meters, seconds, m/s. Spread/recoil are our own by-eye approximations (docs/design/gun_system_plan.md).
Usage (from the project root): python tools/weapons/gen_weapons.py"""
import json, os, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
U = 39.37  # units per meter (combat.md global values)

# combat.md §3: attacker crit bonus scale
CRIT_BONUS_SCALE = {"Billy": -0.2, "Celeste": -0.25, "The Doorman": -0.3, "Drifter": -0.45, "Kelvin": -0.25, "Rem": -0.2, "Vyper": -0.3}
# combat.md §2: spin-up rates (fraction of the spin range per second, inferred)
SPIN = {"McGinnis": (0.5, 0.25), "Victor": (0.6, 1.0)}
# combat.md §2: max travel (u); default 7000
RANGE_U = {"Apollo": 1000.0, "Bebop": 1260.0, "Rem": 3000.0}
NO_CRIT = {"Graves", "Paige"}
PIERCE = {"Paige"}
HARD_CUTOFF = {"Apollo"}  # combat.md §4: 25.4 m hard cut-off (no damage past falloff end)
# by-eye shotgun cone half-angles (deg)
PELLET_CONE = {"Abrams": 4.5, "Calico": 5.0, "Drifter": 2.0, "Mo & Krill": 4.0, "Pocket": 3.5, "Shiv": 3.0, "Silver": 3.0, "Yamato": 2.5}


def key(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def main():
    lines = open(os.path.join(ROOT, "specs", "combat.md"), encoding="utf-8").read().splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith("| Hero | Bullet dmg"))
    out = {}
    for l in lines[start + 2:]:
        if not l.startswith("|"):
            break
        c = [x.strip() for x in l.strip("|").split("|")]
        name = c[0]
        cyc = c[4]
        spin_cycle = 0.0
        if "spin" in cyc:
            a, b = cyc.split("spin->")
            cyc, spin_cycle = float(a), float(b)
        else:
            cyc = float(cyc)
        burst, burst_gap = 1, 0.0
        if c[5] != "-":
            m = re.match(r"(\d+)x @([\d.]+)s", c[5]); burst, burst_gap = int(m.group(1)), float(m.group(2))
        reload_single, reload_delay = False, 0.0
        m = re.match(r"single ([\d.]+)s\+([\d.]+)s/shell", c[7])
        if m:
            reload_single, reload_delay, reload = True, float(m.group(1)), float(m.group(2))
        else:
            reload = float(c[7])
        f0, f1 = (float(x) for x in c[9].split("-"))
        hp, hp_boon = re.match(r"([\d.]+) \(\+([\d.]+)\)", c[15]).groups()
        pellets = int(c[3])
        auto = burst == 1 and (cyc <= 0.15 or spin_cycle > 0.0)
        dmg = float(c[1])
        w = {
            "name": name,
            "bullet_damage": dmg, "bullet_damage_per_boon": float(c[2]), "pellets": pellets,
            "cycle_time": cyc, "burst_count": burst, "burst_interval": burst_gap,
            "spins_up": spin_cycle > 0.0, "spin_cycle_time": spin_cycle,
            "spin_up_rate": SPIN.get(name, (0, 0))[0], "spin_down_rate": SPIN.get(name, (0, 0))[1],
            "clip_size": int(c[6]), "reload_time": reload, "reload_single": reload_single, "reload_single_delay": reload_delay,
            "bullet_speed": float(c[8]), "gravity_scale": float(c[11]), "bullet_radius": float(c[12]) / 100.0,
            "bullet_lifetime": float(c[13]), "range": RANGE_U.get(name, 7000.0) / U,
            "falloff_start": f0, "falloff_end": f1, "falloff_end_scale": float(c[10]),
            "hard_range_cutoff": name in HARD_CUTOFF,
            "can_crit": name not in NO_CRIT, "pierce": name in PIERCE,
            "crit_bonus_scale": CRIT_BONUS_SCALE.get(name, 0.0), "crit_damage_received_scale": float(c[17]),
            "shoot_move_speed_pct": 0.85 if name == "Rem" else 0.75,
            "hero_health": float(hp), "hero_health_per_boon": float(hp_boon), "hero_regen": float(c[16]),
            # approximations (by eye): cone half-angles in degrees, recoil kick in degrees
            "spread_base": PELLET_CONE.get(name, 0.25 if not auto else 0.4),
            "spread_bloom_per_shot": 0.0 if pellets > 1 else (0.4 if auto else 0.15),
            "spread_bloom_max": 0.0 if pellets > 1 else (2.5 if auto else 1.0),
            "spread_bloom_decay": 4.0,
            "recoil_kick": round(min(1.2, 0.25 + 0.03 * dmg * pellets), 3),
            "_source": "specs/combat.md per-hero table (community-datamine 2026-09-16 snapshot); spread/recoil approximated",
        }
        out[key(name)] = w
    p = os.path.join(ROOT, "data", "weapons", "weapons.json")
    json.dump(out, open(p, "w", encoding="utf-8"), indent=1)
    print("wrote %d weapons -> %s" % (len(out), p))


if __name__ == "__main__":
    main()
