# Contributing

Thanks for wanting to help.  The Ark is a small project, so the process is
small too.

## Suggesting content

The most useful contribution is a source we're missing.  Open an issue with:

- what it is and why it matters when the internet is down
- where it comes from (a Kiwix catalog name if one exists: try
  `./ark catalog search <term>`)
- its license, and its size if you know it

Content has to be public domain, Creative Commons, or openly licensed, and
it has to earn its space.  Every gigabyte on a 250 GB drive pushes
something else off.

## Code

The tool is plain Bash plus `curl`, `jq`, `yq`, `xmlstarlet`, and `rclone`.
Please keep it that way: no new runtimes, nothing that phones home.

- Run `shellcheck` on anything you touch.
- Test against a scratch staging area: `./ark init /tmp/ark-test`.
- Don't test `ark stamp` on a drive you care about.  It erases the drive.
  `ark stamp --dry-run` shows what it would do.

## Writing

Anything written onto a drive (the README, logbook headers, error messages
a reader might see) is in Zim's voice.  Read [docs/VOICE.md](docs/VOICE.md)
first.  The short version: plain words, practical first, brief.

## Licensing

Code contributions are accepted under the MIT license ([LICENSE](LICENSE)).
Writing and design contributions are accepted under CC BY-SA 4.0
([LICENSE-CONTENT](LICENSE-CONTENT)).
