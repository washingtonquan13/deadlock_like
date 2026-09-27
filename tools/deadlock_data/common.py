"""Shared helpers for the clean-room Deadlock reference-data toolkit.

Only talks to documented PUBLIC web APIs (see specs/_data_sources.md).
Never reads, unpacks or parses Deadlock game files, memory or network traffic.
"""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:  # optional dependency
    import requests  # type: ignore
except Exception:  # pragma: no cover
    requests = None

TOOL_DIR = Path(__file__).resolve().parent
PROJECT_DIR = TOOL_DIR.parents[1]
CACHE_DIR = TOOL_DIR / "cache"
DATA_DIR = PROJECT_DIR / "data"
REF_DIR = DATA_DIR / "reference"
REPORT_DIR = DATA_DIR / "reports"
GODOT_REF_DIR = DATA_DIR / "reference_godot"

USER_AGENT = (
    "deadlock_like-cleanroom-refdata/0.1 "
    "(indie game-design research; low-volume, cached; python)"
)

# Politeness: deadlock-api analytics limit is 200 req/min per IP (shared across
# analytics endpoints). We stay far below: at most 1 request / 1.0 s overall.
MIN_INTERVAL_S = float(os.environ.get("DL_MIN_INTERVAL_S", "1.0"))
_last_request_ts = 0.0


def utc_now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def _throttle() -> None:
    global _last_request_ts
    wait = MIN_INTERVAL_S - (time.monotonic() - _last_request_ts)
    if wait > 0:
        time.sleep(wait)
    _last_request_ts = time.monotonic()


def http_get_json(url: str, params: dict | None = None, timeout: int = 120,
                  retries: int = 4) -> tuple[int, dict, object]:
    """GET a JSON document. Returns (status, headers, parsed_json).

    Honors 429/503 with Retry-After or exponential backoff.
    """
    if params:
        clean = {k: v for k, v in params.items() if v is not None}
        if clean:
            url = url + ("&" if "?" in url else "?") + urllib.parse.urlencode(clean, doseq=True)
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    backoff = 2.0
    last_err: Exception | None = None
    for attempt in range(retries + 1):
        _throttle()
        try:
            if requests is not None:
                r = requests.get(url, headers=headers, timeout=timeout)
                status, hdrs, body = r.status_code, dict(r.headers), r.content
            else:
                req = urllib.request.Request(url, headers=headers)
                try:
                    with urllib.request.urlopen(req, timeout=timeout) as resp:
                        status, hdrs, body = resp.status, dict(resp.headers), resp.read()
                except urllib.error.HTTPError as e:
                    status, hdrs, body = e.code, dict(e.headers or {}), e.read()
            if status in (429, 502, 503, 504):
                ra = hdrs.get("Retry-After") or hdrs.get("retry-after")
                delay = float(ra) if ra and str(ra).replace(".", "").isdigit() else backoff
                print(f"  [{status}] backing off {delay:.1f}s ({url})", file=sys.stderr)
                time.sleep(delay)
                backoff *= 2
                continue
            if status >= 400:
                raise RuntimeError(f"HTTP {status} for {url}: {body[:200]!r}")
            return status, hdrs, json.loads(body)
        except (urllib.error.URLError, TimeoutError, ConnectionError, json.JSONDecodeError) as e:
            last_err = e
            time.sleep(backoff)
            backoff *= 2
    raise RuntimeError(f"GET failed after retries: {url}: {last_err}")


def cache_path(name: str, url: str, params: dict | None) -> Path:
    key = hashlib.sha1((url + json.dumps(params or {}, sort_keys=True)).encode()).hexdigest()[:10]
    return CACHE_DIR / f"{name}__{key}.json"


def load_cached(path: Path, max_age_hours: float | None):
    if not path.exists():
        return None
    try:
        env = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    if max_age_hours is None:
        return env
    ts = _dt.datetime.fromisoformat(env["retrieved_at"])
    age_h = (_dt.datetime.now(_dt.timezone.utc) - ts).total_seconds() / 3600
    return env if age_h <= max_age_hours else None


def latest_cache(name: str) -> dict | None:
    """Return the most recently retrieved cache envelope for a dataset name."""
    best = None
    for p in CACHE_DIR.glob(f"{name}__*.json"):
        try:
            env = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        if best is None or env.get("retrieved_at", "") > best.get("retrieved_at", ""):
            best = env
    return best


def provenance(env: dict) -> str:
    cv = env.get("client_version") or ("latest" if env.get("source_type") == "community-datamine" else "n/a")
    return (f"{env.get('source_name')}|{env.get('source_url')}|retrieved={env.get('retrieved_at','')[:10]}"
            f"|client_version={cv}|source_type={env.get('source_type')}")


def ensure_dirs() -> None:
    for d in (CACHE_DIR, REF_DIR, REPORT_DIR, GODOT_REF_DIR):
        d.mkdir(parents=True, exist_ok=True)


def to_float(v):
    """Parse numbers the API returns as strings like '20m', '6', '-1.0', '{s:sign}5'."""
    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip()
    for suf in ("m", "s", "%"):
        if s.endswith(suf):
            s = s[: -len(suf)]
    try:
        return float(s)
    except ValueError:
        return None


# Engine distance unit -> metres. Inferred: weapon falloff start 708.661 units
# is shown in-game/wiki as 18 m -> 1 unit = 0.0254 m (inch). source_type=inferred.
UNITS_TO_M = 0.0254
