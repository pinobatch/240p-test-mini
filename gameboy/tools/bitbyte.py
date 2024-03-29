#!/usr/bin/env python3
"""
bit packing for compressors
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
CHAR_BIT = 8

class BitByteInterleave(object):
    """Interleave bytes with big-endian bits."""
    def __init__(self):
        self.out, self.bitsleft = bytearray(), 0

    def putbyte(self, c):
        """Add one full byte at the end."""
        self.out.append(c)

    def putbytes(self, c):
        """Add full bytes at the end."""
        self.out.extend(c)

    def putbits(self, value, length=1):
        """Insert bits into a partially full byte, then add bytes as needed."""
        while length > 0:
            # Make room for at least 1 more bit
            if self.bitsleft == 0:
                self.bitsindex, self.bitsleft = len(self.out), CHAR_BIT
                self.out.append(0)

            # How much of this value can we pack?
            value &= (1 << length) - 1
            length -= self.bitsleft
            if length >= 0:
                self.bitsleft = 0  # squeeze as many bits as we can
                self.out[self.bitsindex] |= value >> length
            else:
                self.bitsleft = -length  # space left for more bits
                self.out[self.bitsindex] |= value << -length

    def __len__(self):
        """Return len(bytes(self)), the length of contents in bytes."""
        return len(self.out)

    def __bytes__(self):
        """Return contents as a bytes object."""
        return bytes(self.out)

    def __iter__(self):
        """Return an iterator over the contents as bytes."""
        return iter(self.out)
