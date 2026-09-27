# deadlock_data: clean-room reference-data toolkit

This toolkit pulls **public** Deadlock statistics from documented community APIs and turns them into CSVs, design reports, and a reference JSON for Godot. We use them to sanity-check our own game's tuning, and they should stay a sanity check only.

> Reference only. Our game uses its own values in `data/` (outside `data/reference*`). Nothing this toolkit produces may be shipped or loaded by gameplay code.

## Clean-room rules

1. Use only the sources rated OK in `specs/_data_sources.md`. Today that means deadlock-api.com's REST API (MIT, attribution), Steam `ISteamNews` (official patch notes), and deadlock.wiki (CC BY-NC-SA, facts only; when its Cloudflare check blocks us we skip it and do not bypass it).
2. We never download, unpack, or parse game files (VPK, KV3), decompile anything, or read memory or network traffic. Some values in the assets API were extracted from game files by deadlock-api.com. We cite those as `community-datamine` facts, and the extraction was theirs.
3. Record numbers and names only. `normalize.py` drops lore, descriptions, and images on purpose.
4. We use aggregate analytics only. The toolkit never calls per-player endpoints.
5. Every CSV row has `source_type` and `provenance` columns: source name, URL, retrieval date, and game client version.
6. Be polite to the APIs. Requests are spaced at least 1 s apart (set `DL_MIN_INTERVAL_S` to change it; the limit is 200/min on analytics). The client sends an identifying User-Agent, backs off on 429/5xx, and caches responses for 12 h by default.

## Setup

Python 3.10 or newer. There are no required dependencies. `requests` is used if installed, and the tools fall back to `urllib` otherwise.

```
cd tools/deadlock_data
pip install -r requirements.txt   # optional
```

## Usage

```
python fetch.py --list                      # show datasets
python fetch.py all                         # assets + analytics + patch notes (about 10 requests)
python fetch.py assets --client-version 6701  # pin a game build
python fetch.py analytics --days 14 --min-badge 90   # high-rank last 14 days
python fetch.py wiki --wiki-pages "Souls,Troopers"   # raw wikitext (may be blocked by Cloudflare)
python fetch.py all --force                 # ignore cache

python normalize.py                         # -> data/reference/*.csv
python normalize.py --limit 5               # smoke test

python analyze.py                           # -> data/reports/*.md
python analyze.py calc --hero Haze --hp 1500 --dist 25 --hs 0.3 --bonus 0.2 --armor 0.1

python export_godot.py --split             # -> data/reference_godot/*.json
```

Raw responses are stored in `cache/<dataset>__<hash>.json` as an envelope. The envelope holds `source_url`, `retrieved_at`, `params`, `client_version`, the rate-limit headers, and `data`, the untouched JSON. When the schema changes, rerun `normalize.py`. If a field has moved, fix it there. The raw data is never lost.

## Outputs

| File | Content |
|---|---|
| `data/reference/heroes.csv` | Base stats (`base_*`), per-level growth (`perlvl_*`), shop-slot bonuses (`shopbonus_*`), and weapon (`wpn_*`, falloff ranges also given in metres) |
| `data/reference/abilities.csv` | The 4 signature abilities per hero: cooldown, range, charges, T1–T3 upgrade deltas, and `key_properties_json` |
| `data/reference/items.csv` | Shop items: slot, tier, cost, active/passive, and numeric properties |
| `data/reference/npc_units.csv` | Troopers, guardians, walkers, neutrals: HP, speeds, DPS, and bounty |
| `data/reference/economy.csv` | Tier prices, kill-share fractions, objective bounties, Rejuvenator (rejuv) parameters |
| `data/reference/analytics_*.csv` | Hero win and pick rates with averages; item win rate and buy time; match-level averages |
| `data/reference/patches.csv` | Official patch titles, dates, and links |
| `data/reports/item_efficiency.md` | Shop structure and stat-per-1000-souls by tier |
| `data/reports/hero_base_stats.md` | Distributions (min, median, max, stdev) and a per-hero summary |
| `data/reports/weapon_ttk.md` | Fire-rate model checked against the API, falloff table, and TTK grids |
| `data/reports/winrate_vs_cost.md` | Item win rate against cost and tier (with a survivorship caveat), and hero win rates |
| `data/reports/economy.md` | Soul income by source, and match averages |
| `data/reference_godot/deadlock_reference.json` | Everything above, keyed by `class_name` or id, with `_meta.reference_only = true` |

`.gdignore` files keep Godot from importing the CSVs, which it would otherwise treat as translations, and the tool folder. If Godot ever picks up `data/reference_godot/`, exclude it in your export presets.

## Units and models

- Engine distance: 1 unit = 0.0254 m. This is inferred, not published. Verify it with recipe R0 in `specs/_measurement_protocol.md`.
- The weapon model in `analyze.py` (`Weapon`) is our own. Falloff lerps between the start and end range with a Source-style bias curve. The headshot multiplier comes from `crit_bonus_start`/`crit_bonus_end`. Burst weapons add a cooldown after each burst. The model's fire rate matches the API's `shots_per_second` for every weapon except the ones flagged "(!)" in the report.

## Attribution

Reference statistics come from deadlock-api.com (MIT) and the Deadlock Wiki (CC BY-NC-SA 4.0, facts only). Deadlock is a trademark of Valve Corporation, and this project is not affiliated with Valve.
