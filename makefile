title := 240p-test-mini
version := 0.16

.PHONY: all dist zip clean
all: nes/240pee.nes nes/240pee-bnrom.nes gameboy/gb240p.gb
dist: zip
zip: $(title)-$(version).zip

# Recursive makes
nes/240pee.nes:
	cd nes && $(MAKE) 240pee.nes
nes/240pee-bnrom.nes:
	cd nes && $(MAKE) 240pee-bnrom.nes
gameboy/gb240p.gb:
	cd gameboy && $(MAKE) gb240p.gb

# Packaging
$(title)-$(version).zip: zip.in all makefile README.md
	zip -9 -u $@ -@ < $<

zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo nes/240pee.nes >> $@
	echo nes/240pee-bnrom.nes >> $@
	echo gameboy/gb240p.gb >> $@
	echo $@ >> $@

