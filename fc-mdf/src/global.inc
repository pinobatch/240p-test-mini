.ifndef GLOBAL_INC
GLOBAL_INC = 1

.globalzp tvSystem, mapper_type, nmis, mdfourier_addrdata
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

.global ppu_cls, ppu_clear_linebuf, ppu_wait_vblank, ppu_screen_on
.global ppu_puts_ay, ppu_puts_0, ppu_putchar, ppu_newline
.global OAM, ppu_clear_oam

IS_MULTICART = 0

; main.s
.global OAM
.global main, nmi_handler, irq_handler
.globalzp cur_keys, new_keys, das_keys, das_timer
.globalzp oam_used, nmis, tvSystem

; mdfourierfe.s and mdfourier.s
.global do_mdfourier, mdfourier_present
.global mdfourier_init_apu, mdfourier_run, mdfourier_ready_tone
.global mdfourier_push_apu
.global mdfourier_good_phase
.globalzp test_state
SIZEOF_TEST_STATE = 24
FDS_OFFSET = (.defined(FDSHEADER) = 1) * 4
; due to FDS BIOS using the triangle, the phase is trash on cold boot
INITIAL_GOOD_PHASE = (IS_MULTICART = 0) && (.defined(FDSHEADER) = 0)

; ntscPeriods.s
.global periodTableLo, periodTableHi

; ntscFDSPeriods.s
.global fdsPeriodTableLo, fdsPeriodTableHi

; pads.s
.global read_pads, autorepeat






.endif
