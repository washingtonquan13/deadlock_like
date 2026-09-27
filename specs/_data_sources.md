# Public Deadlock data sources: legality review

_Researched 2026-09-27. The latest game build that deadlock-api.com lists is client version **6701**; the latest official patch notes are dated **2026-09-16**. Re-check this file after every major Valve update._

## Clean-room position (read this first)

- We **never** download, unpack, or parse Deadlock game files (VPK, vdata, KV3). We do not decompile anything, and we do not read game memory, network traffic, or the local Steam cache.
- Some third parties extract values from the game files themselves and **publish** the results, for example deadlock-api.com's `/v1/assets/*`. We may **cite those published facts**. They are always tagged `source_type=community-datamine`, and the extraction is theirs, not ours. Numbers and game-mechanic facts are not copyrightable expression. We do copy text: no lore, no ability descriptions, no voice lines, no art, no icons.
- The toolkit reads only **aggregate** analytics. It never calls the per-player endpoints (match history, profiles, Steam names, MMR). Collecting data on individuals is outside our design needs, and it creates privacy obligations we do not want.
- Everything we pull is reference data for design. Our Godot game ships **our own tuned values** in `data/`. Anything under `data/reference*` must not be shipped.

## Summary table

| # | Source | What it has | Auth | Rate limit | Terms / licence | Verdict |
|---|---|---|---|---|---|---|
| 1 | **deadlock-api.com REST API** `https://api.deadlock-api.com` (OpenAPI at `/openapi.json`, docs at `/docs`) | Assets for every patch: heroes, items/abilities/weapons, NPC units, generic economy data, client versions, ranks. Analytics: hero, item, game, build, synergy, counter, lane and soul-curve stats. Patch-notes feed. | None for GET. An optional API key raises limits. | Analytics endpoints share **200 req/min per IP**, 400/min per key and 2000/min globally (documented per endpoint). The `/v1/info` and `/v1/patches` pages document 100 req/s per IP. Responses include `ratelimit-*` headers. item-stats responses are cached for 6 h on the server. | Open source under the **MIT** licence (github.com/deadlock-api/deadlock-api). The site says it gives "free access to all data" including dumps. I found no ToS page that forbids use. Their disclaimer says the project is not endorsed by Valve. `robots.txt` has `Disallow: /`, which covers crawlers; `/docs` and `/openapi.json` are allowed. We use it as a documented API client at low volume, not as a crawler. | **OK-with-attribution.** Credit "Data: deadlock-api.com". Tag asset values `community-datamine` and analytics `community-measurement`. |
| 2 | deadlock-api.com **data dumps / DuckLake / MCP** (`https://data.deadlock-api.com/v1/manifest.json`, `https://api.deadlock-api.com/v1/mcp`) | Hourly Parquet snapshots of their database, readable through DuckDB or MCP | None ("read-only, free, needs no account") | n/a | Same project and licence as row 1 | **OK-with-attribution** for aggregate work. The dumps contain per-player rows, so aggregate them and never republish account-level data. The toolkit does not use the dumps yet because the API aggregates are enough. |
| 3 | deadlock-api **write/ingest endpoints** (`/v1/matches/salts` POST, `/v1/matches/custom/*`, `/v1/patron/*`) and the **deadlock-api-ingest** desktop tool | Match-salt ingestion; automated custom-lobby creation | Key or Steam login | n/a | The ingest tool reads the local game cache or traffic | **Avoid.** It touches the game client and data about other players, which breaks our clean-room rules. |
| 4 | **Steam Web API: ISteamNews/GetNewsForApp** (`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1422450`) | Official patch notes and announcements (Deadlock appid **1422450**) | This endpoint needs no key | The Steam Web API Terms cap usage at **100,000 calls/day** | Steam Web API Terms of Use (https://steamcommunity.com/dev/apiterms). Do not imply Valve endorses the project. Only retrieve user data when that user asks for it (we retrieve none). | **OK-with-attribution** for patch dates and titles. Official text is Valve's copyright: link and paraphrase it, do not copy it. |
| 5 | Steam Web API: player counts and achievements for 1422450 | `GetNumberOfCurrentPlayers` returned **404** and `GetGlobalAchievementPercentagesForApp` returned **403** on 2026-09-27. Deadlock has no public stats schema. | - | - | - | **Not available.** Valve publishes no official Deadlock match or stat API. |
| 6 | **Official forum changelog** (`https://forums.playdeadlock.com/forums/changelog.10/index.rss`), also mirrored by deadlock-api `/v2/patches` | Authoritative patch notes, with dates | None | Be polite (RSS) | Valve content | **OK** as the primary source for change *facts*. Paraphrase and link. |
| 7 | **The Deadlock Wiki** (`https://deadlock.wiki`, MediaWiki 1.46 API at `/api.php`) | Hero, item and mechanic pages; console commands; patch history | None | Standard MediaWiki etiquette: `maxlag=5`, one request at a time, and a User-Agent that identifies us | Content licence **CC BY-NC-SA 4.0** (from the `siteinfo` rightsinfo field) | **OK-with-attribution, facts only.** Numbers and mechanics are facts. Copying prose, tables verbatim, or images would pull in NonCommercial and ShareAlike obligations that do not fit a possibly commercial game, so paraphrase instead. **Operational note:** the first API call on 2026-09-27 returned 200. Later calls returned a **Cloudflare "Just a moment" bot challenge (403)**. We do **not** bypass bot protection, so when the challenge appears `fetch.py wiki` skips the source and you look pages up manually in a browser. |
| 8 | **Statlocker** (statlocker.gg) | Player and match tracker; hero and item stats | Account for some features | - | No ToS page found at `/terms`, `/tos` or `/terms-of-service` (all 404). `robots.txt` disallows `/api/`. | **Avoid automated access.** Manual browsing to cross-check is fine. Cite as `community-measurement`. |
| 9 | **tracklock.gg** | Tracker; hero win and pick rates | - | - | No public API docs or ToS found (404) | **Avoid automated access.** Manual cross-checks only. |
| 10 | **Mobalytics** (mobalytics.gg/deadlock) | Guides and tier lists | - | - | ToS page blocked automated fetch (403) | **Avoid automated access.** Tier lists are opinion, not data. |
| 11 | **deadlocktracker.gg / tracker.gg/deadlock** | Trackers | - | - | tracker.gg answers bots with 403. Its developer API does not document Deadlock. | **Avoid automated access.** |
| 12 | **YouTube / Reddit measurement posts** (r/DeadlockTheGame) | Community tests of movement, TTK, mechanics | - | - | Platform ToS | **OK** as cited `community-measurement` facts. Record the URL and the patch, and re-measure anything important ourselves (see `_measurement_protocol.md`). |
| 13 | **Our own measurements** in private lobbies, sandbox, or bot matches | Anything you can observe in the game | - | - | Normal gameplay. Cheats only where the game allows them (private or sandbox). | **OK** (`source_type=community-measurement` with our own name, or `inferred`). |

## Endpoints the toolkit actually uses (tested 2026-09-27)

| Dataset | URL | Records fetched | source_type |
|---|---|---|---|
| client_versions | `/v1/assets/client-versions` | 815 (latest 6701) | community-datamine |
| heroes | `/v1/assets/heroes?only_active=true` | 38 | community-datamine |
| items (abilities, weapons, upgrades) | `/v1/assets/items` | 726 (389 abilities, 251 upgrades, 86 weapons; 173 of the upgrades are shopable) | community-datamine |
| npc_units | `/v1/assets/npc-units` | 58 | community-datamine |
| generic_data | `/v1/assets/generic-data` | 20 top-level keys | community-datamine |
| hero_stats | `/v1/analytics/hero-stats` (last 30 days, `game_mode=normal`) | 38 | community-measurement |
| item_stats | `/v1/analytics/item-stats` (last 30 days, `min_matches=500`) | 156 | community-measurement |
| game_stats | `/v1/analytics/game-stats` (last 30 days) | 1 aggregate row covering about 1.28M matches | community-measurement |
| patches | `/v2/patches` | 30 | official (mirrored) |
| steam_news | Steam `GetNewsForApp` appid 1422450 | 20 | official |
| wiki | `deadlock.wiki/api.php?action=parse` | 0, Cloudflare challenge (see row 7) | wiki |

Note: `assets.deadlock-api.com`, the older host, **no longer resolves** (DNS failure on 2026-09-27). Assets now live under `api.deadlock-api.com/v1/assets/*`, and images come from `assets-bucket.deadlock-api.com`, which we do not download.

## Sample facts retrieved (spot-check of the pipeline)

| Fact | Value | Units | Source URL | source_type | Patch/date | Confidence |
|---|---|---|---|---|---|---|
| Analytics rate limit per IP | 200 | req/min | https://api.deadlock-api.com/openapi.json (hero-stats description) | official (API docs) | 2026-09-27 | high |
| Shop tier prices | 800 / 1600 / 3200 / 6400 / 9999 (T1–T5) | souls | https://api.deadlock-api.com/v1/assets/generic-data (`item_price_per_tier`) | community-datamine | build 6701, 2026-09-27 | high |
| Hero base max health (min / median / max) | 660 / 780 / 930 | HP | https://api.deadlock-api.com/v1/assets/heroes | community-datamine | build 6701 | high |
| Hero base move speed (min / median / max) | 6.2 / 6.9 / 8.2 | m/s (the field is labelled meters; in-game display) | same | community-datamine | build 6701 | medium (units inferred) |
| Ground dash distance / duration | 10 / ~0.68 (0.62–0.72) | m / s | same | community-datamine | build 6701 | high |
| Air dash distance | 8 | m | same | community-datamine | build 6701 | high |
| Stamina charges (min / median / max) | 2 / 3 / 4 | charges | same | community-datamine | build 6701 | high |
| Max hero level / souls to reach it | 36 / 48,600 | level / souls | same (`level_info`) | community-datamine | build 6701 | high |
| Headshot multiplier (every hero at base) | 1.65 | × | same (`weapon_info.crit_bonus_start`) | community-datamine | build 6701 | medium (how it is applied is inferred) |
| Distance unit | 1 engine unit = 0.0254 m | m | falloff start 708.661 units maps to 18 m | inferred | - | medium |
| Lane trooper HP / melee damage | 300 / 50 | HP / dmg | https://api.deadlock-api.com/v1/assets/npc-units (`trooper_normal`) | community-datamine | build 6701 | high |
| Tier 1 guardian HP | 5500 | HP | same (`npc_boss_tier1`) | community-datamine | build 6701 | high |
| Medium neutral: HP / souls | 322 / 68 (+1.08%/min) | HP / souls | same (`neutral_trooper_normal`) | community-datamine | build 6701 | high |
| Average match duration | 38.4 | min | https://api.deadlock-api.com/v1/analytics/game-stats | community-measurement | 2026-08-28 to 2026-09-27 | high |
| Average end net worth per player | ~44,245 | souls | same | community-measurement | same window | high |

The full, fresh tables are in `data/reference/*.csv`. Every row has a `provenance` column.

## Attribution line to use in credits and docs

> Reference statistics from deadlock-api.com (MIT) and the Deadlock Wiki (CC BY-NC-SA 4.0, facts only). Deadlock is a trademark of Valve Corporation. This project is not affiliated with or endorsed by Valve.

## Sources consulted

- https://deadlock-api.com and https://deadlock-api.com/data-privacy and https://deadlock-api.com/data-dumps
- https://api.deadlock-api.com/openapi.json and https://api.deadlock-api.com/robots.txt
- https://github.com/deadlock-api/deadlock-api (licence field: MIT, via the GitHub API)
- https://steamcommunity.com/dev/apiterms
- https://deadlock.wiki/api.php?action=query&meta=siteinfo&siprop=rightsinfo
- https://statlocker.gg/robots.txt, tracklock.gg, mobalytics.gg, tracker.gg (the ToS probes are summarised above)
