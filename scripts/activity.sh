#!/usr/bin/env bash
# Dump this week's (Saturday->Friday, Singapore time) dev-activity digest.
# Sources: Claude Code session logs (~/.claude/projects) + GitHub (gh CLI).
# Read-only. Prints a digest then a final line:
#   [meta] activity_level=<normal|thin|none> score=<n> date=<DDmonYY>
# Usage: bash scripts/activity.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$ROOT/.env" ]] && { set -a; source "$ROOT/.env"; set +a; }

exec python3 - <<'PY'
import os, sys, glob, json, re, subprocess, datetime
from collections import Counter, OrderedDict

SGT = datetime.timezone(datetime.timedelta(hours=8))
PROJECTS = os.environ.get("CLAUDE_PROJECTS_DIR") or os.path.expanduser("~/.claude/projects")
USER = os.environ.get("GITHUB_USER", "")
THRESH = int(os.environ.get("MIN_ACTIVITY_SCORE", "2") or "2")
MONTHS = ["jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"]

def now(): return datetime.datetime.now(SGT)
def window():
    n = now(); d = (n.weekday() - 5) % 7
    s = (n - datetime.timedelta(days=d)).replace(hour=0, minute=0, second=0, microsecond=0)
    return s, n
def parse_ts(s):
    if not s: return None
    s = s.strip().replace("Z", "+00:00")
    m = re.match(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?(.*)$", s)
    if not m:
        try: return datetime.datetime.fromisoformat(s)
        except ValueError: return None
    b, f, r = m.groups(); f = (f or "")[:7]; r = r or "+00:00"
    try: return datetime.datetime.fromisoformat(b + f + r)
    except ValueError: return None
def dslug(dt): return "%02d%s%02d" % (dt.day, MONTHS[dt.month - 1], dt.year % 100)

NOISE = ("base directory for this skill:", "<command-name>", "<command-message>",
         "<command-args>", "<local-command", "system-reminder",
         "this skill helps you build llm-powered applications")
def real(t):
    if not t: return False
    if t.startswith("<") or t.startswith("[Request") or t.startswith("Caveat:"): return False
    if len(t) > 4000: return False
    low = t.lower()
    return not any(m in low for m in NOISE)
def text(c):
    if isinstance(c, str): return c
    if isinstance(c, list):
        return "\n".join(b.get("text", "") for b in c
                         if isinstance(b, dict) and b.get("type") == "text")
    return ""
def tools(c):
    return ([b.get("name") for b in c
             if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name")]
            if isinstance(c, list) else [])

s, e = window()
projects = OrderedDict()
for d in sorted(glob.glob(os.path.join(PROJECTS, "*"))):
    if not os.path.isdir(d): continue
    for jf in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
        try: fh = open(jf)
        except OSError: continue
        with fh:
            for line in fh:
                line = line.strip()
                if not line: continue
                try: rec = json.loads(line)
                except ValueError: continue
                ts = parse_ts(rec.get("timestamp"))
                if ts is None or ts < s or ts > e: continue
                cwd = rec.get("cwd")
                nm = (os.path.basename(cwd.rstrip("/")) if cwd
                      else [p for p in os.path.basename(d).split("-") if p][-1])
                p = projects.setdefault(nm, {"prompts": [], "tools": Counter(),
                                             "titles": OrderedDict(), "sessions": set()})
                sid = rec.get("sessionId")
                if sid: p["sessions"].add(sid)
                rt = rec.get("type"); msg = rec.get("message") or {}; c = msg.get("content")
                if rt == "ai-title":
                    t = (rec.get("title") or text(c)).strip()
                    if t: p["titles"][t] = True
                elif rt == "user":
                    t = text(c).strip()
                    if real(t) and len(p["prompts"]) < 12: p["prompts"].append(t[:220])
                elif rt == "assistant":
                    for n in tools(c): p["tools"][n] += 1
cc = [(k, v) for k, v in projects.items() if v["prompts"] or v["titles"] or v["tools"]]

repos = OrderedDict()
if USER:
    try:
        out = subprocess.run(["gh", "api", "users/%s/events?per_page=100" % USER],
                             capture_output=True, text=True, timeout=60)
        evs = json.loads(out.stdout) if out.returncode == 0 and out.stdout else []
    except Exception:
        evs = []
    for ev in evs:
        ts = parse_ts(ev.get("created_at"))
        if ts is None or ts < s or ts > e: continue
        repo = (ev.get("repo") or {}).get("name", "?")
        r = repos.setdefault(repo, {"pushes": 0, "commits": []})
        pl = ev.get("payload") or {}
        if ev.get("type") == "PushEvent":
            r["pushes"] += 1
            for cm in pl.get("commits", []):
                m = (cm.get("message") or "").splitlines()[0].strip()
                if m and len(r["commits"]) < 15: r["commits"].append(m)

print("WEEK (SGT): %s  ->  %s" % (s.strftime("%a %d %b %Y %H:%M"),
                                  e.strftime("%a %d %b %Y %H:%M")))
print("\n=== CLAUDE CODE ACTIVITY (by project) ===")
if not cc: print("(none)")
for nm, v in cc:
    print("\n# %s  (%d session)" % (nm, len(v["sessions"])))
    for t in list(v["titles"])[:6]: print("  title: %s" % t)
    for q in v["prompts"]: print("  prompt: %s" % q.replace("\n", " "))
    if v["tools"]:
        print("  tools: %s" % ", ".join("%s(%d)" % (n, c) for n, c in v["tools"].most_common(8)))
print("\n=== GITHUB ACTIVITY (by repo) ===")
if not repos: print("(none)")
for repo, r in repos.items():
    print("\n# %s  pushes=%d" % (repo, r["pushes"]))
    for m in r["commits"]: print("  commit: %s" % m)

score = len(cc) + len(repos)
level = "none" if score == 0 else ("thin" if score < THRESH else "normal")
print("\n[meta] activity_level=%s score=%d date=%s" % (level, score, dslug(e)))
PY
