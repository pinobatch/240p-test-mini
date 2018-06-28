#!/usr/bin/env python
"""
The aim here is to beat the digram tree encoder (DTE) used in older
versions of 144p Test Suite, which compresses a 11576-byte text
to 7253 bytes.

The "Huffword" technique described in Witten et al. (1994) segments
each document into runs of alphanumeric and non-alphanumeric
characters, collects unique runs that appear more than once into a
dictionary, and transforms the text into references into this.

The text I'm using is the help file for 144p Test Suite:

    commit fe4476992ac53dfc13d86306adad1ab7f71a8410
    file gameboy/src/helppages.txt

Statistics from this text (not counting document titles):

    52 pages total 600 lines and 10976 bytes (11576 with line terminators)
    4 pages begin with nonwords
    0 lines begin with a single space
    3679 segs, 787 distinct (471 hapax legomena, 316 repeated)
    741 distinct words (454 hapax legomena, 287 repeated)
    46 distinct nonwords (17 hapax legomena, 29 repeated)
    dict entries total 4188 bytes, longest 13 bytes

Estimate I
----------
Encode the text as a sequence of 2-byte indexes into the
dictionary, then each dictionary entry as a 2-byte pointer into an
array of actual elements, plus 1 byte for each line terminator.
But that doesn't save anything: it produces 13720 bytes.

Estimate II
-----------
Notice that each line alternates between words and nonwords, and the
frequency distributions of the two vary greatly.  In particular, " "
(a single space) is by far the most common nonword, accounting for
more than half of all nonwords in the text. Thus we can reserve 1 bit
of each word index for whether the following nonword is space.
In addition, there are fewer than 256 distinct nonwords, allowing
encoding them with 1 byte instead of 2.  But we need to indicate
whether each line begins with a nonword, so make separate line
separator codes for word-initial and nonword-initial codes, and
if a document begins with a nonword, start it with a flag byte.

The dictionary in this estimate is unchanged from the previous.
Encode the text with 2 bytes for each word, 1 for each nonword,
-1 for each occurrence of " ", 1 for each line-initial occurrence
of " ", and 1 for each document beginning with a nonword.
This gives 10774 bytes: barely better than identity, and clearly
not better than DTE.

Estimate III
------------
Some words are far more common than others.  These can be given
shorter codes, with 2-byte codes reserved for less common words.
With 1 bit of each leading "word" byte reserved for "space follows",
we have 128 possible words, of which two are reserved for line and
document terminators.  Reserving three more for sets of 256 distinct
words gives 125 short word codes (used 1174 times) and 3 word
overflow pages, for a total of 9600 bytes.  Still doesn't beat DTE.
Perhaps this is because the dictionary alone is 5762 bytes, with
1574 bytes being word pointers.

Estimate IV
-----------
Can't beat 'em?  Join 'em.  Compressing the dictionary itself with
DTE produces 2832 bytes of dictionary text, saving 1356, leaving
8244 bytes.  This is still 991 bytes worse than just DTEing the
entire text, possibly due to lack of context across words.

Bibliography
------------
Ian H. Witten, Alistair Moffat, and Timothy C. Bell.
_Managing Gigabytes: Compressing and Indexing Documents and Images_.
New York: Van Nostrand Reinhold, 1994
"""
import re
from collections import Counter

import sys
import os
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), ".."
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs
from dte import dte_compress
import cp144p  # registers encoding "cp144p" used by GB and GBA suites

segRE = re.compile(rb"[0-9a-zA-Z]+|[^0-9a-zA-Z]+")
wordRE = re.compile(rb"[0-9a-zA-Z]+")

def stats(segs):
    segcounts = Counter()
    nlines = 0
    for page in segs:
        nlines += len(page)
        for line in page:
            segcounts.update(line)
    wordcounts = Counter({k: v for k, v in segcounts.items()
                         if wordRE.match(k)})
    nonwordcounts = Counter({k: v for k, v in segcounts.items()
                            if k not in wordcounts})
    nsegs = sum(segcounts.values())
    nwords = sum(wordcounts.values())
    nnonwords = sum(nonwordcounts.values())
    assert nwords + nnonwords == nsegs

    longest_seg = max(len(x) for x in segcounts)
    longest_word = max(len(x) for x in wordcounts)
    longest_nonword = max(len(x) for x in nonwordcounts)
    nhapaxes = sum(1 if count == 1 else 0 for count in segcounts.values())
    nwordhapaxes = sum(1 if count == 1 else 0
                       for count in wordcounts.values())
    nnonwordhapaxes = sum(1 if count == 1 else 0
                          for count in nonwordcounts.values())
    dictentrybytes = sum(len(x) for x in segcounts)
    nnonwordinitialpages = sum(1 if page[0][0] in nonwordcounts else 0
                               for page in segs)
    nspaceinitiallines = sum(1 if line and line[0] == b' ' else 0
                             for page in segs for line in page)

    print("%d pages begin with nonwords" % nnonwordinitialpages)
    print("%d lines begin with a single space" % nspaceinitiallines)
    print("%d segs, %d distinct (%d hapax legomena, %d repeated)"
          % (nsegs, len(segcounts),
             nhapaxes, len(segcounts) - nhapaxes))
    print("%d words, %d distinct (%d hapax legomena, %d repeated)"
          % (nwords, len(wordcounts),
             nwordhapaxes, len(wordcounts) - nwordhapaxes))
    print(wordcounts.most_common(10))
    print("%d nonwords, %d distinct (%d hapax legomena, %d repeated)"
          % (nnonwords, len(nonwordcounts),
             nnonwordhapaxes, len(nonwordcounts) - nnonwordhapaxes))
    print("dict entries total %d bytes, longest %d bytes"
          % (dictentrybytes, longest_seg))
    print(nonwordcounts.most_common(10))

    # 2 per dict entry, 1 per dict entry character, 1 per line, 2 per seg
    dictsize = len(segcounts) * 2 + dictentrybytes
    naive_estimate = dictsize + nlines + nsegs * 2
    print("Dictionary size (1-3): %d bytes" % dictsize)
    print("Estimate I: %d bytes" % naive_estimate)

    # 2 per dict entry, 1 per dict entry character, 1 per line,
    # 2 per word, 1 per nonspace nonword,
    # 1 per line-initial space, 1 per document-initial nonword
    estimate_2 = (
        dictsize + nlines
        + 2 * nwords + nnonwords - nonwordcounts[b" "]
        + nspaceinitiallines + nnonwordinitialpages
    )
    print("Estimate II: %d bytes" % estimate_2)

    wordoverflows = -(-(len(wordcounts) - 126) // 255)
    nshortwordcodes = 128 - wordoverflows
    shortwords = wordcounts.most_common(nshortwordcodes)
    shortworduses = sum(row[1] for row in shortwords)
    print("%d short word codes (used %d times) and %d word overflow pages"
          % (nshortwordcodes, shortworduses, wordoverflows))

    # 2 per dict entry, 1 per dict entry character, 1 per line,
    # 2 per word, -1 per short coded word, 1 per nonspace nonword,
    # 1 per line-initial space, 1 per document-initial nonword
    estimate_3 = (
        dictsize + nlines
        + 2 * nwords - shortworduses + nnonwords - nonwordcounts[b" "]
        + nspaceinitiallines + nnonwordinitialpages
    )
    print("Estimate III: %d bytes" % estimate_3)

    dtewords = [x[0] for x in segcounts.most_common()]
    dte_words, dte_decode, _ = dte_compress(dtewords, mincodeunit=132)
    dteentrybytes = sum(len(x) for x in dte_words) + 2 * len(dte_decode)
    print("DTE dictionary text size: %d bytes (%d saved)"
          % (dteentrybytes, dictentrybytes - dteentrybytes))
    dtedictsize = len(segcounts) * 2 + dteentrybytes
    estimate_4 = (
        dtedictsize + nlines
        + 2 * nwords - shortworduses + nnonwords - nonwordcounts[b" "]
        + nspaceinitiallines + nnonwordinitialpages
    )
    print("Estimate IV: %d bytes" % estimate_4)


def main():
    infilename = "../../../gameboy/src/helppages.txt"
    with open(infilename, "r", encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    docs = lines_to_docs(infilename, lines, maxpagelen=14)

    allpages = []
    bytesbefore = 0
    for doc in docs:
        for page in doc[-1]:
            page = [line.encode("cp144p") for line in page]
            bytesbefore += sum(len(line) for line in page) + len(page)
            allpages.append(page)
    nlines = sum(len(x) for x in allpages)
    bytesbefore = sum(len(x) for page in allpages for x in page)
    print("%d pages total %d lines and %d bytes (%d with line terminators)"
          % (len(allpages), nlines, bytesbefore, nlines + bytesbefore))

    segs = [[segRE.findall(line) for line in page] for page in allpages]
    stats(segs)

if __name__=='__main__':
    main()
