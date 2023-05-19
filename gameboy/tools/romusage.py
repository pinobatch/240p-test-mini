#!/usr/bin/env python3
"""
Visualizer of Game Boy 2bpp files (and free space in ROM images)
Copyright 2019, 2022 Damian Yerrick

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

import sys, argparse
from PIL import Image

def hexdump(b, w=32):
    print("\n".join(b[i:i + w].hex() for i in range(0, len(b), w)))

def render_to_texels(data, twidth=16):
    rowbytes = 16 * twidth
    numrows = -(-len(data) // rowbytes)
    texels = bytearray()
    for i in range(numrows):
        rowdata = data[i * rowbytes:i * rowbytes + rowbytes]
        if len(rowdata) < rowbytes:
            rowdata = rowdata + bytes(rowbytes - len(rowdata))
        plane0 = b''.join(rowdata[i::16] for i in range(0, 16, 2))
        plane1 = b''.join(rowdata[i::16] for i in range(1, 17, 2))
        for p0, p1 in zip(plane0, plane1):
            texels.extend(
                ((p0 >> x) & 1) | (((p1 >> x) & 1) << 1)
                for x in range(7, -1, -1)
            )
    im = Image.new('P', (8 * twidth, 8 * numrows))
    im.putdata(texels)
    im.putpalette(b'\xC0\xFF\x5F\x80\xBF\x5F\x40\x7F\x5F\x00\x3F\x5F')
    return im

helpText="Visualize space usage in a file by treating it as Game Boy graphics"

def parse_argv(argv):
    p = argparse.ArgumentParser(description=helpText)
    p.add_argument("romname", help="name of a Game Boy ROM")
    p.add_argument("output", nargs='?', default=None,
                   help="output file (if omitted, display on screen)")
    p.add_argument("-w", "--width", type=int, default=32,
                   help="number of 16-byte chunks per line (default: 32)")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    argv = argv or sys.argv
    with open(args.romname, "rb") as infp:
        romdata = infp.read()
    twidth = args.width
    tiles = render_to_texels(romdata, twidth)
    if args.output:
        tiles.save(args.output)
    else:
        tiles.show()

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(['./romusage.py', '../gb240p.gb'])
    else:
        main()
