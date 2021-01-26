.ifndef GLOBAL_INC
GLOBAL_INC = 1

.globalzp tvSystem, mapper_type
TV_NTSC = 0
TV_PAL_NES = 1
TV_DENDY = 2
MAPPER_UNKNOWN = 0
MAPPER_MMC5 = 1
MAPPER_FME7 = 2
MAPPER_VRC7 = 3
MAPPER_VRC6 = 4
MAPPER_VRC6ED2 = 5
MAPPER_N163 = 6

.global nmis
.global ppu_cls, ppu_clear_linebuf, ppu_wait_vblank, ppu_screen_on
.global ppu_puts_ay, ppu_puts_0, ppu_putchar, ppu_newline
.global OAM, ppu_clear_oam






.endif
