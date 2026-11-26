# 0017 — Grafana keeps its login; alerts designed, not enabled

**Status:** in force. **Source:** D-71, D-72.

**Decision.** Grafana keeps an admin login (no anonymous access, no sign-up)
even inside the tailnet; its password is generated, never chosen or shown
(`scripts/init-env.sh`). Alerts are written as a design only; nothing notifies
anyone yet.

**Why.** A tailnet device can be lost; a second lock is cheap. Alerts need a
channel and thresholds that have not been decided.

**Consequences.** Somebody has to look at the panel. Only the throwaway demo
Grafana allows anonymous, read-only viewing.
