# Kiwix Ecosystem Reference Guide

A practical reference for working with Kiwix, ZIM files, and the OPDS catalog — everything you need to build and maintain offline knowledge archives.

---

## What is Kiwix?

Kiwix is an open-source offline content reader. It reads `.zim` archives — highly compressed, self-contained packages of web content — and serves them through a browser-like interface with full-text search. One app, runs on everything from a Raspberry Pi to a phone.

It was designed for environments with no internet: schools in rural Africa, refugee camps, countries with restricted information access. It's been deployed by NGOs worldwide and even smuggled into North Korea on USB drives.

**Key properties:**
- Completely offline — no internet required after download
- Cross-platform: Linux, Windows, macOS, Android, iOS, Raspberry Pi
- Full-text search built into ZIM files
- Can serve content over a LAN (kiwix-serve)
- Docker image available: `kiwix/kiwix-serve`

---

## The ZIM Format

ZIM (Zeno IMproved) is the de facto standard for offline content packaging. Each `.zim` file is a complete, self-contained website compressed into a single archive.

### Filename Convention

```
{source}_{language}_{scope}_{flavour}_{YYYY-MM}.zim
```

Components:
- **source**: Content origin (e.g., `wikipedia`, `wikibooks`, `ifixit`, `freecodecamp`)
- **language**: ISO language code (e.g., `en`, `es`, `zh`, `fr`)
- **scope**: Content scope, usually `all` for everything
- **flavour**: Content variant (see below)
- **date**: Year and month of the snapshot

Examples:
- `wikipedia_en_all_maxi_2026-02.zim` — Full English Wikipedia, all images, Feb 2026
- `ifixit_en_all_2025-12.zim` — iFixit repair guides, Dec 2025
- `math.stackexchange.com_en_all_2025-06.zim` — Math Stack Exchange

### Flavours

Not all ZIM files have flavours. When present:

| Flavour | Meaning |
|---------|---------|
| `maxi`  | Full content with all images, details, and full-text index |
| `mini`  | Condensed selection of articles |
| `nopic` | Full articles but no images (much smaller) |

Wikipedia ZIMs typically come in all three. Many other sources (Stack Exchange, iFixit, freeCodeCamp) have no flavour — they're just the complete archive.

### What's Inside a ZIM

A ZIM file contains:
- HTML articles with CSS styling
- Images (unless `nopic` flavour)
- A full-text search index (Xapian-based)
- Metadata (title, description, language, article count)
- A URL namespace for internal linking

---

## The OPDS Catalog

Kiwix publishes a machine-readable catalog of all available ZIM files using the [OPDS](https://opds.io/) (Open Publication Distribution System) standard — an Atom XML feed designed for ebook/content distribution.

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `https://library.kiwix.org/catalog/v2/entries` | Full catalog (paginated) |
| `https://library.kiwix.org/catalog/v2/entries?q=<query>` | Search |
| `https://library.kiwix.org/catalog/v2/entries?count=N&start=M` | Pagination |
| `https://library.kiwix.org/catalog/v2/languages` | Available languages |
| `https://library.kiwix.org/catalog/v2/categories` | Available categories |
| `https://library.kiwix.org/catalog/root.xml` | Legacy catalog root |

### Catalog Entry Structure

Each entry in the OPDS feed looks like this (Atom XML):

```xml
<entry>
  <id>urn:uuid:0008fc35-e481-37aa-093e-3637daec0f9d</id>
  <title>Wikipedia</title>
  <updated>2026-02-11T00:00:00Z</updated>
  <summary>offline version of Wikipedia in Chechen</summary>
  <language>che</language>
  <name>wikipedia_ce_all</name>
  <flavour>maxi</flavour>
  <category>wikipedia</category>
  <tags>wikipedia;_category:wikipedia;_pictures:yes;_videos:no;_details:yes;_ftindex:yes</tags>
  <articleCount>871288</articleCount>
  <mediaCount>297551</mediaCount>
  <author><name>Wikipedia</name></author>
  <publisher><name>openZIM</name></publisher>
  <dc:issued>2026-02-11T00:00:00Z</dc:issued>
  <link rel="http://opds-spec.org/acquisition/open-access"
        type="application/x-zim"
        href="https://download.kiwix.org/zim/wikipedia/wikipedia_ce_all_maxi_2026-02.zim.meta4"
        length="5995166720" />
</entry>
```

**Key fields:**
- `<name>` + `<flavour>` — together, uniquely identify a ZIM content type
- `<link rel="...acquisition/open-access">` — the download link
  - `href` points to the `.meta4` metalink file (not the ZIM directly)
  - `length` is the file size in bytes
- `<updated>` / `<dc:issued>` — when this version was published
- `<tags>` — semicolon-separated, includes `_pictures:yes/no`, `_ftindex:yes/no`

### Pagination

The catalog contains ~3400+ entries. The API paginates:

```
GET /catalog/v2/entries?count=100&start=0    → entries 0-99
GET /catalog/v2/entries?count=100&start=100  → entries 100-199
...
```

The root `<feed>` element includes:
- `<totalResults>3454</totalResults>` — total count
- `<startIndex>0</startIndex>` — current offset
- `<itemsPerPage>100</itemsPerPage>` — page size

### Namespaces

The catalog XML uses these namespaces:
- Default: `http://www.w3.org/2005/Atom`
- `dc`: `http://purl.org/dc/terms/`
- `opds`: `https://specs.opds.io/opds-1.2`
- `opensearch`: `http://a9.com/-/spec/opensearch/1.1/`

**Important:** When the catalog entries are extracted from their `<feed>` wrapper (as the ark tool does for caching), the namespace declarations are lost. The cached XML uses bare element names without namespace prefixes.

---

## Download URLs

All ZIM files are hosted at `https://download.kiwix.org/zim/`.

### URL Structure

```
https://download.kiwix.org/zim/{category}/{filename}.zim
```

The category is the content type directory:
- `wikipedia/`, `wiktionary/`, `wikibooks/`, `wikisource/`, `wikiquote/`, `wikivoyage/`
- `stack_exchange/`
- `gutenberg/`
- `ifixit/`
- `freecodecamp/`
- `devdocs/`
- `phet/`
- `ted/`
- And [many more](https://download.kiwix.org/zim/)

### Deriving URLs from Catalog Entries

The catalog's `<link>` `href` points to a `.meta4` file. To get related URLs:

| What you want | How to derive it |
|---------------|------------------|
| Direct download | Strip `.meta4` from the href |
| Metalink (checksums) | Use the href as-is |
| Torrent | Replace `.meta4` with `.torrent` |

Example:
```
Catalog href:  https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2026-02.zim.meta4
Direct:        https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2026-02.zim
Torrent:       https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2026-02.zim.torrent
```

---

## Checksums and Verification (Meta4 / Metalink)

Kiwix uses the [Metalink](https://en.wikipedia.org/wiki/Metalink) format (`.meta4` files) for download metadata including checksums and mirror URLs.

### Meta4 File Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<metalink xmlns="urn:ietf:params:xml:ns:metalink">
  <generator>MirrorBrain/2.19.0</generator>
  <origin dynamic="true">https://download.kiwix.org/zim/.../foo.zim.meta4</origin>
  <published>2026-03-15T05:49:00Z</published>
  <publisher>
    <name>Kiwix project</name>
    <url>https://kiwix.org</url>
  </publisher>
  <file name="foo.zim">
    <size>10844138</size>
    <hash type="md5">ec65db34a6be723da1affae1dfc052f7</hash>
    <hash type="sha-1">b7be50c48027f1f1b2d4fef6c0873ca204679edf</hash>
    <hash type="sha-256">9eaaebea4f800c26f4a56ebe336b4a13f85b81cbedac10b0abafc3fc78f7e9d3</hash>
    <pieces length="4194304" type="sha-1">
      <hash>67bfdcb9e4cbef3d9ae0e54416f4fe927f6b78ec</hash>
      <hash>...</hash>
    </pieces>
    <url location="us" priority="1">https://mirror1.example.com/foo.zim</url>
    <url location="us" priority="2">https://mirror2.example.com/foo.zim</url>
    <!-- More mirrors... -->
  </file>
</metalink>
```

### Extracting SHA-256 with xmlstarlet

```bash
xmlstarlet sel -N ml="urn:ietf:params:xml:ns:metalink" \
  -t -v '//ml:hash[@type="sha-256"]' \
  foo.zim.meta4
```

The namespace `urn:ietf:params:xml:ns:metalink` is required — bare XPath won't match.

### Available Hashes

Each meta4 file provides:
- MD5
- SHA-1
- SHA-256 (recommended for verification)
- SHA-1 piece hashes (4MB chunks, for BitTorrent-style verification)

### Mirror URLs

The meta4 file also lists download mirrors with geographic location hints (`location="us"`) and priority rankings. These are full direct-download URLs that bypass the main Kiwix server.

---

## Kiwix Software Releases

Platform binaries are published at `https://download.kiwix.org/release/`.

### Release Directories

| Directory | Contents |
|-----------|----------|
| `kiwix-android/` | Android APKs |
| `kiwix-desktop/` | Desktop source tarballs |
| `kiwix-js-electron/` | Cross-platform Electron app (AppImage, Windows, macOS) |
| `kiwix-macos/` | macOS DMGs |
| `kiwix-tools/` | CLI tools including kiwix-serve (Linux, Windows binaries) |

### kiwix-serve

`kiwix-serve` is a lightweight HTTP server that serves ZIM files over a network. It's the backbone for making an ark available on a LAN.

```bash
# Serve all ZIM files on port 8080
kiwix-serve --port 8080 /path/to/*.zim

# Or via Docker
docker run -v /path/to/zims:/data -p 8080:80 kiwix/kiwix-serve '*.zim'
```

Binary naming convention for kiwix-tools:
```
kiwix-tools_{platform}-{arch}-{version}.{ext}
```
Examples:
- `kiwix-tools_linux-x86_64-3.8.1.tar.gz`
- `kiwix-tools_linux-aarch64-3.8.1.tar.gz` (Raspberry Pi / ARM)
- `kiwix-tools_win-x86_64-3.8.1.zip`

---

## Querying the Catalog with xmlstarlet

Since the ark tool caches the catalog as a single XML file with bare (non-namespaced) element names, queries are straightforward:

```bash
# Find an entry by name and flavour
xmlstarlet sel -t -m "//entry[name='wikipedia_en_all'][flavour='maxi']" \
  -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@href" -n \
  catalog-cache.xml

# Search by name (case-insensitive via translate)
xmlstarlet sel -t \
  -m "//entry[contains(translate(name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'stack')]" \
  -v "name" -o $'\t' -v "flavour" -o $'\t' \
  -v "link[@rel='http://opds-spec.org/acquisition/open-access']/@length" -n \
  catalog-cache.xml

# Count total entries
xmlstarlet sel -t -v "count(//entry)" catalog-cache.xml

# List all categories
xmlstarlet sel -t -m "//entry" -v "category" -n catalog-cache.xml | sort -u
```

---

## Useful Links

- **Kiwix Library** (browse/preview): https://library.kiwix.org
- **Direct downloads**: https://download.kiwix.org/zim/
- **Release binaries**: https://download.kiwix.org/release/
- **Zimit** (create ZIM from any website): https://youzim.it
- **Kiwix GitHub**: https://github.com/kiwix
- **OPDS spec**: https://specs.opds.io/opds-1.2
- **ZIM format spec**: https://wiki.openzim.org/wiki/ZIM_file_format
- **Kiwix Wiki**: https://wiki.kiwix.org

---

## Tips

1. **Use torrents for files over 10 GB.** Direct HTTP works fine, but torrents are more resilient for the 100+ GB Wikipedia archives.

2. **The meta4 mirrors are real.** If the main Kiwix download server is slow, fetch the meta4 first and use one of the mirror URLs directly.

3. **ZIM files are content-addressed by date.** The filename includes `YYYY-MM`, so you can have multiple versions coexisting. Old versions are safe to delete once the new one is verified.

4. **Full-text search is opt-in.** The `_ftindex:yes` tag in the catalog tells you if the ZIM includes a search index. `maxi` flavour always has it; `nopic` and `mini` usually do too.

5. **Stack Exchange ZIMs don't have a flavour.** They're just `{site}_en_all_{date}.zim`. The catalog's `<flavour>` element is empty.

6. **Kiwix can serve multiple ZIMs simultaneously.** Point kiwix-serve at a directory of ZIM files and it presents them all through a single web interface with unified search.
