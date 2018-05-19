# Replace default rules with devkitARM default rules

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif
.SUFFIXES:
include $(DEVKITARM)/gba_rules

#--------------------------------------------------------------------
# TARGET is the filename of the executable; if it ends with _mb
#   then it can run in RAM
# VERSION is the suffix added after TARGET in the zipfile name
# OBJS is the notdir basename of each .o file, which usually matches
# that of the corresponding .c or .png file
# BUILD is the directory in which to place object files and other
#   intermediate files
# SOURCES is the primary source code directory
# LIBDIRS is a list of directories that have include/*.h and
#   lib/lib*.a files
#
# All directories are specified relative to the project directory
# where the makefile is found
#
#--------------------------------------------------------------------
TARGET := 240pee_mb
VERSION := wip
OBJS := \
  main help \
  placeholder stills overscan scrolltest \
  shadowsprite stopwatch soundtest audiosync backlight megaton \
  ppuclear vwfdraw undte rand \
  bggfx_chr spritegfx_chr vwf7
LIBS := -lgba

BUILD		:= obj/gba
SOURCES		:= src
LIBDIRS     := $(LIBGBA)

#--------------------------------------------------------------------
# some calculations
#--------------------------------------------------------------------
export INCLUDE := \
  $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
  -I$(CURDIR)/$(BUILD)
export LIBPATHS	:= \
  $(foreach dir,$(LIBDIRS),-L$(dir)/lib)
export OFILES := \
  $(foreach o,$(OBJS),$(BUILD)/$(o).o)

#--------------------------------------------------------------------
# programs and options for code generation
#--------------------------------------------------------------------

ARCH := -mthumb -mthumb-interwork
CFLAGS := \
  -g -Wall -O3 -fomit-frame-pointer -ffast-math \
  -mcpu=arm7tdmi -mtune=arm7tdmi $(ARCH)
CFLAGS += $(INCLUDE)
ASFLAGS	:=	-g $(ARCH)
LD	:=	$(CC)
LDFLAGS	:=	-g $(ARCH) -Wl,-Map,$(notdir $*.map)

# Grit comes from GritHub, https://github.com/devkitPro/grit
GRIT := $(DEVKITARM)/bin/grit
PY := py -3
EMU := start

# targets begin
.PHONY: run all clean dist zip
run: $(TARGET).gba
	$(EMU) $<
all: $(TARGET).gba

# Compiling and linking

$(TARGET).elf: $(OFILES)

$(BUILD)/%.o: $(SOURCES)/%.c $(SOURCES)/global.h
	$(CC) $(CFLAGS) -g -c $< -o $@

$(BUILD)/%.o: $(BUILD)/%.s
	$(AS) $< -o $@

# Image conversion

$(BUILD)/bggfx_chr.s: tilesets/bggfx.png
	$(GRIT) $< -gB4 -p! -o $(basename $@)
$(BUILD)/decade_chr.s: tilesets/decade.png
	$(GRIT) $< -gB4 -p! -o $(basename $@)
$(BUILD)/spritegfx_chr.s: tilesets/spritegfx.png
	$(GRIT) $< -gB4 -Mw2 -Mh3 -pn16 -o $(basename $@)
$(BUILD)/helpbgtiles_chr.s: tilesets/helpbgtiles.png
	$(GRIT) $< -gB4 -Mw2 -Mh3 -pn16 -o $(basename $@)
$(BUILD)/helpsprites_chr.s: tilesets/helpsprites.png
	$(GRIT) $< -gB4 -Mw2 -Mh3 -pn16 -o $(basename $@)
$(BUILD)/vwf7.s: tools/vwfbuild.py tilesets/vwf7.png
	$(PY) $^ $@
$(BUILD)/%_chr.h: $(BUILD)/%_chr.s
	touch $@

# Packaging

clean:
	-rm $(BUILD)/*.o $(BUILD)/*.s $(BUILD)/*.h $(TARGET).elf
dist: zip
zip: $(TARGET)-$(VERSION).zip
$(TARGET)-$(VERSION).zip: zip.in \
  README.md $(BUILD)/index.txt $(TARGET).gba
	zip -9 -u $@ -@ < $<
$(BUILD)/index.txt: makefile
	echo Files produced by build tools go here, but caulk goes where? > $@
