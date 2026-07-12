# LinkedinPost — Weekly Dev-Activity → LinkedIn Agent

Turns my weekly dev activity (Claude Code logs + GitHub) into a build-in-public LinkedIn post.
**Markdown-driven**: the intelligence lives in `.md` files; the agent runs two **Claude Code
Local Routines** and calls three small shell wrappers. No Anthropic API key needed.

See [CLAUDE.md](CLAUDE.md) for the design and [memory/CONTENT-STRATEGY.md](memory/CONTENT-STRATEGY.md)
for the post rulebook. **All times Singapore (SGT).** Week = Saturday → Friday.

## Flow

```
Fri 3 PM  generate routine ──▶ weeklyDrafts/ (TEXT-ONLY draft) + Discord notice
                                    │  I review + drag-drop approved files
                                    ▼
                               weeklyPosts/    (vetted queue)
Sun 7 PM  publish routine ──▶  designs a visual FROM the approved post (weeklyAssets/<slug>.png),
                               posts the OLDEST-by-title item with it, deletes the .md
```

The visual is **designed fresh per post at publish time**, from the approved copy — not a fixed
template, so each week's image differs and matches its content. It's a self-contained 1080×1350
HTML card rendered by headless Chrome (optionally embedding a Mermaid graphic via Kroki), all
free. See [memory/DESIGN-SPEC.md](memory/DESIGN-SPEC.md).

The agent never posts on its own — moving a draft to `weeklyPosts/` is the approval gate.

## Setup

```sh
cp .env.example .env        # then edit .env
```
Set `GITHUB_USER`; the LinkedIn + Discord values are filled in below.

- **Requirements:** `gh` authenticated (`gh auth status`), `python3` (used inside the scripts
  for JSON/parse), a Chrome-family browser (Chrome/Chromium/Edge/Brave — for the card render),
  internet (for Kroki diagrams), and the Claude Code app with Local Routines. No Anthropic API
  key.

### Discord (recommended)
Discord → **Server Settings → Integrations → Webhooks → New Webhook** → copy the URL into
`.env` `DISCORD_WEBHOOK_URL` (or leave blank to disable).

### LinkedIn (for publishing)
1. Create an app at <https://www.linkedin.com/developers/apps>; add products **Sign In with
   LinkedIn using OpenID Connect** + **Share on LinkedIn**.
2. Auth tab → Authorized redirect URL: `http://localhost:8765/callback`.
3. Put Client ID/Secret into `.env` (`LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`).
4. Authorize once:
   ```sh
   bash scripts/linkedin.sh auth
   ```
   It opens your browser; click **Allow**. A tiny local server on the redirect port catches
   the response automatically (no copy/paste) and stores the tokens + author URN in `.env`.
   If LinkedIn issues a refresh token it's reused automatically; otherwise the ~60-day access
   token is used directly — just re-run `auth` when it expires.

## Create the routines (Claude Code → Routines → New local routine)

For each: **Folder** = this project, **Ask permissions** = Default, paste the workflow file's
contents into *Instructions*.

| Name | Schedule (SGT) | Instructions = contents of |
|---|---|---|
| `linkedinpost-generate` | Weekly · Friday · 15:00 | [routines/generate.md](routines/generate.md) |
| `linkedinpost-publish` | Weekly · Sunday · 19:00 | [routines/publish.md](routines/publish.md) |

After creating **generate**, run it once manually to confirm it produces a draft + Discord
ping. Review the draft, then move it into `weeklyPosts/` to queue it.

## Run / inspect manually

```sh
bash scripts/activity.sh                 # preview this week's digest + [meta]
bash scripts/discord.sh "test message"   # test the webhook
bash scripts/linkedin.sh post weeklyPosts/<file>.md   # first real publish (after auth)
```

## Layout

```
CLAUDE.md  README.md  .env(.example)  .gitignore
memory/CONTENT-STRATEGY.md   memory/DESIGN-SPEC.md   memory/POSTING-LOG.md
routines/generate.md         routines/publish.md
assets/card.template.html
scripts/activity.sh  scripts/diagram.sh  scripts/render.sh  scripts/discord.sh  scripts/linkedin.sh
.claude/settings.json
weeklyDrafts/  weeklyPosts/  weeklyAssets/
```
