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

A command-line tool that builds curated offline libraries onto ordinary
hard drives: Wikipedia, 70,000 books, medical references, repair guides,
programming docs, and bootable Linux ISOs.  Everything is readable with
[Kiwix](https://kiwix.org), which ships on the drive.

## Quick Start

```bash
./ark init /path/to/staging          # Set up a staging area
./ark catalog search wikipedia       # Browse what's available
./ark sync medium --method=torrent   # Download the medium loadout (~445 GB)
./ark stamp medium /dev/sdX          # Erase, health-check, format, and fill a drive
```

`ark stamp` erases the target drive.  Check the device name twice.

## Loadouts

| Loadout | Drive | ZIM files | Content |
|---------|-------|-----------|---------|
| **mini** | 250 GB SSD | 266 | Wikipedia (text only), medical, survival, Stack Overflow |
| **medium** | 500 GB HDD | 295 | Wikipedia with images, Project Gutenberg, field manuals, textbooks |
| **mega** | 1 TB HDD | 312 | Medium plus Stack Overflow, Wikipedia in 9 more languages, TED Talks |

Most of the file count is DevDocs: 231 small archives that add up to under
1 GB.  See [SOURCES.md](docs/SOURCES.md) for the full inventory.

### Deep Thought, the LLM expansion pack

Six local language models (Gemma 4, gpt-oss, Qwen3.8) plus llama.cpp for
Windows, macOS, and Linux, about 75 GB.  It goes on top of a loadout:

```bash
./ark sync deep-thought
./ark stamp mega /dev/sdX --pack=deep-thought   # mega + models on a 2 TB drive
./ark clone deep-thought /media/THE-ARK          # add to a drive you already have
```

A launcher on the drive picks a model that fits the computer's memory and
opens a chat page in the browser.  Stock releases only, each pinned and
checksummed.  See [Deep Thought](docs/deep-thought.md).

## Why

A lot of what we know lives on servers we don't control.  An outage, a
disaster, or a policy change can put it out of reach.  The Ark puts a copy
on a drive you can hold, for about the price of a takeout dinner.

Old 500 GB laptop drives turn up in e-waste bins all the time.  One of them
holds the medium loadout, roughly 55 million printed pages.  Add a $2.50
USB-to-SATA adapter and a fireproof bag and the whole kit costs about $20.

[DON'T PANIC](docs/DONTPANIC.md) has the longer version, including what
the drives would look like printed out.

## Commands

```
ark init <path>                  Initialize a staging area
ark sync <loadout>               Download missing or outdated content
ark status <loadout>             Compare what's downloaded with the manifest
ark freshen [loadout]            Check the catalog for newer versions
ark verify <loadout>             Verify SHA-256 checksums
ark inspect <mount> [--record]   Compare an old Ark with the catalog, read-only
ark payloads <loadout>...        Publish loadouts for Za Wiper's Wipe + Load
ark stamp <loadout> <device>     Erase, SMART-check, format, and fill a drive
                                 (--pack=deep-thought adds the LLM pack)
ark clone <loadout> <dest>       Copy a loadout to a drive or remote with rclone
ark seed <loadout> [--import]    Stage .torrent files, optionally import to qBittorrent
ark publish <loadout>            Create .torrent files for custom content
ark fetch-data [--dry-run]       Mirror the Data Liberation Project dataset bucket
ark catalog search <query>       Search the Kiwix catalog
ark catalog list [flags]         List available ZIM files
ark catalog refresh              Refresh the cached catalog
```

Run `./ark help` for flags and environment variables.

## Where It Runs

The Ark runs from a checkout on whatever Linux box can see the staging
area and the drive.  There's no server and nothing to deploy.

At home, staging lives on the NAS.  On every push to `master` that touches
`ark`, `lib/`, `cmd/`, or `manifests/`, a Woodpecker pipeline
(`.woodpecker/deploy.yml`) refreshes the Kiwix catalog and
drops each loadout's `.torrent` files into a folder that qBittorrent
watches.  The drive fills itself.  The seed takes the catalog's newest
build and ignores holds in the manifests, so put `[skip ci]` on a push
that shouldn't reach qBittorrent.

## Status

Real and in use: `sync`, `status`, `freshen`, `verify`, `clone`, `stamp`,
`seed`, and the three loadouts.  Deep Thought is built, pinned, and
checksummed.  `sync` keeps every build it replaces, `ark inspect` reads an
old Ark that comes back and compares it with the catalog, and
`ark payloads` publishes loadouts for Za Wiper to load.

**Za Wiper**, the wipe-and-certify drive bays, began here and now lives in
its own repo at [github.com/atmarx/zawiper](https://github.com/atmarx/zawiper).
Its Wipe + Load job is where the two meet: a retired drive is wiped,
proven wiped, and leaves as an Ark.

## The Physical Kit

| Item | Cost |
|------|------|
| 500 GB or 1 TB drive (used) | ~$5-10 |
| USB 3.0 to SATA adapter | ~$2.50 |
| USB-A to USB-C adapter | ~$1 |
| Fireproof bag (9"x13") | ~$8 |
| **Total** | **~$17-22** |

There's also a wall-mounted
["Break Glass In Case Of Emergency" version](docs/DONTPANIC.md#the-physical-kit)
for about $46.

## Dependencies

```bash
# Required
apt install bash curl xmlstarlet jq bc rclone

# For torrents
apt install transmission-cli

# For stamping drives
apt install gdisk smartmontools exfatprogs hdparm

# yq (YAML parser)
curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
```

## Adding Your Own Content

You can turn a website or a static site into a ZIM file.  See
[Custom ZIMs](docs/custom-zims.md).

## Docs

- [DON'T PANIC](docs/DONTPANIC.md): why this exists, what's on it, how big it is
- [SOURCES](docs/SOURCES.md): full content inventory by loadout
- [Custom ZIMs](docs/custom-zims.md): making your own archives
- [Deep Thought](docs/deep-thought.md): the LLM expansion pack
- [Kiwix Guide](docs/kiwix-guide.md): the catalog, the ZIM format, and download URLs
- [Za Wiper](https://github.com/atmarx/zawiper): the drive bays that wipe a retired drive, prove it, and load an Ark
- [Voice](docs/VOICE.md): how Zim, the narrator on every drive, talks
- [Contributing](CONTRIBUTING.md)

## Credits

Content comes from [Wikimedia](https://wikimediafoundation.org),
[Project Gutenberg](https://gutenberg.org), [Kiwix](https://kiwix.org),
[Stack Exchange](https://stackexchange.com), [iFixit](https://ifixit.com),
[Hesperian](https://hesperian.org), [DevDocs](https://devdocs.io),
[PhET](https://phet.colorado.edu), [LibreTexts](https://libretexts.org),
[TED](https://ted.com), [Internet Archive](https://archive.org), the
[Data Liberation Project](https://www.data-liberation-project.org), and the
people behind Debian, Rocky Linux, Arch Linux, and Tails.  The models come
from Google, OpenAI, and Alibaba's Qwen team, and run on
[llama.cpp](https://github.com/ggml-org/llama.cpp).

## How It's Made

Idea, curation, and every call: Andrew Marx (xram).  Written with Claude,
an AI, under the name Zim, in the open.  The commits say so, and Zim is
also the voice on every drive ([Voice](docs/VOICE.md)).

## License

The code is [MIT](LICENSE).  The writing, design, and drive README are
[CC BY-SA 4.0](LICENSE-CONTENT).

The content the tool downloads is not covered by either.  Each source keeps
its own license: mostly CC BY-SA, public domain, and other open licenses.
The models are Apache 2.0.
