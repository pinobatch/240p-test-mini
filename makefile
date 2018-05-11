title := 240p-test-mini
version := 0.16

# Make $(MAKE) work correctly even when Make is installed inside
# C:\Program Files
ifneq ($(words $(MAKE)), 1)
MAKE:="$(MAKE)"
endif

alltargets:=\
  nes/240pee.nes nes/240pee-bnrom.nes gameboy/gb240p.gb

.PHONY: all dist zip clean $(alltargets)
all: $(alltargets)
dist: zip
zip: $(title)-$(version).zip

# 240pee-bnrom.nes depends on 240pee.nes so that parallel make (-j2)
# doesn't try double-building compiling each file in both
nes/240pee.nes:
	$(MAKE) -C nes $(notdir $@)
nes/240pee-bnrom.nes: nes/240pee.nes
	$(MAKE) -C nes $(notdir $@)
gameboy/gb240p.gb:
	$(MAKE) -C gameboy $(notdir $@)

# Packaging
$(title)-$(version).zip: zip.in all makefile README.md
	zip -9 -u $@ -@ < $<

zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo nes/240pee.nes >> $@
	echo nes/240pee-bnrom.nes >> $@
	echo gameboy/gb240p.gb >> $@
	echo $@ >> $@

clean:
	$(MAKE) -C nes clean
	$(MAKE) -C gameboy clean 