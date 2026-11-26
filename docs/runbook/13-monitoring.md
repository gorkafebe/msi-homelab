# 13 — Monitoring panel (stacks/monitoring)

**Status:** the original deployment runs and was verified (2026-11-02 to
2026-11-05: all services healthy, Prometheus growing about 15.5 MB per day).
This repository's copy: `docker compose config` verified with `.env.example`
for every profile; **not started for real** (it uses the same host ports as
the running panel).

## Goal

Charts of the server's health — power and GPU state, temperatures and fans,
battery, disk, network, CPU and memory, updates and backups — kept 30 days,
reachable only from this machine or the tailnet.

## What runs

| Service | Listens on | Notes |
|---|---|---|
| node-exporter | 127.0.0.1:9100 | host metrics; reads `*.prom` files (textfile collector) |
| node-exporter-rapl | 127.0.0.1:9101 | CPU energy counters only; root **without** capabilities, sees only `/sys` |
| textfile-gen | — | every 15 s: GPU power state, fans, charge limits, throttling, updates |
| prometheus | 127.0.0.1:9090 | scrape every 15 s; keeps 30 days, at most 10 GB |
| grafana | 127.0.0.1:3000 | dashboard "MSI health" in folder "Server (MSI)" |
| price-fetch *(profile `pvpc`)* | — | Spanish regulated electricity price from a public API |
| blackbox-exporter *(profile `apphealth`)* | 127.0.0.1:9115 | GET the health URLs of a web app on this machine |

All of them use the host network and bind to `127.0.0.1` with their own flag;
there is no `ports:` (see [page 08](08-firewall-docker.md)). Each has a memory
limit and a health check; the extra containers run unprivileged, read-only and
without capabilities. Design: [ARCHITECTURE.md](../ARCHITECTURE.md).

## First-time setup (a new machine)

```sh
scripts/init-env.sh                       # .env with a random Grafana admin password (never printed)
cd stacks/monitoring
docker compose -p <project> --env-file ../../.env up -d
docker compose -p <project> ps            # all healthy after ~1 minute
```

Optional services: set `COMPOSE_PROFILES=pvpc,apphealth` in `.env`; for
`apphealth`, copy `prometheus/targets/apphealth.yml.example` to
`apphealth.yml` and list the URLs (the file is ignored by git).

## Moving an existing deployment here without losing history

Docker names a project's volumes `<project>_<key>`. This file keeps the
original keys (`prometheus-data`, `grafana-data`, `textfile-gen`), so running
it **under the same project name** reuses the existing volumes: Compose only
recreates the containers ([decision 0024](../decisions/0024-adopt-existing-volumes.md)).

1. Back up the two persistent volumes (stops nothing by itself; it refuses
   while they are in use):

   ```sh
   docker compose -p <project> stop
   scripts/backup-volumes.sh <project> ~/backups
   ```

2. Copy the old `.env` next to `.env.example` and let `scripts/init-env.sh` add
   any missing keys (it never changes existing ones, so the Grafana password in
   the volume still matches). Copy the host textfile folder
   (`experiments.*`) into `stacks/monitoring/textfile/` or point
   `TEXTFILE_HOST_DIR` at it.
3. Start from this repository under the same name:

   ```sh
   cd stacks/monitoring
   docker compose -p <project> --env-file ../../.env up -d
   ```

4. Check: `docker compose -p <project> ps`, the dashboard still shows the days
   before the move, `ss -tlnp` shows only `127.0.0.1` listeners.

**Roll back:** `docker compose -p <project> -f <old folder>/compose.yaml up -d`
— the same volumes, the old configuration.

Visible effects of the move: the `instance` label becomes `msi`, so for up to
30 days some legends show the old and the new name side by side; the app-health
legend shows URL paths; backup metrics are named `homelab_backup_*`.

## Everyday commands (from stacks/monitoring)

| What | Command |
|---|---|
| Status | `docker compose -p <project> ps` |
| Logs | `docker compose -p <project> logs -f grafana` |
| Mark an experiment on every chart | `bin/mark-experiment "what I changed"` |
| Restart Grafana after editing a dashboard JSON | `docker compose -p <project> restart grafana` |

## Verify

```sh
docker compose -p <project> ps                                    # every service (healthy)
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq '.data.result[].value[1]'   # all "1"
curl -s http://127.0.0.1:3000/api/health                          # "database": "ok"
ss -tlnp | grep -E ':(3000|9090|9100|9101|9115)\b'                 # 127.0.0.1 only
curl -s 127.0.0.1:9100/metrics | grep '^node_textfile_scrape_error'   # 0
```

## Undo

`docker compose -p <project> down` stops everything and **keeps** the history.
`down -v` would delete the volumes — all history and Grafana's database.
