#!/usr/bin/env python3
"""
Bit writer and reader

Assumes a big-endian bitstream
"""
from __future__ import with_statement

log2_memo = {0: -1, 1: 0, 2: 1, 3: 1, 4: 2}
def log2(i):
    """Calculate the base 2 logarithm of an integer, rounded down.

log2(0) == -1
log2(1) == 0
log2(2) == log2(3) == 1
log2(4) == log2(7) == 1
etc.
"""
    # Memoize
    try:
        return log2_memo[i]
    except KeyError:
        pass

    # Calculate
    ikey = i
    lg = 0
    while i >= 65536:
        lg = lg + 16
        i = i >> 16
    while i >= 256:
        lg = lg + 8
        i = i >> 8
    while i >= 16:
        lg = lg + 4
        i = i >> 4
    while i >= 4:
        lg = lg + 2
        i = i >> 2
    while i >= 2:
        lg = lg + 1
        i = i >> 1
    log2_memo[ikey] = lg
    return lg

class BitBuilder(object):

    def __init__(self):
        import array
        self.data = bytearray()
        self.nbits = 0  # number of bits left in the last byte

    def append(self, value, length=1):
        """Append a bit string."""
        assert(value < 1 << length)
        while length > 0:
            if self.nbits == 0:
                self.nbits = 8
                self.data.append(0)
            lToAdd = min(length, self.nbits)
            bitsToAdd = (value >> (length - lToAdd))
            length -= lToAdd
            self.nbits -= lToAdd
            bitsToAdd = (bitsToAdd << self.nbits) & 0xFF
            self.data[-1] = self.data[-1] | bitsToAdd

    def appendRemainder(self, value, divisor):
        """Append a number from 0 to divisor - 1.

This writes small numbers with floor(log2(divisor)) bits and large
numbers with ceil(log2(divisor)) bits.

"""
        nBits = log2(divisor)
        # 2 to the power of (1 + nBits)
        cutoff = (2 << nBits) - divisor
        if value >= cutoff:
            nBits += 1
            value += cutoff
        self.append(value, nBits)

    def appendGamma(self, value, divisor=1):
        """Add a nonnegative integer in the exp-Golomb code.

Universal codes are a class of prefix codes over the integers.
They are "universal" in that they encode all distributions of
integers with a finite expected code length.  They are optimal
for a power-law distribution, also called zeta, Zipf, or
discrete Pareto distribution.

The gamma code, invented by Peter Elias in 1975, is a universal
code that has become commonly used in data compression.
First write one fewer 0 bits than there are binary digits in
the number, then write the number.  For example:

1 -> 1
2 -> 010
3 -> 011
4 -> 00100
...
21 -> 000010101

This function modifies the gamma code slightly by encoding value + 1
so that zero has a code.

The exp-Golomb code is a generalization of Peter Elias' gamma code to
support flatter power law distributions.  The code for n with divisor
M is the gamma code for (n // M) + 1 followed by the remainder code
for n % M.  To write plain gamma codes, use M = 1.
"""
        if divisor > 1:
            remainder = value % divisor
            value = value // divisor
        value += 1
        length = log2(value)
        self.append(0, length)
        self.append(value, length + 1)
        if divisor > 1:
            self.appendRemainder(remainder, divisor)

    def appendGolomb(self, value, divisor=1):
        """Add a nonnegative integer in the Golomb code.

The Golomb code, invented by Solomon W. Golomb in the 1960s, is a
prefix code over the integers intended for a geometric distribution,
such as run-length encoding a Bernoulli random variable.  It has a
parameter M related to the variable's expected value.  The Golomb
code for n with divisor M is the unary code for n // M followed by
the remainder code for n % M.

For a Bernoulli process with probability p of zero and (1 - p) of one,
the optimal M to encode lengths of zero runs is M = -1/log2(1 - p).

Rice codes are Golomb codes where the divisor is a power of 2, and
the unary code is the Golomb code with a divisor of 1.

"""
        if divisor > 1:
            remainder = value % divisor
            value = value // divisor
        self.append(1, value + 1)
        if divisor > 1:
##            print(remainder, divisor)
            self.appendRemainder(remainder, divisor)

    def __bytes__(self):
        return bytes(self.data)

    def __len__(self):
        return len(self.data) * 8 - self.nbits

    @classmethod
    def test(cls):
        testcases = [
            (cls.append, 0, 0, b''),
            (cls.append, 123456789, 0, None),
            (cls.append, 1, 1, b'\x80'),
            (cls.append, 1, 2, b'\xA0'),
            (cls.append, 3, 4, b'\xA6'),
            (cls.append, 513, 10, b'\xA7\x00\x80'),  # with 7 bits left
            (cls.appendRemainder, 5, 10, b'\xA7\x00\xD0'),
            (cls.appendRemainder, 6, 10, b'\xA7\x00\xDC'),  # with 0 bits left
            
            (cls.appendGolomb, 14, 9, b'\xA7\x00\xDC\x68'),
        ]
        bits = BitBuilder()
        if bytes(bits) != b'':
            print("fail create")
        for (i, testcase) in zip(range(len(testcases)), testcases):
            (appendFunc, value, length, result) = testcase
            try:
                appendFunc(bits, value, length)
                should = bytes(bits)
            except AssertionError:
                should = None
            if should != result:
                print("BitBuilder.test: line", i, "failed.")
                print(''.join("%02x" % x for x in bits.data))
                return False
        print("BitBuilder tests work as expected")
        return True

# Length calculation for compression rate estimation

def remainderlen(value, divisor):
    """Calculate the length in bits of the remainder code for a number."""
    nBits = log2(divisor)
    cutoff = (2 << nBits) - divisor
    if value >= cutoff:
        nBits += 1
    return nBits

def gammalen(value, divisor=1):
    """Calculate the length in bits of the Exp-Golomb code for a number."""
    return 1 + 2*log2((value // divisor) + 1) + remainderlen(value % divisor, divisor)

def golomblen(value, divisor=1):
    """Calculate the length in bits of the Golomb code for a number."""
    return 1 + value // divisor + remainderlen(value % divisor, divisor)

class Biterator(object):
    """
Bitwise iterator over a byteslike or other iterable of ints 0-255.
"""
    def __init__(self, data):
        self.data = iter(data)
        self.bitsLeft = 0

    def __iter__(self):
        return self

    def read(self, count=1):
        accum = 0
        while count > 0:
            if self.bitsLeft == 0:
                self.bits = next(self.data)
                self.bitsLeft = 8
            bitsToAdd = min(self.bitsLeft, count)
            self.bits <<= bitsToAdd
            accum = (accum << bitsToAdd) | (self.bits >> 8)
            self.bits &= 0x00FF
            self.bitsLeft -= bitsToAdd
            count -= bitsToAdd
        return accum

    next = __next__ = read

    @classmethod
    def test(cls):
        src = Biterator([0xBA,0xDA,0x55,0x52,0xA9,0x0E])
        print("%x" % src.read(12), end=" ")
        print("%x motherf" % src.read(12))
        print("zero is", next(src))
        print("%x" % src.read(12))
        print("one thirty five is", src.read(10))
        print("zero is", next(src))
        try:
            next(src)
        except StopIteration:
            print("stopped.")
        else:
            print("didn't stop.")

if __name__=='__main__':
    BitBuilder.test()
    Biterator.test()
