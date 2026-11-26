# 0010 — Host networking, everything on 127.0.0.1

**Status:** in force. **Source:** D-30 (and the principle of D-15).

**Context.** Ports published by Docker bypass ufw
([runbook 08](../runbook/08-firewall-docker.md)). node_exporter needs the host's
real network interfaces anyway.

**Decision.** Every service uses `network_mode: host` and binds to
`127.0.0.1` with its own setting; no `ports:` anywhere. Exceptions are
explicit: the price fetcher (bridge, outbound only) and the one-shot Garmin
login container (bridge, outbound only).

**Alternatives.** `ports: 127.0.0.1:…` on bridge networks (works; but the
exporters must reach host loopback, which bridge containers cannot).

**Consequences.** Nothing is reachable from the LAN by mistake; the
containers are not isolated from each other at network level — acceptable for
official images and documented in [SECURITY.md](../SECURITY.md).
