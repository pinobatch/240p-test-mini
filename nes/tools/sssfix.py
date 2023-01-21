#!/usr/bin/env python3
"""
Prototype header fixer for FamicomBox
copyright 2023 Damian Yerrick
(insert zlib license here)

WARNING: completely untested
"""
import os, sys, argparse

# The FamicomBox (SSS-CDS) header is a 26-byte byteslike
# 0-15: ASCII title, left-padded with '\x00'
# 16-17: Big-endian sum of all PRG ROM bytes, mod 65536
# 18-19: Big-endian sum of all CHR ROM bytes, mod 65536
# 20: ROM size
#     Bits 6-4: PRG ROM size; 3: 1 for CHR RAM; 2-0 for CHR size
#     Sizes are 0: 8 or 64 KiB; 1: 16 KiB; 2: 32 KiB; 3: 128 KiB;
#     4: 256 KiB; 5: 512 KiB
# 21: Board type
#     Bit 7 is true for horizontal mirroring (inverse of iNES)
#     Bits 2-0 are a mapper type
#     0: NROM; 1: CNROM; 2: UNROM; 3: GNROM; 4: any ASIC mapper
# 22: 0 for no title; 1 for ASCII
# 23: 0 for no title; length of title minus 1 if title exists
# 24: Publisher (like GB; 1: Nintendo; 2-254: other licensees)
# 25: Checksum such that sum(header[18:26]) % 256 == 0
# 
# Fixers take a PRG ROM header with everything filled in but
# the PRG sum, place the header at the appropriate place, and
# return a byteslike with the header added

def fix_NROM(prgrom, header):
    assert len(header) == 26
    prgrom = bytearray(prgrom)
    if len(prgrom) not in (1<<13, 1<<14, 1<<15):
        raise ValueError("NROM/CNROM PRG ROM size must be 8K, 16K, or 32K, not %d"
                         % len(prgrom))
    prgrom[-32:-6] = header
    sumvalue = sum(prgrom)
    prgrom[-16] = (sumvalue >> 8) & 0xFF
    prgrom[-15] = (sumvalue >> 0) & 0xFF
    return prgrom

def multifix(prgrom, header, banksize=0x4000):
    out = []
    for i in range(0, len(prgrom), banksize):
        bank = bytearray(prgrom[i:i + banksize])
        bank[-32:-6] = header
        sumvalue = sum(bank)
        bank[-16] = (sumvalue >> 8) & 0xFF
        bank[-15] = (sumvalue >> 0) & 0xFF
        out.append(bank)
    return b"".join(out)

def fix_AOROM(prgrom, header):
    assert len(header) == 26
    return multifix(prgrom, header, 0x8000)

def fix_GNROM(prgrom, header):
    assert len(header) == 26
    prgrom = bytearray(prgrom)
    if len(prgrom) not in (1<<16, 1<<17):
        raise ValueError("GNROM PRG ROM size must be 64K or 128K, not %d"
                         % len(prgrom))
    return b''.join(fix_NROM(prgrom[i:i + 32768], header)
                    for i in range(0, len(prgrom), 32768))

def fix_UNROM(prgrom, header):
    assert len(header) == 26
    prgrom = bytearray(prgrom)
    if len(prgrom) not in (1<<16, 1<<17, 1<<18):
        raise ValueError("UNROM PRG ROM size must be 64K, 128K, or 256K, not %d"
                         % len(prgrom))
    if len(prgrom) != 1<<17:
        # instead of accounting for double-counting, treat unusually
        # sized UNROM as a generic MMC
        return fix_MMC_generic(prgrom, header)
    prgrom[-32:-6] = header
    sumvalue = sum(prgrom[:1<<17])
    prgrom[-16] = (sum >> 8) & 0xFF
    prgrom[-15] = (sum >> 0) & 0xFF
    return prgrom

def fix_MMC_generic(prgrom, header):
    prgrom = bytearray(prgrom)
    if len(prgrom) not in (1<<15, 1<<16, 1<<17, 1<<18, 1<<19):
        raise ValueError("ASIC mapper PRG ROM size must be 32K, 64K, 128K, 256K, or 512K, not %d"
                         % len(prgrom))
    prgrom[-16384:] = fix_NROM(prgrom[-16384:], header)
    return prgrom

def fix_MMC1(prgrom, header):
    assert len(header) == 26
    prgrom = bytearray(prgrom)
    if len(prgrom) == 1<<15: # SEROM
        return fix_MMC_generic(prgrom, header)
    if len(prgrom) not in (1<<16, 1<<17, 1<<18):
        raise ValueError("MMC1 PRG ROM size must be 32K, 64K, 128K, or 256K, not %d"
                         % len(prgrom))
    return multifix(prgrom, header, 0x4000)

def fix_MMC3(prgrom, header):
    bankC000 = prgrom[-0x4000:-0x2000]
    first_zero = bankC000.index(0)
    if first_zero % 2:
        raise ValueError("MMC3: first zero in second to last bank should be at an even address; found at $%04X"
                         % (first_zero + 0xC000))
    return fix_MMC_generic(prgrom, header)

ines_mapper_to_action = {
    0: ("NROM", 0, fix_NROM),
    3: ("CNROM", 1, fix_NROM),
    66: ("GNROM", 2, fix_GNROM),
    7: ("AOROM", 0, fix_AOROM),
    34: ("BNROM", 0, fix_AOROM),
    2: ("UNROM", 3, fix_UNROM),
    1: ("MMC1", 4, fix_MMC1),
    9: ("MMC2", 4, fix_MMC_generic),
    4: ("MMC3", 4, fix_MMC3),
    118: ("MMC3 TLSROM", 4, fix_MMC3),
    119: ("MMC3 TQROM", 4, fix_MMC3),
    10: ("MMC4", 4, fix_MMC_generic),
}

KiB_to_SSS_PRG_size = {
    64: 0x00, 16: 0x10, 32: 0x20, 128: 0x30, 256: 0x40, 512: 0x50
}
KiB_to_SSS_CHR_size = {
    8: 0x00, 16: 0x01, 32: 0x02, 64: 0x03, 128: 0x03, 256: 0x04, 512: 0x05
}

ROMSIZE_CHRRAM = 0x08
TITLEENC_NONE = 0x00
TITLEENC_ASCII = 0x01

def unpack_ines(inesdata):
    inesheader = inesdata[:16]
    prgromsize = inesheader[4] << 14
    chrromsize = inesheader[5] << 13
    prgromstart = 16  # SSS cartridge can't have a trainer
    chrromstart = 16 + prgromsize
    chrromend = chrromstart + chrromsize
    prgrom = inesdata[prgromstart:chrromstart]
    chrrom = inesdata[chrromstart:chrromend]
    return inesheader, prgrom, chrrom

def form_sss_header(title, inesheader, chrsum, publisher=0, verbose=False):
    prgsize_KiB, chrsize_KiB = inesheader[4] * 16, inesheader[5] * 8
    inesmapper = (inesheader[6] >> 4) | (inesheader[7] & 0xF0)
    sssmirroring = 0x00 if inesheader[6] & 1 else 0x80
    del inesheader

    header = bytearray(b' ') * 16 + bytearray(10)
    title = title.strip().upper() if title else ''
    if not all(' ' <= c <= '?' or 'A' <= c <= 'Z' for c in title):
        raise ValueError("title contains unsupported characters: %s" % repr(title))
    btitle = title.encode("ascii")
    if len(btitle) > 16:
        raise ValueError("title too long: %s" % repr(title))
    if len(btitle) == 1: btitle = btitle + " "
    header[16 - len(btitle):16] = btitle
    header[18] = (chrsum >> 8) & 0xFF
    header[19] = (chrsum >> 0) & 0xFF
    prgsize_SSS = KiB_to_SSS_PRG_size[prgsize_KiB]
    chrsize_SSS = (KiB_to_SSS_CHR_size[chrsize_KiB]
                   if chrsize_KiB
                   else ROMSIZE_CHRRAM)
    header[20] = prgsize_SSS | chrsize_SSS
    action = ines_mapper_to_action[inesmapper]
    header[21] = action[1] | sssmirroring
    header[22] = TITLEENC_ASCII if btitle else TITLEENC_NONE
    header[23] = len(btitle) - 1 if btitle else 0
    header[24] = publisher
    header[25] = -sum(header[18:25]) & 0xFF
    if verbose:
        print("Board type: %s (#%d)" % (action[0], inesmapper))
        print("Fixer type: %s" % action[2].__name__)
    return bytes(header), action

def parse_int(s):
    if s.startswith("$"): return int(s[1:], 16)
    if s.startswith("0x"): return int(s[2:], 16)
    return int(s, 10)

def parse_argv(argv):
    p = argparse.ArgumentParser(description="Adds a FamicomBox header to a ROM.")
    p.add_argument("input",
                   help="name of an iNES ROM")
    p.add_argument("-o", "--output",
                   help="name of output ROM (default: overwrite input)")
    p.add_argument("-t", "--title",
                   help="set the title (2-16 characters; U+0020 through U+003F and U+0041 through U+005A are supported)")
    p.add_argument("-l", "--old-licensee", metavar="licensee_id",
                   type=parse_int, default=0,
                   help="set the publisher code ($01: Nintendo; $02-$FE: third party)")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="show work")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    with open(args.input, "rb") as infp:
        inesheader, prgrom, chrrom = unpack_ines(infp.read(16 + (1<<20)))
    header, action = form_sss_header(
        args.title, inesheader, sum(chrrom), args.old_licensee,
        verbose=args.verbose
    )
    fixer = action[2]
    new_prgrom = fixer(prgrom, header)
    with open(args.output or args.input, "wb") as outfp:
        outfp.write(inesheader)
        outfp.write(new_prgrom)
        outfp.write(chrrom)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("./sssfix.py --help".split())
    else:
        main()
