;
; Zapper test program, corresponding to "Y COORD 1 GUN"
; activity in Zap Ruder
;
; Copyright 2016 Damian Yerrick
;
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;
.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp helpsect_zapper_test

.align 128
.code
;;
; @param Y total number of lines to wait
; @param X which port to read (0 or 1)
; @return $0000=number of lines off, $0001=number of lines on
.proc zapkernel_yonoff_ntsc
off_lines = 0
on_lines = 1
subcycle = 2
DEBUG_THIS = 0
  lda #0
  sta off_lines
  sta on_lines
  sta subcycle

; Wait for photosensor to turn ON
lineloop_on:
  ; 8
  lda #$08
  and $4016,x
  beq hit_on

  ; 72
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12

  ; 11
  lda off_lines
  and #LIGHTGRAY
  ora #BG_ON|OBJ_ON
.if DEBUG_THIS
  sta PPUMASK
.else
  bit $0100
.endif

  ; 12.67
  clc
  lda subcycle
  adc #$AA
  sta subcycle
  bcs :+
:

  ; 10
  inc off_lines
  dey
  bne lineloop_on
  jmp bail

; Wait for photosensor to turn ON
lineloop_off:
  ; 8
  lda #$08
  and $4016,x
  bne hit_off

hit_on:
  ; 72
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12

  ; 11
  lda off_lines
  and #LIGHTGRAY
  ora #BG_ON|OBJ_ON
.if DEBUG_THIS
  sta PPUMASK
.else
  bit $0100
.endif

  ; 12.67
  clc
  lda subcycle
  adc #$AA
  sta subcycle
  bcs :+
:

  ; 10
  inc on_lines
  dey
  bne lineloop_off

hit_off:
bail:
waste_12:
  rts
.endproc

.rodata

ZAPPER_S0_X = 128
ZAPPER_S0_TILE = $0F
ZAPPER_ARROW_TILE = $1A

zapper_rects:
  rf_rect   0,  0,256, 24,$04, 0  ; Top letterbox (incl. sprite 0 trigger)
  rf_rect   0, 24,256,216,$00, 0  ; Blank center
  rf_rect   0,216,256,240,$04, 0  ; Bottom letterbox
  rf_rect  64,184,80,200,$F8, RF_INCR  ; text area (Y, height)
  .byte $00
zapper_attrs:
  rf_attr  0,  0,256, 240, 0
  .byte $00
zapper_texts:
  rf_label 16, 168, 1, 0
  .byte "Zapper test",0
  rf_label 16, 184, 1, 0
  .byte "Light Y:",0
  rf_label 16, 192, 1, 0
  .byte "Height:",0
  rf_label 16, 208, 1, 0
  .byte "B: Exit",0
  .byte $00

zapper_initial_oam:
  .byte 15,ZAPPER_S0_TILE,$23,ZAPPER_S0_X
  .byte $FF,ZAPPER_ARROW_TILE,$42,232
  .byte $FF,ZAPPER_ARROW_TILE,$43,232

zapper_palette:
  .byte $16,$26,$36,$FF,$00,$10,$20
  .byte $20,$0F

.code

.proc do_zapper_test
light_y      = test_state+0
light_height = test_state+1

  jsr rf_load_tiles

  ; Load palette with a light background
  ldx #$3F
  lda #$19
  stx PPUADDR
  sta PPUADDR
  ldx #$00
  stx light_y
  stx light_height
  :
    lda zapper_palette,x
    sta PPUDATA
    inx
    cpx #9
    bcc :-

  ; Load sprite 0
  ldx #12
  jsr ppu_clear_oam
  ldx #11
  :
    lda zapper_initial_oam,x
    sta OAM,x
    dex
    bpl :-

  ; Load nametable
  ldx #$00
  stx rf_curpattable
  ldx #$20
  stx rf_curnametable
  stx rf_tilenum
  ldy #<zapper_rects
  lda #>zapper_rects
  jsr rf_draw_rects_attrs_ay
  inc ciSrc
  bne :+
    inc ciSrc+1
  :
  jsr rf_draw_labels

forever:

  ; Draw Y and height
  jsr clearLineImg
  ldx #10
  lda light_y
  jsr vwfPut3Digits
  ldx #26
  lda light_height
  jsr vwfPut3Digits
  lda #%0001
  jsr rf_color_lineImgBuf
  lda #$0F
  sta vram_copydsthi
  lda #$80
  sta vram_copydstlo

  lda nmis
:
  cmp nmis
  beq :-

  lda #$00
  sta OAMADDR
  lda #>OAM
  sta OAM_DMA
  jsr rf_copy8tiles
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  sec
  jsr ppu_screen_on_xy0

  ; First wait for sprite 0 to be clear (pre-render line)
  waits0off:
    bit PPUSTATUS
    bvs waits0off

  lda #helpsect_zapper_test
  jsr read_pads_helpcheck
  bcc not_help
    jmp do_zapper_test
  not_help:
  
  ; With the port number still in X, wait for either sprite 0 to be
  ; set or a flat out miss
  ldx #1  ; port number
  lda #$C0
  tay
  sty light_height
  s0loop:
    bit PPUSTATUS
    beq s0loop
    bmi not_s0

  ; If no miss, wait up to 192 lines
  jsr zapkernel_yonoff_ntsc
  lda $00
  sta light_y
  lda $01
  sta light_height
not_s0:

  ; Draw light position as sprites  
  lda #16
  clc
  adc light_y
  sta OAM+4
  clc
  adc light_height
  sta OAM+8
  lda #KEY_B
  and new_keys+0
  beq forever
  rts
.endproc

;;
; Writes a 3-digit number to the line buffer.
; @param A positive from 0 to 255
; @param X horizontal position of rightmost digit
.proc vwfPut3Digits
xposition = $01
  stx xposition
  jsr bcd8bit
  ora #'0'
  jsr vwfPutTile
  lda bcd_highdigits
  beq notens
    cmp #$10
    bcc nohundreds
      ;sec
      lda xposition
      sbc #10
      tax
      lda bcd_highdigits
      lsr a
      lsr a
      lsr a
      lsr a
      ora #'0'
      jsr vwfPutTile
    nohundreds:
    sec
    lda xposition
    sbc #5
    tax
    lda bcd_highdigits
    and #$0F
    ora #'0'
    jsr vwfPutTile
  notens:
  rts
.endproc
