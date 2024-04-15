#!/usr/bin/make -f

title := mdfourier
version := wip
defaultmapper := mmc5
allmappers := mmc5 vrc6 vrc6ed2 vrc7 fme7 n163
objlist := init main bg
objlistnsf := mdfouriernsf mdfourier ntscPeriods
objlistnsffds := mdfourierfdsnsf mdfourierfds ntscPeriods ntscFDSPeriods
objlistmdffds4kfdsh := mdfourier4kfe-fdsheader mdfourierfds-fdsheader padsnodas-fdsheader ntscPeriods-fdsheader ntscFDSPeriods-fdsheader

AS65:=ca65
LD65:=ld65
CFLAGS65:=-g
LFLAGS65:=-v
objdir := obj/nes
srcdir := src
extdir := ../nes
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

objlistnsfo := $(foreach o,$(objlistnsf),$(objdir)/$(o).o)
objlistnsffdso := $(foreach o,$(objlistnsffds),$(objdir)/$(o).o)
objlistmdffds4kfdsho := $(foreach o,$(objlistmdffds4kfdsh),$(objdir)/$(o).o)

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

$(objdir)/mdf4k_chr.chr: $(imgdir)/mdf4k_chr.png
	$(PY) ../common/tools/pilbmp2nes.py -H 16 --planes "0" $< $@

# source files

# MDFourier needs the period lookup table
$(objdir)/ntscPeriods.s: $(extdir)/tools/mktables.py
	$(PY) $< period $@

$(objdir)/ntscFDSPeriods.s: $(extdir)/tools/mktables.py
	$(PY) $< fdsperiod $@

$(objdir)/ntscPeriods-fdsheader.s: $(extdir)/tools/mktables.py
	$(PY) $< periodfdsc $@

$(objdir)/ntscFDSPeriods-fdsheader.s: $(extdir)/tools/mktables.py
	$(PY) $< fdsperiodfdsc $@

$(objdir)/mdfourier4k-fdsheader.cfg: $(extdir)/mdfourier4k-fdsheader.cfg
	cp $^ $@

$(objdir)/%-fdsheader.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -DFDSHEADER=1 -o $@

$(objdir)/padsnodas.s: $(extdir)/$(srcdir)/padsnodas.s
	cp $^ $@

$(objdir)/padsnodas-fdsheader.o: $(extdir)/$(srcdir)/pads.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) $< -o $@ -DUSE_DAS=0 -DUSE_2P=0 -DFDSHEADER=1

# Includes

$(objdir)/init.o: $(objdir)/fizztersmboldmono16.chr

$(objdir)/mdfourier.o: $(objdir)/instsamp1.dmc
$(objdir)/instsamp1.dmc: $(extdir)/audio/instsamp1.dmc
	cp $^ $@

$(objdir)/mdfourier4kfe-chrrom.o $(objdir)/mdfourier4kfe.o $(objdir)/mdfourier4kfe-fdsheader.o: \
  $(objdir)/mdf4k_chr.chr

# Linking

$(title).prg: vrc7.x $(foreach o,$(objlist),$(objdir)/$(o).o)
	ld65 -m map.txt -o $@ -C $^

$(title)-%.nes: tools/mkines.py $(title).prg
	$(PY) $^ $* $@

mdf_nsf_map.txt mdfourier.nsf: $(extdir)/nsf.cfg $(objlistnsfo)
	$(LD65) $(LFLAGS65) -o $(objdir)/mdfourier -m mdf_nsf_map.txt --dbgfile mdfourier.dbg -C $^
	cat $(objdir)/mdfourier_header $(objdir)/mdfourier > mdfourier.nsf

mdf_fds_nsf_map.txt mdfourier_fds.nsf: fds_nsf.cfg $(objlistnsffdso)
	$(LD65) $(LFLAGS65) -o $(objdir)/mdfourier_fds -m mdf_fds_nsf_map.txt --dbgfile mdfourier_fds.dbg -C $^
	cat $(objdir)/mdfourier_fds_header $(objdir)/mdfourier_fds > mdfourier_fds.nsf

mdf_fds_fdsh_map.txt mdfourier4k_fds-fdsheader.fds: $(objdir)/mdfourier4k-fdsheader.cfg $(objlistmdffds4kfdsho)
	$(LD65) $(LFLAGS65) -o mdfourier4k-fdsheader.fds -m mdffdshmap.txt \
	  --dbgfile mdfourier4k-fdsheader.dbg -C $^

# Assembly

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/global.inc
	$(AS65) $(CFLAGS65) -o $@ $<

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) -o $@ $<

# Packaging

$(objdir)/index.txt: makefile
	echo 'object files go here' > $@
