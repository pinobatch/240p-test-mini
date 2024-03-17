#!make -f
#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

include $(DEVKITARM)/gba_rules

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# INCLUDES is a list of directories containing extra header files
# DATA is a list of directories containing binary data
# GRAPHICS is a list of directories containing files to be processed by grit
#
# All directories are specified relative to the project directory where
# the makefile is found
#
#---------------------------------------------------------------------------------
TARGET		:= 240pee_mb
BUILD		:= build
SOURCES		:= src
INCLUDES	:=
DATA		:=
MUSIC		:=
GRAPHICS	:= tilesets ../common/tilesets

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
DEFINES := -D__GBA__
ARCH	:=	-mthumb -mthumb-interwork

CFLAGS	:=	-g -Wall -O2 -fno-common\
		-mcpu=arm7tdmi -mtune=arm7tdmi\
		$(ARCH) $(DEFINES)

CFLAGS	+=	$(INCLUDE)

CXXFLAGS	:=	$(CFLAGS) -fno-rtti -fno-exceptions

ASFLAGS	:=	-g $(ARCH) $(DEFINES) -x assembler-with-cpp
LDFLAGS	=	-g $(ARCH) -Wl,-Map,$(notdir $*.map)

#---------------------------------------------------------------------------------
# any extra libraries we wish to link with the project
#---------------------------------------------------------------------------------
LIBS	:= -lgba


#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:=	$(LIBGBA)

#---------------------------------------------------------------------------------
# Python executable name depends on operating system.
# COMSPEC is present on Windows, not UNIX
#---------------------------------------------------------------------------------
ifdef COMSPEC
  PY := py -3
else
  PY := python3
endif

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------


ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
			$(foreach dir,$(DATA),$(CURDIR)/$(dir)) \
			$(foreach dir,$(GRAPHICS),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)

CFILES		:=	\
  main.c help.c \
  placeholder.c stills.c overscan.c scrolltest.c motionblur.c \
  shadowsprite.c stopwatch.c soundtest.c audiosync.c backlight.c megaton.c \
  pads.c ppuclear.c vwfdraw.c vwflabels.c undte.c rand.c 4bcanvas.c
CPPFILES	:=
S_H_SFILES	:=	\
  bggfx_chr.s spritegfx_chr.s monoscope_chr.s sharpness_chr.s \
  stopwatchface_chr.s stopwatchhand_chr.s stopwatchdigits_chr.s \
  kikimap_chr.s kikitiles_chr.s greenhillzone_chr.s hepsie_chr.s \
  Gus_portrait_chr.s convergence_chr.s pluge_shark_6color_chr.s \
  helpbgtiles_chr.s helpsprites_chr.s Donna_chr.s vwf7.s helppages.s
SFILES := 
CSFILES := posprintf.cS

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
#---------------------------------------------------------------------------------
	export LD	:=	$(CC)
#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
	export LD	:=	$(CXX)
#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

export OFILES_BIN := $(addsuffix .o,$(BINFILES))

export OFILES_SOURCES := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(CSFILES:.cS=.o) $(SFILES:.s=.o) $(S_H_SFILES:.s=.o)

export OFILES := $(OFILES_BIN) $(OFILES_SOURCES)

export HFILES := $(addsuffix .h,$(subst .,_,$(BINFILES))) $(subst .s,.h,$(S_H_SFILES))

export INCLUDE	:=	$(foreach dir,$(INCLUDES),-iquote $(CURDIR)/$(dir)) \
					$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
					-I$(CURDIR)/$(BUILD)

export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

.PHONY: $(BUILD) clean

#---------------------------------------------------------------------------------
# This sets up the dependencies for the first build if the user runs
#     make 240pee_mb.gba
# instead of running
#     make
#---------------------------------------------------------------------------------
$(TARGET).gba $(TARGET).elf: $(BUILD)
	echo hello...

#---------------------------------------------------------------------------------
$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).gba


#---------------------------------------------------------------------------------
else

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------

$(OUTPUT).gba	:	$(OUTPUT).elf

$(OUTPUT).elf	:	$(OFILES)

$(OFILES_SOURCES) : $(HFILES)

#---------------------------------------------------------------------------------
# This rule creates assembly source files using grit
# grit takes an image file and a .grit describing how the file is to be processed
# add additional rules like this for each image extension
# you use in the graphics folders 
#---------------------------------------------------------------------------------
%_chr.s %_chr.h	: %.png %.grit
#---------------------------------------------------------------------------------
	grit $< -ff$(word 2,$^) -fts -o$*_chr

# Convert a proportional font
vwf7.s vwf7.h: vwf7_cp144p.png ../tools/vwfbuild.py last-commit
	$(PY) ../tools/vwfbuild.py $< $(basename $@).s $(basename $@).h

# Update last-commit if it has changed
last-commit-now:
	git describe --tags | tr -d '\r\n' > $@
last-commit: last-commit-now
	if test -f $@; then true; else touch $@; fi
	cmp $< $@ || cp $< $@

# Convert help files
helppages.s helppages.h: helppages.txt last-commit ../tools/paginate_help.py 
	$(PY) ../tools/paginate_help.py -DCOMMIT="$$(cat last-commit)" $< -o $(basename $@).s -oh $(basename $@).h

# Compile cS file to o
%.o: %.cS
	$(CC) $(ASFLAGS) -c -o $@ $<

-include $(DEPSDIR)/*.d
#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
