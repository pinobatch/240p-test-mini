#!/usr/bin/env python3
"""
Continued fraction demo

Copyright 2021 Damian Yerrick
License: zlib

The fraction (2950000/2128137) ≈ 1.386188953 appears in the pixel
aspect ratio (PAR) of several digital picture generators that
generate a PAL-compatible signal.  A system containing this fraction
is far more difficult to reason about than the 8/7 of NTSC and tricky
to even approximate because of all the small numbers in its finite
continued fraction expansion.  There are 10 terms before the first
greater than 3.

[1; 2, 1, 1, 2, 3, 2, 1, 1, 1, 20, 1, 3, 1, 50]

1 + 821863/2128137
1 + 1/(2 + 484411/821863)
1 + 1/(2 + 1/(1 + 337452/484411))
1 + 1/(2 + 1/(1 + 1/(1 + 146959/337452)))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 43534 / 146959))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 16357/43534)))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 10820/16357))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 5537/10820)))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 1/(1 + 5283/5537))))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 1/(1 + 1/(1 + 254/5283)))))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 1/(1 + 1/(1 + 1/(20 + 203/254))))))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 1/(1 + 1/(1 + 1/(20 + 1/(1 + 51/203)))))))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 1/(1 + 1/(1 + 1/(20 + 1/(1 + 1/(3 + 50/51))))))))))))
1 + 1/(2 + 1/(1 + 1/(1 + 1/(2 + 1/(3 + 1/(2 + 1/(1 + 1/(1 + 1/(1 + 1/(20 + 1/(1 + 1/(3 + 1/(1 + 1/50)))))))))))))
"""

def eval_cf(terms):
    """Convert the terms of a finite continued fraction to a fraction.

A continued fraction is a number of the form
a[0] + 1/(a[1] + 1/(a[2] + 1/(a[3] + ...)))

Example:
The terms of the continued fraction for math.pi begin
[3;7,15,1,292,1,1,1,2,1,3,1,...]
You can get a reasonable-for-length approximation by cutting the
fraction before a high number: [3,7,15,1]
eval_cf([3,7,15,1]) = (355, 113) where 355/113 approximates math.pi

If the last term is 1, you may truncate it and add 1 to the remaining last term
eval_cf([3,7,16]) also equals (355, 113)

For an introduction to continued fractions, see this video:
"The Golden Ratio (why it is so irrational)" by Numberphile
<https://www.youtube.com/watch?v=sj8Sg8qnjOg>

With pixel aspect ratios, it's often helpful to pick a convergent
whose numerator or denominator divides 72 to make the DPI setting
for paint programs easier to remember.  Hence 18/13 for PAL H32,
pilbmp2nes.py
"""
    it = reversed(terms)
    num, den = next(it), 1
    for term in it:
        den, num = num, den
        num += den * term
    return num, den

def make_cf(num, den):
    """Convert a fraction to a continued fraction via Euclid's algorithm"""
    out = []
    while den != 0:
        term = num // den
        out.append(term)
        num, den = den, num - term * den
    return out

testcases = [
    ("PAL H32 pixel aspect ratio", 2950000, 2128137),
    ("PAL H40 pixel aspect ratio", 2360000, 2128137),
    ("Super Game Boy 2 clock divider", 14765625, 2883584),
    # Though the Nintendo DS has square pixels, its frame timing
    # relative to system M suggests this ratio.
    ("Nintendo DS SuperGun pixel aspect ratio", 6328125, 5767168),
]

def main():
    for name, num, den in testcases:
        print("%s: %s/%s" % (name, num, den))
        pal_cf = make_cf(num, den)
        print("As a continued fraction:", pal_cf)
        print("Convergents:")
        for i in range(len(pal_cf)):
            num_terms = i + 1
            n, d = eval_cf(pal_cf[:num_terms])
            print("%d. %d/%d = %.9f" % (num_terms, n, d, n/d))

if __name__=='__main__':
    main()
