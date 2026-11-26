#!/bin/sh
# Archive the persistent volumes of a monitoring deployment, read-only.
#
#   scripts/backup-volumes.sh <compose-project> [destination-folder]
#   scripts/backup-volumes.sh msi-monitor ~/backups
#
# What it archives: <project>_prometheus-data (metric history) and
# <project>_grafana-data (Grafana's database: users, preferences) and, if the
# Garmin module is installed, <project>_influxdb-data and <project>_garmin-tokens.
# textfile-gen is NOT archived: it is a 1 MB tmpfs in RAM, rewritten within
# seconds of every start.
#
# How: one short-lived container per volume mounts it READ-ONLY (:ro) and
# writes a .tar.gz plus a .sha256 to the destination. The container has no
# network. Nothing is changed in the volumes.
#
# Consistency: Prometheus' write-ahead log and Grafana's SQLite file can be
# caught half-written while the services run. The script therefore refuses
# while any running container uses one of the volumes, and prints the command
# to stop the stack first (and to start it again afterwards). The archive of
# garmin-tokens contains account session tokens: keep it as private as the
# .env file (the script sets mode 600 on every archive).
set -eu

IMAGE="busybox:1.37.0@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"

project=${1:-}
dest=${2:-"$HOME/backups"}
[ -n "$project" ] || { echo "usage: $0 <compose-project> [destination-folder]" >&2; exit 2; }

umask 077
mkdir -p "$dest"
dest=$(CDPATH='' cd -- "$dest" && pwd)
stamp=$(date -u +%Y%m%dT%H%M%SZ)

volumes=""
for key in prometheus-data grafana-data influxdb-data garmin-tokens; do
  v="${project}_${key}"
  if docker volume inspect "$v" >/dev/null 2>&1; then
    volumes="$volumes $v"
  fi
done
[ -n "$volumes" ] || { echo "no volumes found for project '$project'" >&2; exit 1; }

busy=0
for v in $volumes; do
  users=$(docker ps --filter "volume=$v" --format '{{.Names}}')
  if [ -n "$users" ]; then
    echo "volume $v is in use by running container(s): $users" >&2
    busy=1
  fi
done
if [ "$busy" -ne 0 ]; then
  echo "Stop the stack first, for example:" >&2
  echo "  docker compose -p $project stop" >&2
  echo "then run this script again, and finally:  docker compose -p $project start" >&2
  exit 1
fi

for v in $volumes; do
  out="$v-$stamp.tar.gz"
  # tar runs as root inside the container (the files belong to the services'
  # users), then hands the archive to you with mode 600.
  docker run --rm --network none \
    -v "$v:/data:ro" -v "$dest:/backup" \
    "$IMAGE" sh -c 'tar czf "/backup/$1" -C /data . && chown "$2" "/backup/$1" && chmod 600 "/backup/$1"' \
    _ "$out" "$(id -u):$(id -g)"
  ( cd "$dest" && sha256sum "$out" >"$out.sha256" && chmod 600 "$out.sha256" )
  echo "archived $v -> $dest/$out ($(du -h "$dest/$out" | cut -f1))"
done
echo "Restore (not automatic): see docs/runbook/15-backups.md."
