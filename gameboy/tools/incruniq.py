#!/usr/bin/env python3
"""
Compression experiment

The file format:
1 byte: number of PB8 compressed tiles (or 0 for 256)
PB16 compressed tiles
1 byte: length of singleton-eliminated map, divided by 2 and rounded up
IUR compressed map

"""
from collections import Counter
import sys
import argparse
from pb16 import pb16
from uniq import uniq
from bitbyte import BitByteInterleave

def iur_encode_tilemap(tilemap):

    # Type stickiness (brand new uniques vs. horizontal runs)
    # was the key to making IUR efficient
    lastwasnew, lastbyte, maxsofar = False, 0, 0
    out = BitByteInterleave()
    for i, t in enumerate(tilemap):
        isnew = t == maxsofar + 1
        eqlast = t == lastbyte
        ismatch = isnew if lastwasnew else eqlast
        if ismatch:
            # 0: Same run type as last time
            out.putbits(0)
        elif isnew:
            # 10: Switch run type from non-new to new
            out.putbits(0b10, 2)
        elif eqlast:
            # 10: Switch run type from new to non-new
            out.putbits(0b10, 2)
        else:
            # 11: Literal byte follows
            out.putbits(0b11, 2)
            out.putbyte(t)
        lastbyte, lastwasnew = t, isnew
        if isnew: maxsofar += 1
    return bytes(out)

def iur_encode(chrdata):
    """Encode with incremental uniques and runs

chrdata -- a list of bytes objects or other hashables
"""
    utiles, tilemap = uniq(chrdata)
    return utiles, iur_encode_tilemap(tilemap)

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("srcfile")
    p.add_argument("iufile")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.srcfile, "rb") as infp:
        tiles = infp.read()
    block_size = 16
    tiles = [tiles[i:i + block_size]
             for i in range(0, len(tiles), block_size)]
    utiles, iurdata = iur_encode(tiles)

    out = bytearray()
    out.append(len(utiles))
    out.extend(b''.join(pb16(b''.join(utiles))))
    halfnamsize = -(-len(tiles) // 2)
    print("%d tiles" % len(tiles))
    out.append(halfnamsize)
    out.extend(iurdata)
    with open(args.iufile, "wb") as outfp:
        outfp.write(out)

if __name__=='__main__':
    main()
##    main(["incruniq.py", "../obj/gb/Gus_portrait.chrgb", "test.iu"])
