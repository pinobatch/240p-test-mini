#!/usr/bin/env python3
"""
Tool to measure RAM use and ROM use by object file
Copyright 2017-2018 Damian Yerrick
[insert zlib license here]
"""
import sys
import os
from collections import defaultdict

def ld65_map_get_sections(filename):
    with open(filename, "r", encoding="utf-8") as infp:
        lines = [line.rstrip() for line in infp]
    sectbreaks = [
        i - 1 for i, line in enumerate(lines)
        if len(line) >= 4 and not line.rstrip('-')
    ]
    sections = [lines[i:j] for i, j in zip(sectbreaks, sectbreaks[1:])]
    sections.append(lines[sectbreaks[-1]:])
    return {
        s[0].rstrip(':').lower(): s[2:]
        for s in sections
    }

def ld65_parse_modules_list(modules_list):
    module = None
    for line in modules_list:
        if not line:
            continue
        leading_spc = len(line) - len(line.lstrip())
        if not leading_spc and line.endswith(':'):
            module = line.rstrip(':')
            continue

        line = line.split()
        segment = line.pop(0)
        nvp = [s.split("=", 1) for s in line]
        nvp = {k.lower(): int(v, base=16) for k, v in nvp}
        size = nvp['size']
        yield module, segment, size

def main(argv=None):
    argv = argv or sys.argv
    prog = os.path.basename(argv[0])
    if len(argv) < 2:
        print("%s: no map file; try %s --help"
              % (prog, prog), file=sys.stderr)
        sys.exit(1)
    if argv[1] in ['-h', '--help']:
        print("usage: %s map.txt" % prog)
        return
    filename = argv[1]

    sections_by_title = ld65_map_get_sections(filename)
    ml = sections_by_title['modules list']

    # sizes['RODATA']['vwf7.o']
    sizes_by_segment = defaultdict(dict)
    for module, segment, size in ld65_parse_modules_list(ml):
        sizes_by_segment[segment][module] = size
    for segment, module_sizes in sorted(sizes_by_segment.items()):
        segtotal = sum(module_sizes.values())
        print("%s: %d bytes" % (segment, segtotal))
        szs = sorted(module_sizes.items(), key=lambda x: -x[1])
        tszs = ["    %s: %d (%.1f%%)"
                % (module, sz, round(100 * sz / segtotal, 1))
                for module, sz in szs]
        print("\n".join(tszs))

if __name__=='__main__':
    in_IDLE = 'idlelib.__main__' in sys.modules or 'idlelib.run' in sys.modules
    if in_IDLE:
        main(['ld65ramuse.py', '../map.txt'])
    else:
        main()
