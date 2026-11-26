#!/bin/sh
# Crop a PNG (for reviewing long screenshots in parts, or for the README),
# with the Chromium inside the pinned Playwright image: it opens a local page
# that shows the image shifted by (X, Y) in a WIDTH x HEIGHT window and saves
# a screenshot. No network.
#
#   scripts/crop-image.sh in.png out.png WIDTH HEIGHT X Y
set -eu

IMAGE="mcr.microsoft.com/playwright:v1.64.1-noble@sha256:2f05f8a734509a7b3f26a912639488ee08f58a7b292d14d62271bcff9038768f"
CHROME=/ms-playwright/chromium-1248/chrome-linux64/chrome
[ $# -eq 6 ] || { echo "usage: $0 in.png out.png WIDTH HEIGHT X Y" >&2; exit 2; }
in=$(CDPATH='' cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
outdir=$(CDPATH='' cd -- "$(dirname -- "$2")" && pwd)
name=$(basename -- "$2")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$in" "$work/in.png"
printf '<!doctype html><html><body style="margin:0;overflow:hidden;background:#111">
<img src="in.png" style="position:absolute;left:-%spx;top:-%spx"></body></html>\n' "$5" "$6" >"$work/crop.html"
chmod -R a+rX "$work"

docker run --rm --network none --user "$(id -u):$(id -g)" -e HOME=/tmp --cap-drop ALL --tmpfs /tmp \
  -v "$work:/work:ro" -v "$outdir:/out" "$IMAGE" \
  "$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size="$3,$4" \
    --allow-file-access-from-files --screenshot="/out/$name" file:///work/crop.html >/dev/null 2>&1
echo "$outdir/$name"
