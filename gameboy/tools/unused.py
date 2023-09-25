#!/usr/bin/env python3
"""
Long run detector for binary files
Copyright 2018, 2022 Damian Yerrick

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
import string, bisect, sys, os

def addrtosym(s, syms):
    try:
        return syms[s]
    except KeyError:
        return "$%04x" % s

def opcodetocond(opcode):
    """Extract a condition code from a JR, JP, RET, or CALL opcode"""
    condcode = (opcode & 0x18) >> 3
    return ['nz', 'z', 'nc', 'c'][condcode]

def disassemble_inst(opcode, operand, syms):
    if opcode == 0xEA:
        return "ld [%s], a" % addrtosym(operand, syms)
    if opcode == 0xFA:
        return "ld a, [%s]" % addrtosym(operand, syms)
    if opcode == 0xC3:
        return "jp %s" % addrtosym(operand, syms)
    if opcode in (0xC2, 0xCA, 0xD2, 0xDA):
        return "jp %s, %s" % (opcodetocond(opcode), addrtosym(operand, syms))
    if opcode == 0xCD:
        return "call %s" % addrtosym(operand, syms)
    if opcode == 0x01:
        return "ld bc, %s" % addrtosym(operand, syms)
    if opcode == 0x18:
        return "jr %s" % addrtosym(operand, syms)
    if opcode in (0x20, 0x28, 0x30, 0x38):
        return "jr %s, %s" % (opcodetocond(opcode), addrtosym(operand, syms))

def relative_ea(addr, offset):
    if offset >= 0x80: offset -= 0x100
    return (addr + offset) % 0x10000

def jr_target(addr, operand):
    return relative_ea(addr + 2, operand)

# Start and end of (non-code) data in the ROM that has proven
# prone to false alarms
datarange_starts = {
    'soundtest_handlers', 'helppage_000', 'grayramp_bottomhalfmap',
    'allhuffdata', 'helptiles', 'waveram_sinx', 'sgbborder',
}
datarange_ends = {
    'soundtest_8k', 'help_cumul_pages', 'grayramp_chr_gbc',
    'allhuffdata_end', 'helptiles_end', 'waveram_end', 'sgbborder.end',
}

def load_syms(filename):
    with open(filename, "r") as infp:
        lines = [s.split() for s in infp]
    syms = {}
    dataranges = []
    for line in lines:
        if len(line) < 2: continue
        k, v = line[:2]
        k = k.rsplit(':', 1)[-1]
        if not k or not v: continue
        if not all(c in string.hexdigits for c in k): continue
        k = int(k, 16)
        syms[k] = v

        # Compressed help text and other big data areas may contain
        # byte sequences that resemble optimizable opcodes
        if v in datarange_starts:
            dataranges.append((k, k))
        if v in datarange_ends:
            dataranges[-1] = (dataranges[-1][0], k)
    return syms, dataranges

romfolder = os.path.join(os.path.dirname(sys.argv[0]), "..")
with open(os.path.join(romfolder, "gb240p.gb"), "rb") as infp:
    data = infp.read()
syms, dataranges = load_syms(os.path.join(romfolder, "gb240p.sym"))

# Long runs of bytes with the same value ############################
# (the first and primary use of unused.py)

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

# Optimizable memory accesses #######################################

optimizable_hram_accesses = [
    (i, disassemble_inst(d, data[i + 1] + data[i + 2] * 0x100, syms))
    for i, d in enumerate(data[:-2])
    if d in (0xEA, 0xFA) and data[i + 2] == 0xFF
    and not any(l <= i <= h for l, h in dataranges)
]

for i, (addr, inst) in enumerate(optimizable_hram_accesses):
    # LD A, [aaaa] is $FA.  But a backward conditional branch by
    # 6 bytes is also $FA.  This can cause a false alarm with
    # JR NZ, .loop RET (FF-padding) which is 20 FA C9 FF.
    if (addr > 0 and (data[addr - 1] & 0xE7) == 0x20
        and data[addr + 1] == 0xC9):
        inst = inst + "  ; false alarm? (JR before RET)"
        optimizable_hram_accesses[i] = (addr, inst)

# Optimizable calls #################################################

rstable_calls = [
    (i, disassemble_inst(d, data[i + 1] + data[i + 2] * 0x100, syms))
    for i, d in enumerate(data[:-3])
    if d == 0xCD and data[i + 2] == 0 and (data[i + 1] & 0xC7) == 0
    and not any(l <= i <= h for l, h in dataranges)
]

tailcalls = [
    (i, disassemble_inst(d, data[i + 1] + data[i + 2] * 0x100, syms))
    for i, d in enumerate(data[:-4])
    if d == 0xCD and data[i + 3] == 0xC9
]

# Optimizable jumps #################################################

jp_opcodes = (0xC2, 0xC3, 0xCA, 0xD2, 0xDA)
jr_opcodes = (0x18, 0x20, 0x28, 0x30, 0x38)

jp_instructions = [
    (i, data[i + 1] + data[i + 2] * 0x100)
    for i, d in enumerate(data[:-3])
    if (d in jp_opcodes
        and not any(l <= i <= h for l, h in dataranges))
]
jp_instructions = [
    row for row in jp_instructions
    if not any(l <= row[1] <= h for l, h in dataranges)
]

jr_instructions = [
    (i, jr_target(i, data[i + 1]))
    for i, d in enumerate(data[:-3])
    if (d in jr_opcodes
        and not any(l <= i <= h for l, h in dataranges))
]

# This attempt to detect no-op JRs was all false alarms.  First off,
# an ASCII space followed by a NUL terminator is JR NZ, @+2.
# Even without those, it proved too prone to false alarms.
if False:
    jr_forward_0 = [
        (i, disassemble_inst(data[i], target, syms))
        for i, target in jr_instructions
        if target == i + 2
    ]
    print(jr_forward_0)

# The 6502 lacks conditional return.  It's easy for people going
# from 6502 to 8080 family to forget it exists.  Instead, they
# end up pointing a JR at a RET.
jp_to_ret = [
    (i, disassemble_inst(d, data[i + 1] + data[i + 2] * 0x100, syms))
    for i, d in enumerate(data[:-3])
    if (d in jp_opcodes
        and data[i + 2] < 0x80
        and data[data[i + 1] + data[i + 2] * 0x100] == 0xC9
        and not any(l <= i <= h for l, h in dataranges))
]

jr_to_ret = [
    (i, disassemble_inst(data[i], target, syms))
    for i, target in jr_instructions
    if target in syms and target < 0x8000 and data[target] == 0xC9
]

# Unconditional JR over a 1-byte instruction is $18 $01.  It can
# often be replaced with an instruction that ignores that byte being
# jumped over, such as CP imm or LD reg, imm.
def handle_jr_forward_1(addr, target, syms):
    suffix = ""
    # $CD xx $18 $01 xx xx is CALL $18xx followed by LD BC.
    # Comment this as a likely false alarm, or reject it entirely
    # if the CALL is to a known label and the JR is not.
    if addr >= 2 and addr <= 0x7FFC and data[addr - 2] == 0xCD:
        call_target = (data[addr] << 8) | (data[addr - 1])
        if call_target in syms and target not in syms: return None
        call_disasm = disassemble_inst(0xCD, call_target, syms)
        ld_bc_target = (data[addr + 3] << 8) | (data[addr + 2])
        ld_bc_disasm = disassemble_inst(data[addr + 1], ld_bc_target, syms)
        suffix = "  ; false alarm? (%s then %s)" % (call_disasm, ld_bc_disasm)
    return (addr, disassemble_inst(data[addr], target, syms) + suffix)

jr_forward_1 = [
    handle_jr_forward_1(i, target, syms)
    for i, target in jr_instructions
    if data[i] == 0x18 and target == i + 3
]
jr_forward_1 = [x for x in jr_forward_1 if x is not None]

jp_in_jr_range = [
    (i, disassemble_inst(data[i], target, syms))
    for i, target in jp_instructions
    if -126 <= target - i <= 129
]

sortedsyms = sorted(syms.items())
optimizable = []
optimizable.extend(optimizable_hram_accesses)
optimizable.extend(rstable_calls)
optimizable.extend(tailcalls)
optimizable.extend(jr_forward_1)
optimizable.extend(jp_to_ret)
optimizable.extend(jr_to_ret)
optimizable.extend(jp_in_jr_range)

if optimizable:
    optimizable.sort()
    optimizable = [
        (addr, inst,
         sortedsyms[max(0, bisect.bisect_left(sortedsyms, (addr, "")) - 1)])
        for addr, inst in optimizable
    ]
    print("These instructions can be optimized:")
    print("\n".join(
        "$%04x (%s+%d): %s"
        % (addr, label, addr - labeladdr, inst)
        for (addr, inst, (labeladdr, label)) in optimizable
    ))
