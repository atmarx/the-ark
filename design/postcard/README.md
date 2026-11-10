# Ark Postcards

Single-ink, home-laser-safe print designs for slipping into library books,
taping over the e-waste bin, tucking under a windshield wiper.
Five sheets, two voices.

- **Sheet:** 8.5″ × 11″ US letter, portrait
- **Ink:** one color per sheet — home laser or risograph friendly

## The sheets

| File | Philosophy | Layout | Trim | Typeface |
|---|---|---|---|---|
| `postcard.typ` → `postcard.pdf` | [Cartographer's Mercy](philosophy.md) | 6-up (2 × 3) | 4.25″ × 3.667″ | EB Garamond |
| `mini.typ` → `mini.pdf` | Cartographer's Mercy | 10-up (2 × 5) | 3.5″ × 2″ (business card) | EB Garamond |
| `mega.typ` → `mega.pdf` | Cartographer's Mercy | 1-up, single broadside | 8.5″ × 11″ | EB Garamond |
| `concrete.typ` → `concrete.pdf` | [Concrete Poetry](concrete-philosophy.md) | 6-up (2 × 3) | 4.25″ × 3.667″ | Inter + JetBrains Mono |
| `floppy-sleeves.typ` → `floppy-sleeves.pdf` | Cartographer's Mercy | 3 pages, one fold-and-glue sleeve each | 3.5″ floppy | EB Garamond |

The Cartographer's Mercy sheets share one emblem, a raven carrying a book
(`raven.png`).  Noah sent the raven out first (Genesis 8:7).  The earlier
dove emblem (`dove.svg`) is kept for reference but no longer used.

*Cartographer's Mercy* is the field-journal look: ledger rules, ruled
margins, old-style numerals.  *Concrete Poetry* is the Swiss opposite: one
big grotesque numeral, monospaced figures, hairline rules.

## Build

```
./design/postcard/build.sh
```

The script self-bootstraps: if `design/.tools/typst` is missing, it downloads
the `v0.14.2` static musl binary from GitHub releases; if the fonts are
missing, it fetches EB Garamond (OFL), Inter (OFL), and JetBrains Mono
(OFL) from upstream.  Nothing is installed system-wide.  `design/.tools/`
is gitignored.

Re-download everything from scratch with:

```
./design/postcard/build.sh --reinstall
```

All five PDFs are rebuilt on every run.

## Output

- `*.typ`: Typst source.  The design lives in these files.
- `*.pdf`: the printable sheets, committed so you don't need Typst to print.
- `raven.png`: the shared raven-and-book emblem.

## Design philosophies

- [`philosophy.md`](philosophy.md): *Cartographer's Mercy*
- [`concrete-philosophy.md`](concrete-philosophy.md): *Concrete Poetry*
