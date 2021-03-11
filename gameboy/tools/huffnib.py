#!/usr/bin/env python3
"""
Canonical Huffman experiment

Copyright 2019 Damian Yerrick

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
import argparse
import heapq
from collections import Counter
from bitbyte import BitByteInterleave

# Huffman coding core ###############################################

def build_huffman_tree(freqs):
    """Build a parent-linked Huffman tree from an iterable of weights.

After O(n log n) steps, return a list of parent IDs where
- each element x contains the index of x's parent
- elements 0 through len(freqs) - 1 are leaves, in the same order
  as freqs
- length is len(freqs) * 2 - 1
"""
    symheap = [(fi, i) for i, fi in enumerate(freqs)]
    nodetoparent = list(range(len(symheap)))
    heapq.heapify(symheap)
    while len(symheap) > 1:
        lfreq, lsymbol = heapq.heappop(symheap)
        rfreq, rsymbol = heapq.heappop(symheap)
        newfreq = lfreq + rfreq
        newnode = len(nodetoparent)
        nodetoparent.append(newnode)
        nodetoparent[lsymbol] = nodetoparent[rsymbol] = newnode
        heapq.heappush(symheap, (newfreq, newnode))
    return nodetoparent

# Canonical form (lengths and sorted symbols) #######################

def CH_calc_lengths(nodetoparent, returnall=False):
    """Calculate code lengths in a parent-linked Huffman tree.

After O(n) steps, return a list of code lengths for the leaves,
taken to be the tree's first len(nodetoparent) // 2 + 1 elements.
"""
    symlengths = [0] * len(nodetoparent)
    for symbol in range(len(nodetoparent))[::-1]:
        parent = nodetoparent[symbol]
        lengthadd = 1 if symbol < parent else 0
        symlengths[symbol] = symlengths[parent] + lengthadd
    if not returnall:
        del symlengths[len(nodetoparent) // 2 + 1:]
    return symlengths

def CH_assign_bitstrings(codes_per_length):
    """Assign consecutive bit strings for each length."""
    bitstrings = []
    ending_code = 0
    for lminus1, ncodesofthislength in enumerate(codes_per_length):
        starting_code = ending_code << 1
        ending_code = starting_code + ncodesofthislength
        bitstrings.extend(range(starting_code, ending_code))
    return bitstrings

def CH_build(freqs):
    """Build a canonical Huffman code for a given tree.

freqs -- mapping from symbols to weights or (symbol, weight) iterable

Return a 2-tuple (symbols_with_lengths, codes_per_length)

symbols_with_lengths is a list of (symbol, length, bitstring) where

- length is a positive integer
- Symbols are sorted by increasing length then by symbol value
- Kraft's inequality: Sum of 1/(1 << length) for all lengths is 1
- Sum of length * weight for each symbol is minimized
- Values of bitstring form a prefix code, lexicographically sorted
  by position in the result
- bitstring >> bit_length == 0

codes_per_length is a list of the number of codes of each bit length
starting with 1.
"""
    try:
        freqsitems = list(freqs.items())
    except AttributeError:
        freqsitems = list(freqs)
    nodetoparent = build_huffman_tree(fi[1] for fi in freqsitems)
    symlengths = CH_calc_lengths(nodetoparent)
    lc = Counter(symlengths)
    codes_per_length = [lc.get(i + 1, 0) for i in range(max(lc))]
    bitstrings = CH_assign_bitstrings(codes_per_length)
    lengths = [
        (symbol, length)
        for (symbol, _), length in zip(freqsitems, symlengths)
    ]
    lengths.sort(key=lambda row: (row[1], row[0]))
    lengths = [
        (symbol, length, bitstring)
        for (symbol, length), bitstring in zip(lengths, bitstrings)
    ]
    return lengths, codes_per_length

def CH_decode(codes_per_length, getbit):
    """Decode one code from a Canonical Huffman code stream.

codes_per_length -- sequence of numbers of codes that have
    1, 2, 3, ... bits
getbit -- a function that when called repeatedly returns values 0 and 1

Return an index into the list of terminal symbols.
"""
    accumulator = 0
    range_end = 0
    for ncodesofthislength in codes_per_length:
        range_end += ncodesofthislength
        accumulator = ((accumulator << 1) | getbit()) - ncodesofthislength
        if accumulator < 0:
            return accumulator + range_end

def biterate_bytes_be(data):
    """Iterate over the bits in a byte string, MSB first"""
    for b in data:
        for i in range(7, -1, -1):
            yield (b >> i) & 1

def biterate_int(bitstring, length):
    """Iterate over the bits in an integer."""
    while length >= 0:
        length -= 1
        yield (bitstring >> length) & 1

# Test framework ####################################################

# ref: https://rosettacode.org/wiki/Huffman_coding
rosetta_test_text = "this is an example for huffman encoding"

def hexdump(b, w=32):
    print("\n".join(b[i:i + w].hex() for i in range(0, len(b), w)))

def txttest(txt, codedisplimit=5):
    # Construct the code
    freqs = Counter(txt)
    result = CH_build(freqs)
    lengths, codes_per_length = result

    # Count total
    print("\n".join(
        "{0} x{1:3}: {3:0{2}b}".format(symbol, freqs[symbol], length, bitstring)
        for symbol, length, bitstring
        in lengths[:codedisplimit]
    ))
    weightsum = sum((freqs[s] * length) for s, length, _ in lengths)
    print("code counts %s; weightsum %d"
          % (codes_per_length, weightsum))

    decode_result = [
        CH_decode(codes_per_length, biterate_int(bitstring, length).__next__)
        for symbol, length, bitstring in lengths
    ]
    expected = list(range(len(lengths)))
    print("decode: pass" if decode_result == expected else "decode: fail")
    return weightsum

def rosetta_test():
    """Run a Canonical Huffman test on the Rosetta Code test string."""
    return txttest(rosetta_test_text, codedisplimit=len(rosetta_test_text))

def nibble_test(data):
    """Run a Huffman compression test on the nibbles in a byte string."""
    weightsum = txttest(data.hex(), 16)
    afterbytes = 16 + weightsum // 8
    print("would compress %d bytes to %d saving %d"
          % (len(data), afterbytes, len(data) - afterbytes))
    return len(data) - afterbytes

def popcnt(data):
    n = 0
    while data:
        data &= data - 1
        n += 1
    return n

def iutest(data):
    """Run a Canonical Huffman test on the tile data in an incruniq file."""
    num_pb16_packets = data[0] * 2
    startoffset = offset = 1
    for i in range(num_pb16_packets):
        numrepeats = popcnt(data[offset])
        offset += 9 - numrepeats
    print("%d bytes in tiles" % (offset - startoffset))
    return nibble_test(data[startoffset:offset])

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
    """Convert a mode 7 tile to a 1bpp tile."""
    out = bytearray()
    for y in range(0, len(tile), 8):
        row = tile[y:y + 8]
        byte = 0
        for c in row:
            byte = (byte << 1) | (c & 1)
        out.append(byte)
    return bytes(out)

def fonttest():
    """Run a Canonical Huffman test on the 240p-test-mini font glyphs."""
    from PIL import Image

    im = Image.open("../../common/tilesets/vwf7_cp144p.png")
    imbytes = bytes(1 if c == 1 else 0 for c in im.tobytes())
    tiles = [m7tileto1btile(x) for x in pixelstom7tiles(imbytes, im.size)]
    print("Proportional font data")
    return nibble_test(b"".join(tiles))

def CH_test():
    saved = 0

    with open("../obj/gb/helptiles.chrgb16.pb16", "rb") as infp:
        data = infp.read()
    print("DMG help tiles")
    saved += nibble_test(data)

    with open("../obj/gb/helptiles-gbc.chrgb16.pb16", "rb") as infp:
        data = infp.read()
    print("GBC help tiles")
    saved += nibble_test(data)

    with open("../obj/gb/greenhillzone.u.chrgb.pb16", "rb") as infp:
        data = infp.read()
    print("Hill zone tiles")
    saved += nibble_test(data)

    with open("../obj/gb/stopwatchdigits.chrgb.pb16", "rb") as infp:
        data = infp.read()
    print("Stopwatch digits")
    saved += nibble_test(data)

    with open("../obj/gb/stopwatchhand.chrgb.pb16", "rb") as infp:
        data = infp.read()
    print("Stopwatch hand")
    saved += nibble_test(data)

    with open("../obj/gb/linearity-quadrant.iu", "rb") as infp:
        data = infp.read()
    print("Linearity")
    saved += iutest(data)

    with open("../obj/gb/sharpness.iu", "rb") as infp:
        data = infp.read()
    print("Sharpness")
    saved += iutest(data)

    with open("../obj/gb/stopwatchface.iu", "rb") as infp:
        data = infp.read()
    print("Stopwatch face")
    saved += iutest(data)

    with open("../obj/gb/Gus_portrait.iu", "rb") as infp:
        data = infp.read()
    print("Gus portrait (DMG)")
    saved += iutest(data)

    saved += fonttest()

    print("Estimated total savings: %d bytes" % saved)
    print("This is even before counting (e.g.) Gus portrait GBC")

# Actual encoding ###################################################

def huffnibenc(data):
    """Compress a byte sequence using nibble-wise Huffman coding.

Each compressed stream begins with a decoding table, whose length
is the same as the number of distinct nibbles in the decompressed
data.  The low nibble of each byte represents the nibbles sorted
by increasing code length, and the upper nibble of each byte is the
number of codes of each length.  The last byte is OR'd with $F0.

The decoding table for a stream that could not be compressed is
a single byte with value $FF (or any byte at least $30).

In either case, the decoding table is followed by a 2-byte
little-endian length of the decompressed data in bytes, then the
compressed or uncompressed data.  In compressed data, the code
for the high nibble comes before the code for the low nibble.
"""
    freqs = Counter(b & 0x0F for b in data)
    freqs.update(b >> 4 for b in data)
    syms, codes_per_length = CH_build(freqs)
    assert 2 < len(codes_per_length) < len(syms)
    is_huffman = all(b < 15 for b in codes_per_length)

    # Build header
    out = bytearray()
    if is_huffman:
        out.extend(row[0] for row in syms)
        out[-1] |= 0xF0  # last symbol
        for i, ncodes in enumerate(codes_per_length):
            out[i] |= ncodes << 4
    else:
        print("huff: warning: binary with codes_per_length %s"
              % repr(codes_per_length), file=sys.stderr)
        out.append(0xFF)
    out.append(len(data) & 0xFF)
    out.append(len(data) >> 8)
    if is_huffman:
        bits = BitByteInterleave()
        symtolb = {s: (length, value) for s, length, value in syms}
        for b in data:
            length, value = symtolb[b >> 4]
            bits.putbits(value, length)
            length, value = symtolb[b & 0x0F]
            bits.putbits(value, length)
        out.extend(bytes(bits))
    else:
        out.extend(data)
    return bytes(out)

def test_huffnibenc():
    data = bytes.fromhex("6969556778556778")
    enc = huffnibenc(data)
    expect = bytes.fromhex("05362708F908007bc1ac0d60")
    print(data.hex())
    print(enc.hex())
    print(expect.hex())
    print("Match" if enc == expect else "No match")

def main(argv=None):
    argv = argv or sys.argv
    if len(argv) > 1 and argv[1] in ['--help', '-h', '-?', '/?']:
        print("""usage: huffnib.py INFILE OUTFILE
Nibblewise Huffman compressor""")
        return
    infilename, outfilename = argv[1:3]
    with open(infilename, "rb") as infp:
        data = infp.read()
    enc = huffnibenc(data)
    with open(outfilename, "wb") as outfp:
        outfp.write(enc)

if __name__=='__main__':
    if "idlelib" in sys.modules:
        test_huffnibenc()
    else:
        main()
