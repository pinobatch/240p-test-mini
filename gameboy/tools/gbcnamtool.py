#!/usr/bin/env python3
from PIL import Image, ImageChops

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
        diff = [
            sum(2*r*r+4*g*g+3*b*b for (r, g, b) in tile.getdata())
            for tile in diff
        ]
        # diff is the overall color difference for each color area
        # of this image, using weights 2, 4, 3 per
        # https://en.wikipedia.org/w/index.php?title=Color_difference&oldid=840435351
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

def main():
    palette_filename = "../docs/Gus-portrait-GBC.pal.txt"
    imfilename = "../docs/Gus-portrait-GBC.png"
    im = Image.open(imfilename)
    if im.mode != 'RGB':
        im = im.convert('RGB')
    with open(palette_filename, "r") as infp:
        lines = [l.split("//", 1)[0].strip() for l in infp]
    palettes = [
        [hextotuple(c) for c in l.split()]
        for l in lines
        if l
    ]
    imfinal, attrs = colorround(im, palettes, (8, 8), 4)
    imfinal.save("imfinal.png")

if __name__=='__main__':
    main()
