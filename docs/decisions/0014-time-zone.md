# 0014 — Local time zone on the server

**Status:** executed 2026-11-03. **Source:** D-39 ("stay on UTC for now, change
planned"), carried out the next day.

**Context.** The server ran on UTC while the other machines used local time;
logs and commit times looked out of order.

**Decision.** `timedatectl set-timezone` to the local zone. Containers stay on
UTC; Grafana shows times in the browser's zone. Automated session logs keep
writing UTC explicitly (`date -u`).

**Consequences.** One loose end (`/etc/timezone`), see
[runbook 06](../runbook/06-time-zone.md).
