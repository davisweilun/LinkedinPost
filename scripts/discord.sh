#!/usr/bin/env bash
# Discord notification wrapper. Posts a message to a Discord channel via webhook.
# Usage: bash scripts/discord.sh "<message>"   (or pipe the message on stdin)
# Reads DISCORD_WEBHOOK_URL from .env; if unset, prints a notice and exits 0 (no-op).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$ROOT/.env" ]] && { set -a; source "$ROOT/.env"; set +a; }

if [[ $# -gt 0 ]]; then msg="$*"; else msg="$(cat)"; fi
if [[ -z "${msg// /}" ]]; then
  echo "usage: bash scripts/discord.sh \"<message>\"" >&2; exit 1
fi

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  echo "[discord] DISCORD_WEBHOOK_URL unset; skipping notification." >&2
  exit 0
fi

# Discord 'content' max 2000 chars — truncate defensively. python3 does the JSON encoding.
payload="$(python3 -c 'import json,sys; print(json.dumps({"content": sys.argv[1][:1900]}))' "$msg")"
curl -fsS -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$payload" >/dev/null
echo "[discord] sent."
