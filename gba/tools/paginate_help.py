#!/usr/bin/env python3
import sys, os, argparse, string
from vwfbuild import ca65_bytearray

# Find common tools
commontoolspath = os.path.normpath(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "..", "common", "tools"
))
sys.path.append(commontoolspath)
from parsepages import lines_to_docs
import cp144p

def render_help(docs, defines=None):
    lines = ["""
@ Help data generated with paginate_help.py - do not edit
.global helptitles, helppages, help_cumul_pages
.global HELP_NUM_PAGES, HELP_NUM_SECTS

.section .rodata
"""]
    lines_header = ["""// File generated with paginate_help.py
#ifndef HELPPAGES_H__
#define HELPPAGES_H__
enum helpdoc_kind_e {"""]
    lines.extend('.global helpsect_%s' % (doc[1])
                 for i, doc in enumerate(docs))
    lines.extend('helpsect_%s = %d' % (doc[1], i)
                 for i, doc in enumerate(docs))
    lines_header.extend('    helpsect_%s = %d,' % (doc[1], i)
                 for i, doc in enumerate(docs))
    lines.extend('helptitle_%s:\n%s\n  .byte 0'
                 % (doc[1], ca65_bytearray(doc[0].encode("cp144p")))
                 for doc in docs)
    defines = dict(defines or {})

    cumul_pages = [0]
    pagenum = 0
    for doc in docs:
        for page in doc[-1]:
            lines.append("helppage_%03d:" % pagenum)
            page = [string.Template(line).safe_substitute(defines)
                    for line in page]
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
    lines_header.append("};")
    lines_header.append("typedef enum helpdoc_kind_e helpdoc_kind;")
    lines.append('HELP_NUM_PAGES = %d' % cumul_pages[-1])
    lines.append('HELP_NUM_SECTS = %d' % len(docs))
    lines_header.append('#define HELP_NUM_PAGES %d' % cumul_pages[-1])
    lines_header.append('#define HELP_NUM_SECTS %d' % len(docs))
    lines_header.append('extern const char *const helppages[HELP_NUM_PAGES];')
    lines_header.append('extern const char *const helptitles[HELP_NUM_SECTS];')
    lines_header.append('extern const unsigned char help_cumul_pages[HELP_NUM_SECTS];')
    lines_header.append('#endif')
    lines.append('.balign 4')  # set alignment
    lines.append('helppages:')
    lines.extend('  .word helppage_%03d' % i for i in range(cumul_pages[-1]))
    lines.append('helptitles:')
    lines.extend('  .word helptitle_%s' % doc[1] for doc in docs)

    # ensure files end with newline
    lines.extend("")
    lines_header.extend("")
    return ["\n".join(lines), "\n".join(lines_header)]

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
    p.add_argument("-oh", "--output_header", default="-",
                   help="header file to write")
    p.add_argument("-m", "--maxpagelen", default="15", type=int,
                   help="maximum length of a page in lines")
    p.add_argument("-D", metavar="WORD=value",
                   type=parse_define, dest="defines", nargs='*',
                   help="define a word for $WORD or ${WORD} substitution")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.input, 'r', encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    docs = lines_to_docs(args.input, lines, maxpagelen=int(args.maxpagelen))
    out = render_help(docs, defines=args.defines)
    if args.output != '-':
        with open(args.output, "w", encoding="utf-8") as outfp:
            outfp.write(out[0])
    else:
        sys.stdout.write(out[0])
    if args.output_header != '-':
        with open(args.output_header, "w", encoding="utf-8") as outfp:
            outfp.write(out[1])
if __name__=='__main__':
    is_IDLE = 'idlelib.run' in sys.modules or 'idlelib.__main__' in sys.modules
    if is_IDLE:
        main(['paginate_help.py', "-DCOMMIT=commit goes here" '../src/helppages.txt'])
    else:
        main()
