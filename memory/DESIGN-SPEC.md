# Design Spec — the weekly visual

The visual is designed and rendered at **publish** time (see `routines/publish.md`), from the
post I actually approved — never from a fixed template and never a clone of last week. The goal
is the opposite of uniform: **each week's image is designed around that week's content.**

Output goes to `weeklyAssets/<slug>.png` (the visual archive). Renderers are free, no API key:
`scripts/render.sh` turns an HTML file into the PNG; `scripts/diagram.sh` turns Mermaid source
into a PNG you can embed. Both are pure mechanical wrappers — the *design* is yours.

## Mandate: content-driven, not templated

- **Design for the specific post.** Read the approved body, find its single strongest idea, and
  build the image around that. The layout, palette, type, composition, and motif should differ
  from post to post. There is intentionally **no house template** to fill in.
- **Vary deliberately.** Before designing, glance at the last 1–2 published cards in
  `weeklyAssets/` (and the `[visual: ...]` notes in `memory/POSTING-LOG.md`) and make this one
  clearly different — different palette and composition at minimum.
- **The image is a hook, not the post.** Keep on-image text short (a headline plus maybe a line
  or a few numbers). The full story lives in the post copy.

## The only hard constraints

Everything else is free, but stay inside these so it renders and reads on LinkedIn:

- **Canvas: exactly 1080×1350** (LinkedIn 4:5 portrait). The HTML root must be this size.
- **Self-contained HTML.** `render.sh` loads a local file in headless Chrome — inline all CSS,
  use system/web-safe fonts or `@font-face` with a URL, and reference only local files (e.g. a
  diagram PNG you rendered into the same folder). No external CSS/JS that needs network at load.
- **Legible at feed size.** High contrast, generous sizes; assume it's viewed small on a phone.
- **Readable, safe content only.** No misleading claims; match the post.
- **No dates or week labels — ever.** Never put a date, week number, "week of …", or any
  date-like tag on the image, and never derive one from the filename. The filename's `DDmonYY`
  prefix exists **only** to order the publish queue; it is not content and must not be displayed.

## Choosing the graphic

Pick whatever best expresses *this* week — you are not required to include a diagram:

- **Diagram** (via `diagram.sh`) when the week is about a system/flow/process. Choose the
  Mermaid **type** that fits: flowchart, sequence, state, mindmap, timeline, gitgraph, etc. —
  not always a left-to-right flowchart.
- **Data/number** visual (big stat, before/after, a small bar/line drawn in HTML/SVG) when the
  week is about an outcome or metric.
- **Typographic** composition (a strong pull-quote / concept in expressive type) when the week
  is an idea or lesson rather than a system.

Mermaid renders on a white background; if you embed a diagram, place it on a panel that makes
that white look intentional within your design.

## Notes

- `assets/card.template.html` is kept only as **one worked example** of a valid 1080×1350
  self-contained card — a reference for the render mechanics, **not** a style to reuse. Design a
  fresh card per post rather than filling it in.
- The card image is built at publish time alongside posting; `linkedin.sh post` attaches
  `weeklyAssets/<slug>.png` if it exists, otherwise posts text-only.
