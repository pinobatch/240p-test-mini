#!/usr/bin/env python3
"""
Super Game Boy border converter for 144p Test Suite and Libbet

Copyright 2019, 2024 Damian Yerrick

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
"""
import sys
import os
import argparse
from PIL import Image
import pb16

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
if os.path.isdir(commontoolspath): sys.path.append(commontoolspath)
from pilbmp2nes import pilbmp2chr, formatTilePlanar

def snesformat(tile):
    return formatTilePlanar(tile, "0,1;2,3")

def get_bitreverse():
    """Get a lookup table for horizontal flipping."""
    br = bytearray([0x00, 0x80, 0x40, 0xC0])
    for v in range(6):
        bit = 0x20 >> v
        br.extend(x | bit for x in br)
    return br

bitreverse = get_bitreverse()

def hflipGB(tile):
    br = bitreverse
    return bytes(br[b] for b in tile)

hflipSNES = hflipGB

def vflipGB(tile):
    return b"".join(tile[i:i + 2] for i in range(len(tile) - 2, -2, -2))

def vflipSNES(tile):
    return vflipGB(tile[0:16]) + vflipGB(tile[16:32])

def flipuniq(it):
    """Convert list of tiles to unique tiles and 16-bit tilemap.

Tile 0 is hardcoded to the transparent tile.  If tile 0 is not
transparent, the border transition on Super Game Boy briefly blinks
black between the fade out and fade in.
"""
    tiles = [bytes(32)]
    tile2id = {bytes(32): 0}
    tilemap = []
    for tile in it:
        if tile not in tile2id:
            tilenum = len(tiles)
            hf = hflipSNES(tile)
            vf = vflipSNES(tile)
            vhf = vflipSNES(hf)
            tile2id[vhf] = tilenum | 0xC0
            tile2id[vf] = tilenum | 0x80
            tile2id[hf] = tilenum | 0x40
            tile2id[tile] = tilenum
            tiles.append(tile)
        tilemap.append(tile2id[tile])
    return tiles, tilemap

def main(argv=None):
    argv = argv or sys.argv
    infilename, outfilename = argv[1:3]
    # Additional compression options used in 144p Test Suite
    # TODO: parse these with argparse
    use_utmrows = True  #  repeated rows
    use_iur = True  # tilemap bias toward increasing tile numbers

    im = Image.open(infilename)
    if im.mode != 'P':
        raise ValueError("%s: expected indexed color (mode P); got mode %s"
                         % (infilename, im.mode))
    palette_count = max(im.getdata()) + 1
    if not 3 <= palette_count <= 16:
        raise ValueError("%s: expected 3 to 16 colors; got %d"
                         % (infilename, palette_count))
    if im.size[0] != 256:
        raise ValueError("%s: expected width 256 pixels; got %d"
                         % (infilename, im.size[0]))

    tiles = pilbmp2chr(im, formatTile=snesformat)
    utiles, tilemap = flipuniq(tiles)
    assert len(utiles) <= 64
    pbtiles = b"".join(pb16.pb16(b"".join(utiles)))
    tmrows = [bytes(tilemap[i:i + 32]) for i in range(0, len(tilemap), 32)]

    # Encode the tilemap based on which compression options
    # are in use for this project
    if use_utmrows:
        from uniq import uniq
        utmrows, tmrowmap = uniq(tmrows)
        if len(utmrows) >= 16:
            raise ValueError("%s: too many unique rows: %d > 15"
                             % (infilename, len(utmrows)))
    else:
        utmrows, tmrowmap = tmrows, list(range(len(tmrows)))
    if use_iur:
        from incruniq import iur_encode_tilemap
        iutmrows = iur_encode_tilemap(b''.join(utmrows))
    else:
        iutmrows = b''.join(pb16.pb16(b''.join(utmrows)))

    # For determinism, zero palette entries that the input image
    # doesn't define
    palette = im.getpalette()[:palette_count * 3]
    palette.extend(bytes(48 - len(palette)))

    snespalette = bytearray()
    for i in range(0, 48, 3):
        r = palette[i] >> 3
        g = palette[i + 1] >> 3
        b = palette[i + 2] >> 3
        bgr = (b << 10) | (g << 5) | r
        snespalette.append(bgr & 0xFF)
        snespalette.append(bgr >> 8)

    out = b"".join((
        bytes([len(utiles) * 2]), pbtiles,
        bytes([len(utmrows) * 16]) if use_utmrows else b"",
        iutmrows,
        bytes(tmrowmap) if use_utmrows else b"",
        snespalette
    ))
    with open(outfilename, "wb") as outfp:
        outfp.write(out)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(["./makeborder.py", "../tilesets/sgbborder.png", "/dev/null"])
    else:
        main()
