#!/usr/bin/env python3
"""
Long run detector for binary files
Copyright 2018 Damian Yerrick
insert zlib license here
"""
with open("gb240p.gb", "rb") as infp:
    data = infp.read()

runthreshold = 32
runbyte, runlength, runs = 0xC9, 0, []
for addr, value in enumerate(data):
    if value != runbyte:
        if runlength >= runthreshold:
            runs.append((addr - runlength, addr))
        runbyte, runlength = value, 0
    runlength += 1
if runlength >= runthreshold:
    runs.append((len(data) - runlength, len(data)))

totalsz = 0
for startaddr, endaddr in runs:
    sz = endaddr - startaddr
    totalsz += sz
    print("%04x-%04x: %d" % (startaddr, endaddr - 1, sz))
print("total: %d bytes (%.1f KiB)" % (totalsz, totalsz / 1024.0))
