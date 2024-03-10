.include "nes.inc"
.include "global.inc"
.include "rectfill.inc"
.importzp RF_hanover, helpsect_hanover_bars

hanover_bgcolor = test_state+0

.code
.proc do_hanover_bars
  lda #0
  sta hanover_bgcolor
restart:
  lda #$80
  sta help_reload
  sta PPUCTRL
  asl a
  sta PPUMASK
  lda #RF_hanover
  jsr rf_load_layout
  lda #$3F
  sta PPUADDR
  ldx #$01
  stx PPUADDR
  palloop:
    lda hanover_palette-1,x
    sta PPUDATA
    inx
    cpx #hanover_palette_end-hanover_palette+1
    bcc palloop
  ldx #0
  jsr ppu_clear_oam

  ; fill tiles
  ldx #0
  stx PPUADDR
  stx PPUADDR
  jsr hanover_gentiles
  ldx #0
  stx PPUDATA
  inx
  jsr hanover_gentiles

  ; generate sprite
  ldx #0
  objloop:
    txa
    and #%01110000  ; keep row
    lsr a
    cmp #24  ; move bottom sprites down 1 line
    adc #79
    sta OAM,x
    inx
    lda #1
    sta OAM,x
    inx
    lsr a
    sta OAM,x
    inx
    txa
    and #%00001100  ; keep column
    asl a
    adc #48
    sta OAM,x
    inx
    cpx #$60
    bcc objloop

loop:
  lda #helpsect_hanover_bars
  jsr read_pads_helpcheck
  bcs restart

  ldy hanover_bgcolor
  lda new_keys
  lsr a
  bcc not_right
    iny
  not_right:
  lsr a
  bcc not_left
    dey
  not_left:
  cpy #13
  bcc have_new_bgcolor
  bmi wrap_below_0
    ldy #0
    beq have_new_bgcolor
  wrap_below_0:
    ldy #13-1
  have_new_bgcolor:
  sty hanover_bgcolor

  jsr ppu_wait_vblank

  ; update palette
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda hanover_bgcolor
  beq :+
    ora #$10
  :
  sta PPUDATA
  ; update nametable
  lda #$20
  sta PPUADDR
  lda #$CD
  sta PPUADDR
  lda hanover_bgcolor
  beq :+
    lda #2
  :
  ora #$20
  sta PPUDATA
  lda hanover_bgcolor
  cmp #1
  adc #$21
  sta PPUDATA
  
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  jsr ppu_oam_dma_screen_on_xy0
  bit new_keys+0
  bvc loop
  rts
.endproc

.proc hanover_gentiles
xorvalue = $01
  txa
  and #$01
  jsr genplane
  txa
  and #$02
  jsr genplane
  inx
  cpx #4
  bcc hanover_gentiles
  rts
genplane:
  beq :+
    lda #$FF
  :
  sta xorvalue
  ldy #8
  byteloop:
    sta PPUDATA
    eor xorvalue
    dey
    bne byteloop
  rts
.endproc

.rodata
; palette 1: 144,80-240,128
; palette 2: 48,144-144,192
; palette 3: 144,144-240-192

hanover_palette:
  .byte     $20,$12,$13, $00,$14,$15,$16, $00,$17,$18,$19, $00,$1a,$1b,$1c
  .byte $00,$11
hanover_palette_end:
