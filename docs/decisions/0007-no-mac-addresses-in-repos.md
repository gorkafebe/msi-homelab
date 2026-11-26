# 0007 — MAC addresses never in a repository

**Status:** in force. **Source:** D-27.

**Context.** Reserving fixed IPs in the router needs the interfaces' MAC
addresses. A MAC address identifies the hardware for good.

**Decision.** MAC addresses (and serial numbers, host-key fingerprints, Wi-Fi
names) are kept only in private notes, never in a repository.

**Consequences.** `scripts/audit-public.sh` fails on any MAC address and on the
values of a local, ignored denylist.
