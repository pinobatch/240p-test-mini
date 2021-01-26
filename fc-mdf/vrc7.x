#
# Linker script for MDFourier Expansions
# Copyright 2010, 2021 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
MEMORY {
  ZP:       start = $10, size = $f0, type = rw;
  # use first $10 zeropage locations as locals
  RAM:      start = $0300, size = $0500, type = rw;

  # Skipping the header because it varies
  ROM80:    start = $8000, size = $2000, type = ro, file = %O, fill=yes, fillval=$FF;
  ROMA0:    start = $A000, size = $2000, type = ro, file = %O, fill=yes, fillval=$FF;
  ROMC0:    start = $C000, size = $2000, type = ro, file = %O, fill=yes, fillval=$FF;
  ROME0:    start = $E000, size = $2000, type = ro, file = %O, fill=yes, fillval=$FF;
}

SEGMENTS {
  ZEROPAGE:   load = ZP, type = zp;
  BSS:        load = RAM, type = bss, define = yes, align = $100;
  # To support both CHR ROM and CHR RAM boards, the test contains
  # the exact same data in both PRG ROM and CHR ROM.  On CHR RAM
  # boards, init code copies the first 8K of PRG ROM to CHR RAM.
  CHR:        load = ROM80, type = ro, align = $10;
  RODATA:     load = ROMA0, type = ro, align = $10;
  CODE:       load = ROMC0, type = ro, align = $10;
  INITDATA:   load = ROME0, type = ro, align = $100, optional=yes;
  LOWCODE:    load = ROME0, type = ro, align = $10;
  VECTORS:    load = ROME0, type = ro, start = $FFFA;
}

FILES {
  %O: format = bin;
}

