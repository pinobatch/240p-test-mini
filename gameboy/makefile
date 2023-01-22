#!/usr/bin/make -f
#
# Makefile for 144p Test Suite for Game Boy
# Copyright 2014-2021 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# Used in the title of the zipfile and .gb executable
title:=gb240p
version:=0.23b1

# Space-separated list of asm files without .z80 extension
# (use a backslash to continue on the next line)
objlist := linkthisfirst \
  header init \
  main help helppages.hlp placeholder \
  stills shadowsprite backlight scrolltest motionblur overscan \
  megaton stopwatch soundtest mdfourier mdfourierfe audiosync \
  sgbtests gbctests \
  ppuclear pads vwfdraw vwflabels vwf7 rand unpb16 undte bcd \
  uniur huffnib gfxincbins allhuffdata pitchtable \
  linkthislast

huffdata := \
  obj/gb/stopwatchhand.2bpp.pb16 \
  obj/gb/stopwatchdigits.2bpp.pb16 \
  obj/gb/spritegfx.2bpp.pb16 \
  obj/gb/greenhillzone.u.2bpp.pb16 \
  obj/gb/sharpness.iu \
  obj/gb/linearity-quadrant.iu \
  obj/gb/stopwatchface.iu \
  obj/gb/Donna_portrait.iu

# Paths to executables
RGBASM  := rgbasm
RGBLINK := rgblink
RGBFIX  := rgbfix
CC      := gcc

# Flags for native tools written in C
CFLAGS := -std=gnu99 -Wall -Wextra -DNDEBUG -Os

# Disable -static on macOS, whose system libraries are not provided
# in static form
# https://stackoverflow.com/a/3801032
UNAME := $(shell uname)
ifneq ($(UNAME),Darwin)
CFLAGS := $(CFLAGS) -static 
endif

# Things that depend on Windows vs. not-Windows
ifdef COMSPEC
  ifndef GBEMU
    GBEMU := start ""
  endif
  PY := py -3
  DOTEXE:=.exe
else
  ifndef GBEMU
    # I now use a shell script in ~/.local/bin
    GBEMU := bgb
  endif
  PY := python3
  DOTEXE:=
endif

BMP2 := $(PY) ../common/tools/pilbmp2nes.py
BMP2GB := $(PY) ../common/tools/pilbmp2nes.py --planes "0,1"

.SUFFIXES:
.PHONY: run all dist zip ctools clean

run: $(title).gb
	$(GBEMU) $<
all: $(title).gb
ctools: ../common/tools/dte$(DOTEXE)

clean:
	-rm obj/gb/*.s obj/gb/*.z80 obj/gb/*.o obj/gb/*.pb16
	-rm obj/gb/*.2bpp obj/gb/*.2bpp16 obj/gb/*.nam obj/gb/*.chr1
	-rm obj/gb/*.iu obj/gb/*.iuc obj/gb/*.huf obj/gb/*.pal
	-rm obj/gb/*.border obj/gb/*.chrgb* obj/gb/last-commit*
	-rm ../common/tools/dte$(DOTEXE)

# Packaging

dist: zip
zip: $(title)-$(version).zip

# The zipfile depends on every file in zip.in, but as a shortcut,
# mention only files on which the ROM doesn't itself depend.
$(title)-$(version).zip: zip.in $(title).gb \
  README.md CHANGES.txt obj/gb/index.txt
	$(PY) tools/zipup.py $< $(title)-$(version) -o $@
	-advzip -z3 $@

# Build zip.in from the list of files in the Git tree
zip.in: makefile
	git ls-files | grep -e "^[^.]" > $@
	echo $(title).gb >> $@
	echo zip.in >> $@

obj/gb/index.txt: makefile
	echo "Files produced by build tools go here. (This file's existence forces the unzip tool to create this folder.)" > $@

# The ROM

objlisto := $(foreach o,$(objlist),obj/gb/$(o).o)

$(title).gb: $(objlisto)
	$(RGBLINK) -w -p 0xFF -m$(title).map -n$(title).sym -o$@ $^
	$(RGBFIX) -p0 -v $@

#obj/gb/%.o: obj/gb/%-dedent.z80 src/gb.inc src/hardware.inc src/global.inc
#	$(RGBASM) -o $@ $<
#
#obj/gb/%-dedent.z80: src/%.z80
#	$(PY) tools/bgrdedent.py -o $@ $<

obj/gb/%.o: src/%.z80 src/gb.inc src/hardware.inc src/global.inc
	$(RGBASM) -h -o $@ $<

obj/gb/%.o: obj/gb/%.z80
	$(RGBASM) -h -o $@ $<

# Files that will be included with incbin

obj/gb/gfxincbins.o: \
  obj/gb/helptiles.2bpp16.pb16 obj/gb/helptiles-gbc.2bpp16.pb16 \
  obj/gb/helpblink.2bpp \
  obj/gb/hepsie.2bpp.pb16 obj/gb/shadow_reticle.2bpp.pb16 \
  obj/gb/Gus_portrait.iu \
  obj/gb/Gus_portrait-GBC.iuc obj/gb/Gus_portrait-GBC.pal \
  obj/gb/pluge_shark_4color.2bpp.pb16 obj/gb/backlightzone.2bpp.pb16 \
  obj/gb/grayramp-sgb.2bpp obj/gb/grayramp.2bpp \
  obj/gb/convergence.2bpp.pb16 \
  obj/gb/cps_grid.2bpp.pb16 obj/gb/linearity-quadrant.iu \
  obj/gb/sharpness.iu obj/gb/stopwatchdigits.2bpp.pb16.huf \
  obj/gb/stopwatchhand.2bpp.pb16.huf obj/gb/stopwatchface.iu \
  obj/gb/spritegfx.2bpp.pb16 obj/gb/bggfx.2bpp.pb16 \
  obj/gb/kikimap.chr1.pb16 obj/gb/kikitiles.2bpp \
  obj/gb/greenhillzone.u.2bpp.pb16 obj/gb/greenhillzone.nam.pb16 \
  obj/gb/smptetiles.2bpp.pb16 obj/gb/megatontiles.2bpp16.pb16 \
  obj/gb/sgbborder.border
  

# Graphics conversion

# .2bpp (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
obj/gb/%.2bpp: tilesets/%.png
	$(BMP2GB) $< $@

obj/gb/%.2bpp16: tilesets/%.png
	$(BMP2GB) -H 16 $< $@

obj/gb/kikimap.chr1: tilesets/kikimap.png
	$(BMP2) --planes "0" -H 32 $< $@

obj/gb/pluge_shark_4color.2bpp: ../common/tilesets/pluge_shark_4color.png
	$(BMP2GB) -H 32 $< $@

obj/gb/vwf7.z80: tools/vwfbuild.py ../common/tilesets/vwf7_cp144p.png
	$(PY) $^ $@

obj/gb/%.iu: obj/gb/%.2bpp
	$(PY) tools/incruniq.py $< $@

obj/gb/%.u.2bpp: obj/gb/%.2bpp
	$(PY) tools/uniq.py $< $@ $(<:.2bpp=.nam)

obj/gb/%.nam: obj/gb/%.u.2bpp
	-touch $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@

%.huf: tools/huffnib.py %
	$(PY) $^ $@

obj/gb/%.iuc: tools/gbcnamtool.py tilesets/%.png tilesets/%.pal.txt
	$(PY) $^ $@

obj/gb/%.border: tools/makeborder.py tilesets/%.png
	$(PY) $^ $@

obj/gb/%.pal: tools/gbcnamtool.py tilesets/%.pal.txt
	$(PY) $< '' $(word 2,$^) $@

obj/gb/allhuffdata.z80: tools/allhuffdata.py $(filter-out DMG?,$(huffdata))
	$(PY) $< $(huffdata) -o $@

# Help me!
obj/gb/%.hlp.z80: src/%.txt tools/paginate_help.py \
  ../common/tools/dtefe.py ../common/tools/dte$(DOTEXE) \
  ../common/tools/cp144p.py obj/gb/last-commit
	$(PY) tools/paginate_help.py -DCOMMIT="$$(cat obj/gb/last-commit)"  $< -o $@

../common/tools/dte$(DOTEXE): ../common/tools/dte.c
	$(CC) $(CFLAGS) -o $@ $^

# So, pitch!
obj/gb/pitchtable.z80: tools/pitchtable.py
	$(PY) $< > $@

# Print the commit tag
obj/gb/last-commit-now:
	git describe --tags | tr -d '\r\n' > $@
# Update last-commit only if it has changed
obj/gb/last-commit: obj/gb/last-commit-now
	if test -f $@; then true; else touch $@; fi
	cmp $< $@ || cp $< $@
