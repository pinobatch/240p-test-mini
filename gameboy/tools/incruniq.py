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

"""
from collections import Counter

def frequniq(it):
    seq = list(it)
    freqs = Counter(seq)
    byfreq = freqs.most_common()
    singletons = set(el for el, freq in byfreq if freq < 2)
    print("%d entries, %d unique, %d singletons, %d reused"
          % (len(seq), len(freqs), len(singletons),
             len(freqs) - len(singletons)))

nams = [
    "../obj/gb/Gus_portrait.nam",
    "../obj/gb/linearity.nam",
    "../obj/gb/sharpness.nam",
    "../obj/gb/greenhillzone.nam",
    "../obj/gb/stopwatchface.nam",
]
for filename in nams:
    with open(filename, "rb") as infp:
        nam = infp.read()
    print(filename)
    frequniq(nam)
