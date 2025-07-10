#!/usr/bin/make -f
#
# Makefile for 240p test suite for NES
# Copyright 2011-2021 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the NES program and the zip file.
title:=240pee
version:=0.23

# Space-separated list of assembly language files that make up the
# PRG ROM.  If it gets too long for one line, you can add a backslash
# (the \ character) at the end of the line and continue on the next.
objlist:=vwf7 zappertest overclock paldetect vwf_draw init \
  main help helppages.hlp stills stopwatch backlight \
  scrolltest kiki audiosync soundtest crowd mdfourierfe mdfourier \
  overscan megaton shadowsprite padstest hanover \
  pads ppuclear unpb53 uniu undte bcd rand rectfill muldiv \
  pb53files rectfiles ntscPeriods
objlistnsf := mdfouriernsf mdfourier ntscPeriods
objlistmdf4k := mdfourier4kfe mdfourier padsnodas ntscPeriods
objlistmdf4kchr := mdfourier4kfe-chrrom mdfourier padsnodas ntscPeriods
objlistmdf4kauto := mdfourier4kfe-autostart mdfourier ntscPeriods
objlistmdf4kchrauto := mdfourier4kfe-chrrom-autostart mdfourier ntscPeriods

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
DEBUGEMU := Mesen
endif
DEBUGEMU2 := Mesen.exe
BMP2 := $(PY) ../common/tools/pilbmp2nes.py
FIX := $(PY) tools/sssfix.py -v -l 0 -t "240P TEST SUITE"

.PHONY: run runbn runsg runtg runnsf runmdf \
        debug debug2 debugbn debugsg debugtg debugnsf debugmdf \
        nsf dist zip all clean ctools \
        $(objdir)/last-commit-now

run: $(title).nes
	$(EMU) $<
runbn: $(title)-bnrom.nes
	$(EMU) $<
runsg: $(title)-sgrom.nes
	$(EMU) $<
runtg: $(title)-tgrom.nes
	$(EMU) $<
runnsf: mdfourier.nsf
	$(EMU) $<
runmdf: mdfourier4k.nes
	$(EMU) $<
runmdfchr: mdfourier4k-chrrom.nes
	$(EMU) $<
runmdfauto: mdfourier4k-autostart.nes
	$(EMU) $<
runmdfchrauto: mdfourier4k-chrrom-autostart.nes
	$(EMU) $<
debug: $(title).nes
	$(DEBUGEMU) $<
debug2: $(title).nes
	$(DEBUGEMU2) $<
debugbn: $(title)-bnrom.nes
	$(DEBUGEMU2) $<
debugsg: $(title)-sgrom.nes
	$(DEBUGEMU2) $<
debugtg: $(title)-tgrom.nes
	$(DEBUGEMU2) $<
debugnsf: mdfourier.nsf
	$(DEBUGEMU) $<
debugmdf: mdfourier4k.nes
	$(DEBUGEMU) $<
debugmdfchr: mdfourier4k-chrrom.nes
	$(DEBUGEMU) $<
debugmdfauto: mdfourier4k-autostart.nes
	$(DEBUGEMU) $<
debugmdfchrauto: mdfourier4k-chrrom-autostart.nes
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

all: \
  $(title).nes $(title)-bnrom.nes $(title)-sgrom.nes $(title)-tgrom.nes \
  mdfourier.nsf mdfourier4k.nes mdfourier4k-chrrom.nes \
  mdfourier4k-autostart.nes mdfourier4k-chrrom-autostart.nes
ctools: ../common/tools/dte$(EXE)

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here" > $@

clean:
	$(RM) $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr $(objdir)/*.?b53
	$(RM) $(objdir)/*.sav $(objdir)/*.iu53 map.txt ??map.txt nsfmap.txt
	$(RM) $(objdir)/last-commit*
	$(RM) ../common/tools/dte$(DOTEXE)

# Rules for PRG ROM

objlisto := $(foreach o,$(objlist),$(objdir)/$(o).o)
objlistmmco := $(foreach o,$(objlist),$(objdir)/$(o)-mmc.o)
objlistnsfo := $(foreach o,$(objlistnsf),$(objdir)/$(o).o)
objlistmdf4ko := $(foreach o,$(objlistmdf4k),$(objdir)/$(o).o)
objlistmdf4kchro := $(foreach o,$(objlistmdf4kchr),$(objdir)/$(o).o)
objlistmdf4kautoo := $(foreach o,$(objlistmdf4kauto),$(objdir)/$(o).o)
objlistmdf4kchrautoo := $(foreach o,$(objlistmdf4kchrauto),$(objdir)/$(o).o)

map.txt $(title).nes: unrom512kbit.cfg $(objlisto) $(objdir)/unrom.o
	$(LD65) -o $(title).nes -m map.txt --dbgfile $(title).dbg -C $^
	$(FIX) $(title).nes

bnmap.txt $(title)-bnrom.nes: bnrom512kbit.cfg $(objlisto) $(objdir)/bnrom.o
	$(LD65) -o $(title)-bnrom.nes -m bnmap.txt --dbgfile $(title)-bnrom.dbg -C $^
	$(FIX) $(title)-bnrom.nes

sgmap.txt $(title)-sgrom.nes: sgrom512kbit.cfg $(objlistmmco) $(objdir)/mmc1.o
	$(LD65) -o $(title)-sgrom.nes -m sgmap.txt --dbgfile $(title)-sgrom.dbg -C $^
	$(FIX) $(title)-sgrom.nes

tgmap.txt $(title)-tgrom.nes: tgrom512kbit.cfg $(objlistmmco) $(objdir)/mmc3.o
	$(LD65) -o $(title)-tgrom.nes -m tgmap.txt --dbgfile $(title)-tgrom.dbg -C $^
	$(FIX) $(title)-tgrom.nes

mdfmap.txt mdfourier4k.nes: mdfourier4k.cfg $(objlistmdf4ko)
	$(LD65) -o mdfourier4k.nes -m mdfmap.txt \
	  --dbgfile mdfourier4k.dbg -C $^

mdfchrmap.txt mdfourier4k-chrrom.nes: mdfourier4k-chrrom.cfg $(objlistmdf4kchro)
	$(LD65) -o mdfourier4k-chrrom.nes -m mdfchrmap.txt \
	  --dbgfile mdfourier4k-chrrom.dbg -C $^

mdfourier4k-autostart.nes: mdfourier4k.cfg $(objlistmdf4kautoo)
	$(LD65) -o mdfourier4k-autostart.nes -m mdfmap.txt \
	  --dbgfile mdfourier4k-autostart.dbg -C $^

mdfourier4k-chrrom-autostart.nes: mdfourier4k-chrrom.cfg $(objlistmdf4kchrautoo)
	$(LD65) -o mdfourier4k-chrrom-autostart.nes -m mdfchrmap.txt \
	  --dbgfile mdfourier4k-chrrom-autostart.dbg -C $^

nsfmap.txt mdfourier.nsf: nsf.cfg $(objlistnsfo)
	$(LD65) -o mdfourier.nsf -m nsfmap.txt --dbgfile mdfourier.dbg -C $^

$(objdir)/%-mmc.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc $(objdir)/%.o
	$(AS65) $(CFLAGS65) $< -DUSE_MMC=1 -o $@

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%-chrrom.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -DMDF4K_CHRROM=1 -o $@

$(objdir)/%-autostart.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -DMDF4K_AUTOSTART=1 -o $@

$(objdir)/%-chrrom-autostart.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -DMDF4K_CHRROM=1 -DMDF4K_AUTOSTART=1 -o $@

$(objdir)/padsnodas.o: $(srcdir)/pads.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@ -DUSE_DAS=0 -DUSE_2P=0

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%-mmc.o: $(objdir)/%.s
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
  $(objdir)/monoscope50.iu53 $(objdir)/monoscope60.iu53 \
  $(objdir)/sharpness.iu53 $(objdir)/stopwatchface.iu53 \
  $(objdir)/gus_portrait.iu53 \
  $(objdir)/gus_sprite.chr.pb53 $(objdir)/stopwatchhand.chr.pb53 \
  $(objdir)/stdtiles.chr.pb53 $(objdir)/backlight_sprites.chr.pb53 \
  $(objdir)/kikitiles16.chr.pb53 $(objdir)/megatontiles.chr.pb53 \
  $(objdir)/overscan.chr.pb53 $(objdir)/pluge_shark_4color.chr.pb53 \
  $(objdir)/controllerimages.chr.pb53 $(objdir)/powerpad.chr.pb53 \
  $(objdir)/fizzter_digits.chr.pb53 $(objdir)/convergence.chr.pb53 \
  $(objdir)/serialanalyzer.chr.pb53 $(objdir)/arkanoidchr.chr.pb53 \
  $(objdir)/safeareas_lite.chr.pb53
$(objdir)/mdfourier4kfe-chrrom.o $(objdir)/mdfourier4kfe.o \
$(objdir)/mdfourier4kfe-chrrom-autostart.o $(objdir)/mdfourier4kfe-autostart.o: \
  $(objdir)/mdf4k_chr.chr
$(objdir)/padstest.o: $(objdir)/pads_buttons16.chr

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
$(objdir)/monoscope%.sav: $(imgdir)/monoscope%.png
	$(PY) tools/savtool.py --palette 0f2026240f2424240f2424240f242424 $< $@
$(objdir)/%.sb53: $(objdir)/%.sav
	$(PY) tools/sav2sb53.py $< $@
$(objdir)/%.pb53: $(objdir)/%
	$(PY) tools/pb53.py $< $@

# Specific rules for CHR

$(objdir)/monoscope%.iu53: $(objdir)/monoscope%.sav
	$(PY) tools/sav2iu53.py $< $@
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
$(objdir)/mdf4k_chr.chr: $(imgdir)/mdf4k_chr.png
	$(BMP2) -H 16 --planes "0" $< $@

# Help me!
$(objdir)/%.hlp.s: $(srcdir)/%.txt tools/paginate_help.py \
  ../common/tools/dtefe.py ../common/tools/dte$(DOTEXE) \
  ../common/tools/cp240p.py $(objdir)/last-commit
	$(PY) tools/paginate_help.py -DCOMMIT="$$(cat $(objdir)/last-commit)"  $< -o $@

../common/tools/dte$(DOTEXE): ../common/tools/dte.c
	$(CC) $(CFLAGS) -o $@ $^

# Print the commit tag
$(objdir)/last-commit-now:
	(git describe --tags || echo non-Git) | tr -d '\r\n' > $@
# Update last-commit only if it has changed
$(objdir)/last-commit: $(objdir)/last-commit-now
	if test -f $@; then true; else touch $@; fi
	cmp $< $@ || cp $< $@
