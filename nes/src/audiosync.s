;
; Audio sync test for 240p test suite
; Copyright 2016 Damian Yerrick
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
.importzp helpsect_audio_sync_test
.importzp RF_audiosync

.rodata

audiosync_palthresholds:
  .byte 120, 0, 120, 40, 120, 60, 80, 100
NUMPALTHRESHOLDS = * - audiosync_palthresholds

.segment "CODE02"
.proc do_audiosync
progress = test_state+0
calculated_palette = test_state+2

  jsr rf_load_tiles
  lda #RF_audiosync
  jsr rf_load_layout
  lda #$80  ; bit 7: paused
  sta progress

  ; load initial palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldy #$20
  lda #$0F
  :
    sta PPUDATA
    eor #$2F
    dey
    bne :-

  ; set sprite coords other than Y
  lda #$0E
  sta OAM+1
  lda #$00
  sta OAM+2
  lda #127
  sta OAM+3
  ldx #4
  jsr ppu_clear_oam
  
  ; Set up audio output
  lda #$0F
  sta SNDCHN
  lda #8
  sta $4001  ; disable sweep
  lda #$B0
  sta $4000  ; volume=0
  lda #111
  sta $4002  ; 1000 Hz
  lda #$00
  sta $4003

loop:
  lda #helpsect_audio_sync_test
  jsr read_pads_helpcheck
  bcc :+
    jmp do_audiosync
  :
  
  ; Start and stop the dot  
  lda new_keys+0
  bpl notA
    lda progress
    eor #$80
    bmi :+
      lda #0
    :
    cmp #120|$80
    bcc :+
      lda #119|$80
    :
    sta progress
  notA:

  ; Move the dot if not paused
  lda progress
  bmi :+
    inc progress
    lda progress
    cmp #122
    bcc :+
    lda #0
    sta progress
  :

  ; Calculate the palette
  lda progress
  bpl :+
    lda #0
  :
  tay
  ldx #NUMPALTHRESHOLDS-1
  palcalcloop:
    tya
    cmp audiosync_palthresholds,x
    lda #$0F
    bcc :+
      lda #$20
    :
    sta calculated_palette,x
    dex
    bpl palcalcloop
  
  ; Draw the dot
  lda progress
  and #$7F
  cmp #60
  bcs :+
    eor #$FF
    adc #120
  :
  adc #(192-120)-2
  sta OAM+0

  jsr ppu_wait_vblank

  ; set palette
  lda #$3F
  sta PPUADDR
  ldx #$00
  stx PPUADDR
  progress_palloop:
    lda calculated_palette,x
    sta PPUDATA
    inx
    cpx #NUMPALTHRESHOLDS
    bcc progress_palloop
  
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  jsr ppu_oam_dma_screen_on_xy0

  ; Set beeper volume
  lda progress
  bpl :+
    lda #0
  :
  cmp #120
  lda #$B0
  bcc :+
    lda #$BC
  :
  sta $4000
  
  lda new_keys
  and #KEY_B
  bne done
  jmp loop
done:
  lda #$B0
  sta $4000
  rts
.endproc
