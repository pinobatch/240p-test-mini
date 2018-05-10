;
; Stopwatch test for 240p test suite
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
.include "rectfill.inc"

.importzp helpsect_stopwatch

sw_hours = test_state+0
sw_minutes = test_state+1
sw_seconds = test_state+2
sw_frames = test_state+3
sw_framescolor = test_state+4
; 7: update; 6: count. 00: lap+stop, 40: lap+run; 80: stop; c0: run
sw_running = test_state+5
sw_hide_ruler = test_state+6
sw_inactive_color = test_state+7  ; $26 or $20
sw_framestens = test_state+14
sw_framesones = test_state+15

.rodata
stopwatch_labels:
  rf_label  56, 40, 2, 0
  .byte "hours",0
  rf_label  96, 40, 2, 0
  .byte "minutes",0
  rf_label 136, 40, 2, 0
  .byte "seconds",0
  rf_label 176, 40, 2, 0
  .byte "frames",0
  .byte 0
stopwatch_ball_x:
  .byte 116,142,159,159,142,116, 90, 73, 73, 90
stopwatch_ball_y:
  .byte  87, 97,123,155,181,191,181,155,123, 97

COLON_DOT = $BC
RULER_DOT = $BD
LAP_INDICATOR_LEFT = $BE
LAP_INDICATOR_RIGHT = $BF
lapIndicatorAddr = lineImgBuf+96+24

.segment "CODE"
.proc do_stopwatch
  ldx #4
  lda #$80
  sta sw_running
  asl a
  :
    sta sw_hours,x
    dex
    bpl :-
  stx sw_hide_ruler  ; $FF: hide; $00: show
  lda #$36
  sta sw_inactive_color
restart:
  lda #VBLANK_NMI
  sta help_reload
  sta PPUCTRL
  ldx #$00
  stx PPUMASK
  stx rf_curpattable

  ; Tiles $00-$7F (approximately): the clock face
  lda #8
  jsr load_sb53_file

  ; set sprite palette same as bg palette
  ldy #0
  palloop:
    lda PB53_outbuf,y
    sta PPUDATA
    iny
    cpy #16
    bcc palloop

  ; BG and OBJ tiles $80-$BB: background digits (6 tiles each)
  ; $BC: colon dot
  ldx #$08
  jsr unpb53_fizzter_digits
  ldx #$18
  jsr unpb53_fizzter_digits

  ; $C0-$CF we reserve for labels
  lda #$20
  sta rf_curnametable
  lda #$C0
  sta rf_tilenum
  lda #<stopwatch_labels
  sta ciSrc
  lda #>stopwatch_labels
  sta ciSrc+1
  jsr rf_draw_labels
  
  ; OBJ tiles $00-$59: sprite dot overlays (9 tiles each)
  ; $5A: pointer dot
  ldx #$10
  ldy #$00
  lda #0  ; 0: stopwatch_balls
  jsr unpb53_file

  ; Uses 30 sprites for ruler, 10 for clock hand, and 12 for digits
  ldx #(30+10+12)*4
  jsr ppu_clear_oam

  ; Clear background buffer. After ppu_clear_oam, X=0
  txa
:
  sta lineImgBuf,x
  inx
  bpl :-
  jsr sw_prepare

loop:
  ; counting logic
  bit sw_running
  bvc not_counting
    ldy #0
    inc sw_frames
    lda sw_frames
    ldx tvSystem
    cmp tvSystemFPS,x
    bcc not_counting
    sty sw_frames
    inc sw_seconds
    lda sw_seconds
    cmp #60
    bcc not_counting
    sty sw_seconds
    inc sw_minutes
    lda sw_minutes
    cmp #60
    bcc not_counting
    sty sw_minutes
    inc sw_hours
    lda sw_hours
    cmp #100
    bcc not_counting
    sty sw_hours
  not_counting:

  bit sw_running
  bpl not_updating
    jsr sw_prepare
    jmp update_done
  not_updating:
    lda #LAP_INDICATOR_LEFT
    sta lapIndicatorAddr
    lda #LAP_INDICATOR_RIGHT
    sta lapIndicatorAddr+1
  update_done:
  
  lda nmis
:
  cmp nmis
  beq :-
  jsr rf_copy8tiles

  ; change the color of inactive circles
  lda #$3F
  sta PPUADDR
  lda #$05
  sta PPUADDR
  lda sw_inactive_color
  sta PPUDATA
  sec
  sbc #$10
  sta PPUDATA

  lda #VBLANK_NMI|BG_0000|OBJ_1000
  jsr ppu_oam_dma_screen_on_xy0

  lda #helpsect_stopwatch
  jsr read_pads_helpcheck
  bcc not_help
    jmp restart
  not_help:
  
  lda new_keys+0
  and #KEY_A
  beq notStartStop
    lda #$40
    eor sw_running
    sta sw_running
  notStartStop:

  lda new_keys+0
  and #KEY_UP
  beq notToggleRuler
    lda #$FF
    eor sw_hide_ruler
    sta sw_hide_ruler
  notToggleRuler:

  lda new_keys+0
  and #KEY_DOWN
  beq notToggleInactiveCircles
    lda #$06
    eor sw_inactive_color
    sta sw_inactive_color
  notToggleInactiveCircles:

  lda new_keys+0
  and #KEY_SELECT
  beq notLapReset
    ; If stopped and not lap, reset.  Otherwise toggle lap.
    lda sw_running
    cmp #$80
    bne pressedLap

    ; clear to 0
    asl a
    ldx #3
    :
      sta sw_hours,x
      dex
      bpl :-
    bmi notLapReset
  pressedLap:
    eor #$80
    sta sw_running
  notLapReset:

  lda new_keys+0
  and #KEY_B
  bne done
  jmp loop
done:
  rts
.endproc

;;
; Loads 64 tiles of digit shape into CHR RAM.
; @param A upper byte of destination VRAM address
.proc unpb53_fizzter_digits
  ldy #$00
  lda #1
  jmp unpb53_file
.endproc

.proc sw_prepare
  ldx #0
  rulerloop:
    txa
    asl a
    ora sw_hide_ruler
    sta OAM+0,x
    and #$08
    adc #$08
    sta OAM+3,x
    lda #RULER_DOT
    sta OAM+1,x
    lda #3  ; the ruler is red
    sta OAM+2,x
    inx
    inx
    inx
    inx
    cpx #120
    bcc rulerloop
  stx oam_used
  lda #$20
  sta vram_copydsthi
  lda #$C0
  sta vram_copydstlo

  lda sw_hours
  ldx #7
  jsr sw_draw_digits
  lda sw_minutes
  ldx #12
  jsr sw_draw_digits
  lda sw_seconds
  ldx #17
  jsr sw_draw_digits

  ; Draw low digits as sprites so they appear on Hi-Def NES
  ; composite output
  lda sw_frames
  jsr bcd8bit
  sta sw_framesones
  lda bcd_highdigits
  ldx #176
  jsr sw_draw_sprite_digit
  ldx #192
  lda sw_framesones
  jsr sw_draw_sprite_digit

  ; Erase lap indicator
  lda #0
  sta lapIndicatorAddr
  sta lapIndicatorAddr+1

  ; Draw last digit as a sprite on a sped-up clock face
  lda sw_framesones
  tax
  sta sprect_tilenum
  asl a
  asl a
  asl a
  adc sprect_tilenum
  sta sprect_tilenum
  lda stopwatch_ball_x,x
  sta sprect_x
  lda stopwatch_ball_y,x
  sta sprect_y
  lda #3
  sta sprect_attr  ; color palette 3: reds
  sta sprect_w
  sta sprect_h
  lsr a
  sta sprect_tileadd
  jsr draw_spriterect

  ; And a separate smaller red ball pointing at it
  ldx oam_used
  lda sprect_y
  lsr a
  clc
  adc #78-12
  sta OAM,x
  lda #90
  sta OAM+1,x
  lda #3
  sta OAM+2,x
  lda sprect_x
  lsr a
  clc
  adc #54+12
  sta OAM+3,x

  ; Finally draw colon dots
  lda #COLON_DOT
  ldx #32+11
  jsr onesetofcolondots
  ldx #64+11
onesetofcolondots:
  .repeat 3, I
    sta lineImgBuf+5*I,x
  .endrepeat
  rts  
.endproc

;;
; Draw one digit in A (0-9) at horizontal position X
; in the sprite buffer.
.proc sw_draw_sprite_digit
  sta sprect_tilenum
  asl a
  adc sprect_tilenum
  asl a
  ora #$80
  sta sprect_tilenum
  stx sprect_x
  lda #47
  sta sprect_y
  ldx #1
  stx sprect_tileadd
  inx
  stx sprect_w
  inx
  stx sprect_h
  lda sw_frames
  and #$01
  ora #$02
  sta sprect_attr
  jmp draw_spriterect
.endproc

;;
; Draw digits of number in A (0-99) at horizontal position X
; in the nametable buffer.
.proc sw_draw_digits
  jsr bcd8bit
  pha
  lda bcd_highdigits
  jsr onedig
  pla
onedig:
  sta bcd_highdigits
  asl a
  adc bcd_highdigits
  asl a
  ora #$80
  jsr onedigcol
  adc #<-5
  clc
onedigcol:
  .repeat 3, I
    sta lineImgBuf+32*I,x
    adc #2
  .endrepeat
  inx
  rts
.endproc
