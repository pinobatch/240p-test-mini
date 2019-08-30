#!/usr/bin/env python3
"""
Long run detector for binary files
Copyright 2018 Damian Yerrick
insert zlib license here
"""
import string

def disassemble_hram_access(opcode, operand, syms):
    def addrtosym(s):
        try:
            return syms[s]
        except KeyError:
            return "$%04x" % s
    if opcode == 0xEA:
        return "ld [%s], a" % addrtosym(operand)
    if opcode == 0xFA:
        return "ld a, [%s]" % addrtosym(operand)

def load_syms(filename):
    with open(filename, "r") as infp:
        lines = [s.split() for s in infp]
    syms = {}
    falsepos_ranges = []
    for line in lines:
        if len(line) < 2: continue
        k, v = line[:2]
        k = k.rsplit(':', 1)[-1]
        if not k or not v: continue
        if not all(c in string.hexdigits for c in k): continue
        k = int(k, 16)
        syms[k] = v

        # Compressed help text contains byte sequences that
        # resemble optimizable opcodes
        if v == 'helppage_000':
            falsepos_ranges.append((k, k))
        if v == 'help_cumul_pages':
            falsepos_ranges[-1] = (falsepos_ranges[-1][0], k)
    return syms, falsepos_ranges

with open("gb240p.gb", "rb") as infp:
    data = infp.read()
syms, falsepos_ranges = load_syms("gb240p.sym")

runthreshold = 32
runbyte, runlength, runs = 0xC9, 0, []
for addr, value in enumerate(data):
    if value != runbyte:
        if runlength >= runthreshold:
            runs.append((addr - runlength, addr))
        runbyte, runlength = value, 0
    runlength += 1
if runlength >= runthreshold:
    runs.append((len(data) - runlength, len(data)))

totalsz = 0
for startaddr, endaddr in runs:
    sz = endaddr - startaddr
    totalsz += sz
    print("%04x-%04x: %d" % (startaddr, endaddr - 1, sz))
print("total: %d bytes (%.1f KiB)" % (totalsz, totalsz / 1024.0))

optimizable_hram_accesses = [
    (i, disassemble_hram_access(d, data[i + 1] + data[i + 2] * 0x100, syms))
    for i, d in enumerate(data[:-2])
    if d in (0xEA, 0xFA) and data[i + 2] == 0xFF
    and not any(l <= i <= h for l, h in falsepos_ranges)
]

for i, (addr, inst) in enumerate(optimizable_hram_accesses):
    # LD A, [aaaa] is $FA.  But a backward conditional branch by
    # 6 bytes is also $FA.  This can cause a false positive with
    # JR NZ, .loop RET (FF-padding) which is 20 FA C9 FF.
    if (addr > 0 and (data[addr - 1] & 0xE7) == 0x20
        and data[addr + 1] == 0xC9):
        inst = inst + "  ; false positive? (JR before RET)"
        optimizable_hram_accesses[i] = (addr, inst)

if optimizable_hram_accesses:
    print("These HRAM accesses can be optimized:")
    print("\n".join(
        "$%04x: %s" % row for row in optimizable_hram_accesses
    ))
