#!/usr/bin/env python3
import sys
import os
import re
from collections import defaultdict

filename = "gb240p.map"
if 'idlelib' in sys.modules:
    filename = os.path.join("..", filename)

sectionRE = re.compile(
    r"""SECTION:\s+\$([0-7][0-9A-F]*)-\$([0-7][0-9A-F]*)""",
    re.IGNORECASE
)
bankRE = re.compile(
    r"""ROM[0X] BANK #?([0-9A-F])+""",
    re.IGNORECASE
)

used_ranges = defaultdict(list)
banknumber = None

with open(filename, "r") as infp:
    lines = [x.strip() for x in infp]
for line in lines:
    m = sectionRE.match(line)
    if m:
        sl = int(m.group(1), 16), int(m.group(2), 16) + 1
        used_ranges[banknumber].append(sl)
        continue
    m = bankRE.match(line)
    if m:
        banknumber = m.group(1)
        continue

for banknumber, ranges in used_ranges.items():
    ranges.sort()
    freestart = ranges[0][0] & -0x4000
    bankend = 0x4000 + freestart
    unused_here = []
    for s, e in ranges:
        if s > freestart:
            unused_here.append((freestart, s))
        freestart = e
    if freestart < bankend:
        unused_here.append((e, bankend))
    print("Bank %s" % banknumber)
    print("\n".join(
        "$%04x-$%04x (%d %s)"
        % (s, e - 1, e - s, "bytes" if e - s >= 2 else "byte")
        for s, e in unused_here
    ))
