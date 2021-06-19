#!/usr/bin/make -f
#
# Makefile for 240p test suite outer packaging
# Copyright 2020 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
title := 240p-test-mini
version := 0.23wip

# Make $(MAKE) work correctly even when Make is installed inside
# C:\Program Files
ifneq ($(words $(MAKE)), 1)
MAKE:="$(MAKE)"
endif

alltargets:=\
  nes/240pee.nes nes/240pee-bnrom.nes nes/mdfourier.nsf \
  gameboy/gb240p.gb gba/240pee_mb.gba

.PHONY: all dist clean $(alltargets)
all: $(alltargets)
dist: $(title)-docsrc-$(version).zip $(title)-$(version).zip

# Try to minimize the harm of recursive make.
# 240pee-bnrom.nes depends on 240pee.nes so that parallel make (-j2)
# doesn't try double-building compiling each file in both
nes/240pee.nes:
	$(MAKE) -C nes $(notdir $@)
nes/240pee-bnrom.nes: nes/240pee.nes
	$(MAKE) -C nes $(notdir $@)
nes/mdfourier.nsf: nes/240pee.nes
	$(MAKE) -C nes $(notdir $@)
gameboy/gb240p.gb:
	$(MAKE) -C gameboy $(notdir $@)
gba/240pee_mb.gba:
	$(MAKE) -C gba $(notdir $@)

# Packaging
DOCSRC_RE:=\.xcf$$|\.odg$$|/Gus_sketch_by_.*.png

$(title)-$(version).zip: zip.in all makefile README.md
	zip -9 -u $@ -@ < $<

$(title)-docsrc-$(version).zip: docsrc.zip.in makefile
	zip -9 -u $@ -@ < $<

zip.in: makefile nes/makefile gameboy/makefile gba/Makefile
	git ls-files | egrep -iv "^\.|$(DOCSRC_RE)" > $@
	echo nes/240pee.nes >> $@
	echo nes/240pee-bnrom.nes >> $@
	echo nes/mdfourier.nsf >> $@
	echo gameboy/gb240p.gb >> $@
	echo gba/240pee_mb.gba >> $@
	echo $@ >> $@

docsrc.zip.in: makefile nes/makefile gameboy/makefile gba/Makefile
	git ls-files | egrep "$(DOCSRC_RE)" > $@
	echo LICENSE >> $@
	echo $@ >> $@

clean:
	$(MAKE) -C nes clean
	$(MAKE) -C gameboy clean
	$(MAKE) -C gba clean
