# 0009 — node_exporter + Prometheus + Grafana in Compose, own dashboard

**Status:** executed 2026-11-02. **Source:** D-28, D-29, D-32, D-35.

**Context.** The server needed a health panel (temperatures, battery, disk,
power) that one person can read at a glance.

**Decision.** node_exporter → Prometheus → Grafana, in Docker Compose, with a
compact dashboard written for this machine and kept as JSON in git.

**Alternatives.** Beszel, Netdata or Glances (lighter, less standard, harder to
extend); a native install (harder to undo); the community "Node Exporter Full"
dashboard (hundreds of panels, none about this laptop's battery or GPU).

**Consequences.** About 300 MiB of RAM for the three core programs (measured);
everything is plain files that can be diffed and rolled back; easy to extend
(exporters, the Garmin module).
