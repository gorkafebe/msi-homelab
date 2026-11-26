# 0012 — Prometheus: 30 days, 10 GB cap

**Status:** in force. **Source:** D-33.

**Context.** A monitor must never fill the disk it watches.

**Decision.** `--storage.tsdb.retention.time=30d` and
`--storage.tsdb.retention.size=10GB`; whichever is reached first wins.

**Consequences.** Measured growth about 15.5 MB per day (2026-11-03), so 30
days is about 0.5 GB (extrapolation); the 10 GB cap is a safety net. Long-term
trends of the host are not kept; Garmin data lives in InfluxDB without this limit.
