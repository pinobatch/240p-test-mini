#!/usr/bin/env python3
"""
Canonical Huffman tools: Because Huffman-Cano is more efficient
than Shannon-Fano

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
import heapq
from collections import Counter
from PIL import Image

def hexdump(b, w=32):
    print("\n".join(b[i:i + w].hex() for i in range(0, len(b), w)))

def CH_calc_lengths(freqs):
    """Calculate lengths of codes for symbols in a Huffman tree.

freqs -- mapping from symbols to weights or (symbol, weight) iterable

Return a list of (symbol, bit_length) where:

- bit_length is a positive integer
- Kraft's inequality: Sum of 1/(1 << bit_length) for all lengths is 1
- Sum of bit_length * weight for each symbol is minimized
- Symbols appear in same order as input
"""
    try:
        freqsitems = list(freqs.items())
    except AttributeError:
        freqsitems = list(freqs)

    # Construct a parent-linked Huffman tree: O(n log n)
    symheap = [(fi[1], i) for i, fi in enumerate(freqsitems)]
    nodetoparent = list(range(len(freqsitems)))
    heapq.heapify(symheap)
    while len(symheap) > 1:
        lfreq, lsymbol = heapq.heappop(symheap)
        rfreq, rsymbol = heapq.heappop(symheap)
        newfreq = lfreq + rfreq
        newnode = len(nodetoparent)
        nodetoparent.append(newnode)
        nodetoparent[lsymbol] = nodetoparent[rsymbol] = newnode
        heapq.heappush(symheap, (newfreq, newnode))

    # Measure each symbol's length: O(n)
    symlengths = [0] * len(nodetoparent)
    for symbol in range(len(nodetoparent))[::-1]:
        parent = nodetoparent[symbol]
        lengthadd = 1 if symbol < parent else 0
        symlengths[symbol] = symlengths[parent] + lengthadd
    return [
        (symbol, length)
        for (symbol, _), length in zip(freqsitems, symlengths)
    ]

def CH_assign_bitstrings(codes_per_length):
    """Assign consecutive bit strings for each length."""
    bitstrings = []
    ending_code = 0
    for lminus1, ncodesofthislength in enumerate(codes_per_length):
        starting_code = ending_code << 1
        ending_code = starting_code + ncodesofthislength
        bitstrings.extend(range(starting_code, ending_code))
    return bitstrings

def CH_decode(codes_per_length, getbit):
    """Decode one code from a Canonical Huffman code stream.

codes_per_length -- sequence of numbers of codes that have
    1, 2, 3, ... bits
getbit -- a function that when called repeatedly returns values 0 and 1
"""
    accumulator = 0
    first_index = 0
    for ncodesofthislength in codes_per_length:
        accumulator = (accumulator << 1) | getbit()
        if accumulator < ncodesofthislength:
            return accumulator + first_index
        first_index += ncodesofthislength
        accumulator -= ncodesofthislength

def biterate_int(bitstring, length):
    """Iterate over the bits in an integer."""
    while length >= 0:
        length -= 1
        yield (bitstring >> length) & 1

def txttest(txt, codedisplimit=5):
    # Construct the code
    freqs = Counter(txt)
    lengths = CH_calc_lengths(freqs)
    lc = Counter(row[1] for row in lengths)
    codes_per_length = [lc.get(i + 1, 0) for i in range(max(lc))]
    bitstrings = CH_assign_bitstrings(codes_per_length)
    lengths.sort(key=lambda row: (row[1], row[0]))

    # Count total
    print("\n".join(
        "{0} x{1:3}: {3:0{2}b}".format(symbol, freqs[symbol], length, bitstring)
        for _, (symbol, length), bitstring
        in zip(range(codedisplimit), lengths, bitstrings)
    ))
    weightsum = sum((freqs[s] * length) for s, length in lengths)
    print("code counts %s; weightsum %d"
          % (codes_per_length, weightsum))

    decode_result = [
        CH_decode(codes_per_length,  biterate_int(bitstring, length).__next__)
        for (symbol, length), bitstring in zip(lengths, bitstrings)
    ]
    expected = list(range(len(lengths)))
    print("decode: pass" if decode_result == expected else "decode: fail")
    return weightsum

def rosetta_test():
    txttest("this is an example for huffman encoding")

def nibble_test(data):
    weightsum = txttest(data.hex())
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
    out = bytearray()
    for y in range(0, len(tile), 8):
        row = tile[y:y + 8]
        byte = 0
        for c in row:
            byte = (byte << 1) | (c & 1)
        out.append(byte)
    return bytes(out)

def fonttest():
    im = Image.open("../../common/tilesets/vwf7_cp144p.png")
    imbytes = bytes(1 if c == 1 else 0 for c in im.tobytes())
    tiles = [m7tileto1btile(x) for x in pixelstom7tiles(imbytes, im.size)]
    print("Proportional font data")
    return nibble_test(b"".join(tiles))

def main():
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
    print("Stopwtch digits")
    saved += nibble_test(data)

    with open("../obj/gb/stopwatchdigits.chrgb.pb16", "rb") as infp:
        data = infp.read()
    print("Stopwtch digits")
    saved += nibble_test(data)

    with open("../obj/gb/stopwatchhand.chrgb.pb16", "rb") as infp:
        data = infp.read()
    print("Stopwtch digits")
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

if __name__=='__main__':
    main()
