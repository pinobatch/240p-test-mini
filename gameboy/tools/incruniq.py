#!/usr/bin/env python3
"""
Compression experiment that sorts map entries by decreasing
frequency, in hopes that Huffman or something can be used on
tile indices with a dedicated code for repeats.

Currently we have these maps

size  tile  sngl  reus  name
 234   128   116    12  Gus portrait mono
 234                    Gus portrait color plane 0
 234                    Gus portrait color plane 1
 360    77   64     13  Linearity
 360   102   71     31  Sharpness
 576   103   34     69  Green Hill Zone
 156    81   74      7  Stopwatch face

If we can beat PB16, which compresses Green Hill Zone's tilemap
from 576 bytes to 398, it's already worthwhile.

The file format:
1 byte: number of PB8 compressed tiles (or 0 for 256)
PB16 compressed tiles
1 byte: length of singleton-eliminated map, divided by 16 and rounded up
1 byte: starting tile number of singletons
PB16 compressed singleton-eliminated map

"""
from collections import Counter
import sys
import argparse
from pb16 import pb16

def incruniq(it):
    seq = list(it)

    # Find members used only once
    freqs = Counter(seq)
    byfreq = freqs.most_common()
    singletons = set(el for el, freq in byfreq if freq < 2)
    freqs = byfreq = None

    # Find members used more than once in order of first appearance
    alltiles = []
    itiles = {el: 0xFF  for el in singletons}
    for el in seq:
        if el in itiles: continue
        itiles[el] = len(alltiles)
        alltiles.append(el)
    imultis = None

    # Put singletons in order of sole appearance
    firstsingleton = len(alltiles)
    alltiles.extend(el for el in seq if el in singletons)
    
    # Calculate the tilemap
    seq = bytes(itiles[el] for el in seq)
    return alltiles, firstsingleton, seq

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("srcfile")
    p.add_argument("iufile")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.srcfile, "rb") as infp:
        data = infp.read()
        print(len(data))
    block_size = 16
    data = [data[i:i + block_size] for i in range(0, len(data), block_size)]
    alltiles, firstsingleton, nam = incruniq(data)

    out = bytearray()
    out.append(len(alltiles))
    out.extend(b''.join(pb16(b''.join(alltiles))))
    nampb16size = -(-len(nam) // 16)
    out.append(nampb16size)
    out.append(firstsingleton)
    out.extend(b''.join(pb16(nam)))
    print(len(out))
    with open(args.iufile, "wb") as outfp:
        outfp.write(out)

if __name__=='__main__':
    main()
##    main(["incruniq.py", "../obj/gb/Gus_portrait.chrgb", "test.iu"])
