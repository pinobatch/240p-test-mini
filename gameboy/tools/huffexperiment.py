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
import heapq
from collections import Counter

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

def CH_main():
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

# Experimental tree-reconstruction ##################################

def invert_permutation(seq):
    """Return a list where invert_permutation(seq)[seq[x]] == x

>>> invert_permutation([0, 2, 3, 1, 4])
[0, 3, 1, 2, 4]

seq must be a permutation, such that set(seq) == set(range(len(seq)))
"""
    d = {v: k for k, v in enumerate(seq)}
    return [d[i] for i in range(len(d))]

def treemain():
    """Transform a CH code to Huffman tree form"""
    freqs = Counter(rosetta_test_text)
    syms, cpl = CH_build(freqs)
    maxdistance = 4
    terminalvalues = [row[0] for row in syms]
    node_lenbits = [row[1:3] for row in syms]
    lenbits_to_node = {v: k for k, v in node_lenbits}
    node_parent = []

    # Enumerate all nodes in the tree
    i = 0
    rootnode = None
    while i < len(node_lenbits):
        length, bitstring = node_lenbits[i]
        if length == 0:
            rootnode = i
            parent = None
        else:
            parentlb = (length - 1, bitstring >> 1)
            try:
                parent = lenbits_to_node[parentlb]
            except KeyError:
                lenbits_to_node[parentlb] = parent = len(node_lenbits)
                node_lenbits.append(parentlb)
        node_parent.append(parent)
        i += 1

    # Sort internal nodes by their lenbits value, producing a
    # level-order tree traversal
    levelorder = list(range(len(terminalvalues), len(node_lenbits)))
    levelorder.sort(key=lambda i: node_lenbits[i])
    print("Levelorder")
    prlist = [node_lenbits[i] for i in levelorder]
    print("\n".join(
        "{1:0{0}b}".format(l, b) if l else "root" for l, b in prlist
    ))

    # Theoretical maximum index into new tree equals the maximum
    # length in bits of an internal node times the maximum distance
    print("maximum internal code length:")
    maxintlength = max(row[0] for row in node_lenbits[len(terminalvalues):])
    maxindex = maxdistance * maxintlength)
    print("maxintlength is %d; maxindex is %d which should be no less than", maxintlength)

    # With distances of 1 to 4 nodes, I foresee congestion in the
    # level of the tree just above terminals.  To alleviate this,
    # build special-case encodings for two kinds of trees based on
    # how many codes of length 1 there are:
    # - Unary-like codes have rapidly increasing lengths:
    #   0, 10, 110, 1110, ...
    #   Encode the number of 1s before the first 0.
    # - Binary-like codes have flat lengths for the first few codes:
    #   000, 001, 010, 011, 100, 1010, ...
    #   Encode the number of 0s before the first nonzero, then
    #   spend more bits on the offset to each subtree's root.

    # Get children of each node (necessary?)
    node_child0 = [None] * len(node_parent)
    node_child1 = [None] * len(node_parent)
    for i, ((length, bitstring), parent) \
        in enumerate(zip(node_lenbits, node_parent)):
        if length < 1: continue
        target = node_child1 if (bitstring & 1) else node_child0
        target[parent] = i

if __name__=='__main__':
##    CH_main()
    treemain()
