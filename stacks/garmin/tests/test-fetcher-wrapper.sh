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
# The token folders are prepared by a network-less helper container that sets
# the owner to uid 1000 (the fetcher's user), so the result does not depend on
# the uid of whoever runs the tests (1000 on a laptop, 1001 on GitHub's
# runners). The helper also reads the marker and cleans up, for the same reason.
#
# Cases (all must end in HOLD, with the process idle and no loop):
#   1. no token file;
#   2. a structurally valid but FAKE token file (the upstream code tries the
#      session, cannot resolve Garmin's name, falls back to asking for an
#      e-mail, gets end-of-file and exits; the wrapper writes the hold marker);
#   3. restart of the container from case 2 (simulated reboot): holds at once
#      because of the marker, without starting the fetcher again;
#   4. restart of the container from case 1: holds again;
#   5. a token folder and file owned by another user (1001, modes 700/600):
#      what happened on GitHub's runners before the helper existed;
#   6. a token file with invalid content;
#   7. a readable folder with a token file the fetcher's user cannot read.
#
# ok() and ko() always succeed, so "test && ok || ko" is a safe if/else here.
# shellcheck disable=SC2015
set -eu

IMAGE=${IMAGE:-msi-homelab/garmin-fetch:2e9ecadb}
INFLUX_IMAGE="influxdb:1.11.8@sha256:300a2bb2fd9d66c476c4bd7ca3ce6135d485151cce19b605ef7ab2a000fa1845"
HELPER_IMAGE="busybox:1.37.0@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec"
P=msi-verify-garmin-test
WAIT=${WAIT:-25}
work=$(mktemp -d)
# 18 random bytes as hex. od reads exactly that many bytes, so there is no
# "tr | head" pipe whose writer gets SIGPIPE (ignored on some CI runners).
pw=$(od -An -N18 -tx1 /dev/urandom | tr -d ' \n')
fails=0

# Run a command as root in a network-less helper with $work mounted at /w.
helper() { docker run --rm -i --network none -v "$work:/w" "$HELPER_IMAGE" sh -c "$1"; }

cleanup() {
  docker rm -f "$P-influx" "$P-notokens" "$P-faketokens" "$P-unreadable" "$P-invalid" "$P-unreadfile" >/dev/null 2>&1 || true
  # Files belong to uid 1000/1001: remove them from inside the helper first.
  helper 'rm -rf /w/*' >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT INT TERM

ok() { printf 'PASS %s\n' "$*"; }
ko() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }

holding() { docker exec "$1" sh -c 'test -f /tmp/hold-reason'; }
hold_reason() { docker exec "$1" cat /tmp/hold-reason 2>/dev/null || true; }
python_running() {
  # Any process whose command line runs the upstream fetcher?
  docker exec "$1" sh -c 'for c in /proc/[0-9]*/cmdline; do tr "\0" " " <"$c"; echo; done' \
    | grep -q 'garmin_fetch.py'
}
count_log() { docker logs "$1" 2>&1 | grep -c -e "$2" || true; }

# make_tokens <folder> <owner uid> <file mode> : JSON from stdin -> /w/<folder>/garmin_tokens.json
make_tokens() {
  helper "mkdir -p /w/$1 && cat >/w/$1/garmin_tokens.json && chown -R $2:$2 /w/$1 && chmod 700 /w/$1 && chmod $3 /w/$1/garmin_tokens.json"
}

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
  # $1 = container name, $2 = token folder under $work
  docker run -d --name "$1" --network "container:$P-influx" \
    --user 1000:1000 --cap-drop ALL --read-only --security-opt no-new-privileges:true --tmpfs /tmp:size=16m \
    -v "$work/$2:/home/appuser/.garminconnect" \
    -e INFLUXDB_HOST=127.0.0.1 -e INFLUXDB_PORT=18086 -e INFLUXDB_USERNAME=garmin_writer \
    -e INFLUXDB_PASSWORD="$pw" -e INFLUXDB_DATABASE=GarminStats \
    -e TOKEN_DIR=/home/appuser/.garminconnect -e USER_TIMEZONE=UTC \
    "$IMAGE" >/dev/null
}

# Token folders, all prepared by the helper (owner 1000 unless the case says otherwise).
helper 'mkdir -p /w/none && chown 1000:1000 /w/none && chmod 700 /w/none'
# Fake JWT-looking strings with an expiry far in the future; not real tokens.
fake_jwt="eyJhbGciOiJub25lIn0.$(printf '{"exp":4102444800,"client_id":"FAKE"}' | base64 | tr -d '=\n' | tr '/+' '_-').fake"
fake_json=$(printf '{"di_token": "%s", "di_refresh_token": "fake-refresh", "di_client_id": "FAKE_CLIENT"}' "$fake_jwt")
printf '%s\n' "$fake_json" | make_tokens fake 1000 600
printf '%s\n' "$fake_json" | make_tokens unreadable 1001 600
printf '%s\n' '{"di_token": "", "note": "not a token file"}' | make_tokens invalid 1000 600
printf '%s\n' "$fake_json" | make_tokens unreadfile 1000 600
helper 'chown 1001:1001 /w/unreadfile/garmin_tokens.json'

echo "== cases 1, 2, 5, 6, 7 start together"
run_fetcher "$P-notokens" none
run_fetcher "$P-faketokens" fake
run_fetcher "$P-unreadable" unreadable
run_fetcher "$P-invalid" invalid
run_fetcher "$P-unreadfile" unreadfile
echo "network mode of the fetcher: $(docker inspect -f '{{.HostConfig.NetworkMode}}' "$P-notokens")"
echo "interfaces seen by the fetcher: $(docker exec "$P-notokens" ls /sys/class/net | tr '\n' ' ')"
echo "routes seen by the fetcher (header only = none): $(docker exec "$P-notokens" cat /proc/net/route | wc -l) line(s)"
sleep "$WAIT"

echo "== case 1: no token file"
holding "$P-notokens" && ok "1 holds" || ko "1 not holding"
hold_reason "$P-notokens" | grep -q '^no token file' && ok "1 reason: no token file" || ko "1 reason: $(hold_reason "$P-notokens")"
python_running "$P-notokens" && ko "1 fetcher process running" || ok "1 fetcher never started"
[ "$(count_log "$P-notokens" 'starting the fetcher')" -eq 0 ] && ok "1 no start in log" || ko "1 started"

echo "== case 2: fake (structurally valid) token file"
holding "$P-faketokens" && ok "2 holds" || ko "2 not holding"
marker=$(helper 'cat /w/fake/fetcher.hold 2>/dev/null' || true)
[ -n "$marker" ] && ok "2 hold marker written: $marker" || ko "2 no marker"
python_running "$P-faketokens" && ko "2 fetcher still running" || ok "2 fetcher process gone"
starts=$(count_log "$P-faketokens" 'starting the fetcher')
[ "$starts" -eq 1 ] && ok "2 fetcher started exactly once" || ko "2 fetcher started $starts times"
echo "   evidence that no request left the namespace (name resolution failed):"
docker logs "$P-faketokens" 2>&1 | grep -i -E 'resolve|Name or service|DNS|Temporary failure|getaddrinfo|ConnectionError|EOF' \
  | sed 's/^/     /' | head -6

echo "== case 5: token folder and file owned by uid 1001 (the CI situation)"
holding "$P-unreadable" && ok "5 holds" || ko "5 not holding"
hold_reason "$P-unreadable" | grep -q 'folder .* cannot be accessed' && ok "5 reason: $(hold_reason "$P-unreadable")" || ko "5 reason: $(hold_reason "$P-unreadable")"
[ "$(count_log "$P-unreadable" 'starting the fetcher')" -eq 0 ] && ok "5 never started" || ko "5 started"

echo "== case 6: token file with invalid content"
holding "$P-invalid" && ok "6 holds" || ko "6 not holding"
hold_reason "$P-invalid" | grep -q 'invalid content' && ok "6 reason: invalid content" || ko "6 reason: $(hold_reason "$P-invalid")"
[ "$(count_log "$P-invalid" 'starting the fetcher')" -eq 0 ] && ok "6 never started" || ko "6 started"

echo "== case 7: readable folder, token file owned by uid 1001 (mode 600)"
holding "$P-unreadfile" && ok "7 holds" || ko "7 not holding"
hold_reason "$P-unreadfile" | grep -q 'file .* cannot be read' && ok "7 reason: $(hold_reason "$P-unreadfile")" || ko "7 reason: $(hold_reason "$P-unreadfile")"
[ "$(count_log "$P-unreadfile" 'starting the fetcher')" -eq 0 ] && ok "7 never started" || ko "7 started"

echo "== cases 3 and 4: restarts (simulated reboot)"
docker restart "$P-faketokens" "$P-notokens" >/dev/null
sleep "$WAIT"
holding "$P-faketokens" && ok "3 holds after restart" || ko "3 not holding"
starts=$(count_log "$P-faketokens" 'starting the fetcher')
[ "$starts" -eq 1 ] && ok "3 no new start after restart (total starts: $starts)" || ko "3 started again ($starts)"
[ "$(docker inspect -f '{{.RestartCount}}' "$P-faketokens")" -eq 0 ] && ok "3 Docker restart count 0" || ko "3 restart count"
holding "$P-notokens" && ok "4 holds after restart" || ko "4 not holding"
[ "$(count_log "$P-notokens" 'starting the fetcher')" -eq 0 ] && ok "4 never started" || ko "4 started"

echo "== wrapper logs"
for c in notokens faketokens unreadable invalid unreadfile; do
  docker logs "$P-$c" 2>&1 | grep 'garmin-fetch-wrapper: HOLD' | sed "s/^/   [$c] /"
done

if [ "$fails" -ne 0 ]; then echo "WRAPPER TESTS FAILED ($fails)"; exit 1; fi
echo "WRAPPER TESTS OK"
