You are running the weekly LinkedIn publish routine for this project. Work only in this folder.
Publish AT MOST ONE post per run. This routine BUILDS the post's visual from the approved copy,
then posts immediately — I do not approve the visual separately.

STEP 1 — Pick the post:
List weeklyPosts/*.md. If none exist, report "queue empty" and stop. Otherwise choose the ONE
file whose filename date prefix (DDmonYY, e.g. 28mar26 = 28 March 2026) is the OLDEST calendar
date. Parse it as a real date (two-digit day, 3-letter month, two-digit year) — do NOT
string-sort the filenames, and do NOT use file modification time. Let <slug> = the chosen file's
name without its .md extension.

STEP 2 — Design the visual FROM THIS POST (read memory/DESIGN-SPEC.md first):
Read the approved post body. Design a visual that fits THIS post's content — do not reuse a
fixed template or the previous week's look. DESIGN-SPEC.md is the rulebook: it is fully
freeform, so the layout, palette, typography, motif, and diagram type are yours to choose to
match the content.
  2a. If a diagram suits the post, write its Mermaid source to weeklyAssets/<slug>.mmd and render:
        bash scripts/diagram.sh weeklyAssets/<slug>.diagram.png weeklyAssets/<slug>.mmd
      Pick the diagram TYPE that fits the content (flowchart, sequence, state, mindmap,
      timeline, etc.). Skip the diagram entirely if the post is better served by a text/number
      driven visual.
  2b. Write a complete, self-contained 1080×1350 HTML card designed for this post to
      weeklyAssets/<slug>.card.html (embed the diagram PNG by filename if you made one).
  2c. Render it to the PNG that will be attached:
        bash scripts/render.sh weeklyAssets/<slug>.card.html weeklyAssets/<slug>.png
If a render step fails, retry once; if it still fails, proceed to STEP 3 anyway — linkedin.sh
posts text-only when no weeklyAssets/<slug>.png exists.

STEP 3 — Publish it:
  bash scripts/linkedin.sh post weeklyPosts/<chosen-file>
This posts the file's contents to LinkedIn and attaches weeklyAssets/<slug>.png if present.
Success prints "[linkedin] published".

STEP 4 — On success (after "[linkedin] published"):
- Delete the queued file weeklyPosts/<chosen-file>.
- Clean up the visual intermediates, but KEEP the posted card as the archive. Delete these if
  present:
    weeklyAssets/<slug>.mmd
    weeklyAssets/<slug>.card.html
    weeklyAssets/<slug>.diagram.png
  Do NOT delete weeklyAssets/<slug>.png — the published card stays as the archive.
- Append one line to memory/POSTING-LOG.md:
    - <YYYY-MM-DD> publish  <chosen-file>  — published <id if shown>  [visual: ok|text-only]

If publishing FAILED, leave every file in place (including the visual) and report the error
verbatim.

Do NOT edit any code. Beyond building the visual (STEP 2), publishing, deleting the queued file,
and the asset cleanup above, run no other commands.
