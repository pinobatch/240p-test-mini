#!/usr/bin/env python3
import sys
import argparse
from PIL import Image, ImageChops
from pilbmp2nes import pilbmp2chr, formatTilePlanar

# Image processing ##################################################

def quantizetopalette(silf, palette, dither=False):
    """Convert an RGB or L mode image to use a given P image's palette.

This is a forked version of PIL.Image.Image.quantize() with more
control over whether Floyd-Steinberg dithering is used.
"""

    silf.load()

    # use palette from reference image
    palette.load()
    if palette.mode != "P":
        raise ValueError("bad mode for palette image")
    if silf.mode != "RGB" and silf.mode != "L":
        raise ValueError(
            "only RGB or L mode images can be quantized to a palette"
            )
    im = silf.im.convert("P", 1 if dither else 0, palette.im)
    # the 0 above means turn OFF dithering

    try:
        return silf._new(im)  # Name in Pillow 4+
    except AttributeError:
        return silf._makeself(im)  # Name in Pillow 3-

# This is generalized from savtool.py
def colorround(im, palettes, tilesize, subpalsize):
    blockw, blockh = tilesize
    if im.mode != 'RGB':
        im = im.convert('RGB')

    trials = []
    master_palette = []
    onetile = Image.new('P', tilesize)
    for p in palettes:
        p = list(p[:subpalsize])
        p.extend([p[0]] * (subpalsize - len(p)))
        master_palette.extend(p)

        # New images default to the full grayscale palette. Unless
        # all 256 colors are overwritten, quantizetopalette() will
        # use the grays.
        p.extend([p[0]] * (256 - len(p)))

        # putpalette() requires the palette to be flattened:
        # [r,g,b,r,g,b,...] not [(r,g,b),(r,g,b),...]
        # otherwise putpalette() raises TypeError:
        # 'tuple' object cannot be interpreted as an integer
        seq = [component for color in p for component in color]
        onetile.putpalette(seq)
        imp = quantizetopalette(im, onetile)

        # For each color area, calculate the difference
        # between it and the original
        impr = imp.convert('RGB')
        diff = ImageChops.difference(im, impr)
        diff = [
            diff.crop((l, t, l + blockw, t + blockh))
            for t in range(0, im.size[1], blockh)
            for l in range(0, im.size[0], blockw)
        ]
        # diff is the overall color difference for each color area
        # of this image, using weights 2, 4, 3 per
        # https://en.wikipedia.org/w/index.php?title=Color_difference&oldid=840435351
        diff = [
            sum(2*r*r+4*g*g+3*b*b for (r, g, b) in tile.getdata())
            for tile in diff
        ]
        trials.append((imp, diff))

    # Find the attribute with the smallest difference
    # for each color area
    attrs = [
        min(enumerate(i), key=lambda i: i[1])[0]
        for i in zip(*(diff for (imp, diff) in trials))
    ]

    # Calculate the resulting image
    imfinal = Image.new('P', im.size)
    seq = [component for color in master_palette for component in color]
    imfinal.putpalette(seq)
    tilerects = zip(
        ((l, t, l + blockw, t + blockh)
         for t in range(0, im.size[1], blockh)
         for l in range(0, im.size[0], blockw)),
        attrs
    )
    for tilerect, attr in tilerects:
        pbase = attr * subpalsize
        pixeldata = trials[attr][0].crop(tilerect).getdata()
        onetile.putdata(bytes(pbase + b for b in pixeldata))
        imfinal.paste(onetile, tilerect)
    return imfinal, attrs

def formatTileGB(im):
    return formatTilePlanar(im, "0,1")

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

def vflipGB(tile):
    br = bitreverse

def flipuniq(it):
    tiles = []
    tile2id = {}
    tilemap = []
    for tile in it:
        if tile not in tile2id:
            tilenum = len(tiles)
            hf = hflipGB(tile)
            vf = vflipGB(tile)
            vhf = vflipGB(hf)
            tile2id[vhf] = tilenum | 0x6000
            tile2id[vf] = tilenum | 0x4000
            tile2id[hf] = tilenum | 0x2000
            tile2id[tile] = tilenum
            tiles.append(tile)
        tilemap.append(tile2id[tile])
    return tiles, tilemap

# Input parsing #####################################################

def hextotuple(color):
    if color.startswith('#'):
        color = color[1:]
    color = color.lower()
    if not all(c in "0123456789abcdef" for c in color):
        raise ValueError("%s is not hexadecimal" % repr(color))
    if len(color) == 3:
        return tuple(17 * int(component, 16) for component in color)
    if len(color) == 6:
        return tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))
    raise ValueError("%s is not a 3- or 6-digit hex value" % color)

def parse_argv(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("paltxtfile")
    parser.add_argument("outtiles")
    parser.add_argument("outmap")
    parser.add_argument("outattr")
    parser.add_argument("outpalette")
    parser.add_argument("--preview")
    return parser.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)

    # Read palette spec file
    with open(args.paltxtfile, "r") as infp:
        lines = [l.split("//", 1)[0].strip() for l in infp]
    palettes = [
        [hextotuple(c) for c in l.split()]
        for l in lines
        if l
    ]

    im = Image.open(args.image)
    imfinal, attrs = colorround(im, palettes, (8, 8), 4)
    if args.preview:
        imfinal.save(args.preview)
    gbformat = lambda im: formatTilePlanar(im, "0,1")
    tiles = pilbmp2chr(imfinal, formatTile=formatTileGB)
    utiles, tilemap = flipuniq(tiles)
    print("%d tiles, %d unique" % (len(tiles), len(utiles)))

if __name__=='__main__':
    is_IDLE = 'idlelib.run' in sys.modules or 'idlelib.__main__' in sys.modules
    if is_IDLE:
        main("""
gbcnamtool.py ../tilesets/Gus-portrait-GBC.png ../tilesets/Gus-portrait-GBC.pal.txt
out_tiles.chr out_map.bin out_attr.bin out_palette.bin
--preview imfinal.png
""".split())
    else:
        main()
