#!/usr/bin/env python3
"""

savtool
an image conversion tool for use with an NES graphics editor
by Damian Yerrick

See versionText for version and copyright information.

"""
import sys, os, re, argparse
try:
    from PIL import Image, ImageChops
except ImportError:
    print("%s: warning: Pillow (Python Imaging Library) not installed; functionality is limited" % os.path.basename(sys.argv[0]),
          file=sys.stderr)
    Image = None

assert str is not bytes  # Python 2 is buried
default_palette = b'\x0F\x00\x10\x30\x0F\x06\x16\x26\x0F\x1A\x2A\x3A\x0F\x02\x12\x22'

# Find common tools (e.g. pilbmp2nes)
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)

# Command line parsing and help #####################################
#
# Easy is hard.  It takes a lot of code and a lot of text to make a
# program self-documenting and resilient to bad input.

usageText = "usage: %prog [options] [-i] INFILE [-o] OUTFILE"
versionText = """savtool 0.07wip

Copyright 2012, 2024 Damian Yerrick
Copying and distribution of this file, with or without
modification, are permitted in any medium without royalty provided
the copyright notice and this notice are preserved in all source
code copies. This file is offered as-is, without any warranty.
"""
descriptionText = """
Image converter for NES graphics editor.
"""
moreDetailsText = """File formats:
.bmp: Uncompressed or RLE compressed bitmap
.chr: Tile sheet in the NES's format (4096 bytes)
.gif: Lossless compressed bitmap (LZW)
.nam: Map data alone (1024 bytes)
.png: Lossless compressed bitmap (DEFLATE)
.ppu: PPU dump (16384 bytes)
.sav: Saved picture from editor (8192 bytes), containing a
    tile sheet, a map, and a palette
.srm: Synonym for .sav used by some emulators

Supported INFILE/OUTFILE pairs:
ppu->sav, ppu->bitmap, bitmap<->sav, bitmap<->chr, chr<->sav, sav->sav

OUTFILE is required except in two cases.  If --print-palette or
--show is given without OUTFILE, no file is written.  If INFILE is a
.sav file and --show is not specified, changes to the tile sheet or
palette are written back to INFILE.

The behavior of --chr depends on the format of INFILE.
.ppu: ADDR is the hexadecimal address ($0000 or $1000) of the
    tile sheet.
.sav: SHEET is the filename of a tile sheet that replaces the tiles
    without remapping the nametable.
.nam: SHEET is the filename of a tile sheet combined with --chr and
    --palette, both of which are required.
Bitmap: SHEET is the filename of a tile sheet.  Any tiles from the
    bitmap that are not in the tile sheet replace tiles in the tile
    sheet: first duplicate tiles, then unused blank tiles, then
    other unused tiles.  To force this behavior with a .sav INFILE,
    specify --remap.

When converting an indexed bitmap image to .sav without --palette,
the lower 2 bits are used, and the whole picture uses color set 0
with a grayscale palette.  With --palette, the indexed or truecolor
image is converted with all four color sets, and the color set that
best matches each 16x16 pixel area is used.  Using --palette with a
.ppu or .sav INFILE replaces the palette in the output .sav file.

savtool translates NES color codes (00 to 3F) to sRGB colors using
a color lookup table (CLUT).  The default CLUT was generated with
Joel Yliluoma's web app.  (Caution: it's a bit desaturated.)
<https://bisqwit.iki.fi/utils/nespalette.php>

The --nes-clut option loads a different CLUT from the first 192
bytes of a .pal file or the 64-color indexed palette of a PNG image.
This allows converting images drawn against a different CLUT.

The --write-swatches option writes the CLUT in several formats:

.bmp, .gif, .png: Write reference image with indexed palette as
    first 64 colors
--show: Display reference image using image viewer
.pal: Write 192-byte palette for use with NES emulators
.gpl: Write palette in GIMP/Inkscape format
.txt: Write 64 lines of cc<tab>#rrggbb
-: Write 64 lines .txt to standard output

Glossary
Attribute: The color set chosen for each color area
Backdrop: A color code that can be used throughout a picture
Bitmap: A picture stored as rows of pixels, which may represent a
    128 by 128 pixel tile sheet or a larger picture
CHR: Programming term for a tile sheet, especially one in the NES's
    native tile data format
Color area: A 16 by 16 pixel area on the map to which a color set can
    be assigned
Color code: A number from 0 to 63 (0x00 to 0x3F) giving an index
    into the CLUT
Color lookup table (CLUT): The set of 64 colors, not all distinct,
    that the PPU can generate
Color set: A set of three color codes that can be used with the
    backdrop in each color area
Hex palette: A string of 32 letters and numbers representing the 13
    color codes in a palette
Map: A grid of 32 by 30 tile numbers and 16 by 15 attributes
Nametable: Synonym for map, taken from TMS9918 datasheet
Palette: A backdrop and four color sets
Picture Processing Unit (PPU): Video integrated circuit in NES
PPU dump: A copy of all data visible to the PPU, as written by
    FCEUX's hex editor
Tile: An 8 by 8 pixel piece of graphics
Tile sheet: A collection of 256 tiles
"""

testpatterns = [
    "savtool.py",
    "savtool.py --help",
    "savtool.py --more-help",
    "savtool.py --version",
    "savtool.py x.sav --chr y.png",
    "savtool.py x.sav --chr y.chr",
    "savtool.py x.sav --chr y.sav",
    "savtool.py x.sav --print-palette",
    "savtool.py x.png --chr y.png --palette 0F0010300F0616260F1A2A3A0F021222 -o x.sav",
    "savtool.py x.png --chr y.png --palette z.sav -o x.sav",
    'savtool.py "World 1-3.ppu" --chr $1000 -x 16 -y 0 -o treetops.sav',
    "savtool.py x.nam --chr x.chr --palette 0F0010300F0616260F1A2A3A0F021222 -o x.sav",
    "savtool.py --write-swatches -"
    "savtool.py --nes-clut Smooth_FBX.pal --write-swatches --show"
]

xdigitRE = re.compile(r'^\$?([0-9a-fA-F]+)$')
infile_exts = {
    'bmp': 'bmp', 'png': 'bmp', 'gif': 'bmp', 'jpg': 'bmp', 'jpeg': 'bmp',
    'sav': 'sav', 'srm': 'sav',
    'ppu': 'ppu', 'chr': 'chr', 'nam': 'nam'
}

def parse_argv(argv):
    parser = argparse.ArgumentParser(
##        usage=usageText,
        description=descriptionText,
        fromfile_prefix_chars='@'
    )
    parser.add_argument("--more-help", action="store_true",
                        help="show more detailed help and exit")
    parser.add_argument("--version", action="store_true",
                        help="show version and license and exit")
    parser.add_argument("-i", "--input",
                        help="read from INFILE (.bmp, .chr, .nam, .png, .ppu, .sav)",
                        metavar="INFILE")
    parser.add_argument("-o", "--output",
                        help="write output to OUTFILE (.bmp, .chr, .nam, .png, .sav); "
                             "optional if INFILE is a .sav",
                        metavar="OUTFILE")
    parser.add_argument("--chr", metavar="SHEET-OR-ADDR",
                        help="set the hex starting address to ADDR ($0000 or $1000) "
                             "if INFILE is a PPU dump, or use SHEET as a tile sheet")
    parser.add_argument("--remap", dest="remap", action="store_true",
                        help="instead of replacing a picture's tile sheet with SHEET, remap it to use tiles already in SHEET")
    parser.add_argument("--max-tiles", type=int,
                        help="reduce unique tiles to this many (e.g. 256)")
    parser.add_argument("-x", "--scroll-x",
                        help="trim 16*DISTANCE pixels from left side of .ppu (0-31, default 0)",
                        metavar="DISTANCE", type=int, default=0)
    parser.add_argument("-y", "--scroll-y",
                        help="trim 16*DISTANCE pixels from top of .ppu (0-29, default 0)",
                        metavar="DISTANCE", type=int, default=0)
    parser.add_argument("--palette", dest="palette",
                        help="use a 32-character hex palette or the palette from SAVFILE",
                        metavar="SAVFILE-OR-HEX")
    parser.add_argument("--print-palette",
                        default=False, action="store_true",
                        help="write image's 32-character hex palette to standard output",)
    parser.add_argument("--show", dest="show",
                        default=False, action="store_true",
                        help="display picture")
    parser.add_argument("-P", "--write-chr", metavar="COLORSET",
                        help="write tile sheet instead of screen, with colorset COLORSET (0-3)",
                        default=None, type=int)
    parser.add_argument("--nes-clut", metavar="CLUTFILE",
                        help="use the CLUT from this file (.pal or .png)",
                        default="bisqwit2012")
    parser.add_argument("--write-swatches", metavar="OUTFILE", const=True,
                        help="write the entire CLUT to OUTFILE "
                        "(.bmp, .png, .pal, .txt, .gpl, or --show); "
                        "useful for determining hex values",
                        default=None, nargs='?')
    parser.add_argument("files", metavar="FILE", nargs='*',
                        help="specify INFILE and OUTFILE in that order")

    args = parser.parse_intermixed_args(argv[1:])
    if args.more_help:
        print(moreDetailsText)
        sys.exit()
    if args.version:  # bypass "helpful" help formatter
        print(versionText)
        sys.exit()

    if args.write_chr not in (0, 1, 2, 3, None):
        parser.error("color set for tile sheet must be 0 to 3")
    if args.scroll_x < 0 or args.scroll_x > 31:
        parser.error("X scroll must be 0 to 31")
    if args.scroll_y < 0 or args.scroll_y > 29:
        parser.error("Y scroll must be 0 to 29")

    # Fill unfilled roles with positional arguments
    pos = iter(args.files)
    try:
        infilename = args.input or next(pos)
    except StopIteration:
        if args.write_swatches:
            infilename = None
        else:
            parser.error("no input file; try %s --help"
                         % os.path.basename(sys.argv[0]))

    if infilename is not None:
        inext = os.path.splitext(infilename)[1].lstrip('.').lower()
        try:
            intype = infile_exts[inext]
        except KeyError:
            parser.error("unrecognized extension '%s' for input file" % inext)
    else:
        intype = None

    try:
        outfilename = args.output or next(pos)
    except StopIteration:
        if args.show:
            outtype = 'bmp'
            outfilename = None
        elif infilename and infilename[-4:].lower() in ('.sav', '.srm'):
            outfilename = infilename  # overwrite same file
        elif args.write_swatches and not infilename:
            outfilename = None
        else:
            parser.error("no output file")
    if outfilename is not None:
        outext = os.path.splitext(outfilename)[1].lstrip('.').lower()
        try:
            outtype = infile_exts[outext]
        except KeyError:
            parser.error("unrecognized extension '%s' for output file" % outext)

    # make sure no trailing arguments
    try:
        next(pos)
    except StopIteration:
        pass
    else:
        parser.error("too many filenames")

    # look for mutually conflicting options
    if args.chr:
        chrext = os.path.splitext(args.chr)[1].lstrip('.').lower()
        try:
            chrtype = infile_exts[chrext]
        except KeyError:
            if intype == 'ppu' and xdigitRE.match(args.chr):
                chrtype = 'literal'
            else:
                parser.error("unrecognized extension '%s' for tile sheet" % chrext)
        if chrtype == 'nam':
            parser.error("nametable has no tile sheet")
    elif infilename:
        chrtype = intype
    else:
        chrtype = None

    if args.palette:
        palext = os.path.splitext(args.palette)[1].lstrip('.').lower()
        try:
            paltype = infile_exts[palext]
        except KeyError:
            if xdigitRE.match(args.palette):
                paltype = 'literal'
            else:
                parser.error("unrecognized extension '%s' for palette" % chrext)
        if paltype not in ('literal', 'ppu', 'sav'):
            parser.error("only PPU dumps and save files have an NES palette")
    elif infilename:
        paltype = intype
    else:
        paltype = None

    if chrtype == 'nam' and not args.chr:
        parser.error("converting a nametable requires a tile sheet; use --chr")
    remap = (intype == 'bmp' and args.chr) or args.remap
    if remap and (not args.chr or chrtype == 'literal'):
        parser.error("remapping CHR requires a tile sheet; use --chr")
    if chrtype == 'nam' and args.remap:
        parser.error("nametable has no tile sheet to remap")
    if chrtype == 'nam' and args.write_chr:
        parser.error("nametable has no tile sheet to write")
    if intype != 'ppu' and (args.scroll_x or args.scroll_y):
        parser.error("only PPU dumps can be scrolled")
    if args.print_palette and paltype not in ('ppu', 'sav'):
        parser.error("only PPU dumps and save files have an NES palette")
    if args.max_tiles is not None and not 2 <= args.max_tiles <= 256:
        parser.error("max-tiles not in 2 to 256")

    write_swatches = args.write_swatches
    if write_swatches is True:
        if args.show:
            write_swatches = '--show'
        else:
            parser.error("--write-swatches requires a filename, "
                         "- for standard output, or --show for the display")

    return (infilename, outfilename, args.chr,
            args.scroll_x, args.scroll_y,
            args.palette, args.print_palette, args.write_chr,
            args.show, remap, write_swatches, args.max_tiles,
            args.nes_clut)

def test_argv():
    from shlex import split as strtoargs
    argtitles = ("input filename", "output filename", "tile sheet",
                 "X offset", "Y offset",
                 "palette", "print palette", "write CHR with color set",
                 "show picture", "remap CHR")
    for line in testpatterns:
        print(line)
        args = strtoargs(line)
        try:
            row = parse_argv(args)
        except SystemExit:
            print("Would exit")
        except Exception as e:
            print(e)
        else:
            print("\n".join("  %s: %s" % (a, repr(b))
                            for (a, b) in zip(argtitles, row)))

# PPU dump loading ##################################################

def get_scrolled_nametable(four_screens, xscroll, yscroll):
    """Take a 1-screen slice from a 4-screen nametable, scrolled by 16*yscroll pixels."""

    from binascii import b2a_hex
    ntrows = [[screen[i:i + 32] for i in range(0, 960, 32)]
              for screen in four_screens]
    # reattach 4-screen
    ntrows = [l + r
              for (l, r) in zip(ntrows[0] + ntrows[2], ntrows[1] + ntrows[3])]
    # apply vertical scrolling
    toffset = yscroll * 2
    boffset = max(0, toffset - 30)
    ntrows = ntrows[toffset:toffset + 30] + ntrows[:boffset]
    # apply horizontal scrolling
    loffset = xscroll * 2
    roffset = max(0, loffset - 32)
    ntrows = [row[loffset:loffset + 32] + row[:roffset]
              for row in ntrows]
    
    # linearize attributes
    attrs = [[screen[i:i + 8] for i in range(960, 1024, 8)]
             for screen in four_screens]
    attrs = [l + r
             for (l, r) in zip(attrs[0] + attrs[2], attrs[1] + attrs[3])]
    attrs = [([((c >> 0) & 0x03, (c >> 2) & 0x03) for c in row],
              [((c >> 4) & 0x03, (c >> 6) & 0x03) for c in row])
             for row in attrs]
    attrs = [[subcol for byte in subrow for subcol in byte]
             for row in attrs for subrow in row]
    attrs = attrs[0:15] + attrs[16:31]

    # apply vertical scrolling
    boffset = max(0, yscroll - 15)
    attrs = attrs[yscroll:yscroll + 15] + attrs[:boffset]
    # apply horizontal scrolling
    roffset = max(0, xscroll - 16)
    attrs = [row[xscroll:xscroll + 16] + row[:roffset]
             for row in attrs]
    attrs.append([0]*16)

    # reassemble attributes
    attrs = [[row[i] | (row[i + 1] << 2) for i in range(0, 16, 2)]
             for row in attrs]
    attrs = [bytes(tc | (bc << 4) for (tc, bc) in zip(t, b))
             for (t, b) in zip(attrs[0::2], attrs[1::2])]
    ntrows.extend(attrs)
    return b"".join(ntrows)

def load_ppu(filename, pattable_base=0, xscroll=0, yscroll=0):
    """Load a PPU dump and convert it to SAV format."""
    with open(filename, 'rb') as infp:
        data = infp.read(16384)
    bgchr = data[pattable_base:pattable_base + 0x1000]
    spritechr = data[0x0000:0x0800]
    nametables = [data[i + 0x2000:i + 0x2400] for i in range(0, 0x1000, 0x400)]
    nametable = get_scrolled_nametable(nametables, xscroll, yscroll)
    palette = data[0x3F00:0x3F20]
    return b''.join([bgchr, spritechr, nametable,
                    b'\x00'*0x300, palette, b'\000'*0xE0])

def load_sav(filename):
    with open(filename, 'rb') as infp:
        return infp.read(8192)

def load_chr(filename):
    with open(filename, 'rb') as infp:
        data = infp.read(4096)
    return data + b'\xFF' * (4096 - len(data))

def load_chr_as_sav(filename):
    """Load a CHR file and provide a suitable default nametable for --show."""
    sav = bytearray(load_chr(filename)) + bytearray(4096)

    # Generate a nametable starting at (8, 6)
    offset = 6144 + 32 * 6 + 8
    for i in range(0, 256, 16):
        sav[offset:offset + 16] = range(i, i + 16)
        offset += 32

    # Poke in the palette
    sav[-256:-224] = default_palette * 2
    assert len(sav) == 8192
    return sav

def load_nam(filename):
    with open(filename, 'rb') as infp:
        namdata = infp.read(1024)
    sav = bytearray(8192)
    sav[6144:7168] = namdata
    sav[-256:-224] = default_palette * 2
    assert len(sav) == 8192
    return sav

# Bitmap image loading ##############################################

def bitmap_to_sav(im, max_tiles=None):
    """Convert a PIL bitmap without remapping the colors."""
    from pilbmp2nes import pilbmp2chr
    from chnutils import dedupe_chr
    (w, h) = im.size
    im = pilbmp2chr(im, 8, 8)

    if max_tiles is not None:
        from jrtilevq import reduce_tiles
        im = reduce_tiles(im, max_tiles)

    namdata = bytearray([0xFF]) * 960
    namdata.extend(bytes(64))
    # If smaller than 16384 pixels, output as a tile sheet
    # with a blank nametable
    if len(im) > 256:
        im, linear_namdata = dedupe_chr(im)
        if len(im) > 256:
            raise IndexError("image has %d distinct tiles, which exceeds 256"
                              % len(im))
        width_in_tiles = w // 8
        height_in_tiles = len(linear_namdata) // width_in_tiles
        topborder = (31 - height_in_tiles) // 2
        leftborder = (32 - width_in_tiles) // 2
        rightborder = 32 - width_in_tiles - leftborder
        offset = topborder * 32 + leftborder
        for i in range(0, len(linear_namdata), width_in_tiles):
            namdata[offset:offset + width_in_tiles] = linear_namdata[i:i + width_in_tiles]
            offset += 32
        assert len(namdata) == 1024

    chrdata = b''.join(im)
    chrpad = b'\xFF' * (6144 - len(chrdata))

    assert len(chrdata) <= 4096
    assert len(chrdata) + len(chrpad) == 6144
    assert len(namdata) == 1024
    sav = b''.join((chrdata, chrpad,
                    namdata, b'\xFF' * 768,
                    default_palette, default_palette, b'\xFF' * 224))
    assert len(sav) == 8192
    return sav

def ensure_pil():
    if not Image:
        print("%s: error: Pillow not installed" % os.path.basename(sys.argv[0]),
              file=sys.stderr)
        sys.exit(1)

def load_bitmap(filename, max_tiles=None):
    """Load a BMP, GIF, or PNG image without remapping the colors."""
    ensure_pil()
    return bitmap_to_sav(Image.open(filename), max_tiles)

# Rendering .sav file to bitmap #####################################

# Palette generated in 2012 with Bisqwit's NTSC NES palette generator
# <https://bisqwit.iki.fi/utils/nespalette.php>
# The settings have since been lost but were close to
#     hue 0, sat 1.2, contrast 1.0, brightness 1.0, gamma 2.2
# it was later clarified that sat 2 is closer to standard
bisqwit2012 = bytes.fromhex(
    '656565002d69131f7f3c137c600b62730a37710f075a1a00'
    '3428000b3400003c00003d10003840000000000000000000'
    'aeaeae0f63b34051d07841cca736a9c03470bd3c309f4a00'
    '6d5c00366d0007770400793d00727d000000000000000000'
    'fefeff5db3ff8fa1ffc890fff785faff83c0ff8b7fef9a49'
    'bdac2c85bc2f55c7533cc98c3ec2cd4e4e4e000000000000'
    'fefeffbcdfffd1d8ffe8d1fffbcdfdffcce5ffcfcaf8d5b4'
    'e4dca8cce3a9b9e8b8aee8d0afe5eab6b6b6000000000000'
)

known_cluts = {
    'bisqwit2012': bisqwit2012,
}

def sliver_to_texels(lo, hi):
    return [((lo >> i) & 1) | (((hi >> i) & 1) << 1)
            for i in range(7, -1, -1)]

def tile_to_texels(chrdata):
    _stt = sliver_to_texels
    return [_stt(a, b) for (a, b) in zip(chrdata[0:8], chrdata[8:16])]

def add_attr_to_texels(texels, attr):
    attr = attr * 4
    return [[c and c + attr for c in row] for row in texels]

def chrbank_to_texels(chrdata):
    _ttt = tile_to_texels
    return [_ttt(chrdata[i:i + 16]) for i in range(0, len(chrdata), 16)]

def texels_to_pil(texels, tile_width=16, row_height=1):
    ensure_pil()
    row_length = tile_width * row_height
    tilerows = [
        texels[j:j + row_length:row_height]
        for i in range(0, len(texels), row_length)
        for j in range(i, i + row_height)
    ]
    emptytile = [bytes(8)] * 8
    for row in tilerows:
        if len(row) < tile_width:
            row.extend([emptytile] * (tile_width - len(tilerows[-1])))
    texels = [bytes(c for tile in row for c in tile[y])
              for row in tilerows for y in range(8)]
    im = Image.frombytes('P', (8 * tile_width, len(texels)), b''.join(texels))
    im.putpalette(b'\x00\x00\x00\x66\x66\x66\xb2\xb2\xb2\xff\xff\xff'*64)
    return im

def decode_attribute_table(attrs):
    """Decode a 64-byte NES attribute table to a 16x15 grid."""

    from binascii import b2a_hex
    
    # linearize attributes
    attrs = [attrs[i:i + 8] for i in range(0, 64, 8)]
    attrs = [([((c >> 0) & 0x03, (c >> 2) & 0x03) for c in row],
              [((c >> 4) & 0x03, (c >> 6) & 0x03) for c in row])
             for row in attrs]
    attrs = [[subcol for byte in subrow for subcol in byte]
             for row in attrs for subrow in row]
    return attrs[:15]

def render_bitmap(sav, clut):
    """Render a background in a save file to an indexed image.

sav -- save file from which to pull the CHR, tilemap, and palette
clut -- a list of 64 tuples
"""
    chrdata = sav[0x0000:0x1000]
    palette = sav[0x1F00:0x1F20]
    rgbpalette = [clut[c & 0x3F] for c in palette]
    tiles = chrbank_to_texels(chrdata)
    nam = sav[0x1800:0x1C00]
    attrs = decode_attribute_table(nam[0x3C0:])
    r2 = (0,1)
    attrs = [[c for c in row for i in r2] for row in attrs for i in r2]
    nam = [nam[i:i + 32] for i in range(0, 960, 32)]
    tile = add_attr_to_texels(tiles[nam[2][3]], attrs[2][3])
    colortiles = [add_attr_to_texels(tiles[tn], cs)
                  for (nr, ar) in zip(nam, attrs) for (tn, cs) in zip(nr, ar)]
    im = texels_to_pil(colortiles, 32)
    im.putpalette(b''.join(rgbpalette) * 8)
    return im

def render_tilesheet(sav, colorset, clut):
    """Render a CHR sheet to an indexed image.

sav -- save file from which to pull the CHR sheet and palette
colorset -- which subpalette to use (0 to 7)
clut -- a list of 64 tuples
"""
    chrdata = sav[0x0000:0x1000]
    palette = sav[0x1F00:0x1F20]
    rgbpalette = [clut[c & 0x3F] for c in palette]
    tiles = texels_to_pil(chrbank_to_texels(chrdata))
    subpal = rgbpalette[0:1] + rgbpalette[colorset*4+1:colorset*4+4]
    tiles.putpalette(b''.join(subpal) * 64)
    return tiles

# Remapping a picture to use another .chr file ######################

def tile_is_blank(tile):
    blankplanes = (b'\xFF'*8, b'\x00'*8)
    return (tile[0:8] in blankplanes and tile[8:16] in blankplanes)

def remap_sav_to_chr(srcsav, dstsheet):
    # Find sets of all tiles, as mappings to their first occurrence
    # in the tile set
    srctiles = [srcsav[i:i + 16] for i in range(0, 4096, 16)]
    dsttiles = [dstsheet[i:i + 16] for i in range(0, 4096, 16)]
    srcseen = {}
    for i, t in enumerate(srctiles):
        srcseen.setdefault(t, i)
    dstseen = {}
    dstdupes = []
    for i, t in enumerate(dsttiles):
        dstdupes.append(t in dstseen)
        dstseen.setdefault(t, i)

    # find all tiles in srctileset that are not in dsttileset
    spaces_needed = sorted((i, t) for (t, i) in srcseen.items()
                           if t not in dstseen)

    # Find candidates for replacement within the new tile sheet by
    # priority:
    # 1. Duplicate tiles
    # 2. Blank tiles
    # 3. Other tiles not shared
    dstshared = [(i, t, t in srcseen, tile_is_blank(t), dupe)
                 for i, (t, dupe) in enumerate(zip(dsttiles, dstdupes))]
    candidates = [(not dupe, not blank, i)
                  for (i, t, shared, blank, dupe) in dstshared
                  if dupe or not shared]
    candidates.sort()
    assert len(candidates) >= len(spaces_needed)
    replacements = zip(spaces_needed,
                       sorted(row[2] for row in candidates[:len(spaces_needed)]))
    # rows of replacements are of the form
    # (src tile number, tile data, dst tile number)

    for ((srctilenum, tiledata), dsttilenum) in replacements:
        dsttiles[dsttilenum] = tiledata
        dstseen[tiledata] = dsttilenum

    newnam = bytearray(dstseen[srctiles[i]] for i in srcsav[0x1800:0x1BC0])
    return b''.join((b''.join(dsttiles),
                    srcsav[0x1000:0x1800], newnam, srcsav[0x1BC0:]))

def sav_reduce_tiles(sav, max_tiles):
    from jrtilevq import reduce_tiles

    # Reconstitute image from tile set and tile map
    chrdata = [sav[i:i + 16] for i in range(0, 0x1000, 0x10)]
    chrdata = [chrdata[i] for i in sav[0x1800:0x1BC0]]

    # Reduce tiles
    chrdata = reduce_tiles(chrdata, max_tiles)
    print(len(chrdata), max_tiles)

    # Form the new tilemap
    nt = bytearray()
    tiletoid = {}
    for tile in chrdata:
        tiletoid.setdefault(tile, len(tiletoid))
        nt.append(tiletoid[tile])
    newchrdata = [b''] * len(tiletoid)
    for t, n in tiletoid.items():
        newchrdata[n] = t
    assert(len(nt) == 960)
    assert(len(newchrdata) <= max_tiles)

    # And put it in a new sav file
    newsav = bytearray(b''.join(newchrdata))
    newsav.extend(bytes(0x1000 - len(newsav)))
    newsav.extend(sav[0x1000:0x1800])
    newsav.extend(nt)
    newsav.extend(sav[0x1BC0:])
    assert(len(newsav) == 8192)
    return bytes(newsav)

# Rounding a bitmap toward a given palette ##########################

# There are holes in PIL's indexed image conversion API, which appear
# to prompt abstraction inversion.  convert() supports color rounding
# or Floyd-Steinberg dithering, but it supports only web or adaptive
# palette, not a specific palette.  quantize() supports a specific
# palette, but Floyd-Steinberg dithering can't be turned off.
# So I have to do all the conversion pixel by pixel, and it's slow
# as [expletive] in pure Python.  Caching individual converted colors
# speeds up the process for pictures that are already indexed or
# nearly so, so cache the 1024 most common colors.

def closestcolor(rgb, palette):
    r, g, b = rgb
    palette = [(r2 - r, g2 - g, b2 - b) for (r2, g2, b2) in palette]
    palette = [3*r2*r2 + 6*g2*g2 + b2*b2 for (r2, g2, b2) in palette]
    best = sorted(enumerate(palette), key=lambda i: i[1])[0][0]
    return best

def colorround(im, palettes):
    from collections import Counter
    from itertools import chain
    ensure_pil()
    im = im.convert('RGB')
    (w, h) = im.size
    imd = list(im.getdata())  # a list of (R, G, B) tuples in imd
    imdset = frozenset(x[0] for x in Counter(imd).most_common(1024))
    trials = []
    outpal = list(chain.from_iterable(chain.from_iterable(palettes)))
    pbase = 0
    for p in palettes:
        # Convert the image to this 4-color palette
        colordic = dict((rgb, closestcolor(rgb, p) + pbase) for rgb in imdset)
        imm = bytearray(colordic[rgb]
                        if rgb in colordic
                        else closestcolor(rgb, p) + pbase
                        for rgb in imd)
        imp = Image.new('P', im.size)
        imp.putpalette(outpal)
        imp.putdata(imm)
        pbase += len(p)

        # For each 16x16 pixel area, calculate the difference
        # between it and the original
        impr = imp.convert('RGB')
        diff = ImageChops.difference(im, impr)
        difftiles = [diff.crop((l, t, l + 16, t + 16))
                     for t in range(0, h, 16) for l in range(0, w, 16)]
        difftiles = [list(tile.getdata()) for tile in difftiles]
        difftiles = [sum(3*r*r+6*g*g+b*b for (r, g, b) in tile)
                     for tile in difftiles]
        trials.append((imp, difftiles))

    # Find the best attribute for each 16x16 pixel area
    attrs = [sorted(enumerate(i), key=lambda i: i[1])[0][0]
             for i in zip(*(difftiles for (imp, difftiles) in trials))]

    # Calculate the resulting image
    tls = zip(((l, t) for t in range(0, h, 16) for l in range(0, w, 16)),
              attrs)
    imf = Image.new('P', im.size)
    imf.putpalette(outpal)
    for ((l, t), attr) in tls:
        imf.paste(trials[attr][0].crop((l, t, l+16, t+16)), (l, t))
    attrw = -(-w // 16)
    attrs = [attrs[i:i + attrw] for i in range(0, len(attrs), attrw)]
    return (imf, attrs)

def load_bitmap_with_palette(filename, palette, clut, max_tiles=None):
    ensure_pil()
    from pilbmp2nes import pilbmp2chr
    im = Image.open(filename)
    (w, h) = im.size
    palettes = [tuple(clut[i]) for i in palette]
    palettes = [[palettes[0]] + palettes[i + 1:i + 4]
                for i in range(0, 16, 4)]

    if w != 256 or h != 240:
        i2 = Image.new("RGB", (256, 240), palettes[0][0])
        i2.paste(im, ((256 - w) // 2, (240 - h) // 2))
        im = i2
    (imf, attrs) = colorround(im, palettes)
    if len(attrs) % 2:
        attrs.append([0] * len(attrs[0]))
    sav = bitmap_to_sav(imf)
    attrs = [[row[i] | (row[i + 1] << 2) for i in range(0, 16, 2)]
             for row in attrs]
    attrs = [bytes(tc | (bc << 4) for (tc, bc) in zip(t, b))
             for (t, b) in zip(attrs[0::2], attrs[1::2])]
    attrs = b''.join(attrs)
    return b''.join((sav[0:0x1BC0], attrs, sav[0x1C00:0x1F00],
                     palette, palette, sav[0x1F20:]))

# Saving the NES palette that this converter uses ###################

hexfont = [
    0x6999960, 0x2622220, 0x69168f0, 0x6161960,
    0x359f110, 0x78e1960, 0x68e9960, 0xf122440,
    0x6969960, 0x6997160, 0x0617970, 0x8e999e0,
    0x0698960, 0x1799970, 0x069f870, 0x34e4440,
]
HEXFONT_HT = 8
HEXFONT_ADVANCE = 5

def write_hex_digits(im, xy, value, length, fill):
    left, top = xy
    width, height = im.size
    px = im.load()
    for placevalue in reversed(range(length)):
        glyph = hexfont[(value >> (placevalue * 4)) & 0x0F]
        for y in range(HEXFONT_HT):
            sliver_y = top + y
            glyphrow = (glyph >> ((HEXFONT_HT - y - 1) * 4)) & 0x0F
            if glyphrow == 0 or not 0 <= sliver_y < height: continue
            for x in range(left, min(width, left + 4)):
                if glyphrow & 0x08 and 0 <= x:
                    px[x, sliver_y] = fill
                glyphrow <<= 1
        left += HEXFONT_ADVANCE

def colorname(colorid):
    colorid &= 0x3F
    if colorid == 0x0F: return "Black"
    row, column = colorid >> 4, colorid & 0x0F
    if column >= 0x0E: return "Duplicate black"
    if column == 0x00:
        levels = ['Dark gray', 'Light gray', 'White', 'Overbright white']
        return levels[row]
    if column == 0x0D:
        levels = ['Blacker than black', 'Tintable black', 'Darker gray', 'Duplicate light gray']
        return levels[row]
    hues = [
        "aquamarine", "blue", "indigo", "magenta",
        "pink", "red", "orange", "olive",
        "chartreuse", "green", "sea green", "turquoise"
    ]
    levels = ["Dark", "Medium", "Light", "Pale"]
    return " ".join((levels[row], hues[column - 1]))

def save_swatches(clut, clutname, filename=None):
    from PIL import ImageFont, ImageDraw
    assert len(clut) == 64

    # stdout or .txt is 64 lines as follows:
    # 0C<tab>#003840
    if filename is None or filename.lower().endswith(".txt"):
        lines = "".join(
            "%02x\t#%s\n" % (i, b.hex())
            for i, b in enumerate(clut)
        )
        if filename is None:
            sys.stdout.write(lines)
        else:
            with open(filename, "w", encoding="utf-8") as outfp:
                outfp.write(lines)
        return

    # .gpl is a header then 64 lines as follows:
    #   0  56  64     $0c
    # This can be placed somewhere like
    # /home/pino/.gimp-2.8/palettes
    if filename.lower().endswith(".gpl"):
        lines = ["""GIMP Palette
Name: %s
Columns: 16
#
""" % clutname]
        lines.extend(
            "%3d%4d%4d\t$%02x %s\n" % (b[0], b[1], b[2], i, colorname(i))
            for i, b in enumerate(clut)
        )
        with open(filename, "w", encoding="utf-8") as outfp:
            outfp.writelines(lines)
        return

    # .pal files for use with emulators is just a 192 byte
    # binary dump (RGBRGBRGB...)
    # This can be placed somewhere like
    # /home/pino/.local/share/fceux/palettes
    # C:\Program Files (x86)\FCEUX\palettes
    if filename.lower().endswith(".pal"):
        with open(filename, "wb") as outfp:
            outfp.writelines(clut)
        return

    # Otherwise, it's an image (.bmp, .gif, .png)
    cellw, cellh = 24, 24
    im = Image.new('P', (16*cellw, 5*cellh), 0x0F)
    im.putpalette(b''.join(clut) + b"\xff\x00\xff" * (256 - len(clut)))
    fnt = ImageFont.load_default()
    dc = ImageDraw.Draw(im)
    headerh = cellh
    captionpos = (cellw * 16 // 2, headerh // 2)
    dc.text(captionpos, clutname, font=fnt, fill=0x20, anchor="mm")
    for row in range(4):
        y = row * cellh + headerh
        for col in range(16):
            x = col * cellw
            colornumber = row * 16 + col
            dc.rectangle((x, y, x + cellw, y + cellh), fill=colornumber)

            if colornumber == 0x0D:
                # Draw no-no color marker
                dc.ellipse((x, y, x + cellw - 1, y + cellh - 1),
                           width=4, outline=0x16)
                dc.line((x + cellw // 6, y + cellh // 6,
                         x + 5 * cellw // 6, y + 5 * cellh // 6),
                        width=3, fill=0x16)

            # draw caption
            graylevel = (row + 1 if col < 1
                         else row if col < 13
                         else row - 1 if col < 14
                         else 0)
            captioncolor = 0x20 if graylevel < 2 else 0x0F
            captionpos = (x + cellw - 2 * HEXFONT_ADVANCE,
                          y + cellh - HEXFONT_HT)
            write_hex_digits(im, captionpos, colornumber, 2, captioncolor)
    if filename and filename != '--show':
        im.save(filename)
    else:
        im.convert("RGB").show()

# CLI front end #####################################################

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    (infilename, outfilename, chrfilename,
     xscroll, yscroll, palette, printpalette, writechr,
     show, remap, swatchfilename, max_tiles, clutname) = args
    progname = os.path.basename(sys.argv[0])
    try:
        clut = known_cluts[clutname]
    except KeyError:
        if clutname[-4:].lower() == '.png':
            with Image.open(clutname) as im:
                if im.mode != 'P':
                    print("savtool.py: %s: palette image must be mode P (indexed), not mode %s"
                          % (clutname, im.mode))
                    sys.exit(1)
                clut = im.getpalette()
        else:
            with open(clutname, "rb") as infp:
                clut = infp.read(192)
        clutname = os.path.basename(clutname)
    clut = [bytes(clut[i:i + 3]) for i in range(0, 192, 3)]

    if swatchfilename:
        save_swatches(clut, clutname,
                      swatchfilename if swatchfilename != '-' else None)
        if not infilename:
            return

    intype = infile_exts[os.path.splitext(infilename)[1].lstrip('.').lower()]
    outtype = outfilename and infile_exts[os.path.splitext(outfilename)[1].lstrip('.').lower()]
    m = chrfilename and xdigitRE.match(chrfilename)
    if intype == 'ppu' and m:
        chrtype = None
        chrbase = int(m.group(1), 16)
    else:
        chrtype = chrfilename and infile_exts[os.path.splitext(chrfilename)[1].lstrip('.').lower()]
        chrbase = 0
    m = palette and xdigitRE.match(palette)
    if m and len(m.group(1)) == 32:
        paltype = 'literal'
        palette = bytes.fromhex(m.group(1))
    else:
        paltype = palette and infile_exts[os.path.splitext(palette)[1].lstrip('.').lower()]

    if paltype == 'ppu':
        palette = load_ppu(palette)[0x1F00:0x1F10]
        paltype = 'literal'
    elif paltype == 'sav':
        palette = load_sav(palette)[0x1F00:0x1F10]
        paltype = 'literal'
    if paltype and paltype != 'literal':
        print("%s: %s palette type not yet implemented" % (progname, paltype),
              file=sys.stderr)
        sys.exit(1)

    if intype == 'ppu':
        sav = load_ppu(infilename, chrbase, xscroll, yscroll)
    elif intype == 'chr':
        sav = load_chr_as_sav(infilename)
    elif intype == 'sav':
        sav = load_sav(infilename)
    elif intype == 'bmp':
        # max_tiles has to be passed to bitmap loaders because
        # otherwise they can 
        if palette:
            sav = load_bitmap_with_palette(infilename, palette, clut, max_tiles)
        else:
            sav = load_bitmap(infilename, max_tiles)
    elif intype == 'nam':
        sav = load_nam(infilename)
    else:
        print("%s: %s input type not yet implemented" % (progname, intype),
              file=sys.stderr)
        sys.exit(1)

    ntuniques = len(set(sav[0x1800:0x1BC0]))
    if max_tiles is not None and max_tiles < ntuniques:
        print("Reducing", ntuniques, "uniques to", max_tiles)
        sav = sav_reduce_tiles(sav, max_tiles)

    changed = False
    if paltype == 'literal':
        sav = b''.join((sav[:0x1F00], palette, sav[0x1F10:]))
        changed = True

    chrdata = None
    if chrtype in ('ppu', 'sav', 'chr'):
        chrdata = load_chr(chrfilename)
    elif chrtype == 'bmp':
        from pilbmp2nes import pilbmp2chr
        with Image.open(chrfilename) as chrim:
            chrdata = pilbmp2chr(chrim, 8, 8)
        chrdata.extend(chrdata[:1] * (256 - len(chrdata)))
        chrdata = b''.join(chrdata)
    elif chrtype:
        print("%s: %s tile sheet type not yet implemented" % (progname, chrtype),
              file=sys.stderr)
        sys.exit(1)
    if chrdata:
        if remap:
            assert len(chrdata) <= 4096
            sav = remap_sav_to_chr(sav, chrdata)
        else:
            assert len(chrdata) >= 4096
            sav = chrdata[:4096] + sav[4096:]
        changed = True

    im = None
    if show or outtype == 'bmp':
        im = (render_tilesheet(sav, writechr, clut)
              if writechr is not None
              else render_bitmap(sav, clut))
    if outtype == 'bmp':
        im.save(outfilename)
    elif outtype == 'chr':
        with open(outfilename, 'wb') as outfp:
            outfp.write(sav[:0x1000])
    elif outtype == 'nam':
        with open(outfilename, 'wb') as outfp:
            outfp.write(sav[0x1800:0x1C00])
    elif outtype == 'sav':
        with open(outfilename, 'wb') as outfp:
            outfp.write(sav)
    elif outtype and (changed or outfilename != infilename):
        print("%s: %s output type not yet implemented" % (os.path.basename(sys.argv[0]), outtype),
              file=sys.stderr)
        sys.exit(1)
    if show:
        im.convert("RGB").show()
    if printpalette:
        print(''.join('%02x' % b for b in sav[0x1F00:0x1F10]))

    # TO DO:
    # Convert color PNG and guess palette

def test_suite():
    test_argv()
    main(["savtool.py", "../docs/smb1.ppu", "--chr", "1000", "--show"])
    input("Viewing SMB1 PPU dump")
    main(["savtool.py", "../docs/smb1.ppu", "--chr", "1000", "smb1.ppu.png"])
    main(["savtool.py", "../docs/smb1.ppu", "--chr", "1000", "--write-chr", "1", "--show"])
    input("Viewing SMB1 CHR ROM")
    main(["savtool.py", "../sample_savs/pm.sav", "test_chr.bmp", "--write-chr", "1"])
    main(["savtool.py", "../sample_savs/pm.sav", "test_out.png"])
    main(["savtool.py", "../sample_savs/pm.sav", "--print-palette", 'pm.sav.png'])
    print("above is palette for PM")
    main(["savtool.py", "../docs/smb1.ppu", "--chr", "1000", "smb1.ppu.sav"])
    main(["savtool.py", "../docs/kiddie scratch1.png", "stick_figure.png.sav"])
    main(["savtool.py", "../docs/smb1.ppu", "smb1_chr.png", "--chr", "1000", "--write-chr", "1"])
    main(["savtool.py", "smb1_chr.png", "blank_with_smb1_chr.sav"])
    main(["savtool.py", "../sample_savs/pm.sav", "pm.sav.nam"])
    main(["savtool.py", "../sample_savs/pm.sav", "pm.sav.chr"])
    main(["savtool.py", "pm.sav.nam", "--chr", "pm.sav.chr", "--palette", "0f0026300f1726300f2726300f152630", "--show"])
    input("Viewing PM reassembled from CHR and NAM with literal palette")
    main(["savtool.py", "pm.sav.nam", "--chr", "pm.sav.chr", "--palette", "../sample_savs/pm.sav", "--show"])
    input("Viewing PM reassembled from CHR and NAM with palette from SAV")
    main(["savtool.py", "../sample_savs/pm.sav", '--write-chr', '0', "pm.chr.png"])
    main(["savtool.py", "pm.sav.nam", "--chr", "pm.chr.png", "--palette", "0f0026300f1726300f2726300f152630", "pm_reassembled.sav"])
    main(["savtool.py", "pm_reassembled.sav", "--show"])
    input("Viewing the same, except as a SAV")
    main(["savtool.py", "../sample_savs/RPG_village.sav", "--remap", "--chr", "../sample_savs/prez.sav", "RPG_village_with_prez_chr.sav"])
    main(["savtool.py", "RPG_village_with_prez_chr.sav", "--show"])
    input("Viewing RPG village remapped into prez tile sheet")
    main(["savtool.py", "RPG_village_with_prez_chr.sav", "--write-chr", "0", "--show"])
    input("Viewing prez tile sheet that has had RPG village tiles inserted")
    main(["savtool.py", "../sample_savs/RPG_village.sav", "RPG_village.png"])
    main(["savtool.py", "RPG_village.png", "--palette", "0f1219270f1019170f1623270f021222", "--show"])
    input("Viewing RPG_village converted to PNG and back with a palette")
    print("""Copy the sav files from this folder to a PowerPak and make sure they
look correct.""")

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        test_suite()
    else:
        main()
