#!/usr/bin/env python3
"""
Find routines called the most and the least
Copyright 2021 Damian Yerrick

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
"""
"""
If there are fallthrough calls (aka inline tail calls), the
"Called only once" list will contain false alarms.  I could fix
this with more effort by treating the previous instruction (if not
an unconditional jp, jr, or ret) as the subroutine's caller.

2021-03-10 (DY): Add least common calls; add jp; ignore comments;
ignore condition (z, nz, c, nc); rewrite from awk to Python because
I found adding these new features in Python quicker than learning awk

2023-09-25 (DY): Treat fallthrough (SAVE keyword) as jp for once list
"""
import sys, re, argparse
from collections import defaultdict

re_debugging = False

callRE = re.compile(r"""
    \s+(?:[.]?[a-zA-Z_][a-zA-Z0-9]*\s*:\s*)?  # Label
    (jp|call|fallthrough)\s+  # Jump or call
    (n?[zc]\s*,\s*)?  # Condition
    ([a-zA-Z_][a-zA-Z0-9_]*  # Label (excluding same-proc local labels)
      (?:[.][a-zA-Z_][a-zA-Z0-9_]*)?  # Label local part
    )
    
""", re.VERBOSE)

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("filenames", metavar="filename", nargs="*",
                   help="names of RGBASM source files")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)

    # {callee name: [(caller filename, line number, line text), ...], ...}
    callees_by_name = defaultdict(list)
    
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
            calls = callees_by_name[m.group(3)]
            calls.append((filename, i + 1, line.strip()))

    callees_by_name = sorted(callees_by_name.items(),
                             key=lambda x: len(x[1]), reverse=True)
    print("Top 10 callees")
    print("\n".join(
        "%5d %s" % (len(calls), callee_name)
        for callee_name, calls in callees_by_name[:10]
    ))
    print("Called only once")
    print("\n".join(
        "%s:%d: %s" % calls[0]
        for callee_name, calls in callees_by_name
        if (len(calls) < 2
            and not calls[0][2].startswith("fallthrough"))
    ))

if __name__=='__main__':
    want_default_file_set = len(sys.argv) < 2
    if want_default_file_set:
        import os
        from os.path import dirname, normpath, join as joinpath
        srcdir = normpath(joinpath(dirname(sys.argv[0]), "..", "src"))
        argv = [sys.argv[0]]
        argv.extend(joinpath(srcdir, f) for f in sorted(os.listdir(srcdir))
                    if f.endswith(".z80"))
        main(argv)
    else:
        main()

