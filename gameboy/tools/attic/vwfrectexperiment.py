#!/usr/bin/env python3
"""
Experimental compression for VWF tile set, which is nominally
936 bytes, or 9 bytes for each of 104 tiles.  On NES we store it
uncompressed in the ROM.  On GB we have more RAM so we can pack it
tighter in ROM and decompress it on startup.

Normally each tile's pen advance is 8 bits, of which only values 1-8
are ever used.  No tile fills all 64 bits of its 8x8 rectangle
either.  So by storing the pen advance, nonblank width, nonblank
top, and nonblank bottom

Pen advance, nonblank width, and nonblank top and bottom can be
encoded in 3 bits each for 12 bits total, and then each glyph is
w*h bits.

Result:
104 tiles from 936 to 459 bytes saving 477

But this doesn't include the unpacker.
"""
import sys, os, argparse
from PIL import Image
from operator import or_ as bitwise_or
from functools import reduce

def hexdump(b, w=32):
    print("\n".join(b[i:i + w].hex() for i in range(0, len(b), w)))

def pixelstom7tiles(im, size=None):
    if isinstance(im, bytes):
        b = im
    else:
        b, size = im.tobytes(), im.size
    w, h = size
    out = []
    for rowidx in range(0, len(b), w * 8):
        tilerow = b[rowidx:rowidx + w * 8]
        for x in range(0, w, 8):
            tile = b''.join(tilerow[i:i + 8] for i in range(x, w * 8, w))
            out.append(tile)
    return out

def m7tileto1btile(tile):
    out = bytearray()
    for y in range(0, len(tile), 8):
        row = tile[y:y + 8]
        byte = 0
        for c in row:
            byte = (byte << 1) | (c & 1)
        out.append(byte)
    return bytes(out)

def ctz(b):
    """Count trailing zero bits in a binary number."""

    # bit_length()
    
    return (b ^ (b - 1)).bit_length() - 1

def main(argv=None):
    argv = argv or sys.argv
    im = Image.open("../../common/tilesets/vwf7_cp144p.png")
    imbytes = bytes(1 if c == 1 else 0 for c in im.tobytes())
    tiles = [m7tileto1btile(x) for x in pixelstom7tiles(imbytes, im.size)]
    bitcount = 0
    for tile1b in tiles:
        nonempty_rows = [i for i, row in enumerate(tile1b) if row]
        if not nonempty_rows:
            bitcount += 12
            continue
        top, bottom = nonempty_rows[0], nonempty_rows[-1]
        occupiedcols = reduce(bitwise_or, tile1b, 0)
        tilew, tileh = 8 - ctz(occupiedcols), bottom + 1 - top
        assert tilew != 0
        bitlength = tilew * tileh
        bitcount += 12 + bitlength

    oldbytecount, newbytecount = len(tiles) * 9, -(-bitcount // 8)
    print("%d tiles from %d to %d bytes saving %d"
          % (len(tiles), oldbytecount, newbytecount,
             oldbytecount - newbytecount))

if __name__=='__main__':
    main()
