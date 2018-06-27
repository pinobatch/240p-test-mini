;
; Sound test for 240p test suite
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
.include "rectfill.inc"
.importzp helpsect_sound_test_frequency, helpsect_sound_test
.import crowd

; Assuming time constant is 56000 Hz for NTSC and 52000 Hz for PAL
; (actual values are 55930.4 Hz and 51956.5 Hz respectively)

.segment "RODATA"
tonefreqs_lo:
  ; NTSC
  .repeat 9, I
    .byte <((7 << I) - 1)
  .endrepeat
  ; PAL
  .byte 6
  .repeat 8, I
    .byte <((13 << I) - 1)
  .endrepeat
tonefreqs_hi:
  ; NTSC
  .repeat 9, I
    .byte >((7 << I) - 1)
  .endrepeat
  ; PAL
  .byte 0
  .repeat 8, I
    .byte >((13 << I) - 1)
  .endrepeat

; PAL NES and Dendy swap the red and green emphasis bits
tvSystem_redtint:
  .byte LIGHTGRAY|BG_ON|OBJ_ON|TINT_R
  .byte LIGHTGRAY|BG_ON|OBJ_ON|TINT_G
  .byte LIGHTGRAY|BG_ON|OBJ_ON|TINT_G

.segment "CODE"

.proc do_sound_test
  ldx #helpsect_sound_test_frequency
  lda #KEY_A|KEY_B|KEY_START|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
  jsr helpscreen
  lda new_keys+0
  and #KEY_A
  beq not_beep
    cpy #12
    bcc not_crowd
    jmp do_crowd
  not_crowd:
    cpy #9
    beq is_pulse_beep
    bcc istribeep
    jsr noise_beep
    jmp do_sound_test
  is_pulse_beep:
    jsr pulse_beep
    jmp do_sound_test
  istribeep:
    jsr beep_octave_y
    jmp do_sound_test
  not_beep:
  
  lda #helpsect_sound_test
  jsr helpcheck
  bcs do_sound_test
  lda new_keys+0
  and #KEY_B
  bne done
  jmp do_sound_test
done:
  rts
.endproc

.proc beep_octave_y
  ; Demo of tone (for SMPTE bars and tone)
  lda #$88
  sta $4008
  jsr octave_y_to_xa
  sta $400A
  stx $400B
  jsr beepdelay
  lda #$00
  sta $4008
  lda #$FF
  sta $400B
  rts
.endproc

.proc pulse_beep
  ; Demo of tone (for SMPTE bars and tone)
  ; frequency on NTSC NES is very nearly 1000 Hz
  lda #$B8
  sta $4000
  lda #$08
  sta $4001
  ldy #4
  jsr octave_y_to_xa
  sta $4002
  stx $4003
  jsr beepdelay
  lda #$B0
  sta $4000
  rts
.endproc

.proc noise_beep
  tya
  lsr a
  lda #$05 << 1
  ror a
  sta $400E
  ldx #$B8
  stx $400C
  lda #0
  sta $400F
  jsr beepdelay
  lda #$B0
  sta $400C
  rts
.endproc

.proc beepdelay
  ldx #20
  ldy tvSystem
delayloop:
  lda nmis
:
  cmp nmis
  beq :-
  lda tvSystem_redtint,y
  sta PPUMASK
  dex
  bne delayloop
  rts
.endproc

;;
; @param Y octave number (0=highest, 8=lowest)
; @param tvSystem bit 0 clear for NTSC/Dendy or set for PAL NES
; @return period-1 value with high byte in X and low byte in Y
.proc octave_y_to_xa
  lda tvSystem
  lsr a  ; Sets carry iff PAL NES
  bcc :+
    tya
    clc
    adc #9
    tay
  :
  lda tonefreqs_lo,y
  ldx tonefreqs_hi,y
  rts
.endproc

; Crowd title by Damian Yerrick

.rodata
crowd_labels:
  rf_label  80, 96, 3, 0
  .byte 34,"Crowd",34," by Kragen",0
  rf_label  80,112, 3, 0
  .byte "Ported to NES",0
  rf_label  80,120, 3, 0
  .byte "by rainwarrior",0
  rf_label  80,144, 3, 0
  .byte "Reset: exit",0
  .byte $00

.code
do_crowd:
  jsr rf_load_tiles
  jsr rf_load_yrgb_palette
  ldx #$20
  stx rf_curnametable
  stx rf_tilenum
  lda #$00
  sta rf_curpattable
  tay
  jsr ppu_clear_nt
  ldy #<crowd_labels
  lda #>crowd_labels
  sty ciSrc
  sta ciSrc+1
  jsr rf_draw_labels
  lda #0
  tay
  tax
  clc
  jsr ppu_screen_on
  jmp crowd
