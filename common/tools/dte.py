#!/usr/bin/env python3
from __future__ import with_statement, division, print_function, unicode_literals
from collections import defaultdict
import sys, heapq

dte_problem_definition = """
Byte pair encoding, dual tile encoding, or digram coding is a static
dictionary compression method first disclosed to the public by Philip
Gage in 1994.  Each symbol in the compressed data represents a
sequence of two symbols, which may be compressed symbols or literals.
Its size performance is comparable to LZW but without needing RAM
for a dynamic dictionary.
http://www.drdobbs.com/a-new-algorithm-for-data-compression/184402829

The decompression is as follows:

for each symbol in the input:
    push the symbol on the stack
    while the stack is not empty:
        pop a symbol from the stack
        if the symbol is literal:
            emit the symbol
        else:
            push the second child
            push the first child

I'm not guaranteeing that it's optimal, but here's a greedy
compressor:

scan for frequencies of all symbol pairs
while a pair has high enough frequency:
    allocate a new symbol
    replace the old pair with the new symbol
    decrease count of replaced pairs
    increase count of newly created pairs

This is O(k*n) because of the replacements.

"""

lipsum = """"But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?
On the other hand, we denounce with righteous indignation and dislike men who are so beguiled and demoralized by the charms of pleasure of the moment, so blinded by desire, that they cannot foresee the pain and trouble that are bound to ensue; and equal blame belongs to those who fail in their duty through weakness of will, which is the same as saying through shrinking from toil and pain. These cases are perfectly simple and easy to distinguish. In a free hour, when our power of choice is untrammelled and when nothing prevents our being able to do what we like best, every pleasure is to be welcomed and every pain avoided. But in certain circumstances and owing to the claims of duty or the obligations of business it will frequently occur that pleasures have to be repudiated and annoyances accepted. The wise man therefore always holds in these matters to this principle of selection: he rejects pleasures to secure other greater pleasures, or else he endures pains to avoid worse pains.
--M. T. Cicero, "Extremes of Good and Evil", tr. H. Rackham"""

MINFREQ = 3

def olcount(haystack, needle):
    """Count times the 2-character needle appears in haystack, including overlaps."""
    if needle[0] != needle[1]:
        return haystack.count(needle)
    return len([c0 for c0, c1 in zip(haystack[:-1], haystack[1:])
                if c0 == c1 == needle[0]])

def dte_count_changes(s, pairfrom, pairto):
    """Count changes to pair frequencies after replacing a given string."""
    # Collect pair frequency updates
    # Assuming hi->$:
    # ghij -> gh -1, g$ +1, ij -1, $j + 1
    # ghihij -> gh -1, g$ -1, ih -1, $$ + 1, ij -1, $j +1
    assert isinstance(s, bytes)
    assert isinstance(pairfrom, bytes)
    assert isinstance(pairto, int)
    assert len(pairfrom) == 2
    
    newpairfreqs = defaultdict(lambda: 0)
    i, ilen = 0, len(s)
    lastsym = None
    revpairfrom = pairfrom[::-1]
    while i < ilen - 1:
        if s[i:i + 2] != pairfrom:
            lastsym = s[i]
            i += 1
            continue

        # Handle the pair before the replacement
        if i > 0:
            newpairfreqs[bytes([lastsym, pairto])] += 1
            newpairfreqs[bytes([lastsym, pairfrom[0]])] -= 1
        lastsym = pairto

        # Handle consecutive replaced pairs
        # First count nonoverlapping pairs of the replacement
        # ghij -> g$j
        # ghihij -> g$$j
        # ghihihij -> g$$$j
        nollen = 0
        while i < ilen:
            i += 2
            nollen += 1
            nextsym = s[i:i + 2]
            if nextsym != pairfrom:
                break
        # FIXME: This part needs to be replaced to handle
        # overlapping semantics
        if nollen >= 2:
            newpairfreqs[bytes([pairto, pairto])] += nollen - 1
            newpairfreqs[revpairfrom] -= nollen - 1

        if nextsym:
            newpairfreqs[bytes([pairto, nextsym[0]])] += 1
            newpairfreqs[bytes([pairfrom[1], nextsym[0]])] -= 1
    return newpairfreqs

def dte_newsymbol(lines, replacements, pairfreqs, compctrl=False, mincodeunit=128):
    """Find the biggest pair frequency and turn it into a new symbol."""

    # I don't know how to move elements around in the heap, so instead,
    # I'm recomputing the highest value every time.  When frequencies
    # are equal, prefer low numbered symbols for a less deep stack.
    if compctrl:
        useful_items = pairfreqs.items()
    else:
        useful_items = ((k, v)
                        for k, v in pairfreqs.items()
                        if all(c >= 32 for c in k))
    strpair, freq = min(useful_items, key=lambda x: (-x[1], x[0]))
    if freq < MINFREQ:
##        print("Done. freq is", freq)
        return True

    try:
        expected_freq = sum(olcount(line, strpair) for line in lines)
        assert freq == expected_freq
    except AssertionError:
        print("frequency of %s in pairfreqs: %d\nfrequency in inputdata: %d"
              % (repr(strpair), freq, expected_freq),
              file=sys.stderr)
        raise

    # Allocate new symbol
    newsym = mincodeunit + len(replacements)
    replacements.append(strpair)

    # Update pair frequencies
    for line in lines:
        for k, v in dte_count_changes(line, strpair, newsym).items():
            if v:
                pairfreqs[k] += v
    del pairfreqs[strpair]

    return False

def dte_compress(lines, compctrl=False, checkfreqs=True, mincodeunit=128):
    """Compress a set of byte strings with DTE.

lines -- a list of byte strings to compress, where no code unit
    is greater than mincodeunit
compctrl -- if False, exclude control characters ('\x00'-'\x1F')
from compression; if True, compress them as any other

"""
    # Initial frequency pair scan
    # pairfreqs[c] represents the number of times the two-character
    # sequence c occurs throughout lines
    pairfreqs = defaultdict(lambda: 0)
    for line in lines:
        for i in range(len(line) - 1):
            key = line[i:i + 2]
            pairfreqs[key] += 1
            # now we use overlapping matches: oooo is three of oo
            # and we leave the compctrl exclusion for dte_newsymbol

    replacements = []
    lastmaxpairs = 0
    done = False
    while len(replacements) < 256 - mincodeunit and not done:
        if checkfreqs:
            inputdata = b'\xff'.join(lines)
            numfailed = 0
            for strpair, freq in pairfreqs.items():
                expectfreq = olcount(inputdata, strpair)
                if expectfreq != freq:
                    print("Frequency pair scan problem: %s %d!=expected %d"
                          % (repr(strpair), freq, expectfreq),
                          file=sys.stderr)
                    numfailed += 1
            if numfailed > 0:
                if replacements:
                    print("Last replacement was %s with \\x%02x"
                          % (repr(replacements[-1]),
                          len(replacements) + mincodeunit - 1),
                          file=sys.stderr)
                assert False

        curinputlen = sum(len(line) + 1 for line in lines)
##        print("text:%5d bytes; dict:%4d bytes; pairs:%5d"
##              % (curinputlen, 2 * len(replacements), len(pairfreqs)),
##              file=sys.stderr)
        done = dte_newsymbol(lines, replacements, pairfreqs,
                             mincodeunit=mincodeunit)
        if done:
            break

        newsymbol = bytes([len(replacements) + mincodeunit - 1])
        for i in range(len(lines)):
            lines[i] = lines[i].replace(replacements[-1], newsymbol)
        if len(pairfreqs) >= lastmaxpairs * 2:
            for i in list(pairfreqs):
                if pairfreqs[i] <= 0:
                    del pairfreqs[i]
            lastmaxpairs = len(pairfreqs)

    return lines, replacements, pairfreqs

def dte_uncompress(line, replacements, mincodeunit=128):
    outbuf = bytearray()
    s = []
    maxstack = 0
    for c in line:
        s.append(c)
        while s:
            maxstack = max(len(s), maxstack)
            c = s.pop()
            if 0 <= c - mincodeunit < len(replacements):
                repl = replacements[c - mincodeunit]
                s.extend(reversed(repl))
##                print("%02x: %s" % (c, repr(repl)), file=sys.stderr)
##                print(repr(s), file=sys.stderr)
            else:
                outbuf.append(c)
    return bytes(outbuf), maxstack

def dte_tests():
    import cp144p
    inputdatas = [
        "The fat cat sat on the mat.",
        'boooooobies booooooobies',
        lipsum,
    ]
    with open("../src/helppages.txt", "r") as infp:
        inputdatas.append(infp.read())
    for text in inputdatas:
        lines = [text.encode("cp144p")]
        ctxt, replacements, pairfreqs = dte_compress(lines)
        print("compressed %d chaacters to %d bytes and %d replacements"
              % (len(text), len(ctxt[0]), len(replacements)))
        dtxt, stkd = dte_uncompress(ctxt[0], replacements)
        outtxt = dtxt.decode("cp144p")
        print("decompressed to %d characters with %d stack depth"
              % (len(dtxt), stkd))
        assert outtxt == text

# Compress for for robotfindskitten
def nki_main(argv=None):
    # Load input files
    argv = argv or sys.argv
    lines = []
    for filename in argv[1:]:
        with open(filename, 'rU') as infp:
            lines.extend(row.strip() for row in infp)

    # Remove blank lines and comments
    lines = [row.encode('ascii')
             for row in lines
             if row and not row.startswith('#')]

    # Diagnostic for line length (RFK RFC forbids lines longer than 72)
    lgst = heapq.nlargest(10, lines, len)
    if len(lgst[0]) > 72:
        print("Some NKIs are too long (more than 72 characters):", file=sys.stderr)
        print("\n".join(line for line in lgst if len(line) > 72), file=sys.stderr)
    else:
        print("Longest NKI is OK at %d characters. Don't let it get any longer."
              % len(lgst[0]), file=sys.stderr)
        print(lgst[0], file=sys.stderr)

    oldinputlen = sum(len(line) + 1 for line in lines)

    lines, replacements, pairfreqs = dte_compress(lines)

    print("%d replacements; highest remaining frequency is %d"
          % (len(replacements), max(pairfreqs.values())), file=sys.stderr)
    finallen = len(replacements) * 2 + sum(len(line) + 1 for line in lines)
    stkd = max(dte_uncompress(line, replacements)[1] for line in lines)
    print("from %d to %d bytes with peak stack depth: %d"
          % (oldinputlen, finallen, stkd), file=sys.stderr)

    replacements = b''.join(replacements)
    num_nkis = len(lines)
    lines = b''.join(line + b'\x00' for line in lines)
    from vwfbuild import ca65_bytearray
    outfp = sys.stdout
    outfp.write("""; Generated with dte.py; do not edit
.export NUM_NKIS, nki_descriptions, nki_replacements
NUM_NKIS = %d
.segment "NKIDATA"
nki_descriptions:
%s
nki_replacements:
%s
""" % (num_nkis, ca65_bytearray(lines), ca65_bytearray(replacements)))

if __name__=='__main__':
##    main()
##    main([sys.argv[0], "../../rfk/src/fixed.nki", "../../rfk/src/default.nki"])
    dte_tests()
