#!/usr/bin/env python3
import sys, os, argparse, string
from vwfbuild import ca65_bytearray
from collections import Counter
from itertools import chain

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs
from dtefe import dte_compress
import cp240p  # registers encoding "cp240p" used by NES suite

# must match src/undte.s
DTE_MIN_CODEUNIT = 136
FIRST_PRINTABLE_CU = 32


# Reencoding given a replacements table #############################

# The compressed text that jroatch's encoder emits isn't optimal and
# can be improved, even with a greedy algorithm.

def dtedec(s, replacements):
    """Decode a byteslike using a DTE table."""
    stack = bytearray(reversed(s))
    out = bytearray()
    while stack:
        c = stack.pop()
        if c < DTE_MIN_CODEUNIT:
            out.append(c)
        else:
            stack.extend(reversed(replacements[c - DTE_MIN_CODEUNIT]))
    return bytes(out)

def dtemakeenctable(replacements):
    """Make a greedy encoding table for DTE"""
    encs = [(dtedec(r, replacements), bytes([i + DTE_MIN_CODEUNIT]))
            for i, r in enumerate(replacements)]
    # put longer replacement first (greedy algorithm)
    encs.sort(key=lambda x: len(x[0]), reverse=True)
    return encs

def dteenc(s, enctable):
    for needle, replacement in enctable:
        s = s.replace(needle, replacement)
    return s

def dtereenc(txt, oldenc, enctable, printoldbetter=False):
    """Encode to DTE then keep the shorter of corresponding lines.

Neither jroatch's algorithm nor my algorithm is optimal.
So I compare them line by line and take whatever's better.
"""
    newenc = dteenc(txt, enctable).split(b"\n")
    oldenc = oldenc.split(b"\n")
    if printoldbetter: txt = txt.split(b"\n")
    bestenc = []
    for u, o, n in zip(txt, oldenc, newenc):
        if len(o) < len(n):
            if printoldbetter:
                print(u.decode("cp240p"), file=sys.stderr)
                print("jr-dte:", o.hex(), file=sys.stderr)
                print("greedy:", n.hex(), file=sys.stderr)
            bestenc.append(o)
        else:
            bestenc.append(n)
    return b"\n".join(bestenc)

# Encoding for ca65 assembler #######################################

def ca65_escape_bytes(blo):
    """Encode an iterable of ints in 0-255, mostly ASCII, for ca65 .byte statement"""
    runs = []
    for c in blo:
        if 32 <= c <= 126 and c != 34:
            if runs and isinstance(runs[-1], bytearray):
                runs[-1].append(c)
            else:
                runs.append(bytearray([c]))
        else:
            runs.append(c)
    return ','.join('"%s"' % r.decode('ascii')
                    if isinstance(r, bytearray)
                    else '%d' % r
                    for r in runs)

def render_help(docs, defines=None, verbose=False, inputlog=None):
    lines = ["""
; Help data generated with paginate_help.py - do not edit
.export helptitles_hi, helptitles_lo
.export helppages_hi, helppages_lo, help_cumul_pages
.export dte_replacements
.exportzp HELP_NUM_PAGES, HELP_NUM_SECTS, HELP_BANK

.segment "HELPDATA"
HELP_BANK = <.bank(*)
"""]
    lines.extend('.exportzp helpsect_%s' % (doc[1])
                 for i, doc in enumerate(docs))
    lines.extend('helpsect_%s = %d' % (doc[1], i)
                 for i, doc in enumerate(docs))

    defines = dict(defines or {})
    allpages, cumul_pages = [], [0]
    for doc in docs:
        for page in doc[-1]:
            page = [string.Template(line).safe_substitute(defines)
                    for line in page]
            page = b"\x0A".join(line.encode("cp240p") for line in page)
            allpages.append(page + b"\x00")
        assert len(allpages) == cumul_pages[-1] + len(doc[-1])
        cumul_pages.append(len(allpages))

    # DTE compress titles and bodies
    helptitledata = [doc[0].encode("cp240p") for doc in docs]
    dtepages = list(allpages)
    dtepages.extend(helptitledata)
    oldsize = sum(len(x) for x in dtepages)
    result = dte_compress(dtepages, mincodeunit=DTE_MIN_CODEUNIT,
                          compctrl=FIRST_PRINTABLE_CU, inputlog=inputlog)
    dtepages, replacements, pairfreqs = result
    newsize = 2 * len(replacements) + sum(len(x) for x in dtepages)
    print("compressed help from %d bytes to %d bytes"
          % (oldsize, newsize), file=sys.stderr)

    # Try an alternate encoder with the same dictionary
    reenctable = dtemakeenctable(replacements)
    greedysaved = 0
    for i, txt in enumerate(chain(allpages, helptitledata)):
        newpage = dtereenc(txt, dtepages[i], reenctable,
                           printoldbetter=inputlog or verbose)
        assert dtedec(newpage, replacements) == txt
        svd = len(dtepages[i]) - len(newpage)
        bytes_pl = "bytes" if abs(svd) != 1 else "byte"
        if svd > 0:
            if inputlog:
                loglines = [
                    "For the text", "", txt.decode("cp144p"), "",
                    "jroatch dte gives", dtepages[i].hex(),
                    "while greedy recompression saves %d %s" % (svd, bytes_pl),
                    newpage.hex(), ""
                ]
                print("\n".join(loglines), file=sys.stderr)
            dtepages[i] = newpage
            greedysaved += svd

    newnewsize = 2 * len(replacements) + sum(len(x) for x in dtepages)
    assert newnewsize == newsize - greedysaved

    # Put most commonly repeated lines in/after title table
    uniquelines = Counter()
    linecount = 0
    for page in dtepages:
        page = page.rstrip(b'\x00').split(b"\n")
        uniquelines.update(x for x in page if x)
    repeatedlines = {k for k, v in uniquelines.items() if v > 1}

    # Document titles come last
    helptitledata = dtepages[len(allpages):]
    del dtepages[len(allpages):]

    # Append repeated lines that aren't titles as if they were
    repeatedlines.difference_update(helptitledata)
    helptitledata.extend(repeatedlines)
    lines.append('helptitles_hi:')
    lines.extend('  .byte >helptitle_%d' % i
                 for i in range(len(helptitledata)))
    lines.append('helptitles_lo:')
    lines.extend('  .byte <helptitle_%d' % i
                 for i in range(len(helptitledata)))

    # Match lines of text to document titles
    helptitleinv = {t: idx for idx, t in enumerate(helptitledata)}

    # Replace lines matching helplines with references
    for i, page in enumerate(dtepages):
        page = page.rstrip(b'\x00').split(b"\n")
        newpage = bytearray()
        for j, line in enumerate(page):
            helptitleid = helptitleinv.get(line)
            if helptitleid is not None:
                newpage.extend([0x0F, helptitleid])
            else:
                newpage.extend(line)
                if j != len(page) - 1:
                    newpage.append(0x0A)
        newpage.append(0)
        dtepages[i] = bytes(newpage)

    code_usage = Counter()
    for pagenum, page in enumerate(dtepages):
        lines.append("helppage_%03d:" % pagenum)
        lines.append("  .byte %s" % ca65_escape_bytes(page))
        code_usage.update(page)  # Make histogram

    lines.extend('helptitle_%d: .byte %s,0'
                 % (i, ca65_escape_bytes(txt))
                 for i, txt in enumerate(helptitledata))
    lines.append('help_cumul_pages:')
    lines.append(ca65_bytearray(cumul_pages))
    lines.append('HELP_NUM_PAGES = %d' % cumul_pages[-1])
    lines.append('HELP_NUM_SECTS = %d' % len(docs))
    lines.append('helppages_hi:')
    lines.extend('  .byte >helppage_%03d' % i for i in range(cumul_pages[-1]))
    lines.append('helppages_lo:')
    lines.extend('  .byte <helppage_%03d' % i for i in range(cumul_pages[-1]))
    lines.append("dte_replacements:")
    lines.extend("  .byte %s" % ca65_escape_bytes(r) for r in replacements)

    lines.append("; compressed help from %d bytes to %d bytes"
                 % (oldsize, newsize))
    if greedysaved > 0:
        lines.append("; the greedy reencoder saved %d more making %d bytes"
                     % (greedysaved, newnewsize))

    if verbose:
        for i, r in enumerate(replacements):
            out = dtedec(r, replacements).decode("cp144p")
            lines.append("; $%02X: %s (%d)"
                         % (i + DTE_MIN_CODEUNIT, repr(out),
                            code_usage.get(i + DTE_MIN_CODEUNIT, 0)))
        lines.append("; Repeated lines that aren't document titles")
        print(repeatedlines, file=sys.stderr)
        lines.extend(
            "; %s (%d)"
            % (dtedec(r, replacements).decode("cp144p"), uniquelines[r])
            for r in repeatedlines
        )

    lines.append("")

    return "\n".join(lines)

def parse_define(s):
    kv = s.split('=', 1)
    if len(kv) < 2:
        raise ValueError("expected KEY=value; got %s" % s)
    return tuple(kv)

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("input",
                   help="help file with pages introduced by ==title==")
    p.add_argument("-o", "--output", default="-",
                   help="assembly file to write (default: standard output)")
    p.add_argument("-D", metavar="WORD=value",
                   type=parse_define, dest="defines", nargs='*',
                   help="define a word for $WORD or ${WORD} substitution")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.input, 'r', encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    docs = lines_to_docs(args.input, lines, maxpagelen=20)
    out = render_help(docs, defines=args.defines)
    if args.output != '-':
        with open(args.output, "w", encoding="utf-8") as outfp:
            outfp.write(out)
    else:
        sys.stdout.write(out)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(['paginate_help.py', "-DCOMMIT=commit goes here", '../src/helppages.txt'])
    else:
        main()
