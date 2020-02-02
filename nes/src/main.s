;
; Dispatch for 240p test suite
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

.include "nes.inc"
.include "global.inc"
.importzp helpsect_240p_test_suite, helpsect_240p_test_suite_menu
.importzp helpsect_about

OAM = $0200

.rodata
warmbootsig: .byte 240, "pTV"
WARMBOOTSIGLEN = * - warmbootsig

.segment "ZEROPAGE"
nmis:          .res 1
oam_used:      .res 1  ; starts at 0
cur_keys:      .res 2
new_keys:      .res 2
das_keys:      .res 2
das_timer:     .res 2
tvSystem:      .res 1

.bss
; Default crt0 clears ZP but not BSS
; Currently used only by multicarts
is_warm_boot:  .res WARMBOOTSIGLEN

; Save which activity the user was in
help_last_page: .res 1
help_last_y:    .res 1


.code

.proc main
  lda #VBLANK_NMI
  sta PPUCTRL
  sta help_reload
  lda #$0F
  sta SNDCHN
  jsr getTVSystem
  sta tvSystem

  ; 1. Set triangle phase quality to good iff not a multicart
  ; 2. Check whether this was a warm boot
  ; 3. If this was a warm boot, set triangle phase quality to good
  ; 4. If triangle phase quality is good and Start is held,
  ;    skip to MDFourier
  ; 5. If Reset was pressed

  ; Check for a warm boot
  lda #INITIAL_GOOD_PHASE
  sta mdfourier_good_phase

  .if ::IS_MULTICART
    ldy #0
    ldx #WARMBOOTSIGLEN - 1
    warmbootcheckloop:
      lda warmbootsig,x
      cmp is_warm_boot,x
      sta is_warm_boot,x
      beq :+
        iny
      :
      dex
      bpl warmbootcheckloop
    ; At this point, X=$FF, and Y=0 iff warm boot.
    ; Save Y in help_last_y temporarily during boot
    sty help_last_y
    tya
    bne :+
      ; On a warm boot, phase is also good
      stx mdfourier_good_phase
    :
    ; Start to skip to MDFourier only if the triangle phase is OK
    lda mdfourier_good_phase
    beq start_not_held
  .endif

  ; Hold Start for 15 frames to go straight to MDFourier
  lda #15
  sta oam_used
  lda #VBLANK_NMI
  sta PPUCTRL
  mdfourier_skip_loop:
    jsr read_pads
    lda cur_keys+0
    and #KEY_START
    beq start_not_held
    jsr ppu_wait_vblank
    dec oam_used
    bne mdfourier_skip_loop
  ; and place the cursor there
  ldy #<mdfourier_item_id - page2start
  lda #1
  sta help_cur_page
  bne have_help_result
start_not_held:

  .if ::IS_MULTICART
    ; If this was a cold boot, it is not a double reset
    lda help_last_y
    bne not_double_reset
    ; If an activity page was selected, it is not a double reset
    lda help_last_page
    bpl not_double_reset
      jmp do_a53_exit
    not_double_reset:
    lda #$FF
    sta help_last_page
  .endif

  jsr do_credits
forever:
  ldx #helpsect_240p_test_suite_menu
  lda #KEY_A|KEY_START|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  jsr helpscreen
have_help_result:

  ; The user chose line Y of (relative) page A of the menu document
  lsr a  ; carry clear for 0 or set for 1

  ; Save position on menu to be restored even if the user views
  ; a different help page, Sound test, About, or Credits.
  lda help_cur_page
  sta help_last_page
  sty help_last_y

  ; Calculate which routine to call
  tya
  bcc :+
    adc #page2start-1
  :
  asl a
  tax

  ; Start should always open About
  lda new_keys
  and #KEY_START
  beq not_force_about
    ldx #about_item_id * 2
  not_force_about:

  jsr main_dispatch

  ; Restore position on menu
  lda help_last_y
  sta help_cursor_y
  lda help_last_page
  sta help_cur_page
  .if ::IS_MULTICART
    lda #$FF
    sta help_last_page
  .endif
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
  .addr do_new_linearity-1
  .addr do_convergence-1
  .addr do_gray_ramp-1
  .addr do_solid_color-1
  .addr do_ire-1
  .addr do_sharpness-1
  .addr do_crosstalk-1
  .addr do_overscan-1
  .addr do_overclock-1
::page2start = (* - routines)/2
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
::mdfourier_item_id = (* - routines)/2
  .addr do_mdfourier-1
::about_item_id = (* - routines)/2
  .addr do_about-1
  .addr do_credits-1
  .addr do_a53_exit-1
.popseg
.endproc

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

;;
; Exit to Action 53 menu
.proc do_a53_exit
.if ::IS_MULTICART
  lda #0
  sta PPUMASK
  sta PPUCTRL
  sta SNDCHN
  ldx #exitcode_end-exitcode
  copyloop:
    lda exitcode,x
    sta OAM,x
    dex
    bpl copyloop

  ; Write sequence:
  ; 80=02 (NROM-256), 81=FF (Last outer bank)
  ; ldx #$FF
  ldy #$80
  lda #$02
  sty $5000
  iny
  jmp OAM
exitcode:
  sta $8000
  sty $5000
  stx $8000
  jmp ($FFFC)
exitcode_end:
.else
  rts
.endif
.endproc
