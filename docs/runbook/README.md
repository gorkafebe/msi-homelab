# Runbook: an MSI gaming laptop as a headless Ubuntu server

How the server under this repository was installed and configured, step by
step, so it can be rebuilt from a blank disk. The laptop was chosen to host a
personal audio web app: a recent CPU, 16 GB of RAM and a single 512 GB NVMe
drive that could hold the recordings; that app is not part of this repository.

Every page has the same parts: **Goal**, **Requirements**, **Steps**,
**Verify**, **Undo** and a **Status** line. Commands starting with `sudo`
change the system. `<user>`, `<hostname>`, `<server-ip>` and other `<...>`
are placeholders: put your own values on the machine, never in a repository.

## Status labels

| Label | Meaning |
|---|---|
| **verified** | done, and the check was run and gave the expected output (date given) |
| **done but not verified** | done, but the check was not run, or not in all conditions |
| **planned** | written down, not done |
| **to confirm** | an open question; the page says what would settle it |

Dates refer to the original setup in November 2026 (Ubuntu Server 24.04.5 LTS).

## Pages

| # | Page | Status |
|---|---|---|
| 00 | [Hardware and choice of OS](00-hardware.md) | verified |
| 01 | [Installer USB, boot menu and installer choices](01-install.md) | done but not verified (no check beyond a working system) |
| 02 | [Disk: the 98 GB LVM root and how to give it the whole disk](02-disk-lvm.md) | verified |
| 03 | [Network: cable plus Wi-Fi with netplan](03-network-wifi.md) | verified |
| 04 | [SSH with keys only](04-ssh.md) | verified |
| 05 | [Headless: lid, sleep, console, temperatures](05-headless.md) | verified (BIOS options: to confirm) |
| 06 | [Time zone](06-time-zone.md) | verified (one loose end: to confirm) |
| 07 | [Docker Engine and Compose from Docker's repository](07-docker.md) | verified |
| 08 | [Firewall and the Docker/ufw problem](08-firewall-docker.md) | procedure |
| 09 | [Battery charge limit with msi-ec](09-battery-limit.md) | verified (cold boot: not verified) |
| 10 | [Secure Boot and the Machine Owner Key](10-secure-boot-mok.md) | verified |
| 11 | [The NVIDIA GPU: leave it off](11-gpu-power.md) | verified |
| 12 | [Tailscale: private access to the panel](12-tailscale.md) | procedure |
| 13 | [Monitoring panel (stacks/monitoring)](13-monitoring.md) | verified on the original deployment; this repository's copy: not started for real |
| 14 | [Garmin module](14-garmin.md) | planned (demo verified) |
| 15 | [Backups](15-backups.md) | planned |
| 16 | [Reboot, cold-boot and on-battery tests](16-reboot-tests.md) | planned |

Why each choice was made, with the alternatives: [docs/decisions/](../decisions/).
What went wrong on the way: [docs/lessons.md](../lessons.md).
