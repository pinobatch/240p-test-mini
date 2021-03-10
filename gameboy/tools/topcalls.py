#!/usr/bin/env python3
"""
Find routines called the most and the least
Copyright 2021 Damian Yerrick
<insert zlib license here>

If there are fallthrough calls (aka inline tail calls), the
"Called only once" list will contain false alarms.  I could fix
this with more effort by treating the previous instruction (if not
an unconditional jp, jr, or ret) as the subroutine's caller.

2021-03-10 (DY): Add least common calls; add jp; ignore comments;
ignore condition (z, nz, c, nc); rewrite from awk to Python because
I found adding these new features in Python quicker than learning awk
"""
import os, sys, re, argparse
from collections import defaultdict

re_debugging = False

callRE = re.compile(r"""
    \s+(?:[.]?[a-zA-Z_][a-zA-Z0-9]*\s*:\s*)?  # Label
    (jp|call)\s+  # Jump or call
    (n?[zc]\s*,\s*)?  # Condition
    ([a-zA-Z_][a-zA-Z0-9_]*  # Label (excluding same-proc local labels)
      (?:[.][a-zA-Z_][a-zA-Z0-9_]*)?  # Label local part
    )
    
""", re.VERBOSE)

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("filenames", metavar="filename", nargs="*")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)

    # found is a dict from callee names to caller lists.
    # {callee name: [(caller filename, line number, line), ...], ...}
    found = defaultdict(list)
    
    for filename in args.filenames:
        with open(filename, "r", encoding="utf-8") as infp:
            lines = [(line, callRE.match(line)) for line in infp]

        if re_debugging:
            for line, m in lines:
                line0 = line.split(";", 1)[0].strip()
                if (("call" in line0 or "jp " in line0) and not m
                    and "call ." not in line0 and "jp ." not in line0):
                    print("call in", line, "but not matched")
                if ("call" not in line0 and "jp " not in line0) and m:
                    print("call not in", line, "but in", m.groups())

        for i, (line, m) in enumerate(lines):
            if not m: continue
            callee_name = m.group(3)
            found[callee_name].append((filename, i + 1, line.strip()))

    found = sorted(found.items(), key=lambda x: len(x[1]), reverse=True)
    print("Top 10 callees")
    print("\n".join(
        "%5d %s" % (len(calls), callee_name)
        for callee_name, calls in found[:10]
    ))
    print("Called only once")
    print("\n".join(
        "%s:%d: %s" % calls[0]
        for callee_name, calls in found
        if len(calls) < 2
    ))

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        import glob
        main(list(sys.argv) + list(glob.glob("../src/*.z80")))
    else:
        main()

