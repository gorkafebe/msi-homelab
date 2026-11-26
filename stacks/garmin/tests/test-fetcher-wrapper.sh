#!/bin/sh
# Offline tests of the garmin-fetch wrapper (stacks/garmin/fetcher/wrapper.sh).
#
#   stacks/garmin/tests/test-fetcher-wrapper.sh      (make garmin-test)
#
# Nothing here can reach Garmin or any other machine:
#   * a throwaway InfluxDB runs with --network none (only a loopback interface);
#   * the fetcher shares THAT network namespace (--network container:...), so
#     it sees InfluxDB on 127.0.0.1 and has no route, no DNS and no other
#     interface; the script prints the interfaces and routes to prove it;
#   * no Docker volume is created: tokens live in a temporary folder, InfluxDB
#     data in a tmpfs. Every container is removed at the end.
#
# Cases (all must end in HOLD, with the process idle and no loop):
#   1. no token file;
#   2. a structurally valid but FAKE token file (the upstream code tries the
#      session, cannot resolve Garmin's name, falls back to asking for an
#      e-mail, gets end-of-file and exits; the wrapper writes the hold marker);
#   3. restart of the container from case 2 (simulated reboot): holds at once
#      because of the marker, without starting the fetcher again;
#   4. restart of the container from case 1: holds again.
#
# ok() and ko() always succeed, so "test && ok || ko" is a safe if/else here.
# shellcheck disable=SC2015
set -eu

IMAGE=${IMAGE:-msi-homelab/garmin-fetch:2e9ecadb}
INFLUX_IMAGE="influxdb:1.11.8@sha256:300a2bb2fd9d66c476c4bd7ca3ce6135d485151cce19b605ef7ab2a000fa1845"
P=msi-verify-garmin-test
WAIT=${WAIT:-25}
work=$(mktemp -d)
pw=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
fails=0

cleanup() {
  docker rm -f "$P-influx" "$P-notokens" "$P-faketokens" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT INT TERM

ok() { printf 'PASS %s\n' "$*"; }
ko() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }

holding() { docker exec "$1" sh -c 'test -f /tmp/hold-reason'; }
python_running() {
  # Any process whose command line runs the upstream fetcher?
  docker exec "$1" sh -c 'for c in /proc/[0-9]*/cmdline; do tr "\0" " " <"$c"; echo; done' \
    | grep -q 'garmin_fetch.py'
}
count_log() { docker logs "$1" 2>&1 | grep -c -e "$2" || true; }

echo "== throwaway InfluxDB, --network none"
docker run -d --name "$P-influx" --network none --tmpfs /var/lib/influxdb:uid=1500,gid=1500 \
  -e INFLUXDB_HTTP_BIND_ADDRESS=127.0.0.1:18086 -e INFLUXDB_BIND_ADDRESS=127.0.0.1:18088 \
  -e INFLUXDB_HTTP_AUTH_ENABLED=true -e INFLUXDB_HTTP_LOG_ENABLED=false -e INFLUXDB_REPORTING_DISABLED=true \
  -e INFLUXDB_DB=GarminStats -e INFLUXDB_ADMIN_USER=admin -e INFLUXDB_ADMIN_PASSWORD="$pw" \
  -e INFLUXDB_WRITE_USER=garmin_writer -e INFLUXDB_WRITE_USER_PASSWORD="$pw" \
  "$INFLUX_IMAGE" >/dev/null
i=0; until docker exec "$P-influx" curl -sf -o /dev/null http://127.0.0.1:18086/ping 2>/dev/null; do
  i=$((i + 1)); [ "$i" -lt 60 ] || { echo "InfluxDB did not start"; exit 1; }; sleep 1; done
echo "network mode of InfluxDB: $(docker inspect -f '{{.HostConfig.NetworkMode}}' "$P-influx")"

run_fetcher() {
  # $1 = container name, $2 = token folder on the host
  docker run -d --name "$1" --network "container:$P-influx" \
    --user 1000:1000 --cap-drop ALL --read-only --security-opt no-new-privileges:true --tmpfs /tmp:size=16m \
    -v "$2:/home/appuser/.garminconnect" \
    -e INFLUXDB_HOST=127.0.0.1 -e INFLUXDB_PORT=18086 -e INFLUXDB_USERNAME=garmin_writer \
    -e INFLUXDB_PASSWORD="$pw" -e INFLUXDB_DATABASE=GarminStats \
    -e TOKEN_DIR=/home/appuser/.garminconnect -e USER_TIMEZONE=UTC \
    "$IMAGE" >/dev/null
}

mkdir -p "$work/none" "$work/fake"
chmod 700 "$work/none" "$work/fake"

echo "== case 1: no token file"
run_fetcher "$P-notokens" "$work/none"
echo "network mode of the fetcher: $(docker inspect -f '{{.HostConfig.NetworkMode}}' "$P-notokens")"
echo "interfaces seen by the fetcher: $(docker exec "$P-notokens" ls /sys/class/net | tr '\n' ' ')"
echo "routes seen by the fetcher (header only = none): $(docker exec "$P-notokens" cat /proc/net/route | wc -l) line(s)"
sleep "$WAIT"
holding "$P-notokens" && ok "1 holds" || ko "1 not holding"
python_running "$P-notokens" && ko "1 fetcher process running" || ok "1 fetcher never started"
[ "$(count_log "$P-notokens" 'starting the fetcher')" -eq 0 ] && ok "1 no start in log" || ko "1 started"

echo "== case 2: fake (structurally valid) token file"
# Fake JWT-looking strings with an expiry far in the future; not real tokens.
fake_jwt="eyJhbGciOiJub25lIn0.$(printf '{"exp":4102444800,"client_id":"FAKE"}' | base64 | tr -d '=\n' | tr '/+' '_-').fake"
printf '{"di_token": "%s", "di_refresh_token": "fake-refresh", "di_client_id": "FAKE_CLIENT"}\n' "$fake_jwt" \
  >"$work/fake/garmin_tokens.json"
chmod 600 "$work/fake/garmin_tokens.json"
run_fetcher "$P-faketokens" "$work/fake"
sleep "$WAIT"
holding "$P-faketokens" && ok "2 holds" || ko "2 not holding"
[ -f "$work/fake/fetcher.hold" ] && ok "2 hold marker written: $(cat "$work/fake/fetcher.hold")" || ko "2 no marker"
python_running "$P-faketokens" && ko "2 fetcher still running" || ok "2 fetcher process gone"
starts=$(count_log "$P-faketokens" 'starting the fetcher')
[ "$starts" -eq 1 ] && ok "2 fetcher started exactly once" || ko "2 fetcher started $starts times"
echo "   evidence that no request left the namespace (name resolution failed):"
docker logs "$P-faketokens" 2>&1 | grep -i -E 'resolve|Name or service|DNS|Temporary failure|getaddrinfo|ConnectionError|EOF' \
  | sed 's/^/     /' | head -6

echo "== case 3: restart of case 2 (simulated reboot)"
docker restart "$P-faketokens" >/dev/null
sleep "$WAIT"
holding "$P-faketokens" && ok "3 holds after restart" || ko "3 not holding"
starts=$(count_log "$P-faketokens" 'starting the fetcher')
[ "$starts" -eq 1 ] && ok "3 no new start after restart (total starts: $starts)" || ko "3 started again ($starts)"
[ "$(docker inspect -f '{{.RestartCount}}' "$P-faketokens")" -eq 0 ] && ok "3 Docker restart count 0" || ko "3 restart count"

echo "== case 4: restart of case 1"
docker restart "$P-notokens" >/dev/null
sleep "$WAIT"
holding "$P-notokens" && ok "4 holds after restart" || ko "4 not holding"
[ "$(count_log "$P-notokens" 'starting the fetcher')" -eq 0 ] && ok "4 never started" || ko "4 started"

echo "== logs (case 2 and 3)"
docker logs "$P-faketokens" 2>&1 | grep 'garmin-fetch-wrapper' | sed 's/^/   /'

if [ "$fails" -ne 0 ]; then echo "WRAPPER TESTS FAILED ($fails)"; exit 1; fi
echo "WRAPPER TESTS OK"
