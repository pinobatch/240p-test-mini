#!/usr/bin/env python3
import json, sys, os
from vwfbuild import ca65_bytearray

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs
import cp144p

def render_help(docs):
    lines = ["""
@ Help data generated with paginate_help.py - do not edit
.global helptitles, helppages, help_cumul_pages
.global HELP_NUM_PAGES, HELP_NUM_SECTS

.section .rodata
"""]
    lines.extend('.global helpsect_%s' % (doc[1])
                 for i, doc in enumerate(docs))
    lines.extend('helpsect_%s = %d' % (doc[1], i)
                 for i, doc in enumerate(docs))
    lines.extend('helptitle_%s:\n%s\n  .byte 0'
                 % (doc[1], ca65_bytearray(doc[0].encode("cp144p")))
                 for doc in docs)

    cumul_pages = [0]
    pagenum = 0
    for doc in docs:
        for page in doc[-1]:
            lines.append("helppage_%03d:" % pagenum)
            page = [bytearray(line.encode("cp144p")) for line in page]
            for i in range(len(page) - 1):
                page[i].append(10)  # newline
            page[-1].append(0)
            lines.extend(ca65_bytearray(line) for line in page)
            pagenum += 1
        assert pagenum == cumul_pages[-1] + len(doc[-1])
        cumul_pages.append(pagenum)
    lines.append('help_cumul_pages:')
    lines.append(ca65_bytearray(cumul_pages))
    lines.append('HELP_NUM_PAGES = %d' % cumul_pages[-1])
    lines.append('HELP_NUM_SECTS = %d' % len(docs))
    lines.append('.balign 4')  # set alignment
    lines.append('helppages:')
    lines.extend('  .word helppage_%03d' % i for i in range(cumul_pages[-1]))
    lines.append('helptitles:')
    lines.extend('  .word helptitle_%s' % doc[1] for doc in docs)

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
    is_IDLE = 'idlelib.run' in sys.modules or 'idlelib.__main__' in sys.modules
    if is_IDLE:
        main(['paginate_help.py', '../src/helppages.txt'])
    else:
        main()
