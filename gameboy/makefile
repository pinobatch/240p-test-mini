#!/usr/bin/make -f
#
# Makefile for Game Boy template
# Copyright 2014-2018 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# Used in the title of the zipfile and .gb executable
title:=gb240p
version:=wip

# Space-separated list of asm files without .s extension
# (use a backslash to continue on the next line)
objlist = header init \
  main help helppages.hlp placeholder \
  stills shadowsprite backlight scrolltest motionblur \
  megaton stopwatch overscan soundtest audiosync \
  ppuclear pads vwfdraw vwflabels vwf7 rand unpb16 undte bcd

EMU := mgba-qt
DEBUGEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/bgb/bgb.exe

ifdef COMSPEC
  PY := py -3
else
  PY := python3
endif

.SUFFIXES:
.PHONY: run debug all dist zip

run: $(title).gb
	$(EMU) $<
debug: $(title).gb
	$(DEBUGEMU) $<

all: $(title).gb

clean:
	-rm obj/gb/*.s obj/gb/*.o obj/gb/*.pb16
	-rm obj/gb/*.chrgb obj/gb/*.chrgb16 obj/gb/*.nam obj/gb/*.chr1

# Packaging

dist: zip
zip: $(title)-$(version).zip

# The zipfile depends on every file in zip.in, but as a shortcut,
# mention only files on which the ROM doesn't itself depend.
$(title)-$(version).zip: zip.in $(title).gb \
  README.md CHANGES.txt obj/gb/index.txt
	tools/zipup.py $< $(title)-$(version) -o $@
	-advzip -z3 $@

obj/gb/index.txt: makefile
	echo "Files produced by build tools go here. (This file's existence forces the unzip tool to create this folder.)" > $@

# The ROM

objlisto = $(foreach o,$(objlist),obj/gb/$(o).o)

$(title).gb: $(objlisto)
	rgblink -p 0xFF -m$(title).map -n$(title).sym -o$@ $^
	rgbfix -p0 -v $@

obj/gb/%.o: obj/gb/%-dedent.s src/gb.inc src/hardware.inc src/global.inc
	rgbasm -o $@ $<

obj/gb/%.o: obj/gb/%.s
	rgbasm -o $@ $<

obj/gb/%-dedent.s: src/%.s
	$(PY) tools/bgrdedent.py -o $@ $<

# Files that will be included with incbin

obj/gb/placeholder.o: obj/gb/spritegfx.chrgb.pb16 obj/gb/bggfx.chrgb.pb16
obj/gb/help.o: \
  obj/gb/helptiles.chrgb16.pb16 obj/gb/helptiles-gbc.chrgb16.pb16
obj/gb/stills.o: obj/gb/grayramp.chrgb obj/gb/cps_grid.chrgb.pb16 \
  obj/gb/linearity.u.chrgb.pb16 obj/gb/linearity.nam \
  obj/gb/sharpness.u.chrgb.pb16 obj/gb/sharpness.nam 
obj/gb/shadowsprite.o: \
  obj/gb/hepsie.chrgb16.pb16 obj/gb/shadow_reticle.chrgb16.pb16 \
  obj/gb/Gus_portrait.u.chrgb.pb16 obj/gb/Gus_portrait.nam
obj/gb/backlight.o: obj/gb/backlightzone.chrgb.pb16
obj/gb/scrolltest.o: \
  obj/gb/kikimap.chr1 obj/gb/kikitiles.chrgb \
  obj/gb/greenhillzone.u.chrgb.pb16 obj/gb/greenhillzone.nam.pb16
obj/gb/megaton.o: obj/gb/megatontiles.chrgb16.pb16
obj/gb/stopwatch.o: \
  obj/gb/stopwatchface.u.chrgb.pb16 obj/gb/stopwatchface.nam \
  obj/gb/stopwatchhand.chrgb.pb16 obj/gb/stopwatchdigits.chrgb.pb16
obj/gb/overscan.o: obj/gb/overscan.chrgb.pb16
obj/gb/motionblur.o: obj/gb/motionblurtiles.chrgb.pb16


# Graphics conversion

# .chrgb (CHR data for Game Boy) denotes the 2-bit tile format
# used by Game Boy and Game Boy Color, as well as Super NES
# mode 0 (all planes), mode 1 (third plane), and modes 4 and 5
# (second plane).
obj/gb/%.chrgb: tilesets/%.png
	$(PY) tools/pilbmp2nes.py --planes "0,1" $< $@

obj/gb/%.chrgb16: tilesets/%.png
	$(PY) tools/pilbmp2nes.py --planes "0,1" -H 16 $< $@

obj/gb/kikimap.chr1: tilesets/kikimap.png
	$(PY) tools/pilbmp2nes.py --planes "0" -H 32 $< $@

obj/gb/vwf7.s: tools/vwfbuild.py tilesets/vwf7.png
	$(PY) $^ $@

obj/gb/%.u.chrgb: obj/gb/%.chrgb
	$(PY) tools/uniq.py $< $@ $(<:.chrgb=.nam)

obj/gb/%.nam: obj/gb/%.u.chrgb
	touch $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@

# Help me!
obj/gb/%.hlp.s: tools/paginate_help.py src/%.txt
	$(PY) $^ > $@

