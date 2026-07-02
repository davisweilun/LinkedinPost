#!/usr/bin/env bash
# Render an HTML file to a PNG using headless Chrome (or Chromium/Edge/Brave).
# Usage: bash scripts/render.sh <input.html> <output.png> [width] [height]
# Default size is 1080x1350 (LinkedIn 4:5 portrait).
set -euo pipefail
html="${1:?usage: render.sh <input.html> <output.png> [W H]}"
out="${2:?usage: render.sh <input.html> <output.png> [W H]}"
W="${3:-1080}"; H="${4:-1350}"

CHROME=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  "$(command -v google-chrome 2>/dev/null || true)" \
  "$(command -v chromium 2>/dev/null || true)"; do
  if [[ -n "$c" && -x "$c" ]]; then CHROME="$c"; break; fi
done
if [[ -z "$CHROME" ]]; then
  echo "render: no Chrome/Chromium/Edge/Brave found — install one to render cards." >&2
  exit 1
fi

abs="$(cd "$(dirname "$html")" && pwd)/$(basename "$html")"
out_abs="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"
"$CHROME" --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --force-device-scale-factor=2 --window-size="${W},${H}" \
  --screenshot="$out_abs" "file://${abs}" >/dev/null 2>&1
echo "[render] $out  (${W}x${H} @2x)"
