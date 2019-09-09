#!/usr/bin/env python3
import sys
import os
import argparse
from PIL import Image, ImageChops

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
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
    return b"".join(tile[i:i + 2] for i in range(len(tile) - 2, -2, -2))

def flipuniq(it):
    """Convert list of tiles to unique tiles and 16-bit tilemap"""
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

def color_tuple_to_bgr5(rgb):
    r, g, b = rgb
    return (
        (b & 0xF8) << (10 - 3) | (g & 0xF8) << (5 - 3) | (r & 0xF8) >> 3
    )

def subpalette_to_bgr5(row):
    """Convert the first 4 color tuples in a list to 5 bits per channel"""
    row = [color_tuple_to_bgr5(x) for x in list(row)[:4]]
    if len(row) < 4:
        row.extend([row[0]] * (4 - len(row)))
    return row

def subpalette_to_asm(row):
    """Convert the first 4 color tuples in a list to a DW statement"""
    return "  dw " + ",".join("$%04x" % x for x in subpalette_to_bgr5(row))

def subpalette_to_bin(row):
    out = bytearray()
    for i in subpalette_to_bgr5(row):
        out.append(i & 0xFF)
        out.append(i >> 8)
    return out

def im_to_gbc(im, palettes):
    imfinal, attrs = colorround(im, palettes, (8, 8), 4)
    gbformat = lambda im: formatTilePlanar(im, "0,1")
    tiles = pilbmp2chr(imfinal, formatTile=formatTileGB)
    utiles, tilemap = flipuniq(tiles)
    assert len(tilemap) == len(attrs)
    tilemap_hi = bytearray((t >> 8) | c for t, c in zip(tilemap, attrs))
    tilemap_lo = bytearray(t & 0xFF for t in tilemap)
    return imfinal, utiles, tilemap_lo, tilemap_hi

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

def path_to_symbol_name(imagename):
    import os
    import re

    # Make basename is Python splitext; Make notdir is Python basename
    basename = os.path.splitext(os.path.basename(imagename))[0]

    # Replace each run of non-identifier characters with a single underscore
    alnum_basename = re.sub(r"[^a-zA-Z_]+", "_", basename)

    # Add underscore before leading digit
    if alnum_basename[0].isdigit():
        alnum_basename = "_" + alnum_basename

    return alnum_basename

def load_palette_spec(lines):
    lines = [l.split("//", 1)[0].strip() for l in lines]
    return [
        [hextotuple(c) for c in l.split()]
        for l in lines
        if l
    ]

def parse_argv(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("image",
                        help="image file to convert, or blank to write "
                        "palette instead")
    parser.add_argument("paltxtfile",
                        help="file containing newline-separated list of "
                        "space-separated hex color codes, one line per "
                        "subpalette")
    parser.add_argument("outfile",
                        help="output (IUC or palette) written here")
    parser.add_argument("--preview", metavar="IMAGENAME",
                        help="write palette conversion result as image")
    return parser.parse_args(argv[1:])

def main(argv=None):
    import pb16, incruniq

    args = parse_argv(argv or sys.argv)

    # Read input files
    with open(args.paltxtfile, "r") as infp:
        lines = list(infp)
    palettes = load_palette_spec(lines)
    if not args.image:
        with open(args.outfile, "wb") as outfp:
            outfp.writelines(subpalette_to_bin(row) for row in palettes)
        return
    im = Image.open(args.image)

    result = im_to_gbc(im, palettes)
    imfinal, utiles, tilemap_lo, tilemap_hi = result
    if args.preview:
        imfinal.save(args.preview)

    # Compress tiles with PB16, nametable with IUR, and
    # attributes with PB16
    ctilemap_lo = incruniq.iur_encode_tilemap(tilemap_lo)
    ctiles = b"".join(pb16.pb16(b"".join(utiles)))
    ctilemap_hi = b"".join(pb16.pb16(tilemap_hi))

    halfnamsize = -(-len(tilemap_lo) // 2)
    out = bytearray([len(utiles)])
    out.extend(ctiles)
    out.append(halfnamsize)
    out.extend(ctilemap_lo)
    out.extend(ctilemap_hi)
    with open(args.outfile, 'wb') as outfp:
        outfp.write(out)

if __name__=='__main__':
    is_IDLE = 'idlelib.run' in sys.modules or 'idlelib.__main__' in sys.modules
    if is_IDLE:
        main("""
gbcnamtool.py
../tilesets/Gus_portrait-GBC.png ../tilesets/Gus_portrait-GBC.pal.txt
out.iuc
--preview imfinal.png
""".split())
    else:
        main()
