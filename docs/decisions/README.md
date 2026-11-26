# Decisions

One short page per decision: **context, decision, alternatives, consequences,
status**. Pages 0001–0023 are translated (and shortened) from the decision log
of the private project this server was built for; each says which entry it
comes from (`D-xx`) and keeps that entry's status. Pages 0024 and later were
made for this repository.

Statuses: **in force**, **executed** (a one-off action that was done),
**planned**, **superseded by …**, **under review**.

| # | Decision | Status |
|---|---|---|
| [0001](0001-ubuntu-server-lts.md) | Ubuntu Server 24.04 LTS on the laptop; stay on 24.04 for now | executed; review |
| [0002](0002-no-disk-encryption.md) | No full-disk encryption | in force |
| [0003](0003-keep-lvm-and-extend.md) | Keep LVM and extend the root volume | executed |
| [0004](0004-wifi-own-netplan-file.md) | Wi-Fi in its own netplan file; the cable is primary | in force |
| [0005](0005-ssh-keys-only.md) | SSH with keys only, no root login | in force |
| [0006](0006-headless-laptop.md) | Ignore the lid, never sleep, blank the console | in force |
| [0007](0007-no-mac-addresses-in-repos.md) | MAC addresses never in a repository | in force |
| [0008](0008-docker-from-official-repo.md) | Docker from Docker's apt repository | in force |
| [0009](0009-monitoring-stack.md) | node_exporter + Prometheus + Grafana in Compose, own dashboard | executed |
| [0010](0010-host-network-loopback.md) | Host networking, everything on 127.0.0.1 | in force |
| [0011](0011-pinned-images.md) | `grafana/grafana`, every image pinned | in force |
| [0012](0012-prometheus-retention.md) | Prometheus: 30 days, 10 GB cap | in force |
| [0013](0013-battery-limit-msi-ec.md) | Battery limit 60 % with msi-ec, Secure Boot kept | in force |
| [0014](0014-time-zone.md) | Local time zone on the server | executed |
| [0015](0015-power-saving-no-proprietary-driver.md) | Power saving by measured steps; no proprietary NVIDIA driver; GPU left as is | in force (steps planned) |
| [0016](0016-panel-only-inside-tailscale.md) | Panel only inside Tailscale (`serve`, never `funnel`), HTTP on 3000 | in force |
| [0017](0017-grafana-login-alerts-design-only.md) | Grafana keeps its login; alerts designed, not enabled | in force |
| [0018](0018-read-only-check-scripts.md) | Host checks are read-only, sudo-free scripts | in force |
| [0019](0019-rapl-capless-root-exporter.md) | CPU energy via a second, capability-less root exporter | in force |
| [0020](0020-textfile-collector-and-price.md) | Extra metrics through text files; electricity price fetcher | in force (price optional here) |
| [0021](0021-power-total-is-a-model.md) | The power total is a model, not a measurement | in force |
| [0022](0022-app-health-probe.md) | App health with blackbox_exporter, GET only, ≥ 30 s | in force (optional here) |
| [0023](0023-explicit-compose-project-name.md) | The Compose project name is never implicit | in force |
| [0024](0024-adopt-existing-volumes.md) | The repository adopts the running panel's volumes | in force |
| [0025](0025-backups-before-real-data.md) | Backups ready before real data; a restore test decides | planned |
| [0026](0026-single-grafana-two-folders.md) | One Grafana, two folders, same port | in force |
| [0027](0027-garmin-module-garmin-grafana.md) | Optional Garmin module built on garmin-grafana | in force |
| [0028](0028-garmin-login-tokens-only.md) | Garmin: tokens only, one manual login with a newer library | in force |
| [0029](0029-heatmap-without-plugin.md) | Built-in heatmap instead of a downloaded plugin | in force |
| [0030](0030-new-public-history.md) | A new public repository with its own history | executed |
