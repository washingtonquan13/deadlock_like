#!/usr/bin/env python3
"""Fetch PUBLIC Deadlock reference data into tools/deadlock_data/cache/.

Clean-room: only documented public web APIs are used (see specs/_data_sources.md).
Raw JSON is stored untouched inside an envelope with provenance metadata so that
schema changes never lose data; normalize.py does the (tolerant) parsing.

Examples:
  python fetch.py --list
  python fetch.py heroes items npc_units            # asset datasets
  python fetch.py analytics                         # hero/item/game stats, last 30 days
  python fetch.py all --max-age-hours 24            # everything, reuse fresh cache
  python fetch.py hero_stats --min-badge 90 --days 14
  python fetch.py wiki --wiki-pages "Abrams,Souls"  # raw wikitext (CC BY-NC-SA, facts only)
  python fetch.py heroes --client-version 6697      # pin a specific game build
"""
from __future__ import annotations

import argparse
import sys
import time
import urllib.parse

from common import (CACHE_DIR, cache_path, ensure_dirs, http_get_json, load_cached,
                    utc_now_iso)
import json

API = "https://api.deadlock-api.com"
DLAPI_NOTE = ("deadlock-api.com (MIT-licensed open-source project, not affiliated with Valve). "
              "Asset values are parsed by them from game data = community-datamine.")

# name -> spec. kind: 'asset' (versioned game data) | 'analytics' | 'official' | 'wiki'
SOURCES = {
    "client_versions": dict(url=f"{API}/v1/assets/client-versions", kind="asset",
                            source_type="community-datamine", note=DLAPI_NOTE),
    "heroes": dict(url=f"{API}/v1/assets/heroes", kind="asset", versioned=True,
                   params={"only_active": "true", "language": "english"},
                   source_type="community-datamine", note=DLAPI_NOTE),
    "items": dict(url=f"{API}/v1/assets/items", kind="asset", versioned=True,
                  params={"language": "english"},
                  source_type="community-datamine", note=DLAPI_NOTE),
    "npc_units": dict(url=f"{API}/v1/assets/npc-units", kind="asset", versioned=True,
                      source_type="community-datamine", note=DLAPI_NOTE),
    "generic_data": dict(url=f"{API}/v1/assets/generic-data", kind="asset", versioned=True,
                         source_type="community-datamine", note=DLAPI_NOTE),
    "patches": dict(url=f"{API}/v2/patches", kind="official",
                    source_type="official",
                    note="Mirror of the official forum changelog RSS + Steam news, via deadlock-api.com"),
    "steam_news": dict(url="https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/",
                       kind="official", params={"appid": 1422450, "count": 20, "maxlength": 400,
                                                "format": "json", "feeds": "steam_community_announcements"},
                       source_type="official",
                       note="Steam Web API (keyless news endpoint); Steam Web API Terms apply"),
    "hero_stats": dict(url=f"{API}/v1/analytics/hero-stats", kind="analytics",
                       source_type="community-measurement",
                       note="Aggregates of public match metadata computed by deadlock-api.com"),
    "item_stats": dict(url=f"{API}/v1/analytics/item-stats", kind="analytics",
                       source_type="community-measurement",
                       note="Aggregates of public match metadata computed by deadlock-api.com"),
    "game_stats": dict(url=f"{API}/v1/analytics/game-stats", kind="analytics",
                       source_type="community-measurement",
                       note="Aggregates of public match metadata computed by deadlock-api.com"),
}
GROUPS = {
    "assets": ["client_versions", "heroes", "items", "npc_units", "generic_data"],
    "analytics": ["hero_stats", "item_stats", "game_stats"],
    "official": ["patches", "steam_news"],
}
GROUPS["all"] = GROUPS["assets"] + GROUPS["analytics"] + GROUPS["official"]

WIKI_API = "https://deadlock.wiki/api.php"


def fetch_one(name: str, spec: dict, args) -> dict:
    params = dict(spec.get("params", {}))
    if spec.get("versioned") and args.client_version:
        params["client_version"] = args.client_version
    if spec["kind"] == "analytics":
        params["min_unix_timestamp"] = int(time.time()) - args.days * 86400
        if args.min_badge is not None:
            params["min_average_badge"] = args.min_badge
        if args.max_badge is not None:
            params["max_average_badge"] = args.max_badge
        if name == "item_stats":
            params["min_matches"] = args.min_matches
    # timestamps change every run; round to the day so cache keys are stable
    key_params = {k: (v // 86400 if k == "min_unix_timestamp" else v) for k, v in params.items()}
    path = cache_path(name, spec["url"], key_params)
    cached = load_cached(path, args.max_age_hours)
    if cached is not None and not args.force:
        print(f"  cache hit  {name:15s} -> {path.name}")
        return cached
    status, headers, data = http_get_json(spec["url"], params)
    full_url = spec["url"] + ("?" + urllib.parse.urlencode(params) if params else "")
    env = {
        "source_name": name,
        "source_url": full_url,
        "source_type": spec["source_type"],
        "source_note": spec["note"],
        "retrieved_at": utc_now_iso(),
        "http_status": status,
        "client_version": params.get("client_version"),
        "params": params,
        "rate_limit_headers": {k: v for k, v in headers.items() if "ratelimit" in k.lower()},
        "data": data,
    }
    path.write_text(json.dumps(env, ensure_ascii=False), encoding="utf-8")
    n = len(data) if isinstance(data, (list, dict)) else 1
    print(f"  fetched    {name:15s} -> {path.name} ({n} top-level records)")
    return env


def fetch_wiki(pages: list[str], args) -> None:
    """Raw wikitext of named pages. License CC BY-NC-SA 4.0: keep for FACT lookup only,
    never copy prose into the game. One page per request, maxlag honoured."""
    for title in pages:
        params = {"action": "parse", "page": title, "prop": "wikitext|revid",
                  "format": "json", "formatversion": 2, "maxlag": 5, "redirects": 1}
        path = cache_path("wiki_" + title.replace(" ", "_").replace("/", "_"), WIKI_API, params)
        if load_cached(path, args.max_age_hours) is not None and not args.force:
            print(f"  cache hit  wiki:{title}")
            continue
        status, _h, data = http_get_json(WIKI_API, params)
        env = {"source_name": f"wiki:{title}",
               "source_url": f"https://deadlock.wiki/{urllib.parse.quote(title.replace(' ', '_'))}",
               "source_type": "wiki",
               "source_note": "deadlock.wiki, CC BY-NC-SA 4.0 - facts only, attribute, do not copy prose",
               "retrieved_at": utc_now_iso(), "http_status": status, "params": params, "data": data}
        path.write_text(json.dumps(env, ensure_ascii=False), encoding="utf-8")
        print(f"  fetched    wiki:{title} (revid {data.get('parse', {}).get('revid')})")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("targets", nargs="*", default=["all"],
                    help="dataset names or groups (assets, analytics, official, all, wiki)")
    ap.add_argument("--list", action="store_true", help="list datasets and exit")
    ap.add_argument("--max-age-hours", type=float, default=12.0,
                    help="reuse cache younger than this (default 12)")
    ap.add_argument("--force", action="store_true", help="ignore cache")
    ap.add_argument("--client-version", type=int, default=None, help="pin game build for assets")
    ap.add_argument("--days", type=int, default=30, help="analytics window in days (default 30)")
    ap.add_argument("--min-badge", type=int, default=None, help="analytics: min average badge (e.g. 90)")
    ap.add_argument("--max-badge", type=int, default=None)
    ap.add_argument("--min-matches", type=int, default=500, help="item_stats: min matches per item")
    ap.add_argument("--wiki-pages", default="", help="comma list of wiki page titles for 'wiki'")
    args = ap.parse_args(argv)

    if args.list:
        for n, s in SOURCES.items():
            print(f"{n:16s} {s['kind']:10s} {s['source_type']:22s} {s['url']}")
        print("groups:", {k: v for k, v in GROUPS.items()})
        print("wiki   (use --wiki-pages)", WIKI_API)
        return 0

    ensure_dirs()
    names: list[str] = []
    for t in args.targets:
        if t == "wiki":
            continue
        names += GROUPS.get(t, [t])
    failures = []
    for n in dict.fromkeys(names):
        if n not in SOURCES:
            print(f"unknown dataset {n!r}; use --list", file=sys.stderr)
            failures.append(n)
            continue
        try:
            fetch_one(n, SOURCES[n], args)
        except Exception as e:  # keep going; document failure
            print(f"  FAILED     {n}: {e}", file=sys.stderr)
            failures.append(n)
    if "wiki" in args.targets:
        pages = [p.strip() for p in args.wiki_pages.split(",") if p.strip()]
        if not pages:
            print("wiki: pass --wiki-pages 'Title1,Title2'", file=sys.stderr)
        else:
            try:
                fetch_wiki(pages, args)
            except Exception as e:
                msg = str(e)
                if "403" in msg and "Just a moment" in msg:
                    msg = ("deadlock.wiki answered with a Cloudflare bot challenge (403). "
                           "We do NOT try to bypass bot protection - look the page up manually "
                           "in a browser and cite it instead.")
                print(f"  SKIPPED    wiki: {msg}", file=sys.stderr)
                failures.append("wiki")
    print(f"done. cache dir: {CACHE_DIR}  failures: {failures or 'none'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
