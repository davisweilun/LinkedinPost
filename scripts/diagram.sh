#!/usr/bin/env bash
# Render a Mermaid diagram to PNG via Kroki (free hosted renderer; POST = no encoding).
# Usage:
#   bash scripts/diagram.sh <output.png> <input.mmd>
#   ... or pipe the mermaid source on stdin:  bash scripts/diagram.sh <output.png>
# Override the service with KROKI_URL (e.g. a self-hosted instance).
set -euo pipefail
out="${1:?usage: diagram.sh <output.png> [input.mmd]   (mermaid on stdin)}"
src="${2:-}"
KROKI="${KROKI_URL:-https://kroki.io}"

if [[ -n "$src" ]]; then
  curl -fsS -X POST "${KROKI}/mermaid/png" -H "Content-Type: text/plain" --data-binary "@$src" -o "$out"
else
  curl -fsS -X POST "${KROKI}/mermaid/png" -H "Content-Type: text/plain" --data-binary @- -o "$out"
fi
echo "[diagram] $out"

# Alternative — mermaid.ink (GET, base64-encoded source):
#   b64="$(python3 -c 'import base64,sys; print(base64.urlsafe_b64encode(open(sys.argv[1],"rb").read()).decode())' "$src")"
#   curl -fsS "https://mermaid.ink/img/${b64}" -o "$out"
