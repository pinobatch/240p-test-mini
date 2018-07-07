#!/usr/bin/env python3

filenames = ["240pee.nes", "240pee-bnrom.nes"]
for filename in filenames:
    with open(filename, "rb") as infp:
        infp.read(16)
        data = infp.read()

    runbyte, runlength, runthreshold = 0xC9, 0, 32
    runs = []
    for addr, value in enumerate(data):
        if value != runbyte:
            if runlength >= runthreshold:
                runs.append((addr - runlength, addr))
            runbyte, runlength = value, 0
        runlength += 1
    if runlength >= runthreshold:
        runs.append((len(data) - runlength, addr))

    totalsz = 0
    for startaddr, endaddr in runs:
        sz = endaddr - startaddr
        totalsz += sz
        print("%s: %04x-%04x: %d"
              % (filename, startaddr, endaddr - 1, sz))
    print("%s: total: %d bytes (%.1f KiB)"
          % (filename, totalsz, totalsz / 1024.0))
