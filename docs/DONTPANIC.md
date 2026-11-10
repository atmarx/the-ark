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

The internet holds more of what people know than anything before it.
It's also fragile.  A natural disaster, an infrastructure failure, a
political decision, or a company going under can put any part of it out
of reach, for a day or for good.

The Ark is a hedge against that fragility. It's a curated snapshot of
human knowledge stored on commodity hard drives, readable with free
software, designed to be useful when the internet isn't available.

## What's On It

Three loadouts, sized for whatever drives you have lying around:

| Loadout | Drive Size | Content |
|---------|-----------|---------|
| **mini** | 250 GB SSD | Wikipedia (text only), medical, survival, programming |
| **medium** | 500 GB | Wikipedia with images, 70,000 books, field manuals, textbooks |
| **mega** | 1 TB | Medium plus Stack Overflow, Wikipedia in 9 more languages, TED Talks |

Every loadout also includes:
- **Kiwix readers** for Windows, macOS, Linux, and Android
- **Linux ISOs** to boot a computer from bare metal
- **Medical references** (Where There Is No Doctor, WikiMed, MedlinePlus, WikEM)
- **Repair guides** (iFixit), **textbooks** (Wikibooks), **dictionaries** (Wiktionary)
- **Survival guides** (water, food, knots, post-disaster recovery)
- **Primary source documents** (Wikisource: constitutions, treaties, speeches)
- **Accountability archives** (public court documents)
- **A README** explaining what the drive is and how to use it

See [SOURCES.md](SOURCES.md) for the complete content inventory.

## How Big Is This, Really?

Your kids asked. So did ours. Here's what these drives would look like
if you printed them.

### mini (250 GB): a university library

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

### medium (500 GB): a wing of a national library

Everything in mini, plus images and 70,000 books.  (The field manuals and
textbooks added in 2026 aren't counted here.)

| Addition | Est. Words | Printed Pages | Physical Equivalent |
|----------|-----------|---------------|-------------------|
| Wikipedia images | — | — | ~4 million photographs and diagrams |
| Project Gutenberg | ~5 billion | ~16.6 million | 33,300 volumes of classic literature |
| **medium total** | **~16.5 billion** | **~55 million** | **~110,000 volumes** |

### mega (1 TB): a small national library

Everything in medium, plus 9 more languages of Wikipedia.

| Addition | Est. Words | Printed Pages | Physical Equivalent |
|----------|-----------|---------------|-------------------|
| Wikipedia ES/ZH/FR/DE/RU/JA/PT/AR/HI | ~8 billion | ~26 million | 53,000 volumes |
| TED Talks (video) | ~65 million spoken | ~2,400 hours of video | 100 days nonstop |
| **mega total** | **~24.5 billion** | **~81 million** | **~163,000 volumes** |

### In perspective

- The **Library of Congress** holds about 17 million books.  At a typical
  80,000 words each, that's over a trillion words, roughly **50 times** a
  mega drive.  The Ark is a selection, not a national library.
- The **Library of Alexandria** at its peak held an estimated 400,000 scrolls.
  A single mega drive holds the equivalent of **163,000 bound volumes**.
- Printed double-sided on paperback paper, the mega loadout would make a
  stack about **2.5 miles tall** (4 km).
- At 250 words per minute reading speed, the mega loadout would take
  **186 years** of continuous reading to finish.
- The whole thing fits in a fireproof bag that costs about $8.

## How It Works

1. **Install Kiwix**, a free offline reader.  It's already on the drive in
   the `kiwix/` folder, for every major platform.

2. **Open Kiwix** and point it at the `zim/` folder on the drive.

3. **Browse.** Wikipedia, dictionaries, repair guides, textbooks, medical
   references, all offline.  Searchable and cross-linked, like the
   original sites.

## How to Build Your Own

The Ark is built with a set of Bash scripts that automate everything:

```bash
# Search what's available
./ark catalog search wikipedia

# Download a loadout
./ark sync medium --method=torrent

# Secure-erase, stress-test, and stamp a drive
./ark stamp medium /dev/sdb

# That's it. You have an ark.
```

The stamp pipeline is thorough: it secure-erases the drive (a full
stress test that exercises every sector), runs a SMART health analysis
to make sure the drive survived, then partitions, formats, clones,
and fills remaining space with zeros. If a drive can't survive the
wipe, it shouldn't be trusted with knowledge meant to last decades.

## The Physical Kit

The wall-mount version:

| Item | Cost |
|------|------|
| "Break Glass In Case Of Emergency" box | ~$32 |
| 1 TB hard drive (used) | ~$10 |
| USB 3.0 to SATA adapter | ~$2.50 |
| USB-A to USB-C adapter | ~$1 |
| Printed card: "This drive contains a snapshot of human knowledge" | ~$0 |
| **Total** | **~$46** |

The go-bag version:

| Item | Cost |
|------|------|
| Fireproof document bag (9"x13") | ~$8 |
| 500 GB hard drive (used) | ~$5 |
| USB 3.0 to SATA adapter | ~$2.50 |
| USB-A to USB-C adapter | ~$1 |
| **Total** | **~$17** |

## Philosophy

- **Assume the worst, build for it.** Not because the worst is likely,
  but because the cost of preparation is trivial compared to the cost of loss.
- **Use what you have.** Old drives, used SSDs, whatever's in the junk drawer.
  An imperfect ark beats no ark.
- **Knowledge should be free.** Everything on this drive is public domain,
  Creative Commons, or openly licensed. No subscriptions, no paywalls,
  no DRM.
- **Include the hard parts.** A real archive doesn't sanitize history.
  The `shame/` folder exists because accountability matters.
- **Spread it.** Copy this drive. Give it away. Seed the torrents.
  The more copies exist, the harder it is to lose.

## Credits

Content sourced from: [Wikimedia Foundation](https://wikimediafoundation.org),
[Project Gutenberg](https://gutenberg.org), [Kiwix](https://kiwix.org),
[Stack Exchange](https://stackexchange.com), [iFixit](https://ifixit.com),
[Hesperian Health Guides](https://hesperian.org), [DevDocs](https://devdocs.io),
[PhET Interactive Simulations](https://phet.colorado.edu), [LibreTexts](https://libretexts.org), [TED](https://ted.com),
[OpenStreetMap](https://openstreetmap.org), [Internet Archive](https://archive.org),
and the maintainers of Debian, Rocky Linux, Arch Linux, and Tails.

Built with [the-ark](https://github.com/atmarx/the-ark).

---

*"I wish you peace & good health!"* — RJ Whelan, medical herbalist,
whose site we hope to include in a future version.
