# 0019 — CPU energy via a second, capability-less root exporter

**Status:** in force. **Source:** D-77.

**Context.** The CPU energy counters (`/sys/class/powercap/intel-rapl*/energy_uj`)
are readable only by root since kernel 5.10 (PLATYPUS, CVE-2020-8694). The main
node_exporter runs unprivileged with the whole host filesystem mounted.

**Decision.** A second node_exporter that runs as root **without any
capability**, read-only, `no-new-privileges`, seeing only `/sys` (read-only),
with only the RAPL collector enabled, on 127.0.0.1:9101.

**Alternatives.** Run the main exporter as root (root with the whole disk
mounted); a udev rule that opens the files to everyone (undoes a security fix).

**Consequences.** No change on the host; a root process limited to reading `/sys`.
