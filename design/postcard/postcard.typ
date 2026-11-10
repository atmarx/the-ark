// The Ark — e-waste rescue postcard
// Layout: 6 cards per 8.5"x11" sheet (2 cols x 3 rows)
// Each card: 4.25" x 3.667", full-bleed, with 1/8" safety margin inside
// Philosophy: Cartographer's Mercy — cream stock, one ink, ledger rules,
// letterpress headline, old-style numerals, understated authority.
//
// One ink (oxblood) on cream.  No gradients, no screens, no color.
// Emblem: raven-and-book printer's mark, carried top-right as the Ark device.
// Noah sent the raven first (Genesis 8:7) — it never returned, still mapping.

#let ink   = rgb("#6b1f18")  // oxblood, single ink
#let cream = rgb("#f4ead8")  // cream stock (background fill)
#let rule  = 0.3pt           // ledger hairline

#set document(
  title: "The Ark — 500GB Postcard",
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
      // Inner frame — the ledger rule, the card's own edge of the page
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

      // Double rule under the headline — a surveyor's convention
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

      // Tiny locator — top-left corner, like a map sheet number.
      // Sheet number + year, set wide in small caps.
      place(
        top + left,
        dx: safe + 0.18in,
        dy: safe + 0.18in,
        text(
          size: 6pt,
          tracking: 1.2pt,
          upper[Sheet I · Medium · MMXXVI]
        )
      )

      // ---------- RAVEN MARK (top-right, the Ark emblem) ----------
      // Raven carrying a book.  Noah's first messenger, the one that never
      // came back — still surveying, still mapping.  Knowledge-carrier.
      place(
        top + right,
        dx: -safe - 0.22in,
        dy: safe + 0.16in,
        image("raven.png", height: 0.86in)
      )

      // ---------- HEADLINE ----------
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
          [for the five-hundred-gigabyte drive]
        )
      )

      // ---------- BODY ----------
      // Held to ~4 lines so the provenance block below breathes.
      place(
        top + left,
        dx: safe + 0.28in,
        dy: safe + 1.22in,
        box(width: w - 2 * safe - 0.56in, {
          set par(leading: 0.48em, justify: false)
          set text(size: 8.6pt)
          [That drive in your drawer is not junk. It is an unopened library.]
          parbreak()
          [One laptop disk holds Wikipedia, seventy thousand books, medical texts, repair manuals, programming docs — readable without signal, grid optional.]
        })
      )

      // ---------- INVENTORY (right-aligned tally, hand-ruled look) ----------
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
            [— Wikipedia, complete, with illustrations],    align(right)[94 GB],
            [— Project Gutenberg, seventy thousand volumes], align(right)[206 GB],
            [— Stack Exchange, fourteen communities],        align(right)[36 GB],
            [— Medical, repair, and survival references],    align(right)[12 GB],
            [— Programming docs, a hundred languages],       align(right)[4 GB],
          )
        })
      )

      // ---------- URL (bottom-right) ----------
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

      // ---------- SIGNATURE (bottom-left) ----------
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
// Sheet — 2 columns x 3 rows, no gutter (trim straight through)
// Plus hairline crop marks at the four interior cuts.
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

// Crop/trim hairlines drawn over the grid, dashed so they disappear into
// the cut. One vertical spine down the middle, two horizontals.
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
