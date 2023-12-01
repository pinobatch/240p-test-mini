#!/usr/bin/env python3
#
# Lookup table generator for note periods
# Copyright 2010, 2020 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
assert str is not bytes
import sys

lowestFreq = 55.0
ntscOctaveBase = 39375000.0/(22 * 16 * lowestFreq)
palOctaveBase = 266017125.0/(10 * 16 * 16 * lowestFreq)
maxNote = 87

def makePeriodTable(filename, pal=False):
    semitone = 2.0**(1./12)
    octaveBase = palOctaveBase if pal else ntscOctaveBase
    relFreqs = [(1 << (i // 12)) * semitone**(i % 12)
                for i in range(maxNote)]
    periods = [int(round(octaveBase / freq)) - 1 for freq in relFreqs]
    systemName = "PAL" if pal else "NTSC"
    with open(filename, 'wt') as outfp:
        outfp.write("""; %s period table generated by mktables.py
.export periodTableLo, periodTableHi
.segment "RODATA"
periodTableLo:\n"""
                    % systemName)
        for i in range(0, maxNote, 12):
            outfp.write('  .byt '
                        + ','.join('$%02x' % (i % 256)
                                   for i in periods[i:i + 12])
                        + '\n')
        outfp.write('periodTableHi:\n')
        for i in range(0, maxNote, 12):
            outfp.write('  .byt '
                        + ','.join('$%02x' % (i >> 8)
                                   for i in periods[i:i + 12])
                        + '\n')

def makePALPeriodTable(filename):
    return makePeriodTable(filename, pal=True)

def makeFDSPeriodTable(filename, pal=False):
    semitone = 2.0**(1./12)
    octaveBase = palOctaveBase if pal else ntscOctaveBase
    relFreqs = [(1 << (i // 12)) * semitone**(i % 12)
                for i in range(maxNote)]
    periods = [int(round(octaveBase / freq)) - 1 for freq in relFreqs]
    systemName = "PAL" if pal else "NTSC"
    with open(filename, 'wt') as outfp:
        outfp.write("""; %s period table generated by mktables.py
.export periodTableLo, periodTableHi
.segment "FILE0_DAT"
periodTableLo:\n"""
                    % systemName)
        for i in range(0, maxNote, 12):
            outfp.write('  .byt '
                        + ','.join('$%02x' % (i % 256)
                                   for i in periods[i:i + 12])
                        + '\n')
        outfp.write('periodTableHi:\n')
        for i in range(0, maxNote, 12):
            outfp.write('  .byt '
                        + ','.join('$%02x' % (i >> 8)
                                   for i in periods[i:i + 12])
                        + '\n')

tableNames = {
    'period': makePeriodTable,
    'palperiod': makePALPeriodTable,
    'fdsperiod': makeFDSPeriodTable
}

def main(argv):
    if len(argv) >= 2 and argv[1] in ('/?', '-?', '-h', '--help'):
        print("usage: %s TABLENAME FILENAME" % argv[0])
        print("known tables:", ' '.join(sorted(tableNames)))
    elif len(argv) < 3:
        print("mktables: too few arguments; try %s --help" % argv[0])
    elif argv[1] in tableNames:
        tableNames[argv[1]](argv[2])
    else:
        print("mktables: no such table %s; try %s --help" % (argv[1], argv[0]))

if __name__=='__main__':
    main(sys.argv)
