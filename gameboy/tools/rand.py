#!/usr/bin/env python3
s = 1
for i in range(10):
    s = (s * 0x01010101 + 0x31415927) & 0xFFFFFFFF
    print("%04x" % (s >> 16))

