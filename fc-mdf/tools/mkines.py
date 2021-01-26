#!/usr/bin/env python3
import sys
import argparse

# map from names to (iNES mapper, use CHR ROM) pairs
mapperdefs = {
    "mmc5": (5, True),
    "vrc6": (24, True),
    "vrc6ed2": (26, True),
    "vrc7": (85, False),
    "n163": (19, True),
    "fme7": (69, True),
}


def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("input", help="32768 byte program file")
    p.add_argument("mapper", type=lambda x: mapperdefs[x.lower()])
    p.add_argument("output", help="write iNES format ROM")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    mapper, use_chr_rom = args.mapper
    header = bytearray(b"NES\x1A" + bytes(12))
    header[4] = 2  # 2*16384 bytes
    header[5] = 4 if use_chr_rom else 0
    header[6] = (mapper << 4) & 0xF0
    header[7] = mapper & 0xF0
    with open(args.input, "rb") as infp:
        prg_rom = infp.read(32768)
    out = [header, prg_rom]
    if use_chr_rom: out.append(prg_rom)
    with open(args.output, "wb") as outfp:
        outfp.writelines(out)

if __name__=='__main__':
    if "idlelib" in sys.modules:
        main(["./mkines.py", "../mdfourier.prg", "mmc5", "../mdfourier-mmc5.nes"])
    else:
        main()
