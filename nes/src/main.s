;
; Dispatch for 240p test suite
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

.include "nes.inc"
.include "global.inc"
.importzp helpsect_240p_test_suite, helpsect_240p_test_suite_menu
.importzp helpsect_about

OAM = $0200

.segment "ZEROPAGE"
nmis:          .res 1
oam_used:      .res 1  ; starts at 0
cur_keys:      .res 2
new_keys:      .res 2
das_keys:      .res 2
das_timer:     .res 2
tvSystem:      .res 1

.code

.proc main
  lda #VBLANK_NMI
  sta PPUCTRL
  sta help_reload
  lda #$0F
  sta SNDCHN
  jsr getTVSystem
  sta tvSystem
  .if 1
    jsr do_credits
  .else
    jsr do_fc_mic_test
  .endif

forever:
  ldx #helpsect_240p_test_suite_menu
  lda #KEY_A|KEY_START|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  jsr helpscreen

  ; The user chose line Y of (relative) page A of the menu document
  lsr a  ; carry clear for 0 or set for 1

  ; Save position on menu to be restored even if the user views
  ; a different help page, Sound test, About, or Credits.
  lda help_cur_page
  pha
  tya
  pha

  ; Calculate which routine to call
  bcc :+
    adc #page2start-1
  :
  asl a
  tax

  ; Start should always open About
  lda new_keys
  and #KEY_START
  beq not_force_about
    ldx #about_item * 2
  not_force_about:

  jsr main_dispatch

  ; Restore position on menu
  pla
  sta help_cursor_y
  pla
  sta help_cur_page
  jmp forever
.endproc

.proc main_dispatch
  lda routines+1,x
  pha
  lda routines,x
  pha
  rts  
.pushseg
.segment "RODATA"
routines:
  .addr do_pluge-1
  .addr do_gcbars-1
  .addr do_smpte-1
  .addr do_601bars-1
  .addr do_color_bleed-1
  .addr do_cpsgrid-1
  .addr do_linearity-1
  .addr do_gray_ramp-1
  .addr do_solid_color-1
  .addr do_ire-1
  .addr do_sharpness-1
  .addr do_crosstalk-1
  .addr do_overclock-1
::page2start = (* - routines)/2
  .addr do_overscan-1
  .addr do_drop_shadow_sprite-1
  .addr do_stopwatch-1
  .addr do_manual_lag-1
  .addr do_hill_zone_scroll-1
  .addr do_vscrolltest-1
  .addr do_grid_scroll-1
  .addr do_full_stripes-1
  .addr do_backlight-1
  .addr do_zapper_test-1
  .addr do_sound_test-1
  .addr do_audiosync-1
::about_item = (* - routines)/2
  .addr do_about-1
  .addr do_credits-1
.popseg
.endproc

.if 0
.proc beep
  ; Demo of tone (for SMPTE bars and tone)
  ; frequency on NTSC NES is very nearly 1000 Hz
  lda #$88
  sta $4008
  lda #55  ; FIXME: change this for PAL NES and Dendy
  sta $400A
  lda #0
  sta $400B
  ldx #20
delayloop:
  lda nmis
:
  cmp nmis
  beq :-
  dex
  bne delayloop
  lda #$00
  sta $4008
  sta $400B
  rts
.endproc
.endif

.proc do_credits
  ldx #helpsect_240p_test_suite
  lda #KEY_LEFT|KEY_RIGHT|KEY_B|KEY_A|KEY_START
  jmp helpscreen
.endproc

.proc do_about
  ldx #helpsect_about
  lda #KEY_LEFT|KEY_RIGHT|KEY_B|KEY_A|KEY_START
  jmp helpscreen
.endproc
