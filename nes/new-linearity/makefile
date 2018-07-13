#!/usr/bin/make -f
# Experimental makefile for linearity tilemap compression experiment

title = new-linearity
version = wip

objlist := nrom init main ppuclear unpb53 uniu
AS65 = ca65
LD65 = ld65
CFLAGS65 = 
objdir = obj/nes
srcdir = src
imgdir = ../tilesets
cimgdir = ../../common/tilesets

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

.PHONY: run debug dist zip all clean

run: $(title).nes
	$(EMU) $<
debug: $(title).nes
	$(DEBUGEMU) $<

# Rule to create or update the distribution zipfile
dist: zip
zip: $(title)-$(version).zip
$(title)-$(version).zip: zip.in all \
  making-carts.md $(objdir)/index.txt
	zip -9 -u $@ -@ < $<
	-advzip -z3 $@

all: $(title).nes

$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here, but caulk goes where?" > $@

clean:
	-rm $(objdir)/*.o $(objdir)/*.s $(objdir)/*.chr $(objdir)/*.iu53
	-rm $(objdir)/*.sav map.txt

# Rules for PRG ROM

objlisto = $(foreach o,$(objlist),$(objdir)/$(o).o)

map.txt $(title).nes: nrom128.cfg $(objlisto)
	$(LD65) -o $(title).nes -m map.txt -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

# included things

$(objdir)/main.o: $(objdir)/linearity_ntsc.iu53 $(objdir)/linearity_pal.iu53

# graphics rules

$(objdir)/linearity_ntsc.iu53: $(objdir)/linearity_ntscgray.sav
	$(PY) ../tools/sav2iu53.py --x-grid 0,1,2,3,4,5,6 $< $@

$(objdir)/linearity_pal.iu53: $(objdir)/linearity_palgray.sav
	$(PY) ../tools/sav2iu53.py --y-grid 8,2,5,8,0,3,6,8,1,4,7 $< $@

$(objdir)/%gray.sav: $(imgdir)/%.png
	$(PY) ../tools/savtool.py --palette 0f0010200f1616160f1616160f161616 $< $@
