#!/usr/bin/make -f

title := mdfourier
version := wip
defaultmapper := mmc5
allmappers := mmc5 vrc6 vrc6ed2 vrc7 fme7 n163
objlist := init main bg

objdir := obj/nes
srcdir := src
imgdir := tilesets

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

# Phony targets

.PHONY: run debug all clean dist

run: $(title)-$(defaultmapper).nes
	$(EMU) $<

debug: $(title)-$(defaultmapper).nes
	$(DEBUGEMU) $<

all: $(foreach o,$(allmappers),$(title)-$(o).nes)

clean:
	-rm $(objdir)/*.o $(objdir)/*.chr $(title).prg

dist: \
  $(foreach o,$(allmappers),$(title)-$(o).nes) $(objdir)/index.txt \
  README.md

# Pictures

$(objdir)/%16.chr: $(imgdir)/%.png
	$(PY) ../common/tools/pilbmp2nes.py $< --planes "0;1" -H16 -o $@

# Assembly

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	ca65 -o $@ $<

$(objdir)/%.o: $(objdir)/%.s
	ca65 -o $@ $<

# Includes

$(objdir)/init.o: $(objdir)/fizztersmboldmono16.chr

# Linking

$(title).prg: vrc7.x $(foreach o,$(objlist),$(objdir)/$(o).o)
	ld65 -m map.txt -o $@ -C $^

$(title)-%.nes: tools/mkines.py $(title).prg
	$(PY) $^ $* $@

# Packaging

$(objdir)/index.txt: makefile
	echo 'object files go here' > $@
