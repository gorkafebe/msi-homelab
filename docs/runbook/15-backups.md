# 15 — Backups

**Status:** planned. Tools are ready (`scripts/backup-volumes.sh`, verified on
a test volume on 2026-11-26); **no backup device has been chosen and no real
backup or restore test has been done**.

## Goal

The SSD is not a backup. Follow 3-2-1: three copies, on two kinds of media,
one off-site — and a backup only counts once a **restore** has been tested
([decision 0025](../decisions/0025-backups-before-real-data.md)).

## What is worth backing up here

| Data | Where | Worth it? |
|---|---|---|
| Configuration | this git repository | yes — push it; `.env` separately and encrypted |
| Prometheus history | volume `<project>_prometheus-data` | low: 30 days of host metrics |
| Grafana database | volume `<project>_grafana-data` | low: dashboards and datasources are in git |
| Garmin data | volume `<project>_influxdb-data` | **yes**: personal health history (also re-downloadable, slowly) |
| Garmin session tokens | volume `<project>_garmin-tokens` | **no**: a fresh login is safer than a copied session |

## Steps (manual, today)

```sh
docker compose -p <project> stop
scripts/backup-volumes.sh <project> /path/to/backup/disk
docker compose -p <project> start
```

The archives are `.tar.gz` (mode 600) with a `.sha256`; check them with
`sha256sum -c *.sha256`. For anything leaving the machine, encrypt first
(planned: restic, which encrypts and deduplicates, in a container with a fixed
image tag).

## Restore (not tested)

```sh
docker compose -p <project> down                       # keeps volumes; restore into an EMPTY volume
docker volume create <project>_<key>
docker run --rm --network none -v <project>_<key>:/data -v /path/to/backup:/backup:ro \
  busybox:1.37.0 tar xzf /backup/<archive>.tar.gz -C /data
docker compose -p <project> up -d
```

## Verify

Planned: a monthly restore test into a throwaway project, and the dashboard's
"Last backup age" and "Last restore test age" panels fed by the backup job
(metrics `homelab_backup_last_success_timestamp_seconds`,
`homelab_backup_last_result`, `homelab_restore_test_last_success_timestamp_seconds`
written into the textfile folder).

## Undo

Delete the archives.
