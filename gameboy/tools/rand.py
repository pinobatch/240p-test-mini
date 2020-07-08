#!/usr/bin/env python3
s = 1
for i in range(10):
    s = ((s + 0xB3) * 0x01010101) & 0xFFFFFFFF
    print("%04x" % (s >> 16))

