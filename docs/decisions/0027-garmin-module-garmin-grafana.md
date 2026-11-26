# 0027 — Optional Garmin module built on garmin-grafana

**Status:** in force.

**Context.** Garmin watch data (sleep, heart rate, activities) is more useful
next to the server's other charts, and should not leave the machine.

**Decision.** An optional compose file (`stacks/garmin/compose.garmin.yaml`)
on top of the monitoring stack: InfluxDB 1.11 with authentication on loopback,
and the fetcher of [garmin-grafana](https://github.com/arpanghosh8453/garmin-grafana)
(BSD-3-Clause) built from a pinned commit, unprivileged, read-only, memory
limited. Its dashboard is vendored unchanged and a script derives the local
copy. The upstream example's open ports, `latest` tags, unauthenticated
database and second Grafana are not used.

**Alternatives.** Garmin's official data export (safe for the account, but a
one-off ZIP, not continuous — documented as the alternative); garmin-givemydata
(AGPL-3.0, browser automation; only mentioned as a future option); writing a
fetcher from scratch.

**Consequences.** Unofficial access that may breach Garmin's terms of service
(said plainly in the README and [GARMIN.md](../GARMIN.md)). Without the file,
the panel is exactly as before.
