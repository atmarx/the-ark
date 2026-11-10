// The Ark — Floppy Sleeves, Three for the New CIO
// One sheet per sleeve, three pages total (READ_FIRST / STRATEGY / SUCCESSION).
// Same Cartographer's Mercy voice as the field-guide series — cream, oxblood,
// ledger rules, EB Garamond, raven-and-book emblem.
//
// Layout (per page):
//   Front panel (top, 3.7" x 3.85") — face of the sleeve, shows the gag.
//   Hinge fold (0.15") — solid line on page, dashed for cut/score reference.
//   Back panel (bottom, 3.7" x 3.85") — printed rotated 180deg so it reads
//     right-side-up after folding behind the front.
//   Side glue tabs (0.45" each) — fold under and glue to back.
//
// Crop/fold marks: dashed = fold, dotted = cut.

#let ink   = rgb("#6b1f18")
#let cream = rgb("#f4ead8")
#let rule  = 0.3pt

#set document(
  title: "The Ark — Three Floppies for the CIO",
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
// Geometry
// ------------------------------------------------------------------
#let pw = 8.5in        // page width
#let ph = 11in         // page height

#let panel_w = 3.7in   // sleeve panel width  (3.5" floppy = 3.54" wide)
#let panel_h = 3.85in  // sleeve panel height (3.5" floppy = 3.7" tall)
#let hinge   = 0.15in  // bottom fold depth
#let tab_w   = 0.45in  // side glue tab width

#let sleeve_w = panel_w + 2 * tab_w        // 4.6"
#let sleeve_h = 2 * panel_h + hinge        // 7.85"

#let ox = (pw - sleeve_w) / 2              // origin x
#let oy = (ph - sleeve_h) / 2              // origin y

// Convenient anchors
#let front_x = ox + tab_w
#let front_y = oy
#let back_x  = ox + tab_w
#let back_y  = oy + panel_h + hinge
#let left_tab_x  = ox
#let right_tab_x = ox + tab_w + panel_w

// ------------------------------------------------------------------
// One sleeve — parameterised by what makes each disk distinct.
//
//   disk_no       — "I", "II", "III"
//   filename      — "READ_FIRST.TXT" etc.
//   when_to_open  — "When the auditors arrive, open this disk."
//   subtitle      — short editorial line under the filename
//   body          — content block (free-form), drawn inside the front panel
// ------------------------------------------------------------------
#let sleeve(disk_no: "I", filename: "READ_FIRST.TXT",
            when_to_open: "", subtitle: "", body: []) = {

  // ---------- Outline of the unfolded sleeve (cut path) ----------
  // Outer rectangle = the trim line.  Dotted = cut.
  place(top + left, dx: ox, dy: oy,
    rect(width: sleeve_w, height: sleeve_h,
         stroke: (paint: ink, thickness: 0.3pt, dash: "densely-dotted"),
         fill: none))

  // ---------- Fold lines (dashed) ----------
  // Bottom-of-front fold (top of hinge band)
  place(top + left, dx: front_x, dy: front_y + panel_h,
    line(length: panel_w,
         stroke: (paint: ink, thickness: 0.3pt, dash: "dashed")))
  // Top-of-back fold (bottom of hinge band)
  place(top + left, dx: front_x, dy: back_y,
    line(length: panel_w,
         stroke: (paint: ink, thickness: 0.3pt, dash: "dashed")))
  // Left tab fold
  place(top + left, dx: front_x, dy: oy,
    line(length: panel_h, angle: 90deg,
         stroke: (paint: ink, thickness: 0.3pt, dash: "dashed")))
  // Right tab fold
  place(top + left, dx: front_x + panel_w, dy: oy,
    line(length: panel_h, angle: 90deg,
         stroke: (paint: ink, thickness: 0.3pt, dash: "dashed")))

  // ---------- FRONT PANEL ----------
  let inset = 0.22in

  // Inner ledger-rule frame (sits inside the panel, like the postcards)
  place(top + left,
    dx: front_x + 0.14in,
    dy: front_y + 0.14in,
    rect(width: panel_w - 0.28in,
         height: panel_h - 0.28in,
         stroke: rule + ink,
         fill: none))

  // Locator (top-left, like a sheet number)
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset,
    text(size: 6pt, tracking: 1.2pt,
         upper[Disk #disk_no · Pico · MMXXVI]))

  // Raven mark (top-right corner)
  place(top + right,
    dx: -(pw - (front_x + panel_w)) - inset,
    dy: front_y + inset - 0.04in,
    image("raven.png", height: 0.78in))

  // Headline — the filename, in JetBrains Mono, all caps
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset + 0.40in,
    text(font: "JetBrains Mono", size: 14pt, weight: "bold",
         tracking: 0.6pt, [#filename]))

  // "When to open" — the gag's cue line
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset + 0.74in,
    box(width: panel_w - 2 * inset,
        text(size: 9pt, style: "italic",
             [#when_to_open])))

  // Double rule under the cue
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset + 1.06in,
    line(length: panel_w - 2 * inset, stroke: rule + ink))
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset + 1.10in,
    line(length: panel_w - 2 * inset, stroke: rule + ink))

  // Subtitle
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset + 1.20in,
    box(width: panel_w - 2 * inset,
        text(size: 8pt, tracking: 0.4pt,
             upper[#subtitle])))

  // Body block
  place(top + left,
    dx: front_x + inset,
    dy: front_y + inset + 1.50in,
    box(width: panel_w - 2 * inset, {
      set par(leading: 0.5em, justify: false)
      set text(size: 8.4pt)
      body
    }))

  // Provenance fields (bottom of front panel)
  place(top + left,
    dx: front_x + inset,
    dy: front_y + panel_h - inset - 0.34in,
    box(width: panel_w - 2 * inset, {
      grid(
        columns: (auto, 0.55in, 10pt, auto, 0.80in),
        column-gutter: 3pt,
        align: bottom,
        text(size: 5.8pt, tracking: 1.0pt, upper([No.])),
        box(width: 100%, height: 0.13in, fill: cream,
            stroke: (bottom: rule + ink), inset: 0pt)[],
        [],
        text(size: 5.8pt, tracking: 1.0pt, upper([Stamped])),
        box(width: 100%, height: 0.13in, fill: cream,
            stroke: (bottom: rule + ink), inset: 0pt)[],
      )
    }))

  // Signature + URL (bottom edge of front panel)
  place(top + left,
    dx: front_x + inset,
    dy: front_y + panel_h - inset - 0.06in,
    text(size: 6.4pt, style: "italic", [— Zim, hermit of the drive]))
  place(top + right,
    dx: -(pw - (front_x + panel_w)) - inset,
    dy: front_y + panel_h - inset - 0.06in,
    text(size: 6.4pt, tracking: 1.0pt,
         upper[github.com / atmarx / the-ark]))

  // ---------- BACK PANEL (printed rotated 180deg so it reads right-side-up
  // when folded up behind the front) ----------
  place(top + left, dx: back_x, dy: back_y,
    box(width: panel_w, height: panel_h, fill: cream, stroke: none,
        rotate(180deg, reflow: false,
          box(width: panel_w, height: panel_h, {
            // Inner frame
            place(top + left,
              dx: 0.14in, dy: 0.14in,
              rect(width: panel_w - 0.28in,
                   height: panel_h - 0.28in,
                   stroke: rule + ink, fill: none))

            // Centred mark + dedication
            place(center + horizon,
              dy: -0.55in,
              image("raven.png", height: 1.10in))
            place(center + horizon,
              dy: 0.22in,
              text(size: 12pt, weight: "bold", tracking: 2.2pt,
                   font: "EB Garamond", upper[The Ark · Pico]))
            place(center + horizon,
              dy: 0.50in,
              text(size: 8pt, style: "italic",
                   [one disk, one and forty-four hundredths]))
            place(center + horizon,
              dy: 0.66in,
              text(size: 8pt, style: "italic",
                   [of a megabyte, two files]))
            place(center + horizon,
              dy: 0.92in,
              text(size: 6pt, tracking: 1.2pt,
                   upper[the smallest ark that is still an ark]))

            // Footer dedication
            place(bottom + center,
              dy: -0.34in,
              text(size: 6pt, tracking: 1.4pt,
                   upper[For the Desk of the Chief Information Officer]))
            place(bottom + center,
              dy: -0.22in,
              text(size: 6pt, tracking: 1.4pt,
                   upper[· MMXXVI ·]))
          }))))

  // ---------- LEFT GLUE TAB (cream, hinted with hatching) ----------
  // Diagonal hatch lines so the tab reads as "glue here" without ink coverage.
  let hatch(x, y, w, h) = {
    let n = 8
    for i in range(n) {
      let t = i / (n - 1)
      place(top + left,
        dx: x + t * w,
        dy: y,
        line(length: h * 1.4, angle: 60deg,
             stroke: (paint: ink, thickness: 0.15pt)))
    }
  }
  // Light hatching is fine — it'll be hidden inside the sleeve once folded.
  // hatch(left_tab_x + 0.05in, oy + 0.20in, tab_w - 0.10in, panel_h - 0.40in)
  // hatch(right_tab_x + 0.05in, oy + 0.20in, tab_w - 0.10in, panel_h - 0.40in)

  // Tab labels (small caps, vertical) — so the printer knows which side glues
  place(top + left,
    dx: left_tab_x + tab_w / 2 - 0.04in,
    dy: oy + panel_h / 2 + 0.4in,
    rotate(-90deg, reflow: false,
      text(size: 5.4pt, tracking: 1.0pt, upper[fold · glue])))
  place(top + left,
    dx: right_tab_x + tab_w / 2 - 0.04in,
    dy: oy + panel_h / 2 - 0.4in,
    rotate(90deg, reflow: false,
      text(size: 5.4pt, tracking: 1.0pt, upper[fold · glue])))

  // ---------- ASSEMBLY HINT (just outside the sleeve, top of page) ----------
  place(top + center,
    dy: 0.55in,
    text(size: 7pt, tracking: 1.4pt,
         upper[cut on dotted · fold on dashed · glue tabs behind]))
  place(top + center,
    dy: 0.72in,
    text(size: 7pt, style: "italic",
         [a sleeve for one floppy disk, three-and-a-half-inch]))
}

// ==================================================================
// PAGE 1 — DISK I — READ_FIRST.TXT
// ==================================================================
#sleeve(
  disk_no: "I",
  filename: "READ_FIRST.TXT",
  when_to_open: "When the auditors arrive, open this disk.",
  subtitle: "The Predecessor Defense",
  body: [
    A complete inventory of the systems you did not build, the decisions you did not make, and the risk registers signed off long before your arrival.

    Read aloud, in order, until the auditors stop nodding.

    File this disk somewhere they will not look — but somewhere you can find it before the next quarter closes.
  ]
)

#pagebreak()

// ==================================================================
// PAGE 2 — DISK II — STRATEGY.TXT
// ==================================================================
#sleeve(
  disk_no: "II",
  filename: "STRATEGY.TXT",
  when_to_open: "When morale drops, open this disk.",
  subtitle: "The Reorganisation",
  body: [
    A complete organisational chart with every title shifted exactly one box to the right.  Print, distribute, schedule the all-hands.

    Bonus file `VISION.TXT` — the word *synergy*, repeated until the disk is full.

    Reorgs do not solve problems.  They restart the clock.  This disk restarts the clock.
  ]
)

#pagebreak()

// ==================================================================
// PAGE 3 — DISK III — SUCCESSION.TXT
// ==================================================================
#sleeve(
  disk_no: "III",
  filename: "SUCCESSION.TXT",
  when_to_open: "When all else fails, open this disk.",
  subtitle: "The Last Instruction",
  body: [
    Format three blank floppies.  Label them in oxblood ink.  Write a welcome note to the next Chief Information Officer.

    Leave the disks in the top drawer of the desk.  Leave the desk.

    The office is a relay.  You are not the runner; you are the baton.  Pass cleanly.
  ]
)
