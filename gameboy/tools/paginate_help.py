#!/usr/bin/env python3
import sys, os, argparse
from vwfbuild import rgbasm_bytearray

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs
from dtefe import dte_compress
import cp144p  # registers encoding "cp144p" used by GB and GBA suites

# must match src/undte.z80
DTE_MIN_CODEUNIT = 128
FIRST_PRINTABLE_CU = 24

# Converting lines to documents #####################################

# Encoding for RGBDS assembler ######################################

def rgbasm_escape_bytes(blo):
    """Encode an iterable of ints in 0-255, mostly ASCII, for rgbasm db statement"""
    runs = []
    for c in blo:
        if 32 <= c <= 126 and c != 34:
            if runs and isinstance(runs[-1], bytearray):
                runs[-1].append(c)
            else:
                runs.append(bytearray([c]))
        else:
            runs.append(c)
    runs = ['"%s"' % r.decode('ascii')
            if isinstance(r, bytearray)
            else '%d' % r
            for r in runs]
    return ','.join(runs)

def render_help(docs, verbose=False):
    lines = ["""
; Help data generated with paginate_help.py - do not edit

section "helppages",ROMX
"""]
    lines.extend('helpsect_%s equ %d' % (doc[1], i)
                 for i, doc in enumerate(docs))
    lines.extend('global helpsect_%s' % (doc[1])
                 for i, doc in enumerate(docs))
    lines.append('helptitles::')
    lines.extend('  dw helptitle_%s' % doc[1] for doc in docs)

    cumul_pages = [0]
    allpages = []
    for doc in docs:
        for page in doc[-1]:
            page = [line.encode("cp144p") for line in page]
            allpages.append(b"\x0A".join(page) + b"\x00")
        assert len(allpages) == cumul_pages[-1] + len(doc[-1])
        cumul_pages.append(len(allpages))

    # DTE compression
    helptitledata = [doc[0].encode("cp144p") for doc in docs]
    dtepages = list(allpages)
    dtepages.extend(helptitledata)
    oldsize = sum(len(x) for x in dtepages)
    result = dte_compress(dtepages, mincodeunit=DTE_MIN_CODEUNIT, compctrl=FIRST_PRINTABLE_CU)
    dtepages, replacements, pairfreqs = result
    newsize = 2 * len(replacements) + sum(len(x) for x in dtepages)
    helptitledata = dtepages[len(allpages):]
    del dtepages[len(allpages):]

    for pagenum, page in enumerate(dtepages):
        lines.append("helppage_%03d:" % pagenum)
        lines.append("  db %s" % rgbasm_escape_bytes(page))
    lines.extend('helptitle_%s: db %s,0'
                 % (doc[1], rgbasm_escape_bytes(dtetitle))
                 for doc, dtetitle in zip(docs, helptitledata))

    lines.append('help_cumul_pages::')
    lines.append(rgbasm_bytearray(cumul_pages))
    lines.append('HELP_NUM_PAGES equ %d' % cumul_pages[-1])
    lines.append('HELP_NUM_SECTS equ %d' % len(docs))
    lines.append('global HELP_NUM_PAGES, HELP_NUM_SECTS')
    
    lines.append('helppages::')
    lines.extend('  dw helppage_%03d' % i for i in range(cumul_pages[-1]))

    lines.append("dte_replacements::")
    lines.extend("  db %s" % rgbasm_escape_bytes(r) for r in replacements)

    lines.append("; compressed help from %d bytes to %d bytes"
                 % (oldsize, newsize))
    if verbose:
        for i, r in enumerate(replacements):
            stack = bytearray(reversed(r))
            out = bytearray()
            while stack:
                c = stack.pop()
                if c < DTE_MIN_CODEUNIT:
                    out.append(c)
                else:
                    stack.extend(reversed(replacements[c - DTE_MIN_CODEUNIT]))
            out = out.decode("cp144p")
            lines.append("; $%02X: %s" % (i + DTE_MIN_CODEUNIT, repr(out)))

    lines.append("")
    return "\n".join(lines)

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("INFILE")
    p.add_argument("-o", "--output", metavar="OUTFILE", default='-',
                   help="write asm output here instead of standard output")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="write replacements")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)

    with open(args.INFILE, 'r', encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    docs = lines_to_docs(args.INFILE, lines, maxpagelen=14)
    help_asm = render_help(docs, verbose=args.verbose)
    if args.output != '-':
        with open(args.output, "w") as outfp:
            outfp.write(help_asm)
    else:
        sys.stdout.write(help_asm)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(['paginate_help.py', '../src/helppages.txt'])
    else:
        main()
