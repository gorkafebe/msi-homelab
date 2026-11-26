#!/usr/bin/env python3
"""Generate the local Garmin dashboard from the vendored upstream copy.

    python3 scripts/vendor-dashboard.py          # write stacks/garmin/dashboards/garmin-stats.json
    python3 scripts/vendor-dashboard.py --check  # exit 1 if the committed file is out of date (CI)

Input:  stacks/garmin/vendor/garmin-grafana/Garmin-Grafana-Dashboard.json
        (unchanged copy of garmin-grafana at a pinned commit, BSD-3-Clause)
Output: stacks/garmin/dashboards/garmin-stats.json

Changes, each one listed in THIRD_PARTY_NOTICES.md:
  1. Every datasource reference ${DS_GARMIN_STATS} -> the provisioned InfluxDB
     datasource uid (202 occurrences: 58 on panels, 144 on queries; any other count stops
     the script, so an upstream change cannot slip through silently).
  2. The export-only blocks __inputs and __requires are removed (they ask the
     importer to choose a datasource and list the heatmap plugin).
  3. The three geomap panels are removed: their base maps are tiles fetched by
     the browser from an external map service.
  4. The "Support Me!" text panel is removed: it loads an image from an
     external site. The author is credited in README.md and the notices.
  5. The two marcusolsson-hourly-heatmap-panel panels (a plugin that would
     have to be downloaded) become Grafana's built-in heatmap panel.
  6. Fixed uid, title and tags so provisioning is stable; id and version reset.

The output is deterministic: same input, same bytes (sorted keys are NOT used,
so the file stays diff-friendly against upstream).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "stacks/garmin/vendor/garmin-grafana/Garmin-Grafana-Dashboard.json"
DST = ROOT / "stacks/garmin/dashboards/garmin-stats.json"

DS_PLACEHOLDER = "${DS_GARMIN_STATS}"
DS_UID = "garmin-influxdb"
EXPECTED_DS_REFS = 202  # 58 panel-level + 144 query-level references
REMOVED_GEOMAP_IDS = {49, 50, 69}
REMOVED_TEXT_ID = 25
HEATMAP_PLUGIN = "marcusolsson-hourly-heatmap-panel"


def replace_datasource(node, counter):
    """Recursively replace the placeholder uid; count replacements."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "uid" and value == DS_PLACEHOLDER:
                node[key] = DS_UID
                counter[0] += 1
            else:
                replace_datasource(value, counter)
    elif isinstance(node, list):
        for item in node:
            replace_datasource(item, counter)
    elif isinstance(node, str) and DS_PLACEHOLDER in node:
        raise SystemExit(f"unexpected placeholder inside a string: {node[:80]!r}")


def native_heatmap(panel):
    """Built-in heatmap replacing the hourly-heatmap plugin panel.

    The plugin draws hour-of-day (Y) against day (X). The built-in panel has no
    hour-of-day axis for InfluxQL data, so the closest faithful view is used:
    X = day, Y = buckets of the hourly value, colour = how many hours of that
    day fell into each bucket. Same measurement and field as upstream.
    """
    target = dict(panel["targets"][0])
    target["rawQuery"] = False
    target.pop("query", None)
    target["groupBy"] = [{"params": ["1h"], "type": "time"}, {"params": ["none"], "type": "fill"}]
    is_sleep = target.get("measurement") == "SleepIntraday"
    y_buckets = {"mode": "size", "value": "1"} if is_sleep else {"mode": "count", "value": "12"}
    scheme = "Blues" if is_sleep else "Oranges"
    what = "sleep stage level" if is_sleep else "steps per hour"
    return {
        "type": "heatmap",
        "id": panel["id"],
        "title": panel["title"],
        "description": (
            f"Built-in heatmap (converted from the {HEATMAP_PLUGIN} panel of the upstream "
            f"dashboard). X: day. Y: {what}, hourly values grouped in buckets. "
            "Colour: number of hours of that day in each bucket."
        ),
        "datasource": {"type": "influxdb", "uid": DS_UID},
        "gridPos": panel["gridPos"],
        "targets": [target],
        "options": {
            "calculate": True,
            "calculation": {
                "xBuckets": {"mode": "size", "value": "1d"},
                "yBuckets": y_buckets,
            },
            "cellGap": 1,
            "color": {"mode": "scheme", "scheme": scheme, "steps": 64, "exponent": 0.5,
                      "fill": "dark-orange", "reverse": False, "scale": "exponential"},
            "exemplars": {"color": "rgba(255,0,255,0.7)"},
            "filterValues": {"le": 1e-9},
            "legend": {"show": True},
            "rowsFrame": {"layout": "auto"},
            "tooltip": {"mode": "single", "showColorScale": False, "yHistogram": False},
            "yAxis": {"axisPlacement": "left", "reverse": False},
        },
        "fieldConfig": {"defaults": {}, "overrides": []},
    }


def transform(dashboard):
    counter = [0]
    replace_datasource(dashboard, counter)
    if counter[0] != EXPECTED_DS_REFS:
        raise SystemExit(f"expected {EXPECTED_DS_REFS} datasource references, found {counter[0]}")

    dashboard.pop("__inputs", None)
    dashboard.pop("__requires", None)
    dashboard.pop("__elements", None)

    removed, converted = [], []

    def edit(panels):
        out = []
        for p in panels:
            if p.get("type") == "geomap" and p.get("id") in REMOVED_GEOMAP_IDS:
                removed.append(p["id"])
                continue
            if p.get("type") == "text" and p.get("id") == REMOVED_TEXT_ID:
                removed.append(p["id"])
                continue
            if p.get("type") == HEATMAP_PLUGIN:
                converted.append(p["id"])
                p = native_heatmap(p)
            if "panels" in p:
                p["panels"] = edit(p["panels"])
            out.append(p)
        return out

    dashboard["panels"] = edit(dashboard["panels"])
    if sorted(removed) != sorted(REMOVED_GEOMAP_IDS | {REMOVED_TEXT_ID}):
        raise SystemExit(f"removed panels {sorted(removed)} differ from the expected set")
    if sorted(converted) != [20, 27]:
        raise SystemExit(f"converted heatmaps {sorted(converted)} differ from [20, 27]")

    leftovers = json.dumps(dashboard)
    for needle in (DS_PLACEHOLDER, f'"{HEATMAP_PLUGIN}"', '"geomap"', "ko-fi"):
        if needle in leftovers:
            raise SystemExit(f"left over after transform: {needle}")

    dashboard["id"] = None
    dashboard["uid"] = "garmin-stats"
    dashboard["title"] = "Garmin Stats"
    dashboard["version"] = 1
    dashboard["tags"] = sorted(set(dashboard.get("tags", [])) | {"garmin", "garmin-grafana"})
    return dashboard


def render():
    dashboard = json.loads(SRC.read_text(encoding="utf-8"))
    return json.dumps(transform(dashboard), indent=2, ensure_ascii=False) + "\n"


def main(argv):
    text = render()
    if "--check" in argv:
        if not DST.exists() or DST.read_text(encoding="utf-8") != text:
            print(f"{DST.relative_to(ROOT)} is out of date: run scripts/vendor-dashboard.py", file=sys.stderr)
            return 1
        print("garmin dashboard up to date")
        return 0
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(text, encoding="utf-8")
    print(f"wrote {DST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
