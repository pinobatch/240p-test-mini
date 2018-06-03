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
version:=0.05

# Space-separated list of asm files without .z80 extension
# (use a backslash to continue on the next line)
objlist = header init \
  main help helppages.hlp placeholder \
  stills shadowsprite backlight scrolltest motionblur \
  megaton stopwatch overscan soundtest audiosync gbctests \
  Gus_portrait_GBC \
  ppuclear pads vwfdraw vwflabels vwf7 rand unpb16 undte bcd \
  singletons gfxincbins

ifdef COMSPEC
  ifndef GBEMU
    GBEMU := start ""
  endif
  PY := py -3
else
  ifndef GBEMU
    GBEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/bgb/bgb.exe
  endif
  PY := python3
endif

.SUFFIXES:
.PHONY: run all dist zip

run: $(title).gb
	$(GBEMU) $<
all: $(title).gb

clean:
	-rm obj/gb/*.s obj/gb/*.z80 obj/gb/*.o obj/gb/*.pb16
	-rm obj/gb/*.chrgb obj/gb/*.chrgb16 obj/gb/*.nam obj/gb/*.chr1
	-rm obj/gb/*.iu

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

objlisto = $(foreach o,$(objlist),obj/gb/$(o).o)

$(title).gb: $(objlisto)
	rgblink -p 0xFF -m$(title).map -n$(title).sym -o$@ $^
	rgbfix -p0 -v $@

obj/gb/%.o: obj/gb/%-dedent.z80 src/gb.inc src/hardware.inc src/global.inc
	rgbasm -o $@ $<

obj/gb/%.o: obj/gb/%.z80
	rgbasm -o $@ $<

obj/gb/%-dedent.z80: src/%.z80
	$(PY) tools/bgrdedent.py -o $@ $<

# Files that will be included with incbin

obj/gb/gfxincbins.o: \
  obj/gb/helptiles.chrgb16.pb16 obj/gb/helptiles-gbc.chrgb16.pb16 \
  obj/gb/hepsie.chrgb16.pb16 obj/gb/shadow_reticle.chrgb16.pb16 \
  obj/gb/Gus_portrait.iu \
  obj/gb/backlightzone.chrgb.pb16 \
  obj/gb/grayramp.chrgb obj/gb/cps_grid.chrgb.pb16 \
  obj/gb/linearity.iu obj/gb/sharpness.iu \
  obj/gb/spritegfx.chrgb.pb16 obj/gb/bggfx.chrgb.pb16 \
  obj/gb/kikimap.chr1 obj/gb/kikitiles.chrgb \
  obj/gb/greenhillzone.u.chrgb.pb16 obj/gb/greenhillzone.nam.pb16 \
  obj/gb/megatontiles.chrgb16.pb16 \
  obj/gb/stopwatchface.iu \
  obj/gb/stopwatchhand.chrgb.pb16 obj/gb/stopwatchdigits.chrgb.pb16 \
  obj/gb/smptetiles.chrgb.pb16 obj/gb/gradientcolorbartiles.chrgb.pb16 \

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

obj/gb/vwf7.z80: tools/vwfbuild.py tilesets/vwf7.png
	$(PY) $^ $@

obj/gb/%.iu: obj/gb/%.chrgb
	$(PY) tools/incruniq.py $< $@

obj/gb/%.u.chrgb: obj/gb/%.chrgb
	$(PY) tools/uniq.py $< $@ $(<:.chrgb=.nam)

obj/gb/%.nam: obj/gb/%.u.chrgb
	touch $@

%.pb16: tools/pb16.py %
	$(PY) $^ $@

obj/gb/Gus_portrait_GBC.z80: tools/gbcnamtool.py \
  tilesets/Gus_portrait-GBC.png tilesets/Gus_portrait-GBC.pal.txt
	$(PY) $^ --incruniq --pb16-attrs $@

# Help me!
obj/gb/%.hlp.z80: tools/paginate_help.py src/%.txt
	$(PY) $^ > $@

