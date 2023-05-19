#!/usr/bin/env python3
"""
YUV table generator
2019 Damian Yerrick
no rights reserved
"""
from math import sin, cos, pi

for i in range(12):
    theta = i * pi / 6.0
    y = 127.5
    u = cos(theta) * 62.5
    v = sin(theta) * 62.5
##    print("yuv is", round(y), round(u), round(v))
    r = round(y + 1.13983*v)
    g = round(y - .39465*u - .58060*v)
    b = round(y + 2.03211*u)
    print("  drgb $%02x%02x%02x" % (r, g, b))
