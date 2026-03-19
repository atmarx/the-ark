# DON'T PANIC

```
   ░██    ░██                      ░███    ░█████████  ░██     ░██
   ░██    ░██                     ░██░██   ░██     ░██ ░██    ░██
░████████ ░████████   ░███████   ░██  ░██  ░██     ░██ ░██   ░██
   ░██    ░██    ░██ ░██    ░██ ░█████████ ░█████████  ░███████
   ░██    ░██    ░██ ░█████████ ░██    ░██ ░██   ░██   ░██   ░██
   ░██    ░██    ░██ ░██        ░██    ░██ ░██    ░██  ░██    ░██
    ░████ ░██    ░██  ░███████  ░██    ░██ ░██     ░██ ░██     ░██
```

**An offline knowledge archive for when the internet isn't there.**

## Why

The internet is the greatest repository of human knowledge ever assembled.
It is also fragile. A single natural disaster, infrastructure failure,
political decision, or corporate bankruptcy can make any part of it
inaccessible — temporarily or permanently.

The Ark is a hedge against that fragility. It's a curated snapshot of
human knowledge stored on commodity hard drives, readable with free
software, designed to be useful when the internet isn't available.

Not if. When.

## What's On It

Three loadouts, sized for whatever drives you have lying around:

| Loadout | Drive Size | Content |
|---------|-----------|---------|
| **mini** | 240-250 GB SSD | Wikipedia (text), medical, survival, programming |
| **medium** | 500 GB | Full Wikipedia with images, 70,000 books, everything |
| **mega** | 1 TB | Medium + Stack Overflow + 9 language Wikipedias + TED Talks |

Every loadout also includes:
- **Kiwix readers** for Windows, macOS, Linux, and Android
- **Linux ISOs** to boot a computer from bare metal
- **Medical references** (Where There Is No Doctor, WikiMed, MedlinePlus)
- **Repair guides** (iFixit), **textbooks** (Wikibooks), **dictionaries** (Wiktionary)
- **Primary source documents** (Wikisource — constitutions, treaties, speeches)
- **Accountability archives** (public court documents)
- **A README** explaining what the drive is and how to use it

See [SOURCES.md](SOURCES.md) for the complete content inventory.

## How Big Is This, Really?

My kids asked. Yours might too. Here's what these drives would look like
if you printed them.

### mini (240 GB) — A university library

| Content | Est. Words | Printed Pages | Physical Equivalent |
|---------|-----------|---------------|-------------------|
| Wikipedia EN (text only) | ~4.4 billion | ~14.6 million | 29,300 volumes (500 pp each) |
| Simple English Wikipedia | ~120 million | ~400,000 | 800 volumes |
| Stack Overflow | ~3.2 billion | ~10.6 million | 21,300 volumes |
| Wiktionary | ~250 million | ~833,000 | 1,600 volumes |
| Wikibooks | ~45 million | ~150,000 | 300 volumes |
| Wikisource | ~3 billion | ~10 million | 20,000 volumes |
| Stack Exchange (10 sites) | ~400 million | ~1.3 million | 2,700 volumes |
| Everything else | ~100 million | ~333,000 | 600 volumes |
| **mini total** | **~11.5 billion** | **~38 million** | **~76,600 volumes** |

### medium (500 GB) — A national library wing

Everything in mini, plus images, plus 70,000 books.

| Addition | Est. Words | Printed Pages | Physical Equivalent |
|----------|-----------|---------------|-------------------|
| Wikipedia images | — | — | ~4 million photographs and diagrams |
| Project Gutenberg | ~5 billion | ~16.6 million | 33,300 volumes of classic literature |
| **medium total** | **~16.5 billion** | **~55 million** | **~110,000 volumes** |

### mega (1 TB) — The Library of Alexandria, rebuilt

Everything in medium, plus 9 more languages of Wikipedia.

| Addition | Est. Words | Printed Pages | Physical Equivalent |
|----------|-----------|---------------|-------------------|
| Wikipedia ES/ZH/FR/DE/RU/JA/PT/AR/HI | ~8 billion | ~26 million | 53,000 volumes |
| TED Talks (video) | ~65 million spoken | ~2,400 hours of video | 100 days nonstop |
| **mega total** | **~24.5 billion** | **~81 million** | **~163,000 volumes** |

### In perspective

- The **Library of Congress** holds ~17 million books. The mega loadout
  is roughly **10x the word count** (the LoC has many short works;
  Wikipedia articles are dense).
- The **Library of Alexandria** at its peak held an estimated 400,000 scrolls.
  A single mega drive holds the equivalent of **163,000 bound volumes** —
  and none of it will burn.
- Printing the mega loadout at standard paperback density would produce a
  stack of paper **5.4 miles tall** (8.7 km).
- At 250 words per minute reading speed, the mega loadout would take
  **188 years** of continuous reading to finish.
- The entire archive fits in a fireproof bag that costs $7.50.

## How It Works

1. **Install Kiwix** — a free, offline content reader. It's on the drive
   already, in the `kiwix/` folder. Available for every major platform.

2. **Open Kiwix** and point it at the `zim/` folder on the drive.

3. **Browse.** Wikipedia, dictionaries, repair guides, textbooks, medical
   references — all completely offline. Searchable. Cross-linked.
   Just like the real thing, minus the ads.

## How to Build Your Own

The Ark is built with a set of Bash scripts that automate everything:

```bash
# Search what's available
./ark catalog search wikipedia

# Download a loadout
./ark sync medium --method=torrent

# Health-check and stamp a drive
./ark stamp medium /dev/sdb

# That's it. You have an ark.
```

See the [project page](https://github.com/atmarx/the-ark) for details.

## The Physical Kit

The wall-mount version:

| Item | Cost |
|------|------|
| "Break Glass In Case Of Emergency" box | ~$32 |
| 1 TB hard drive (used) | ~$10 |
| USB 3.0 to SATA adapter | ~$2.50 |
| USB-A to USB-C adapter | ~$1 |
| Anti-static bag + desiccant | ~$2 |
| Printed card: "This drive contains a snapshot of human knowledge" | ~$0 |
| **Total** | **~$48** |

The go-bag version:

| Item | Cost |
|------|------|
| Fireproof document bag (9"x13") | ~$8 |
| 500 GB hard drive (used) | ~$5 |
| USB 3.0 to SATA adapter | ~$2.50 |
| USB-A to USB-C adapter | ~$1 |
| Anti-static bag + desiccant | ~$2 |
| **Total** | **~$19** |

## Keeping It Alive

A used hard drive that passes SMART checks has a realistic unpowered
shelf life of **5-10 years**, often much longer. The enemy isn't
sudden failure — it's moisture, temperature swings, and time.

**Store it right:** Anti-static bag (the silvery kind) with a
desiccant pack inside, folded shut, inside the fireproof bag.
Don't vacuum seal — drives have a breather hole that needs
atmospheric pressure.

**Make several.** Two drives in different buildings beats one
perfectly stored drive. Drives from ewaste are free. The data is
identical. Treat them like seeds — scatter them widely.

**Check occasionally.** Spin a drive up every year or two and run
`ark verify` to confirm the checksums. If SMART starts warning,
copy to a fresh drive and retire the old one.

See [Drive Care](drive-care.md) for the full guide — 2.5" vs 3.5"
drives, EMP shielding, maintenance schedules, and what not to do.

## From Ewaste to Archive

Got access to old drives? You were going to wipe them anyway.

`ark stamp` runs a SMART health check, formats the drive, clones the
loadout, and then **zero-fills the remaining free space** — a full
overwrite of whatever was on the disk before. One command, and a drive
headed for the recycling bin becomes a copy of the best library ever
assembled.

Every ewaste event, every office cleanout, every box of old laptop
drives in a closet — that's not junk. That's a fleet of arks waiting
to happen.

## Philosophy

- **Assume the worst, build for it.** Not because the worst is likely,
  but because the cost of preparation is trivial compared to the cost of loss.
- **Use what you have.** Old drives, used SSDs, whatever's in the junk drawer.
  An imperfect ark is infinitely better than no ark.
- **Knowledge should be free.** Everything on this drive is public domain,
  Creative Commons, or openly licensed. No subscriptions, no paywalls,
  no DRM. Just knowledge.
- **Include the hard parts.** A real archive doesn't sanitize history.
  The `shame/` folder exists because accountability matters.
- **Spread it.** Copy this drive. Give it away. Seed the torrents.
  The more copies exist, the harder it is to lose.

## Credits

Content sourced from: [Wikimedia Foundation](https://wikimediafoundation.org),
[Project Gutenberg](https://gutenberg.org), [Kiwix](https://kiwix.org),
[Stack Exchange](https://stackexchange.com), [iFixit](https://ifixit.com),
[Hesperian Health Guides](https://hesperian.org), [DevDocs](https://devdocs.io),
[PhET Interactive Simulations](https://phet.colorado.edu), [TED](https://ted.com),
[OpenStreetMap](https://openstreetmap.org), [Internet Archive](https://archive.org),
and the maintainers of Debian, Rocky Linux, Arch Linux, and Tails.

Built with [the-ark](https://github.com/atmarx/the-ark).

---

I wish you peace & good health in whatever lies ahead.