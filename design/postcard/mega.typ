// The Ark — e-waste rescue postcard, MEGA variant
// Layout: 6 cards per 8.5"x11" sheet (2 cols x 3 rows)
// Each card: 4.25" x 3.667", full-bleed, with 1/8" safety margin inside
// Same Cartographer's Mercy voice — cream, oxblood, ledger rules.
// Different editorial question: what happens when there's room for everything?

#let ink   = rgb("#6b1f18")
#let cream = rgb("#f4ead8")
#let rule  = 0.3pt

#set document(
  title: "The Ark — 1TB Postcard (Mega)",
  author: "Zim the Hermit",
)

#set page(
  paper: "us-letter",
  margin: 0in,
  fill: cream,
)

#set text(
  font: "EB Garamond",
  fill: ink,
  size: 9pt,
  number-type: "old-style",
)

// ------------------------------------------------------------------
// A single postcard — 4.25" wide x 3.667" tall, full-bleed
// ------------------------------------------------------------------
#let card = {
  let w = 4.25in
  let h = 3.6666in
  let safe = 0.175in

  box(
    width: w,
    height: h,
    fill: cream,
    stroke: none,
    inset: 0pt,
    {
      // Inner frame
      place(
        top + left,
        dx: safe,
        dy: safe,
        rect(
          width: w - 2 * safe,
          height: h - 2 * safe,
          stroke: rule + ink,
          fill: none,
        )
      )

      // Double rule under the headline
      place(
        top + left,
        dx: safe + 0.28in,
        dy: safe + 1.02in,
        line(length: w - 2 * safe - 0.56in, stroke: rule + ink)
      )
      place(
        top + left,
        dx: safe + 0.28in,
        dy: safe + 1.06in,
        line(length: w - 2 * safe - 0.56in, stroke: rule + ink)
      )

      // Locator — top-left, sheet series marker
      place(
        top + left,
        dx: safe + 0.18in,
        dy: safe + 0.18in,
        text(
          size: 6pt,
          tracking: 1.2pt,
          upper[Sheet III · Mega · MMXXVI]
        )
      )

      // Raven mark — top-right, the Ark emblem
      place(
        top + right,
        dx: -safe - 0.22in,
        dy: safe + 0.16in,
        image("raven.png", height: 0.86in)
      )

      // Headline
      place(
        top + left,
        dx: safe + 0.28in,
        dy: safe + 0.44in,
        text(
          size: 17pt,
          weight: "bold",
          tracking: 2.4pt,
          font: "EB Garamond",
          upper[A FIELD GUIDE]
        )
      )
      place(
        top + left,
        dx: safe + 0.28in,
        dy: safe + 0.70in,
        text(
          size: 11pt,
          style: "italic",
          tracking: 0.4pt,
          [for the one-terabyte drive]
        )
      )

      // Body
      place(
        top + left,
        dx: safe + 0.28in,
        dy: safe + 1.22in,
        box(width: w - 2 * safe - 0.56in, {
          set par(leading: 0.48em, justify: false)
          set text(size: 8.6pt)
          [Space stopped being a question. Gutenberg came back.]
          parbreak()
          [Then ten Wikipedias — English to Arabic — every article, every illustration. Then Stack Overflow, then TED Talks. The library began.]
        })
      )

      // Inventory tally
      place(
        bottom + left,
        dx: safe + 0.28in,
        dy: -safe - 0.66in,
        box(width: w - 2 * safe - 0.56in, {
          // Provenance fields — filled by hand when assigned to a drive
          grid(
            columns: (auto, 0.55in, 10pt, auto, 0.80in),
            column-gutter: 3pt,
            align: bottom,
            text(size: 5.8pt, tracking: 1.0pt, upper([No.])),
            box(width: 100%, height: 0.13in, fill: cream, stroke: (bottom: rule + ink), inset: 0pt)[],
            [],
            text(size: 5.8pt, tracking: 1.0pt, upper([Stamped])),
            box(width: 100%, height: 0.13in, fill: cream, stroke: (bottom: rule + ink), inset: 0pt)[],
          )
          v(4pt)
          set text(size: 7.4pt, tracking: 0.6pt)
          grid(
            columns: (1fr, auto),
            column-gutter: 6pt,
            row-gutter: 2.2pt,
            [— Wikipedia, ten languages, with illustrations],  align(right)[331 GB],
            [— Project Gutenberg, seventy thousand volumes],   align(right)[206 GB],
            [— Stack Overflow, the complete Q&A archive],      align(right)[75 GB],
            [— TED Talks, all talks, every language],          align(right)[10 GB],
            [— Medical, repair, and survival references],      align(right)[12 GB],
          )
        })
      )

      // URL
      place(
        bottom + right,
        dx: -safe - 0.28in,
        dy: -safe - 0.20in,
        text(
          size: 6.6pt,
          tracking: 1.0pt,
          upper[github.com / atmarx / the-ark]
        )
      )

      // Signature
      place(
        bottom + left,
        dx: safe + 0.28in,
        dy: -safe - 0.20in,
        text(
          size: 6.6pt,
          style: "italic",
          [— Zim, hermit of the drive]
        )
      )
    }
  )
}

// ------------------------------------------------------------------
// Sheet — 2 columns x 3 rows, no gutter
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

// Crop marks — one vertical, two horizontals
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
