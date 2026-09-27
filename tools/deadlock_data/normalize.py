#!/usr/bin/env python3
"""Flatten cached raw JSON (from fetch.py) into CSVs under data/reference/.

Tolerant of schema drift: every field is read with .get(), unknown stats are
carried through generically, and each row has `provenance` + `source_type`.
No lore / long descriptions are exported - numbers and names only.

  python normalize.py            # all datasets present in cache
  python normalize.py --limit 5  # quick smoke test (first N rows per table)
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from common import REF_DIR, UNITS_TO_M, ensure_dirs, latest_cache, provenance, to_float

# Ability properties that are engine defaults / UI plumbing, not design numbers.
NOISE_PROPS = {"AbilityUnitTargetLimit", "ChannelMoveSpeed", "AbilityCooldownBetweenCharge",
               "AbilityPostCastDuration", "AbilityResourceCost", "HeightOffGround",
               "ParticleRadiusMultiplier"}
CORE_PROPS = {"AbilityCooldown": "cooldown_s", "AbilityCastRange": "cast_range_m",
              "AbilityCharges": "charges", "AbilityCastDelay": "cast_delay_s",
              "AbilityDuration": "duration_s", "AbilityChannelTime": "channel_s"}
WEAPON_FIELDS = ["bullet_damage", "bullets", "cycle_time", "clip_size", "reload_duration",
                 "burst_shot_count", "burst_shot_cooldown", "bullet_speed", "bullet_gravity_scale",
                 "damage_falloff_start_range", "damage_falloff_end_range",
                 "damage_falloff_start_scale", "damage_falloff_end_scale", "damage_falloff_bias",
                 "crit_bonus_start", "crit_bonus_end", "crit_bonus_start_range", "crit_bonus_end_range",
                 "range", "shoot_move_speed_percent", "shots_per_second", "damage_per_shot",
                 "damage_per_second", "damage_per_second_with_reload", "damage_per_magazine"]


def write_csv(name: str, rows: list[dict], limit: int | None) -> Path:
    path = REF_DIR / name
    if limit:
        rows = rows[:limit]
    cols: list[str] = []
    for r in rows:
        for k in r:
            if k not in cols:
                cols.append(k)
    # provenance columns last for readability
    for k in ("source_type", "provenance"):
        if k in cols:
            cols.remove(k)
            cols.append(k)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {path.relative_to(REF_DIR.parents[1])} ({len(rows)} rows)")
    return path


def latest_client_version() -> str:
    env = latest_cache("client_versions")
    if env and isinstance(env.get("data"), list) and env["data"]:
        return str(max(env["data"]))
    return "latest"


def _prov(env: dict, cv: str) -> dict:
    e = dict(env)
    if not e.get("client_version"):
        e["client_version"] = f"latest({cv})"
    return {"source_type": env.get("source_type"), "provenance": provenance(e)}


def numeric_props(props: dict) -> dict:
    out = {}
    for k, p in (props or {}).items():
        if not isinstance(p, dict) or k in NOISE_PROPS or k in CORE_PROPS:
            continue
        v = to_float(p.get("value"))
        if v is None or v == 0:
            continue
        if to_float(p.get("disable_value")) == v:
            continue
        out[k] = v
    return out


def items_index(items_env) -> dict:
    return {i.get("class_name"): i for i in (items_env or {}).get("data", []) if isinstance(i, dict)}


def norm_heroes(heroes_env, items_env, cv) -> list[dict]:
    idx = items_index(items_env)
    rows = []
    for h in heroes_env.get("data", []):
        r = {"hero_id": h.get("id"), "class_name": h.get("class_name"), "name": h.get("name"),
             "hero_type": h.get("hero_type"), "complexity": h.get("complexity"),
             "gun_tag": h.get("gun_tag")}
        for k, s in (h.get("starting_stats") or {}).items():
            r[f"base_{k}"] = s.get("value") if isinstance(s, dict) else s
        for k, v in (h.get("standard_level_up_upgrades") or {}).items():
            short = k.replace("MODIFIER_VALUE_", "").lower()
            if to_float(v):
                r[f"perlvl_{short}"] = v
        lv = h.get("level_info") or {}
        if lv:
            r["max_level"] = max(int(k) for k in lv)
            r["souls_for_max_level"] = max((x.get("required_gold") or 0) for x in lv.values())
        for slot, bonuses in (h.get("purchase_bonuses") or {}).items():
            for b in bonuses or []:
                vt = (b.get("value_type") or "").replace("MODIFIER_VALUE_", "").lower()
                r[f"shopbonus_{slot}_t{b.get('tier')}_{vt}"] = b.get("value")
        wcls = (h.get("items") or {}).get("weapon_primary")
        wi = (idx.get(wcls) or {}).get("weapon_info") or {}
        r["weapon_class"] = wcls
        r["weapon_name"] = (idx.get(wcls) or {}).get("name")
        for f in WEAPON_FIELDS:
            r[f"wpn_{f}"] = wi.get(f)
        for f in ("damage_falloff_start_range", "damage_falloff_end_range"):
            v = to_float(wi.get(f))
            r[f"wpn_{f}_m"] = round(v * UNITS_TO_M, 2) if v is not None else None
        for i in range(1, 5):
            r[f"ability{i}_class"] = (h.get("items") or {}).get(f"signature{i}")
        r.update(_prov(heroes_env, cv))
        rows.append(r)
    return rows


def _upgrade_text(upg) -> str:
    parts = []
    for p in upg.get("property_upgrades", []) if isinstance(upg, dict) else []:
        parts.append(f"{p.get('name')}:{p.get('bonus')}")
    return "; ".join(parts)


def norm_abilities(heroes_env, items_env, cv) -> list[dict]:
    idx = items_index(items_env)
    rows = []
    for h in heroes_env.get("data", []):
        for i in range(1, 5):
            cls = (h.get("items") or {}).get(f"signature{i}")
            a = idx.get(cls)
            if not a:
                continue
            props = a.get("properties") or {}
            r = {"hero_id": h.get("id"), "hero_name": h.get("name"), "slot": i,
                 "ability_id": a.get("id"), "class_name": cls, "name": a.get("name"),
                 "ability_type": a.get("ability_type")}
            for pk, col in CORE_PROPS.items():
                v = to_float((props.get(pk) or {}).get("value"))
                r[col] = v if v not in (None, 0) else ""
            ups = a.get("upgrades") or []
            for t in range(3):
                r[f"t{t+1}_upgrade"] = _upgrade_text(ups[t]) if t < len(ups) else ""
            r["key_properties_json"] = json.dumps(numeric_props(props), sort_keys=True)
            r.update(_prov(items_env, cv))
            rows.append(r)
    return rows


def norm_items(items_env, cv) -> list[dict]:
    rows = []
    for it in items_env.get("data", []):
        if it.get("type") != "upgrade" or not it.get("shopable"):
            continue
        props = it.get("properties") or {}
        cd = to_float((props.get("AbilityCooldown") or {}).get("value"))
        r = {"item_id": it.get("id"), "class_name": it.get("class_name"), "name": it.get("name"),
             "slot": it.get("item_slot_type"), "tier": it.get("item_tier"), "cost": it.get("cost"),
             "is_active": it.get("is_active_item"), "activation": it.get("activation"),
             "cooldown_s": cd or "",
             "properties_json": json.dumps(numeric_props(props), sort_keys=True)}
        r.update(_prov(items_env, cv))
        rows.append(r)
    rows.sort(key=lambda r: (str(r["slot"]), r["tier"] or 0, r["cost"] or 0, str(r["name"])))
    return rows


def norm_npcs(env, cv) -> list[dict]:
    rows = []
    for u in env.get("data", []):
        r = {k: v for k, v in u.items() if not isinstance(v, (dict, list))}
        wi = u.get("weapon_info") or {}
        for f in ("bullet_damage", "cycle_time", "range", "damage_per_second"):
            if f in wi:
                r[f"wpn_{f}"] = wi[f]
        r.update(_prov(env, cv))
        rows.append(r)
    return rows


def _flatten(prefix, v, out):
    if isinstance(v, dict):
        for k, x in v.items():
            _flatten(f"{prefix}.{k}" if prefix else k, x, out)
    elif isinstance(v, list) and all(isinstance(x, (int, float)) for x in v):
        out[prefix] = json.dumps(v)
    elif isinstance(v, (int, float, str)) and not isinstance(v, bool):
        out[prefix] = v


def norm_economy(env, cv) -> list[dict]:
    d = env.get("data") or {}
    keep = ["item_price_per_tier", "trooper_kill_gold_share_frac", "hero_kill_gold_share_frac",
            "objective_params", "rejuv_params"]
    flat: dict = {}
    for k in keep:
        if k in d:
            _flatten(k, d[k], flat)
    p = _prov(env, cv)
    return [{"key": k, "value": v, **p} for k, v in flat.items()]


def norm_hero_stats(env, heroes_env) -> list[dict]:
    names = {h.get("id"): h.get("name") for h in (heroes_env or {}).get("data", [])}
    data = [r for r in env.get("data", []) if isinstance(r, dict)]
    total_player_slots = sum(r.get("matches", 0) for r in data) or 1
    rows = []
    for s in data:
        m = s.get("matches") or 0
        if not m:
            continue
        hit, miss = s.get("total_shots_hit") or 0, s.get("total_shots_missed") or 0
        rows.append({
            "hero_id": s.get("hero_id"), "hero_name": names.get(s.get("hero_id"), ""),
            "matches": m, "wins": s.get("wins"), "losses": s.get("losses"),
            "win_rate": round((s.get("wins") or 0) / m, 4),
            "pick_share_of_slots": round(m / total_player_slots, 4),
            "avg_kills": round((s.get("total_kills") or 0) / m, 2),
            "avg_deaths": round((s.get("total_deaths") or 0) / m, 2),
            "avg_assists": round((s.get("total_assists") or 0) / m, 2),
            "avg_net_worth": round((s.get("total_net_worth") or 0) / m, 0),
            "avg_last_hits": round((s.get("total_last_hits") or 0) / m, 1),
            "avg_player_damage": round((s.get("total_player_damage") or 0) / m, 0),
            "avg_player_damage_taken": round((s.get("total_player_damage_taken") or 0) / m, 0),
            "avg_boss_damage": round((s.get("total_boss_damage") or 0) / m, 0),
            "avg_end_max_health": round((s.get("total_max_health") or 0) / m, 0),
            "accuracy": round(hit / (hit + miss), 4) if hit + miss else "",
            "source_type": env.get("source_type"), "provenance": provenance(env)})
    rows.sort(key=lambda r: -r["win_rate"])
    return rows


def norm_item_stats(env, items_env) -> list[dict]:
    idx = {i.get("id"): i for i in (items_env or {}).get("data", [])}
    rows = []
    for s in env.get("data", []):
        m = s.get("matches") or 0
        it = idx.get(s.get("item_id"), {})
        if not m or it.get("type") != "upgrade":
            continue
        rows.append({"item_id": s.get("item_id"), "name": it.get("name"),
                     "slot": it.get("item_slot_type"), "tier": it.get("item_tier"),
                     "cost": it.get("cost"), "matches": m, "wins": s.get("wins"),
                     "win_rate": round((s.get("wins") or 0) / m, 4), "players": s.get("players"),
                     "avg_buy_time_s": round(s.get("avg_buy_time_s") or 0, 1),
                     "avg_sell_time_s": round(s.get("avg_sell_time_s") or 0, 1),
                     "source_type": env.get("source_type"), "provenance": provenance(env)})
    rows.sort(key=lambda r: (str(r["slot"]), r["tier"] or 0, -r["win_rate"]))
    return rows


def norm_game_stats(env) -> list[dict]:
    d = env.get("data")
    d = d[0] if isinstance(d, list) and d else (d or {})
    return [{"key": k, "value": v, "source_type": env.get("source_type"), "provenance": provenance(env)}
            for k, v in d.items() if isinstance(v, (int, float))]


def norm_patches(env) -> list[dict]:
    return [{"date": (p.get("pub_date") or "")[:10], "title": p.get("title"), "link": p.get("link"),
             "feed": p.get("source"), "source_type": "official", "provenance": provenance(env)}
            for p in env.get("data", []) if isinstance(p, dict)]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--limit", type=int, default=None, help="only first N rows per table")
    args = ap.parse_args(argv)
    ensure_dirs()
    cv = latest_client_version()
    heroes, items = latest_cache("heroes"), latest_cache("items")
    missing = []
    if heroes and items:
        write_csv("heroes.csv", norm_heroes(heroes, items, cv), args.limit)
        write_csv("abilities.csv", norm_abilities(heroes, items, cv), args.limit)
    else:
        missing.append("heroes/items")
    if items:
        write_csv("items.csv", norm_items(items, cv), args.limit)
    for name, fn, fname in [("npc_units", norm_npcs, "npc_units.csv"),
                            ("generic_data", norm_economy, "economy.csv")]:
        env = latest_cache(name)
        if env:
            write_csv(fname, fn(env, cv), args.limit)
        else:
            missing.append(name)
    env = latest_cache("hero_stats")
    if env:
        write_csv("analytics_hero_stats.csv", norm_hero_stats(env, heroes), args.limit)
    env = latest_cache("item_stats")
    if env:
        write_csv("analytics_item_stats.csv", norm_item_stats(env, items), args.limit)
    env = latest_cache("game_stats")
    if env:
        write_csv("analytics_game_stats.csv", norm_game_stats(env), args.limit)
    env = latest_cache("patches")
    if env:
        write_csv("patches.csv", norm_patches(env), args.limit)
    if missing:
        print("missing in cache (run fetch.py):", missing)
    print(f"game client_version used: {cv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
