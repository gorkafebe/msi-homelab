"""price-fetch: Spanish electricity price (PVPC) for the dashboard.

Source: Red Eléctrica's public REData API, no token needed:
  https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real
It returns the hourly PVPC (the regulated consumer price, energy term, taxes
not included) and the 15-minute spot market price, in EUR/MWh.

Privacy: the only thing sent is an HTTPS GET with the dates; no data about the
machine. TLS certificates are verified (Python's default context).

Every LOOP_SECONDS the current price is recomputed from the cached day; the API
is asked again every FETCH_SECONDS, or sooner if the cache lacks the current
hour. The result is written atomically to OUT for node_exporter's textfile
collector. Standard library only.
"""

import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone

API = "https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real"
OUT = os.environ.get("OUT", "/out/price.prom")
LOOP_SECONDS = int(os.environ.get("LOOP_SECONDS", "60"))
FETCH_SECONDS = int(os.environ.get("FETCH_SECONDS", "900"))
TIMEOUT = 20
USER_AGENT = "msi-monitor-price-fetch/1.0"

# Series type in the API answer -> (label, length of one price period).
SERIES = {"PVPC": ("pvpc", timedelta(hours=1)), "Precio mercado spot": ("spot", timedelta(minutes=15))}


def build_url(now_utc):
    """Ask for yesterday..tomorrow so the current hour is always included."""
    start = (now_utc - timedelta(days=1)).strftime("%Y-%m-%dT00:00")
    end = (now_utc + timedelta(days=1)).strftime("%Y-%m-%dT23:59")
    return f"{API}?start_date={start}&end_date={end}&time_trunc=hour"


def parse(payload):
    """Return {"pvpc": [(start_datetime, eur_per_mwh), ...], "spot": [...]}."""
    out = {}
    for item in payload.get("included", []):
        label = SERIES.get(item.get("type"))
        if not label:
            continue
        points = []
        for v in item.get("attributes", {}).get("values", []):
            try:
                points.append((datetime.fromisoformat(v["datetime"]), float(v["value"])))
            except (KeyError, TypeError, ValueError):
                continue
        out[label[0]] = sorted(points)
    return out


def current(points, length, now_utc):
    """The (start, price) whose period contains now, or None."""
    for start, price in points:
        if start <= now_utc < start + length:
            return start, price
    return None


def today_stats(points, now_utc):
    """Min, mean and max of the prices whose period starts on now's local day."""
    if not points:
        return None
    tz = points[0][0].tzinfo
    day = now_utc.astimezone(tz).date()
    vals = [p for s, p in points if s.astimezone(tz).date() == day]
    if not vals:
        return None
    return min(vals), sum(vals) / len(vals), max(vals)


def render(data, now_utc, last_success, fetch_ok):
    lines = []

    def metric(name, kind, help_text, samples):
        lines.append(f"# HELP {name} {help_text}")
        lines.append(f"# TYPE {name} {kind}")
        for labels, value in samples:
            lines.append(f"{name}{labels} {value}")

    price, start, stats = [], [], []
    for label, length in SERIES.values():
        cur = current(data.get(label, []), length, now_utc)
        if cur:
            price.append((f'{{source="{label}"}}', f"{cur[1] / 1000:.5f}"))
            start.append((f'{{source="{label}"}}', f"{cur[0].timestamp():.0f}"))
        st = today_stats(data.get(label, []), now_utc)
        if st:
            for stat, v in zip(("min", "mean", "max"), st):
                stats.append((f'{{source="{label}",stat="{stat}"}}', f"{v / 1000:.5f}"))
    if price:
        metric("msi_electricity_price_eur_per_kwh", "gauge",
               "Electricity price now in EUR/kWh (REE REData; pvpc = regulated consumer price, energy term without taxes; spot = wholesale).",
               price)
        metric("msi_electricity_price_period_start_timestamp_seconds", "gauge",
               "Start of the price period the current price belongs to (Unix time).", start)
    if stats:
        metric("msi_electricity_price_today_eur_per_kwh", "gauge",
               "Today's (Spain) min, mean and max price in EUR/kWh.", stats)
    metric("msi_electricity_price_fetch_success", "gauge",
           "1 if the last request to the REE API succeeded.", [("", 1 if fetch_ok else 0)])
    metric("msi_electricity_price_last_success_timestamp_seconds", "gauge",
           "When the REE API last answered correctly (Unix time, 0 = never).", [("", f"{last_success:.0f}")])
    return "\n".join(lines) + "\n"


def write_atomic(path, text):
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def fetch(now_utc):
    req = urllib.request.Request(build_url(now_utc), headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return parse(json.load(resp))


def main():
    data, last_fetch, last_success, fetch_ok = {}, 0.0, 0.0, False
    once = "--once" in sys.argv
    while True:
        now = datetime.now(timezone.utc)
        missing = current(data.get("pvpc", []), SERIES["PVPC"][1], now) is None
        if missing or time.time() - last_fetch >= FETCH_SECONDS:
            last_fetch = time.time()
            try:
                new = fetch(now)
                if new.get("pvpc"):
                    data, last_success, fetch_ok = new, time.time(), True
                else:
                    fetch_ok = False
                    print("price-fetch: answer without PVPC series", file=sys.stderr, flush=True)
            except Exception as exc:  # network, TLS, JSON: keep the cache, report failure
                fetch_ok = False
                print(f"price-fetch: request failed: {exc}", file=sys.stderr, flush=True)
        write_atomic(OUT, render(data, now, last_success, fetch_ok))
        if once:
            return 0 if fetch_ok else 1
        time.sleep(LOOP_SECONDS)


if __name__ == "__main__":
    sys.exit(main())
