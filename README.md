# the-ark

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

A CLI tool that builds curated snapshots of human knowledge onto
commodity hard drives. Wikipedia, 70,000 books, medical references,
repair guides, programming docs, Linux ISOs — readable offline with
[Kiwix](https://kiwix.org), no internet required.

## Quick Start

```bash
./ark catalog search wikipedia       # Browse what's available
./ark sync medium --method=torrent   # Download the medium loadout (~384 GB)
./ark stamp medium /dev/sdb          # Health-check, format, and stamp a drive
```

## Loadouts

| Loadout | Target Drive | ZIMs | Content |
|---------|-------------|------|---------|
| **mini** | 240 GB SSD | ~248 | Wikipedia (text), medical, survival, programming |
| **medium** | 500 GB HDD | ~250 | Full Wikipedia + images, 70K books, everything |
| **mega** | 1 TB HDD | ~268 | Medium + 9 language Wikipedias, Stack Overflow, TED Talks |

See [SOURCES.md](docs/SOURCES.md) for the complete content inventory.

## What's the Point?

The internet is fragile. A disaster, an outage, a political decision —
any of it can make knowledge inaccessible. This project puts a curated
copy of humanity's most important knowledge on a drive you can hold in
your hand, for less than the cost of a pizza dinner.

Got a pile of old 500 GB laptop drives from an ewaste bin? Each one
can carry the medium loadout — the equivalent of **55 million printed
pages** and **110,000 volumes**. Toss in a $2.50 USB-to-SATA adapter
and a fireproof bag, and you've got the best library ever assembled
for under $20.

You were going to wipe those drives anyway. `ark stamp` SMART-checks
the drive, formats it, clones the loadout, and zero-fills the remaining
space — a full overwrite of whatever was on the disk before. Responsible
recycling *and* a contribution to the preservation of human knowledge,
in one pass.

Read [DON'T PANIC](docs/DONTPANIC.md) for the full story, including
what this looks like printed (spoiler: a stack of paper 5.4 miles tall).

## Commands

```
ark init <path>                  Initialize a staging area
ark sync <loadout>               Download content for a loadout
ark status <loadout>             Show what's downloaded vs manifest
ark stamp <loadout> <device>     SMART-check, format, and clone to a drive
ark seed <loadout> [--import]    Stage .torrent files, import to qBittorrent
ark clone <loadout> <dest>       Copy to a drive or remote via rclone
ark verify <loadout>             SHA-256 checksum verification
ark catalog search <query>       Search the Kiwix OPDS catalog
```

## The Physical Kit

| Item | Cost |
|------|------|
| 500 GB / 1 TB drive (used) | ~$5-10 |
| USB 3.0 to SATA adapter | ~$2.50 |
| USB-A to USB-C adapter | ~$1 |
| Anti-static bag + desiccant | ~$2 |
| Fireproof bag (9"x13") | ~$8 |
| **Total** | **~$19-24** |

Store the drive in the anti-static bag with desiccant, folded shut,
inside the fireproof bag. See [Drive Care](docs/drive-care.md) for
the full guide on storage, longevity, and why not to vacuum seal.

Or the conversation-starter version: put it in a
["Break Glass In Case Of Emergency" box](docs/DONTPANIC.md#the-physical-kit)
and mount it on the wall (~$48 total).

## Dependencies

```bash
# Required
apt install bash curl xmlstarlet jq bc rclone

# For torrents
apt install transmission-cli

# For stamping drives
apt install gdisk smartmontools exfatprogs

# yq (YAML parser)
curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
```

## Adding Your Own Content

You can create custom ZIM files from any website or static site and
add them to the ark. See [Custom ZIMs](docs/custom-zims.md).

## Docs

- [DON'T PANIC](docs/DONTPANIC.md) — Why this exists, what's on it, scale estimates
- [Sources](docs/SOURCES.md) — Complete content inventory with loadout comparison
- [Custom ZIMs](docs/custom-zims.md) — How to add your own content
- [Kiwix Guide](docs/kiwix-guide.md) — OPDS catalog, ZIM format, ecosystem reference
- [Drive Care](docs/drive-care.md) — Storage, longevity, and keeping your ark alive

## Credits

Content sourced from [Wikimedia](https://wikimediafoundation.org),
[Project Gutenberg](https://gutenberg.org), [Kiwix](https://kiwix.org),
[Stack Exchange](https://stackexchange.com), [iFixit](https://ifixit.com),
[Hesperian](https://hesperian.org), [DevDocs](https://devdocs.io),
[PhET](https://phet.colorado.edu), [TED](https://ted.com),
[Internet Archive](https://archive.org), and the people behind
Debian, Rocky Linux, Arch Linux, and Tails.

## License

This project is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Share it, remix it, build on it — just give credit. The content it
downloads is governed by the respective licenses of each source
(primarily CC BY-SA, public domain, and open access).

---

My hope is to look back in a decade and think: I ever needed one of these drives, and was worried for nothing.
