# Creating Custom ZIM Files

You can add any website or local content to the ark by converting it
into a ZIM file. This guide covers the two main scenarios:

1. **Crawling a live website** into a ZIM
2. **Converting a local static site** (mkdocs, Hugo, Jekyll, etc.) into a ZIM

Once it's built, see [Adding Your ZIM to the Ark](#adding-your-zim-to-the-ark)
below.  The short version: `ark clone` picks it up, `ark stamp` doesn't yet.

## Option 1: Crawl a Live Website (zimit)

[zimit](https://github.com/openzim/zimit) is a Docker-based tool from
the openZIM project that crawls a website and produces a ZIM file.
It handles JavaScript rendering, so it works with modern sites.

### Basic Usage

```bash
docker run -v /tmp/zim-output:/output ghcr.io/openzim/zimit \
    --url "https://example.com/" \
    --name "example" \
    --lang "eng" \
    --title "Example Site" \
    --description "A useful reference site" \
    --output /output/
```

This will crawl the site and produce a ZIM in `/tmp/zim-output/`.

### Useful Flags

```bash
--limit 10000            # Max pages to crawl (default: no limit)
--scope "https://example.com/"
                         # Stay within this URL prefix
--exclude "login|admin"  # Regex of URL patterns to skip
--behaviors "autoplay,autoscroll"
                         # Browser behaviors during crawl
--lang "eng"             # ISO 639-3 language code
--creator "Site Author"  # Attribution
--publisher "the-ark"    # Your name/org
```

### Example: Crawling a Herbalism Reference

```bash
docker run -v /tmp/zim-output:/output ghcr.io/openzim/zimit \
    --url "https://rjwhelan.co.nz/" \
    --name "rjwhelan_herbs" \
    --lang "eng" \
    --title "Richard Whelan - Medical Herbalism" \
    --description "Herbs A-Z, conditions, constitutional medicine" \
    --creator "Richard Whelan" \
    --publisher "the-ark" \
    --output /output/
```

### Tips for Crawling

- **Always ask permission** before archiving someone's site. It's their
  life's work; treat it with respect.
- **Check the license.** The site needs to be CC, public domain, or you
  need explicit permission from the author.
- **Test with a small limit first** (`--limit 50`) to make sure the
  crawl is finding the right pages.
- **Old HTML is fine.** zimit handles hand-written HTML from 2005 better
  than many modern JavaScript-heavy sites.
- **Watch for odd URL structures.** Some sites use spaces in directory
  names or inconsistent naming.  zimit usually copes, but check the
  output.

## Option 2: Convert a Local Static Site (zimwriterfs)

If you have a locally-built static site (mkdocs, Hugo, Jekyll, Sphinx,
or plain HTML), you can convert the build output directly into a ZIM
without crawling.

### Install zimwriterfs

```bash
# Debian/Ubuntu
sudo apt install zim-tools

# Or via Docker
docker pull ghcr.io/openzim/zim-tools
```

### Build Your Site First

```bash
# mkdocs
mkdocs build          # output in site/

# Hugo
hugo                  # output in public/

# Jekyll
jekyll build          # output in _site/

# Sphinx
make html             # output in _build/html/
```

### Convert to ZIM

```bash
zimwriterfs \
    --welcome "index.html" \
    --illustration "illustration.png" \
    --language "eng" \
    --title "My Knowledge Base" \
    --description "Offline reference for ..." \
    --creator "Your Name" \
    --publisher "the-ark" \
    --name "my_knowledge_base" \
    ./site/ \
    ./my_knowledge_base.zim
```

The two positional arguments are the build output directory (the folder
containing `index.html`) and the ZIM file to write.  `--illustration` must
be a 48x48 PNG; older zim-tools releases called this `--favicon`.

### Example: Converting a mkdocs Site

```bash
# Build the site
cd ~/projects/keepyourteeth
mkdocs build

# Convert to ZIM
zimwriterfs \
    --welcome "index.html" \
    --illustration "img/illustration.png" \
    --language "eng" \
    --title "Keep Your Teeth" \
    --description "Dental self-care guide" \
    --creator "Your Name" \
    --publisher "the-ark" \
    --name "keepyourteeth" \
    ./site/ \
    ./keepyourteeth_en_all.zim
```

### Tips for Static Sites

- **Use the build output, not the source.** Point zimwriterfs at `site/`,
  `public/`, or `_site/`: the compiled HTML, not the markdown source.
- **Check your welcome page.** It must be relative to the root of the
  directory you're converting. Usually `index.html`.
- **Include assets.** Make sure CSS, JS, and images are in the build
  output. zimwriterfs will bundle everything it finds.
- **Test the ZIM** by opening it in Kiwix before adding it to the ark.

## Option 3: Submit to the Official Kiwix Library

If your content is openly licensed, you can request that the openZIM
team add it to the official Kiwix library. This means:

- It gets auto-built and refreshed on their schedule
- It appears in `ark catalog search` for everyone
- Every ark in the world can include it

### How to Submit

1. Open an issue at [openzim/zim-requests](https://github.com/openzim/zim-requests)
2. Provide:
   - **URL** of the website
   - **Title** and **description**
   - **Language** (ISO code)
   - **License** (must be CC, public domain, or author permission)
3. If it's accepted, the openZIM team sets up a recipe on their zimfarm
4. The ZIM shows up in the catalog after its first build, and is rebuilt
   on a schedule from then on

Expect this to take a while; it's a volunteer project.  It's still the
best path for content that should outlive any one person's copy.

## Adding Your ZIM to the Ark

Once you have a ZIM file:

Copy it into the loadout's folder in your staging area:

```bash
cp my_custom_content.zim "$ARK_STAGING/medium/zim/"
```

`ark clone` copies everything in the loadout folder, so the ZIM goes along.
`ark stamp` currently copies only the ZIMs its manifest resolves to in the
Kiwix catalog, so a custom ZIM is left off a stamped drive.  Manifest
support for custom ZIMs is planned; until then, use `ark clone` for drives
that need them.

### Verify It Works

```bash
# Open in Kiwix to test
kiwix-serve my_custom_content.zim
# Then visit http://localhost:8080 in your browser

# Or use kiwix-desktop and open the file directly
```

## Naming Convention

Follow the Kiwix naming pattern for consistency:

```
{name}_{language}_{variant}_{YYYY-MM}.zim
```

Examples:
- `keepyourteeth_en_all_2026-03.zim`
- `rjwhelan_herbs_en_all_2026-03.zim`
- `my_garden_notes_en_all_2026-03.zim`

## Size Estimates

| Content Type | Typical Size |
|-------------|-------------|
| Small blog (50 pages) | 5-20 MB |
| Documentation site (500 pages) | 50-200 MB |
| Large reference (5,000+ pages) | 200 MB - 2 GB |
| Site with lots of images | 2-10x the text-only size |
| Full mkdocs project | 10-100 MB |

ZIM files compress well; expect roughly 50-70% of the original
site size.
