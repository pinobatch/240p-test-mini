#!/usr/bin/make -f
#
# Makefile for 240p test suite for NES
# Copyright 2011-2019 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the NES program and the zip file.
title:=240pee
version:=0.21

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist:=vwf7 zappertest overclock paldetect vwf_draw init \
  main help helppages.hlp stills linearity stopwatch backlight scrolltest \
  kiki audiosync soundtest crowd mdfourierfe mdfourier \
  overscan megaton shadowsprite \
  pads ppuclear unpb53 uniu undte bcd rand rectfill muldiv \
  pb53files rectfiles ntscPeriods
objlistnsf := mdfouriernsf mdfourier ntscPeriods

AS65:=ca65
LD65:=ld65
CFLAGS65:=-g
objdir:=obj/nes
srcdir:=src
imgdir:=tilesets
cimgdir:=../common/tilesets

# Flags for native tools written in C
CC := gcc
CFLAGS := -std=gnu99 -Wall -Wextra -DNDEBUG -Os

# Disable -static on macOS, whose system libraries are not provided
# in static form
# https://stackoverflow.com/a/3801032
UNAME := $(shell uname)
ifneq ($(UNAME),Darwin)
CFLAGS := $(CFLAGS) -static 
endif

# Windows needs .exe suffixed to the names of executables; UNIX does
# not.  COMSPEC will be set to the name of the shell on Windows and
# not defined on UNIX.  Also the Windows Python installer puts
# py.exe in the path, but not python3.exe, which confuses MSYS Make.
ifdef COMSPEC
DOTEXE:=.exe
PY:=py
EMU:=start ""
DEBUGEMU := start ""
else
DOTEXE:=
PY:=python3
EMU:=fceux
DEBUGEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/FCEUX/fceux.exe
endif
DEBUGEMU2 := Mesen.exe
BMP2 := $(PY) ../common/tools/pilbmp2nes.py

.PHONY: run runalt runnsf debug debug2 debugalt debugnsf nsf dist zip all clean ctools

run: $(title).nes
	$(EMU) $<
runalt: $(title)-bnrom.nes
	$(EMU) $<
runnsf: mdfourier.nsf
	$(EMU) $<
debug: $(title).nes
	$(DEBUGEMU) $<
debug2: $(title).nes
	$(DEBUGEMU2) $<
debugalt: $(title)-bnrom.nes
	$(DEBUGEMU2) $<
debugnsf: mdfourier.nsf
	$(DEBUGEMU) $<

# Rule to create or update the distribution zipfile by adding all
# files listed in zip.in.  Use changes to the compiled program and
# README as a heuristic for when something was changed.
dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in all \
  README.md CHANGES.txt making-carts.md $(objdir)/index.txt
	zip -9 -u $@ -@ < $<
	-advzip -z3 $@

all: $(title)-bnrom.nes $(title).nes mdfourier.nsf
ctools: ../common/tools/dte$(EXE)

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here, but caulk goes where?" > $@

clean:
	-rm $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr $(objdir)/*.?b53
	-rm $(objdir)/*.sav $(objdir)/*.iu53 map.txt bnmap.txt nsfmap.txt
	-rm ../common/tools/dte$(DOTEXE)

# Rules for PRG ROM

objlisto = $(foreach o,$(objlist),$(objdir)/$(o).o)
objlistnsfo = $(foreach o,$(objlistnsf),$(objdir)/$(o).o)

map.txt $(title).nes: unrom512kbit.cfg $(objlisto) $(objdir)/unrom.o
	$(LD65) -o $(title).nes -m map.txt --dbgfile $(title).dbg -C $^

bnmap.txt $(title)-bnrom.nes: bnrom512kbit.cfg $(objlisto) $(objdir)/bnrom.o
	$(LD65) -o $(title)-bnrom.nes -m bnmap.txt --dbgfile $(title)-bnrom.dbg -C $^

nsfmap.txt mdfourier.nsf: nsf.cfg $(objlistnsfo)
	$(LD65) -o mdfourier.nsf -m nsfmap.txt --dbgfile mdfourier.dbg -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

# Files that depend on included files (.include, .incbin)

$(objdir)/stills.o $(objdir)/shadowsprite.o \
$(objdir)/overclock.o $(objdir)/rectfill.o $(objdir)/stopwatch.o \
$(objdir)/scrolling.o $(objdir)/overscan.o $(objdir)/megaton.o: \
  $(srcdir)/rectfill.inc
$(objdir)/shadowsprite.o: \
  $(objdir)/shadow_reticle.chr.pb53 $(objdir)/hepsie.chr.pb53
$(objdir)/kiki.o: \
  $(objdir)/kikimap.chr.pb53
$(objdir)/mdfourier.o: audio/instsamp1.dmc
# Most of the compressed CHR data is grouped into "files" so that
# I can move them from bank to bank more easily
$(objdir)/pb53files.o: \
  $(objdir)/gus_bg.sb53 $(objdir)/greenhillzone.sb53 \
  $(objdir)/linearity_ntsc.iu53 $(objdir)/linearity_pal.iu53 \
  $(objdir)/sharpness.iu53 $(objdir)/stopwatchface.iu53 \
  $(objdir)/crosstalk.iu53 $(objdir)/gus_portrait.iu53 \
  $(objdir)/gus_sprite.chr.pb53 $(objdir)/stopwatchhand.chr.pb53 \
  $(objdir)/stdtiles.chr.pb53 $(objdir)/backlight_sprites.chr.pb53 \
  $(objdir)/kikitiles16.chr.pb53 $(objdir)/megatontiles.chr.pb53 \
  $(objdir)/overscan.chr.pb53 $(objdir)/pluge_shark_4color.chr.pb53 \
  $(objdir)/fizzter_digits.chr.pb53 $(objdir)/convergence.chr.pb53

# MDFourier needs the period lookup table
$(objdir)/ntscPeriods.s: tools/mktables.py
	$(PY) $< period $@

# Generic rules for CHR

$(objdir)/%.chr: $(imgdir)/%.png
	$(BMP2) --planes "0;1" $< $@
$(objdir)/%16.chr: $(imgdir)/%.png
	$(BMP2) -H 16 --planes "0;1" $< $@
$(objdir)/%gray.sav: $(imgdir)/%.png
	$(PY) tools/savtool.py --palette 0f0010200f1616160f1616160f161616 $< $@
$(objdir)/%.sb53: $(objdir)/%.sav
	$(PY) tools/sav2sb53.py $< $@
$(objdir)/%.pb53: $(objdir)/%
	$(PY) tools/pb53.py $< $@

# Specific rules for CHR

$(objdir)/linearity_ntsc.iu53: $(objdir)/linearity_ntscgray.sav
	$(PY) tools/sav2iu53.py --x-grid 0,1,2,3,4,5,6 $< $@
$(objdir)/linearity_pal.iu53: $(objdir)/linearity_palgray.sav
	$(PY) tools/sav2iu53.py --y-grid 8,2,5,8,0,3,6,8,1,4,7 $< $@
$(objdir)/sharpness.iu53: $(objdir)/sharpness.sav
	$(PY) tools/sav2iu53.py --with-attrs --with-palette $< $@
$(objdir)/stopwatchface.iu53: $(objdir)/lag_clock_face.sav
	$(PY) tools/sav2iu53.py --with-attrs --with-palette $< $@
$(objdir)/crosstalk.iu53: $(objdir)/crosstalk.sav
	$(PY) tools/sav2iu53.py $< $@
$(objdir)/gus_portrait.iu53: $(objdir)/gus_portrait.sav
	$(PY) tools/sav2iu53.py --with-attrs --with-palette --blank-color=1 $< $@

$(objdir)/gus_sprite.chr: $(imgdir)/gus_sprite.png
	$(BMP2) -H 128 --planes "0;1" $< $@
$(objdir)/gus_bg.sav: $(imgdir)/gus_bg.png
	$(PY) tools/savtool.py --palette 0f0820180f1a202a0f060f160f0f1424 $< $@
$(objdir)/sharpness.sav: $(imgdir)/sharpness.png
	$(PY) tools/savtool.py --palette 000F2024000607100024242400242424 $< $@
$(objdir)/lag_clock_face.sav: $(imgdir)/lag_clock_face.png
	$(PY) tools/savtool.py --palette 20100f24203626242021012420261624 $< $@
$(objdir)/vwf7.s: tools/vwfbuild.py $(cimgdir)/vwf7_cp240p.png
	$(PY) $^ $@
$(objdir)/gus_portrait.sav: $(imgdir)/gus_portrait.png
	$(PY) tools/savtool.py --palette 0F2012370F2028100F2027370F122810 $< $@
$(objdir)/greenhillzone.sb53: $(imgdir)/greenhillzone.png
	$(PY) tools/widesb53.py $< 2208322022081A29220818282208181A $@
$(objdir)/kikimap.chr: $(imgdir)/kikimap.png
	$(BMP2) -H 32 --planes "0" $< $@
$(objdir)/crosstalk.sav: $(imgdir)/crosstalk.png
	$(PY) tools/savtool.py --palette 0F161A120F0F0F0F0F0F0F0F0F0F0F0F $< $@
$(objdir)/pluge_shark_4color.chr: $(cimgdir)/pluge_shark_4color.png
	$(BMP2) -H 32 $< $@

# Help me!
$(objdir)/%.hlp.s: $(srcdir)/%.txt tools/paginate_help.py \
  ../common/tools/dtefe.py ../common/tools/dte$(DOTEXE)
	$(PY) tools/paginate_help.py $< > $@

../common/tools/dte$(DOTEXE): ../common/tools/dte.c
	$(CC) $(CFLAGS) -o $@ $^
