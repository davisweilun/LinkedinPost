# LinkedinPost — Weekly Dev-Activity → LinkedIn Agent

Turns my weekly development activity into a build-in-public LinkedIn post. **Markdown-driven**:
the project's intelligence lives in `.md` files (this file, `memory/`, `routines/`); the agent
does the work by following the routines and calling the small shell wrappers in `scripts/`.

Owner: Davis (`davis.weilun@gmail.com`), GitHub `davisweilun`.

## Read-me-first

- `memory/CONTENT-STRATEGY.md` — the post rulebook (voice, what to highlight, formatting,
  disclaimer, thin-week web rules). **The generate routine follows this.**
- `memory/DESIGN-SPEC.md` — the weekly **visual** rulebook (freeform, content-driven; the visual
  is designed at publish time from the approved post). **The publish routine follows this.**
- `memory/POSTING-LOG.md` — running record the routines append to.
- `routines/generate.md`, `routines/publish.md` — the two scheduled agent workflows.

## Execution model — Claude Code Local Routines

Two **local routines** (Claude Code → Routines) run a Claude Code agent in this folder on a
schedule (only while the Mac is awake — no catch-up if asleep). The agent does the thinking;
each `scripts/*.sh` is a thin wrapper around one external thing. **No Anthropic API key** is
needed — the routine agent *is* Claude.

| Routine | Schedule (SGT) | Workflow file | Does |
|---|---|---|---|
| `linkedinpost-generate` | Weekly · Friday · 15:00 | [routines/generate.md](routines/generate.md) | `activity.sh` → write post per `CONTENT-STRATEGY.md` → save **text-only** draft → `discord.sh` → log |
| `linkedinpost-publish` | Weekly · Sunday · 19:00 | [routines/publish.md](routines/publish.md) | pick oldest in `weeklyPosts/` → **design the visual from the approved post** per `DESIGN-SPEC.md` (`diagram.sh` + `render.sh`) → `linkedin.sh post` (attaches the card) → delete the queued post, **keep its `.png`** in `weeklyAssets/` (clear intermediates) → log |

Setup: Folder = this project, **Ask permissions** = Default (allowlist in `.claude/settings.json`
covers it), paste the workflow file's contents into the routine's *Instructions*.

## Scripts (thin wrappers only)

| Script | Wraps | Notes |
|---|---|---|
| `scripts/activity.sh` | Claude Code logs + GitHub | Prints the Sat→Fri digest + `[meta] activity_level/date`. Read-only. |
| `scripts/discord.sh` | Discord webhook | Posts a message; no-ops if `DISCORD_WEBHOOK_URL` unset. |
| `scripts/diagram.sh` | Kroki (free) | Mermaid source → PNG. POST, no encoding. `mermaid.ink` fallback in comments; `KROKI_URL` to self-host. |
| `scripts/render.sh` | headless Chrome | HTML file → PNG (default 1080×1350 @2x). Auto-detects Chrome/Chromium/Edge/Brave. |
| `scripts/linkedin.sh` | LinkedIn OAuth + Posts API | `auth` (one-time) and `post <file>` (refresh token + publish; **attaches `weeklyAssets/<slug>.png`** if present, else text-only). |

Secrets/config live in **`.env`** (gitignored), sourced by the scripts. See `.env.example`.

## Weekly visual (free, no design service)

The visual is designed and built at **publish** time into `weeklyAssets/`, from the post I
actually approved — so it always matches the final copy. It is **not** a fixed template:
`DESIGN-SPEC.md` is fully freeform, so the agent designs a fresh 1080×1350 card per post around
that week's content (layout, palette, type, and diagram type all vary). The agent writes a
self-contained `<slug>.card.html` (optionally embedding a Mermaid graphic it renders with
`diagram.sh`), then `render.sh` (headless Chrome) turns it into `<slug>.png`. `linkedin.sh post`
attaches that PNG. `assets/card.template.html` is kept only as one worked *example*, not a style
to reuse. Cost: **$0** — both renderers are free; needs a Chrome-family browser locally and
(if a diagram is used) internet for Kroki. After a successful publish, the posted **`<slug>.png`
is kept** in `weeklyAssets/` as the visual archive; the `.mmd` / `.card.html` / `.diagram.png`
intermediates are removed.

## Time zone & week

All times **Singapore (SGT, UTC+8)**. The week is **Saturday 00:00 → the Friday** the generate
routine fires. `activity.sh` computes this window in SGT.

## Directory lifecycle

```
weeklyDrafts/   generated, UNVETTED, TEXT-ONLY (generate routine writes here) + Discord notice
      │  ← I review, edit, and manually move approved posts (drag-and-drop)
      ▼
weeklyPosts/    VETTED queue — the ONLY source publish may post from
      │  ← publish takes the oldest item (by title date), designs its visual from the
      │    approved copy → weeklyAssets/<slug>.png, posts, then deletes the .md
      ▼
   (.md deleted after a successful post; the posted <slug>.png is kept in weeklyAssets/)
```

## File naming

`DDmonYY-short-title.md` (e.g. `28mar26-trading-bot-terror.md`). The `DDmonYY` prefix is the
canonical date the publish routine orders by — **parsed as a real date**, not string-sorted,
not by file mtime. Oldest-dated post publishes first (FIFO, one per Sunday).

## Autonomy & the vetting gate

Clear separation:

1. **Vetting gate (human):** I move an approved draft `weeklyDrafts/ → weeklyPosts/`. Nothing
   is published that I haven't promoted. This is the only recurring human step.
2. **Execution (autonomous):** once approved, the routines run end-to-end with no per-step
   prompts — tool permissions are pre-allowlisted in `.claude/settings.json`, the scripts are
   non-interactive, and actions are logged to `memory/POSTING-LOG.md`.

Genuinely-manual one-time setup (not normal operation): `bash scripts/linkedin.sh auth`
(browser OAuth consent), creating the Discord webhook, and creating the two routines.

## Data sources

1. **Claude Code session logs** — `~/.claude/projects/<encoded-cwd>/*.jsonl` (central store
   mirroring every `Documents/claude-code/*` project). Per-project prompts/titles/tools in the
   Sat→Fri window, with injected skill/command payloads filtered out. Richest signal.
2. **GitHub** — `gh api users/<user>/events` in the same window.

Not used (no reliable local export): Claude web/desktop app, raw VS Code activity. Images out
of scope.

## Status

Restructured to the TradingBotTerror markdown-driven pattern (markdown source-of-truth + thin
shell wrappers + `.env`). `activity.sh`/`discord.sh` verified locally; `linkedin.sh post`
awaits the one-time app/auth for its first live publish.
