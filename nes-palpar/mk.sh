#!/bin/sh
set -e
mkdir -p obj/nes
../nes/tools/savtool.py --palette 0f2610200f2424240f2424240f242424 tilesets/palpar.png obj/nes/palpar.png.sav
../nes/tools/savtool.py obj/nes/palpar.png.sav obj/nes/palpar.chr
../nes/tools/savtool.py obj/nes/palpar.png.sav obj/nes/palpar.nam
ca65 -o obj/nes/main.o src/main.s
ld65 -o palpar.nes -C nrom128.cfg obj/nes/main.o
