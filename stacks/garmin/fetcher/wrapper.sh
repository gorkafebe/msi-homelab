#!/bin/sh
# Entry point of the garmin-fetch container: runs the upstream fetcher only
# when it can work WITHOUT a password, and never lets a failure turn into a
# loop of login attempts.
#
# Rules (docs/GARMIN.md, "Why the fetcher never retries a login"):
#   1. No usable token file  -> HOLD (no network traffic at all).
#   2. A hold marker exists  -> HOLD (a previous run failed; a human decides).
#   3. Otherwise run the fetcher with stdin closed and no credentials in the
#      environment. If it ever exits, write the hold marker and HOLD.
#
# HOLD = log one line, then sleep forever. The container keeps running, so
# Docker's restart policy never starts a new attempt; the health check reports
# "unhealthy" while holding. A restart of the container (or of the machine)
# comes back to rule 1 or 2 and holds again.
#
# To release a hold: fix the cause, do a new first login if needed
# (docs/GARMIN.md), delete the marker, restart the container.
set -u

TOKEN_DIR=${TOKEN_DIR:-/home/appuser/.garminconnect}
TOKEN_FILE="$TOKEN_DIR/garmin_tokens.json"
MARKER="$TOKEN_DIR/fetcher.hold"
STATE=/tmp/hold-reason

log() { printf '%s garmin-fetch-wrapper: %s\n' "$(date -u +%FT%TZ)" "$*"; }

hold() {
  log "HOLD: $1"
  log "no further attempts will be made; see docs/GARMIN.md to release the hold"
  printf '%s\n' "$1" >"$STATE"
  # sleep in a loop of long naps rather than 'sleep infinity', so the
  # container still stops promptly on SIGTERM (trap below).
  trap 'exit 0' TERM INT
  while :; do sleep 3600 & wait $!; done
}

rm -f "$STATE"

# Credentials must never reach the fetcher: drop them even if someone added
# them to the environment by mistake (the upstream code would use them).
unset GARMINCONNECT_EMAIL GARMINCONNECT_BASE64_PASSWORD GARMINTOKENS

# Every check below only looks at local files; a failing one holds without any
# network traffic. The messages say which case it is, never what the file holds.
# Folder first: if this user cannot enter it, neither the marker nor the token
# file can be seen, and "missing" would be a misleading answer.
if [ ! -d "$TOKEN_DIR" ] || [ ! -x "$TOKEN_DIR" ]; then
  hold "token folder $TOKEN_DIR cannot be accessed by uid $(id -u) (permissions; it must belong to 1000)"
fi

if [ -e "$MARKER" ]; then
  hold "marker $MARKER present (a previous run stopped)"
fi

if [ ! -e "$TOKEN_FILE" ]; then
  hold "no token file at $TOKEN_FILE (do the first login once: docs/GARMIN.md)"
fi
if [ ! -r "$TOKEN_FILE" ]; then
  hold "token file $TOKEN_FILE cannot be read by uid $(id -u) (permissions; it must belong to 1000, mode 600)"
fi

# The token file must parse and hold a DI access token, a refresh token and
# the client id. Checked locally with Python; nothing is printed from the file.
if ! python -I -c '
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(1)
ok = isinstance(data, dict) and all(isinstance(data.get(k), str) and data.get(k) for k in ("di_token", "di_refresh_token", "di_client_id"))
sys.exit(0 if ok else 1)
' "$TOKEN_FILE" 2>/dev/null; then
  hold "token file $TOKEN_FILE has invalid content (not JSON with di_token, di_refresh_token and di_client_id; do the first login again: docs/GARMIN.md)"
fi

log "token file present; starting the fetcher (stdin closed, no credentials in the environment)"
python garmin_grafana/garmin_fetch.py </dev/null
rc=$?

# Any exit means something the fetcher could not handle by itself (expired or
# refused session, unexpected error). Never start again automatically.
umask 077
printf 'stopped=%s exit_code=%s\n' "$(date -u +%FT%TZ)" "$rc" >"$MARKER" 2>/dev/null \
  || log "could not write $MARKER (read-only?)"
hold "fetcher exited with code $rc"
