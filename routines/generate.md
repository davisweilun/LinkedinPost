You are running the weekly LinkedIn draft-generation routine for this project (the week is
Saturday → Friday, Singapore time). Work only in this folder.

This routine produces a TEXT-ONLY draft. The visual is NOT made here — it is designed and
rendered at publish time, from the post I actually approve (see routines/publish.md). This keeps
the visual matched to my final edited copy.

STEP 1 — Gather my activity:
  bash scripts/activity.sh
It prints the week's digest and ends with a line like:
  [meta] activity_level=<normal|thin|none> score=<n> date=<DDmonYY>

STEP 2 — Write the post:
Read memory/CONTENT-STRATEGY.md and follow it exactly. Write ONE build-in-public post from the
digest. Never invent work that isn't in the digest.

STEP 3 — Save the draft:
Save ONLY the post body to weeklyDrafts/<date>-<slug>.md, where <date> is the `date=` value
from the [meta] line and <slug> is a 2-4 word kebab-case theme. Write nothing else to the file —
no title line, no frontmatter, no notes. Whatever is in this file is exactly what may be posted.

STEP 4 — Notify Discord:
  bash scripts/discord.sh "New LinkedIn draft: <date>-<slug>.md
<the full post text>"

STEP 5 — Log it:
Append one line to memory/POSTING-LOG.md:
  - <YYYY-MM-DD> generate  <date>-<slug>.md  — <one-line summary>  [discord: ok|skipped|failed]

Do NOT make any image, do NOT post to LinkedIn, do NOT move files into weeklyPosts/, and do NOT
edit any code. Finish by reporting the draft filename and the Discord result.
