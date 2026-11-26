#!/bin/sh
# Screenshots of the demo Grafana for review and for the README.
#
#   scripts/screenshots.sh [base-url] [output-folder]
#   scripts/screenshots.sh http://127.0.0.1:13300 .screenshots
#
# Uses the Chromium that ships inside the pinned Playwright image (no npm
# package, nothing installed on the host). The browser runs with --network
# host only to reach Grafana on 127.0.0.1; the dashboards it opens contain no
# external content (see THIRD_PARTY_NOTICES.md). It runs as the image's
# own user id, with no capabilities.
#
# Output: one PNG per view. Every image must be LOOKED AT before it goes to
# docs/images/: empty panels, absurd scales, cut text, and anything
# identifying (host names, addresses, network names, interface details).
# See docs/PUBLISH_CHECKLIST.md.
set -eu

IMAGE="mcr.microsoft.com/playwright:v1.64.1-noble@sha256:2f05f8a734509a7b3f26a912639488ee08f58a7b292d14d62271bcff9038768f"
CHROME=/ms-playwright/chromium-1248/chrome-linux64/chrome
base=${1:-http://127.0.0.1:13300}
out=${2:-.screenshots}
# Milliseconds of (virtual) time Chromium waits for Grafana to finish drawing.
BUDGET=${BUDGET:-20000}

mkdir -p "$out"
out=$(CDPATH='' cd -- "$out" && pwd)


shot() {
  # $1 = file name, $2 = path and query, $3 = width, $4 = height
  docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp --cap-drop ALL \
    --security-opt no-new-privileges:true --tmpfs /tmp \
    -v "$out:/out" "$IMAGE" \
    "$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
      --force-device-scale-factor=1 --window-size="$3,$4" \
      --virtual-time-budget="$BUDGET" --run-all-compositor-stages-before-draw \
      --screenshot="/out/$1" "$base$2" >/dev/null 2>&1
  echo "  $out/$1"
}

echo "screenshots from $base:"
q='orgId=1&kiosk&theme=dark'
# Garmin dashboard, whole page in several heights (it is long), last 7 days.
shot garmin-7d.png       "/d/garmin-stats/garmin-stats?$q&from=now-7d&to=now"   1600 9800
# Last 24 h: the intraday panels.
shot garmin-24h.png      "/d/garmin-stats/garmin-stats?$q&from=now-24h&to=now"  1600 2400
# A year: long-term trends.
shot garmin-1y.png       "/d/garmin-stats/garmin-stats?$q&from=now-1y&to=now"   1600 9800
# Server dashboard (reads the local Prometheus, if any), last 6 hours.
shot server-6h.png       "/d/msi-health/msi-health?$q&from=now-6h&to=now"       1600 7000
