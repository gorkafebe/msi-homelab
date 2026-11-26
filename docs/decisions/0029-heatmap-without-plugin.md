# 0029 — Built-in heatmap instead of a downloaded plugin

**Status:** in force.

**Context.** Two upstream panels use `marcusolsson-hourly-heatmap-panel`
(2.0.1, 2022), which Grafana would download at start-up; the real Grafana has
plugin downloads disabled and its compatibility with Grafana 13.2.5 was not
verified.

**Decision.** `scripts/vendor-dashboard.py` turns those two panels into
Grafana's built-in heatmap (X = day, Y = buckets of the hourly value, colour =
hours in the bucket). The upstream file stays unchanged in `vendor/`. The same
script removes the three map panels (external map tiles) and the donation
panel (external image).

**Consequences.** No plugin, no external content in the browser. The view
differs from upstream (no hour-of-day axis); each panel's description says so.
