#!/usr/bin/env python3
# ark-zimcount.py — article count of each ZIM named on the command line.
# Prints path<TAB>count, or path<TAB>- if the file won't open (a truncated
# ZIM on an old drive shouldn't stop the rest).  Needs libzim, in a venv:
#   python3 -m venv .venv && .venv/bin/pip install libzim

import sys

from libzim.reader import Archive

for path in sys.argv[1:]:
    try:
        count = Archive(path).article_count
    except Exception:
        count = "-"
    print(f"{path}\t{count}", flush=True)
