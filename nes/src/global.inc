;
; Include files for NES port of 240p test suite
; Copyright 2015-2017 Damian Yerrick
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;

.ifndef GLOBAL_INC
.define GLOBAL_INC

IS_MULTICART = 0

; init.s
.global reset_handler
.global rtl
.global mmc_bank_a

; main.s
.global OAM
.global main, nmi_handler, irq_handler
.globalzp cur_keys, new_keys, das_keys, das_timer
.globalzp oam_used, nmis, tvSystem

; pads.s
.global read_pads, autorepeat

; ppuclear.s
.global ppu_clear_nt, ppu_clear_oam, ppu_wait_vblank
.global ppu_screen_on, ppu_oam_dma_screen_on_xy0, ppu_screen_on_xy0

; help.s
HELP_LINE_LEN = 40
.global helpscreen, helpscreen_abslr, do_credits, do_about
.global helpcheck, read_pads_helpcheck, flashing_consent
.globalzp help_reload
.globalzp vram_copydstlo, vram_copydsthi
.global help_line_buffer
; these are for "save your place on the main menu" functionality
.globalzp help_cursor_y, help_cur_page

; undte.s
.global undte_line, undte_line0

; unpb53.s
.global unpb53_gate, PB53_outbuf
.global unpb53_file, load_sb53_file
.globalzp ciSrc, ciDst, ciBufStart, ciBufEnd

; PB53 data used directly with unpb53_gate must be in GATEDATA.
; This way, both the UNROM and BNROM versions can see it.
; UNROM decompresses from the current bank.
; BNROM can decompress only from physical bank 0, and the code is
; running in physical bank 1.  So changing to bank 1 is a no-op, but
; the correct physical bank still gets used.
GATEDATA_BANK = 1

; uniu.c
.global load_iu53_file

; vwf_draw.s
.global vwfPutTile, vwfPuts, vwfPuts0
.global vwfGlyphWidth, vwfStrWidth, vwfStrWidth0
.global clearLineImg, lineImgBuf, invertTiles
.global copyLineImg_helpscreen

; paldetect.s
.global getTVSystem

; stills.s
.global do_monoscope, do_sharpness, do_ire, do_smpte, do_601bars
.global do_pluge, do_gcbars, do_gray_ramp, do_color_bleed
.global do_full_stripes, do_solid_color, do_crosstalk, do_convergence
.global tvSystemFPS
SIZEOF_TEST_STATE = 24
.globalzp test_state

; linearity.s
.global do_new_linearity

; stopwatch.s
.global do_stopwatch

; backlight.s
.global do_backlight

; scrolling.s
.global do_grid_scroll, do_hill_zone_scroll
.global hill_zone_load, hill_zone_do_raster
.global hill_zone_speed_control
.globalzp hill_zone_speed, hill_zone_dir, hill_zone_xlo, hill_zone_xhi

; kiki.s
.global do_vscrolltest

; soundtest.s
.global do_sound_test

; audiosync.s
.global do_audiosync

; overscan.s
.global do_overscan, do_safearea

; megaton.s
.global do_manual_lag

; semixparent.s
.global do_drop_shadow_sprite, draw_spriterect
sprect_y = $00
sprect_tilenum = $01
sprect_attr = $02
sprect_x = $03
sprect_w = $04
sprect_h = $05
sprect_tileadd = $06

; bcd.s
.global bcd8bit
bcd_highdigits = $0000
.global bcdConvert24, bcdWrite
.globalzp bcdNum, bcdResult

; rand.s
.global _srand, _rand

; overclock.s
.global do_overclock

; muldiv.s
.globalzp prodlo, prodmlo, prodmhi, prodhi, fac1lo, fac1hi, fac2lo, fac2hi
.global mul16x16, div32x16

; padstest.s
.global do_input_test

; zapper.s
.global do_zapper_test, vwfPut3Digits

; mdfourierfe.s and mdfourier.s
.global do_mdfourier, mdfourier_present
.global mdfourier_init_apu, mdfourier_run, mdfourier_ready_tone
.global mdfourier_push_apu
.global mdfourier_good_phase
INITIAL_GOOD_PHASE = (IS_MULTICART = 0)

; ntscPeriods.s
.global periodTableLo, periodTableHi

.endif

