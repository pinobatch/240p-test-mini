;
; Include files for NES port of 240p test suite
; Copyright 2015 Damian Yerrick
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

; init.s
.global reset_handler

; main.s
.global OAM
.global main, nmi_handler, irq_handler
.globalzp cur_keys, new_keys, das_keys, das_timer
.globalzp oam_used, nmis, tvSystem

; pads.s
.global read_pads, autorepeat

; ppuclear.s
.global ppu_clear_nt, ppu_clear_oam
.global ppu_screen_on, ppu_oam_dma_screen_on_xy0, ppu_screen_on_xy0

; helpscreen.s
.global helpscreen, help_reload, helpcheck, read_pads_helpcheck
.global txtlinebuf, vram_copydstlo, vram_copydsthi
; these are for "save your place on the main menu" functionality
.global help_cursor_y, help_cur_page

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

; vwf_draw.s
.global vwfPutTile, vwfPuts, vwfPuts0
.global vwfGlyphWidth, vwfStrWidth, vwfStrWidth0
.global clearLineImg, lineImgBuf, invertTiles
.global copyLineImg_helpscreen

; paldetect.s
.global getTVSystem

; stills.s
.global do_linearity, do_sharpness, do_ire, do_smpte, do_601bars
.global do_pluge, do_gcbars, do_cpsgrid, do_gray_ramp, do_color_bleed
.global do_full_stripes, do_solid_color, do_crosstalk
.global test_state, tvSystemFPS

; stopwatch.s
.global do_stopwatch

; backlight.s
.global do_backlight

; scrolling.s
.global do_grid_scroll, do_hill_zone_scroll
.global hill_zone_load, hill_zone_do_raster
.global hill_zone_xlo, hill_zone_xhi
.global hill_zone_speed_control
.global hill_zone_speed, hill_zone_dir, hill_zone_xlo, hill_zone_xhi

; kiki.s
.global do_vscrolltest

; soundtest.s
.global do_sound_test

; audiosync.s
.global do_audiosync

; overscan.s
.global do_overscan

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

; random.s
.globalzp CRCLO, CRCHI
.global rand_crc, crc16_update

; overclock.s
.global do_overclock

; muldiv.s
.globalzp prodlo, prodmlo, prodmhi, prodhi, fac1lo, fac1hi, fac2lo, fac2hi
.global mul16x16, div32x16

; zapper.s
.global do_zapper_test, vwfPut3Digits

.endif

