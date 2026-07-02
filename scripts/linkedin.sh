#!/usr/bin/env bash
# LinkedIn wrapper: one-time OAuth + publish a text post via the Posts API.
# Usage:
#   bash scripts/linkedin.sh auth              # one-time: mint a refresh token into .env
#   bash scripts/linkedin.sh post <file.md>    # refresh access token, publish file content
# Reads/writes credentials in .env. python3 is used only for JSON/URL encoding.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

API_VERSION="${LINKEDIN_API_VERSION:-202506}"
REDIRECT="${LINKEDIN_REDIRECT_URI:-http://localhost:8765/callback}"
SCOPE="openid profile w_member_social"

jget() { python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get(sys.argv[1], ""))
except Exception:
    print("")
' "$1"; }
urlenc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

set_env() {  # set_env KEY VALUE  -> update existing line or append in .env
  local k="$1" v="$2"
  if grep -q "^${k}=" "$ENV_FILE" 2>/dev/null; then
    python3 - "$ENV_FILE" "$k" "$v" <<'PY'
import sys
path, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().splitlines()
open(path, "w").write("\n".join((k + "=" + v) if ln.startswith(k + "=") else ln
                                for ln in lines) + "\n")
PY
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  auth)
    : "${LINKEDIN_CLIENT_ID:?set LINKEDIN_CLIENT_ID in .env}"
    : "${LINKEDIN_CLIENT_SECRET:?set LINKEDIN_CLIENT_SECRET in .env}"
    # Auto-catch flow: opens the browser, runs a tiny local server on the redirect
    # port to capture the code automatically (no copy/paste, no 30s race), exchanges
    # it for tokens, and writes LINKEDIN_REFRESH_TOKEN + LINKEDIN_PERSON_URN to .env.
    python3 - "$ENV_FILE" <<'PY'
import os, sys, json, secrets, urllib.parse, urllib.request, webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

env_file = sys.argv[1]
cid = os.environ["LINKEDIN_CLIENT_ID"]
csec = os.environ["LINKEDIN_CLIENT_SECRET"]
redirect = os.environ.get("LINKEDIN_REDIRECT_URI", "http://localhost:8765/callback")
scope = "openid profile w_member_social"
state = secrets.token_urlsafe(12)
pu = urllib.parse.urlparse(redirect)
host, port = (pu.hostname or "localhost"), (pu.port or 80)

auth_url = "https://www.linkedin.com/oauth/v2/authorization?" + urllib.parse.urlencode(
    {"response_type": "code", "client_id": cid, "redirect_uri": redirect,
     "scope": scope, "state": state})

result = {}

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if "error" in q:
            result["error"] = q.get("error_description", q["error"])[0]
        elif q.get("state", [None])[0] != state:
            result["error"] = "state mismatch (possible CSRF)"
        else:
            result["code"] = q.get("code", [None])[0]
        ok = result.get("code") and not result.get("error")
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        msg = ("Authorized — close this tab and return to the terminal."
               if ok else "Authorization failed: %s" % result.get("error"))
        self.wfile.write(("<h2>%s</h2>" % msg).encode())
    def log_message(self, *a):
        pass

print("Opening the browser to authorize. If it doesn't open, visit:\n  %s\n" % auth_url)
try:
    webbrowser.open(auth_url)
except Exception:
    pass
httpd = HTTPServer((host, port), H)
print("Waiting for the LinkedIn redirect on %s ..." % redirect)
while "code" not in result and "error" not in result:
    httpd.handle_request()
httpd.server_close()
if result.get("error"):
    sys.exit("auth failed: %s" % result["error"])
code = result["code"]

def post(url, fields):
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(url, data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"})
    return json.load(urllib.request.urlopen(req, timeout=30))

try:
    tok = post("https://www.linkedin.com/oauth/v2/accessToken",
               {"grant_type": "authorization_code", "code": code,
                "client_id": cid, "client_secret": csec, "redirect_uri": redirect})
except Exception as e:
    sys.exit("token exchange failed: %s" % e)
access = tok.get("access_token")
refresh = tok.get("refresh_token", "")
if not access:
    sys.exit("token exchange failed: %s" % tok)

urn = ""
try:
    req = urllib.request.Request("https://api.linkedin.com/v2/userinfo",
                                 headers={"Authorization": "Bearer " + access})
    sub = json.load(urllib.request.urlopen(req, timeout=30)).get("sub")
    if sub:
        urn = "urn:li:person:" + sub
except Exception:
    pass

def set_env(k, v):
    lines = open(env_file).read().splitlines() if os.path.exists(env_file) else []
    out, found = [], False
    for ln in lines:
        if ln.startswith(k + "="):
            out.append(k + "=" + v); found = True
        else:
            out.append(ln)
    if not found:
        out.append(k + "=" + v)
    open(env_file, "w").write("\n".join(out) + "\n")

import time
expires_in = int(tok.get("expires_in", 0) or 0)
set_env("LINKEDIN_ACCESS_TOKEN", access)
set_env("LINKEDIN_ACCESS_EXPIRES", str(int(time.time()) + expires_in))
if refresh:
    set_env("LINKEDIN_REFRESH_TOKEN", refresh)
if urn:
    set_env("LINKEDIN_PERSON_URN", urn)
if refresh:
    print("Authorized. Stored refresh token + access token + author URN in .env.")
else:
    days = expires_in // 86400
    print("Authorized. LinkedIn issued NO refresh token (app not approved for them),")
    print("so the access token (valid ~%d days) was stored. Re-run auth when it expires." % days)
PY
    ;;

  post)
    file="${1:?usage: bash scripts/linkedin.sh post <file>}"
    : "${LINKEDIN_CLIENT_ID:?set LINKEDIN_CLIENT_ID in .env}"
    : "${LINKEDIN_CLIENT_SECRET:?set LINKEDIN_CLIENT_SECRET in .env}"
    if [[ -n "${LINKEDIN_REFRESH_TOKEN:-}" ]]; then
      # Preferred path: trade the refresh token for a fresh access token.
      resp="$(curl -sS -X POST https://www.linkedin.com/oauth/v2/accessToken \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "grant_type=refresh_token" \
        --data-urlencode "refresh_token=${LINKEDIN_REFRESH_TOKEN}" \
        --data-urlencode "client_id=${LINKEDIN_CLIENT_ID}" \
        --data-urlencode "client_secret=${LINKEDIN_CLIENT_SECRET}" || true)"
      access="$(printf '%s' "$resp" | jget access_token)"
      newref="$(printf '%s' "$resp" | jget refresh_token)"
      [[ -z "$access" ]] && { echo "token refresh failed: $resp" >&2; exit 1; }
      [[ -n "$newref" ]] && set_env LINKEDIN_REFRESH_TOKEN "$newref"
    else
      # LinkedIn issued no refresh token — use the stored ~60-day access token.
      access="${LINKEDIN_ACCESS_TOKEN:-}"
      now="$(date +%s)"
      if [[ -z "$access" ]]; then
        echo "No access token stored. Run: bash scripts/linkedin.sh auth" >&2; exit 1
      fi
      if [[ -n "${LINKEDIN_ACCESS_EXPIRES:-}" && "${LINKEDIN_ACCESS_EXPIRES}" -le "$now" ]]; then
        echo "Stored LinkedIn access token has expired. Re-run: bash scripts/linkedin.sh auth" >&2; exit 1
      fi
    fi
    urn="${LINKEDIN_PERSON_URN:-}"
    if [[ -z "$urn" ]]; then
      sub="$(curl -sS https://api.linkedin.com/v2/userinfo -H "Authorization: Bearer ${access}" | jget sub)"
      urn="urn:li:person:${sub}"
    fi

    # Attach the matching visual if one exists: weeklyAssets/<same-slug>.png
    base="$(basename "$file")"; base="${base%.*}"
    image_urn=""; asset=""
    for cand in "$ROOT/weeklyAssets/${base}.png" "${file%.*}.png"; do
      [[ -f "$cand" ]] && { asset="$cand"; break; }
    done
    if [[ -n "$asset" ]]; then
      init="$(curl -sS -X POST "https://api.linkedin.com/rest/images?action=initializeUpload" \
        -H "Authorization: Bearer ${access}" -H "Content-Type: application/json" \
        -H "X-Restli-Protocol-Version: 2.0.0" -H "LinkedIn-Version: ${API_VERSION}" \
        --data "$(python3 -c 'import json,sys;print(json.dumps({"initializeUploadRequest":{"owner":sys.argv[1]}}))' "$urn")" || true)"
      upload_url="$(printf '%s' "$init" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("value",{}).get("uploadUrl",""))' 2>/dev/null || true)"
      image_urn="$(printf '%s' "$init" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("value",{}).get("image",""))' 2>/dev/null || true)"
      if [[ -n "$upload_url" && -n "$image_urn" ]]; then
        curl -fsS -X PUT "$upload_url" -H "Authorization: Bearer ${access}" --upload-file "$asset" >/dev/null \
          || { echo "[linkedin] image upload failed; posting text-only." >&2; image_urn=""; }
      else
        echo "[linkedin] image init failed; posting text-only." >&2; image_urn=""
      fi
    fi

    body="$(python3 - "$urn" "$file" "$image_urn" <<'PY'
import json, sys
urn, path = sys.argv[1], sys.argv[2]
image = sys.argv[3] if len(sys.argv) > 3 else ""
text = open(path).read().strip()
post = {"author": urn, "commentary": text, "visibility": "PUBLIC",
        "distribution": {"feedDistribution": "MAIN_FEED", "targetEntities": [],
                         "thirdPartyDistributionChannels": []},
        "lifecycleState": "PUBLISHED", "isReshareDisabledByAuthor": False}
if image:
    post["content"] = {"media": {"id": image, "title": "Weekly build log"}}
print(json.dumps(post))
PY
)"
    headers="$(curl -fsS -D - -o /dev/null -X POST https://api.linkedin.com/rest/posts \
      -H "Authorization: Bearer ${access}" \
      -H "Content-Type: application/json" \
      -H "X-Restli-Protocol-Version: 2.0.0" \
      -H "LinkedIn-Version: ${API_VERSION}" \
      --data "$body")" || { echo "[linkedin] post failed" >&2; exit 1; }
    id="$(printf '%s' "$headers" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-restli-id"{print $2}')"
    echo "[linkedin] published${id:+ (id=$id)}"
    ;;

  *)
    echo "usage: bash scripts/linkedin.sh {auth | post <file>}" >&2; exit 2 ;;
esac
