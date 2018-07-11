#!/usr/bin/env python3
"""
Linearity image converter
Copyright 2018 Damian Yerrick

A specialized image converter for Linearity in 240p Test Suite for
NES and Super NES that allows programmatic combination of the grid
with the circles.  Because of the nonsquare pixel aspect ratio, the
grid is made of rectangles: 7x8 pixels on NTSC or 8x11 pixels on PAL.
In tile terms, this means a 7x1 grid on NTSC or 1x11 on PAL.
Only tiles at the same position within the can be repeated.

"""
import os
import sys
from PIL import Image
from collections import Counter
import pb53

# Find common tools (e.g. pilbmp2nes)
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from pilbmp2nes import pilbmp2chr
from bitbuilder import log2, BitBuilder, Biterator

def do_job(tiledata, tiles_per_row, xstamps, ystamps):
    blanktile = bytes(16)
    nonblank_map_spaces = sum(
        1 if t == blanktile else 0 for t in tiledata
    )
    istamps = (
        (xstamps[x % len(xstamps)], ystamps[y % len(ystamps)])
        for y in range(len(tiledata) // tiles_per_row)
        for x in range(tiles_per_row)
    )
    # For compression purposes, all zero stamps are equal
    stamps = [
        ((0, 0) if tile == blanktile else pos, tile)
        for pos, tile in zip(istamps, tiledata)
    ]

    num_blank_tiles = len(xstamps) * len(ystamps)
    total_blanks = sum(1 if k == blanktile else 0 for k in tiledata)
    istamps = Counter(stamps)
    stamptoid = {((0, 0), blanktile): 0}
    for k in stamps:
        if k in stamptoid:
            continue
        stamptoid[k] = len(stamptoid)

    # Now fill the nametable
    nt = [stamptoid[k] if k[1] != blanktile else 0 for k in stamps]
    idtostamp = sorted((v, k) for (k, v) in stamptoid.items())
    utiles = [row[1][1] for row in idtostamp]

    print("%d position classes; %d of %d map spaces are blank; %d distinct tiles\n"
          "(each nonblank tile is counted once for each position class where it matters)\n"
          "without position dependence there'd be only %d uniques"
          % (num_blank_tiles, total_blanks, len(tiledata), len(stamptoid),
             len(set(tiledata))))
    return utiles, nt

def linearity_compress_nt(nt, numfixedtiles=0):
    """

Zero tile is 0
Fixed tiles are 1 through numfixedtiles
Sequential tiles are numfixedtiles+1 through 255
A sequential tile must be no more than 1 plus the highest seen
sequential tile so far

Format:

0 zero tile
10 new tile
11xxx... old tile, where x is the same number of bits as in last new tile - 1

"""
    out = BitBuilder()
    numseentiles = numfixedtiles
    for tilenum in nt:
        if tilenum == 0:
            out.append(0)
            continue
        if tilenum <= numseentiles:
            nbits = log2(numseentiles - 1) + 1
            out.append(3, 2)
            out.append(tilenum - 1, nbits)
            continue
        numseentiles += 1
        if tilenum > numseentiles:
            raise ValueError("tile %d premature when expecting %d")
        out.append(2, 2)
    return bytes(out)

def linearity_decompress_nt(data, length, numfixedtiles=0):
    b = Biterator(data)
    numseentiles = numfixedtiles
    out = []
    while len(out) < length:
        if next(b):
            if next(b):
                nbits = log2(numseentiles - 1) + 1
                out.append(1 + b.read(nbits))
            else:
                numseentiles += 1
                out.append(numseentiles)
                pass
        else:
            out.append(0)
            pass
    return out

stampsets = {
    None: ((0,), (0,)),
    'ntsc': ((0, 1, 2, 3, 4, 5, 6), (0,)),
    'pal': ((0,), (8, 2, 5, 8, 0, 3, 6, 8, 1, 4, 7))
}

jobs = [
    ("../tilesets/linearity_ntsc.png", 'ntsc'),
    ("../tilesets/linearity_pal.png", 'pal'),
]
totalbytes = 0
for job in jobs:
    filename, stampsetname = job
    print(filename)
    xstamps, ystamps = stampsets[stampsetname]
    im = Image.open(filename)
    tiles_per_row = im.size[0] // 8
    tiledata = pilbmp2chr(im)
    tiles, nt = do_job(tiledata, tiles_per_row, xstamps, ystamps)
    ctiles, _ = pb53.pb53(b''.join(tiles))
    print(len(ctiles), "bytes in compressed pattern table")
    totalbytes += len(ctiles)
    cnt = linearity_compress_nt(nt)
    print(len(cnt), "bytes in compressed nametable")
    totalbytes += len(cnt)
    print(cnt.hex())
    out = linearity_decompress_nt(cnt, len(nt))
    print("Match" if nt == out else "Mismatch")

print("total compressed size: %d bytes" % totalbytes)
