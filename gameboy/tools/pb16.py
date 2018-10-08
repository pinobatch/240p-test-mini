#!/usr/bin/env python
"""
PB16 encoder
Copyright 2018 Damian Yerrick
[License: zlib]

PB16 can be thought of as either of two things:

- Run-length encoding (RLE) of two interleaved streams, with
  unary-coded run lengths
- LZSS with a fixed distance of 2 and a fixed copy length of 1

Each packet represents 8 bytes of uncompressed data.  The bits
of the first byte in a packet, ordered from MSB to LSB, encode
which of the following eight bytes repeat the byte 2 bytes back.
A 0 means a literal byte follows; a 1 means a repeat.

It's similar to the PB8 codec that I've used for NES CHR data,
adapted to the interleaving of Game Boy and Super NES CHR data.
"""
import itertools
import sys
import argparse

def ichunk(data, count):
    """Turn an iterable into lists of a fixed length."""
    data = iter(data)
    while True:
        b = list(itertools.islice(data, count))
        if len(b) == 0: break
        yield b

def pb16(data):
    """Compress an iterable of bytes into a generator of PB16 packets."""
    prev = [0, 0]
    for unco in ichunk(data, 8):
        # Pad the chunk to a multiple of 2 then to 8 bytes
        if len(unco) < 8:
            if len(unco) == 1:  # pad from 1 to 2
                unco.append(prev[1])
            elif len(unco) % 2:  # pad from 3 to 4, 5 to 6, or 7 to 8
                unco.append(unco[-2])
            unco.extend(unco[-2:]*(8 - len(unco)))

        packet = bytearray(1)
        for i, value in enumerate(unco):
            if value == prev[i % 2]:
                packet[0] |= 0x80 >> i
            else:
                packet.append(value)
                prev[i % 2] = value
        yield packet

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("infile")
    p.add_argument("outfile")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.infile, "rb") as infp:
        data = infp.read()
    with open(args.outfile, "wb") as outfp:
        outfp.writelines(pb16(data))

def test():
    tests = [
        ()
    ]
    s = b"ABAHBHCHCECEFEFE"
    print(b''.join(pb16(s)).hex())

if __name__=='__main__':
    main()
##    test()
