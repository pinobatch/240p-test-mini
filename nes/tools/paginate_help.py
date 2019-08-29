#!/usr/bin/env python3
import json, sys, os
from vwfbuild import ca65_bytearray

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs
from dtefe import dte_compress
import cp240p

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

def render_help(docs):
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
    lines.append('helptitles_hi:')
    lines.extend('  .byte >helptitle_%s' % doc[1] for doc in docs)
    lines.append('helptitles_lo:')
    lines.extend('  .byte <helptitle_%s' % doc[1] for doc in docs)
    lines.extend('helptitle_%s: .byte %s,0'
                 % (doc[1], ca65_escape_bytes(doc[0].encode("cp240p")))
                 for doc in docs)

    allpages = []
    cumul_pages = [0]
    for doc in docs:
        for page in doc[-1]:
            page = [line.encode("cp240p") for line in page]
            allpages.append(b"\x0A".join(page) + b"\x00")
        assert len(allpages) == cumul_pages[-1] + len(doc[-1])
        cumul_pages.append(len(allpages))

    # DTE compression; currently not including titles
    dtepages = list(allpages)
    oldsize = sum(len(x) for x in dtepages)
    dtepages, replacements, pairfreqs = dte_compress(dtepages, mincodeunit=136)
    newsize = 2 * len(replacements) + sum(len(x) for x in dtepages)
    print("compressed help from %d bytes to %d bytes"
          % (oldsize, newsize), file=sys.stderr)

    for pagenum, page in enumerate(dtepages):
        lines.append("helppage_%03d:" % pagenum)
        lines.append("  .byte %s" % ca65_escape_bytes(page))

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

    return "\n".join(lines)

def main(argv=None):
    argv = argv or sys.argv
    if len(argv) > 1 and argv[1] == '--help':
        print("usage: paginate_help.py INFILE.txt")
        return
    if len(argv) != 2:
        print("paginate_help.py: wrong number of arguments; try paginate_help.py --help")
        sys.exit(1)

    filename = argv[1]
    with open(filename, 'r', encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    docs = lines_to_docs(filename, lines, maxpagelen=20)
    print(render_help(docs))

if __name__=='__main__':
##    main(['paginate_help.py', '../src/helppages.txt'])
    main()
