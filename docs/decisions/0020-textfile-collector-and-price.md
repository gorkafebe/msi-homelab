# 0020 — Extra metrics through text files; electricity price fetcher

**Status:** in force; the price fetcher is an optional profile (`pvpc`) in this
repository. **Source:** D-78, D-80.

**Decision.** Facts node_exporter does not export (GPU power state, fan speeds,
charge thresholds, throttling, pending updates) are written every 15 s by an
unprivileged busybox container into a 1 MB tmpfs that node_exporter reads
(textfile collector). Your own tools write into a host folder the same way
(experiment marks, backup status). The Spanish regulated electricity price
(PVPC) comes from the grid operator's public API every 15 minutes, from an
unprivileged container on the bridge network — the only core-stack container
that talks to the internet, sending only dates.

**Alternatives.** A custom exporter (a long-running HTTP service to maintain);
root scripts on the host.

**Consequences.** Simple shell and Python, ShellCheck-clean, no host changes.
Outside Spain the price panels say "No data" (profile off).
