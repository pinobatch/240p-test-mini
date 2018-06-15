#!/usr/bin/env python3
import json, sys, re, os
from vwfbuild import rgbasm_bytearray

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from dte import dte_compress
import cp144p  # registers encoding "cp144p" used by GB and GBA suites

# Converting lines to documents #####################################

nonalnumRE = re.compile("[^0-9a-zA-Z]+")

def lines_to_docs(filename, lines, wrap=None, maxpagelen=16):
    """Convert a list of lines to a list of documents.

filename -- source of list of lines for use in error messages
lines -- a list of lines of the following form
    "== section title ==": start of document
    "----": page separator
    Other: text on page.  Leading, trailing, and consecutive
    blank lines will be removed.
wrap -- a function performing word wrap on long lines (optional)
maxpagelen -- raise an exception if text lines per page exceeds this
"""
    # docs[docnum] = (title, labelname, docpages)
    # docpages[pagenum][linenum] = line text
    docs, secttitles = [], {}
    for linenum, line in enumerate(lines):
        line = line.rstrip()
        if line.startswith('==') and line.endswith('=='):
            # New section
            secttitle = line.strip('=').strip()
            normtitle = nonalnumRE.sub('_', secttitle.lower()).strip('_')
            try:
                oldsection = secttitles[normtitle]
            except KeyError:
                pass
            else:
                oldsecttitle, oldlinenum = oldsection
                raise ValueError("%s:%d: %s was already defined on line %d"
                                 % (filename, linenum + 1,
                                    oldsecttitle, oldlinenum))
            secttitles[normtitle] = (secttitle, linenum)
            docs.append((secttitle, normtitle, [[]]))
            continue
        docpages = docs[-1][-1] if docs else None
        doclastpage = docpages[-1] if docpages else None
        
        line_rstrip = line.rstrip()
        if line_rstrip == '':
            # Blank line; append only if following a nonblank line
            if doclastpage and doclastpage[-1]:
                doclastpage.append('')
            continue
        if doclastpage is None:
            raise IndexError("%s:%d: nonblank line with no open document"
                             % (filename, linenum + 1))
        if line.startswith('----') and line.rstrip('-') == '':
            # Page break
            if doclastpage:
                docpages.append([])
            continue

        # Ordinary text
        doclastpage.extend(wrap(line_rstrip) if wrap else [line_rstrip])
        if len(doclastpage) > maxpagelen:
            raise IndexError("%s:%d: exceeds page length of %d lines"
                             % (filename, linenum + 1, maxpagelen))

    for doc in docs:
        pages = doc[-1]

        # Remove trailing blank lines
        for page in pages:
            while page and not page[-1]: del page[-1]

        # Remove blank pages
        for i in range(len(pages) - 1, -1, -1):
            if not pages[i]: del pages[i]

    # Remove blank docs entirely
    for i in range(len(docs) - 1, -1, -1):
        if not docs[i][-1]:
            del docs[i]

    return docs

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

def render_help(docs):
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
    lines.extend('helptitle_%s: db %s,0'
                 % (doc[1], rgbasm_escape_bytes(doc[0].encode("cp144p")))
                 for doc in docs)

    cumul_pages = [0]
    allpages = []
    for doc in docs:
        for page in doc[-1]:
            page = [line.encode("cp144p") for line in page]
            allpages.append(b"\x0A".join(page) + b"\x00")
        assert len(allpages) == cumul_pages[-1] + len(doc[-1])
        cumul_pages.append(len(allpages))

    # DTE compression
    dtepages = list(allpages)
    dtepages, replacements, pairfreqs = dte_compress(dtepages, mincodeunit=136)
    print("compressed help from %d bytes to %d bytes"
          % (sum(len(x) for x in allpages),
             2 * len(replacements) + sum(len(x) for x in dtepages)),
          file=sys.stderr)

    for pagenum, page in enumerate(dtepages):
        lines.append("helppage_%03d:" % pagenum)
        lines.append("  db %s" % rgbasm_escape_bytes(page))

    lines.append('help_cumul_pages::')
    lines.append(rgbasm_bytearray(cumul_pages))
    lines.append('HELP_NUM_PAGES equ %d' % cumul_pages[-1])
    lines.append('HELP_NUM_SECTS equ %d' % len(docs))
    lines.append('global HELP_NUM_PAGES, HELP_NUM_SECTS')
    
    lines.append('helppages::')
    lines.extend('  dw helppage_%03d' % i for i in range(cumul_pages[-1]))

    lines.append("dte_replacements::")
    lines.extend("  db %s" % rgbasm_escape_bytes(r) for r in replacements)

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
    docs = lines_to_docs(filename, lines, maxpagelen=14)
    print(render_help(docs))

if __name__=='__main__':
##    main(['paginate_help.py', '../src/helppages.txt'])
    main()
