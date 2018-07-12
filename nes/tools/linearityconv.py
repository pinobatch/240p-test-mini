#!/usr/bin/env python3
"""
iu53 image converter
Copyright 2018 Damian Yerrick

A specialized image converter for Linearity in 240p Test Suite for
NES and Super NES that allows programmatic combination of the grid
with the circles.  Because of the nonsquare pixel aspect ratio, the
grid is made of rectangles: 7x8 pixels on NTSC or 8x11 pixels on PAL.
In tile terms, this means a 7x1 grid on NTSC or 1x11 on PAL.
Only tiles at the same position within the grid can be repeated.

proposed iu53 file format

byte: starting tile number (set in PPUADDR then pushed)
byte: tile count
PB53 stream: tiles
byte: starting NT address low
byte: starting NT address high, attr if 7 set, palette if 6 set
byte: width
byte: height
IU map stream
(optional) PB53 stream: attributes
(optional) 16 bytes: palette

"""
import os
import sys
import argparse
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

def uniq_on_grid(tiledata, tiles_per_row=32, xgrid=(0,), ygrid=(0,),
                 verbose=False):
    blanktile = bytes(16)
    nonblank_map_spaces = sum(
        1 if t == blanktile else 0 for t in tiledata
    )
    igrid = (
        (xgrid[x % len(xgrid)], ygrid[y % len(ygrid)])
        for y in range(len(tiledata) // tiles_per_row)
        for x in range(tiles_per_row)
    )
    # A "stamp" is a tile at a given position on the grid.
    # For compression purposes, all blank tile stamps are equal.
    stamps = [
        ((0, 0) if tile == blanktile else pos, tile)
        for pos, tile in zip(igrid, tiledata)
    ]

    num_blank_tiles = len(xgrid) * len(ygrid)
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

    if verbose:
        print("%d position classes; %d of %d map spaces are blank; %d distinct tiles"
              % (num_blank_tiles, total_blanks, len(tiledata), len(stamptoid)))
        if num_blank_tiles > 1:
            print("(each nonblank tile is counted once for each position class where it matters;\n"
                  "without position dependence there'd be only %d uniques)"
                  % len(set(tiledata)))
    return utiles, nt

def iu53_compress_nt(nt, numfixedtiles=0):
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

def iu53_decompress_nt(data, length, numfixedtiles=0):
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

def crop_blank_tiles(tiles, tiles_per_row=32):
    # Copy and reformat as list-of-lists
    tiles = [
        tiles[i:i + tiles_per_row]
        for i in range(0, len(tiles), tiles_per_row)
    ]

    # Bottom crop
    blanktile = bytes(16)
    while tiles and all(x == blanktile for x in tiles[-1]):
        del tiles[-1]
    if not tiles:  # Blank screen
        return tiles, (0, 0, 0, 0)
    bottom = len(tiles)

    # Top crop.  After the previous we know there's at least
    # one nonblank tile in the picture.
    left, top, right, bottom = None, 0, 0, len(tiles)
    while tiles and all(x == blanktile for x in tiles[0]):
        top += 1
        del tiles[0]

    # Side crop
    for x in range(tiles_per_row):
        if all(row[x] == blanktile for row in tiles): continue
        if left is None:
            left = x
        right = x + 1

    tiles = [b for row in tiles for b in row[left:right]]
    return tiles, (left, top, right, bottom)

def parse_grid(s):
    return s.split(",")

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("savfile",
                   help="path of image converted by savtool "
                   "(tiles at 0x0000, map at 0x1800, pal at 0x1F00)")
    p.add_argument("iu53file",
                   help="path of iu53 file to write")
    p.add_argument("--with-attrs", action="store_true",
                   help="include attribute table in file")
    p.add_argument("--with-palette", action="store_true",
                   help="include palette in file")
    p.add_argument("--start-tile", type=int, default=None,
                   help="starting tile number of nonblank tiles (default: len(x-grid)*len(y-grid))")
    p.add_argument("--x-grid", type=parse_grid, default=(0,),
                   help="comma-separated pattern of in which columns tiles may be reused")
    p.add_argument("--y-grid", type=parse_grid, default=(0,),
                   help="comma-separated pattern of in which rows tiles may be reused")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="enable extra debugging info")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.savfile, "rb") as infp:
        tiledata = infp.read(4096)
        infp.read(2048)
        nt = infp.read(960)
        attrs = infp.read(64)
        infp.read(768)
        palette = infp.read(16)
    tiledata = [tiledata[16 * i:16 * i + 16] for i in nt]
    nt = None
    tiledata, r = crop_blank_tiles(tiledata, 32)
    tiles_per_row = r[2] - r[0]
    tiledata, nt = uniq_on_grid(
        tiledata, tiles_per_row, args.x_grid, args.y_grid,
        verbose=args.verbose
    )
    # Crop the leading blank tile
    assert tiledata[0] == bytes(16)
    del tiledata[0]

    # Now compress everything
    ctiles, _ = pb53.pb53(b''.join(tiledata))
    cnt = iu53_compress_nt(nt)
    start_tile = args.start_tile
    if start_tile is None:
        start_tile = len(args.x_grid) * len(args.y_grid)
        if args.verbose:
            print("starting tile number set to %d" % start_tile)
    if args.verbose:
        print("cropped to rect: (%d, %d)-(%d, %d)" % r)
        print("%s: %d bytes of pattern and %d bytes of map"
              % (args.savfile, len(ctiles), len(cnt)))
        out = iu53_decompress_nt(cnt, len(nt))
        print("Match" if nt == out else "Decompression mismatch")

    ntaddr = 0x2000 + r[1] * 32 + r[0]
    if args.with_attrs:
        ntaddr += 0x8000
    if args.with_palette:
        ntaddr += 0x4000

    out = bytearray([start_tile, len(tiledata)])
    out.extend(ctiles)
    out.extend((
        ntaddr & 0xFF, (ntaddr >> 8) & 0xFF, tiles_per_row, r[3] - r[1]
    ))
    out.extend(cnt)
    if args.with_attrs:
        cattrs, _ = pb53.pb53(attrs)
        out.extend(cattrs)
    if args.with_palette:
        out.extend(palette)
    if args.verbose:
        print(len(out), "total bytes")
    with open(args.iu53file, "wb") as outfp:
        outfp.write(out)

jobs = [
    "sav2iu53.py ../obj/nes/linearity_ntscgray.sav"
    "  ../new-linearity/obj/nes/test_ntsc.iu53"
    "  --x-grid 0,1,2,3,4,5,6 -v",
    "sav2iu53.py ../obj/nes/linearity_palgray.sav"
    "  ../new-linearity/obj/nes/test_pal.iu53"
    "  --y-grid 8,2,5,8,0,3,6,8,1,4,7 -v",
]
for job in jobs:
    main(job.split())
