#!/usr/bin/env python3
"""
Python frontend for JRoatch's C language DTE compressor
license: zlib
"""
import sys, os, subprocess

def dte_compress(lines, compctrl=False, mincodeunit=128):
    dte_path = os.path.join(os.path.dirname(__file__), "dte")
    delimiter = b'\0'
    if len(lines) > 1:
        unusedvalues = set(range(1 if compctrl else 32))
        for line in lines:
            unusedvalues.difference_update(line)
        delimiter = min(unusedvalues)
        delimiter = bytes([delimiter])
    excluderange = "0x00-0x00" if compctrl else "0x00-0x1F"
    digramrange = "0x%02x-0xFF" % mincodeunit
    compress_cmd_line = [
        dte_path, "-c", "-e", excluderange, "-r", digramrange
    ]
    inputdata = delimiter.join(lines)
    spresult = subprocess.run(
        compress_cmd_line, check=True,
        input=inputdata, stdout=subprocess.PIPE
    )
    table_len = (256 - mincodeunit) * 2
    repls = [spresult.stdout[i:i + 2] for i in range(0, table_len, 2)]
    clines = spresult.stdout[table_len:].split(delimiter)
    return clines, repls, None

def main(argv=None):
    argv = argv or sys.argv
    with open(argv[1], "rb") as infp:
        lines = [x.rstrip(b"\r\n") for x in infp]
    clines, repls = dte_compress(lines)[:2]
    print(clines)
    print(repls)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(["dtefe.py", "../README.md"])
    else:
        main()

    
    
