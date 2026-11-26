# 0011 — `grafana/grafana`, every image pinned

**Status:** in force. **Source:** D-31, D-11.

**Context.** `grafana/grafana-oss` stopped receiving updates; floating tags
(`latest`, `13`) change under you.

**Decision.** `grafana/grafana:13.2.5`; every image pinned by exact tag **and**
digest in this repository; updates are deliberate commits.

**Consequences.** Reproducible deployments; updates must be done by hand
(Grafana's own update checks are off). Pinned versions are listed in
[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).
