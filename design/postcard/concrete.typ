// The Ark — Concrete Poetry variant
// Layout: 6 cards per 8.5"x11" sheet (2 cols x 3 rows)
// Each card: 4.25" x 3.667", full-bleed, 1/4" hairline frame inside
// Philosophy: Concrete Poetry — black ink on white, Swiss/Brutalist,
// grotesque display, monospace numerals, one dominant mark.
//
// The "500" is the whole page.  Everything else is a footnote to the number.

#let ink   = rgb("#0a0a0a")
#let paper = rgb("#ffffff")
#let hair  = 0.25pt

#set document(
  title: "The Ark — Concrete Poetry Postcard",
  author: "Zim the Hermit",
)

#set page(
  paper: "us-letter",
  margin: 0in,
  fill: paper,
)

#set text(
  font: "Inter",
  fill: ink,
  size: 8pt,
)

// ------------------------------------------------------------------
// A single postcard — 4.25" wide x 3.667" tall, full-bleed
// ------------------------------------------------------------------
#let card = {
  let w = 4.25in
  let h = 3.6666in
  let m = 0.22in

  box(
    width: w,
    height: h,
    fill: paper,
    stroke: none,
    inset: 0pt,
    {
      // Hairline frame
      place(
        top + left,
        dx: m,
        dy: m,
        rect(
          width: w - 2 * m,
          height: h - 2 * m,
          stroke: hair + ink,
          fill: none,
        )
      )

      // ---------- TOP BAR: locators + rule ----------
      place(
        top + left,
        dx: m + 0.16in,
        dy: m + 0.14in,
        text(
          font: "JetBrains Mono",
          size: 5.6pt,
          tracking: 0.8pt,
          upper[THE ARK / SHEET I]
        )
      )
      place(
        top + right,
        dx: -m - 0.16in,
        dy: m + 0.14in,
        text(
          font: "JetBrains Mono",
          size: 5.6pt,
          tracking: 0.8pt,
          upper[FIELD GUIDE · 2026]
        )
      )
      place(
        top + left,
        dx: m + 0.16in,
        dy: m + 0.30in,
        line(length: w - 2 * m - 0.32in, stroke: hair + ink)
      )

      // ---------- HERO: 500 centered, Inter Black, dominant ----------
      place(
        top,
        dy: m + 0.48in,
        box(width: w, {
          align(center, text(
            font: "Inter",
            weight: 900,
            size: 140pt,
            tracking: -5.5pt,
            "500"
          ))
        })
      )

      // ---------- "GIGABYTES" unit mark, mono, centered under the numeral ---
      place(
        top,
        dy: m + 1.94in,
        box(width: w, align(center, text(
          font: "JetBrains Mono",
          weight: 500,
          size: 8pt,
          tracking: 6pt,
          upper[GIGABYTES]
        )))
      )

      // ---------- SUBTITLE (centered, 2 lines, tight leading) ----------
      place(
        top,
        dy: m + 2.26in,
        box(width: w, {
          set text(font: "Inter", weight: 800, size: 11pt, tracking: 0.1pt)
          set par(leading: 0.26em)
          align(center)[
            #upper[A LIBRARY YOU CAN HOLD] \
            #upper[IN ONE HAND.]
          ]
        })
      )

      // ---------- INVENTORY STRIP (horizontal, mono, micro) ----------
      place(
        bottom,
        dy: -m - 0.34in,
        box(width: w, {
          set text(font: "JetBrains Mono", size: 5.6pt, tracking: 0.6pt)
          align(center, upper[
            GUTENBERG 206 · WIKIPEDIA 094 · MEDICINE 012 · REPAIR 008 · CODE 004
          ])
        })
      )

      // ---------- BOTTOM RULE + FOOTER ----------
      place(
        bottom + left,
        dx: m + 0.16in,
        dy: -m - 0.22in,
        line(length: w - 2 * m - 0.32in, stroke: hair + ink)
      )
      place(
        bottom + left,
        dx: m + 0.16in,
        dy: -m - 0.08in,
        text(
          font: "JetBrains Mono",
          size: 5.6pt,
          tracking: 0.8pt,
          upper[ATMARX / THE-ARK]
        )
      )
      place(
        bottom + right,
        dx: -m - 0.16in,
        dy: -m - 0.08in,
        text(
          font: "JetBrains Mono",
          size: 5.6pt,
          tracking: 0.8pt,
          upper[— ZIM · HERMIT OF THE DRIVE]
        )
      )

    }
  )
}

// ------------------------------------------------------------------
// Sheet — 2 columns x 3 rows, no gutter (trim straight through)
// ------------------------------------------------------------------
#grid(
  columns: (4.25in, 4.25in),
  rows: (3.6666in, 3.6666in, 3.6666in),
  column-gutter: 0pt,
  row-gutter: 0pt,
  card, card,
  card, card,
  card, card,
)

// Crop/trim hairlines — one vertical spine, two horizontals
#place(
  top + left,
  dx: 4.25in,
  dy: 0in,
  line(
    length: 11in,
    angle: 90deg,
    stroke: (paint: ink, thickness: 0.2pt, dash: "dotted"),
  )
)
#place(
  top + left,
  dx: 0in,
  dy: 3.6666in,
  line(
    length: 8.5in,
    stroke: (paint: ink, thickness: 0.2pt, dash: "dotted"),
  )
)
#place(
  top + left,
  dx: 0in,
  dy: 7.3333in,
  line(
    length: 8.5in,
    stroke: (paint: ink, thickness: 0.2pt, dash: "dotted"),
  )
)
