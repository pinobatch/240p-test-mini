#!/usr/bin/make -f
#
# Makefile for 240p test suite
# Copyright 2011-2016 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the NES program and the zip file.
title = 240pee
version = 0.16

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist = vwf7 overclock paldetect init vwf_draw \
  main helpscreen stills stopwatch backlight scrolling kiki \
  audiosync soundtest crowd overscan megaton semixparent zappertest \
  pads ppuclear unpb53 bcd random rectfill muldiv \
  pb53files helppages.hlp

AS65 = ca65
LD65 = ld65
CFLAGS65 = 
objdir = obj/nes
srcdir = src
imgdir = tilesets
cimgdir = ../common/tilesets

#EMU := "/C/Program Files/Nintendulator/Nintendulator.exe"
EMU := fceux
DEBUGEMU := ~/.wine/drive_c/Program\ Files\ \(x86\)/FCEUX/fceux.exe

# Windows needs .exe suffixed to the names of executables; UNIX does
# not.  COMSPEC will be set to the name of the shell on Windows and
# not defined on UNIX.  Also the Windows Python installer puts
# py.exe in the path, but not python3.exe, which confuses MSYS Make.
ifdef COMSPEC
DOTEXE:=.exe
PY:=py
else
DOTEXE:=
PY:=
endif

.PHONY: run runalt debug dist zip all clean

run: $(title).nes
	$(EMU) $<
runalt: $(title)-bnrom.nes
	$(EMU) $<
debug: $(title).nes
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

all: $(title)-bnrom.nes $(title).nes

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here, but caulk goes where?" > $@

clean:
	-rm $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr $(objdir)/*.?b53
	-rm $(objdir)/*.sav map.txt bnmap.txt

# Rules for PRG ROM

objlisto = $(foreach o,$(objlist),$(objdir)/$(o).o)

map.txt $(title).nes: unrom512kbit.cfg $(objlisto) $(objdir)/unrom.o
	$(LD65) -o $(title).nes -m map.txt -C $^

bnmap.txt $(title)-bnrom.nes: bnrom512kbit.cfg $(objlisto) $(objdir)/bnrom.o
	$(LD65) -o $(title)-bnrom.nes -m bnmap.txt -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

# Files that depend on included files (.include, .incbin)

$(objdir)/stills.o $(objdir)/semixparent.o \
$(objdir)/overclock.o $(objdir)/rectfill.o $(objdir)/stopwatch.o \
$(objdir)/scrolling.o $(objdir)/overscan.o $(objdir)/megaton.o: \
  $(srcdir)/rectfill.inc
$(objdir)/semixparent.o: \
  $(objdir)/shadow_reticle.chr.pb53 $(objdir)/hepsie.chr.pb53
$(objdir)/kiki.o: \
  $(objdir)/kikimap.chr.pb53
# Most of the compressed CHR data is grouped into "files" so that
# I can move them from bank to bank more easily
$(objdir)/pb53files.o: \
  $(objdir)/gus_bg.sb53 $(objdir)/gus_sprite.chr.pb53 \
  $(objdir)/greenhillzone.sb53 $(objdir)/kikitiles16.chr.pb53 \
  $(objdir)/overscan.chr.pb53 $(objdir)/megatontiles.chr.pb53 \
  $(objdir)/lag_clock_face.sb53 $(objdir)/fizzter_digits.chr.pb53 \
  $(objdir)/lag_clock_balls.chr.pb53 $(objdir)/gus_portrait.sb53 \
  $(objdir)/stdtiles.chr.pb53 $(objdir)/backlight_sprites.chr.pb53 \
  $(objdir)/linearity_ntscgray.sb53 $(objdir)/linearity_palgray.sb53 \
  $(objdir)/linearity_grid_ntscgray.sb53 $(objdir)/linearity_grid_palgray.sb53 \
  $(objdir)/sharpnessgray.sb53 $(objdir)/crosstalk.sb53

# Generic rules for CHR

$(objdir)/%.chr: $(imgdir)/%.png
	$(PY) tools/pilbmp2nes.py --planes "0;1" $< $@
$(objdir)/%16.chr: $(imgdir)/%.png
	$(PY) tools/pilbmp2nes.py -H 16 --planes "0;1" $< $@
$(objdir)/%gray.sav: $(imgdir)/%.png
	$(PY) tools/savtool.py --palette 0f0010200f1616160f1616160f161616 $< $@
$(objdir)/%.sb53: $(objdir)/%.sav
	$(PY) tools/sav2sb53.py $< $@
$(objdir)/%.pb53: $(objdir)/%
	$(PY) tools/pb53.py $< $@

# Specific rules for CHR

$(objdir)/gus_sprite.chr: $(imgdir)/gus_sprite.png
	$(PY) tools/pilbmp2nes.py -H 128 --planes "0;1" $< $@
$(objdir)/gus_bg.sav: $(imgdir)/gus_bg.png
	$(PY) tools/savtool.py --palette 0f0820180f1a202a0f060f160f0f1424 $< $@
$(objdir)/lag_clock_face.sav: $(imgdir)/lag_clock_face.png
	$(PY) tools/savtool.py --palette 20100f24203626242026162420210124 $< $@
$(objdir)/vwf7.s: $(cimgdir)/vwf7_cp240p.png
	$(PY) tools/vwfbuild.py $< $@
$(objdir)/gus_portrait.sav: $(imgdir)/gus_portrait.png
	$(PY) tools/savtool.py --palette 0F2012370F2028100F2027370F122810 $< $@
$(objdir)/greenhillzone.sb53: $(imgdir)/greenhillzone.png
	$(PY) tools/widesb53.py $< 2208322022081A29220818282208181A $@
$(objdir)/kikimap.chr: $(imgdir)/kikimap.png
	$(PY) tools/pilbmp2nes.py -H 32 --planes "0" $< $@
$(objdir)/crosstalk.sav: $(imgdir)/crosstalk.png
	$(PY) tools/savtool.py --palette 0F161A120F0F0F0F0F0F0F0F0F0F0F0F $< $@

# Help me!
$(objdir)/%.hlp.s: $(srcdir)/%.txt
	$(PY) tools/paginate_help.py $< > $@

